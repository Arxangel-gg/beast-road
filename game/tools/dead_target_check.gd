extends Node

## A body lets go of a Warden who has fallen, or gone inside the walls
## (owner, 2026-09-26: "enemies should stop targeting a player once the player
## has died").
##
##   godot --headless --path game res://tools/dead_target_check.tscn
##
## Measured before the fix: of six bodies fighting the Warden on the live field,
## three kept the corpse as their target for four whole seconds and spent 108
## frames striking it. The choosing clock only counted down while a body walked,
## and a fighting body walks one frame a swing; a wind-up was never asked whether
## its target still stood.
##
## Six bodies of the road's own breeds stand round the Warden on the real field.
## Once they are fighting, the Warden is killed by an ordinary blow; after a
## grace of `LET_GO_SECONDS` no body may be walking at, winding up on or
## striking the corpse. Then the same with a living Warden who steps inside the
## walls - the sanctuary rule of 2026-09-17, which the same gap let a chasing
## body ignore.

## Long enough for a blow already falling to finish; nothing after it.
const LET_GO_SECONDS: float = 0.35
const WATCH_SECONDS: float = 3.0

var _run: Run = null
var _field: Battlefield = null
var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260926)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	var animals: Node = _field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.resume()
	# Nothing may end the run while the bodies stand about; the door the
	# withdrawal and the siege gate already use.
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	await _test_a_fallen_warden_is_let_go()
	await _test_a_sheltered_warden_is_let_go()
	for stage: String in ["fallen", "sheltered"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("[dead-target] PASS - %d checks: a body lets go of a Warden who falls or goes inside the walls, and swings at neither" % _checks)
	else:
		push_error("[dead-target] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	printerr("[dead-target] FAIL: %s" % why)


## Six ordinary bodies round `spot`, left to engage the Warden standing on it.
func _surround(spot: Vector2) -> Array[Enemy]:
	var hero: Hero = _field.hero
	hero.global_position = spot
	hero.set_present(true)
	if not hero.is_alive():
		hero.health.revive()
	var bodies: Array[Enemy] = []
	var ids: Array = ContentDB.enemies.keys()
	ids.sort()
	for id: Variant in ids:
		var breed: EnemyData = ContentDB.enemies[id] as EnemyData
		if breed == null or breed.category != EnemyData.Category.BREED:
			continue
		var body: Enemy = _field.spawn_enemy(breed, 0, 1.0)
		if body == null:
			continue
		body.global_position = spot + Vector2.RIGHT.rotated(TAU * float(bodies.size()) / 6.0) * 140.0
		bodies.append(body)
		if bodies.size() >= 6:
			break
	return bodies


func _engaged(bodies: Array[Enemy]) -> int:
	var count: int = 0
	for body: Enemy in bodies:
		if is_instance_valid(body) and body.get("_target") == _field.hero:
			count += 1
	return count


## Watches for `WATCH_SECONDS` after the grace and returns, per breed, the
## frames it spent walking at, winding up on or striking the Warden.
func _watch(bodies: Array[Enemy]) -> Dictionary:
	var held: Dictionary = {}
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int((LET_GO_SECONDS + WATCH_SECONDS) * 1000.0):
		await get_tree().process_frame
		if Time.get_ticks_msec() - start < int(LET_GO_SECONDS * 1000.0):
			continue
		for body: Enemy in bodies:
			if not is_instance_valid(body) or body.is_dying():
				continue
			var state: int = int(body.get("_state"))
			if body.get("_target") == _field.hero and state in [Enemy.State.WALKING,
					Enemy.State.WINDUP, Enemy.State.STRIKE]:
				held[body.data.id] = int(held.get(body.data.id, 0)) + 1
	return held


func _clear(bodies: Array[Enemy]) -> void:
	for body: Enemy in bodies:
		if is_instance_valid(body):
			body.queue_free()
	await get_tree().process_frame


func _test_a_fallen_warden_is_let_go() -> void:
	var probe: Enemy = _field.spawn_enemy(ContentDB.enemies.values()[0] as EnemyData, 0, 1.0)
	var spot: Vector2 = probe.route_point_at(0.45)
	probe.queue_free()
	var bodies: Array[Enemy] = _surround(spot)
	for _i: int in 180:
		await get_tree().process_frame
	var engaged: int = _engaged(bodies)
	_check(engaged >= 4, "the harness needs bodies fighting the Warden before it dies: %d of %d" % [engaged, bodies.size()])
	var hero: Hero = _field.hero
	hero.health.take_damage(hero.health.current_hp + 9999.0, spot + Vector2.RIGHT * 30.0)
	_check(not hero.is_alive(), "an ordinary blow must be able to kill the Warden here")
	var held: Dictionary = await _watch(bodies)
	_check(held.is_empty(),
		"bodies kept fighting a Warden who had died (%d frames after the grace): %s"
		% [held.values().reduce(func(a: int, b: int) -> int: return a + b, 0), str(held)])
	await _clear(bodies)
	_reached.append("fallen")


func _test_a_sheltered_warden_is_let_go() -> void:
	var probe: Enemy = _field.spawn_enemy(ContentDB.enemies.values()[0] as EnemyData, 0, 1.0)
	var spot: Vector2 = probe.route_point_at(0.45)
	probe.queue_free()
	var bodies: Array[Enemy] = _surround(spot)
	for _i: int in 180:
		await get_tree().process_frame
	var hero: Hero = _field.hero
	_check(_engaged(bodies) >= 4, "the harness needs bodies fighting a living Warden: %d" % _engaged(bodies))
	hero.health.floor_hp = hero.health.max_hp
	hero.global_position = _field.town_position()
	_check(_field.inside_city(hero.global_position), "the town's own position must be inside the walls")
	var held: Dictionary = await _watch(bodies)
	_check(held.is_empty(),
		"bodies kept fighting a Warden inside the walls: %s" % str(held))
	hero.health.floor_hp = 0.0
	await _clear(bodies)
	_reached.append("sheltered")
