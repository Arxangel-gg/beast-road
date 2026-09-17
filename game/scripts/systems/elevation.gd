class_name Elevation
extends Node2D

## **Ground that is not flat, for every place in this game that has a step in
## it.**
##
## Owner, 2026-09-17: the Hold must not be *"3 straight elevation steps that
## stretch horizontally"* but a place laid out like Nahantu, and *"the stair
## solution should also apply to dungeons with the correct adaptations for each
## environment"*. Both of those are the same object: a **height field** with a
## kit of art hung off it, rather than a list of horizontal edges with a list of
## stairs beside it.
##
## ## Why a field and not a table
##
## The Hold's first cut held `TERRACE_AT` - the y of each edge - and `STAIRS` -
## the stretch of each edge you were allowed to cross. Two tables that have to
## agree, and every shape they can describe is a band across the screen. Worse,
## a stair authored outside the stretch people actually walk strands a whole
## third of the yard and *every number in both tables still reads as correct*.
##
## Here the ground is a character map, a flight is a cell in it, and the two
## cannot disagree because a flight reads its own low and high side off its own
## neighbours. **The map is the only authority.**
##
## ## A step is legal by its slope
##
## `height_at` is continuous - flat inside a flat cell, ramped across a flight -
## so there is no rule about stairs anywhere in this file. A move is allowed
## when the ground it climbs is gentle for the distance it covers, which lets a
## flight through at two thirds and refuses a cliff at sixteen. One function,
## and a new shape of stair needs no change to it.
##
## ## Only the south face is drawn, and that is not a shortcut
##
## The camera looks down and slightly along, so a south-facing bank is the only
## face a player can ever see; a north one would be drawn behind the shelf that
## owns it. The raid camp reached that conclusion on 2026-09-13. East and west
## edges get a narrow side strip instead - enough to give a slab thickness,
## which is what stops a plateau reading as paint on flat earth.
##
## ## The kit is the environment
##
## Nothing here knows what soil looks like. A caller hands over the ground
## sheet, the bank, the two stair pieces and the tints; the Hold hands jungle
## earth, a rift hands cut stone. One authored piece used twice cannot disagree
## with itself, which is the argument the Hold's bank was already borrowed from
## the raid under.

## Void, and the one thing that is not ground you may stand on.
const VOID: String = " "
const WATER: String = "~"

## Which way a flight climbs. The **high** side is the neighbour this vector
## points away from, so the low side is `cell + WAY[mark]`.
const WAY: Dictionary = {
	"^": Vector2i(0, 1), "v": Vector2i(0, -1),
	"<": Vector2i(1, 0), ">": Vector2i(-1, 0),
}

const LEVEL: Dictionary = {".": 0, "1": 1, "2": 2, "3": 3}

## How much height a step may gain for the ground it covers.
##
## A flight climbs one rise across one cell; a cliff climbs the same across
## nothing at all. Anything between those two is a decision about how steep a
## place may be, and this is the one place it is made.
const MAX_SLOPE: float = 0.95

## How far a shelf's own ground spills over its lip before it fades into the
## face, and how far the shade it casts reaches across the ground below.
##
## Both are the difference between a shelf that is standing on something and one
## that was pasted over it, and both are small on purpose: a wide fade reads as
## fog rather than as earth.
const LIP: float = 13.0
const FOOT_SHARE: float = 0.34
const FOOT_SHADE: float = 0.34

## **The pond sheet is the road's, and the road is a brighter place.**
##
## A pool in the Hold is drawn with the same jungle pond tiles every Act I road
## digs, which is what stops two paintings of water disagreeing - but those are
## graded for ground a third brighter than a shaded valley, and photographed
## here the wet sand ring around the pool was the lightest thing on the screen.
## Tinted at the draw rather than graded on disk, because the file belongs to
## the road as much as to the Hold.
const SHORE_TINT: Color = Color(0.56, 0.62, 0.64)

## How strongly the shelf's own ground is worn back over the pool's outer ring.
## Enough that the sheet's rim stops being a line, not so much that the shore
## disappears - a pool with no bank is a hole in the ground.
const SHORE_BLEND: Color = Color(1.0, 1.0, 1.0, 0.62)

## One tile on a Wang sheet, and how many across it is.
const TILE_PX: int = 64
const SHEET_ACROSS: int = 4

var _rows: PackedStringArray = []
var _cell: float = 96.0
var _rise: float = 64.0
var _origin: Vector2 = Vector2.ZERO

var _soil: Texture2D = null
var _bank: Texture2D = null
var _stair_north: Texture2D = null
var _stair_side: Texture2D = null

## One Wang sheet per shelf: the transition *onto* that level from the one
## below. A level with no sheet falls back to a plain slab of the soil, which
## is what every shelf was before these existed.
var _tiles: Dictionary = {}

## The Wang sheet a pool is drawn with - a region's own pond tiles, so the
## Hold's water is the water the road already has.
var _pond: Texture2D = null
var _soil_tint: Color = Color.WHITE
var _bank_tint: Color = Color(0.62, 0.62, 0.62)
## Water is the ground's own sheet stained, so a pool has a bed rather than
## being a hole. Lifted well above one because a modulate multiplies and the
## soil it stains is dark moss.
var _water_tint: Color = Color(0.62, 1.05, 1.28, 0.94)
var _overscan: float = 620.0

## The canvas being painted into for the current pass. Set by `paint`.
var _on: CanvasItem = null


## The ground itself. Every row must be the same length; a ragged map is a map
## whose right-hand edge is wherever the shortest line happened to stop.
func set_map(rows: PackedStringArray, cell: float, rise: float) -> void:
	_rows = rows
	_cell = maxf(cell, 1.0)
	_rise = maxf(rise, 1.0)
	_origin = Vector2(-float(columns()) * _cell * 0.5,
		-float(_rows.size()) * _cell * 0.5)
	queue_redraw()


## The art. Handed in rather than loaded, so this file knows nothing about where
## it is standing - the rule `PenYard` was rebuilt under on the same day.
func set_kit(soil: Texture2D, bank: Texture2D, stair_north: Texture2D,
		stair_side: Texture2D, soil_tint: Color, bank_tint: Color) -> void:
	_soil = soil
	_bank = bank
	_stair_north = stair_north
	_stair_side = stair_side
	_soil_tint = soil_tint
	_bank_tint = bank_tint
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	queue_redraw()


## **The sheet that draws the edge of a shelf.**
##
## A 4x4 of `TILE_PX` tiles indexed by its corners, upper terrain first - the
## rule `PondTiles` and `DungeonTiles` already read, packed by
## `tools/install_hold_tiles.py`. Owner, 2026-09-17: a shelf painted as a quad
## of one texture has a hard edge *by construction*, and no amount of tinting
## fixes that. The transition is art now.
func set_tiles(level: int, sheet: Texture2D) -> void:
	if sheet == null:
		_tiles.erase(level)
	else:
		_tiles[level] = sheet
	queue_redraw()


## The pond sheet, or null for a place with no water in it.
func set_water(sheet: Texture2D) -> void:
	_pond = sheet
	queue_redraw()


## How far the valley floor keeps going past the last cell. The picture has no
## edge even though the walking does - the rule the deep's rock is cut under.
func set_overscan(units: float) -> void:
	_overscan = maxf(units, 0.0)
	queue_redraw()


func columns() -> int:
	return 0 if _rows.is_empty() else _rows[0].length()


func row_count() -> int:
	return _rows.size()


func cell_size() -> float:
	return _cell


func rise() -> float:
	return _rise


## The rectangle the map covers, in the coordinates a caller places things at.
func extent() -> Rect2:
	return Rect2(_origin, Vector2(float(columns()) * _cell,
		float(_rows.size()) * _cell))


## Which cell a point stands in.
func cell_at(at: Vector2) -> Vector2i:
	var local: Vector2 = (at - _origin) / _cell
	return Vector2i(int(floor(local.x)), int(floor(local.y)))


func mark(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= _rows.size():
		return VOID
	var row: String = _rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return VOID
	return row[cell.x]


## The middle of a cell, in the caller's coordinates.
func cell_middle(cell: Vector2i) -> Vector2:
	return _origin + (Vector2(cell) + Vector2(0.5, 0.5)) * _cell


## **How high the ground is, in levels, continuously.**
##
## Flat inside a flat cell and ramped across a flight, so nothing above this
## needs a rule about stairs. A point off the map answers with the valley floor
## rather than with nothing, because the picture continues out there.
func height_at(at: Vector2) -> float:
	var cell: Vector2i = cell_at(at)
	var ch: String = mark(cell)
	if LEVEL.has(ch):
		return float(LEVEL[ch])
	if WAY.has(ch):
		var way: Vector2i = WAY[ch]
		var low: float = float(LEVEL.get(mark(cell + way), 0))
		var local: Vector2 = (at - _origin) / _cell - Vector2(cell)
		# The fraction of the way from the low edge toward the high one.
		var along: float = local.x if way.x != 0 else local.y
		if (way.x + way.y) > 0:
			along = 1.0 - along
		return low + clampf(along, 0.0, 1.0)
	if ch == WATER:
		return float(LEVEL.get(_around(cell), 0))
	return 0.0


## The level of whatever a pool is sunk into, so water does not read as a hole
## in the hillside.
func _around(cell: Vector2i) -> String:
	for step: Vector2i in [Vector2i(0, -1), Vector2i(0, 1),
			Vector2i(-1, 0), Vector2i(1, 0)]:
		var ch: String = mark(cell + step)
		if LEVEL.has(ch):
			return ch
	return "."


## How far above its own place a point is *drawn*. Negative is up the screen.
##
## The flat plane is what everything measures reach, focus and errands in; this
## is only where it is painted, which is what keeps every other system in this
## project from having to learn that the ground has steps in it.
func lift_at(at: Vector2) -> float:
	return -height_at(at) * _rise


## Whether a point is ground a person may stand on at all.
func is_ground(at: Vector2) -> bool:
	var ch: String = mark(cell_at(at))
	return LEVEL.has(ch) or WAY.has(ch)


## Whether the ground between two points may be walked.
##
## **Slope, not stairs.** A flight gains one rise across one cell and passes; a
## cliff gains the same across a hand's width and does not. Nothing here knows
## what a stair is, which is why a new shape of one needs no change here.
func step_is_legal(from: Vector2, to: Vector2) -> bool:
	if not is_ground(to):
		return false
	var run: float = from.distance_to(to)
	if run <= 0.001:
		return true
	# **Walked, not measured end to end.** A cliff is a discontinuity, so a
	# single long step across one reads as a gentle average: the middle of a
	# level-2 cell and the middle of the level-1 cell south of it are a whole
	# cell apart and one rise up, which is exactly the slope a flight has. The
	# gate found that on its first run - 40 of 46 cliffs walkable - and a dash
	# would have found it in play. Sampling finely enough that no sub-step can
	# straddle a boundary unnoticed is what makes the rule mean what it says.
	var steps: int = maxi(1, int(ceil(run / (_cell * 0.25))))
	var last: Vector2 = from
	var was: float = height_at(from)
	for step: int in steps:
		var here: Vector2 = from.lerp(to, float(step + 1) / float(steps))
		var now: float = height_at(here)
		if absf(now - was) * _rise > last.distance_to(here) * MAX_SLOPE:
			return false
		last = here
		was = now
	return true


## A step that gives ground sideways rather than sticking against a bank.
func slide(from: Vector2, to: Vector2) -> Vector2:
	if step_is_legal(from, to):
		return to
	var step: Vector2 = to - from
	for guess: Vector2 in [Vector2(step.x, 0.0), Vector2(0.0, step.y),
			Vector2(step.x, 0.0) * 0.5, Vector2(0.0, step.y) * 0.5]:
		if guess.length_squared() < 0.0001:
			continue
		if step_is_legal(from, from + guess):
			return from + guess
	return from


## The nearest point a person may stand on, for putting something down.
##
## A station authored a cell into the hillside is the failure this whole file
## exists to prevent, and it is invisible in a table - so rather than trusting
## the author, anything placed off the ground is walked back onto it.
func settle(at: Vector2) -> Vector2:
	if is_ground(at):
		return at
	for ring: int in range(1, 10):
		for step: int in 16:
			var angle: float = TAU * float(step) / 16.0
			var guess: Vector2 = at + Vector2(cos(angle), sin(angle)) \
				* float(ring) * _cell * 0.7
			if is_ground(guess):
				return guess
	return at


# --- the picture --------------------------------------------------------------


## **Painted into somebody else's canvas.**
##
## The ground has to be underneath the place standing on it, and a Godot child
## draws after its parent - so this is handed the canvas rather than owning one.
## It is also what a rift needs, where the deep already has a tile layer and the
## banks and flights belong in it rather than beside it.
##
## Its own `_draw` still works, so the node can be stood up alone.
func _draw() -> void:
	paint(self)


func paint(into: CanvasItem) -> void:
	if _rows.is_empty():
		return
	_on = into
	_draw_floor()
	var deepest: int = 0
	for level: Variant in LEVEL.values():
		deepest = maxi(deepest, int(level))
	# Lowest first, so a shelf covers the face of the shelf behind it exactly
	# the way earth does. Run the other way and the top slab paints over
	# everything below it, which is what the Hold's first cut did.
	for level: int in range(deepest + 1):
		_draw_level(level)
		_draw_faces(level)
	_draw_water()
	_draw_flights()


## The valley the map sits in: one sheet, out past the last cell, so the picture
## has no edge. What makes it read as hillside rather than as more yard is the
## caller's own rim shadow.
func _draw_floor() -> void:
	if _soil == null:
		return
	_on.draw_texture_rect(_soil, extent().grow(_overscan), true,
		_soil_tint.darkened(0.26))


## **A shelf, laid as Wang tiles on a dual grid.**
##
## A node sits on the corner four cells share, and which of the four stand at
## this level or above decides the tile - so the rim of a shelf is the authored
## transition art rather than the edge of a rectangle. That is the whole of what
## the owner meant by *"tilesets that don't just have hard edges"*, and it is
## the machinery the ponds and the deep already run on.
##
## With no sheet for a level it falls back to plain slabs of soil, which is what
## every shelf was before, so a missing sheet is a duller Hold and never a hole.
func _draw_level(level: int) -> void:
	if _soil == null:
		return
	var sheet: Texture2D = _tiles.get(level, null) as Texture2D
	if sheet == null:
		var quads: Array[Rect2] = []
		for y: int in _rows.size():
			for x: int in columns():
				if int(LEVEL.get(mark(Vector2i(x, y)), -1)) != level:
					continue
				quads.append(_slab(Vector2i(x, y), float(level)))
		if not quads.is_empty():
			_paint(quads, _soil, _soil_tint)
		return
	var lift: float = float(level) * _rise
	for j: int in _rows.size() + 1:
		for i: int in columns() + 1:
			var nw: bool = _at_least(Vector2i(i - 1, j - 1), level)
			var ne: bool = _at_least(Vector2i(i, j - 1), level)
			var sw: bool = _at_least(Vector2i(i - 1, j), level)
			var se: bool = _at_least(Vector2i(i, j), level)
			if not (nw or ne or sw or se):
				continue
			var index: int = (8 if nw else 0) + (4 if ne else 0) 				+ (2 if sw else 0) + (1 if se else 0)
			var where := Rect2(
				_origin.x + float(i) * _cell - _cell * 0.5,
				_origin.y + float(j) * _cell - _cell * 0.5 - lift,
				_cell + 0.5, _cell + 0.5)
			# **No mirroring here, and that is a finding rather than a
			# preference.** The first cut turned the all-upper tile about from
			# its own place to break up the grain, by giving the destination
			# rect a negative width or height - and `draw_texture_rect_region`
			# draws *nothing at all* for a negative rect, so three nodes in four
			# were simply skipped and the valley floor showed through in a
			# lattice of dark rectangles across the whole plaza.
			#
			# The grain it was there to break is the *art's* problem and was
			# fixed in the art: an interior tile is plain ground with no motif
			# in it, which is the only thing that makes a Wang set tile cleanly
			# however many times it is drawn.
			_on.draw_texture_rect_region(sheet, where, _tile_rect(index),
				_soil_tint)


## Whether a cell stands at this level or higher. A flight counts as its own
## high end, so the ground does not tear away from under a staircase.
func _at_least(cell: Vector2i, level: int) -> bool:
	return _standing(cell) >= level and _standing(cell) > -2


func _tile_rect(index: int) -> Rect2:
	return Rect2(float(index % SHEET_ACROSS) * float(TILE_PX),
		float(index / SHEET_ACROSS) * float(TILE_PX),
		float(TILE_PX), float(TILE_PX))


## One cell's slab, lifted to its own level.
func _slab(cell: Vector2i, level: float) -> Rect2:
	var at: Vector2 = _origin + Vector2(cell) * _cell
	# A whisker of overlap, because two quads that share an edge exactly show
	# the background through it once the view is scaled.
	return Rect2(at.x - 0.5, at.y - level * _rise - 0.5,
		_cell + 1.0, _cell + 1.0)


## Every south face at this level, and a narrow side on the east and west edges
## so a slab has thickness rather than being a cut-out.
## Every south face at this level, the narrow sides that give a slab its
## thickness, and the two things that stop a shelf reading as a sticker.
##
## **A hard join is what "no smoothing transitions between the ground changes"
## meant** (owner, 2026-09-17). The bank art was fine and the *joins* at both
## ends of it were ruled lines: the material stopped dead at the top edge and
## the ground below it was untouched at the bottom. Two feathered passes fix
## both, and neither is a texture:
##
## - a **lip**, where the upper shelf's own ground spills a little way over its
##   edge and fades out, so the top of a bank is grass giving way rather than a
##   cut; and
## - a **contact shadow** on the lower ground at the foot, strongest against the
##   face and gone a stride out, which is the single strongest cue that one
##   slab is standing on another rather than floating over it.
func _draw_faces(level: int) -> void:
	if _bank == null or level <= 0:
		return
	var fronts: Array[Rect2] = []
	var sides: Array[Rect2] = []
	var feet: Array[Rect2] = []
	var lips: Array[Rect2] = []
	for y: int in _rows.size():
		for x: int in columns():
			var cell := Vector2i(x, y)
			if _standing(cell) != level:
				continue
			var at: Vector2 = _origin + Vector2(cell) * _cell
			var top: float = at.y - float(level) * _rise
			var south: int = _standing(cell + Vector2i(0, 1))
			if south < level and south > -2:
				var drop: float = float(level - maxi(south, 0)) * _rise
				fronts.append(Rect2(at.x - 0.5, top + _cell,
					_cell + 1.0, drop + 1.0))
				lips.append(Rect2(at.x - 0.5, top + _cell - LIP,
					_cell + 1.0, LIP))
				feet.append(Rect2(at.x - 0.5, top + _cell + drop,
					_cell + 1.0, _cell * FOOT_SHARE))
			for side: int in [-1, 1]:
				var over: int = _standing(cell + Vector2i(side, 0))
				if over >= level:
					continue
				var thick: float = _cell * 0.17
				var edge: float = at.x if side < 0 else at.x + _cell - thick
				sides.append(Rect2(edge, top + _cell * 0.84, thick,
					float(level - maxi(over, 0)) * _rise + _cell * 0.18))
	if not fronts.is_empty():
		_paint(fronts, _bank, _bank_tint)
	# **The sides are shade, not masonry.** Drawn with the bank sheet they came
	# out as narrow barber poles down the flank of every slab - a 16-unit strip
	# stretched from a 64-pixel face is diagonal stripes, and it read as a row
	# of decorative posts. What an east or west edge needs is the *thickness* of
	# the earth, which at this angle is a dark line and nothing else.
	for side: Rect2 in sides:
		_on.draw_rect(side, Color(0.0, 0.0, 0.0, 0.42), true)
	# The shelf's own ground, spilling over its lip and fading into the face.
	var sheet: Texture2D = _tiles.get(level, _soil) as Texture2D
	if sheet != null and not lips.is_empty():
		_feather(lips, _soil_tint, true, sheet)
	# And the shade it casts on the ground it stands on.
	if not feet.is_empty():
		_feather(feet, Color(0.0, 0.0, 0.0, FOOT_SHADE), false, null)


## A band of quads that fades out along its own height.
##
## `from_top` keeps the solid edge at the top and fades downward, which is what
## a lip does; the other way round is what a contact shadow does. One colour for
## the whole shape is what a hard edge *is* - the finding this project has now
## rebuilt six things on - so the alpha lives on the vertices.
##
## A textured band wears the sheet in world coordinates, so the ground spilling
## over an edge is the same ground it spilled from rather than a smear of it.
func _feather(bands: Array[Rect2], tint: Color, from_top: bool,
		sheet: Texture2D) -> void:
	var size := Vector2(1.0, 1.0)
	if sheet != null:
		size = Vector2(maxf(float(sheet.get_width()), 1.0),
			maxf(float(sheet.get_height()), 1.0))
	var clear := Color(tint.r, tint.g, tint.b, 0.0)
	var points: PackedVector2Array = []
	var colours: PackedColorArray = []
	var uvs: PackedVector2Array = []
	var indices: PackedInt32Array = []
	for band: Rect2 in bands:
		var base: int = points.size()
		var corners: Array[Vector2] = [band.position,
			Vector2(band.end.x, band.position.y), band.end,
			Vector2(band.position.x, band.end.y)]
		for index: int in 4:
			var corner: Vector2 = corners[index]
			var solid: bool = (index < 2) == from_top
			points.append(corner)
			colours.append(tint if solid else clear)
			uvs.append(Vector2(corner.x / size.x, corner.y / size.y))
		indices.append_array([base, base + 1, base + 2,
			base, base + 2, base + 3])
	if indices.is_empty():
		return
	var rid: RID = RID() if sheet == null else sheet.get_rid()
	RenderingServer.canvas_item_add_triangle_array(_on.get_canvas_item(),
		indices, points, colours, uvs, PackedInt32Array(),
		PackedFloat32Array(), rid)


## What level a cell reads as when it is being drawn: a flight stands at its own
## high end, so the ground beside it is not cut away from under the steps.
func _standing(cell: Vector2i) -> int:
	var ch: String = mark(cell)
	if LEVEL.has(ch):
		return int(LEVEL[ch])
	if WAY.has(ch):
		return int(LEVEL.get(mark(cell + WAY[ch]), 0)) + 1
	if ch == WATER:
		return int(LEVEL.get(_around(cell), 0))
	return -2


## **Water, drawn as water.**
##
## Owner, 2026-09-17, on the first photograph of this: *"bugs and defects like
## the blue tiles"* - and they were exactly that, a flat blue rectangle per
## cell, which is the hard-edge fault one more time in the one place a hard edge
## is most obviously wrong.
##
## A pool is the same Wang machinery every pond on the road already uses, on the
## same dual grid the shelves are laid on, so the shore is authored art. With no
## sheet it falls back to a *feathered* stain of the ground's own soil rather
## than to a rectangle: duller, never a blue box.
func _draw_water() -> void:
	var wet: Array[Vector2i] = []
	for y: int in _rows.size():
		for x: int in columns():
			if mark(Vector2i(x, y)) == WATER:
				wet.append(Vector2i(x, y))
	if wet.is_empty() or _soil == null:
		return
	if _pond == null:
		for cell: Vector2i in wet:
			GroundWear.patch(_on.get_canvas_item(), _soil, cell_middle(cell),
				_cell * 0.62, _water_tint, 0.60)
		return
	var lift: float = float(_standing(wet[0])) * _rise
	var rim: Array[Rect2] = []
	for j: int in _rows.size() + 1:
		for i: int in columns() + 1:
			# **Through the ponds' own index** rather than a second copy of the
			# rule: the first cut inverted the corners on a guess and drew every
			# pool inside out - brown in the middle and blue around the rim, which
			# is the defect the owner reported as "the blue tiles".
			var index: int = PondTiles.tile_index(
				mark(Vector2i(i - 1, j - 1)) == WATER,
				mark(Vector2i(i, j - 1)) == WATER,
				mark(Vector2i(i - 1, j)) == WATER,
				mark(Vector2i(i, j)) == WATER)
			if index == 0:
				continue
			var where := Rect2(
				_origin.x + float(i) * _cell - _cell * 0.5,
				_origin.y + float(j) * _cell - _cell * 0.5 - lift,
				_cell + 0.5, _cell + 0.5)
			var across: int = PondTiles.SHEET_ACROSS
			var tile: int = PondTiles.TILE
			_on.draw_texture_rect_region(_pond, where,
				Rect2(float(index % across) * float(tile),
					float(index / across) * float(tile),
					float(tile), float(tile)), SHORE_TINT)
			# **The outermost tile is where the pond stops being a pond**, and
			# a Wang sheet's own rim is a hard edge against whatever it was
			# dropped on: the pond art is packed for the road's ground and the
			# Hold's shelves are a different material. Owner, 2026-09-17: *"the
			# ponds at the hold do not have smoothing transitions around the
			# edges of the ground changes around its outer most border."*
			#
			# So every tile with dry corners gets the shelf's own ground worn
			# back over it, feathered from the dry side - which is the same
			# answer the paths and the bank lips are drawn with, and it needs no
			# second painting.
			if index != 15:
				rim.append(where)
	# Laid after the water, so the ground is worn back *over* the shore rather
	# than under it. The shelf's own sheet, so a pool in the plaza is ringed by
	# plaza and one in the lower yard by the valley floor.
	var ground: Texture2D = _tiles.get(_standing(wet[0]), _soil) as Texture2D
	if ground != null:
		for patch: Rect2 in rim:
			GroundWear.patch(_on.get_canvas_item(), ground,
				patch.get_center(), _cell * 0.62, SHORE_BLEND, 0.72)


## **The flights, drawn one whole staircase at a time.**
##
## A flight is cut three cells wide so that people can pass on it, and the piece
## is a single tapering staircase - so drawn once per cell it comes out as three
## narrow flights side by side with gaps between them. The cells of one flight
## are found and the piece is stretched across all of them, which is what makes
## a wide stair read as a wide stair.
##
## The two side directions are one piece drawn and its mirror: a staircase going
## the other way is the same staircase.
func _draw_flights() -> void:
	var seen: Dictionary = {}
	for y: int in _rows.size():
		for x: int in columns():
			var cell := Vector2i(x, y)
			var ch: String = mark(cell)
			if not WAY.has(ch) or seen.has(cell):
				continue
			var art: Texture2D = _stair_north if (ch == "^" or ch == "v") 				else _stair_side
			# The run lies across the way it climbs: a stair going north is
			# wide east to west.
			var across: Vector2i = Vector2i(1, 0) if WAY[ch].x == 0 				else Vector2i(0, 1)
			# **Only a flight that climbs away from the camera is stretched.**
			# A staircase drawn across the view is steps seen edge-on, and
			# stretching one down a three-cell run turns it into diagonal
			# hatching - photographed as a row of barber poles down the flank
			# of the yard. Its own cell each keeps the aspect it was drawn at.
			var last: Vector2i = cell
			seen[cell] = true
			if across.x != 0:
				while mark(last + across) == ch:
					last += across
					seen[last] = true
			if art == null:
				continue
			var low: int = int(LEVEL.get(mark(cell + WAY[ch]), 0))
			var from: Vector2 = _origin + Vector2(cell) * _cell
			var to: Vector2 = _origin + Vector2(last + across) * _cell
			# Drawn from the low edge up: the steps *are* the climb, so the
			# piece covers the run and the rise it crosses.
			var box := Rect2(from.x, from.y - float(low + 1) * _rise,
				to.x - from.x, (to.y - from.y) + _rise) 				if across.x != 0 				else Rect2(from.x, from.y - float(low + 1) * _rise,
					_cell, (to.y - from.y) + _rise)
			if across.x != 0:
				box.size.y = _cell + _rise
			if ch == "<" or ch == "v":
				box = Rect2(box.position.x + box.size.x, box.position.y,
					-box.size.x, box.size.y)
			_on.draw_texture_rect_region(art, box,
				Rect2(0.0, 0.0, float(art.get_width()),
					float(art.get_height())), _bank_tint)


## One triangle array for a whole set of quads, wearing the sheet in world
## coordinates so the soil in a slab is the soil beside it.
func _paint(quads: Array[Rect2], sheet: Texture2D, tint: Color) -> void:
	var size := Vector2(maxf(float(sheet.get_width()), 1.0),
		maxf(float(sheet.get_height()), 1.0))
	var points: PackedVector2Array = []
	var colours: PackedColorArray = []
	var uvs: PackedVector2Array = []
	var indices: PackedInt32Array = []
	for quad: Rect2 in quads:
		var base: int = points.size()
		for corner: Vector2 in [quad.position,
				Vector2(quad.end.x, quad.position.y), quad.end,
				Vector2(quad.position.x, quad.end.y)]:
			points.append(corner)
			colours.append(tint)
			uvs.append(Vector2(corner.x / size.x, corner.y / size.y))
		indices.append_array([base, base + 1, base + 2,
			base, base + 2, base + 3])
	RenderingServer.canvas_item_add_triangle_array(_on.get_canvas_item(),
		indices, points, colours, uvs, PackedInt32Array(),
		PackedFloat32Array(), sheet.get_rid())
