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
## ## The map is authored, not generated
##
## The layout comes from `LAYOUT_PATH`, exported by the owner's map tool. It
## replaced four procedural U-bends, and the reason is not that the bends were
## wrong — it is that a generator can only produce the shape it was written for.
## The authored map **forks and rejoins**, so there is more than one way from a
## spawn to the town, and that is a thing no amount of tuning to a single
## polyline could have produced.
##
## The consequence runs deep enough to be worth stating plainly: a lane is no
## longer *a path*. It is a set of routes that share corridors with each other
## and with the other three lanes. `lane_paths` keeps the shortest one so old
## callers still work, but anything asking "where will this enemy be" has to ask
## the enemy, not the lane.

## Where the authored layout lives. JSON rather than a `.tres` because it is
## produced by an external tool and diffed by eye.
const LAYOUT_PATH: String = "res://data/maps/battlefield_layout.json"

## 45x45 tiles at 64 units is a 2880x2880 field. Read from the layout at load and
## asserted against it; the constant is here so callers that size things against
## the field do not all have to hold a grid.
const SIZE: int = 45
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

## Tile ids as the map tool writes them.
const TILE_EMPTY: int = 0
const TILE_PATH: int = 1
const TILE_BACKGROUND: int = 2
const TILE_START: int = 3
const TILE_END: int = 4
const TILE_SPAWN: int = 5
const TILE_BLOCKED: int = 7
const TILE_CITY: int = 9

enum Cell { OPEN, ROAD, TOWN, BORDER }

var cells: Array[int] = []

## One polyline per lane, in world space, ordered from the spawn edge to the
## town. The *shortest* route for that lane; see `routes` for the rest.
var lane_paths: Array = []

## Every route per lane, shortest first. Enemies pick from here, which is what
## makes two enemies from the same spawn take different ways in.
var routes: Array = []

## Where each lane's enemies enter the map, in world space.
var spawn_points: Array = []

var _lattice: Dictionary = {}
var _centre_cols: Array[int] = []
var _centre_rows: Array[int] = []


func _init() -> void:
	cells.resize(SIZE * SIZE)
	cells.fill(Cell.OPEN)
	_load_layout()
	_seal_border()
	_build_lattice()
	for lane: int in Balance.LANE_COUNT:
		var found: Array = _routes_for(lane)
		routes.append(found)
		lane_paths.append(found[0] if not found.is_empty() else PackedVector2Array())


## The direction a lane runs, out from the town.
##
## Duplicated from `Battlefield` rather than called from it, and that is not an
## oversight. `Battlefield` reaches `RunState`, which is an autoload, and a
## `SceneTree` tool script replaces the main loop so no autoload exists — merely
## *referencing* the class fails to compile there. This class is meant to be
## checkable without a scene, so it owns the one line it needs.
static func lane_vector(lane: int) -> Vector2:
	return Vector2.UP.rotated(TAU * float(lane) / float(Balance.LANE_COUNT))


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
	if rows.size() != SIZE:
		push_error("BattleGrid: layout is %d rows, expected %d" % [rows.size(), SIZE])
		return

	for y: int in SIZE:
		var row: Array = rows[y] as Array
		for x: int in mini(row.size(), SIZE):
			cells[y * SIZE + x] = _cell_for(int(row[x]))


## Closes the outermost ring to building, without touching authored tiles.
##
## The blueprint marks the whole outer ring Background, which is buildable, and a
## tower flush against the edge is drawn half off the visible field. The old grid
## carved a border ring outright; that cannot be done here because the ring also
## carries the twelve spawn tiles, and carving those would delete the entrances.
##
## So only open ground is sealed. Road stays road, and the author's topology
## comes through unchanged.
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
## built on, whatever it is called.
func _cell_for(id: int) -> int:
	match id:
		TILE_PATH, TILE_START, TILE_END, TILE_SPAWN:
			return Cell.ROAD
		TILE_CITY:
			return Cell.TOWN
		TILE_BLOCKED, TILE_EMPTY:
			return Cell.BORDER
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
# fifty nodes. That is what routes are enumerated over, and what the renderer
# stamps tiles along.
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

## Where a lane's enemies come in, as a lattice node.
func _entry_node(lane: int) -> Vector2i:
	var direction: Vector2 = lane_vector(lane)
	var centre: int = SIZE / 2
	# The entry is the outermost lattice node on the lane's own axis.
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


## Where a lane's enemies come onto the map, just outside the edge.
##
## Taken from the authored spawn tiles rather than derived from the entry node.
## The first version worked back from the lattice with an arithmetic guess at how
## far the edge was and put the spawn inside the field - in one case inside a
## build pocket, which the balance test caught.
func _spawn_point(lane: int) -> Vector2:
	var direction: Vector2 = lane_vector(lane)
	var total := Vector2.ZERO
	var count: int = 0
	for y: int in SIZE:
		for x: int in SIZE:
			if not (x == 0 or y == 0 or x == SIZE - 1 or y == SIZE - 1):
				continue
			if cells[y * SIZE + x] != Cell.ROAD:
				continue
			var at: Vector2 = tile_to_world(Vector2i(x, y))
			# The edge tiles belonging to this lane: the ones furthest out along
			# its own axis.
			if at.dot(direction) < HALF_EXTENT - TILE * 1.5:
				continue
			total += at
			count += 1
	if count == 0:
		return direction * (HALF_EXTENT + TILE)
	# One tile beyond the edge, so enemies walk on rather than appear on the map.
	return total / float(count) + direction * TILE


## Every simple route from a lane's entry to the town, shortest first.
##
## Simple — no node visited twice — because a route that loops is not a decision,
## it is a mistake the player watches an enemy make.
func _routes_for(lane: int) -> Array:
	var centre: int = SIZE / 2
	var goal := Vector2i(centre, centre)
	var entry: Vector2i = _entry_node(lane)
	var found: Array = []
	_walk(entry, goal, {entry: true}, [entry], found)

	found.sort_custom(func(a: Array, b: Array) -> bool:
		return _tile_length(a) < _tile_length(b))

	var spawn: Vector2 = _spawn_point(lane)
	spawn_points.append(spawn)

	# Routes far longer than the direct way in are dropped rather than merely made
	# unlikely. A weighting still rolls them occasionally, and an enemy that walks
	# for two and a half minutes arrives long after its wave is over - which reads
	# as a stuck enemy, not as a flanker.
	var shortest: int = _tile_length(found[0]) if not found.is_empty() else 0
	var out: Array = []
	for path: Array in found:
		if shortest > 0 and float(_tile_length(path)) 				> float(shortest) * Balance.ROUTE_LENGTH_MAX_RATIO:
			continue
		var points: PackedVector2Array = PackedVector2Array()
		# Enemies walk in from off-map, so the route starts outside the edge.
		points.append(spawn)
		for node: Vector2i in path:
			points.append(tile_to_world(node))
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


## A route for an enemy to take, biased toward the shorter ways in.
##
## Not uniform. The longest route on this map is three times the shortest, and a
## flat draw would send a third of every wave on a scenic tour — the wave would
## arrive in two distinct clumps and read as a bug. Weighting by the inverse of
## length keeps the short ways busy and still sends a real minority the long way
## round, which is the point: an enemy that takes the far corridor should be a
## thing the player notices, not the thing they expect.
func route_for(lane: int, roll: float) -> PackedVector2Array:
	var options: Array = routes[lane] if lane < routes.size() else []
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


static func _world_length(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	return total


# --- What callers ask --------------------------------------------------------

## A buildable anchor in the lane's own quarter of the field, for hints and tools.
func lane_pocket_centre(lane: int) -> Vector2:
	var direction: Vector2 = lane_vector(lane)
	var target: Vector2 = direction * (HALF_EXTENT * 0.45)
	var best: Vector2 = target
	var nearest: float = INF
	for y: int in SIZE - FOOTPRINT:
		for x: int in SIZE - FOOTPRINT:
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
