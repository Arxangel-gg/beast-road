extends Node

## No body arrives long after its wave, and a camp is not a wave.
##
##   godot --headless --path game res://tools/route_length_check.tscn
##
## Owner report, 2026-09-22: *"Not all enemies that have spawned go to the city
## base! Some seem to go off elsewhere or get lost preventing the wave from
## completing!"* Traced, nothing was lost: they were walking legitimate routes
## up to 2688 units longer than the ones their wave-mates drew - 67 seconds at an
## ordinary walk - and a wave cannot close until its last body resolves.
##
## **The two halves of that, and both are gated here.**
##
## - **The pool.** `ROUTE_LENGTH_MAX_RATIO` is a ratio, and a ratio says nothing
##   about how long anybody walks. When the outskirts grew on 2026-09-14 every
##   route got longer while the ratio between them did not move, so the cap went
##   on passing a pool it no longer described. `ROUTE_LATE_ARRIVAL_SECONDS` is
##   the absolute bound, and it is held on the polyline a body actually walks -
##   the filter used to measure the whole lattice walk from the fork junction,
##   which is a different length from the route it hands back.
## - **The rescue.** When a body genuinely is stuck, `WaveDirector`'s watchdog is
##   supposed to end the wave after `WAVE_STALL_TIMEOUT`. Its two readings -
##   `nearest_enemy_distance` and `wave_activity_checksum` - counted camp
##   bodies, which `enemy_count` deliberately does not. A camp regenerating on
##   the outskirts, which is what a camp does the moment it is left alone, reset
##   the stall clock every frame and disarmed the rescue completely.
##
## **And a countervailing bound**, because the cheap way to pass the first half
## is to leave one route per lane - which would make the forks, the two ambush
## sides and the whole shape of the map pointless. A lane must still offer more
## than one way in.

## Seeds to read. The authored core is identical on every seed and `camp_side`
## is rolled from the layout seed, so a handful covers both mirrorings.
const SEEDS: Array[int] = [20260922, 20260923, 1, 77, 4242]
## How finely `route_for`'s roll space is walked. The weighting maps a roll to
## an option, so this must be fine enough to reach the longest one on offer.
const ROLLS: int = 400

var _failures: int = 0
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null
## Which tests reached their own last line. A GDScript runtime error stops the
## function it is in and nothing else, so a test that aborts halfway reads
## exactly like one that passed - which `hold_check` was caught by once.
var _reached: Dictionary = {}


func _ready() -> void:
	MetaState.hold_saves()
	_test_every_dealt_route_arrives_with_its_wave()
	_test_a_lane_still_offers_more_than_one_way_in()
	await _test_a_camp_is_not_a_wave()
	for stage: String in ["dealt", "variety", "camps"]:
		_check(_reached.has(stage),
			("'%s' never reached its end - it aborted partway, and every check "
				+ "it had not made yet is a check nobody made") % stage)
	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	MetaState.resume_saves()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 12:
		await get_tree().process_frame
	if _failures == 0:
		print(("[routes] PASS - %d checks: every route a lane can deal arrives "
			+ "within %.0fs of the shortest, every lane still offers more than "
			+ "one, and a camp body holds no wave open")
			% [_checks, Balance.ROUTE_LATE_ARRIVAL_SECONDS])
	else:
		push_error("[routes] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[routes] " + why)


static func _length(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for index: int in path.size() - 1:
		total += path[index].distance_to(path[index + 1])
	return total


## **Driven through `route_for`, not read off the pool.** The pool is where the
## bound is applied and `route_for` is the door `Battlefield.lane_route` opens,
## so a pool that is bounded while the spawner draws from somewhere else would
## pass a check that read the arrays - the same distinction that let a set-piece
## label pass while nothing called it.
func _test_every_dealt_route_arrives_with_its_wave() -> void:
	var budget: float = Balance.ROUTE_LATE_ARRIVAL_SECONDS * Balance.ROUTE_REFERENCE_WALK
	for seed_value: int in SEEDS:
		var grid := BattleGrid.new(seed_value)
		for lane: int in Balance.LANE_COUNT:
			for fork: bool in [false, true]:
				grid.set_fork_open(lane, fork)
				var shortest: float = INF
				var longest: float = 0.0
				var dealt: int = 0
				for step: int in ROLLS:
					var path: PackedVector2Array = grid.route_for(lane,
						float(step) / float(ROLLS))
					if path.size() < 2:
						continue
					dealt += 1
					var length: float = _length(path)
					shortest = minf(shortest, length)
					longest = maxf(longest, length)
				_check(dealt > 0,
					"seed %d lane %d fork=%s deals no route at all"
						% [seed_value, lane, fork])
				if dealt == 0 or not is_finite(shortest):
					continue
				_check(longest - shortest <= budget + 1.0,
					("seed %d lane %d fork=%s can deal a route %.0f units behind "
						+ "its shortest - %.0fs at %.0f units a second, against a "
						+ "budget of %.0fs. A wave waits for its last body.")
						% [seed_value, lane, fork, longest - shortest,
							(longest - shortest) / Balance.ROUTE_REFERENCE_WALK,
							Balance.ROUTE_REFERENCE_WALK,
							Balance.ROUTE_LATE_ARRIVAL_SECONDS])
				_check(longest <= shortest * Balance.ROUTE_LENGTH_MAX_RATIO + 1.0,
					("seed %d lane %d fork=%s can deal a route %.2fx its shortest, "
						+ "against a ceiling of %.2fx")
						% [seed_value, lane, fork, longest / maxf(shortest, 1.0),
							Balance.ROUTE_LENGTH_MAX_RATIO])
	_reached["dealt"] = true


## The bound must not be paid for by deleting the map's shape.
##
## One route a lane is trivially inside every ceiling above and is a road with
## no decision on it: the two ambush sides would arrive identically and the
## flanking the corridors exist for would stop happening.
func _test_a_lane_still_offers_more_than_one_way_in() -> void:
	for seed_value: int in SEEDS:
		var grid := BattleGrid.new(seed_value)
		for lane: int in Balance.LANE_COUNT:
			for pool: Array in [grid.routes, grid.far_routes]:
				if lane >= pool.size():
					continue
				var options: Array = pool[lane] as Array
				_check(options.size() >= 2,
					("seed %d lane %d offers %d way(s) in - a lane with one road "
						+ "has no flank at all") % [seed_value, lane, options.size()])
				# **Distinct roads, not distinct routes**, and the difference is
				# what the first cut of this check missed. Every shape is laid
				# twice, once from each ambush side, so a pool holding one road
				# still holds two routes and still holds two *different* arrays -
				# they differ in their first point and nowhere else. Counting
				# either passed a budget tuned down to a single way in, which is
				# precisely the shortcut this test exists to refuse.
				#
				# A road is different if it takes a different length or arrives at
				# a different gate. Length is snapped, because two sides of one
				# road are symmetric and only float noise separates them.
				var lengths: Dictionary = {}
				var gates: Dictionary = {}
				for path: Variant in options:
					var line: PackedVector2Array = path as PackedVector2Array
					if line.size() < 2:
						continue
					lengths[snappedi(int(_length(line)), 32)] = true
					gates[str(line[line.size() - 1])] = true
				_check(lengths.size() >= 2 or gates.size() >= 2,
					("seed %d lane %d offers %d routes that are all the same road: "
						+ "%d distinct length(s), %d distinct gate(s). The bound on "
						+ "how late a body may arrive must not be paid for by "
						+ "leaving the lane one way in")
						% [seed_value, lane, options.size(), lengths.size(),
							gates.size()])
	_reached["variety"] = true


## **A camp is not a wave**, and the three things that decide whether a wave has
## resolved must all agree about that.
##
## Driven rather than read: the fault was that `enemy_count` excluded camp
## bodies while the watchdog's own two readings did not, so a test that asked
## `holds_the_wave` directly would have passed on the build that shipped it.
func _test_a_camp_is_not_a_wave() -> void:
	RunState.reset(false, 20260922)
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	_check(_field != null, "the harness could not stand a battlefield up")
	if _field == null:
		return
	RunState.set_phase(RunState.Phase.PREPARATION)

	var breed: EnemyData = _a_breed()
	_check(breed != null, "no breed to stand up")
	if breed == null:
		return
	var count_before: int = _field.enemy_count()
	var nearest_before: float = _field.nearest_enemy_distance()
	var checksum_before: float = _field.wave_activity_checksum()

	# Standing right on the town, which is the harshest placement: a camp body
	# that counted would set the closest approach every later body is measured
	# against, as well as holding the wave open.
	var raider: Enemy = _field.spawn_enemy(breed, 0, 1.0)
	_check(raider != null, "the harness could not spawn a body")
	if raider == null:
		return
	raider.make_camp_mob(_field.town_position() + Vector2(120.0, 0.0), 400.0)
	raider.global_position = _field.town_position() + Vector2(120.0, 0.0)
	await get_tree().process_frame

	_check(raider.is_camp_mob(), "the harness did not make a camp body")
	_check(_field.enemy_count() == count_before,
		("a camp body moved the wave count %d -> %d; a wave would wait on a camp "
			+ "nobody has visited") % [count_before, _field.enemy_count()])
	_check(is_equal_approx(_field.nearest_enemy_distance(), nearest_before),
		("a camp body standing 120 units from the wall set the wave's nearest "
			+ "approach to %.0f (was %.0f) - the watchdog then measures every "
			+ "real body against ground a camp happened to stand on")
			% [_field.nearest_enemy_distance(), nearest_before])

	# The half that disarmed the rescue: a camp heals itself the moment it is
	# left alone, and any change here resets the stall clock.
	var health: Health = Health.of(raider)
	_check(health != null, "the camp body has no health to move")
	if health != null:
		health.current_hp = maxf(health.max_hp * 0.4, 1.0)
		_check(is_equal_approx(_field.wave_activity_checksum(), checksum_before),
			("a camp body's health moved the wave's activity checksum %.1f -> "
				+ "%.1f. A camp regenerating on the outskirts resets the stall "
				+ "clock every frame, so the rescue after %.0fs never fires and a "
				+ "straggler holds the road open for ever")
				% [checksum_before, _field.wave_activity_checksum(),
					Balance.WAVE_STALL_TIMEOUT])
		_check(not _field.living_enemy_summary().contains(breed.id),
			("the stall report names a camp body among the bodies keeping the "
				+ "wave open: %s") % _field.living_enemy_summary())

	# **And the rescue, when it fires, may only resolve what was holding the
	# wave.** `resolve_stalled_wave` walked the whole group and killed it through
	# `Health.kill`, which is the ordinary death - so a watchdog firing razed
	# every camp on the outskirts and paid full spoils, experience, loot and gear
	# for each one. With no wave standing it must do nothing at all.
	var camps_before: int = _camp_bodies()
	var resolved: int = _field.resolve_stalled_wave()
	_check(resolved == 0,
		("the stall rescue resolved %d bodies with no wave on the road") % resolved)
	_check(_camp_bodies() == camps_before,
		("the stall rescue razed %d of %d camp bodies and paid the player for "
			+ "them") % [camps_before - _camp_bodies(), camps_before])
	_reached["camps"] = true


func _camp_bodies() -> int:
	var total: int = 0
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dying() \
				and enemy.is_camp_mob():
			total += 1
	return total


func _a_breed() -> EnemyData:
	for one: EnemyData in ContentDB.enemies.values():
		if one != null and one.category == EnemyData.Category.BREED:
			return one
	return null
