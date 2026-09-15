class_name MenuFrame
extends Control

## The carved border around the main menu, and the life in it.
##
## **Owner brief, 2026-09-15:** "add an aesthetically appealing but polished
## frame around the whole screen that is gorgeous and maybe even has lively
## animated elements with awesome game juice and even reactiveness".
##
## Four corner brackets and a border strip tiled between them, graded to the
## same light everything else on this screen is graded to. What makes it a frame
## rather than a border is the three things on top of that, and each is a
## separate decision:
##
## - **A sheen travels the perimeter**, slowly, once every half minute or so. A
##   frame that does nothing is furniture; a frame that pulses on a beat is a
##   loading bar. One quiet pass of light that a player half-notices is the
##   thing that makes a still screen feel lit.
## - **It answers being touched.** `pulse_at` sends a brighter wave out from
##   wherever the player just pressed, in both directions round the frame, so
##   pressing TAKE THE ROAD lights the corner beside it first. The same seam
##   `UiJuice` uses, so the hologram on the button and the wave on the frame are
##   one gesture rather than two effects.
## - **The vines on it breathe**, on the corner's own slow clock, because the
##   art has vines painted on it and a still vine beside a swaying one is the
##   thing the eye lands on.
##
## **It is drawn and never read.** Nothing about the layout, the buttons or the
## touch zones knows this exists; it is inside its own CanvasLayer with input
## ignored. A frame that stole a press would be the worst possible trade for a
## decoration, and it is the fault this kind of overlay always ships with.

const CORNER_ART: String = "res://art/ui/menu_frame_corner.png"
const EDGE_ART: String = "res://art/ui/menu_frame_edge.png"

## How much of the screen's shorter side one corner bracket takes. Big enough to
## be carved rather than a line, small enough that the interface it surrounds is
## still the thing you are looking at.
const CORNER_SHARE: float = 0.135
## The border strip's height against the corner's.
const EDGE_SHARE: float = 0.46

var light: Color = Color(1.0, 0.92, 0.82)

var _corner: Texture2D = null
var _edge: Texture2D = null
var _time: float = 0.0
var _drawn_at: float = -1.0
## Where a press last happened, as a fraction round the perimeter, and how much
## of that wave is left.
var _wave_at: float = 0.0
var _wave_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(CORNER_ART):
		_corner = load(CORNER_ART) as Texture2D
	if ResourceLoader.exists(EDGE_ART):
		_edge = load(EDGE_ART) as Texture2D
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	_wave_left = maxf(_wave_left - delta * Balance.MENU_FRAME_WAVE_FADE, 0.0)
	# Sampled, not driven. The frame is a few dozen quads and redrawing it every
	# frame for a sheen nobody is watching closely is the trade `flame.gd`
	# already lost once.
	if _time - _drawn_at >= 1.0 / maxf(Balance.MENU_FRAME_HZ, 1.0):
		_drawn_at = _time
		queue_redraw()


## A player touched something at this point on the screen. The wave leaves from
## the nearest point on the frame and runs both ways round it.
func pulse_at(where: Vector2) -> void:
	_wave_at = perimeter_of(where)
	_wave_left = 1.0


## Where a screen point sits as a fraction round the frame, clockwise from the
## top-left corner. Projected onto the nearest edge rather than measured as an
## angle: a press near the left edge should light the left edge, and an angle
## from the centre would send it to whichever corner the aspect ratio favoured.
func perimeter_of(where: Vector2) -> float:
	var span: Vector2 = size
	if span.x <= 1.0 or span.y <= 1.0:
		return 0.0
	var to_left: float = where.x
	var to_right: float = span.x - where.x
	var to_top: float = where.y
	var to_bottom: float = span.y - where.y
	var nearest: float = minf(minf(to_left, to_right), minf(to_top, to_bottom))
	var across: float = span.x + span.y
	if is_equal_approx(nearest, to_top):
		return where.x * 0.5 / across
	if is_equal_approx(nearest, to_right):
		return (span.x + where.y) * 0.5 / across
	if is_equal_approx(nearest, to_bottom):
		return (span.x + span.y + (span.x - where.x)) * 0.5 / across
	return (span.x + span.y + span.x + (span.y - where.y)) * 0.5 / across


func _draw() -> void:
	if _corner == null or size.x <= 1.0 or size.y <= 1.0:
		return
	var short: float = minf(size.x, size.y)
	var bracket: float = short * CORNER_SHARE
	var thick: float = bracket * EDGE_SHARE
	_draw_edges(bracket, thick)
	# The corners last, so a strip that runs a pixel long is covered by the
	# bracket rather than drawn over it.
	for index: int in 4:
		_draw_corner(index, bracket)


## The four straight runs, each a row of copies of the border strip.
##
## **Counted rather than stretched.** A strip scaled to the length of an edge is
## a smeared strip, and this is pixel art at four times its own size already.
## The copies are laid whole and the last one is clipped by the corner bracket
## that sits over it.
func _draw_edges(bracket: float, thick: float) -> void:
	if _edge == null:
		return
	var tile: float = thick * float(_edge.get_width()) \
		/ maxf(float(_edge.get_height()), 1.0)
	if tile <= 1.0:
		return
	for side: int in 4:
		var horizontal: bool = side == 0 or side == 2
		var run: float = (size.x if horizontal else size.y) - bracket * 2.0
		var many: int = int(ceil(run / tile))
		for step: int in maxi(many, 0):
			var along: float = bracket + float(step) * tile
			var at: Vector2
			var turn: float = 0.0
			match side:
				0:
					at = Vector2(along, 0.0)
				1:
					at = Vector2(size.x, along)
					turn = PI * 0.5
				2:
					at = Vector2(size.x - along, size.y)
					turn = PI
				_:
					at = Vector2(0.0, size.y - along)
					turn = PI * 1.5
			var here: float = _around(side, along, bracket)
			draw_set_transform(at, turn, Vector2.ONE)
			draw_texture_rect(_edge, Rect2(0.0, 0.0, tile + 1.0, thick),
				false, light_at(here))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_corner(index: int, bracket: float) -> void:
	# The art is drawn as a top-left corner; the other three are it turned.
	var at: Vector2 = Vector2.ZERO
	var turn: float = 0.0
	match index:
		0:
			at = Vector2.ZERO
		1:
			at = Vector2(size.x, 0.0)
			turn = PI * 0.5
		2:
			at = size
			turn = PI
		_:
			at = Vector2(0.0, size.y)
			turn = PI * 1.5
	# **The vine on it breathes.** A hundredth of the bracket, on the corner's
	# own clock: enough that the eye catches it and never enough to show a seam
	# where the bracket meets the strip.
	var breath: float = 1.0 + sin(_time * 0.37 + float(index) * 1.9) \
		* Balance.MENU_FRAME_BREATH
	draw_set_transform(at, turn, Vector2.ONE)
	draw_texture_rect(_corner,
		Rect2(0.0, 0.0, bracket * breath, bracket * breath), false,
		light_at(float(index) * 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Whether a press is still travelling. For the gate.
func waving() -> bool:
	return _wave_left > 0.0


## Advance the frame's own clock. For the gate, which has no frames to spend.
func advance(delta: float) -> void:
	_time += delta
	_wave_left = maxf(_wave_left - delta * Balance.MENU_FRAME_WAVE_FADE, 0.0)


## How far round the frame a point on one side is, as a fraction.
func _around(side: int, along: float, bracket: float) -> float:
	var across: float = maxf(size.x + size.y, 1.0)
	var run: float = along - bracket
	match side:
		0:
			return run * 0.5 / across
		1:
			return (size.x + run) * 0.5 / across
		2:
			return (size.x + size.y + run) * 0.5 / across
		_:
			return (size.x * 2.0 + size.y + run) * 0.5 / across


## What one piece of the frame is multiplied by at this instant. Public so the
## gate can read the bound off the thing itself rather than off a copy of the
## arithmetic: the scene's own
## light, darkened the way the branches are, plus whatever the sheen and the
## wave are adding there.
##
## **Additive on top of a multiply**, and only ever brightening - the same bound
## `UiJuice` is held to. A frame that could darken would be able to swallow the
## menu's own edges on a dark backdrop.
func light_at(around: float) -> Color:
	var base: Color = Color(light.r * Balance.MENU_FRAME_SHADE,
		light.g * Balance.MENU_FRAME_SHADE * 0.97,
		light.b * Balance.MENU_FRAME_SHADE * 0.93, 1.0)
	var add: float = _sheen(around) + _wave(around)
	return Color(minf(base.r + add, 1.0), minf(base.g + add * 0.92, 1.0),
		minf(base.b + add * 0.78, 1.0), 1.0)


## One slow pass of light round the perimeter. A narrow band rather than a
## gradient, so it reads as something travelling rather than as the whole frame
## brightening.
func _sheen(around: float) -> float:
	var head: float = fposmod(_time / maxf(Balance.MENU_FRAME_SHEEN_SECONDS, 1.0), 1.0)
	var gap: float = absf(fposmod(around - head + 0.5, 1.0) - 0.5)
	return Balance.MENU_FRAME_SHEEN * maxf(1.0 - gap / Balance.MENU_FRAME_SHEEN_WIDTH, 0.0)


## The answer to a press: a wave leaving the touched point in both directions,
## fading as it goes and as it ages.
func _wave(around: float) -> float:
	if _wave_left <= 0.0:
		return 0.0
	var travelled: float = (1.0 - _wave_left) * Balance.MENU_FRAME_WAVE_REACH
	var gap: float = absf(fposmod(around - _wave_at + 0.5, 1.0) - 0.5)
	var front: float = absf(gap - travelled)
	return Balance.MENU_FRAME_WAVE * _wave_left \
		* maxf(1.0 - front / Balance.MENU_FRAME_SHEEN_WIDTH, 0.0)
