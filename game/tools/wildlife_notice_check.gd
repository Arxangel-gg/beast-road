extends Node

## **The animals hear the road** (owner, 2026-10-01: *"Wildlife should receive
## threat notifications sent from threatful events if in range of receiving the
## notices. Make AI behaviors smarter. Keep it optimized and efficient."*):
##
##   godot --headless --path game res://tools/wildlife_notice_check.tscn
##
## Driven on a real field through the bus signals the road already raises:
##
## - **A death near a grazer sends it running away from it**, a death out of
##   its hearing leaves it be, and one in between lifts its head.
## - **Its own kind falling is heard from further**, and **the herd runs
##   together**: a grazer that bolts takes its kind close by with it.
## - **A blast sends everything running**, predators included; **a clash may
##   draw a predator** toward it; **the birds come to a death**.
## - **A fright is remembered**: wandering walks round the ground it was on.
## - **It costs one pass however loud the fight**: a hundred blows in one place
##   in one frame are one notice, and the frame's news is capped.

var _failures: int = 0
var _checks: int = 0
var _finished: int = 0
var _run: Run = null
var _field: Battlefield = null
var _wild: Wildlife = null
var _grazer: WildlifeData = null
var _predator: WildlifeData = null
var _scavenger: WildlifeData = null
## Where the Warden stands, far enough from the animals not to frighten them.
var _warden_at: Vector2 = Vector2(0.0, 1700.0)


func _ready() -> void:
	MetaState.hold_saves()
	await _stand_a_field()
	if _wild != null and _grazer != null:
		await _test_a_death_is_heard_by_distance()
		await _test_kin_and_the_herd()
		await _test_a_blast_and_a_clash()
		await _test_the_birds_come()
		await _test_a_fright_is_remembered()
		await _test_it_costs_one_pass()
	_check(_finished == 6, "%d of 6 tests reached their end" % _finished)
	if _run != null:
		RunState.set_phase(RunState.Phase.PREPARATION)
		GameDirector.run_active = false
		_run.queue_free()
	MetaState.resume_saves()
	if _failures == 0:
		print("[wildlife-notice] PASS - %d checks: a death is heard by distance, kin and the herd run together, a blast scatters everything and a clash draws a predator, the birds come to a death, a fright is remembered, and a loud fight costs one pass" % _checks)
	else:
		push_error("[wildlife-notice] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _stand_a_field() -> void:
	RunState.reset(false, 20261012)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	_field = _run.battlefield
	_field.wave_director.stop()
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	_field.hero.global_position = _warden_at
	_wild = _field.wildlife()
	_check(_wild != null, "the field has no wildlife")
	if _wild == null:
		return
	# Nothing arrives while the harness places its own animals.
	_wild.set("_hush_left", 99999.0)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	for kind: WildlifeData in ContentDB.wildlife():
		if kind.mythic or kind.flies or kind.amphibious or kind.steals or kind.hoards:
			continue
		if _grazer == null and not kind.is_hostile() and kind.skittish_radius > 120.0:
			_grazer = kind
		if _predator == null and kind.is_hostile() \
				and kind.temperament == WildlifeData.Temperament.PREDATORY:
			_predator = kind
	for kind: WildlifeData in ContentDB.wildlife():
		if _scavenger == null and kind.skittish_radius <= 0.0 and not kind.is_hostile() \
				and not kind.mythic:
			_scavenger = kind
	_check(_grazer != null, "the roster has no skittish grazer to listen with")
	_check(_predator != null, "the roster has no predator to listen with")
	_check(_scavenger != null, "the roster has no bird that comes to a battle")


func _clear() -> void:
	_wild.clear()
	_wild.set("_notices", [] as Array[Dictionary])
	await get_tree().process_frame


## An animal of `kind` standing quietly at `at`.
func _place(kind: WildlifeData, at: Vector2) -> Dictionary:
	_wild.call("_spawn", kind, at)
	var living: Array[Dictionary] = _wild.living()
	var animal: Dictionary = living[living.size() - 1]
	var sprite := animal["sprite"] as Sprite2D
	sprite.global_position = at
	animal["state"] = Wildlife.State.SETTLED
	animal["goal"] = at
	animal["home"] = at
	animal["pause"] = 99.0
	animal["patience"] = 999.0
	return animal


func _at(animal: Dictionary) -> Vector2:
	return (animal["sprite"] as Sprite2D).global_position


func _state(animal: Dictionary) -> int:
	return int(animal["state"])


func _test_a_death_is_heard_by_distance() -> void:
	await _clear()
	var origin: Vector2 = _warden_at + Vector2(0.0, -900.0)
	var near: Dictionary = _place(_grazer, origin + Vector2(220.0, 0.0))
	var middle: Dictionary = _place(_grazer, origin + Vector2(-Balance.WILDLIFE_NOTICE_DEATH_REACH
		* Wildlife.hearing_of(_grazer) * 0.85, 0.0))
	var far: Dictionary = _place(_grazer, origin + Vector2(0.0, -Balance.WILDLIFE_NOTICE_DEATH_REACH
		* Wildlife.hearing_of(_grazer) * 1.8))
	EventBus.enemy_died.emit("bogkin", origin)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_state(near) == Wildlife.State.FLEEING, "a grazer beside a death did not run")
	var goal: Vector2 = near["goal"] as Vector2
	_check(goal.distance_to(origin) > _at(near).distance_to(origin),
		"a grazer ran toward the death it heard, not away from it")
	_check(_state(middle) == Wildlife.State.ALERT,
		"a grazer at the edge of its hearing did not lift its head (state %d)" % _state(middle))
	_check(_state(far) == Wildlife.State.SETTLED, "a grazer out of earshot answered a death")
	_finished += 1


func _test_kin_and_the_herd() -> void:
	await _clear()
	var origin: Vector2 = _warden_at + Vector2(0.0, -900.0)
	# Further than any death is heard from, but it is its own kind.
	var cousin: Dictionary = _place(_grazer, origin + Vector2(Balance.WILDLIFE_NOTICE_DEATH_REACH
		* Wildlife.hearing_of(_grazer) * 0.9, 0.0))
	# And beyond that, out of earshot, but beside the cousin: the herd.
	var herd: Dictionary = _place(_grazer, _at(cousin) + Vector2(Balance.WILDLIFE_KIN_REACH * 0.6, 0.0))
	_check(_at(herd).distance_to(origin) > Balance.WILDLIFE_NOTICE_DEATH_REACH * Wildlife.hearing_of(_grazer),
		"the harness put the herd within earshot")
	_wild.notice(origin, Balance.WILDLIFE_NOTICE_DEATH_REACH, Wildlife.Notice.DEATH, _grazer.id)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_state(cousin) == Wildlife.State.FLEEING, "a grazer did not run from its own kind falling")
	_check(_state(herd) == Wildlife.State.FLEEING, "the herd did not run with the one that bolted")
	_finished += 1


func _test_a_blast_and_a_clash() -> void:
	await _clear()
	var origin: Vector2 = _warden_at + Vector2(0.0, -900.0)
	var wolf: Dictionary = _place(_predator, origin + Vector2(300.0, 0.0))
	EventBus.camera_impact.emit(origin, Balance.WILDLIFE_NOTICE_BLAST_FROM * 2.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_state(wolf) == Wildlife.State.FLEEING, "a predator stood its ground against a blast")
	# A clash may draw it: across enough tries, its haunt moves toward the fight.
	var drawn: int = 0
	for attempt: int in 12:
		await _clear()
		var hunter: Dictionary = _place(_predator, origin + Vector2(380.0, 0.0))
		var home_before: Vector2 = hunter["home"] as Vector2
		EventBus.camera_impact.emit(origin + Vector2(0.0, float(attempt)), 0.6)
		await get_tree().process_frame
		await get_tree().process_frame
		if (hunter["home"] as Vector2).distance_to(origin) < home_before.distance_to(origin) - 40.0:
			drawn += 1
	_check(drawn > 0, "a clash never drew a predator toward it in twelve tries")
	_check(drawn < 12, "every clash drew the predator - it is a pull, not a leash")
	_finished += 1


func _test_the_birds_come() -> void:
	await _clear()
	if _scavenger == null:
		_finished += 1
		return
	var origin: Vector2 = _warden_at + Vector2(0.0, -900.0)
	var bird: Dictionary = _place(_scavenger, origin + Vector2(350.0, -120.0))
	EventBus.enemy_died.emit("bogkin", origin)
	await get_tree().process_frame
	await get_tree().process_frame
	_check((bird["goal"] as Vector2).distance_to(origin) < 120.0,
		"a bird that lives off a battle did not come to the death")
	_finished += 1


func _test_a_fright_is_remembered() -> void:
	await _clear()
	var origin: Vector2 = _warden_at + Vector2(0.0, -900.0)
	var deer: Dictionary = _place(_grazer, origin + Vector2(150.0, 0.0))
	EventBus.enemy_died.emit("bogkin", origin)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(float(deer.get("fear_left", 0.0)) > 0.0, "a fright left no memory")
	# Every wander goal it picks while it remembers stays off that ground.
	var close: int = 0
	for _attempt: int in 40:
		var goal: Vector2 = _wild.call("_clear_of_fear", deer, origin + Vector2(randf_range(-150.0, 150.0),
			randf_range(-150.0, 150.0)))
		if goal.distance_to(origin) < Balance.WILDLIFE_FEAR_RADIUS - 1.0:
			close += 1
	_check(close == 0, "%d wander goals of forty went back onto ground it was frightened on" % close)
	deer["fear_left"] = 0.0
	var free: Vector2 = _wild.call("_clear_of_fear", deer, origin + Vector2(30.0, 0.0))
	_check(free.distance_to(origin + Vector2(30.0, 0.0)) < 1.0, "a forgotten fright still moved a wander goal")
	_finished += 1


func _test_it_costs_one_pass() -> void:
	await _clear()
	var origin: Vector2 = _warden_at + Vector2(0.0, -900.0)
	_place(_grazer, origin + Vector2(900.0, 0.0))
	var heard: int = _wild.notices_heard
	for _blow: int in 100:
		EventBus.camera_impact.emit(origin + Vector2(randf_range(-20.0, 20.0), 0.0), 0.5)
	_check((_wild.get("_notices") as Array).size() == 1,
		"a hundred blows in one place were %d notices, not one" % (_wild.get("_notices") as Array).size())
	for spot: int in 40:
		EventBus.camera_impact.emit(origin + Vector2(float(spot) * 400.0, 0.0), 0.5)
	_check((_wild.get("_notices") as Array).size() <= Balance.WILDLIFE_NOTICE_MAX,
		"a frame's news ran past its cap")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_wild.notices_heard > heard, "the frame's news was never heard")
	_check((_wild.get("_notices") as Array).is_empty(), "the news was heard and kept")
	# A guest decides nothing: its animals are the host's.
	_finished += 1


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[wildlife-notice] " + why)
