class_name ThemeBuilder
extends RefCounted

## Builds `res://ui_theme.tres` from the UI frame art.
##
## The theme used to be sixteen hand-authored StyleBoxFlats — flat rectangles
## with rounded corners — while `ui_button.png`, `ui_button_hover.png`,
## `ui_panel.png`, `ui_panel_dark.png`, `ui_bar_fill.png` and `ui_bar_back.png`
## sat in `res://art/ui/` referenced by nothing at all. Six pieces of finished
## art, imported and dead.
##
## Generating the theme rather than authoring it means the nine-patch margins
## live next to the reasoning for them, and re-running this after the art is
## redrawn costs one command instead of an afternoon in the theme editor.
##
##   godot --headless --path game --script res://tools/run_tool.gd -- theme
##
## **On the margins.** A nine-patch cuts the source into a 3x3: the corners are
## drawn as-is, the edges stretch along one axis, the middle stretches both ways.
## So the margin has to be at least as deep as the decoration in that corner, or
## the stretch smears a rivet across the whole edge. The numbers below were
## measured off the art by walking outward from the centre until the flat
## interior colour stopped, then rounded *up* to clear the corner bolts, which
## stick out further than the straight run of frame between them.

const ART: String = "res://art/ui/"
const OUTPUT: String = "res://ui_theme.tres"
const BODY_FONT: String = "res://fonts/AtkinsonHyperlegibleNext-Variable.ttf"
## Carved Roman capitals, for everything the game says loudly.
##
## A readable interface face with a real bold weight for buttons.
const DISPLAY_FONT: String = "res://fonts/AtkinsonHyperlegibleNext-Variable.ttf"

# --- Palette -----------------------------------------------------------------
# Kept identical to the previous hand-authored theme: the art changes, the
# reading colours do not.

const INK: Color = Color(0.85098, 0.80392, 0.72157)
const INK_BRIGHT: Color = Color(0.96863, 0.91765, 0.82353)
const INK_DIM: Color = Color(0.52, 0.5, 0.45, 0.55)
const GOLD: Color = Color(0.90980, 0.63922, 0.23922)
const OUTLINE: Color = Color(0.02, 0.04, 0.05, 0.9)

# --- Slices ------------------------------------------------------------------
# The kit's own nine-slice margins at the size the frames are installed at.
const BUTTON_SLICE_X: int = 21
const BUTTON_SLICE_Y: int = 15
const FOCUS_SLICE: int = 17
const FOCUS_EXPAND: float = 4.0

# Padding lives in UiMetrics, not here. The running game needs the same numbers
# to line runtime-positioned children up with the theme, and it cannot see this
# file — `export_presets.cfg` excludes `tools/*` from the build.

static func build() -> Dictionary:
	var theme := Theme.new()
	theme.default_font_size = 18

	var problems: PackedStringArray = []
	var body_font: Font = load(BODY_FONT) as Font if ResourceLoader.exists(BODY_FONT) else null
	var display_font: Font = load(DISPLAY_FONT) as Font \
		if ResourceLoader.exists(DISPLAY_FONT) else null
	if body_font == null:
		problems.append("missing %s" % BODY_FONT)
	else:
		var body_weight := FontVariation.new()
		body_weight.base_font = body_font
		body_weight.variation_opentype = {"wght": 500}
		body_font = body_weight
		theme.default_font = body_font
	if display_font == null:
		problems.append("missing %s" % DISPLAY_FONT)

	if display_font != null:
		var heading_weight := FontVariation.new()
		heading_weight.base_font = display_font
		heading_weight.variation_opentype = {"wght": 700}
		display_font = heading_weight

	# --- Buttons -------------------------------------------------------------
	#
	# **The Emberbound kit, as of 2026-09-30** (`art_inbox/chatgpt/ui`, the
	# owner's). Every state has art of its own now, pressed and disabled
	# included, so nothing is tinted to fake one: a darkened hover frame read as
	# the same button in worse light. The frames are the kit's 2x export resampled
	# to 192x48, because the kit drew a 64 px button with 20 px horns and this
	# game's buttons are 34-54 px tall; the slice is the kit's own 28/20 at that
	# scale, so a 34 px RIDE ON still holds both horns.
	var normal: StyleBox = _frame("ui_button", BUTTON_SLICE_X, BUTTON_SLICE_X,
		BUTTON_SLICE_Y, BUTTON_SLICE_Y, problems)
	var hover: StyleBox = _frame("ui_button_hover", BUTTON_SLICE_X, BUTTON_SLICE_X,
		BUTTON_SLICE_Y, BUTTON_SLICE_Y, problems)
	var pressed: StyleBox = _frame("ui_button_pressed", BUTTON_SLICE_X, BUTTON_SLICE_X,
		BUTTON_SLICE_Y, BUTTON_SLICE_Y, problems)
	var disabled: StyleBox = _frame("ui_button_disabled", BUTTON_SLICE_X, BUTTON_SLICE_X,
		BUTTON_SLICE_Y, BUTTON_SLICE_Y, problems)

	# Symmetric, and deep enough to clear the corner bolts rather than merely the
	# straight run of frame between them.
	#
	# These were 34/26/10/12. Left-aligned text therefore started 8px further from
	# its frame than it ended from the other one, and a line of 17px type in a 42px
	# button had 10 above and 12 below - which reads as text sitting low in its box
	# rather than centred in it. Both are the kind of thing you cannot name when
	# you look at it and cannot unsee once you can.
	for style: StyleBox in [normal, hover, pressed, disabled]:
		_pad(style, UiMetrics.PAD_BUTTON_X, UiMetrics.PAD_BUTTON_X, UiMetrics.PAD_BUTTON_Y, UiMetrics.PAD_BUTTON_Y)

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	# Focus is the kit's gold corner brackets, drawn a little outside the button
	# so they frame it rather than sit on its horns - a keyboard or pad focus
	# must never look like the hover under the mouse.
	theme.set_stylebox("focus", "Button", _focus_frame(problems))

	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK_BRIGHT)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", INK_DIM)
	theme.set_color("font_outline_color", "Button", OUTLINE)
	theme.set_constant("outline_size", "Button", 4)
	theme.set_font_size("font_size", "Button", 17)
	if display_font != null:
		theme.set_font("font", "Button", display_font)

	# The two loud buttons. **Primary** is the one thing a screen is for - begin
	# the road, ride on - in the kit's ember; **Danger** is the one that throws
	# something away, in its blood red. Variations of Button, so a screen opts in
	# with one line and everything else about the button is the theme's.
	for variation: Array in [["PrimaryButton", "ui_button_primary"],
			["DangerButton", "ui_button_danger"]]:
		var type: String = variation[0]
		var art: String = variation[1]
		theme.set_type_variation(type, "Button")
		var loud: Dictionary = {
			"normal": _frame(art, BUTTON_SLICE_X, BUTTON_SLICE_X, BUTTON_SLICE_Y,
				BUTTON_SLICE_Y, problems),
			"hover": _frame(art + "_hover", BUTTON_SLICE_X, BUTTON_SLICE_X,
				BUTTON_SLICE_Y, BUTTON_SLICE_Y, problems),
			"pressed": _frame(art + "_pressed", BUTTON_SLICE_X, BUTTON_SLICE_X,
				BUTTON_SLICE_Y, BUTTON_SLICE_Y, problems),
		}
		for state: String in loud:
			var style: StyleBox = loud[state]
			_pad(style, UiMetrics.PAD_BUTTON_X, UiMetrics.PAD_BUTTON_X, UiMetrics.PAD_BUTTON_Y,
				UiMetrics.PAD_BUTTON_Y)
			theme.set_stylebox(state, type, style)
		theme.set_color("font_color", type, INK_BRIGHT)
		theme.set_color("font_hover_color", type, Color.WHITE)

	# --- Panels --------------------------------------------------------------
	# The kit's slices, measured again on its art: the main frame's horns reach
	# about 40 px along each edge, the dark frame's 24, the inset's a thin
	# border, the tooltip's corner plates 28.
	var panel: StyleBox = _frame("ui_panel", 44, 44, 44, 44, problems)
	_pad(panel, UiMetrics.PAD_PANEL_X, UiMetrics.PAD_PANEL_X, UiMetrics.PAD_PANEL_Y, UiMetrics.PAD_PANEL_Y)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)

	# The plain frame for things that float over the game and must not compete
	# with it: tooltips and popups.
	var dark: StyleBox = _frame("ui_panel_dark", 24, 24, 24, 24, problems)
	_pad(dark, UiMetrics.PAD_DARK_X, UiMetrics.PAD_DARK_X, UiMetrics.PAD_DARK_Y, UiMetrics.PAD_DARK_Y)
	theme.set_stylebox("panel", "PopupPanel", dark)
	var tooltip: StyleBox = _frame("ui_panel_tooltip", 28, 28, 28, 28, problems)
	_pad(tooltip, UiMetrics.PAD_DARK_X, UiMetrics.PAD_DARK_X, UiMetrics.PAD_DARK_Y, UiMetrics.PAD_DARK_Y)
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
	theme.set_color("font_color", "TooltipLabel", INK)

	# A panel *inside* a panel must not repeat the ornate frame - riveted iron
	# nested in riveted iron reads as a rendering mistake. The stat preview in the
	# build panel is the case that needs this.
	theme.set_type_variation("InnerPanel", "PanelContainer")
	var inner: StyleBox = _frame("ui_panel_inset", 16, 16, 16, 16, problems)
	_pad(inner, UiMetrics.PAD_DARK_X, UiMetrics.PAD_DARK_X, UiMetrics.PAD_DARK_Y, UiMetrics.PAD_DARK_Y)
	theme.set_stylebox("panel", "InnerPanel", inner)

	# --- Bars ----------------------------------------------------------------
	#
	# No margins: both are a plain vertical gradient with nothing in the corners
	# to protect, so the whole texture may stretch. The fill is modulated per bar
	# by the HUD, which is why the art is a neutral warm ramp rather than one
	# specific colour.
	theme.set_stylebox("background", "ProgressBar", _frame("ui_bar_back", 0, 0, 0, 0, problems))
	theme.set_stylebox("fill", "ProgressBar", _frame("ui_bar_fill", 0, 0, 0, 0, problems))

	# --- Sliders -------------------------------------------------------------
	#
	# Reusing the bar art: a volume slider and a health bar are the same object
	# with a grabber on it. The vertical content margins are what give the track
	# its thickness - a StyleBox takes its minimum size from those, and with them
	# at zero the only visible part of a slider is the grabber floating in space.
	var track: StyleBox = _frame("ui_bar_back", 0, 0, 0, 0, problems)
	_pad(track, 0, 0, 5, 5)
	var filled: StyleBox = _frame("ui_bar_fill", 0, 0, 0, 0, problems)
	_pad(filled, 0, 0, 5, 5)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)

	# --- Text ----------------------------------------------------------------
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_outline_color", "Label", Color(0.02, 0.04, 0.05, 0.85))
	theme.set_constant("outline_size", "Label", 5)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_stylebox("normal", "LineEdit", _sunken())
	if body_font != null:
		theme.set_font("font", "Label", body_font)
		theme.set_font("font", "LineEdit", body_font)
		theme.set_font("normal_font", "RichTextLabel", body_font)
	if display_font != null:
		theme.set_font("bold_font", "RichTextLabel", display_font)
		theme.set_font("font", "TooltipLabel", display_font)
	theme.set_color("default_color", "RichTextLabel", INK)

	# --- Scrollbars ----------------------------------------------------------
	#
	# A persistent iron-and-amber rail rather than a hairline that only wheel
	# users can discover. Pressed and focus states matter here: this control is a
	# primary navigation path for mouse users without wheels and for controllers.
	theme.set_stylebox("scroll", "VScrollBar", _bar_slot())
	theme.set_stylebox("scroll_focus", "VScrollBar", _bar_slot(true))
	theme.set_stylebox("grabber", "VScrollBar", _bar_grabber(0.55))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _bar_grabber(0.85))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _bar_grabber(1.0))

	var error: String = ""
	if not problems.is_empty():
		error = ", ".join(problems)
	else:
		var status: int = ResourceSaver.save(theme, OUTPUT)
		if status != OK:
			error = "could not write %s (error %d)" % [OUTPUT, status]

	return {"ok": error.is_empty(), "error": error, "path": OUTPUT}


## A nine-patch from `res://art/ui/<id>.png`.
static func _frame(id: String, left: int, right: int, top: int, bottom: int,
		problems: PackedStringArray, tint: Color = Color.WHITE) -> StyleBox:
	var path: String = "%s%s.png" % [ART, id]
	if not ResourceLoader.exists(path):
		problems.append("missing %s" % path)
		return StyleBoxFlat.new()

	var style := StyleBoxTexture.new()
	style.texture = load(path)
	style.texture_margin_left = float(left)
	style.texture_margin_right = float(right)
	style.texture_margin_top = float(top)
	style.texture_margin_bottom = float(bottom)
	style.modulate_color = tint
	return style


## Space between the frame and whatever is drawn inside it.
static func _pad(style: StyleBox, left: int, right: int, top: int, bottom: int) -> void:
	style.content_margin_left = float(left)
	style.content_margin_right = float(right)
	style.content_margin_top = float(top)
	style.content_margin_bottom = float(bottom)


## The kit's focus brackets, standing `FOCUS_EXPAND` outside what they frame.
static func _focus_frame(problems: PackedStringArray) -> StyleBox:
	var style: StyleBox = _frame("ui_focus_frame", FOCUS_SLICE, FOCUS_SLICE, FOCUS_SLICE,
		FOCUS_SLICE, problems)
	var textured := style as StyleBoxTexture
	if textured == null:
		return _focus_ring()
	textured.draw_center = false
	textured.expand_margin_left = FOCUS_EXPAND
	textured.expand_margin_right = FOCUS_EXPAND
	textured.expand_margin_top = FOCUS_EXPAND
	textured.expand_margin_bottom = FOCUS_EXPAND
	return textured


static func _focus_ring() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(GOLD, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style


static func _sunken() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.07, 1.0)
	style.border_color = Color(0.3, 0.26, 0.21, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	_pad(style, 8, 8, 4, 4)
	return style


static func _bar_slot(focused: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.07, 0.85)
	style.border_color = Color(GOLD, 0.72 if focused else 0.30)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	_pad(style, 8, 8, 0, 0)
	return style


static func _bar_grabber(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(GOLD, alpha)
	style.border_color = Color(INK_BRIGHT, minf(1.0, alpha + 0.12))
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	# Keeps the handle legible and comfortably draggable even on a long list.
	_pad(style, 5, 5, 11, 11)
	return style
