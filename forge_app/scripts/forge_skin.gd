class_name ForgeSkin
extends RefCounted

## The app's dark theme, built in code rather than authored as a `.tres`.
##
## Owner, 2026-09-22: the forge should be *"a full standalone app that can
## also be customized with an aesthetically appealing smart dark mode fully
## featured GUI"*.
##
## **In code because it has to answer questions a resource cannot.** Every
## plate here is derived from three seeds - an ink, a paper and an accent -
## so changing the app's mood is changing three colours rather than forty
## boxes, and a control added tomorrow is styled without anybody opening an
## editor. The game's own interface is themed from a `.tres`, which is right
## there because an artist maintains it; nobody is going to art-direct a
## tool, so the tool derives its own.
##
## The palette is the game's: warm gold on cold slate, which is what the
## Hold, the menu and the stash are painted in, so the tool that makes the
## game's effects does not look like it came from somewhere else.

const INK: Color = Color("e8e3d6")
const PAPER: Color = Color("14171b")
const ACCENT: Color = Color("e8a33d")
const DANGER: Color = Color("d98b6a")
const GOOD: Color = Color("8fc99a")

const RADIUS: int = 6
const PAD: int = 10


## How far a shade is from the paper: 0 is the paper, 1 is a step toward the
## ink. One function, so every plate in the app is on the same ladder and
## "one step lighter" means the same thing everywhere.
static func shade(step: float) -> Color:
	return PAPER.lerp(Color("39414c"), clampf(step, 0.0, 1.6))


static func plate(step: float, edge: Color = Color.TRANSPARENT,
		width: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = shade(step)
	box.set_corner_radius_all(RADIUS)
	box.content_margin_left = PAD
	box.content_margin_right = PAD
	box.content_margin_top = PAD - 2
	box.content_margin_bottom = PAD - 2
	if width > 0:
		box.border_color = edge
		box.set_border_width_all(width)
	return box


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15

	# Buttons: a plate that lifts under the cursor and presses in. Three
	# states from one ladder rather than three authored colours.
	theme.set_stylebox("normal", "Button", plate(0.42))
	theme.set_stylebox("hover", "Button", plate(0.62))
	theme.set_stylebox("pressed", "Button", plate(0.28))
	theme.set_stylebox("focus", "Button", plate(0.62, ACCENT, 1))
	theme.set_stylebox("disabled", "Button", plate(0.18))
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_disabled_color", "Button", shade(1.1))
	theme.set_constant("h_separation", "Button", 8)

	theme.set_stylebox("panel", "PanelContainer", plate(0.16))
	theme.set_stylebox("panel", "Panel", plate(0.16))

	for kind: String in ["LineEdit", "SpinBox"]:
		theme.set_color("font_color", kind, INK)
	theme.set_stylebox("normal", "LineEdit", plate(0.3))
	theme.set_stylebox("focus", "LineEdit", plate(0.3, ACCENT, 1))
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_color("selection_color", "LineEdit", ACCENT * Color(1, 1, 1, 0.3))

	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "RichTextLabel", INK)
	theme.set_color("default_color", "RichTextLabel", INK)
	theme.set_stylebox("normal", "RichTextLabel", plate(0.08))

	theme.set_stylebox("panel", "ItemList", plate(0.08))
	theme.set_stylebox("selected", "ItemList", plate(0.55, ACCENT, 1))
	theme.set_stylebox("selected_focus", "ItemList", plate(0.62, ACCENT, 1))
	theme.set_stylebox("hovered", "ItemList", plate(0.34))
	theme.set_color("font_color", "ItemList", INK)
	theme.set_color("font_selected_color", "ItemList", Color.WHITE)
	theme.set_constant("v_separation", "ItemList", 4)

	theme.set_stylebox("scroll", "HSlider", plate(0.24))
	theme.set_stylebox("grabber_area", "HSlider", plate(0.9))
	theme.set_stylebox("grabber_area_highlight", "HSlider", plate(1.2))

	theme.set_stylebox("panel", "TabContainer", plate(0.16))
	theme.set_stylebox("tab_selected", "TabContainer", plate(0.42))
	theme.set_stylebox("tab_unselected", "TabContainer", plate(0.14))
	theme.set_color("font_selected_color", "TabContainer", ACCENT)
	theme.set_color("font_unselected_color", "TabContainer", shade(1.2))

	theme.set_stylebox("panel", "ProgressBar", plate(0.16))
	theme.set_stylebox("fill", "ProgressBar", plate(0.9))

	theme.set_stylebox("panel", "PopupMenu", plate(0.3, ACCENT, 1))
	theme.set_color("font_color", "PopupMenu", INK)

	theme.set_color("font_color", "CheckBox", INK)
	theme.set_stylebox("normal", "CheckBox", plate(0.0))
	theme.set_stylebox("hover", "CheckBox", plate(0.22))
	theme.set_stylebox("pressed", "CheckBox", plate(0.22))
	return theme


## A heading, an ordinary line, or a quiet one. Three sizes and three
## weights of grey, so the app does not invent a fourth every screen.
static func title(text: String, size: int = 20) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", ACCENT)
	return label


static func line(text: String, size: int = 15) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	return label


static func quiet(text: String, size: int = 13) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", shade(1.3))
	return label
