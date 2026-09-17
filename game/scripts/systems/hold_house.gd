class_name HoldHouse
extends Node2D

## **A dwelling assembled from parts rather than painted whole.**
##
## Owner, 2026-09-17: *"buildings should have modular tilesets as well and be
## procedurally generatable for slight variations in them, and to still be
## perfect and aesthetically appealing and polished"*.
##
## Six pieces ship - a wall, a door, a window, a roof course, a gable end and a
## chimney - and a house is a *sentence* made of them: some number of bays wide,
## the door somewhere along it, windows in some of the rest, the roof laid over
## the whole and a chimney somewhere on the ridge. Two houses built from the
## same six parts are different houses, and adding a seventh part is adding a
## file (working rule 3).
##
## ## Why this is not a tilemap
##
## A `TileMapLayer` is the right answer for *ground*, which is a field of cells
## where every cell is as good as any other. A building is not a field: its
## parts have an order (plinth, wall, roof, ridge), a rule about which may
## repeat, and exactly one door. That is a grammar, and a grammar is a few lines
## of code rather than a lattice. The Hold's ground is Wang tiles for the same
## reason turned round.
##
## ## The variation is fixed, not rolled
##
## Everything is derived from one `seed`, so a house is the same house every
## time the Hold opens. A dwelling that re-rolled its own windows on each visit
## would be the strongest possible signal that none of this is a place - the
## same argument the pens' animals, the paddock's horses and the Hold's own
## foliage are each given a fixed clock under.
##
## ## It is a picture
##
## Nothing reads a house. It has no door to press, blocks nothing by itself -
## the yard's own map decides where people may walk - and turning it off changes
## no number. Placing one on ground the map calls open is the author's job, and
## `hold_check` walks the yard to prove nobody was walled in.

## The parts, by name. A kit with a piece missing simply draws fewer things:
## a missing chimney is a house without one, never a hole.
const WALL: String = "res://art/city/house_wall.png"
const DOOR: String = "res://art/city/house_door.png"
const WINDOW: String = "res://art/city/house_window.png"
const ROOF: String = "res://art/city/house_roof.png"
const ROOF_END: String = "res://art/city/house_roof_end.png"
const CHIMNEY: String = "res://art/city/house_chimney.png"

## What decides this house. Set before it enters the tree.
var seed_value: int = 0

## How the light falls on it, so a dwelling belongs to the yard it stands in
## rather than to the sheet it was painted on.
var tint: Color = Color.WHITE

var _wall: Texture2D = null
var _door: Texture2D = null
var _window: Texture2D = null
var _roof: Texture2D = null
var _roof_end: Texture2D = null
var _chimney: Texture2D = null

var _bays: int = 3
var _door_at: int = 1
var _windows: Array[bool] = []
var _chimney_at: float = 0.0
var _flip: bool = false


func _ready() -> void:
	_wall = _load(WALL)
	_door = _load(DOOR)
	_window = _load(WINDOW)
	_roof = _load(ROOF)
	_roof_end = _load(ROOF_END)
	_chimney = _load(CHIMNEY)
	_compose()
	queue_redraw()


static func _load(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## **The grammar.** Its own stream off its own seed, so nothing here touches the
## run's dice and the same house comes back every visit.
func _compose() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_bays = rng.randi_range(Balance.HOLD_HOUSE_BAYS.x,
		Balance.HOLD_HOUSE_BAYS.y)
	# The door is never in a corner bay: a door at the very end of a wall reads
	# as a hole in the gable rather than as the way in.
	_door_at = rng.randi_range(1, maxi(_bays - 2, 1)) if _bays >= 3 else 0
	_windows.clear()
	for bay: int in _bays:
		_windows.append(bay != _door_at
			and rng.randf() < Balance.HOLD_HOUSE_WINDOW_CHANCE)
	_chimney_at = rng.randf_range(0.18, 0.82)
	_flip = rng.randf() < 0.5


## How wide this house stands, so a caller can keep two of them apart.
func span() -> float:
	return float(_bays) * Balance.HOLD_HOUSE_BAY


func _draw() -> void:
	var bay: float = Balance.HOLD_HOUSE_BAY
	var tall: float = Balance.HOLD_HOUSE_WALL
	var eave: float = Balance.HOLD_HOUSE_ROOF
	var wide: float = span()
	var left: float = -wide * 0.5
	# **Drawn from the foot up.** The node stands on the ground it is placed on,
	# which is the same contract every sprite in the yard is placed under, so a
	# house on a shelf is lifted by the shelf and nothing here learns about it.
	var floor_at: float = 0.0
	var wall_top: float = floor_at - tall
	var ridge: float = wall_top - eave

	# The shadow it casts, first and under everything: a building with none is
	# a building floating on the grass.
	_shadow(Vector2(0.0, floor_at), wide * 0.54, eave * 0.24)

	for index: int in _bays:
		var piece: Texture2D = _wall
		if index == _door_at and _door != null:
			piece = _door
		elif _windows[index] and _window != null:
			piece = _window
		if piece == null:
			continue
		var at: float = left + float(index) * bay
		# Mirrored as a whole rather than per bay, so the timber posts still
		# line up across the joints.
		var box := Rect2(at, wall_top, bay, tall)
		if _flip:
			box = Rect2(at + bay, wall_top, -bay, tall)
		draw_texture_rect(piece, box, false, tint)

	if _roof == null:
		return
	# The roof overhangs the wall at both ends, which is what an eave is, and
	# **it is seated down onto the wall** rather than balanced above it: a
	# thatch with daylight under its own eave is a hat.
	var over: float = bay * Balance.HOLD_HOUSE_OVERHANG
	var seat: float = eave * Balance.HOLD_HOUSE_SEAT
	var span_wide: float = wide + over * 2.0
	var courses: int = _bays
	var course: float = span_wide / float(courses)
	var lap: float = course * Balance.HOLD_HOUSE_LAP
	for index: int in courses:
		var at: float = left - over + float(index) * course
		draw_texture_rect(_roof, Rect2(at - lap, ridge + seat,
			course + lap * 2.0, eave), false, tint)
	if _roof_end != null:
		# One painting, drawn and then mirrored: a hip on the other side of a
		# roof is the same hip.
		var cap: float = bay * 0.7
		draw_texture_rect(_roof_end,
			Rect2(left - over + cap, ridge + seat, -cap, eave), false, tint)
		draw_texture_rect(_roof_end,
			Rect2(left + wide + over - cap, ridge + seat, cap, eave),
			false, tint)
	if _chimney != null:
		var stack := Vector2(left + wide * _chimney_at,
			ridge + seat + eave * Balance.HOLD_HOUSE_CHIMNEY_SEAT)
		var stack_wide: float = float(_chimney.get_width()) \
			* Balance.HOLD_HOUSE_SCALE
		var stack_tall: float = float(_chimney.get_height()) \
			* Balance.HOLD_HOUSE_SCALE
		draw_texture_rect(_chimney, Rect2(stack.x - stack_wide * 0.5,
			stack.y - stack_tall, stack_wide, stack_tall), false, tint)


## A soft shadow on the ground, the shared technique: one colour for the whole
## shape is what a hard edge is.
func _shadow(at: Vector2, wide: float, tall: float) -> void:
	var steps: int = 16
	var points: PackedVector2Array = [at]
	var colours: PackedColorArray = [Color(0.0, 0.0, 0.0, 0.34)]
	var indices: PackedInt32Array = []
	for step: int in steps + 1:
		var angle: float = TAU * float(step) / float(steps)
		points.append(at + Vector2(cos(angle) * wide, sin(angle) * tall))
		colours.append(Color(0.0, 0.0, 0.0, 0.0))
	for step: int in steps:
		indices.append_array([0, step + 1, step + 2])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),
		indices, points, colours)
