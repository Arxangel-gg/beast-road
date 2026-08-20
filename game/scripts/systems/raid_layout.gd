class_name RaidLayout
extends RefCounted

## The procedural terrain of one raid camp: elevation islands, the ramps that
## reach them, and where the chests and keys sit.
##
## Pure geometry, no nodes and no autoloads — the same rule `BattleGrid` follows,
## and for the same reason. Connectivity is the property that decides whether a
## raid is playable at all, and it has to be checkable without standing an arena
## up.
##
## ## What the shape is for
##
## The old arena was a circle of flat ground 700 units across. Nothing in it made
## one part of the camp different from another, so a raid was sixty seconds of
## backing away from whatever spawned.
##
## Raised islands change that in three ways at once. They **block line and
## movement**, so a player can break contact and enemies have to come round. They
## **hold the good loot**, so climbing is a decision made under pressure. And a
## ramp is a **choke**: one tile wide, and whoever holds it holds the island.
##
## Elevation is a gameplay boundary rather than a decoration: nothing crosses a
## cliff, and every raised tile is reachable, which this class guarantees rather
## than hopes for.

const TILE: float = 64.0

## 40 tiles is 2560 units, close to the battlefield's 2880 and nearly four times
## the old circle's diameter. The camp should feel like a place the war host
## actually lives in, not an arena bolted to the side of the game.
const SIZE: int = 40

const HALF_EXTENT: float = float(SIZE) * TILE * 0.5

enum Cell { OPEN, ISLAND, RAMP, WALL }

## Elevation of a tile, 0 for the camp floor.
const MAX_LEVEL: int = 2

var cells: Array[int] = []
var levels: Array[int] = []

## Where chests stand, and which of them are locked.
var chests: Array[Vector2] = []
var locked_chests: Array[bool] = []

## Where the keys for the locked chests are, in the same order as the locked
## ones appear in `chests`.
var keys: Array[Vector2] = []

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	cells.resize(SIZE * SIZE)
	cells.fill(Cell.OPEN)
	levels.resize(SIZE * SIZE)
	levels.fill(0)
	_carve_edge()
	_raise_islands()
	_clear_arrival()
	_cut_ramps()
	_repair_unreachable()
	_place_treasure()


# --- Coordinates -------------------------------------------------------------

static func tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(
		float(tile.x) * TILE - HALF_EXTENT + TILE * 0.5,
		float(tile.y) * TILE - HALF_EXTENT + TILE * 0.5)


static func world_to_tile(at: Vector2) -> Vector2i:
	return Vector2i(
		int(floor((at.x + HALF_EXTENT) / TILE)),
		int(floor((at.y + HALF_EXTENT) / TILE)))


static func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < SIZE and tile.y < SIZE


func cell_at(tile: Vector2i) -> int:
	if not in_bounds(tile):
		return Cell.WALL
	return cells[tile.y * SIZE + tile.x]


func level_at(tile: Vector2i) -> int:
	if not in_bounds(tile):
		return 0
	return levels[tile.y * SIZE + tile.x]


## Whether something standing on `from` may step onto `to`.
##
## The whole movement rule in one place. A step is legal on flat ground, and up
## or down exactly one level *only* where one of the two tiles is a ramp. That is
## what makes a cliff a wall and a ramp a door, and it is why enemies path round
## an island instead of walking up its side.
func can_step(from: Vector2i, to: Vector2i) -> bool:
	if not in_bounds(to) or cell_at(to) == Cell.WALL:
		return false
	var rise: int = level_at(to) - level_at(from)
	if rise == 0:
		return true
	if absi(rise) > 1:
		return false
	return cell_at(from) == Cell.RAMP or cell_at(to) == Cell.RAMP


## Whether a world point is somewhere a body may stand.
func is_open(at: Vector2) -> bool:
	return cell_at(world_to_tile(at)) != Cell.WALL


# --- Generation --------------------------------------------------------------

## A wall ring, so nothing walks off the camp.
func _carve_edge() -> void:
	for i: int in SIZE:
		for tile: Vector2i in [Vector2i(i, 0), Vector2i(i, SIZE - 1),
				Vector2i(0, i), Vector2i(SIZE - 1, i)]:
			cells[tile.y * SIZE + tile.x] = Cell.WALL


## Scatters raised blobs across the camp.
##
## Blobs rather than rectangles, and grown from a seed rather than stamped, so
## two raids never produce the same silhouette. The centre is kept clear: the
## hero arrives there, and arriving inside a cliff is not a surprise anybody
## enjoys.
func _raise_islands() -> void:
	var wanted: int = _rng.randi_range(Balance.RAID_ISLANDS_MIN, Balance.RAID_ISLANDS_MAX)
	var centre := Vector2i(SIZE / 2, SIZE / 2)
	var placed: Array[Vector2i] = []
	var tries: int = 0
	while placed.size() < wanted and tries < 200:
		tries += 1
		var seed := Vector2i(_rng.randi_range(4, SIZE - 5), _rng.randi_range(4, SIZE - 5))
		if Vector2(seed - centre).length() < Balance.RAID_ARRIVAL_CLEARANCE:
			continue
		var crowded: bool = false
		for other: Vector2i in placed:
			if Vector2(seed - other).length() < Balance.RAID_ISLAND_SPACING:
				crowded = true
				break
		if crowded:
			continue
		placed.append(seed)
		_grow_island(seed, 1)
		# A second tier on some of them, drawn smaller and from the same seed, so
		# the silhouette reads as one hill rather than two stacked plates.
		if _rng.randf() < Balance.RAID_SECOND_TIER_CHANCE:
			_grow_island(seed, 2)


## Flattens a disc around the arrival point.
##
## Keeping island *seeds* away from the centre was not enough: a seed five tiles
## out with a radius of six grows straight over it, and the hero then arrives
## standing on a cliff they cannot walk off. Clearing afterwards is unconditional
## and cannot be defeated by a lucky radius roll.
func _clear_arrival() -> void:
	var centre := Vector2i(SIZE / 2, SIZE / 2)
	var reach: int = int(ceil(Balance.RAID_ARRIVAL_CLEARANCE))
	for y: int in range(maxi(centre.y - reach, 1), mini(centre.y + reach + 1, SIZE - 1)):
		for x: int in range(maxi(centre.x - reach, 1), mini(centre.x + reach + 1, SIZE - 1)):
			if Vector2(Vector2i(x, y) - centre).length() > Balance.RAID_ARRIVAL_CLEARANCE:
				continue
			var index: int = y * SIZE + x
			levels[index] = 0
			cells[index] = Cell.OPEN


func _grow_island(seed: Vector2i, level: int) -> void:
	var radius: float = _rng.randf_range(Balance.RAID_ISLAND_RADIUS_MIN,
		Balance.RAID_ISLAND_RADIUS_MAX) / float(level)
	var wobble: float = _rng.randf() * TAU
	for y: int in range(maxi(seed.y - 8, 1), mini(seed.y + 9, SIZE - 1)):
		for x: int in range(maxi(seed.x - 8, 1), mini(seed.x + 9, SIZE - 1)):
			var offset: Vector2 = Vector2(Vector2i(x, y) - seed)
			# A sine on the angle is what turns a circle into a blob without
			# needing a noise texture for a shape this small.
			var edge: float = radius * (1.0 + sin(offset.angle() * 3.0 + wobble) * 0.28)
			if offset.length() <= edge:
				var index: int = y * SIZE + x
				if levels[index] < level:
					levels[index] = level
					cells[index] = Cell.ISLAND


## Cuts ramps so every raised tile can be walked to.
##
## One or two per island, on the side facing the camp floor. A ramp is a single
## tile wide on purpose: it is the choke the whole shape exists to create.
func _cut_ramps() -> void:
	for level: int in range(1, MAX_LEVEL + 1):
		for region: Array in _regions_at(level):
			var wanted: int = 1 if region.size() < Balance.RAID_BIG_ISLAND_TILES \
				else _rng.randi_range(1, 2)
			var edges: Array[Vector2i] = _edge_tiles(region, level)
			if edges.is_empty():
				continue
			for _cut: int in wanted:
				var tile: Vector2i = edges[_rng.randi_range(0, edges.size() - 1)]
				cells[tile.y * SIZE + tile.x] = Cell.RAMP


## Every connected group of tiles at exactly this level.
func _regions_at(level: int) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for y: int in SIZE:
		for x: int in SIZE:
			var tile := Vector2i(x, y)
			if level_at(tile) != level or seen.has(tile):
				continue
			var region: Array[Vector2i] = []
			var queue: Array[Vector2i] = [tile]
			seen[tile] = true
			while not queue.is_empty():
				var here: Vector2i = queue.pop_back()
				region.append(here)
				for step: Vector2i in _NEIGHBOURS:
					var next: Vector2i = here + step
					if in_bounds(next) and not seen.has(next) and level_at(next) == level:
						seen[next] = true
						queue.append(next)
			out.append(region)
	return out


const _NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


## Tiles of a region that touch the level below it.
func _edge_tiles(region: Array, level: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for tile: Vector2i in region:
		for step: Vector2i in _NEIGHBOURS:
			var next: Vector2i = tile + step
			if in_bounds(next) and level_at(next) == level - 1 \
					and cell_at(next) != Cell.WALL:
				out.append(tile)
				break
	return out


## Connects anything the ramps missed, rather than retrying the whole layout.
##
## The generator can strand ground in three ways: a tier whose only edge was
## swallowed by its own second tier, a blob grown flush against the wall ring, or
## a ramp that happened to be cut on the far side of a pinch. Regenerating until
## a seed happens to work is how a generator becomes a hang, so each stranded
## region is *repaired* instead.
##
## A ramp first, because a ramp preserves the shape the generator drew. Flatten
## only when no legal ramp exists, and flatten the whole region to its lowest
## neighbour so it cannot become a pit that is equally unreachable — which is the
## bug the first version of this had, lowering tiles one level per pass and
## producing level-0 hollows inside level-1 islands.
func _repair_unreachable() -> void:
	for _pass: int in 12:
		var reached: Dictionary = _walk_from_centre()
		var stranded: Array[Vector2i] = []
		for y: int in SIZE:
			for x: int in SIZE:
				var tile := Vector2i(x, y)
				if cell_at(tile) != Cell.WALL and not reached.has(tile):
					stranded.append(tile)
		if stranded.is_empty():
			return
		if not _bridge_one(stranded, reached):
			_flatten_region(stranded[0])


## Cuts a ramp between a stranded tile and reachable ground one level away.
func _bridge_one(stranded: Array[Vector2i], reached: Dictionary) -> bool:
	for tile: Vector2i in stranded:
		for step: Vector2i in _NEIGHBOURS:
			var next: Vector2i = tile + step
			if not in_bounds(next) or cell_at(next) == Cell.WALL:
				continue
			if not reached.has(next):
				continue
			if absi(level_at(next) - level_at(tile)) > 1:
				continue
			# Either side may carry the ramp; the higher one keeps the silhouette
			# tidier, since a ramp on the floor reads as a hole in it.
			var carry: Vector2i = tile if level_at(tile) >= level_at(next) else next
			cells[carry.y * SIZE + carry.x] = Cell.RAMP
			return true
	return false


## Lowers a whole connected region to the level of its lowest neighbour.
func _flatten_region(seed: Vector2i) -> void:
	var level: int = level_at(seed)
	var region: Array[Vector2i] = []
	var seen: Dictionary = {seed: true}
	var queue: Array[Vector2i] = [seed]
	var lowest: int = level
	while not queue.is_empty():
		var here: Vector2i = queue.pop_back()
		region.append(here)
		for step: Vector2i in _NEIGHBOURS:
			var next: Vector2i = here + step
			if not in_bounds(next) or cell_at(next) == Cell.WALL:
				continue
			if level_at(next) == level and not seen.has(next):
				seen[next] = true
				queue.append(next)
			elif level_at(next) < lowest:
				lowest = level_at(next)
	for tile: Vector2i in region:
		var index: int = tile.y * SIZE + tile.x
		levels[index] = lowest
		cells[index] = Cell.OPEN if lowest == 0 else Cell.ISLAND


## Every tile walkable from the arrival point, obeying `can_step`.
func _walk_from_centre() -> Dictionary:
	var start := Vector2i(SIZE / 2, SIZE / 2)
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var here: Vector2i = queue.pop_back()
		for step: Vector2i in _NEIGHBOURS:
			var next: Vector2i = here + step
			if seen.has(next) or not can_step(here, next):
				continue
			seen[next] = true
			queue.append(next)
	return seen


## Reachable tiles, for callers that want to place something walkable.
func reachable_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key: Variant in _walk_from_centre():
		out.append(key)
	return out


# --- Treasure ----------------------------------------------------------------

## Chests on the high ground, keys on the floor.
##
## Locked chests go as high as the camp offers, because a locked chest is the
## one worth a detour and the climb should be part of it. Their keys are placed
## on ground the player passes anyway — a key hidden on *another* island turns
## one detour into two, which is a chore rather than a decision.
func _place_treasure() -> void:
	var reachable: Dictionary = _walk_from_centre()
	var high: Array[Vector2i] = []
	var low: Array[Vector2i] = []
	var centre := Vector2i(SIZE / 2, SIZE / 2)
	for key: Variant in reachable:
		var tile: Vector2i = key
		if cell_at(tile) == Cell.RAMP:
			continue
		if Vector2(tile - centre).length() < Balance.RAID_ARRIVAL_CLEARANCE:
			continue
		if level_at(tile) > 0:
			high.append(tile)
		else:
			low.append(tile)

	var wanted: int = _rng.randi_range(Balance.RAID_CHESTS_MIN, Balance.RAID_CHESTS_MAX)
	var taken: Array[Vector2i] = []
	for index: int in wanted:
		# Locked ones prefer height; the rest fill in wherever there is room.
		var lock: bool = index < Balance.RAID_LOCKED_CHESTS and not high.is_empty()
		var pool: Array[Vector2i] = high if lock and not high.is_empty() else low
		if pool.is_empty():
			pool = low if not low.is_empty() else high
		if pool.is_empty():
			break
		var tile: Vector2i = _draw_spaced(pool, taken, Balance.RAID_CHEST_SPACING)
		taken.append(tile)
		chests.append(tile_to_world(tile))
		locked_chests.append(lock)
		if lock:
			var key_tile: Vector2i = _draw_spaced(low, taken, Balance.RAID_CHEST_SPACING)
			taken.append(key_tile)
			keys.append(tile_to_world(key_tile))


## Draws a tile from `pool` that is not crowding anything already taken.
func _draw_spaced(pool: Array[Vector2i], taken: Array[Vector2i], spacing: float) -> Vector2i:
	var best: Vector2i = pool[_rng.randi_range(0, pool.size() - 1)]
	for _try: int in 24:
		var tile: Vector2i = pool[_rng.randi_range(0, pool.size() - 1)]
		var clear: bool = true
		for other: Vector2i in taken:
			if Vector2(tile - other).length() < spacing:
				clear = false
				break
		if clear:
			return tile
	return best
