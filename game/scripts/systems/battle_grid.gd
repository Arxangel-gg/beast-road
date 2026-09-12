class_name BattleGrid
extends RefCounted

## The battlefield's tile grid and the road network laid across it (GDD §13).
##
## Everything here is pure geometry: no nodes, no scene, no autoload. That is
## deliberate — placement rules, road shape and buildability are the kind of
## thing that has to be testable without standing a battlefield up, and the
## headless tools cannot reach an autoload at all.
##
## Coordinates come in two kinds and mixing them is the bug this class exists to
## prevent:
##
##   **tile**  `Vector2i`, 0..SIZE-1 on each axis, origin at the top-left.
##   **world** `Vector2`, centred on the town at (0, 0), which is what every
##             node in the battlefield already uses.
##
## Convert with `tile_to_world` / `world_to_tile`, never by hand.
##
## ## The core is authored; the outskirts are laid
##
## The centre of the field - `CORE_SIZE` tiles a side - comes from `LAYOUT_PATH`,
## exported by the owner's map tool. It replaced four procedural U-bends, and
## the reason is not that the bends were wrong — it is that a generator can only
## produce the shape it was written for. The authored map **forks and rejoins**,
## so there is more than one way from a spawn to the town, and that is a thing
## no amount of tuning to a single polyline could have produced.
##
## Around it, since 2026-09-12, lie the **outskirts** (owner brief: "extend the
## pathing ... camps ... fork splits"). Each of the four roads now runs on past
## the old edge: past two camps that branch off it, to a junction where the
## road forks into two legs that reach the map's edge with a war camp between
## them. The outskirts are *laid* rather than authored - one template applied
## to each cardinal with the run's seed choosing which side the camps sit -
## because they are the same shape four times over and a tool export would be
## four copies of one drawing. v4 §54's cut of procedural battlefield *layouts*
## stands: the roads the waves walk are the authored core plus a fixed
## extension, and what the seed decides is a mirror.
##
## The consequence of forking runs deep enough to be worth stating plainly: a
## lane is no longer *a path*. It is a set of routes that share corridors with
## each other and with the other three lanes. `lane_paths` keeps the shortest
## one so old callers still work, but anything asking "where will this enemy
## be" has to ask the enemy, not the lane.

## Where the authored layout lives. JSON rather than a `.tres` because it is
## produced by an external tool and diffed by eye.
const LAYOUT_PATH: String = "res://data/maps/battlefield_layout.json"

## The authored core: 45x45 tiles at 64 units.
const CORE_SIZE: int = 45
## Tiles laid beyond the core on every side.
const OUTSKIRTS: int = 15
## The whole field. 75x75 tiles at 64 units is a 4800x4800 world.
const SIZE: int = CORE_SIZE + OUTSKIRTS * 2
const TILE: float = 64.0

## A tower covers 2x2 tiles. Its anchor is the top-left tile of that square.
##
## Kept at 2 against a layout whose corridors sit four tiles apart, which is the
## point: a four-tile gap takes two towers side by side, where the old three-tile
## pockets took one. "Every four grid spaces is a tower slot" is the same
## statement from the other end.
const FOOTPRINT: int = 2

## How many tiles across a corridor is in the authored layout.
##
## Three, everywhere, which is what makes the centre-line lattice findable at all
## — a run of exactly three across a corridor identifies its middle. The renderer
## sizes its road pieces from this so the art covers the tiles enemies walk on.
const ROAD_WIDTH_TILES: int = 3

## Half the field in world units, used to move the origin to the centre.
const HALF_EXTENT: float = float(SIZE) * TILE * 0.5
## Half the authored core, in world units: where "beyond the paths" begins.
const CORE_HALF_EXTENT: float = float(CORE_SIZE) * TILE * 0.5

## Tile ids as the map tool writes them.
const TILE_EMPTY: int = 0
const TILE_PATH: int = 1
const TILE_BACKGROUND: int = 2
const TILE_START: int = 3
const TILE_END: int = 4
const TILE_SPAWN: int = 5
const TILE_BLOCKED: int = 7
const TILE_CITY: int = 9

## CAMP is ground a raider camp stands on: walked over like open ground, never
## built on, never dug for water, and never road - the lattice does not see it.
enum Cell { OPEN, ROAD, TOWN, BORDER, CAMP }

## The outskirts template, in lane-local tiles. `d` runs outward from the old
## edge (0 is the core's outermost row, `OUTSKIRTS` is the map's edge); `v`
## runs sideways from the road's centre line. See `_lay_outskirts`.
const CORRIDOR_DEPTH: int = 9
const FORK_DEPTH: int = 9
const FORK_BAR_HALF: int = 5
const LEG_CENTRE: int = 4
const CAMP_BRANCH_NEAR: int = 2
const CAMP_BRANCH_FAR: int = 5
const CAMP_CLEARING_NEAR: int = 6
const CAMP_CLEARING_FAR: int = 10
const CAMP_A_DEPTH: int = 2
const CAMP_B_DEPTH: int = 6
const BARON_HALF: int = 2
const BARON_DEPTH_FROM: int = 12
## Where the barrier stands across each leg while the fork is closed.
const BARRIER_DEPTH: int = 12

## Camp tiers, outermost last.
enum CampTier { EASY, HARD, BARON }

var cells: Array[int] = []

## One polyline per lane, in world space, ordered from the spawn edge to the
## town. The *shortest* route for that lane; see `routes` for the rest.
var lane_paths: Array = []

## Every route per lane, shortest first, from the lane's near spawn. Enemies
## pick from here, which is what makes two enemies from the same spawn take
## different ways in.
var routes: Array = []

## Every route per lane from the far spawns - the two legs of the fork - used
## once the fork is open. Same shape as `routes`.
var far_routes: Array = []

## Where each lane's enemies enter the map while its fork is closed, in world
## space: the mouth of the fork junction.
var spawn_points: Array = []

## Where each lane's enemies enter once its fork is open: one point per leg.
var far_spawn_points: Array = []

## Whether each lane's fork is open. Closed until both of its camps fall.
var fork_open: Array[bool] = []

## The camps, one record each: {lane, tier, centre, rect, tiles}. `rect` and
## `centre` are world space; `tiles` the CAMP cells.
var camps: Array[Dictionary] = []

## Where the barriers stand while a fork is closed: per lane, two records
## {at, along} in world space, `along` the leg's own direction.
var barriers: Array = []

## Which side of each road its first camp branches to, +1 or -1. The same for
## all four lanes so the field stays four-fold symmetric under a quarter turn -
## the torches and the lane ring depend on that - and the seed picks which.
var camp_side: int = 1

var _lattice: Dictionary = {}
var _centre_cols: Array[int] = []
var _centre_rows: Array[int] = []


func _init(layout_seed: int = 0) -> void:
	cells.resize(SIZE * SIZE)
	cells.fill(Cell.OPEN)
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	camp_side = 1 if rng.randf() < 0.5 else -1
	_load_layout()
	_lay_outskirts()
	_seal_border()
	_build_lattice()
	for lane: int in Balance.LANE_COUNT:
		fork_open.append(false)
		var found: Array = _routes_for(lane)
		routes.append(found)
		lane_paths.append(found[0] if not found.is_empty() else PackedVector2Array())
		far_routes.append(_far_routes_for(lane, found))


## The direction a lane runs, out from the town.
##
## Duplicated from `Battlefield` rather than called from it, and that is not an
## oversight. `Battlefield` reaches `RunState`, which is an autoload, and a
## `SceneTree` tool script replaces the main loop so no autoload exists — merely
## *referencing* the class fails to compile there. This class is meant to be
## checkable without a scene, so it owns the one line it needs.
static func lane_vector(lane: int) -> Vector2:
	return Vector2.UP.rotated(TAU * float(lane) / float(Balance.LANE_COUNT))


## A lane's frame in tiles: outward and sideways unit steps.
static func lane_frame(lane: int) -> Array[Vector2i]:
	var outward: Vector2 = lane_vector(lane)
	var o := Vector2i(roundi(outward.x), roundi(outward.y))
	# A quarter turn, the same way round for every lane, so the four outskirts
	# are one shape rotated rather than one shape and its mirror.
	var s := Vector2i(-o.y, o.x)
	return [o, s]


## The tile at lane-local (d, v): `d` outward from the core's outermost row,
## `v` sideways from the road's centre line.
static func local_tile(lane: int, d: int, v: int) -> Vector2i:
	var frame: Array[Vector2i] = lane_frame(lane)
	var centre: int = SIZE / 2
	return Vector2i(centre, centre) + frame[0] * (CORE_SIZE / 2 + d) + frame[1] * v


# --- Coordinates -------------------------------------------------------------

static func tile_to_world(tile: Vector2i) -> Vector2:
	# Centre of the tile, not its corner: a tower placed on a tile should stand
	# in the middle of it.
	return Vector2(
		float(tile.x) * TILE - HALF_EXTENT + TILE * 0.5,
		float(tile.y) * TILE - HALF_EXTENT + TILE * 0.5)


static func world_to_tile(at: Vector2) -> Vector2i:
	return Vector2i(
		int(floor((at.x + HALF_EXTENT) / TILE)),
		int(floor((at.y + HALF_EXTENT) / TILE)))


## The world centre of a 2x2 tower anchored at `tile` — half a tile further along
## each axis than the anchor's own centre.
static func footprint_centre(tile: Vector2i) -> Vector2:
	return tile_to_world(tile) + Vector2(TILE, TILE) * 0.5


static func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < SIZE and tile.y < SIZE


## Whether a tile lies in the authored core rather than the laid outskirts.
static func in_core(tile: Vector2i) -> bool:
	return tile.x >= OUTSKIRTS and tile.y >= OUTSKIRTS \
		and tile.x < OUTSKIRTS + CORE_SIZE and tile.y < OUTSKIRTS + CORE_SIZE


## Whether a world point is beyond the authored core - "past where the paths
## begin", which is where the water and the gates go.
static func beyond_core(at: Vector2) -> bool:
	return absf(at.x) > CORE_HALF_EXTENT or absf(at.y) > CORE_HALF_EXTENT


func cell_at(tile: Vector2i) -> int:
	if not in_bounds(tile):
		return Cell.BORDER
	return cells[tile.y * SIZE + tile.x]


# --- Buildability ------------------------------------------------------------

## True when a 2x2 tower anchored here would sit entirely on open ground.
##
## Occupancy by other towers is *not* checked here — this class knows the map,
## not the run. `RunState` owns what has been built, and asking one object about
## both is how the two end up disagreeing.
func footprint_is_open(anchor: Vector2i) -> bool:
	for dx: int in FOOTPRINT:
		for dy: int in FOOTPRINT:
			if cell_at(anchor + Vector2i(dx, dy)) != Cell.OPEN:
				return false
	return true


## Every tile a tower anchored here would cover.
static func footprint_tiles(anchor: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for dx: int in FOOTPRINT:
		for dy: int in FOOTPRINT:
			tiles.append(anchor + Vector2i(dx, dy))
	return tiles


# --- The authored layout -----------------------------------------------------

func _load_layout() -> void:
	var text: String = FileAccess.get_file_as_string(LAYOUT_PATH)
	if text.is_empty():
		push_error("BattleGrid: no layout at %s" % LAYOUT_PATH)
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("BattleGrid: %s is not a map blueprint" % LAYOUT_PATH)
		return
	var rows: Array = (parsed as Dictionary).get("tiles", []) as Array
	if rows.size() != CORE_SIZE:
		push_error("BattleGrid: layout is %d rows, expected %d" % [rows.size(), CORE_SIZE])
		return

	for y: int in CORE_SIZE:
		var row: Array = rows[y] as Array
		for x: int in mini(row.size(), CORE_SIZE):
			_put(Vector2i(x + OUTSKIRTS, y + OUTSKIRTS), _cell_for(int(row[x])))


func _put(tile: Vector2i, cell: int) -> void:
	if in_bounds(tile):
		cells[tile.y * SIZE + tile.x] = cell


## Lays the outskirts around the core: the road on past the old edge, two camps
## branching off it, and the fork with the war camp between its legs.
##
## One template per lane in lane-local coordinates, so the four cardinals are
## one shape rotated. Every corridor is three tiles wide so the lattice finds
## it by the same rule that finds the authored ones - a branch two tiles wide
## would be road the renderer never drew and enemies never walked.
func _lay_outskirts() -> void:
	camps.clear()
	barriers.clear()
	for lane: int in Balance.LANE_COUNT:
		# The old blocked tiles at the spawn mouth become road: the corridor
		# now runs on through them.
		for d: int in range(0, CORRIDOR_DEPTH + 1):
			for v: int in range(-1, 2):
				_put(local_tile(lane, d, v), Cell.ROAD)
		# The fork: a bar across the road, and two legs out to the edge.
		for d: int in range(FORK_DEPTH, FORK_DEPTH + 3):
			for v: int in range(-FORK_BAR_HALF, FORK_BAR_HALF + 1):
				_put(local_tile(lane, d, v), Cell.ROAD)
		for d: int in range(FORK_DEPTH, OUTSKIRTS + 1):
			for v: int in range(LEG_CENTRE - 1, LEG_CENTRE + 2):
				_put(local_tile(lane, d, v), Cell.ROAD)
				_put(local_tile(lane, d, -v), Cell.ROAD)
		# The camps. The first branches to the seed's side, the second to the
		# other, so the road reads as a road with things off it rather than as
		# a corridor with a mirror.
		_lay_camp(lane, CampTier.EASY, CAMP_A_DEPTH, camp_side)
		_lay_camp(lane, CampTier.HARD, CAMP_B_DEPTH, -camp_side)
		# The war camp between the legs, beyond the bar.
		var baron_tiles: Array[Vector2i] = []
		for d: int in range(BARON_DEPTH_FROM, OUTSKIRTS + 1):
			for v: int in range(-BARON_HALF, BARON_HALF + 1):
				var tile: Vector2i = local_tile(lane, d, v)
				_put(tile, Cell.CAMP)
				baron_tiles.append(tile)
		camps.append(_camp_record(lane, CampTier.BARON, baron_tiles))
		# The barriers, one across each leg, standing while the fork is closed.
		var frame: Array[Vector2i] = lane_frame(lane)
		var along: Vector2 = Vector2(frame[0])
		var pair: Array = []
		for side: int in [-1, 1]:
			pair.append({
				"at": tile_to_world(local_tile(lane, BARRIER_DEPTH, LEG_CENTRE * side)),
				"along": along,
			})
		barriers.append(pair)


func _lay_camp(lane: int, tier: int, depth: int, side: int) -> void:
	for d: int in range(depth - 1, depth + 2):
		for v: int in range(CAMP_BRANCH_NEAR, CAMP_BRANCH_FAR + 1):
			_put(local_tile(lane, d, v * side), Cell.ROAD)
	var tiles: Array[Vector2i] = []
	for d: int in range(depth - 2, depth + 3):
		for v: int in range(CAMP_CLEARING_NEAR, CAMP_CLEARING_FAR + 1):
			var tile: Vector2i = local_tile(lane, d, v * side)
			_put(tile, Cell.CAMP)
			tiles.append(tile)
	camps.append(_camp_record(lane, tier, tiles))


func _camp_record(lane: int, tier: int, tiles: Array[Vector2i]) -> Dictionary:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for tile: Vector2i in tiles:
		var at: Vector2 = tile_to_world(tile)
		low = Vector2(minf(low.x, at.x - TILE * 0.5), minf(low.y, at.y - TILE * 0.5))
		high = Vector2(maxf(high.x, at.x + TILE * 0.5), maxf(high.y, at.y + TILE * 0.5))
	var rect := Rect2(low, high - low)
	return {"lane": lane, "tier": tier, "centre": rect.get_center(), "rect": rect,
		"tiles": tiles}


## Closes the outermost ring to building, without touching authored tiles.
##
## The ring carries the spawn tiles at the ends of the fork legs, so only open
## ground is sealed: road stays road, and the entrances come through unchanged.
func _seal_border() -> void:
	for i: int in SIZE:
		for tile: Vector2i in [Vector2i(i, 0), Vector2i(i, SIZE - 1),
				Vector2i(0, i), Vector2i(SIZE - 1, i)]:
			if cells[tile.y * SIZE + tile.x] == Cell.OPEN:
				cells[tile.y * SIZE + tile.x] = Cell.BORDER


## How a map-tool tile id lands in the grid's own vocabulary.
##
## Start, end and spawn tiles are all road: they mark *roles* on the network for
## the tool's benefit, and a tile an enemy walks over is a tile nothing may be
## built on, whatever it is called. The tool's blocked tiles sat beyond the
## spawn mouths to close the old edge; the road runs through them now, and
## `_lay_outskirts` overwrites them.
func _cell_for(id: int) -> int:
	match id:
		TILE_PATH, TILE_START, TILE_END, TILE_SPAWN:
			return Cell.ROAD
		TILE_CITY:
			return Cell.TOWN
		TILE_BLOCKED, TILE_EMPTY:
			return Cell.OPEN
		_:
			return Cell.OPEN


func _is_road(tile: Vector2i) -> bool:
	var cell: int = cell_at(tile)
	return cell == Cell.ROAD or cell == Cell.TOWN


# --- The corridor lattice ----------------------------------------------------
#
# Corridors are three tiles wide. Their centre lines fall on a small set of rows
# and columns, and every junction in the map sits where one of those rows crosses
# one of those columns — so the whole road network reduces to a lattice of about
# a hundred nodes. That is what routes are enumerated over, and what the
# renderer stamps tiles along.
#
# Found rather than hard-coded, so re-exporting the map from the tool does not
# also mean editing a table in here.

func _build_lattice() -> void:
	_centre_cols = _centres(true)
	_centre_rows = _centres(false)
	_lattice.clear()
	for col: int in _centre_cols:
		for row: int in _centre_rows:
			var node := Vector2i(col, row)
			if _is_road(node):
				_lattice[node] = _neighbours_of(node)


## Centre lines of the three-wide corridors on one axis.
##
## A run of exactly three road tiles across the corridor means its middle is a
## centre line. Runs longer than three are junctions, where two corridors overlap,
## and they are deliberately ignored: the centre lines they lie on have already
## been found somewhere the corridor was on its own.
func _centres(vertical: bool) -> Array[int]:
	var found: Dictionary = {}
	for fixed: int in SIZE:
		var start: int = -1
		for moving: int in SIZE + 1:
			var road: bool = moving < SIZE and _is_road(
				Vector2i(moving, fixed) if vertical else Vector2i(fixed, moving))
			if road and start < 0:
				start = moving
			elif not road and start >= 0:
				if moving - start == 3:
					found[(start + moving - 1) / 2] = true
				start = -1
	var out: Array[int] = []
	for key: Variant in found:
		out.append(int(key))
	out.sort()
	return out


func _neighbours_of(node: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var col: int = _centre_cols.find(node.x)
	var row: int = _centre_rows.find(node.y)
	for step: int in [-1, 1]:
		if col + step >= 0 and col + step < _centre_cols.size():
			var across := Vector2i(_centre_cols[col + step], node.y)
			if _is_road(across) and _corridor_is_clear(node, across):
				out.append(across)
		if row + step >= 0 and row + step < _centre_rows.size():
			var along := Vector2i(node.x, _centre_rows[row + step])
			if _is_road(along) and _corridor_is_clear(node, along):
				out.append(along)
	return out


## Whether the straight run between two lattice nodes is road the whole way.
func _corridor_is_clear(from: Vector2i, to: Vector2i) -> bool:
	if from.x == to.x:
		for y: int in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			if not _is_road(Vector2i(from.x, y)):
				return false
		return true
	for x: int in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
		if not _is_road(Vector2i(x, from.y)):
			return false
	return true


## Every lattice node, for the renderer.
func lattice_nodes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key: Variant in _lattice:
		out.append(key)
	return out


## A lattice node's connected neighbours.
func lattice_neighbours(node: Vector2i) -> Array[Vector2i]:
	return _lattice.get(node, [] as Array[Vector2i])


# --- Routes ------------------------------------------------------------------

## Where a lane's enemies come in while its fork is closed: the junction node
## at the mouth of the fork, which is the outermost lattice node on the lane's
## own axis.
func _entry_node(lane: int) -> Vector2i:
	var direction: Vector2 = lane_vector(lane)
	var centre: int = SIZE / 2
	var best := Vector2i(centre, centre)
	var furthest: float = -INF
	for key: Variant in _lattice:
		var node: Vector2i = key
		var offset: Vector2 = Vector2(node - Vector2i(centre, centre))
		if absf(offset.dot(direction.orthogonal())) > 0.5:
			continue
		var out: float = offset.dot(direction)
		if out > furthest:
			furthest = out
			best = node
	return best


## The lattice node where one fork leg meets the bar.
func _leg_node(lane: int, side: int) -> Vector2i:
	var wanted: Vector2i = local_tile(lane, FORK_DEPTH + 1, LEG_CENTRE * side)
	if _lattice.has(wanted):
		return wanted
	# The bar's centre row and the leg's centre column are both found by the
	# corridor rule, so this is the node; falling back to the nearest node on
	# the bar keeps a re-tuned template from routing through nothing.
	var best: Vector2i = wanted
	var nearest: float = INF
	for key: Variant in _lattice:
		var node: Vector2i = key
		var gap: float = Vector2(node - wanted).length()
		if gap < nearest:
			nearest = gap
			best = node
	return best


## Every simple route from a lane's entry to the town wall, shortest first.
##
## Simple — no node visited twice — because a route that loops is not a decision,
## it is a mistake the player watches an enemy make.
func _routes_for(lane: int) -> Array:
	var entry: Vector2i = _entry_node(lane)
	var found: Array = _walk_routes(entry)
	# The near spawn: one tile out from the junction into the bar, so enemies
	# walk on to the mouth rather than appear on it.
	var frame: Array[Vector2i] = lane_frame(lane)
	var spawn: Vector2 = tile_to_world(entry + frame[0])
	spawn_points.append(spawn)
	return _finish_routes(found, spawn)


## The routes from the far spawns: each leg's own end at the map's edge, down
## the leg to where it meets the bar, then whichever way in from there.
func _far_routes_for(lane: int, _near: Array) -> Array:
	var frame: Array[Vector2i] = lane_frame(lane)
	var spawns: Array = []
	var out: Array = []
	for side: int in [-1, 1]:
		var node: Vector2i = _leg_node(lane, side)
		# One tile beyond the edge, so enemies walk on rather than appear.
		var spawn: Vector2 = tile_to_world(local_tile(lane, OUTSKIRTS + 1, LEG_CENTRE * side))
		spawns.append(spawn)
		var found: Array = _walk_routes(node)
		for path: PackedVector2Array in _finish_routes(found, spawn):
			out.append(path)
	far_spawn_points.append(spawns)
	# Shortest first across both legs, like the near routes.
	out.sort_custom(func(a: PackedVector2Array, b: PackedVector2Array) -> bool:
		return _world_length(a) < _world_length(b))
	return out


func _walk_routes(entry: Vector2i) -> Array:
	var centre: int = SIZE / 2
	var goal := Vector2i(centre, centre)
	var found: Array = []
	_walk(entry, goal, {entry: true}, [entry], found)
	found.sort_custom(func(a: Array, b: Array) -> bool:
		return _tile_length(a) < _tile_length(b))
	return found


## Turns lattice walks into world polylines from `spawn`, dropping the ones far
## longer than the direct way in and the final step onto the town itself.
##
## Routes far longer than the direct way in are dropped rather than merely made
## unlikely. A weighting still rolls them occasionally, and an enemy that walks
## for two and a half minutes arrives long after its wave is over - which reads
## as a stuck enemy, not as a flanker.
##
## **A route ends at the wall, not at the origin.** The goal node is the town's
## own tile, and a body that walked to it stood in the middle of the square
## before it swung; the last node before the goal is the gate ring, three tiles
## out, which is inside a melee reach of the wall and is where a besieger
## stands. Owner report, 2026-09-12: "melee units should not head all the way
## into the city base at origin but rather attack it from just outside its
## walls on their cardinal direction."
func _finish_routes(found: Array, spawn: Vector2) -> Array:
	var shortest: int = _tile_length(found[0]) if not found.is_empty() else 0
	var out: Array = []
	for path: Array in found:
		if shortest > 0 and float(_tile_length(path)) \
				> float(shortest) * Balance.ROUTE_LENGTH_MAX_RATIO:
			continue
		var points: PackedVector2Array = PackedVector2Array()
		points.append(spawn)
		var last: int = path.size() - 1 if path.size() <= 2 else path.size() - 2
		for index: int in range(0, last + 1):
			points.append(tile_to_world(path[index]))
		out.append(points)
	return out


func _walk(node: Vector2i, goal: Vector2i, seen: Dictionary,
		path: Array, found: Array) -> void:
	if found.size() >= Balance.ROUTES_PER_LANE_MAX:
		return
	if node == goal:
		found.append(path.duplicate())
		return
	for next: Vector2i in lattice_neighbours(node):
		if seen.has(next):
			continue
		seen[next] = true
		path.append(next)
		_walk(next, goal, seen, path, found)
		path.pop_back()
		seen.erase(next)


static func _tile_length(path: Array) -> int:
	var total: int = 0
	for i: int in path.size() - 1:
		var a: Vector2i = path[i]
		var b: Vector2i = path[i + 1]
		total += absi(a.x - b.x) + absi(a.y - b.y)
	return total


## Opens or closes a lane's fork. Open, the lane's waves come from the two legs
## at the map's edge; closed, from the junction.
func set_fork_open(lane: int, open: bool) -> void:
	if lane >= 0 and lane < fork_open.size():
		fork_open[lane] = open


## A route for an enemy to take, biased toward the shorter ways in.
##
## Not uniform. The longest route on this map is three times the shortest, and a
## flat draw would send a third of every wave on a scenic tour — the wave would
## arrive in two distinct clumps and read as a bug. Weighting by the inverse of
## length keeps the short ways busy and still sends a real minority the long way
## round, which is the point: an enemy that takes the far corridor should be a
## thing the player notices, not the thing they expect.
func route_for(lane: int, roll: float) -> PackedVector2Array:
	var pool: Array = far_routes if lane < fork_open.size() and fork_open[lane] else routes
	var options: Array = pool[lane] if lane < pool.size() else []
	if options.is_empty():
		return PackedVector2Array()
	var weights: Array[float] = []
	var total: float = 0.0
	for path: Variant in options:
		var length: float = maxf(_world_length(path), 1.0)
		var weight: float = pow(length, -Balance.ROUTE_LENGTH_BIAS)
		weights.append(weight)
		total += weight
	var target: float = clampf(roll, 0.0, 0.9999) * total
	for i: int in options.size():
		target -= weights[i]
		if target <= 0.0:
			return options[i]
	return options[0]


## Where a lane's enemies come in right now: one point, or two once the fork
## is open.
func active_spawn_points(lane: int) -> Array:
	if lane < fork_open.size() and fork_open[lane] and lane < far_spawn_points.size():
		return far_spawn_points[lane]
	return [spawn_points[lane]] if lane < spawn_points.size() else []


static func _world_length(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	return total


# --- Camps -------------------------------------------------------------------

## The camp records for one lane, easy first.
func camps_of(lane: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for camp: Dictionary in camps:
		if int(camp["lane"]) == lane:
			out.append(camp)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["tier"]) < int(b["tier"]))
	return out


## The camp a world point stands in, or an empty record.
func camp_at(at: Vector2) -> Dictionary:
	for camp: Dictionary in camps:
		if (camp["rect"] as Rect2).has_point(at):
			return camp
	return {}


# --- What callers ask --------------------------------------------------------

## A buildable anchor in the lane's own quarter of the field, for hints and tools.
##
## Inside the core: the outskirts are open ground too, but a hint that pointed
## a new player at a tower slot beside a raider camp would be a hint that got
## them killed.
func lane_pocket_centre(lane: int) -> Vector2:
	var direction: Vector2 = lane_vector(lane)
	var target: Vector2 = direction * (CORE_HALF_EXTENT * 0.45)
	var best: Vector2 = target
	var nearest: float = INF
	for y: int in range(OUTSKIRTS, OUTSKIRTS + CORE_SIZE - FOOTPRINT):
		for x: int in range(OUTSKIRTS, OUTSKIRTS + CORE_SIZE - FOOTPRINT):
			var anchor := Vector2i(x, y)
			if not footprint_is_open(anchor):
				continue
			var at: Vector2 = footprint_centre(anchor)
			# The lane's own quarter, so a hint for the north road never points
			# the player at ground behind them.
			if at.dot(direction) <= 0.0:
				continue
			var distance: float = at.distance_to(target)
			if distance < nearest:
				nearest = distance
				best = at
	return best


func lane_length(lane: int) -> float:
	if lane >= lane_paths.size():
		return 1.0
	return maxf(_world_length(lane_paths[lane]), 1.0)


## How far along its lane a point is, measured from the town.
##
## Kept for the systems that grade pressure by depth. With a network rather than
## a single path this is a projection onto the lane axis rather than an arc
## length, which is what those callers actually wanted: they ask "how close to
## the town is this", not "how far has it walked".
func distance_to_town_along(lane: int, at: Vector2) -> float:
	return maxf(at.dot(lane_vector(lane)), 0.0)


## Which lane a world point bears on, seen from the town.
##
## The lane something *spawned* in is a fact about the past. Anything asking
## "which way is this threat coming from" has to recompute the answer from where
## the thing actually is, because an enemy that leaves the road to chase the hero
## can cross into another lane's quarter entirely - and then it is pressure on
## the side it is standing, not on the side it entered from.
##
## Decided by best alignment rather than by bucketing an arc-tangent: with four
## lanes this is four dot products, it needs no angle wrapping or quadrant
## special-casing, and it stays correct if `LANE_COUNT` ever changes.
static func lane_at(at: Vector2) -> int:
	# Dead centre bears on nothing. Answering 0 rather than dividing by zero -
	# anything standing exactly on the town is already inside it, and no readout
	# is improved by picking a random side for it.
	if at.length_squared() < 0.0001:
		return 0
	var heading: Vector2 = at.normalized()
	var best: int = 0
	var best_dot: float = -2.0
	for lane: int in Balance.LANE_COUNT:
		var aligned: float = heading.dot(lane_vector(lane))
		if aligned > best_dot:
			best_dot = aligned
			best = lane
	return best
