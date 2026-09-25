class_name HealthBar
extends Node2D

## A health bar that rides above a unit in world space.
##
## Stage 1 has no HUD by design, but "does swinging feel good" is unanswerable
## if you cannot see whether a swing landed. This is the smallest thing that
## makes damage legible, and it stays attached to the unit rather than becoming
## screen furniture.

## **One canvas item, as of 2026-09-24.** A bar was a `Node2D` with two
## `ColorRect`s and a trail rect - three canvas items a body, sixty bodies on
## Act X, and a frame drawn as polylines that break the batch every rect
## around them joins. `perf_bisect --visuals` and the act census both named
## the bars. The rects are read for their authored colours in `_ready` and
## freed; everything is filled rects in one `_draw`, redrawn only when the
## health or the trail moves, and a filled rect is a command the renderer
## batches. The bar still rides its unit, so it costs nothing per frame.

@export var background: ColorRect
@export var fill: ColorRect

## Enemies only show a bar once they have been hurt; the hero always shows one.
@export var hide_until_damaged: bool = true

var _bound: Health = null
## The pale trail behind the fill: a hit leaves it where the health was and
## it drains after, so a blow that takes one percent off a huge body is still
## a visible bite rather than a bar that reads as full (owner brief,
## 2026-09-12: "it always showed a full health bar despite being hit").
var _trail_ratio: float = 1.0
var _ratio: float = 1.0
## Width against the ordinary bar; the ranked wear a wider one.
var _width_scale: float = 1.0
## Whether this bar dresses as a ranked body's: a warm frame with end caps
## and a ticked fill, so an elite reads as one across the field.
var _ranked: bool = false
var _background_colour: Color = Balance.HEALTH_BAR_BACKGROUND_COLOUR
var _fill_colour: Color = Balance.HEALTH_BAR_FILL_COLOUR
## A bite flashes the fill toward white and it settles (2026-09-25): the
## bar says "that landed" before the trail says how much.
var _flash: float = 0.0


func _ready() -> void:
	# Above everything in the sorted layer, and absolute rather than relative so
	# it cannot inherit a parent's depth. A health bar is a readout, not scenery:
	# foliage standing in front of the hero was drawing over the hero's own bar,
	# which is correct y-sorting and completely wrong information.
	z_index = Balance.HEALTH_BAR_Z
	z_as_relative = false
	# The scene's rects carry the authored colours and nothing else now; a
	# ranked bar set before `_ready` keeps its rank fill.
	if background != null:
		_background_colour = background.color
		background.queue_free()
		background = null
	if fill != null:
		if not _ranked:
			_fill_colour = fill.color
		fill.queue_free()
		fill = null
	visible = not hide_until_damaged
	queue_redraw()


func bind(health: Health) -> void:
	if _bound != null and _bound.changed.is_connected(_on_changed):
		_bound.changed.disconnect(_on_changed)
	_bound = health
	if _bound == null:
		return
	_bound.changed.connect(_on_changed)
	_on_changed(_bound.current_hp, _bound.max_hp)


func _apply_size() -> void:
	queue_redraw()


## A wider bar, for a body worth reading: elites and bosses. Shown at once
## rather than on the first hit, so the rank is visible before it matters.
func set_ranked(scale_width: float) -> void:
	_width_scale = maxf(scale_width, 1.0)
	_ranked = true
	hide_until_damaged = false
	visible = true
	_fill_colour = Balance.HEALTH_BAR_RANK_FILL
	_apply_size()


func _on_changed(current: float, maximum: float) -> void:
	var ratio: float = clampf(current / maximum if maximum > 0.0 else 0.0, 0.0, 1.0)
	if ratio < _ratio:
		# A bite: the trail stays where the health was and drains after.
		_trail_ratio = maxf(_trail_ratio, _ratio)
		_flash = 1.0
		set_process(true)
	elif ratio > _trail_ratio:
		_trail_ratio = ratio
	_ratio = ratio
	_apply_size()
	if hide_until_damaged:
		visible = ratio < 1.0


func _process_measured(delta: float) -> void:
	_flash = maxf(_flash - delta / Balance.HEALTH_BAR_FLASH_SECONDS, 0.0)
	if _trail_ratio <= _ratio + 0.0005 and _flash <= 0.0:
		_trail_ratio = _ratio
		_apply_size()
		set_process(false)
		return
	if _trail_ratio <= _ratio + 0.0005:
		_trail_ratio = _ratio
		_apply_size()
		return
	# A short hold, then a drain: the eye catches the pale bite before it goes.
	_trail_ratio = maxf(_trail_ratio - delta * Balance.HEALTH_BAR_TRAIL_RATE, _ratio)
	_apply_size()


## The bar's rect in its own space: centred on the node, hanging below it.
func _bar_rect() -> Rect2:
	var w: float = Balance.HEALTH_BAR_WIDTH * _width_scale
	var h: float = Balance.HEALTH_BAR_RANK_HEIGHT if _ranked else Balance.HEALTH_BAR_HEIGHT
	return Rect2(-w * 0.5, 0.0, w, h)


## The whole bar: background, trail, fill, then the pixel frame - a one-pixel
## outline with a bevel, so the bar reads as a piece of the interface rather
## than two rectangles (owner brief, 2026-09-12). A ranked bar wears a warm
## frame with end caps and ticks across the fill, which is how an elite reads
## as one at a glance. Every stroke is a filled rect: an outline drawn with
## `draw_rect(..., false)` or a `draw_line` is a polyline, and a polyline is
## its own draw call.
func _draw_measured() -> void:
	var rect: Rect2 = _bar_rect()
	draw_rect(rect, _background_colour)
	if _trail_ratio > _ratio:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * _trail_ratio, rect.size.y)),
			Balance.HEALTH_BAR_TRAIL_COLOUR)
	if _ratio > 0.0:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * _ratio, rect.size.y)),
			_fill_colour.lerp(Color.WHITE, _flash * Balance.HEALTH_BAR_FLASH_GAIN))
	var outline: Color = Balance.HEALTH_BAR_RANK_FRAME if _ranked else Balance.HEALTH_BAR_FRAME_OUTLINE
	_frame(rect.grow(1.0), outline)
	if _ranked:
		_frame(rect.grow(2.0), Balance.HEALTH_BAR_FRAME_OUTLINE)
		# End caps.
		draw_rect(Rect2(rect.position.x - 3.0, rect.position.y - 1.0, 2.0, rect.size.y + 2.0), outline)
		draw_rect(Rect2(rect.end.x + 1.0, rect.position.y - 1.0, 2.0, rect.size.y + 2.0), outline)
		# Ticks across the fill, so a quarter is a quarter.
		for tick: int in range(1, Balance.HEALTH_BAR_RANK_TICKS):
			var x: float = rect.position.x + rect.size.x * float(tick) / float(Balance.HEALTH_BAR_RANK_TICKS)
			draw_rect(Rect2(x - 0.5, rect.position.y, 1.0, rect.size.y),
				Color(Balance.HEALTH_BAR_FRAME_OUTLINE, 0.7))
	else:
		# Bevel: light along the top, shade along the bottom.
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), Balance.HEALTH_BAR_FRAME_LIGHT)
		draw_rect(Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x, 1.0), Balance.HEALTH_BAR_FRAME_SHADE)


## A one-pixel frame as four filled rects.
func _frame(rect: Rect2, colour: Color) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), colour)
	draw_rect(Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x, 1.0), colour)
	draw_rect(Rect2(rect.position.x, rect.position.y + 1.0, 1.0, rect.size.y - 2.0), colour)
	draw_rect(Rect2(rect.end.x - 1.0, rect.position.y + 1.0, 1.0, rect.size.y - 2.0), colour)


## `FrameProfile` bucket "d_health_bar": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_health_bar", started)


## `FrameProfile` bucket "p_health_bar": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_health_bar", started)
