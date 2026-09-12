extends Node

## The camps on the outskirts, and the forks they open (owner brief,
## 2026-09-12).
##
## What this holds, driven through the real battlefield:
##
## - every road has an outer camp, an inner camp and a sleeping war camp,
##   with bodies in camp mode that do not march on the town, and a barrier
##   across each of its two far legs;
## - razing both camps of a road opens its fork: the barriers fall, the war
##   camp wakes, and the road's routes now come from the two far spawns;
## - a razed camp stands again after its clock, and razing the war camp
##   digs a dungeon mouth on its ground and rests it until the dungeon
##   closes.

var _failures: int = 0
var _checked: int = 0
var _forks: Array[int] = []
var _near_start: Dictionary = {}
var _war_camps: Array = []


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	RunState.reset(false, 20260912)
	GameDirector.run_active = true
	EventBus.fork_opened.connect(func(lane: int) -> void: _forks.append(lane))
	EventBus.war_camp_razed.connect(func(lane: int, at: Vector2) -> void: _war_camps.append([lane, at]))
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame

	var field: Battlefield = run.battlefield
	var camps: Camps = field.camps()
	var grid: BattleGrid = field.grid
	_check(camps != null and grid != null, "the battlefield has camps and a grid")
	if camps != null and grid != null:
		_test_the_camps_stand(camps, grid)
		await _test_a_fork_opens(camps, grid, field)
		await _test_the_war_camp(camps, grid, field)

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	Sfx.stop_immediately()
	GameDirector.run_active = false
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[camps] FAIL - %d of %d" % [_failures, _checked])
		get_tree().quit(1)
		return
	print("[camps] PASS - %d checks: the camps, the fork, the respawn and the war camp" % _checked)
	get_tree().quit(0)


func _test_the_camps_stand(camps: Camps, grid: BattleGrid) -> void:
	_check(camps.site_count() == Balance.LANE_COUNT * 3, "three camps a road (%d)" % camps.site_count())
	for lane: int in Balance.LANE_COUNT:
		_check(camps.state_of(lane, BattleGrid.CampTier.EASY) == Camps.State.ALIVE, "lane %d: the outer camp stands" % lane)
		_check(camps.state_of(lane, BattleGrid.CampTier.HARD) == Camps.State.ALIVE, "lane %d: the inner camp stands" % lane)
		_check(camps.state_of(lane, BattleGrid.CampTier.BARON) == Camps.State.LOCKED, "lane %d: the war camp sleeps" % lane)
		_check(camps.barrier_count(lane) == 2, "lane %d: both far legs are barred" % lane)
		_check(not grid.fork_open[lane], "lane %d: the fork is closed" % lane)
		var mobs: Array = camps.mobs_of(lane, BattleGrid.CampTier.EASY)
		_check(mobs.size() >= Balance.CAMP_MOBS_MIN[BattleGrid.CampTier.EASY], "lane %d: the outer camp has bodies (%d)" % [lane, mobs.size()])
		var all_camp: bool = not mobs.is_empty()
		for mob: Variant in mobs:
			var enemy := mob as Enemy
			if enemy == null or not enemy.is_camp_mob():
				all_camp = false
		_check(all_camp, "lane %d: every camp body is in camp mode, off the road" % lane)
		_check(camps.mobs_of(lane, BattleGrid.CampTier.BARON).is_empty(), "lane %d: a sleeping war camp has no bodies" % lane)
		var near: PackedVector2Array = grid.route_for(lane, 0.3)
		_check(near.size() >= 2 and BattleGrid.beyond_core(near[0]),
			"lane %d: the road starts on the outskirts" % lane)
		_near_start[lane] = near[0].length() if near.size() >= 1 else 0.0


func _test_a_fork_opens(camps: Camps, grid: BattleGrid, field: Battlefield) -> void:
	var lane: int = 0
	_fell(camps.mobs_of(lane, BattleGrid.CampTier.EASY))
	camps._process(0.1)
	_check(camps.state_of(lane, BattleGrid.CampTier.EASY) == Camps.State.RESPAWNING, "the outer camp razed rests")
	_check(not grid.fork_open[lane] and camps.barrier_count(lane) == 2, "one camp razed does not open the fork")
	_fell(camps.mobs_of(lane, BattleGrid.CampTier.HARD))
	camps._process(0.1)
	_check(_forks == [lane], "both camps razed open the fork: %s" % str(_forks))
	_check(grid.fork_open[lane] and RunState.forks_open[lane], "the grid and the run both know the fork is open")
	_check(camps.barrier_count(lane) == 0, "the barriers fall")
	_check(camps.state_of(lane, BattleGrid.CampTier.BARON) == Camps.State.ALIVE, "the war camp wakes")
	_check(not camps.mobs_of(lane, BattleGrid.CampTier.BARON).is_empty(), "with bodies")
	var far: PackedVector2Array = grid.route_for(lane, 0.3)
	_check(far.size() >= 2 and far[0].length() > float(_near_start.get(lane, 0.0)) + 100.0,
		"with the fork open, the road starts at a far spawn (%.0f beyond %.0f)" % [
			far[0].length() if far.size() >= 1 else 0.0, float(_near_start.get(lane, 0.0))])
	_check(grid.active_spawn_points(lane).size() >= 2, "an open fork has two spawns")
	_check(MetaState.camps_razed >= 2, "the statistic counts razed camps")
	# The outer camp stands again after its clock.
	camps._process(Balance.CAMP_RESPAWN_SECONDS[BattleGrid.CampTier.EASY] + 1.0)
	_check(camps.state_of(lane, BattleGrid.CampTier.EASY) == Camps.State.ALIVE, "the outer camp stands again")
	_check(not camps.mobs_of(lane, BattleGrid.CampTier.EASY).is_empty(), "with new bodies")
	_check(grid.fork_open[lane], "and the fork stays open")
	await get_tree().process_frame


func _test_the_war_camp(camps: Camps, grid: BattleGrid, field: Battlefield) -> void:
	var lane: int = 0
	var gates: RiftGates = field.rift_gates()
	var before: int = gates.count() if gates != null and gates.has_method("count") else -1
	_fell(camps.mobs_of(lane, BattleGrid.CampTier.BARON))
	camps._process(0.1)
	_check(camps.state_of(lane, BattleGrid.CampTier.BARON) == Camps.State.RAZED, "the war camp razed stays down")
	_check(_war_camps.size() == 1 and int(_war_camps[0][0]) == lane, "and says so")
	if before >= 0:
		_check(gates.count() == before + 1, "a dungeon mouth opens on its ground")
	_check(MetaState.war_camps_razed >= 1, "the statistic counts it")
	camps._process(Balance.CAMP_RESPAWN_SECONDS[BattleGrid.CampTier.BARON] * 2.0)
	_check(camps.state_of(lane, BattleGrid.CampTier.BARON) == Camps.State.RAZED, "it does not stand while the dungeon is open")
	EventBus.rift_ended.emit({"kind": 1, "stages": 1})
	_check(camps.state_of(lane, BattleGrid.CampTier.BARON) == Camps.State.RESPAWNING, "the dungeon closing starts its clock")
	camps._process(Balance.CAMP_RESPAWN_SECONDS[BattleGrid.CampTier.BARON] + Balance.CAMP_BARON_DUNGEON_GRACE + 1.0)
	_check(camps.state_of(lane, BattleGrid.CampTier.BARON) == Camps.State.ALIVE, "and it stands again after")
	await get_tree().process_frame


## The bodies are gone. Freed rather than damaged: what the camp reads is
## that nobody is left, however they went.
func _fell(mobs: Array) -> void:
	for mob: Variant in mobs.duplicate():
		var enemy := mob as Enemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		var parent: Node = enemy.get_parent()
		if parent != null:
			parent.remove_child(enemy)
		enemy.free()


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[camps] " + message)
