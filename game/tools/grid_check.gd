extends SceneTree

## Verifies the battlefield grid and road geometry before anything is built on it.
##
##   godot --headless --path game --script res://tools/grid_check.gd
##
## Pure geometry, so this runs without a scene, an autoload or a viewport. Every
## later piece of the grid work - placement, fusion adjacency, enemy pathing -
## assumes these properties hold, and each is far more expensive to debug once
## something is standing on top of it.

var _failures: PackedStringArray = []


func _init() -> void:
	var grid := BattleGrid.new()

	_check(BattleGrid.SIZE == 30 and is_equal_approx(BattleGrid.TILE, 64.0),
		"the grid must be 30x30 at 64 units")

	# Round-tripping is the contract the whole coordinate system rests on.
	for tile: Vector2i in [Vector2i(0, 0), Vector2i(15, 15), Vector2i(29, 29), Vector2i(7, 22)]:
		var back: Vector2i = BattleGrid.world_to_tile(BattleGrid.tile_to_world(tile))
		_check(back == tile, "tile %s must survive a world round trip, got %s" % [tile, back])

	# The town sits at the origin, which is where every existing node expects it.
	var centre: Vector2i = BattleGrid.world_to_tile(Vector2.ZERO)
	_check(grid.cell_at(centre) == BattleGrid.Cell.TOWN,
		"the origin must be town, got %d" % grid.cell_at(centre))
	_check(not grid.footprint_is_open(centre), "nothing may be built on the town")

	# The border frame.
	_check(grid.cell_at(Vector2i(0, 12)) == BattleGrid.Cell.BORDER, "the edge must be border")
	_check(not grid.footprint_is_open(Vector2i(0, 12)), "nothing may be built on the border")

	# Roads: one per lane, each with a U-bend, each reaching the gate.
	_check(grid.lane_paths.size() == Balance.LANE_COUNT,
		"every lane needs a road, got %d" % grid.lane_paths.size())
	for lane: int in Balance.LANE_COUNT:
		var path: PackedVector2Array = grid.lane_paths[lane]
		_check(path.size() >= 5, "lane %d needs a bend, got %d points" % [lane, path.size()])
		_check(path[path.size() - 1].is_equal_approx(Vector2.ZERO),
			"lane %d must end at the town gate, ends at %s" % [lane, path[path.size() - 1]])

		# The bend has to actually double back, or it is a corner and not a
		# U-bend: some segment must move *away* from the town.
		var retreats: bool = false
		for i: int in path.size() - 1:
			if path[i + 1].length() > path[i].length() + 1.0:
				retreats = true
		_check(retreats, "lane %d never doubles back - that is a corner, not a U-bend" % lane)

		# A bent road is longer than the straight line it replaces. If it is not,
		# the bend is cosmetic and buys the player no extra seconds under fire.
		var straight: float = path[0].length()
		_check(grid.lane_length(lane) > straight * 1.25,
			"lane %d road (%.0f) must be meaningfully longer than straight (%.0f)"
				% [lane, grid.lane_length(lane), straight])

		# Distance-along must fall as you approach the gate, or lane pressure
		# will rank a besieger behind a straggler.
		var near_gate: float = grid.distance_to_town_along(lane, path[path.size() - 2] * 0.5)
		var at_spawn: float = grid.distance_to_town_along(lane, path[0])
		_check(near_gate < at_spawn,
			"lane %d: distance-to-town must shrink toward the gate (%.0f vs %.0f)"
				% [lane, near_gate, at_spawn])

	# The build pocket the bend encloses is the whole reason for the bend. Count
	# open tiles near the bend's outer corner; four towers need sixteen tiles.
	for lane: int in Balance.LANE_COUNT:
		var path: PackedVector2Array = grid.lane_paths[lane]
		var pocket_centre: Vector2i = BattleGrid.world_to_tile(grid.lane_pocket_centre(lane))
		var open: int = 0
		for dx: int in range(-3, 4):
			for dy: int in range(-3, 4):
				if grid.cell_at(pocket_centre + Vector2i(dx, dy)) == BattleGrid.Cell.OPEN:
					open += 1
		_check(open >= 16, "lane %d bend pocket has %d open tiles, needs 16 for four towers"
			% [lane, open])

	# There must be somewhere to build at all, and it must be most of the map.
	var open_total: int = 0
	for tile_index: int in grid.cells.size():
		if grid.cells[tile_index] == BattleGrid.Cell.OPEN:
			open_total += 1
	var fraction: float = float(open_total) / float(BattleGrid.SIZE * BattleGrid.SIZE)
	_check(fraction > 0.45 and fraction < 0.9,
		"open ground is %.0f%% of the field - roads are either invisible or eating it"
			% (fraction * 100.0))
	print("[grid] %d open tiles (%.0f%%), road length %.0f vs straight %.0f"
		% [open_total, fraction * 100.0, grid.lane_length(0), grid.lane_paths[0][0].length()])

	for problem: String in _failures:
		push_error("[grid] " + problem)
	print("[grid] %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
