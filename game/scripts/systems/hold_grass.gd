class_name HoldGrass
extends Node2D

## **Grass that leans in the wind and gives way when somebody walks through it.**
##
## Owner, 2026-09-17: *"the Hold should have some highly aesthetically appealing
## natural appearing grass that is also highly optimized and perfect for our game
## and should react to players walking through the grass with proper procedural
## animation"*.
##
## ## Why it is one node and not a thousand
##
## A tuft as a `Sprite2D` with a shader is about nine hundred bytes of node, a
## material and a draw call, and a field this size wants thousands of them. This
## is **one canvas item**: every tuft is four vertices in one triangle array, and
## the whole field is a single `canvas_item_add_triangle_array` with the tuft
## sheet on it. That is the same argument the shadows, the paths and the banners
## are each drawn under, at the scale where it matters most.
##
## ## How a blade moves
##
## The top two vertices move and the bottom two do not, which is the whole of
## it: grass is hinged at the root. Three things push the top:
##
## - **the wind**, shared with the banners and the embers so the yard leans
##   together;
## - **its own phase**, so a field is not one blade repeated - taken from where
##   the tuft stands rather than from a roll, so it never re-shuffles;
## - **whoever is walking through it**, pushed *away* from them and hardest at
##   their feet, easing back over `Balance.HOLD_GRASS_RECOVER` once they pass.
##
## The recovery is what makes it read as grass rather than as a force field: a
## tuft that snapped back the instant somebody stepped off it is a switch, and a
## real blade takes a moment to stand up.
##
## ## It is a picture
##
## Nothing reads the grass. It blocks nothing, hides nothing and is in no group;
## `Graphics.foliage_trample()` turns the parting off on a weak machine and the
## field simply stands still in the wind. Same bound as the fog and the coats.

## Where the tufts are, in the flat plane. Each carries its own lift already.
var field: PackedVector2Array = PackedVector2Array()

## The sheet of tufts, four across (`Foliage.GRASS_TUFTS_ACROSS`).
var sheet: Texture2D = null

## Who is walking through it. Returns an Array of Vector2 in the same plane.
var walkers: Callable = Callable()

## How the light falls on the yard this grass grows in.
var tint: Color = Color(1.0, 1.0, 1.0)

var _wind: Vector2 = Vector2.ZERO
var _clock: float = 0.0
## How far each tuft is currently pushed over, and by whom. Kept between frames
## so a blade eases back up rather than snapping.
var _bent: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	set_process(true)


## The field, sorted north to south so a tuft on a shelf is drawn before the
## bank that falls in front of it.
func set_field(points: Array) -> void:
	var sorted: Array = points.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	field = PackedVector2Array(sorted)
	_bent.resize(field.size())
	for index: int in _bent.size():
		_bent[index] = Vector2.ZERO
	queue_redraw()


func set_wind(wind: Vector2) -> void:
	_wind = wind


func _process(delta: float) -> void:
	_clock += delta
	_part(delta)
	queue_redraw()


## **Who is standing in the grass, and how it gives way.**
##
## Squared distance against a squared reach, so nothing takes a root per tuft
## per walker per frame - a field of several thousand is the one place in this
## file where that arithmetic would show.
func _part(delta: float) -> void:
	var ease: float = clampf(delta / maxf(Balance.HOLD_GRASS_RECOVER, 0.01),
		0.0, 1.0)
	var feet: Array = []
	if walkers.is_valid() and Graphics.foliage_trample():
		feet = walkers.call()
	var reach: float = Balance.HOLD_GRASS_PART_REACH
	var reach_sq: float = reach * reach
	for index: int in field.size():
		var at: Vector2 = field[index]
		var push: Vector2 = Vector2.ZERO
		for who: Variant in feet:
			var away: Vector2 = at - (who as Vector2)
			var gap: float = away.length_squared()
			if gap > reach_sq or gap < 0.0001:
				continue
			# Hardest under the boot and nothing at the rim, so a person walking
			# through leaves a moving dent rather than a disc.
			var share: float = 1.0 - sqrt(gap) / reach
			push += away.normalized() * share * share \
				* Balance.HOLD_GRASS_PART_LEAN
		_bent[index] = (_bent[index] as Vector2).lerp(push, ease)


func _draw() -> void:
	if sheet == null or field.is_empty():
		return
	# **No culling.** The first cut worked out a visible rectangle from this
	# node's own transform and got it wrong, which showed as a field of four
	# tufts: the Hold is drawn inside a screen that scales and offsets it, and
	# a rect derived from `get_global_transform` there is not the rect the
	# camera sees. Two thousand six hundred quads is one array and about ten
	# thousand vertices, which is less than a single tower's sprite - the cull
	# was solving a problem this does not have, and it was solving it wrongly.
	var across: int = Foliage.GRASS_TUFTS_ACROSS
	var cell: float = float(sheet.get_width()) / float(across)
	var tall: float = float(sheet.get_height())
	var wide: float = Balance.HOLD_GRASS_WIDE
	var high: float = Balance.HOLD_GRASS_TALL
	var points: PackedVector2Array = []
	var colours: PackedColorArray = []
	var uvs: PackedVector2Array = []
	var indices: PackedInt32Array = []
	for index: int in field.size():
		var at: Vector2 = field[index]
		# Its own tuft off its own place, so a field is four tufts shuffled
		# rather than one repeated - and the same tuft every time it is drawn.
		var which: int = absi(int(at.x * 7.0) ^ int(at.y * 13.0)) % across
		var phase: float = float(absi(int(at.x + at.y * 3.0)) % 628) * 0.01
		var sway: float = sin(_clock * Balance.HOLD_GRASS_SWAY_HZ + phase) \
			* Balance.HOLD_GRASS_SWAY
		var lean: Vector2 = _wind * Balance.HOLD_GRASS_WIND \
			+ Vector2(sway, 0.0) + (_bent[index] as Vector2)
		var base: int = points.size()
		var half: float = wide * 0.5
		# The root is nailed and the head moves: grass is hinged at the ground.
		points.append(at + Vector2(-half, -high) + lean)
		points.append(at + Vector2(half, -high) + lean)
		points.append(at + Vector2(half, 0.0))
		points.append(at + Vector2(-half, 0.0))
		# The head catches the light and the root is in its own shade, which is
		# what gives a flat tuft any depth at all.
		var lit: Color = tint
		var root: Color = Color(tint.r * 0.66, tint.g * 0.72, tint.b * 0.62,
			tint.a)
		colours.append(lit)
		colours.append(lit)
		colours.append(root)
		colours.append(root)
		var u0: float = float(which) * cell / float(sheet.get_width())
		var u1: float = float(which + 1) * cell / float(sheet.get_width())
		uvs.append(Vector2(u0, 0.0))
		uvs.append(Vector2(u1, 0.0))
		uvs.append(Vector2(u1, tall / tall))
		uvs.append(Vector2(u0, tall / tall))
		indices.append_array([base, base + 1, base + 2,
			base, base + 2, base + 3])
	if indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),
		indices, points, colours, uvs, PackedInt32Array(),
		PackedFloat32Array(), sheet.get_rid())
