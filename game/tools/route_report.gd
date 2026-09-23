extends Node

## What every lane's route pool actually offers, in world units.
##
##   godot --headless --path game res://tools/route_report.tscn
##
## A report, not a gate. `Balance.ROUTE_LENGTH_MAX_RATIO` says in as many words
## that "the longest route a lane may offer" is capped "at twice the direct
## route", because a body on a longer one "arrives long after its wave is over -
## which reads as a stuck enemy, not as a flanker". That is the owner's report of
## 2026-09-22 word for word, so the first question is whether the cap describes
## the routes the game actually deals.
##
## It is enforced in `BattleGrid._finish_routes` against `_tile_length` of the
## **whole lattice walk from the fork junction**. What a body walks is the
## polyline that function then *builds*: its spawn, its way onto the road, and
## the walk from `_join_step` onward. Those are two different lengths, and this
## prints the one the body actually walks.

## Seeds to read. The authored core is byte-identical on every seed and
## `camp_side` is rolled from the layout seed, so a handful covers both sides.
const SEEDS: Array[int] = [20260922, 20260923, 20260924, 20260925, 20260926, 1, 7, 99]


func _ready() -> void:
	var worst_near: float = 0.0
	var worst_far: float = 0.0
	var over_two: int = 0
	var total: int = 0
	for seed_value: int in SEEDS:
		var grid := BattleGrid.new(seed_value)
		print("")
		print("=== seed %d  camp_side=%d ===" % [seed_value, grid.camp_side])
		for lane: int in Balance.LANE_COUNT:
			var counts: Array = _say(grid, lane, "near", grid.routes)
			over_two += int(counts[0])
			total += int(counts[1])
			worst_near = maxf(worst_near, float(counts[2]))
			var far: Array = _say(grid, lane, "far ", grid.far_routes)
			over_two += int(far[0])
			total += int(far[1])
			worst_far = maxf(worst_far, float(far[2]))
	print("")
	print("[routes] worst near ratio %.2fx, worst far ratio %.2fx; %d of %d routes exceed "
		% [worst_near, worst_far, over_two, total]
		+ "ROUTE_LENGTH_MAX_RATIO (%.1f)" % Balance.ROUTE_LENGTH_MAX_RATIO)
	get_tree().quit(0)


## One lane's pool: every route's world length, its ratio to the shortest on
## offer, and how often the weighting actually deals it.
func _say(grid: BattleGrid, lane: int, tag: String, pool: Array) -> Array:
	if lane >= pool.size():
		return [0, 0, 0.0]
	var options: Array = pool[lane] as Array
	if options.is_empty():
		print("  lane %d %s: no routes" % [lane, tag])
		return [0, 0, 0.0]
	var lengths: Array[float] = []
	var shortest: float = INF
	for path: Variant in options:
		var length: float = _length(path as PackedVector2Array)
		lengths.append(length)
		shortest = minf(shortest, length)
	# The same weighting `route_for` uses, so the odds printed are the odds run.
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for length: float in lengths:
		var weight: float = pow(maxf(length, 1.0), -Balance.ROUTE_LENGTH_BIAS)
		weights.append(weight)
		total_weight += weight
	var over: int = 0
	var worst: float = 0.0
	var line: PackedStringArray = []
	for index: int in lengths.size():
		var ratio: float = lengths[index] / maxf(shortest, 1.0)
		worst = maxf(worst, ratio)
		var odds: float = weights[index] / maxf(total_weight, 0.0001)
		if ratio > Balance.ROUTE_LENGTH_MAX_RATIO + 0.001:
			over += 1
		line.append("%.0fu %.2fx %s%.1f%%" % [lengths[index], ratio,
			"OVER " if ratio > Balance.ROUTE_LENGTH_MAX_RATIO + 0.001 else "", odds * 100.0])
	# Seconds of walking for an ordinary body, because that is the unit the
	# complaint is in: a wave is over and one body is still coming.
	var longest: float = 0.0
	for length: float in lengths:
		longest = maxf(longest, length)
	print("  lane %d %s: %d routes, %.0f-%.0fu (worst %.2fx, %.0fs at 40u/s) | %s" % [
		lane, tag, options.size(), shortest, longest, worst, longest / 40.0,
		", ".join(line)])
	return [over, lengths.size(), worst]


static func _length(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for index: int in path.size() - 1:
		total += path[index].distance_to(path[index + 1])
	return total
