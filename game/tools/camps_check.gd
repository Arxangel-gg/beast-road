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

	_test_the_camps_escalate()
	var field: Battlefield = run.battlefield
	var camps: Camps = field.camps()
	_test_an_ambush_walks_inward(field.grid)
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
		_test_the_ambush_ground(grid, lane)


## While the fork is closed a lane's bodies come out of the trees either side
## of the corridor, just outside the core, and nobody sees them arrive.
##
## Owner brief, 2026-09-14. Four things make it an ambush rather than a spawn
## in a new place, and each is held: the two points are on open ground, not
## road; they are outside the core the fog primes and outside the town's own
## sight, so a fresh run does not show them; the way in touches the corridor
## before the core, so the body walks *onto* the road; and there is one on
## each side, so a wave comes out of both woods.
func _test_the_ambush_ground(grid: BattleGrid, lane: int) -> void:
	var sides: Array = grid.active_spawn_points(lane)
	_check(sides.size() == 2, "lane %d: a closed fork ambushes from both sides (%d)"
		% [lane, sides.size()])
	for spawn: Variant in sides:
		var at: Vector2 = spawn as Vector2
		var tile: Vector2i = BattleGrid.world_to_tile(at)
		_check(grid.cell_at(tile) == BattleGrid.Cell.OPEN,
			"lane %d: the ambush ground at %s is not open ground (cell %d)"
				% [lane, str(tile), grid.cell_at(tile)])
		_check(BattleGrid.beyond_core(at),
			"lane %d: the ambush ground at %s is inside the core the fog primes"
				% [lane, str(at)])
		_check(at.length() > Balance.FOG_VISION_TOWN,
			"lane %d: the ambush ground at %.0f is inside the town's sight of %.0f"
				% [lane, at.length(), Balance.FOG_VISION_TOWN])
	# Every route from either side reaches the corridor before the core.
	var onto: Vector2 = grid.spawn_points[lane] as Vector2
	_check(grid.cell_at(BattleGrid.world_to_tile(onto)) == BattleGrid.Cell.ROAD,
		"lane %d: the point the ambush steps onto is not road" % lane)
	for path: Variant in grid.routes[lane]:
		var route: PackedVector2Array = path as PackedVector2Array
		_check(route.size() >= 3 and route[1].distance_to(onto) < 1.0,
			"lane %d: a route from the trees does not step onto the corridor first" % lane)
	# And the far spawns stand inside the map, on a cell the fog knows.
	for spawn: Variant in grid.far_spawn_points[lane]:
		var far: Vector2 = spawn as Vector2
		var tile: Vector2i = BattleGrid.world_to_tile(far)
		_check(tile.x >= 0 and tile.y >= 0 and tile.x < BattleGrid.SIZE and tile.y < BattleGrid.SIZE,
			"lane %d: far spawn %s is outside the grid, where the fog's veil ends and "
				% [lane, str(tile)] + "a body straddles its edge")


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




## **The three camps are three different fights.**
##
## Owner, 2026-09-15: "second camp should have some unique camp only harder
## mobs, and third camp should as well, but also have a higher chance of also
## having a rarer epic camp mob that is a miniboss of its own. Sometimes that
## might even be a dragon."
##
## Four things have to hold and none of them is visible in one camp:
##
## - **The first camp is the region's own**, so a player meets a camp against
##   bodies they already know before one full of strangers.
## - **The second and third are mostly strangers**, which is what makes the
##   detour its own fight rather than a lane with more health.
## - **A lord is rare at the second camp and common at the war camp**, and never
##   certain anywhere - a fixture is not a miniboss.
## - **A camp lord never reaches the road.** The category is the only thing
##   keeping it out of the wave roll, so a lord listed in a region's
##   `enemy_ids` would walk up the lane as rank and file.
func _test_the_camps_escalate() -> void:
	var lords: Array[EnemyData] = ContentDB.enemies_of_category(
		EnemyData.Category.CAMP_LORD)
	var strangers: Array[EnemyData] = ContentDB.enemies_of_category(
		EnemyData.Category.CAMP_BREED)
	_check(lords.size() >= 4,
		"a war camp needs lords to draw from: %d authored" % lords.size())
	_check(not strangers.is_empty(),
		"the harder camps need camp-only breeds: %d authored" % strangers.size())

	# **Never on the road.** Checked against every region rather than the
	# current one: a lord added to one terrain's list is a dragon in a wave.
	for value: Variant in ContentDB.terrains.values():
		var region := value as TerrainData
		if region == null:
			continue
		for id: String in region.enemy_ids:
			var breed: EnemyData = ContentDB.enemy(id)
			if breed == null:
				continue
			_check(breed.category != EnemyData.Category.CAMP_LORD,
				"%s lists the camp lord %s, which would walk up the lane"
					% [region.id, id])
			_check(breed.category != EnemyData.Category.CAMP_BREED,
				"%s lists the camp-only breed %s" % [region.id, id])

	# **And a camp dragon is never a companion** (owner's ruling in the same
	# breath: wild dragons are bondable, camp ones are not). It falls out of the
	# types - bonding reads `WildlifeData` - and this is what would notice if a
	# wild roster were ever given one of these ids.
	for lord: EnemyData in lords:
		_check(not ContentDB.wildlife_kinds.has(lord.id),
			("%s is a camp lord and also a wildlife kind, so killing one in a "
				+ "camp would credit the collection") % lord.id)

	# The escalation itself, read off the constants the roll uses.
	_check(is_zero_approx(Balance.CAMP_STRANGER_SHARE[BattleGrid.CampTier.EASY]),
		"the first camp must be the region's own bodies")
	_check(is_zero_approx(Balance.CAMP_LORD_CHANCE[BattleGrid.CampTier.EASY]),
		"and must never hold a lord")
	_check(Balance.CAMP_STRANGER_SHARE[BattleGrid.CampTier.HARD] > 0.2
			and Balance.CAMP_STRANGER_SHARE[BattleGrid.CampTier.BARON]
				>= Balance.CAMP_STRANGER_SHARE[BattleGrid.CampTier.HARD],
		"strangers must arrive at the second camp and not thin out at the third")
	_check(Balance.CAMP_LORD_CHANCE[BattleGrid.CampTier.BARON]
			> Balance.CAMP_LORD_CHANCE[BattleGrid.CampTier.HARD],
		"a lord must be likelier at the war camp than at the second")
	_check(Balance.CAMP_LORD_CHANCE[BattleGrid.CampTier.BARON] < 1.0,
		"and never certain: a fixture is not a miniboss")

	# A lord is a set piece and a camp breed is not - the distinction four
	# separate `!= BREED` expressions used to get wrong.
	for lord: EnemyData in lords:
		_check(lord.is_promoted(), "%s must count as promoted" % lord.id)
	for stranger: EnemyData in strangers:
		_check(not stranger.is_promoted(),
			("%s is rank and file that lives in a camp; counting it promoted "
				+ "pays it elite loot") % stranger.id)




## **An ambusher walks in, and never back out first.**
##
## Owner, 2026-09-15: wave enemies "spawn at the correct location between camp 1
## and closer to the central square ... but then they head to the fork joint
## where camp 3 is before heading back to the central square."
##
## They did, and it was every closed-fork wave in the game. `_entry_node` finds
## the lattice node *furthest out* along a lane, so every route is written from
## the fork junction inward - correct for a body that enters at the fork, and
## a round trip for one that ambushes from the trees beside the core. The route
## was laid whole behind the ambush point, so the body crossed to the corridor
## and then walked the entire road outward before turning round.
##
## **Measured as a property of the path rather than by watching a body**: from
## the moment it steps onto the road, nothing on a closed-fork route may be
## further from the town than the point it joined at. A route that weaves is
## fine; one that goes back out to the edge is the bug.
func _test_an_ambush_walks_inward(grid: BattleGrid) -> void:
	if grid == null:
		_check(false, "the route test needs a grid")
		return
	var worst: float = 0.0
	var worst_lane: int = -1
	var counted: int = 0
	for lane: int in grid.routes.size():
		if lane < grid.fork_open.size() and grid.fork_open[lane]:
			continue
		for value: Variant in (grid.routes[lane] as Array):
			var route: PackedVector2Array = value
			if route.size() < 3:
				continue
			counted += 1
			# Point 0 is the spawn in the trees and point 1 is the corridor it
			# steps onto; the road proper starts after that.
			var joined: float = route[1].length()
			for index: int in range(2, route.size()):
				var out: float = route[index].length() - joined
				if out > worst:
					worst = out
					worst_lane = lane
	_check(counted > 0, "there must be closed-fork routes to measure")
	# A tile of slack: the lattice does not put a node exactly on the corridor.
	var slack: float = float(BattleGrid.TILE) * 1.5
	_check(worst <= slack,
		("an ambusher on lane %d walks %.0f further out than where it joined "
			+ "the road before turning back - the route is laid from the fork "
			+ "rather than from the corridor") % [worst_lane, worst])


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[camps] " + message)
