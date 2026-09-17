class_name CrispText
extends Control

## **The type, drawn above the grid.**
##
## Owner, 2026-09-17: *"The pixelshader should apply to everything in the game if
## possible except for text"*, and, on the town scope, *"The text in the town
## view scope is not legible with the pixelshader so text must not be
## affected."*
##
## **The whole of "except for text" is one layer number.** A screen filter
## pixelates what was drawn below it and cannot touch what is drawn above, so a
## string that must stay sharp has to be drawn later than the filter. That is
## free for the HUD, which already sits above the world's grid at layer 20 - and
## it is not free for the two cases the owner reported:
##
## - **World-space labels.** The town scope's tier captions are `Label` nodes
##   parented into the world, under the world's filter. Nothing about them was
##   wrong; they were simply below the grid.
## - **The interface**, once the owner's second switch turns a grid on over that
##   too.
##
## **Muted and redrawn, rather than redrawn on top.** The obvious version leaves
## the original where it is and draws a sharp copy over it. That does not work:
## the blocky copy underneath is *wider* than the sharp one, so every letter
## comes out with a quantised fringe around it, which reads worse than the
## blocky text did on its own. So a string this node takes over is turned
## transparent where it was authored - alpha only, so nothing about the layout
## moves and `layout_check` still sees the same rectangles in the same places -
## and drawn here instead.
##
## **It reads the tree; it does not own it.** Nothing is re-parented, nothing is
## resized, no container is given a different child. A screen that changes its
## own text changes what this draws on the next frame, because this asks the
## control what it says rather than being told once. That is the same "read it
## twice" rule `HoldYard` stands its buildings under, and it is what stops this
## and the interface ever disagreeing about what the game said.
##
## **What it cannot take over is declared rather than skipped.** A
## `RichTextLabel` is marked-up text with its own layout engine - wrapping,
## inline colour, images, tables - and `draw_string` is not that engine. Those
## are handed to the filter as exempt rectangles instead (see
## `Balance.UI_PIXEL_FILTER_EXCLUDE_MAX`), so the grid skips them where they
## stand. A ninth is a gate failure rather than one silently falling off the
## end.
##
## **Turned off, it puts everything back.** Every mute is recorded with the
## value it replaced, so releasing is exact rather than a guess at what the
## colour used to be - and a control freed while muted is dropped from the
## ledger rather than written back to.

## Controls that carry a string this node knows how to draw.
##
## `Label` and `Button` cover nearly all of it. `Button` is the interesting one:
## it draws its plate and its caption in the same pass, so the plate cannot be
## pixelated and the caption spared by any means except muting the caption.
const DRAWN: Array[String] = [
	"Label", "Button", "CheckBox", "CheckButton", "OptionButton", "LineEdit",
]

## Controls whose text this node cannot reproduce, and which are therefore cut
## out of the grid where they stand.
const EXEMPT: Array[String] = [
	"RichTextLabel", "TextEdit", "CodeEdit",
]

## The font colour overrides a muted control may be carrying. All of them are
## taken, because a `Button` that only had `font_color` muted still draws its
## caption the moment the pointer crosses it.
const COLOURS: Array[String] = [
	"font_color", "font_hover_color", "font_pressed_color",
	"font_focus_color", "font_disabled_color", "font_hover_pressed_color",
	"font_uneditable_color", "font_placeholder_color",
]

## Roots whose text is taken over whenever this node is running at all. The
## world's grid is always over them when the feature is on.
var world_roots: Array[Node] = []

## Roots whose text is taken over only while the interface's own grid is on.
var ui_roots: Array[Node] = []

## Where the exempt rectangles are sent: the interface's own grid, since a
## `RichTextLabel` is an interface thing. A `PixelGrid` rather than a
## `PixelFilter`, because the main menu has the grid without the layer.
var ui_filter_grid: PixelGrid = null

var _muted: Array[Dictionary] = []
var _strings: Array[Dictionary] = []
var _on: bool = false
var _ui: bool = false


func _ready() -> void:
	name = "CrispText"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# So the two switches in the video settings reach it while the game is
	# running. Without this a preference changes a saved value and nothing on
	# screen, which is how a setting reads as broken.
	add_to_group(Graphics.SETTINGS_GROUP)
	refresh_from_settings()


func refresh_from_settings() -> void:
	set_enabled(Graphics.pixel_filter(), Graphics.pixel_filter_ui())


## Both switches at once, because the second only means anything under the
## first: a sharp world under a blocky interface is this feature's own problem
## pointing the other way.
func set_enabled(on: bool, over_ui: bool) -> void:
	var changed: bool = on != _on or over_ui != _ui
	_on = on
	_ui = on and over_ui
	if changed:
		_release()
	queue_redraw()


func enabled() -> bool:
	return _on


func over_ui() -> bool:
	return _ui


## How many strings were drawn last frame. For the gate, which has no screen to
## read and needs to know the difference between "took the text over" and "drew
## nothing at all" - a comparison of two nothings being the most dangerous shape
## a check can take.
func drawn() -> int:
	return _strings.size()


func muted() -> int:
	return _muted.size()


func _process(_delta: float) -> void:
	if not _on:
		return
	_gather()
	queue_redraw()


## Walks the roots and decides, for every text-bearing control under them, what
## is drawn here and what is cut out of the grid.
func _gather() -> void:
	_release()
	_strings.clear()
	var exempt: Array[Rect2] = []

	# `Variant` loop variables, because a typed one casts on assignment - so a
	# root freed while this was watching it would throw here, before `_walk`
	# could guard it. Same reason the walk and the release both take one.
	for root: Variant in world_roots:
		_walk(root, exempt)
	if _ui:
		for root: Variant in ui_roots:
			_walk(root, exempt)

	if ui_filter_grid != null and is_instance_valid(ui_filter_grid):
		ui_filter_grid.set_exclusions(exempt)


## Takes a `Variant` for the same reason the release does: a root freed while
## this was watching it cannot be typed as a `Node` without throwing on the spot.
func _walk(from: Variant, exempt: Array[Rect2]) -> void:
	if from == null or not is_instance_valid(from):
		return
	var node: Node = from as Node
	if node == null:
		return
	# This node's own children are the sharp copies. Walking into them would
	# have it take over the text it is itself drawing.
	if node == self:
		return
	var control: Control = node as Control
	if control != null:
		if not control.is_visible_in_tree():
			# A hidden branch draws nothing, so nothing under it needs muting -
			# and descending anyway would mute a whole closed screen's captions
			# and leave them muted when it opens.
			return
		var kind: String = control.get_class()
		if EXEMPT.has(kind):
			if exempt.size() < Balance.UI_PIXEL_FILTER_EXCLUDE_MAX:
				exempt.append(control.get_global_rect())
			return
		if DRAWN.has(kind):
			_take(control)
	for child: Node in node.get_children():
		_walk(child, exempt)


## Records what a control says and where, and turns its own copy transparent.
func _take(control: Control) -> void:
	var text: String = String(control.get("text"))
	if text.is_empty():
		return
	var font: Font = control.get_theme_font(&"font")
	if font == null:
		return
	var size: int = control.get_theme_font_size(&"font_size")
	if size <= 0:
		size = 16

	# The colour the string *would* have been drawn in, read before it is muted.
	# A disabled button is dimmer than a live one and a copy at full strength
	# would say it can be pressed.
	var ink: Color = _ink(control)
	var outline: int = control.get_theme_constant(&"outline_size")
	var outline_ink: Color = control.get_theme_color(&"font_outline_color")

	_mute(control)

	_strings.append({
		"text": text,
		"font": font,
		"size": size,
		"ink": ink,
		"outline": outline,
		"outline_ink": outline_ink,
		"rect": control.get_global_rect(),
		"align": _align(control),
		"line": _line_height(control, font, size),
	})


## What colour this control's text is right now, given what it is doing.
func _ink(control: Control) -> Color:
	var button: Button = control as Button
	if button != null:
		if button.disabled:
			return control.get_theme_color(&"font_disabled_color")
		if button.button_pressed:
			return control.get_theme_color(&"font_pressed_color")
	return control.get_theme_color(&"font_color")


func _align(control: Control) -> int:
	var label: Label = control as Label
	if label != null:
		return int(label.horizontal_alignment)
	var button: Button = control as Button
	if button != null:
		return int(button.alignment)
	return int(HORIZONTAL_ALIGNMENT_LEFT)


## Where the first baseline sits inside the control's rectangle.
##
## A `Label` with one line centres it vertically; anything taller than its text
## is centred the same way. Taken from the font rather than assumed, because a
## theme may set a line height that is not the font's own.
func _line_height(control: Control, font: Font, size: int) -> float:
	var height: float = font.get_height(size)
	var label: Label = control as Label
	if label != null and label.get_line_count() > 1:
		return height
	return height


## Turns a control's own copy of its text transparent, remembering every
## override it replaced so the release is exact.
func _mute(control: Control) -> void:
	var was: Dictionary = {}
	for key: String in COLOURS:
		var name: StringName = StringName(key)
		# `has_theme_color_override` is the question, not `get_theme_color`:
		# writing back a colour that was inherited from the theme would pin it
		# to today's theme for ever, and a theme change would then miss it.
		was[key] = control.get_theme_color(name) if \
			control.has_theme_color_override(name) else null
		control.add_theme_color_override(name, Color(0.0, 0.0, 0.0, 0.0))
	var outline: StringName = &"font_outline_color"
	was["font_outline_color"] = control.get_theme_color(outline) if \
		control.has_theme_color_override(outline) else null
	control.add_theme_color_override(outline, Color(0.0, 0.0, 0.0, 0.0))
	_muted.append({"control": control, "was": was})


## Puts every muted control back exactly as it was found.
func _release() -> void:
	for row: Dictionary in _muted:
		# **Validity before the cast, never after it.** `as Control` on a freed
		# object throws on the spot, so a guard written *under* the cast never
		# runs - which is the ninety-five-errors-a-frame flood `companion_check`
		# found, and which this file shipped again until the gate caught it.
		var held: Variant = row["control"]
		if held == null or not is_instance_valid(held):
			continue
		var control: Control = held as Control
		if control == null:
			continue
		var was: Dictionary = row["was"] as Dictionary
		for key: String in was:
			var name: StringName = StringName(key)
			var value: Variant = was[key]
			if value == null:
				control.remove_theme_color_override(name)
			else:
				control.add_theme_color_override(name, value as Color)
	_muted.clear()


func _draw() -> void:
	if not _on:
		return
	for row: Dictionary in _strings:
		var rect: Rect2 = row["rect"] as Rect2
		var font: Font = row["font"] as Font
		var size: int = int(row["size"])
		var line: float = float(row["line"])
		# Baseline rather than top: `draw_string` measures from the baseline, so
		# a rect's top is a line's ascent above where the glyphs sit.
		var at: Vector2 = Vector2(rect.position.x,
			rect.position.y + (rect.size.y - line) * 0.5 + font.get_ascent(size))
		var outline: int = int(row["outline"])
		if outline > 0:
			font.draw_string_outline(get_canvas_item(), at, String(row["text"]),
				row["align"] as HorizontalAlignment, rect.size.x, size, outline,
				row["outline_ink"] as Color)
		font.draw_string(get_canvas_item(), at, String(row["text"]),
			row["align"] as HorizontalAlignment, rect.size.x, size,
			row["ink"] as Color)


func _exit_tree() -> void:
	# A screen torn down with the filter on must not leave the game's captions
	# invisible. That failure is silent and permanent, which is the shape the
	# boss hush was gated for.
	_release()
