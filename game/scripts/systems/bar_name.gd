class_name BarName
extends Control

## **The two letters written on a pool bar, drawn rather than laid out.**
##
## A `Label` cannot do this job. `Control.size` is clamped to the combined
## minimum size and a Label's minimum height comes from its font, so a Label
## anchored to fill an eight-pixel bar is not eight pixels tall - it is as tall
## as the font wants, and it hangs out of the bottom of its parent onto whatever
## is underneath. "MP" was sitting across the SP bar, and `layout_check` was red
## on main because the SP bar arrived without anybody running the gate.
##
## Two other fixes were tried and measured first, and both are worse:
##
##  - **Growing the bars to fit.** At 430 wide the pools column has no vertical
##    room to give: taller bars pushed the whole top row down and produced six
##    fresh overlaps in the act line, the boss readout and the city icon.
##  - **Putting the name beside the bar.** A row is as tall as its tallest
##    child, so the Label drove the row height exactly as it had driven its own,
##    and the same six overlaps came back.
##
## A plain `Control` has no font-driven minimum, so this is exactly the rect it
## is given. The glyphs may paint a pixel or two past a very thin bar, which is
## what a name written on a bar looks like, and nothing in the layout can
## collide with something that is not in the layout.

var text: String = ""
## **The pool's own figures, on the bar** (owner, 2026-09-22: "Player HP MP SP
## all need current/max values and percentages displayed within their progress
## bars"). Drawn at the right end, as the name is at the left.
var value_text: String = ""
var font_size: int = 11
var inset: float = 5.0
var tint: Color = Color(0.96, 0.94, 0.90, 0.95)
var outline: Color = Color(0.04, 0.03, 0.03, 0.85)


## Where this control's lettering actually lands, for `CrispText`.
##
## The pixel grid steps over type by keeping a mask of every rectangle a string
## is drawn in, and it finds those by class - which can only ever see the ones
## Godot lays out. This one paints its own, so it says so; without this the grid
## chewed the three pool captions in the corner of the HUD and nothing else in
## the interface, which is a very confusing bug to be shown.
##
## The whole rect rather than the glyphs' own box: a name written on a bar is a
## couple of letters in a strip a few pixels tall, and measuring the string to
## the pixel would hold open a rectangle the same size anyway.
func crisp_rects() -> Array[Rect2]:
	if text.is_empty() or not is_visible_in_tree():
		return []
	return [get_global_rect()] as Array[Rect2]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchors *and* offsets - see `PixelGrid._ready`. The bare call keeps the
	# rect the control already has, which inside `_ready` is nothing at all,
	# and this one paints from `size`.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Nothing may ask this to be bigger than the bar it names.
	custom_minimum_size = Vector2.ZERO


func _draw() -> void:
	if text.is_empty():
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	# Sat on the bar's own middle rather than on a baseline, so a 7px bar and a
	# 14px one both read as having the name on them.
	var at := Vector2(inset, size.y * 0.5 + float(font_size) * 0.36)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		font_size, 4, outline)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, tint)
	if not value_text.is_empty():
		var wide: float = font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, font_size).x
		var right := Vector2(size.x - inset - wide, at.y)
		draw_string_outline(font, right, value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			font_size, 4, outline)
		draw_string(font, right, value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			font_size, tint)
