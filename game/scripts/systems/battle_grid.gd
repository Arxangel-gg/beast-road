class_name BattleGrid
extends RefCounted

## The battlefield's tile grid and the four roads laid across it (GDD §13).
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

## 30x30 tiles at 64 units is a 1920x1920 field — close to the old arena, and a
## whole number of tiles across so the roads can be authored on tile boundaries.
const SIZE: int = Balance.GRID_TILES
const TILE: float = 64.0

## A tower covers 2x2 tiles. Its anchor is the top-left tile of that square.
const FOOTPRINT: int = Balance.TOWER_FOOTPRINT_TILES

## Half the field in world units, used to move the origin to the centre.
const HALF_EXTENT: float = float(SIZE) * TILE * 0.5

## The town's unbuildable block, in tiles either side of the origin.
##
## 1 gives a 3x3 block, 192 units across, against a TOWN_RADIUS of 160 - so it
## covers the town and no more. It was 2 (a 5x5 block) and, with four roads
## converging on the origin as well, that left nothing buildable inside six tiles
## of the gate: the last line of defence was the one place the player could not
## defend. Measured with tools/gate_probe.gd.
const TOWN_TILES: int = 1

## Tiles either side of a road's centre line, so the carriageway is
## 2*ROAD_WIDTH+1 tiles across — 3 tiles, 192 units. Sized to LANE_WIDTH (120)
## plus the +-55 units enemies drift, with a tile spare.
##
## It was 2 (a 5-tile road) and that quietly cost the whole feature: two legs of
## a U-bend four tiles apart, each five tiles wide, leave no pocket between them
## at all. The bend was there and there was nowhere to build in it.
const ROAD_WIDTH: int = 1

enum Cell { OPEN, ROAD, TOWN, BORDER }

var cells: Array[int] = []

## One polyline per lane, in world space, ordered from the spawn edge to the
## town. Enemies walk these; the U-bend is in the shape, not in a special case.
var lane_paths: Array = []


func _init() -> void:
	cells.resize(SIZE * SIZE)
	cells.fill(Cell.OPEN)
	_carve_border()
	_carve_town()
	for lane: int in Balance.LANE_COUNT:
		var path: PackedVector2Array = _build_lane_path(lane)
		lane_paths.append(path)
		_carve_road(path)


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


# --- Road shape --------------------------------------------------------------

## The lane's polyline, from the map edge to the town gate, with one U-bend.
##
## Authored in the lane's own frame — x runs along the road toward the town, y
## runs across it — and then rotated into place. One shape, four roads, and the
## bend lands in the same relative spot on each so no lane is quietly easier.
##
## The bend is a there-and-back detour: the road runs in, turns across, doubles
## back away from the town, turns across again, then resumes. That encloses a
## pocket on one side, which is the point — a tower in the pocket covers both
## legs, so position is worth as much as range (GDD §13).
func _build_lane_path(lane: int) -> PackedVector2Array:
	var forward: Vector2 = lane_vector(lane)
	var across: Vector2 = forward.orthogonal()

	# Distances out from the town along the road, and the sideways depth of the
	# bend. Tile multiples so the road lands on tile boundaries.
	# The bend runs from 7 tiles out to 13, and 8 deep.
	#
	# Both ends are load bearing and both were wrong once. The *inner* end sat at
	# 5: its return leg is a 3-tile wall across the lane axis, and that left no
	# ground at all between it and the gate, so the last line of defence was
	# undefendable. Pushing it to 7 fixed that and collapsed the pocket to a
	# single tile, because the pocket's width is the gap between the two legs
	# minus the three tiles they occupy - so the *outer* end had to move too.
	#
	# 13 - 7 - 3 leaves three tiles of interior width and eight of depth: room for
	# four towers in the pocket, and room for four more inside the gate.
	var t: float = TILE
	var points_local: Array[Vector2] = [
		Vector2(14.0 * t, 0.0),        # spawn edge
		Vector2(13.0 * t, 0.0),        # run in
		Vector2(13.0 * t, 8.0 * t),    # turn across
		Vector2(7.0 * t, 8.0 * t),     # double back toward the town
		Vector2(7.0 * t, 0.0),         # turn back across
		Vector2(0.0, 0.0),             # the gate
	]

	# The shape above is one there-and-back detour. Asserted against the constant
	# rather than merely described by it, so the two cannot drift: a second bend
	# would need six more points and this would catch a half-made edit.
	assert(_bends_in(points_local) == Balance.ROAD_BEND_COUNT,
		"lane shape no longer matches Balance.ROAD_BEND_COUNT")

	var path: PackedVector2Array = []
	for local: Vector2 in points_local:
		path.append(forward * local.x + across * local.y)
	return path


## How many times the road leaves the lane axis and comes back to it.
static func _bends_in(points: Array[Vector2]) -> int:
	var away: int = 0
	var previous: bool = false
	for point: Vector2 in points:
		var off_axis: bool = absf(point.y) > 0.001
		if off_axis and not previous:
			away += 1
		previous = off_axis
	return away


## Marks every tile the road covers, so nothing can be built on it.
## The final approach narrows to a causeway.
##
## Four roads three tiles wide converging on one point leave only thin diagonal
## wedges near the gate: measured, two buildable anchors per ring inside seven
## tiles. The last line of defence was the one place with nowhere to build.
##
## Narrowing the last leg to a single tile frees a tile either side of all four
## approaches, and it is better design as well as more room - a road that
## narrows at the gate is a chokepoint, which is exactly what the ground closest
## to the town should be.
func _carve_road(path: PackedVector2Array) -> void:
	for i: int in path.size() - 1:
		var final_leg: bool = i == path.size() - 2
		_carve_segment(path[i], path[i + 1], 0 if final_leg else ROAD_WIDTH)


func _carve_segment(from: Vector2, to: Vector2, half: int = ROAD_WIDTH) -> void:
	var span: float = from.distance_to(to)
	if span <= 0.0:
		return
	# Step at half a tile so a diagonal segment cannot leave gaps between the
	# tiles it passes through.
	var steps: int = int(ceil(span / (TILE * 0.5)))
	for step: int in steps + 1:
		var at: Vector2 = from.lerp(to, float(step) / float(steps))
		var centre: Vector2i = world_to_tile(at)
		for dx: int in range(-half, half + 1):
			for dy: int in range(-half, half + 1):
				var tile: Vector2i = centre + Vector2i(dx, dy)
				if in_bounds(tile) and cells[tile.y * SIZE + tile.x] == Cell.OPEN:
					cells[tile.y * SIZE + tile.x] = Cell.ROAD


func _carve_town() -> void:
	var centre: Vector2i = world_to_tile(Vector2.ZERO)
	var reach: int = TOWN_TILES
	for dx: int in range(-reach, reach + 1):
		for dy: int in range(-reach, reach + 1):
			var tile: Vector2i = centre + Vector2i(dx, dy)
			if in_bounds(tile):
				cells[tile.y * SIZE + tile.x] = Cell.TOWN


## A one-tile frame. Towers built flush against the edge would be half off the
## visible field at battlefield zoom.
func _carve_border() -> void:
	for i: int in SIZE:
		cells[i] = Cell.BORDER
		cells[(SIZE - 1) * SIZE + i] = Cell.BORDER
		cells[i * SIZE] = Cell.BORDER
		cells[i * SIZE + SIZE - 1] = Cell.BORDER


## The world centre of the open pocket a lane's U-bend encloses.
##
## The bend exists to create somewhere worth building; naming that place lets the
## check assert it stays open and lets the interface point at it.
func lane_pocket_centre(lane: int) -> Vector2:
	var path: PackedVector2Array = lane_paths[lane]
	if path.size() < 6:
		return lane_vector(lane) * (10.0 * TILE)
	# Derived from the road itself rather than restated as numbers. The bend has
	# moved twice; both times a hardcoded centre was left pointing at where the
	# pocket used to be, which put it on the carriageway and failed placement.
	#
	# The pocket is the area the detour encloses: midway between the two legs
	# that run across the lane, and midway up the depth they reach.
	var inner_leg: Vector2 = path[path.size() - 2]
	var outer_leg: Vector2 = path[1]
	var crossbar: Vector2 = path[2]
	return (inner_leg + outer_leg) * 0.5 + (crossbar - outer_leg) * 0.5


# --- Path queries ------------------------------------------------------------

## Total length of a lane's road, for pressure and time-to-breach maths that used
## to assume a straight line from spawn to town.
func lane_length(lane: int) -> float:
	var path: PackedVector2Array = lane_paths[lane]
	var total: float = 0.0
	for i: int in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	return total


## How far along the road a point is, as remaining distance to the town. Used by
## lane pressure, which cares about who is closest to breaching rather than who
## is nearest in a straight line - and with a U-bend those are different answers.
func distance_to_town_along(lane: int, at: Vector2) -> float:
	var path: PackedVector2Array = lane_paths[lane]
	# Walked from the gate backwards: `behind` is the road length from the town
	# to the *end* of the segment under test. Kept separate from the answer,
	# because a running total that doubles as the result gets overwritten by
	# every segment that happens to be nearer.
	var behind: float = 0.0
	var nearest_off_road: float = INF
	var answer: float = 0.0
	for i: int in range(path.size() - 2, -1, -1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(at, a, b)
		var off_road: float = at.distance_to(closest)
		if off_road < nearest_off_road:
			nearest_off_road = off_road
			answer = behind + closest.distance_to(b)
		behind += a.distance_to(b)
	return answer
