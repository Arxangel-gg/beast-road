extends SceneTree

## Verifies the battlefield grid and road network before anything is built on it.
##
##   godot --headless --path game --script res://tools/grid_check.gd
##
## Pure geometry, so this runs without a scene, an autoload or a viewport. Every
## later piece of the grid work — placement, fusion adjacency, enemy pathing —
## assumes these properties hold, and each is far more expensive to debug once
## something is standing on top of it.
##
## Rewritten for the authored layout. The old checks asserted the shape of four
## procedural U-bends: that each road doubled back, that it was 25% longer than
## the straight line, that its bend enclosed a pocket. None of that describes the
## map any more, and a check that describes the last design is worse than no
## check, because it goes green on a build it never looked at.
##
## What replaces it is the property the authored map actually has to satisfy:
## every route is a real way in, made of road the whole distance.

var _failures: PackedStringArray = []


func _init() -> void:
	var grid := BattleGrid.new()

	_check(BattleGrid.SIZE == 45 and is_equal_approx(BattleGrid.TILE, 64.0),
		"the grid must be 45x45 at 64 units")

	# The town sits at the origin, which is where every existing node expects it.
	var centre: Vector2i = BattleGrid.world_to_tile(Vector2.ZERO)
	_check(grid.cell_at(centre) == BattleGrid.Cell.TOWN,
		"the origin must be town, got %d" % grid.cell_at(centre))
	_check(not grid.footprint_is_open(centre), "nothing may be built on the town")

	# The outer ring is closed to building but must not have eaten the entrances.
	_check(not grid.footprint_is_open(Vector2i(0, 12)),
		"nothing may be built on the outermost ring")
	var spawn_tiles: int = 0
	for i: int in BattleGrid.SIZE:
		for tile: Vector2i in [Vector2i(i, 0), Vector2i(i, BattleGrid.SIZE - 1),
				Vector2i(0, i), Vector2i(BattleGrid.SIZE - 1, i)]:
			if grid.cell_at(tile) == BattleGrid.Cell.ROAD:
				spawn_tiles += 1
	_check(spawn_tiles == 12,
		"sealing the border must leave the twelve spawn tiles as road, found %d" % spawn_tiles)

	_check(grid.lane_paths.size() == Balance.LANE_COUNT,
		"every lane needs a road, got %d" % grid.lane_paths.size())

	# The point of the authored map: more than one way in from each spawn.
	var shapes: Dictionary = {}
	for lane: int in Balance.LANE_COUNT:
		var options: Array = grid.routes[lane]
		_check(options.size() >= 2,
			"lane %d offers %d routes - the forks are the whole point of the map"
				% [lane, options.size()])
		shapes[options.size()] = true

		for index: int in options.size():
			var route: PackedVector2Array = options[index]
			_check(route.size() >= 3,
				"lane %d route %d is only %d points" % [lane, index, route.size()])
			_check(route[route.size() - 1].is_equal_approx(Vector2.ZERO),
				"lane %d route %d must end at the town, ends at %s"
					% [lane, index, route[route.size() - 1]])

			# Every step of every route has to be road the whole way. This is the
			# check that matters: the lattice is derived rather than authored, and
			# a centre line found one tile off would still produce routes that
			# look plausible, connect end to end, and walk enemies through the
			# buildable ground beside the road.
			for i: int in range(1, route.size() - 1):
				var tile: Vector2i = BattleGrid.world_to_tile(route[i])
				var cell: int = grid.cell_at(tile)
				if cell != BattleGrid.Cell.ROAD and cell != BattleGrid.Cell.TOWN:
					_check(false, "lane %d route %d turns at %s, which is not road"
						% [lane, index, tile])
					break
			for i: int in range(1, route.size() - 2):
				if not _corridor_is_road(grid, route[i], route[i + 1]):
					_check(false, "lane %d route %d crosses open ground between %s and %s"
						% [lane, index, route[i], route[i + 1]])
					break

	# Four roads cut from one shape rotated: they must offer the same choices, or
	# one spawn is quietly harder than another.
	_check(shapes.size() == 1,
		"the four lanes offer different route counts - the map is not symmetric")

	# Distance-along has to fall toward the gate, or lane pressure ranks a
	# besieger behind a straggler.
	for lane: int in Balance.LANE_COUNT:
		var path: PackedVector2Array = grid.lane_paths[lane]
		_check(grid.distance_to_town_along(lane, path[path.size() - 2] * 0.5)
			< grid.distance_to_town_along(lane, path[0]),
			"lane %d: distance-to-town must shrink toward the gate" % lane)

	# Two towers side by side is the layout's stated reason for four-tile gaps.
	# Checked as a property of the map rather than taken on trust.
	var pairs: int = 0
	for y: int in BattleGrid.SIZE - BattleGrid.FOOTPRINT:
		for x: int in BattleGrid.SIZE - BattleGrid.FOOTPRINT * 2:
			if grid.footprint_is_open(Vector2i(x, y)) \
					and grid.footprint_is_open(Vector2i(x + BattleGrid.FOOTPRINT, y)):
				pairs += 1
	_check(pairs >= 200,
		"only %d places take two towers side by side - the gaps are too narrow" % pairs)

	for lane: int in Balance.LANE_COUNT:
		var pocket: Vector2i = BattleGrid.world_to_tile(grid.lane_pocket_centre(lane))
		var open: int = 0
		for dx: int in range(-3, 4):
			for dy: int in range(-3, 4):
				if grid.cell_at(pocket + Vector2i(dx, dy)) == BattleGrid.Cell.OPEN:
					open += 1
		_check(open >= 16, "lane %d pocket has %d open tiles, needs 16 for four towers"
			% [lane, open])

	var open_total: int = 0
	for tile_index: int in grid.cells.size():
		if grid.cells[tile_index] == BattleGrid.Cell.OPEN:
			open_total += 1
	var fraction: float = float(open_total) / float(BattleGrid.SIZE * BattleGrid.SIZE)
	_check(fraction > 0.45 and fraction < 0.9,
		"open ground is %.0f%% of the field - roads are either invisible or eating it"
			% (fraction * 100.0))

	var lengths: Array[float] = []
	for route: Variant in grid.routes[0]:
		lengths.append(_length(route))
	print("[grid] %d open tiles (%.0f%%), %d places for two towers abreast"
		% [open_total, fraction * 100.0, pairs])
	print("[grid] lane 0 offers %d routes, %.0f to %.0f units"
		% [lengths.size(), lengths[0], lengths[lengths.size() - 1]])

	for problem: String in _failures:
		push_error("[grid] " + problem)
	print("[grid] %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)


## Whether the straight run between two waypoints is road for its whole length.
func _corridor_is_road(grid: BattleGrid, from: Vector2, to: Vector2) -> bool:
	var steps: int = int(ceil(from.distance_to(to) / (BattleGrid.TILE * 0.5)))
	for step: int in steps + 1:
		var at: Vector2 = from.lerp(to, float(step) / float(maxi(steps, 1)))
		var cell: int = grid.cell_at(BattleGrid.world_to_tile(at))
		if cell != BattleGrid.Cell.ROAD and cell != BattleGrid.Cell.TOWN:
			return false
	return true


static func _length(route: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in route.size() - 1:
		total += route[i].distance_to(route[i + 1])
	return total


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
