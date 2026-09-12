class_name DungeonLayout
extends RaidLayout

## The floor of a rift or a dungeon: corridors and rooms cut through rock
## (owner brief, 2026-09-12: "Astonia mazes + Diablo rifts").
##
## The raid's layout is islands on a plain - places to climb, with the plain
## between them. This is the opposite shape: the plain is rock, and the only
## ground is what was cut out of it. A maze is dealt on a coarse lattice with a
## recursive walk, rooms are knocked through it where the walk went, extra
## doors are opened so it loops rather than dead-ends, and the room the walk
## reached last is the **vault**, where the guardian waits and the chest lands.
##
## Everything the raid's terrain, cliffs and stepping rules know still holds:
## a wall is a `Cell.WALL` at `MAX_LEVEL`, so `RaidTerrain` bakes it as a raised
## plate with a cliff line, `RaidArena._build_cliffs` puts collision on every
## wall face, and `can_step` refuses it. Nothing downstream learns that a maze
## exists.
##
## A rift is the same thing cut looser - bigger rooms, more doors - so it reads
## as a cavern the way a Diablo rift does, while a dungeon is the tight one.
##
## Pure geometry, like its parent. `dungeon_check` walks it.

## Tiles per lattice cell: two of corridor and two of rock between.
const PITCH: int = 4
## Lattice cells across; the ring of wall at the edge is outside it.
const CELLS: int = (SIZE - 2) / PITCH
## The tile the lattice starts on, so it sits centred inside the wall ring.
const ORIGIN: int = (SIZE - CELLS * PITCH) / 2 + 1
const WALL_LEVEL: int = MAX_LEVEL

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## Looser cut: the cavern a rift is, against the maze a dungeon is.
var cavern: bool = false
## Where the hero arrives, and the vault the walk reached last.
var entry: Vector2i = Vector2i(SIZE / 2, SIZE / 2)
var deep: Vector2i = Vector2i(SIZE / 2, SIZE / 2)
var rooms: Array[Rect2i] = []
## Every open tile's walking distance from the entry.
var _depth: Dictionary = {}


func _init(rng: RandomNumberGenerator = null, open_cavern: bool = false) -> void:
	cavern = open_cavern
	super(rng)


func _generate() -> void:
	cells.fill(Cell.WALL)
	levels.fill(WALL_LEVEL)
	_carve_maze()
	_carve_rooms()
	_open_rect(Rect2i(entry - Vector2i(3, 3), Vector2i(6, 6)))
	_find_deep()
	_open_rect(Rect2i(deep - Vector2i(2, 2), Vector2i(5, 5)))
	_seal_unreachable()
	_depth = distances_from(entry)


# --- Carving ---------------------------------------------------------------------

## The top-left tile of a lattice cell's two-by-two block.
static func cell_tile(cell: Vector2i) -> Vector2i:
	return Vector2i(ORIGIN + cell.x * PITCH, ORIGIN + cell.y * PITCH)


func _open_rect(rect: Rect2i) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if x <= 0 or y <= 0 or x >= SIZE - 1 or y >= SIZE - 1:
				continue
			var index: int = y * SIZE + x
			cells[index] = Cell.OPEN
			levels[index] = 0


## A recursive walk over the lattice from the middle cell, then a few extra
## doors so the maze loops. Dead ends are what a maze is made of, and a fight
## in one is a fight with no way out; a door or two per row keeps it a place
## you move through rather than a place you back into.
func _carve_maze() -> void:
	var start := Vector2i(CELLS / 2, CELLS / 2)
	var seen: Dictionary = {start: true}
	var stack: Array[Vector2i] = [start]
	_open_rect(Rect2i(cell_tile(start), Vector2i(2, 2)))
	while not stack.is_empty():
		var here: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for step: Vector2i in DIRS:
			var next: Vector2i = here + step
			if next.x < 0 or next.y < 0 or next.x >= CELLS or next.y >= CELLS:
				continue
			if not seen.has(next):
				options.append(next)
		if options.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = options[_rng.randi_range(0, options.size() - 1)]
		seen[next] = true
		_link(here, next)
		stack.append(next)
	var loop_chance: float = Balance.RIFT_LOOP_CHANCE if cavern else Balance.DUNGEON_LOOP_CHANCE
	for y: int in CELLS:
		for x: int in CELLS:
			for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var next: Vector2i = Vector2i(x, y) + step
				if next.x >= CELLS or next.y >= CELLS:
					continue
				if _rng.randf() < loop_chance:
					_link(Vector2i(x, y), next)


## Opens two cells and the rock between them.
func _link(a: Vector2i, b: Vector2i) -> void:
	var ta: Vector2i = cell_tile(a)
	var tb: Vector2i = cell_tile(b)
	var lo := Vector2i(mini(ta.x, tb.x), mini(ta.y, tb.y))
	var hi := Vector2i(maxi(ta.x, tb.x) + 2, maxi(ta.y, tb.y) + 2)
	_open_rect(Rect2i(lo, hi - lo))


## Rooms knocked through where the walk already went, so every room is on the
## maze by construction rather than by repair.
func _carve_rooms() -> void:
	var count: int = Balance.RIFT_ROOMS if cavern else Balance.DUNGEON_ROOMS
	var largest: int = Balance.RIFT_ROOM_MAX if cavern else Balance.DUNGEON_ROOM_MAX
	var middle := Vector2i(CELLS / 2, CELLS / 2)
	var tries: int = 0
	while rooms.size() < count and tries < count * 6:
		tries += 1
		var cell := Vector2i(_rng.randi_range(0, CELLS - 1), _rng.randi_range(0, CELLS - 1))
		if (cell - middle).length() < 2.0:
			continue
		var width: int = _rng.randi_range(Balance.DUNGEON_ROOM_MIN, largest)
		var height: int = _rng.randi_range(Balance.DUNGEON_ROOM_MIN, largest)
		var centre: Vector2i = cell_tile(cell) + Vector2i.ONE
		var rect := Rect2i(centre - Vector2i(width / 2, height / 2), Vector2i(width, height))
		rect = rect.intersection(Rect2i(1, 1, SIZE - 2, SIZE - 2))
		var overlaps: bool = false
		for other: Rect2i in rooms:
			if other.grow(1).intersects(rect):
				overlaps = true
				break
		if overlaps:
			continue
		_open_rect(rect)
		rooms.append(rect)


## The vault is the open tile farthest from the entry by walking: the end of
## the longest way in, which is what "deep" means in a maze.
func _find_deep() -> void:
	var depth: Dictionary = distances_from(entry)
	var best: int = -1
	for tile: Variant in depth:
		var far: int = int(depth[tile])
		var at: Vector2i = tile
		# Not on the outer corridor ring's edge, so the vault has room to be cut.
		if at.x < 3 or at.y < 3 or at.x > SIZE - 4 or at.y > SIZE - 4:
			continue
		if far > best:
			best = far
			deep = at
	if best < 0:
		deep = entry


## Anything open that the entry cannot reach is rock again. There should be
## none - the rooms sit on the walk - but a maze that lies about its shape is
## worse than one with a little less floor.
func _seal_unreachable() -> void:
	var reach: Dictionary = distances_from(entry)
	for y: int in SIZE:
		for x: int in SIZE:
			var tile := Vector2i(x, y)
			if cell_at(tile) == Cell.OPEN and not reach.has(tile):
				cells[y * SIZE + x] = Cell.WALL
				levels[y * SIZE + x] = WALL_LEVEL


# --- Reading ---------------------------------------------------------------------

## Walking distance of every reachable tile from `tile`. Breadth-first over
## `can_step`, so the answer is the maze's and not a straight line's.
func distances_from(tile: Vector2i) -> Dictionary:
	var dist: Dictionary = {}
	if not in_bounds(tile) or cell_at(tile) == Cell.WALL:
		return dist
	dist[tile] = 0
	var queue: Array[Vector2i] = [tile]
	var head: int = 0
	while head < queue.size():
		var here: Vector2i = queue[head]
		head += 1
		var next_depth: int = int(dist[here]) + 1
		for step: Vector2i in DIRS:
			var next: Vector2i = here + step
			if dist.has(next) or not can_step(here, next):
				continue
			dist[next] = next_depth
			queue.append(next)
	return dist


## How far in a tile is, by walking from the entry; -1 for rock.
func depth_of(tile: Vector2i) -> int:
	return int(_depth.get(tile, -1))


func deepest() -> int:
	return depth_of(deep)


func open_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in SIZE:
		for x: int in SIZE:
			if cells[y * SIZE + x] == Cell.OPEN:
				out.append(Vector2i(x, y))
	return out


## The open tile nearest a world point, for landing a prop where a body fell.
func nearest_open(at: Vector2) -> Vector2i:
	var tile: Vector2i = world_to_tile(at)
	if in_bounds(tile) and cell_at(tile) == Cell.OPEN:
		return tile
	var best: Vector2i = entry
	var best_distance: float = INF
	for candidate: Vector2i in open_tiles():
		var distance: float = tile_to_world(candidate).distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
