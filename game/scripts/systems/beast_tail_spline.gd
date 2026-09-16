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
## The difference between the two paintings, measured once per pair.
var _paint_match: Color = Color.WHITE
## The grade the body is wearing, handed over by whoever grades it.
var _grade: Color = Color.WHITE
## The painting's own centreline, in its own pixels: one point per slice
## boundary, from the root end to the tip.
var _rest: PackedVector2Array = PackedVector2Array()
## Where in the texture the root sits, so the node's origin can be put on it.
var _root: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _drawn_at: float = -1.0
var _phase: float = 0.0
## How long one of the body's frames lasts. The limb's pose steps on the
## same beat - see `_posed_time`.
var frame_time: float = 0.22

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
	_rest = _settled(found["centreline"])
	_root = found["root"]
	queue_redraw()


## The painting's centreline and its root point.
##
## **Read off the art rather than authored**, for the same reason `BeastTail`
## reads the body's stub row off the body: a number written down here would be
## wrong the next time the tail is redrawn, and wrong silently.
## **The far end of the limb settles, and the root does not move.**
##
## Owner, 2026-09-16: "bring yuri's tail end down just a very tiny bit and it
## should finally be in place". Applied to the *rest pose* rather than to the
## walk, for two reasons. It is a property of how the limb hangs rather than of
## how it moves, so the slices should follow it and the whip should build on top
## of it. And `beast_tail_check` holds that the chain at rest reproduces its rest
## pose exactly - which is what catches the wave accidentally distorting the art
## - so a droop added in the walk reads to that gate as exactly the distortion it
## exists to refuse. Here the invariant keeps its teeth and the limb still hangs.
##
## Zero at the root and all of it at the tip, because that is what a hanging
## thing does, and because `BEAST_TAIL_LIFT` lines the seam up and was set by two
## separate reports about exactly that seam.
static func _settled(centreline: PackedVector2Array) -> PackedVector2Array:
	var count: int = centreline.size()
	if count < 2 or Balance.BEAST_TAIL_TIP_DROOP == 0.0:
		return centreline
	var out := PackedVector2Array()
	for index: int in count:
		# The painting runs tip-first: index 0 is the far end, the last point is
		# the root. So "how far from the root" counts down rather than up.
		var from_root: float = 1.0 - float(index) / float(count - 1)
		var point: Vector2 = centreline[index]
		point.y += Balance.BEAST_TAIL_TIP_DROOP * from_root * from_root
		out.append(point)
	return out


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


## **Match the hide the limb grows out of, measured rather than painted.**
##
## Owner, four reports ending 2026-09-15: the tail "is still lighter than the
## body's colour grading and tint, it's not receiving whatever custom thing is
## going on there for the body's colour grading".
##
## Every *render-time* grade does reach it - the modulate chain carries the
## scene tint, the day, the fog - and that has been checked. What does not
## reach it is the one thing no chain can carry: the two paintings are
## different paintings, and the tail's own mid-tones sit above the hide's at
## the place they meet. Four passes over the pixels narrowed that and never
## closed it, because a pass over a whole limb cannot know which end of it is
## against which part of the body.
##
## So it is closed here, by measurement, once per pair of textures: the mean
## surface brightness of the body's stub against the mean of the tail's root,
## applied as a `self_modulate` on the limb. Whatever either painting is, they
## meet at the same tone - and if either is ever redrawn, the number follows on
## its own rather than needing a fifth pass.
##
## **Only ever darkening.** Brightening a limb to meet a hide is how a tail ends
## up glowing in a night scene, and two earlier attempts at a gain were wrong in
## exactly that direction.
func harmonise(body: Texture2D) -> void:
	if body == null or _texture == null:
		return
	var key: String = "%s|%s" % [body.resource_path, _texture.resource_path]
	if not _harmony.has(key):
		_harmony[key] = _measure_harmony(body, _texture)
	_paint_match = _harmony[key] as Color
	_apply_grade()


## **The grade the body is wearing, handed over rather than inherited.**
##
## Reported seven times, and every previous pass measured the two paintings
## instead of the screen. Photographed: the body's `modulate` was
## (0.58, 0.473, 0.476) - warm, dark, strongly coloured - and the limb's was
## (1, 1, 1) with a flat grey `self_modulate`, so it rendered **+27% brighter
## than the hide and almost entirely desaturated**. A grey tail on a warm
## animal.
##
## `beast_scope.gd` carried a comment asserting the opposite - "`modulate` is
## inherited from the beast, so the day tint and the environment grade already
## reach it" - and that belief is why four passes were spent tuning a ratio that
## was then multiplied by grey. **Whatever the reason the chain does not carry
## it, handing it over explicitly is one line and cannot be wrong about it.**
##
## Called wherever the body is given its own grade, so the two can never be set
## from different values on the same frame.
func wear_grade(grade: Color) -> void:
	_grade = grade
	_apply_grade()


func _apply_grade() -> void:
	self_modulate = Color(
		_paint_match.r * _grade.r,
		_paint_match.g * _grade.g,
		_paint_match.b * _grade.b,
		1.0)


## The ratio between the hide at the stub and the limb at its root.
## **Per channel, not per luminance.**
##
## This returned one greyscale ratio, so two colours of the same brightness and
## a different hue measured identical - and the owner's words were "not color
## graded or tinted the same", which is a hue complaint a scalar can never
## answer. Multiplying by a coloured ratio tints a grey limb toward the hide;
## multiplying by a grey one only ever dims it.
##
## **And it reads the whole limb against the whole rear of the body**, not a
## strip at the seam. The seam agreed within nine percent while the length of
## the tail - which is nearly all of what anybody looks at - did not.
static func _measure_harmony(body: Texture2D, tail: Texture2D) -> Color:
	var hide: Color = _surface_mean(body, 0.0, 0.34, 0.0, 1.0)
	var limb: Color = _surface_mean(tail, 0.0, 1.0, 0.0, 1.0)
	if hide.get_luminance() <= 0.001 or limb.get_luminance() <= 0.001:
		return Color.WHITE
	# **And then the offset the eye asked for.**
	#
	# The measurement above closes a gap when there is one. On today's art there
	# is not: mean, median and upper quartile of the hide's haunch and the
	# limb's surface agree within three percent, checked six ways. The owner has
	# still reported the tail as lighter four times, and four reports beat a
	# histogram - a limb hanging in open air beside a mass that is shadowed by
	# its own bulk reads brighter than the numbers say it is, because there is
	# nothing around it to compare against.
	#
	# So `BEAST_TAIL_SEAT` is an authored offset rather than a derived one, and
	# it is written down as such. If the art is ever redrawn far enough apart
	# for the measurement to bite, it takes over and this only trims.
	var ratio: Color = Color(
		clampf(hide.r / maxf(limb.r, 0.001), Balance.BEAST_TAIL_HARMONY_FLOOR, 1.0),
		clampf(hide.g / maxf(limb.g, 0.001), Balance.BEAST_TAIL_HARMONY_FLOOR, 1.0),
		clampf(hide.b / maxf(limb.b, 0.001), Balance.BEAST_TAIL_HARMONY_FLOOR, 1.0),
		1.0)
	return Color(ratio.r * Balance.BEAST_TAIL_SEAT,
		ratio.g * Balance.BEAST_TAIL_SEAT,
		ratio.b * Balance.BEAST_TAIL_SEAT, 1.0)


## Mean brightness of the painted surface inside a box, ink held out.
##
## Ink is held out for the reason `match_tail_palette.py` learnt the hard way: a
## limb carries more outline per unit of area than a flank does, and averaging
## the two together compares line weight rather than colour.
static func _surface_mean(texture: Texture2D, from_x: float, to_x: float,
		from_y: float, to_y: float) -> Color:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Color.BLACK
	var width: int = image.get_width()
	var height: int = image.get_height()
	var total := Vector3.ZERO
	var count: int = 0
	for y: int in range(int(float(height) * from_y), int(float(height) * to_y)):
		for x: int in range(int(float(width) * from_x), int(float(width) * to_x)):
			var at: Color = image.get_pixel(x, y)
			if at.a < 0.5:
				continue
			if at.r <= 0.05 and at.g <= 0.05 and at.b <= 0.05:
				continue
			total += Vector3(at.r, at.g, at.b)
			count += 1
	if count <= 0:
		return Color.BLACK
	total /= float(count)
	return Color(total.x, total.y, total.z, 1.0)


## **The pose steps on the body's own beat** (owner, 2026-09-15: "change the FPS
## of Yuri's tail spline animations to match the FPS of his body's animations
## and to change on matching times with it").
##
## The chain is continuous arithmetic and would happily move every frame, which
## beside a body that steps five times a second reads as two animals. Quantised
## to the same step and offset to the same instants, the limb moves when the
## body moves - which is what pixel art wants and what makes the two read as one
## creature. The *drawing* still samples at `BEAST_TAIL_HZ`; only the pose is
## stepped.
func _posed_time() -> float:
	var step: float = maxf(frame_time, 0.01)
	return floor(_time / step) * step


static var _harmony: Dictionary = {}


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
	var beat: float = _posed_time()
	return sin(beat * 1.15 + _phase + along * 2.4) * 0.62 \
		+ sin(beat * 1.86 + _phase * 1.31 + along * 4.1) * 0.38 \
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
