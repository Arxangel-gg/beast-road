class_name BeastTailSpline
extends Node2D

## Yuri's tail, laid along a spline that is anchored to his body and moves.
##
## **Owner's idea, 2026-09-15:** "make the tail a spline animated procedural
## solution". It answers two things at once that four passes of art could not.
##
## **The join cannot come apart, because there is nothing to line up.** The tail
## used to be a sprite placed at an anchor, and every report about it since it
## was built has been about that placement: a gap, a doubled underside, a root a
## few pixels low. A spline has no placement - its first point *is* the stub row
## the body frame paints, read off that frame's own pixels, so the limb starts
## where the body ends by construction and keeps doing so on every frame of the
## gait, at every scale, in both scopes.
##
## **And it is alive.** A hanging thing anchored at one end and free at the
## other is a whip: the root barely moves, the deviation accumulates down the
## length, and the tip travels furthest. That is the same motion `menu_foliage`
## gives a vine and the same reason - it is what a hanging thing actually does,
## and one sine applied to the whole limb is what reads as rubber.
##
## **The rest pose is the painting, exactly.** The art is not straightened or
## re-drawn: it is cut into slices and each slice is laid at its own place along
## the chain. With no wind the chain *is* the centreline measured off the
## painting, so the tail renders pixel for pixel as it always did, and the
## motion is a deviation from that rather than a different tail.
##
## **It carries no material and is a child of the body**, which is how every
## tint the beast is given reaches it - see `beast_tail_check`. A shader here
## would take the scene's colour off it, which this project has already paid
## for once.

## How many slices the painting is cut into. Enough that the bend reads as a
## curve rather than as a fan; few enough that the whole tail is forty quads.
const SLICES: int = 24

## What the limb is doing. The scope sets these from the gait and the wind; the
## menu leaves them at rest and lets the idle sway carry it.
var sway: float = 1.0
var wind: float = 0.0

var _texture: Texture2D = null
## The painting's own centreline, in its own pixels: one point per slice
## boundary, from the root end to the tip.
var _rest: PackedVector2Array = PackedVector2Array()
## Where in the texture the root sits, so the node's origin can be put on it.
var _root: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _drawn_at: float = -1.0
var _phase: float = 0.0

static var _measured: Dictionary = {}


func _ready() -> void:
	_phase = randf() * TAU
	set_process(true)


## Hand it the painting. Measured once per texture and cached, because reading
## a 160x96 image per slice per frame is not a thing to do in a draw call.
func adopt(texture: Texture2D) -> void:
	_texture = texture
	if texture == null:
		return
	var key: String = texture.resource_path if texture.resource_path != "" \
		else str(texture.get_instance_id())
	if not _measured.has(key):
		_measured[key] = _measure(texture)
	var found: Dictionary = _measured[key]
	_rest = found["centreline"]
	_root = found["root"]
	queue_redraw()


## The painting's centreline and its root point.
##
## **Read off the art rather than authored**, for the same reason `BeastTail`
## reads the body's stub row off the body: a number written down here would be
## wrong the next time the tail is redrawn, and wrong silently.
static func _measure(texture: Texture2D) -> Dictionary:
	var image: Image = texture.get_image()
	var centreline := PackedVector2Array()
	if image == null or image.is_empty():
		return {"centreline": centreline, "root": Vector2.ZERO}
	var width: int = image.get_width()
	var height: int = image.get_height()
	for step: int in SLICES + 1:
		var x: int = clampi(int(round(float(step) * float(width) / float(SLICES))),
			0, width - 1)
		var top: int = -1
		var bottom: int = -1
		for y: int in height:
			if image.get_pixel(x, y).a > 0.16:
				if top < 0:
					top = y
				bottom = y
		# An empty column takes its neighbour's height rather than the top of
		# the canvas, or the chain kinks to zero at the ends.
		var middle: float = float(top + bottom) * 0.5 if top >= 0 \
			else (centreline[centreline.size() - 1].y if centreline.size() > 0
				else float(height) * 0.5)
		centreline.append(Vector2(float(x), middle))
	return {
		"centreline": centreline,
		"root": Vector2(float(width) * Balance.BEAST_TAIL_ROOT.x,
			float(height) * Balance.BEAST_TAIL_ROOT.y),
	}


func _process(delta: float) -> void:
	_time += delta
	# Sampled, like every other drawn thing in this project - see `flame.gd`.
	if _time - _drawn_at >= 1.0 / maxf(Balance.BEAST_TAIL_HZ, 1.0):
		_drawn_at = _time
		queue_redraw()


## Advance the limb's own clock. For the gate, which has no frames to spend.
func advance(delta: float) -> void:
	_time += delta


## Where the chain is at this instant, in the texture's own pixels.
##
## Walked from the root outward: each segment keeps the length it has in the
## painting and turns by however much the rest pose turned there, plus a
## deviation that accumulates. So the limb is inextensible, the root is fixed,
## and the tip is the sum of every turn before it - which is what makes it whip
## rather than wobble.
func chain() -> PackedVector2Array:
	var out := PackedVector2Array()
	if _rest.size() < 2:
		return out
	# The root end of the painting is the *last* point: the tail is drawn with
	# its tip at the left and its root at the right (`BEAST_TAIL_ROOT.x` is
	# 0.95). Walking has to start there.
	var at: Vector2 = _rest[_rest.size() - 1]
	out.append(at)
	var drift: float = 0.0
	var count: int = _rest.size() - 1
	for step: int in count:
		var index: int = count - step
		var rest_from: Vector2 = _rest[index]
		var rest_to: Vector2 = _rest[index - 1]
		var span: Vector2 = rest_to - rest_from
		var length: float = span.length()
		var along: float = float(step + 1) / float(count)
		drift += _wave(along) * sway * along / float(count) \
			* Balance.BEAST_TAIL_WHIP
		at += span.rotated(drift) if length > 0.001 else Vector2.ZERO
		out.append(at)
	return out


## The travelling wave down the limb. Two rates, as everything else here is
## built from, so the motion has no period a player can catch; the wind leans
## the whole thing one way on top of that.
func _wave(along: float) -> float:
	return sin(_time * 1.15 + _phase + along * 2.4) * 0.62 \
		+ sin(_time * 1.86 + _phase * 1.31 + along * 4.1) * 0.38 \
		+ wind * 0.7


func _draw() -> void:
	if _texture == null or _rest.size() < 2:
		return
	var points: PackedVector2Array = chain()
	if points.size() < 2:
		return
	var height: float = float(_texture.get_height())
	var count: int = points.size() - 1
	for step: int in count:
		# `points` runs root to tip; the painting's slices run tip to root, so
		# the slice this segment carries is counted from the far end.
		var index: int = _rest.size() - 1 - step
		var from_x: float = _rest[index - 1].x
		var to_x: float = _rest[index].x
		var slice: float = to_x - from_x
		if slice <= 0.0:
			continue
		var here: Vector2 = points[step]
		var next: Vector2 = points[step + 1]
		var lean: Vector2 = here - next
		if lean.length() < 0.001:
			continue
		# **The turn is the deviation from the painting, not the slope of the
		# painting.** Rotating each slice by its own rest slope draws the tail
		# with every slice turned twice - once by where the curve already goes
		# and once by the drawing - which scatters it into a fan. At rest this
		# is zero and the painting is reproduced exactly, which is the whole
		# claim this class makes.
		var rest_lean: Vector2 = _rest[index] - _rest[index - 1]
		var turn: float = lean.angle() - rest_lean.angle() if rest_lean.length() > 0.001 			else 0.0
		# The slice is drawn with its own root-side edge on `here`, running back
		# toward `next`, turned to the segment it belongs to. Its vertical place
		# is the painting's own: the centreline point it was measured at.
		var middle: float = _rest[index].y
		# The origin is this slice's own centreline point, moved to where the
		# chain has taken it and turned to the chain's own direction. At rest
		# the chain is the centreline and the turn is the painting's own, so
		# source pixel (x, y) lands at (x, y) less the root - which is the
		# painting, unchanged.
		#
		# Half a pixel of overlap on the far side, because twenty-four slices
		# laid end to end at arbitrary angles will otherwise show the gap
		# between two of them on some frames.
		draw_set_transform(here - _root, turn, Vector2.ONE)
		draw_texture_rect_region(_texture,
			Rect2(-slice - 0.5, -middle, slice + 0.5, height),
			Rect2(from_x, 0.0, slice, height))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Where the root of the limb sits inside the painting, so a caller can put the
## node's origin on the body's own stub.
func root_in_art() -> Vector2:
	return _root


## How far the tip has travelled from where the painting puts it. For the gate:
## the whole claim is that the tip moves and the root does not.
func tip_drift() -> float:
	var points: PackedVector2Array = chain()
	if points.size() < 2 or _rest.size() < 2:
		return 0.0
	return points[points.size() - 1].distance_to(_rest[0])
