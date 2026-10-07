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
## The Warden's mana and stamina, as shares of their pools, drawn as thin bars
## under the health (owner, 2026-09-26). -1 is no bar: only the hero sets them,
## and a partner's stamina never crosses the wire, so theirs shows mana alone.
var _pools: PackedFloat32Array = PackedFloat32Array([-1.0, -1.0])
var _pool_colours: Array[Color] = [Color(Balance.UI_MANA_INDIGO), Color(Balance.UI_STAMINA_GREEN)]
## The pool the bar stands for, and the ward on top of it as a share of that
## pool (2026-09-30). Drawn League's way: a bright segment after the health,
## the whole bar rescaled when the two together pass the pool.
var _max_hp: float = 0.0
var _shield_share: float = 0.0
## Notched every `HEALTH_BAR_SEGMENT_STEPS` health: the Warden's bar.
var _segmented: bool = false
## A tower's or a wall's: the frame lights as it falls.
var _structure: bool = false
var _alarm_clock: float = 0.0
var _alarm_redraw_left: float = 0.0


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
	if _bound != null and _bound.shield_changed.is_connected(_on_shield):
		_bound.shield_changed.disconnect(_on_shield)
	_bound = health
	if _bound == null:
		return
	_bound.changed.connect(_on_changed)
	_bound.shield_changed.connect(_on_shield)
	_on_changed(_bound.current_hp, _bound.max_hp)


## Notches every so much health (the Warden's bar). A readout: nothing reads it.
func set_segmented(on: bool) -> void:
	_segmented = on
	queue_redraw()


## A tower's or a wall's bar, whose frame lights as the structure falls.
func set_structure(on: bool) -> void:
	_structure = on
	_wake_for_alarm()
	queue_redraw()


## **How much health one notch stands for**, for a pool of `pool` and at most
## `most` notches. The first step on the list that fits; past the last, the
## last. Static so the HUD's bar and the one over the head cannot disagree.
static func segment_step(pool: float, most: int) -> float:
	for step: float in Balance.HEALTH_BAR_SEGMENT_STEPS:
		if pool / step <= float(most):
			return step
	return Balance.HEALTH_BAR_SEGMENT_STEPS[Balance.HEALTH_BAR_SEGMENT_STEPS.size() - 1]


## **How loudly a structure's frame calls**: nothing above `ALARM_FROM`, all of
## it at `ALARM_FULL` and below. A share, so the gate can read it.
static func alarm_for(ratio: float) -> float:
	if ratio <= 0.0:
		return 0.0
	return clampf((Balance.HEALTH_BAR_ALARM_FROM - ratio)
		/ (Balance.HEALTH_BAR_ALARM_FROM - Balance.HEALTH_BAR_ALARM_FULL), 0.0, 1.0)


func alarm() -> float:
	return alarm_for(_ratio) if _structure else 0.0


## The ward as a share of the pool, and whether the bar is rescaled for it.
func shield_share() -> float:
	return _shield_share


## The share of the pool the whole bar stands for: one, or health and ward
## together when they pass it.
func scale_total() -> float:
	return maxf(1.0, _ratio + _shield_share)


func _on_shield(remaining: float) -> void:
	var share: float = remaining / _max_hp if _max_hp > 0.0 else 0.0
	share = maxf(share, 0.0)
	if is_equal_approx(share, _shield_share):
		return
	_shield_share = share
	if hide_until_damaged:
		visible = _ratio < 1.0 or _shield_share > 0.0
	queue_redraw()


func _wake_for_alarm() -> void:
	if alarm() > 0.0:
		set_process(true)


func _apply_size() -> void:
	queue_redraw()


## Mana then stamina as shares of their pools, -1 for a bar not shown. A change
## too small to move a pixel is not a redraw.
func set_pools(mana: float, stamina: float) -> void:
	var wanted := PackedFloat32Array([mana, stamina])
	var moved: bool = false
	for index: int in wanted.size():
		var value: float = clampf(wanted[index], 0.0, 1.0) if wanted[index] >= 0.0 else -1.0
		if (value < 0.0) != (_pools[index] < 0.0) or absf(value - _pools[index]) > 0.004:
			_pools[index] = value
			moved = true
	if moved:
		queue_redraw()


## How tall the whole stack is, from the top of the health to the bottom of the
## last pool, so the hero can stand it clear of a head.
func stack_height() -> float:
	var height: float = _bar_rect().size.y
	for value: float in _pools:
		if value >= 0.0:
			height += Balance.HERO_POOL_BAR_GAP + Balance.HERO_POOL_BAR_HEIGHT
	return height


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
	_max_hp = maximum
	if _bound != null:
		_shield_share = _bound.shield() / maximum if maximum > 0.0 else 0.0
	_wake_for_alarm()
	_apply_size()
	if hide_until_damaged:
		visible = ratio < 1.0 or _shield_share > 0.0


func _process_measured(delta: float) -> void:
	_flash = maxf(_flash - delta / Balance.HEALTH_BAR_FLASH_SECONDS, 0.0)
	var alarmed: bool = alarm() > 0.0
	if alarmed:
		_alarm_clock += delta
	if _trail_ratio <= _ratio + 0.0005 and _flash <= 0.0:
		_trail_ratio = _ratio
		if not alarmed:
			_apply_size()
			set_process(false)
			return
		# Only the pulse is moving: redrawn on its own clock.
		_alarm_redraw_left -= delta
		if _alarm_redraw_left <= 0.0:
			_alarm_redraw_left = 1.0 / Balance.HEALTH_BAR_ALARM_HZ
			_apply_size()
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
	# The trough is see-through over the road (owner, 2026-10-07); the fill,
	# the trail and the frame stay whole, because they are what is read.
	draw_rect(rect, Color(_background_colour, _background_colour.a * Balance.UI_BAR_SEE_THROUGH))
	# League's rule: health and ward together never overflow the bar - past the
	# pool, the whole bar stands for both.
	var total: float = scale_total()
	var fill_w: float = rect.size.x * _ratio / total
	if _trail_ratio > _ratio:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * minf(_trail_ratio / total, 1.0), rect.size.y)),
			Balance.HEALTH_BAR_TRAIL_COLOUR)
	if _ratio > 0.0:
		draw_rect(Rect2(rect.position, Vector2(fill_w, rect.size.y)),
			_fill_colour.lerp(Color.WHITE, _flash * Balance.HEALTH_BAR_FLASH_GAIN))
	if _shield_share > 0.0:
		var ward_w: float = minf(rect.size.x * _shield_share / total, rect.size.x - fill_w)
		if ward_w > 0.0:
			draw_rect(Rect2(rect.position.x + fill_w, rect.position.y, ward_w, rect.size.y),
				Balance.HEALTH_BAR_SHIELD_COLOUR)
			# A lit leading edge, so a thin ward still reads as a thing.
			draw_rect(Rect2(rect.position.x + fill_w, rect.position.y, minf(1.0, ward_w), rect.size.y),
				Balance.HEALTH_BAR_SHIELD_EDGE)
	if _segmented:
		_draw_notches(rect, _max_hp * total, Balance.HEALTH_BAR_SEGMENT_MOST)
	var outline: Color = Balance.HEALTH_BAR_RANK_FRAME if _ranked else Balance.HEALTH_BAR_FRAME_OUTLINE
	var calling: float = alarm()
	if calling > 0.0:
		outline = _alarm_colour(calling)
	_frame(rect.grow(1.0), outline)
	_draw_pools(rect)
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
	if calling > 0.0:
		_draw_alarm(rect, calling)


## Amber climbing to red as the structure falls.
func _alarm_colour(calling: float) -> Color:
	if calling < 0.5:
		return Balance.HEALTH_BAR_FRAME_OUTLINE.lerp(Balance.HEALTH_BAR_ALARM_AMBER, calling * 2.0)
	return Balance.HEALTH_BAR_ALARM_AMBER.lerp(Balance.HEALTH_BAR_ALARM_RED, (calling - 0.5) * 2.0)


## **The glow round a falling structure's frame**: two rings outside it that
## breathe, brighter and faster the lower it goes, and a corner bracket on
## each end at the loudest - the frame is the thing that highlights, so the
## bar's fill still says exactly how much is left.
func _draw_alarm(rect: Rect2, calling: float) -> void:
	var rate: float = lerpf(Balance.HEALTH_BAR_ALARM_PULSE_SLOW, Balance.HEALTH_BAR_ALARM_PULSE_FAST, calling)
	var pulse: float = 0.5 + 0.5 * sin(_alarm_clock * TAU * rate)
	var tone: Color = _alarm_colour(calling)
	_frame(rect.grow(2.0), Color(tone, calling * lerpf(0.45, 1.0, pulse)))
	_frame(rect.grow(3.0), Color(tone, calling * lerpf(0.12, 0.5, pulse)))
	if calling >= 0.5:
		var arm: float = 4.0
		var bright := Color(tone.lightened(0.25), clampf(calling * pulse + 0.25, 0.0, 1.0))
		for corner: Vector2 in [rect.grow(4.0).position, Vector2(rect.grow(4.0).end.x - 1.0, rect.grow(4.0).position.y),
				Vector2(rect.grow(4.0).position.x, rect.grow(4.0).end.y - 1.0), rect.grow(4.0).end - Vector2.ONE]:
			var sx: float = 1.0 if corner.x < rect.get_center().x else -1.0
			var sy: float = 1.0 if corner.y < rect.get_center().y else -1.0
			draw_rect(Rect2(minf(corner.x, corner.x + sx * (arm - 1.0)), corner.y, arm, 1.0), bright)
			draw_rect(Rect2(corner.x, minf(corner.y, corner.y + sy * (arm - 1.0)), 1.0, arm), bright)


## Notches across the bar: one every `segment_step` health, heavier every
## `HEALTH_BAR_SEGMENT_MAJOR`. A light notch is the top half of the bar and a
## heavy one the whole of it, which is how League draws the difference.
func _draw_notches(rect: Rect2, pool: float, most: int) -> void:
	if pool <= 0.0:
		return
	var step: float = segment_step(pool, most)
	var hp: float = step
	while hp < pool - 0.5:
		var x: float = floorf(rect.position.x + rect.size.x * hp / pool)
		var heavy: bool = step < Balance.HEALTH_BAR_SEGMENT_MAJOR \
			and is_zero_approx(fmod(hp, Balance.HEALTH_BAR_SEGMENT_MAJOR))
		var tall: float = rect.size.y if heavy or step >= Balance.HEALTH_BAR_SEGMENT_MAJOR else ceilf(rect.size.y * 0.55)
		draw_rect(Rect2(x, rect.position.y, 1.0, tall), Balance.HEALTH_BAR_SEGMENT_COLOUR)
		hp += step


## The thin mana and stamina bars under the health, the same width, framed
## the same way, so the three read as one readout.
func _draw_pools(health: Rect2) -> void:
	var y: float = health.end.y
	for index: int in _pools.size():
		var value: float = _pools[index]
		if value < 0.0:
			continue
		y += Balance.HERO_POOL_BAR_GAP
		var rect := Rect2(health.position.x, y, health.size.x, Balance.HERO_POOL_BAR_HEIGHT)
		draw_rect(rect, _background_colour)
		if value > 0.0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * value, rect.size.y)), _pool_colours[index])
		_frame(rect.grow(1.0), Balance.HEALTH_BAR_FRAME_OUTLINE)
		y = rect.end.y


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
