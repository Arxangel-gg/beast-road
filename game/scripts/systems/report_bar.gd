class_name ReportBar
extends Control

## A progress bar for the end-of-run report (owner, 2026-10-06, item 23:
## "a juicy end-of-run report with icons, sections and progress bars").
##
## Drawn rather than a `ProgressBar`, for two reasons. A `ProgressBar` has
## exactly two styleboxes and this bar has three bands - the trough, what was
## held before the road, and **what the road paid**, lit brighter at the end of
## the fill so a player sees their evening's share of the level at a glance.
## And a drawn control is exactly the rect it is given: nothing in the column
## can collide with a font-driven minimum, which is the lesson
## `a-label-cannot-be-smaller-than-its-font` records.
##
## **A readout reads.** It is handed its shares and draws them; nothing reads
## it back but the gate, through `share`, `gain` and `ticks`.

## The whole fill, 0 to 1, after the road.
var share: float = 0.0
## The part of `share` the road paid, lit brighter. Never past `share`.
var gain: float = 0.0
## Marks along the trough, 0 to 1 - the act boundaries on the road bar.
var ticks: PackedFloat32Array = PackedFloat32Array()
## The fill's colour; the gain is this lifted.
var tint: Color = Color("9b8fc4")
## How much of the fill is drawn, 0 to 1 - the rise when the report opens.
var shown: float = 1.0

const TROUGH: Color = Color("14120f")
const FRAME: Color = Color(0.91, 0.64, 0.24, 0.42)
const TICK: Color = Color(0.0, 0.0, 0.0, 0.55)
const RISE_SECONDS: float = 1.1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size.y <= 0.0:
		custom_minimum_size = Vector2(0.0, 14.0)
	resized.connect(queue_redraw)


## Hands the bar its figures and starts the rise. Headless there is nobody to
## watch a rise, and every gate reads the bar on the frame after it is set.
func present(new_share: float, new_gain: float, new_ticks: PackedFloat32Array = PackedFloat32Array()) -> void:
	share = clampf(new_share, 0.0, 1.0)
	gain = clampf(new_gain, 0.0, share)
	ticks = new_ticks
	if DisplayServer.get_name() == "headless":
		shown = 1.0
		queue_redraw()
		return
	shown = 0.0
	var tween: Tween = create_tween()
	tween.tween_method(_rise, 0.0, 1.0, RISE_SECONDS) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _rise(value: float) -> void:
	shown = value
	queue_redraw()


func _draw() -> void:
	var box: Rect2 = Rect2(Vector2.ZERO, size)
	if not box.has_area():
		return
	draw_rect(box, TROUGH)
	var inner: Rect2 = box.grow(-1.0)
	var filled: float = inner.size.x * share * shown
	if filled > 0.0:
		draw_rect(Rect2(inner.position, Vector2(filled, inner.size.y)), tint)
		# A lit top edge, so the fill has a thickness rather than being a stripe.
		draw_rect(Rect2(inner.position, Vector2(filled, 1.0)), tint.lightened(0.35))
	var lit: float = inner.size.x * gain * shown
	if lit > 0.0:
		var start: float = inner.position.x + maxf(filled - lit, 0.0)
		draw_rect(Rect2(Vector2(start, inner.position.y), Vector2(lit, inner.size.y)),
			tint.lightened(0.45))
		draw_rect(Rect2(Vector2(start, inner.position.y), Vector2(lit, 1.0)), Color.WHITE)
	for tick: float in ticks:
		if tick <= 0.0 or tick >= 1.0:
			continue
		var x: float = inner.position.x + inner.size.x * tick
		draw_rect(Rect2(Vector2(x, inner.position.y), Vector2(1.0, inner.size.y)), TICK)
	draw_rect(box, FRAME, false, 1.0)
