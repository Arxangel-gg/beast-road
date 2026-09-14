extends Node

## The performance budgets are constants, and the things they bound refuse
## to exceed them (the fifth forwarded list: "set explicit performance
## budgets ... Claude should know when a feature exceeds budget"). The wave
## director waits at the enemy cap rather than spawning past it; the road's
## wildlife stops arriving at its cap; the clocks that aggregate what crosses
## the wire are not per-frame; and the caps themselves stay inside the
## ceilings the frame was measured under.
##
##   godot --headless --path game res://tools/budget_check.tscn
##
## Frame timing is `perf_check`'s, on the release, with a real renderer.
## This gate is the cheap half: that every cap is enforced where it says it
## is, because a cap authored and read by nothing is the frame going away.

## Ceilings the frame was measured under. Raising one is a perf run, not an edit.
const ENEMY_CEILING: int = 160
const WILDLIFE_CEILING: int = 40
const FIRE_CEILING: int = 64
const ZONE_CEILING: int = 12
const SLOWEST_SYNC: float = 0.2

var _failures: PackedStringArray = []
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset()
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	for _f: int in 12:
		await get_tree().process_frame
	_field = _run.get("battlefield") as Battlefield
	_check(_field != null, "the battlefield must stand up")
	_test_the_budgets_are_inside_the_ceilings()
	if _field != null:
		await _test_the_director_waits_at_the_cap()
		await _test_the_wildlife_stops_at_the_cap()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[budget] PASS - %d checks: the caps are inside the ceilings, the director waits "
			% _checks + "at the enemy cap, and the wildlife stops at its own")
	else:
		for failure: String in _failures:
			push_error("[budget] " + failure)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


func _test_the_budgets_are_inside_the_ceilings() -> void:
	_check(Balance.BATTLEFIELD_MAX_ENEMIES <= ENEMY_CEILING,
		"BATTLEFIELD_MAX_ENEMIES %d is past the ceiling of %d the frame was measured under" % [Balance.BATTLEFIELD_MAX_ENEMIES, ENEMY_CEILING])
	_check(Balance.RIFT_MAX_ENEMIES <= Balance.BATTLEFIELD_MAX_ENEMIES
		and Balance.RAID_MAX_ENEMIES <= Balance.BATTLEFIELD_MAX_ENEMIES,
		"an arena allows more bodies than the road")
	_check(int(round(float(Balance.WILDLIFE_MAX) * Graphics.MAX_DENSITY)) <= WILDLIFE_CEILING,
		"WILDLIFE_MAX at the densest preset is past the ceiling of %d" % WILDLIFE_CEILING)
	_check(Balance.WILDFIRE_MAX_FIRES <= FIRE_CEILING, "WILDFIRE_MAX_FIRES is past the ceiling")
	_check(Balance.ZONE_MAX <= ZONE_CEILING, "ZONE_MAX is past the ceiling")
	# What crosses the wire is aggregated on a clock, never per frame.
	_check(Balance.SKY_SYNC_INTERVAL >= SLOWEST_SYNC, "the sky syncs every %.2fs, which is per-frame" % Balance.SKY_SYNC_INTERVAL)
	_check(Balance.CLIMATE_TICK >= SLOWEST_SYNC, "the climate ticks every %.2fs, which is per-frame" % Balance.CLIMATE_TICK)
	# The particle slider scales, never multiplies past the densest preset.
	_check(Graphics.scaled(100, Graphics.MAX_DENSITY) <= int(ceil(100.0 * Graphics.MAX_DENSITY)),
		"the particle slider hands out more than the densest preset allows")


## At the cap the director keeps its queue and waits; it does not spawn past
## it and it does not drop the body it was going to spawn.
func _test_the_director_waits_at_the_cap() -> void:
	var director: Node = _field.get("wave_director")
	_check(director != null, "the battlefield has a wave director")
	if director == null:
		return
	director.call("stop")
	var data: EnemyData = ContentDB.enemy("bogkin")
	while _field.enemy_count() < Balance.BATTLEFIELD_MAX_ENEMIES:
		_field.spawn_enemy(data, _field.enemy_count() % 4, 1.0)
	await get_tree().process_frame
	var at_cap: int = _field.enemy_count()
	_check(at_cap >= Balance.BATTLEFIELD_MAX_ENEMIES, "the field could not be filled to the cap (%d)" % at_cap)
	var queue: Array = director.get("_spawn_queue")
	queue.clear()
	queue.append({"lane": 0, "enemy_id": "bogkin"})
	director.set("_spawn_queue", queue)
	director.call("_spawn_next")
	await get_tree().process_frame
	_check(_field.enemy_count() == at_cap, "the director spawned past the cap (%d)" % _field.enemy_count())
	_check((director.get("_spawn_queue") as Array).size() == 1, "the director dropped the body it was waiting to spawn")
	# Room again: the same entry is spawned.
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	director.call("_spawn_next")
	await get_tree().process_frame
	_check(_field.enemy_count() == 1, "with room the director did not spawn the waiting body (%d)" % _field.enemy_count())
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		node.queue_free()
	(director.get("_spawn_queue") as Array).clear()
	await get_tree().process_frame


## The road's population stops arriving at the cap however often it is asked.
func _test_the_wildlife_stops_at_the_cap() -> void:
	var animals: Wildlife = _field.wildlife()
	_check(animals != null, "the field has wildlife")
	if animals == null:
		return
	var cap: int = int(round(float(Balance.WILDLIFE_MAX) * Graphics.foliage_scale()))
	for _i: int in cap * 12:
		animals.call("_consider_arrival")
	var living: Array = animals.get("_living")
	_check(living.size() <= cap, "%d animals on the road against a cap of %d" % [living.size(), cap])
	await get_tree().process_frame
