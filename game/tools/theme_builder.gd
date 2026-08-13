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

# --- Palette -----------------------------------------------------------------
# Kept identical to the previous hand-authored theme: the art changes, the
# reading colours do not.

const INK: Color = Color(0.85098, 0.80392, 0.72157)
const INK_BRIGHT: Color = Color(0.96863, 0.91765, 0.82353)
const INK_DIM: Color = Color(0.52, 0.5, 0.45, 0.55)
const GOLD: Color = Color(0.90980, 0.63922, 0.23922)
const OUTLINE: Color = Color(0.02, 0.04, 0.05, 0.9)


static func build() -> Dictionary:
	var theme := Theme.new()
	theme.default_font_size = 18

	var problems: PackedStringArray = []

	# --- Buttons -------------------------------------------------------------
	#
	# Pressed reuses the hover frame darkened rather than getting art of its own:
	# the lit inner edge is what says "this one", and dimming it reads as the
	# button taking the weight of the click.
	# Vertical margins are deliberately under the art's own 20px border. The
	# top and bottom of this frame are a uniform iron bar with no features along
	# their length, so letting a few pixels of it stretch is invisible - whereas
	# reserving the full 20 on a 54px button leaves 14px of middle and the frame
	# swallows the button. The corner bolts are the part that must not stretch,
	# and those are held by the horizontal margins.
	var normal: StyleBox = _frame("ui_button", 34, 34, 15, 16, problems)
	var hover: StyleBox = _frame("ui_button_hover", 34, 34, 15, 16, problems)
	var pressed: StyleBox = _frame("ui_button_hover", 34, 34, 15, 16, problems,
		Color(0.72, 0.66, 0.56))
	var disabled: StyleBox = _frame("ui_button", 34, 34, 15, 16, problems,
		Color(0.55, 0.55, 0.55, 0.7))

	# Left padding clears the corner bolt rather than merely clearing the frame,
	# or the first glyph of a label sits on top of a rivet.
	for style: StyleBox in [normal, hover, pressed, disabled]:
		_pad(style, 34, 26, 10, 12)

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	# Focus stays a drawn outline. The art has no focus state, and tinting the
	# hover frame for it would make a keyboard-focused button indistinguishable
	# from the one under the mouse.
	theme.set_stylebox("focus", "Button", _focus_ring())

	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK_BRIGHT)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", INK_DIM)
	theme.set_color("font_outline_color", "Button", OUTLINE)
	theme.set_constant("outline_size", "Button", 4)
	theme.set_font_size("font_size", "Button", 17)

	# --- Panels --------------------------------------------------------------
	var panel: StyleBox = _frame("ui_panel", 40, 40, 40, 40, problems)
	_pad(panel, 26, 26, 22, 22)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)

	# The plain frame for things that float over the game and must not compete
	# with it: tooltips and popups.
	var dark: StyleBox = _frame("ui_panel_dark", 22, 22, 22, 22, problems)
	_pad(dark, 14, 14, 10, 10)
	theme.set_stylebox("panel", "PopupPanel", dark)
	theme.set_stylebox("panel", "TooltipPanel", dark)
	theme.set_color("font_color", "TooltipLabel", INK)

	# A panel *inside* a panel must not repeat the ornate frame - riveted iron
	# nested in riveted iron reads as a rendering mistake. The stat preview in the
	# build panel is the case that needs this.
	theme.set_type_variation("InnerPanel", "PanelContainer")
	var inner: StyleBox = _frame("ui_panel_dark", 22, 22, 22, 22, problems)
	_pad(inner, 14, 14, 10, 10)
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

	# --- Scrollbars ----------------------------------------------------------
	#
	# Still defined even though the build panel no longer scrolls. Something
	# somewhere will scroll eventually, and an unstyled scrollbar is the fastest
	# way to make a themed screen look unfinished.
	theme.set_stylebox("scroll", "VScrollBar", _bar_slot())
	theme.set_stylebox("grabber", "VScrollBar", _bar_grabber(0.55))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _bar_grabber(0.85))

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


static func _bar_slot() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.07, 0.85)
	style.set_corner_radius_all(3)
	return style


static func _bar_grabber(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(GOLD, alpha)
	style.set_corner_radius_all(3)
	return style
