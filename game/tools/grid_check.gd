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
## Rewritten once for the authored layout. The old checks asserted the shape of
## four procedural U-bends: that each road doubled back, that it was 25% longer
## than the straight line, that its bend enclosed a pocket. None of that
## describes the map any more, and a check that describes the last design is
## worse than no check, because it goes green on a build it never looked at.
##
## ## Amended 2026-09-22, for the outskirts
##
## And then it happened again, with this file on the receiving end. This gate
## ran on **neither** workflow — it is a `--script` tool rather than a `.tscn`,
## so the two hand-kept gate lists never carried it — and it had been red since
## the outskirts landed on 2026-09-12, asserting the map as it was the day
## before. Three assertions, 34 failures, all stale:
##
##   * *"the grid must be 45x45"*. It is 45x45 **authored**, pasted at an offset
##     inside a field of `SIZE`; the outskirts lie around it. The replacement
##     does not restate `SIZE`'s own definition, which would assert nothing -
##     it holds the two things that can actually be wrong: the authored layout
##     on disk is `CORE_SIZE` square, and every tile the outskirts template can
##     address lands on the field. `_put` drops an out-of-bounds write in
##     silence, so a tuned template constant that ran off the edge would simply
##     not exist, with nothing said.
##
##   * *"sealing the border must leave the twelve spawn tiles as road"*. Twelve
##     was one three-wide mouth a lane. Each lane now forks into two legs that
##     reach the map's edge, so the figure is `LANE_COUNT * 2 * ROAD_WIDTH_TILES`
##     — derived rather than typed, because a hand-typed 45 is what put this
##     file a design behind in the first place.
##
##   * *"a route must end at the town"*, 32 times. It deliberately does not.
##     Owner report, 2026-09-12: a route ends at the **gate ring**, one node
##     before the town, "which is what put the wall back in reach: a body at
##     the gate hits the gate". Derived from the lattice rather than from the
##     256 units it happens to be: the last point must be one of the town
##     node's own lattice neighbours, and the town's tile must appear nowhere
##     on the route at all.
##
## Three assertions were also **re-scoped**, which is an amendment rather than a
## repair and is recorded in CLAUDE.md with its reasoning. The open-ground
## fraction and the two-towers-abreast count now measure the **authored core**:
## they were written about the authored map's four-tile gaps, and read over a
## field 3.7 times the area they were sized for, the outskirts drown the signal
## — 4,566 places for two towers against a floor of 200 is a number that can no
## longer go wrong. The field-wide fraction is kept beside them as a loose bound
## on the outskirts eating themselves.
##
## And `far_routes` is walked. It is half the road network — the legs every wave
## uses once a lane's two camps have fallen — it is a product of this class, and
## no gate in the project had ever asked whether it was road the whole way.

var _failures: PackedStringArray = []


func _init() -> void:
	var grid := BattleGrid.new()

	_check_the_field(grid)
	_check_the_border(grid)
	_check_the_outskirts_landed(grid)

	_check(grid.lane_paths.size() == Balance.LANE_COUNT,
		"every lane needs a road, got %d" % grid.lane_paths.size())

	# The gate ring: the lattice nodes one step from the town, one per cardinal.
	# Every route in the game ends on one of these, and this is where that fact
	# is derived rather than written down.
	var town_node := Vector2i(BattleGrid.SIZE / 2, BattleGrid.SIZE / 2)
	var gates: Array[Vector2i] = grid.lattice_neighbours(town_node)
	_check(gates.size() == Balance.LANE_COUNT,
		"the town should stand on %d gates, the lattice offers %d"
			% [Balance.LANE_COUNT, gates.size()])

	# The point of the authored map: more than one way in from each spawn. Both
	# pools, because a lane is two road networks - the near one while its fork
	# is shut, the legs once it is open - and only one of them was ever checked.
	#
	# `first_step` differs by pool and the reason is the ambush. A near route
	# begins in the trees beside the corridor and crosses open ground to reach
	# it, so its opening segment is deliberately not road; a far route begins
	# on the leg it walks down, so every step of it is.
	var near_shapes: Dictionary = {}
	var far_shapes: Dictionary = {}
	for lane: int in Balance.LANE_COUNT:
		near_shapes[_check_routes(grid, gates, lane, "near", grid.routes[lane], 1)] = true
		far_shapes[_check_routes(grid, gates, lane, "far", grid.far_routes[lane], 0)] = true

	# Four roads cut from one shape rotated: they must offer the same choices, or
	# one spawn is quietly harder than another.
	_check(near_shapes.size() == 1,
		"the four lanes offer different numbers of near routes - the map is not symmetric")
	_check(far_shapes.size() == 1,
		"the four lanes offer different numbers of far routes - the map is not symmetric")

	# Distance-along has to fall toward the gate, or lane pressure ranks a
	# besieger behind a straggler. Read off the ends of the lane's own road
	# rather than off a point pulled halfway to the origin first, which is a
	# question with only one possible answer.
	for lane: int in Balance.LANE_COUNT:
		var path: PackedVector2Array = grid.lane_paths[lane]
		_check(path.size() >= 2, "lane %d has no road to measure" % lane)
		if path.size() < 2:
			continue
		_check(grid.distance_to_town_along(lane, path[path.size() - 1])
			< grid.distance_to_town_along(lane, path[0]),
			"lane %d: distance-to-town must shrink toward the gate" % lane)

	_check_the_core_is_buildable(grid)

	for lane: int in Balance.LANE_COUNT:
		var pocket: Vector2i = BattleGrid.world_to_tile(grid.lane_pocket_centre(lane))
		var open: int = 0
		for dx: int in range(-3, 4):
			for dy: int in range(-3, 4):
				if grid.cell_at(pocket + Vector2i(dx, dy)) == BattleGrid.Cell.OPEN:
					open += 1
		_check(open >= 16, "lane %d pocket has %d open tiles, needs 16 for four towers"
			% [lane, open])

	var lengths: Array[float] = []
	for route: Variant in grid.routes[0]:
		lengths.append(_length(route))
	print("[grid] %dx%d tiles: a %d authored core with %d of outskirts around it"
		% [BattleGrid.SIZE, BattleGrid.SIZE, BattleGrid.CORE_SIZE, BattleGrid.OUTSKIRTS])
	print("[grid] lane 0 offers %d near and %d far routes, %.0f to %.0f units"
		% [lengths.size(), (grid.far_routes[0] as Array).size(),
			lengths[0], lengths[lengths.size() - 1]])

	for problem: String in _failures:
		push_error("[grid] " + problem)
	print("[grid] %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)


## The field is the authored core with the outskirts laid around it.
##
## Deliberately not `SIZE == CORE_SIZE + OUTSKIRTS * 2`, which is how `SIZE` is
## defined and so asserts nothing. What can go wrong is the authored map being
## re-exported at another size - `_load_layout` then bails and the middle of the
## field is quietly empty ground - and the lane-local template addressing tiles
## that are not on the field, which `_put` discards without a word.
func _check_the_field(grid: BattleGrid) -> void:
	_check(is_equal_approx(BattleGrid.TILE, 64.0),
		"the grid must be at 64 units, found %.1f" % BattleGrid.TILE)

	var text: String = FileAccess.get_file_as_string(BattleGrid.LAYOUT_PATH)
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	var rows: Array = ((parsed as Dictionary).get("tiles", []) as Array) \
		if parsed is Dictionary else []
	_check(rows.size() == BattleGrid.CORE_SIZE,
		"the authored layout is %d rows, and the core it is pasted into is %d"
			% [rows.size(), BattleGrid.CORE_SIZE])
	var short_rows: int = 0
	for row: Variant in rows:
		if (row as Array).size() < BattleGrid.CORE_SIZE:
			short_rows += 1
	_check(short_rows == 0,
		"%d authored rows are narrower than the %d-tile core, so their far side is "
			% [short_rows, BattleGrid.CORE_SIZE] + "open ground nobody drew")

	# Every tile the outskirts template can address. `local_tile` reaches
	# `CORE_SIZE / 2 + OUTSKIRTS` out from the centre and as far sideways as any
	# constant asks; if that ever exceeds `SIZE / 2` the writes at the extreme
	# land nowhere.
	for lane: int in Balance.LANE_COUNT:
		for d: int in [0, BattleGrid.OUTSKIRTS]:
			for v: int in [-BattleGrid.OUTSKIRTS, 0, BattleGrid.OUTSKIRTS]:
				var tile: Vector2i = BattleGrid.local_tile(lane, d, v)
				_check(BattleGrid.in_bounds(tile),
					"lane %d: the outskirts template reaches %s, which is off the field - "
						% [lane, str(tile)] + "writes there are dropped in silence")

	# The authored core arrived: it carries the town and the corridors drawn on
	# it. A layout that failed to parse leaves open ground and says nothing else.
	var core_road: int = 0
	var town: int = 0
	for y: int in range(BattleGrid.OUTSKIRTS, BattleGrid.OUTSKIRTS + BattleGrid.CORE_SIZE):
		for x: int in range(BattleGrid.OUTSKIRTS, BattleGrid.OUTSKIRTS + BattleGrid.CORE_SIZE):
			var cell: int = grid.cell_at(Vector2i(x, y))
			if cell == BattleGrid.Cell.ROAD:
				core_road += 1
			elif cell == BattleGrid.Cell.TOWN:
				town += 1
	_check(town > 0, "the authored core carries no town at all")
	_check(core_road > BattleGrid.CORE_SIZE * BattleGrid.ROAD_WIDTH_TILES,
		"the authored core carries %d road tiles, which is less than one corridor "
			% core_road + "across it - the layout did not arrive")

	# The town sits at the origin, which is where every existing node expects it.
	var centre: Vector2i = BattleGrid.world_to_tile(Vector2.ZERO)
	_check(grid.cell_at(centre) == BattleGrid.Cell.TOWN,
		"the origin must be town, got %d" % grid.cell_at(centre))
	_check(not grid.footprint_is_open(centre), "nothing may be built on the town")


## The outermost ring is closed to building, and the fork legs come through it.
##
## The hand-picked tile this used to sample is gone: the ring is swept, so a seal
## that missed a stretch of it cannot hide in the tiles nobody looked at.
func _check_the_border(grid: BattleGrid) -> void:
	var edge_road: int = 0
	var buildable: Array[Vector2i] = []
	for i: int in BattleGrid.SIZE:
		for tile: Vector2i in [Vector2i(i, 0), Vector2i(i, BattleGrid.SIZE - 1),
				Vector2i(0, i), Vector2i(BattleGrid.SIZE - 1, i)]:
			if grid.cell_at(tile) == BattleGrid.Cell.ROAD:
				edge_road += 1
			if grid.footprint_is_open(tile) and not buildable.has(tile):
				buildable.append(tile)
	# Counted twice at the four corners, which are open ground and so never road.
	edge_road = edge_road - _corner_road(grid)

	_check(buildable.is_empty(),
		"%d tiles on the outermost ring take a tower - the border is not sealed (%s)"
			% [buildable.size(), str(buildable.slice(0, 4))])

	# Two legs a lane, each a corridor wide, and they run to the map's edge.
	var wanted: int = Balance.LANE_COUNT * 2 * BattleGrid.ROAD_WIDTH_TILES
	_check(edge_road == wanted,
		"the forks should put %d road tiles on the outermost ring - two legs a lane, "
			% wanted + "each %d across - and there are %d"
			% [BattleGrid.ROAD_WIDTH_TILES, edge_road])

	# And a lane's waves come in on that road rather than beside it.
	for lane: int in Balance.LANE_COUNT:
		for spawn: Variant in grid.far_spawn_points[lane]:
			var tile: Vector2i = BattleGrid.world_to_tile(spawn as Vector2)
			_check(grid.cell_at(tile) == BattleGrid.Cell.ROAD,
				"lane %d: the far spawn at %s is not on the leg it walks down (cell %d)"
					% [lane, str(tile), grid.cell_at(tile)])


func _corner_road(grid: BattleGrid) -> int:
	var last: int = BattleGrid.SIZE - 1
	var doubled: int = 0
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(last, 0), Vector2i(0, last),
			Vector2i(last, last)]:
		if grid.cell_at(corner) == BattleGrid.Cell.ROAD:
			doubled += 1
	return doubled


## What the outskirts template actually wrote, rather than what its constants say.
##
## A camp record names its tiles and a barrier names its ground; if a constant
## were tuned past the edge, `_put` would drop the cell and the record would
## still be there, describing ground the field does not have.
func _check_the_outskirts_landed(grid: BattleGrid) -> void:
	var per_lane: Dictionary = {}
	for camp: Dictionary in grid.camps:
		var lane: int = int(camp["lane"])
		per_lane[lane] = int(per_lane.get(lane, 0)) + 1
		var tiles: Array = camp["tiles"]
		# **A camp has to name ground before it can name the right ground.**
		# Found by planting the fault this function exists for - a template
		# constant tuned past the edge - and watching the check below pass: the
		# range that lays the war camp came out empty, so the record described
		# nothing, and "none of its tiles are wrong" was true of no tiles at all.
		# A comparison of two nothings is the most dangerous shape a check can
		# take, and this project has shipped that one before.
		_check(not tiles.is_empty(),
			"lane %d tier %d: the camp names no ground at all - its template range "
				% [lane, int(camp["tier"])] + "is empty or ran off the field")
		var wrong: int = 0
		for tile: Vector2i in tiles:
			if grid.cell_at(tile) != BattleGrid.Cell.CAMP:
				wrong += 1
		_check(wrong == 0,
			"lane %d tier %d: %d of the camp's %d tiles are not camp ground"
				% [lane, int(camp["tier"]), wrong, tiles.size()])
	for lane: int in Balance.LANE_COUNT:
		_check(int(per_lane.get(lane, 0)) == BattleGrid.CampTier.size(),
			"lane %d has %d camps, one a tier is %d"
				% [lane, int(per_lane.get(lane, 0)), BattleGrid.CampTier.size()])

	for lane: int in Balance.LANE_COUNT:
		var pair: Array = grid.barriers[lane]
		_check(pair.size() == 2, "lane %d bars %d legs, not 2" % [lane, pair.size()])
		for bar: Variant in pair:
			var tile: Vector2i = BattleGrid.world_to_tile((bar as Dictionary)["at"] as Vector2)
			_check(grid.cell_at(tile) == BattleGrid.Cell.ROAD,
				"lane %d: a barrier stands at %s, which is not on the leg it bars (cell %d)"
					% [lane, str(tile), grid.cell_at(tile)])


## Every route of one pool, and what it returns is how many there were - the
## caller compares that across lanes to decide the map is symmetric.
func _check_routes(grid: BattleGrid, gates: Array[Vector2i], lane: int, pool: String,
		options: Array, first_step: int) -> int:
	_check(options.size() >= 2,
		"lane %d offers %d %s routes - the forks are the whole point of the map"
			% [lane, options.size(), pool])

	var town: Vector2i = BattleGrid.world_to_tile(Vector2.ZERO)
	for index: int in options.size():
		var route: PackedVector2Array = options[index]
		_check(route.size() >= 3,
			"lane %d %s route %d is only %d points" % [lane, pool, index, route.size()])
		if route.size() < 3:
			continue

		# **A route ends at the gate ring, not at the town.** One node short of
		# the square, which is inside a melee reach of the wall - owner report,
		# 2026-09-12: "melee units should not head all the way into the city
		# base at origin but rather attack it from just outside its walls".
		# Named off the lattice so the day the town moves or the corridors are
		# re-exported, this still means the gate rather than 256 units.
		var last: Vector2i = BattleGrid.world_to_tile(route[route.size() - 1])
		_check(gates.has(last),
			"lane %d %s route %d ends at %s, which is not one of the town's gates %s"
				% [lane, pool, index, str(last), str(gates)])
		for i: int in route.size():
			if BattleGrid.world_to_tile(route[i]) == town:
				_check(false, "lane %d %s route %d walks onto the town's own tile at step %d"
					% [lane, pool, index, i])
				break

		# Every step of every route has to be road the whole way. This is the
		# check that matters: the lattice is derived rather than authored, and
		# a centre line found one tile off would still produce routes that
		# look plausible, connect end to end, and walk enemies through the
		# buildable ground beside the road.
		for i: int in range(first_step, route.size()):
			var tile: Vector2i = BattleGrid.world_to_tile(route[i])
			var cell: int = grid.cell_at(tile)
			if cell != BattleGrid.Cell.ROAD and cell != BattleGrid.Cell.TOWN:
				_check(false, "lane %d %s route %d turns at %s, which is not road"
					% [lane, pool, index, tile])
				break
		for i: int in range(first_step, route.size() - 1):
			if not _corridor_is_road(grid, route[i], route[i + 1]):
				_check(false, "lane %d %s route %d crosses open ground between %s and %s"
					% [lane, pool, index, route[i], route[i + 1]])
				break
	return options.size()


## Two towers side by side is the layout's stated reason for four-tile gaps, and
## how much of the map is ground rather than road.
##
## **Measured over the authored core**, which is the ground those two statements
## were ever about: the outskirts are woodland with camps in it, they are 3.7
## times the core's area, and read over the whole field either figure is a number
## about the outskirts wearing a statement about the map. The whole field keeps a
## loose bound of its own, which is a different question - whether the template
## has grown over everything.
func _check_the_core_is_buildable(grid: BattleGrid) -> void:
	var first: int = BattleGrid.OUTSKIRTS
	var past: int = BattleGrid.OUTSKIRTS + BattleGrid.CORE_SIZE

	var pairs: int = 0
	for y: int in range(first, past - BattleGrid.FOOTPRINT):
		for x: int in range(first, past - BattleGrid.FOOTPRINT * 2):
			if grid.footprint_is_open(Vector2i(x, y)) \
					and grid.footprint_is_open(Vector2i(x + BattleGrid.FOOTPRINT, y)):
				pairs += 1
	_check(pairs >= 200,
		"only %d places in the authored core take two towers side by side - the gaps "
			% pairs + "are too narrow")

	var core_open: int = 0
	for y: int in range(first, past):
		for x: int in range(first, past):
			if grid.cell_at(Vector2i(x, y)) == BattleGrid.Cell.OPEN:
				core_open += 1
	var core_fraction: float = float(core_open) \
		/ float(BattleGrid.CORE_SIZE * BattleGrid.CORE_SIZE)
	_check(core_fraction > 0.45 and core_fraction < 0.9,
		"open ground is %.0f%% of the authored core - roads are either invisible or "
			% (core_fraction * 100.0) + "eating it")

	var field_open: int = 0
	for cell: int in grid.cells:
		if cell == BattleGrid.Cell.OPEN:
			field_open += 1
	var field_fraction: float = float(field_open) / float(BattleGrid.SIZE * BattleGrid.SIZE)
	_check(field_fraction > 0.45,
		"open ground is %.0f%% of the whole field - the outskirts have grown over it"
			% (field_fraction * 100.0))

	print("[grid] core: %d open tiles (%.0f%%), %d places for two towers abreast; "
		% [core_open, core_fraction * 100.0, pairs]
		+ "field %.0f%% open" % (field_fraction * 100.0))


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
