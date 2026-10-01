extends Node

## **A wild dragon is pure destruction, and a steward of the wrath** (owner,
## 2026-10-01):
##
##   godot --headless --path game res://tools/dragon_wild_check.tscn
##
## - **It weighs everything living the way Aurelion Sol would**: a body this
##   breath would finish outweighs a whole one, a near body a far one, and a
##   Warden more than either; the line through two weak bodies is chosen over
##   the line through one strong one; and the dragon breathes first at the one
##   most worth it.
## - **Its breath takes everything on the line** - road bodies and animals as
##   well as Wardens - each once, by the share it authors; a camp wyrm's breath
##   still takes only the party.
## - **What it kills, the earth counts as a kill and more**.
## - **It grows with the anger**, and a guest is told how much.

var _failures: int = 0
var _checks: int = 0
var _finished: int = 0
var _run: Run = null
var _field: Battlefield = null
var _sky: WeatherSky = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20261014)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field = _run.battlefield
	_field.wave_director.stop()
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	_field.hero.health.floor_hp = _field.hero.health.max_hp
	_field.hero.global_position = Vector2(0.0, 2000.0)
	_sky = _field.sky()
	_sky.events_enabled = false
	_field.wildlife().set("_hush_left", 99999.0)
	await _test_the_aim()
	await _test_the_breath_takes_everything()
	await _test_it_breathes_at_the_weak()
	await _test_it_grows_with_the_anger()
	_check(_finished == 4, "%d of 4 tests reached their end" % _finished)
	RunState.set_phase(RunState.Phase.PREPARATION)
	GameDirector.run_active = false
	_run.queue_free()
	MetaState.resume_saves()
	if _failures == 0:
		print("[dragon-wild] PASS - %d checks: the wild dragon weighs the weak and the near, takes everything on its line once, counts its kills on the wrath, breathes first at the most worth it, and grows with the anger" % _checks)
	else:
		push_error("[dragon-wild] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _body(at: Vector2, hp_share: float = 1.0) -> Enemy:
	var body: Enemy = _field.spawn_enemy(ContentDB.enemy("bogkin"), 0, 1.0, 0.001, 0.001)
	await get_tree().process_frame
	body.global_position = at
	body.process_mode = Node.PROCESS_MODE_DISABLED
	body.health.max_hp = 400.0
	body.health.current_hp = 400.0 * hp_share
	return body


func _grazer() -> WildlifeData:
	for kind: WildlifeData in ContentDB.wildlife():
		if not kind.is_hostile() and not kind.mythic and not kind.flies and not kind.amphibious \
				and not kind.steals and not kind.hoards:
			return kind
	return null


func _animal(at: Vector2) -> Dictionary:
	var wild: Wildlife = _field.wildlife()
	wild.call("_spawn", _grazer(), at)
	var living: Array[Dictionary] = wild.living()
	var animal: Dictionary = living[living.size() - 1]
	(animal["sprite"] as Sprite2D).global_position = at
	animal["state"] = Wildlife.State.SETTLED
	animal["goal"] = at
	return animal


func _clear_bodies() -> void:
	for body: Enemy in _field.living_bodies():
		body.queue_free()
	_field.wildlife().clear()
	await get_tree().process_frame
	await get_tree().process_frame


func _weight_at(marks: Array[Dictionary], at: Vector2) -> float:
	for mark: Dictionary in marks:
		if (mark["at"] as Vector2).distance_to(at) < 1.0:
			return float(mark["weight"])
	return -1.0


func _test_the_aim() -> void:
	await _clear_bodies()
	var mouth: Vector2 = Vector2(-1200.0, 0.0)
	var whole: Enemy = await _body(mouth + Vector2(300.0, 0.0), 1.0)
	var finished: Enemy = await _body(mouth + Vector2(0.0, 300.0), 0.2)
	var far: Enemy = await _body(mouth + Vector2(0.0, -540.0), 1.0)
	var marks: Array[Dictionary] = DragonBreath.wild_marks(get_tree(), _field, mouth, 560.0, {}, 0.1)
	var w_whole: float = _weight_at(marks, whole.global_position)
	var w_finished: float = _weight_at(marks, finished.global_position)
	var w_far: float = _weight_at(marks, far.global_position)
	_check(w_whole > 0.0 and w_finished > 0.0 and w_far > 0.0, "a body in reach was not weighed")
	_check(w_finished > w_whole + Balance.DRAGON_AIM_LAST_HIT * 0.9,
		"a body this breath would finish weighed %.2f against a whole one's %.2f" % [w_finished, w_whole])
	_check(w_whole > w_far, "a near body weighed no more than a far one")
	var out: Enemy = await _body(mouth + Vector2(900.0, 0.0), 0.1)
	marks = DragonBreath.wild_marks(get_tree(), _field, mouth, 560.0, {}, 0.1)
	_check(_weight_at(marks, out.global_position) < 0.0, "a body out of reach was weighed")
	var struck: Dictionary = {finished.get_instance_id(): true}
	marks = DragonBreath.wild_marks(get_tree(), _field, mouth, 560.0, struck, 0.1)
	_check(_weight_at(marks, finished.global_position) < 0.0, "a body already struck was weighed again")
	# The line through two weak bodies over the line through one strong one.
	var lines: Array[Dictionary] = [
		{"at": mouth + Vector2.from_angle(0.6) * 300.0, "weight": 3.2},
		{"at": mouth + Vector2.from_angle(0.6) * 420.0, "weight": 3.0},
		{"at": mouth + Vector2.from_angle(-0.6) * 300.0, "weight": 1.6},
	]
	var angle: float = DragonBreath.best_line_among(lines, mouth, 0.0, 0.9, 560.0, 40.0, 0.0)
	_check(absf(angle - 0.6) < 0.1, "the breath chose %.2f, not the line through the two weak bodies" % angle)
	# A Warden counts, and more.
	var hero: Hero = _field.hero
	hero.global_position = mouth + Vector2(-300.0, 0.0)
	marks = DragonBreath.wild_marks(get_tree(), _field, mouth, 560.0, {}, 0.1)
	_check(_weight_at(marks, hero.global_position) > w_whole,
		"a Warden as near as a whole body weighed no more than it")
	hero.global_position = Vector2(0.0, 2000.0)
	_finished += 1


func _hazard(from: Vector2, to: Vector2, wild: bool) -> GroundHazard:
	var hazard := GroundHazard.new()
	hazard.field = _field
	hazard.plan = {"mode": "breath", "from": from, "to": to, "origin": from,
		"element": "fire", "ultra": false, "width": 40.0, "warning": 0.05, "travel": 0.3,
		"share": 0.1, "tower_damage": 0.0, "tint": Color(1.0, 0.5, 0.2), "wild": wild,
		"blame": "a test dragon"}
	_field.add_child(hazard)
	return hazard


func _test_the_breath_takes_everything() -> void:
	await _clear_bodies()
	_sky.set("_wrath_floor", 0.0)
	_sky.set("_wrath_heat", 0.0)
	var from: Vector2 = Vector2(-1400.0, -600.0)
	var to: Vector2 = from + Vector2(500.0, 0.0)
	# The Warden near enough that the animals are not forgotten, off the line.
	_field.hero.global_position = from + Vector2(250.0, 420.0)
	var body: Enemy = await _body(from + Vector2(250.0, 0.0), 1.0)
	var animal: Dictionary = _animal(from + Vector2(350.0, 0.0))
	var fell: Array[String] = []
	var listen: Callable = func(_k: String, _a: Vector2, _r: int, _s: bool, cause: String) -> void:
		fell.append(cause)
	EventBus.wildlife_fell.connect(listen)
	var hazard: GroundHazard = _hazard(from, to, true)
	for _f: int in 90:
		await get_tree().physics_frame
		if not is_instance_valid(hazard):
			break
	var taken: float = 400.0 - body.health.current_hp if is_instance_valid(body) else -1.0
	_check(is_equal_approx(taken, DragonBreath.wild_blow(400.0)),
		"a body on the line took %.1f, not the wild breath's %.1f once" % [taken, DragonBreath.wild_blow(400.0)])
	var hurt: bool = float(animal.get("hp", 0.0)) < Wildlife.pool_of(animal) - 0.5 \
		or float(animal.get("dying", 0.0)) > 0.0
	_check(hurt, "an animal on the line was not touched")
	EventBus.wildlife_fell.disconnect(listen)
	_check(fell.is_empty() or fell == ["dragon"], "an animal the dragon killed was announced as %s" % str(fell))
	# Kill one for certain and read the earth.
	var victim: Dictionary = _animal(from + Vector2(150.0, 40.0))
	var floor_before: float = float(_sky.get("_wrath_floor"))
	var wild: Wildlife = _field.wildlife()
	wild.wound_where(func(_at: Vector2) -> bool: return true, 50.0, "dragon", {})
	_check(float(victim.get("dying", 0.0)) > 0.0, "a dragon's blow of fifty times a pool did not kill")
	_check(float(_sky.get("_wrath_floor")) > floor_before, "the earth did not count the dragon's kill")
	# A breath that is not wild takes only the party.
	await _clear_bodies()
	var spared: Enemy = await _body(from + Vector2(250.0, 0.0), 1.0)
	var camp_line: GroundHazard = _hazard(from, to, false)
	for _f: int in 90:
		await get_tree().physics_frame
		if not is_instance_valid(camp_line):
			break
	_check(is_equal_approx(spared.health.current_hp, 400.0), "a breath that is not wild struck a road body")
	_finished += 1


func _test_it_breathes_at_the_weak() -> void:
	await _clear_bodies()
	var at: Vector2 = Vector2(1300.0, -900.0)
	var wyrm := DragonPass.new()
	wyrm.from = at + Vector2(-3000.0, 0.0)
	wyrm.to = at + Vector2(3000.0, 0.0)
	wyrm.field = _field
	_field.add_child(wyrm)
	await get_tree().process_frame
	wyrm.set_process(false)
	wyrm.global_position = at
	var whole: Enemy = await _body(at + Vector2(0.0, 200.0), 1.0)
	var weak: Enemy = await _body(at + Vector2(0.0, -260.0), 0.15)
	var aimed: Array[Vector2] = []
	var listen: Callable = func(kind: String, payload: Dictionary) -> void:
		if kind == "ground" and String(payload.get("mode", "")) == "breath":
			aimed.append(payload["to"] as Vector2)
	EventBus.world_hazard.connect(listen)
	for _try: int in 30:
		wyrm.call("_breathe")
		if not aimed.is_empty():
			break
	EventBus.world_hazard.disconnect(listen)
	_check(not aimed.is_empty(), "the dragon never breathed in thirty tries")
	if not aimed.is_empty():
		# Toward it: an ultra breathes past it, along the same line.
		var toward: Vector2 = (weak.global_position - at).normalized()
		_check((aimed[0] - at).normalized().dot(toward) > 0.999,
			"the dragon breathed toward %s, not at the body it could finish" % aimed[0])
	_check(is_instance_valid(whole) and is_equal_approx(whole.health.current_hp, 400.0),
		"choosing a target struck the whole body")
	wyrm.queue_free()
	for node: Node in get_tree().get_nodes_in_group(&"ground_hazard"):
		node.queue_free()
	_finished += 1


func _test_it_grows_with_the_anger() -> void:
	await _clear_bodies()
	_sky.set("_wrath_floor", 0.0)
	_sky.set("_wrath_heat", 0.0)
	var calm: DragonPass = _sky.send_dragon()
	_check(calm != null, "the sky sent no dragon")
	if calm == null:
		_finished += 1
		return
	await get_tree().process_frame
	_check(is_equal_approx(calm.fury, 1.0), "a dragon over a calm earth was drawn larger")
	var calm_size: Vector2 = calm.flying_size() / (1.0 + float(calm.rarity) * Balance.DRAGON_RARITY_SIZE_STEP)
	calm.free()
	await get_tree().process_frame
	_sky.set("_wrath_heat", Balance.WRATH_CAP * 2.0)
	var angry: DragonPass = _sky.send_dragon()
	_check(angry != null, "the sky sent no second dragon")
	if angry != null:
		await get_tree().process_frame
		_check(is_equal_approx(angry.fury, 1.0 + Balance.DRAGON_WRATH_GROWTH),
			"a dragon at the wrath's ceiling grew %.2f, not %.2f" % [angry.fury, 1.0 + Balance.DRAGON_WRATH_GROWTH])
		var angry_size: Vector2 = angry.flying_size() / (1.0 + float(angry.rarity) * Balance.DRAGON_RARITY_SIZE_STEP)
		if calm_size.x > 0.0:
			_check(absf(angry_size.x / calm_size.x - angry.fury) < 0.01,
				"the angry dragon is drawn %.2f the calm one's size, not %.2f" % [angry_size.x / calm_size.x, angry.fury])
		_check(float(angry.encounter_plan().get("fury", 0.0)) == angry.fury, "a guest is not told how large it is")
		var mirrored := DragonPass.new()
		mirrored.from = angry.from
		mirrored.to = angry.to
		mirrored.authored_plan = angry.encounter_plan()
		_field.add_child(mirrored)
		await get_tree().process_frame
		_check(is_equal_approx(mirrored.fury, angry.fury), "a guest's dragon was drawn at another size")
		mirrored.free()
		angry.free()
	_sky.set("_wrath_heat", 0.0)
	_finished += 1


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[dragon-wild] " + why)
