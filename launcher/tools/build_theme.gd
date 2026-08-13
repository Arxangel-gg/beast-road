extends SceneTree

## Builds `res://launcher_theme.tres` from the same frame art the game uses.
##
##   godot --headless --path launcher --script res://tools/build_theme.gd
##
## The launcher looked like a Godot demo while the game it installs looks like a
## grim-fantasy game. That is a poor first impression from the one program every
## player runs before they have seen anything else, and it is nearly free to fix:
## the nine-patch art already exists and the launcher uses five widget types.
##
## Deliberately a copy of the game's numbers rather than an import of them. The
## launcher is a separate Godot project with no access to the game's scripts, and
## sharing the file would mean one project reaching into the other's source tree.

const ART: String = "res://art/"
const OUTPUT: String = "res://launcher_theme.tres"

const INK: Color = Color(0.85098, 0.80392, 0.72157)
const INK_BRIGHT: Color = Color(0.96863, 0.91765, 0.82353)
const INK_DIM: Color = Color(0.52, 0.5, 0.45, 0.55)
const GOLD: Color = Color(0.90980, 0.63922, 0.23922)


func _init() -> void:
	var theme := Theme.new()
	theme.default_font_size = 20

	var normal: StyleBox = _frame("ui_button", 34, 34, 15, 16)
	var hover: StyleBox = _frame("ui_button_hover", 34, 34, 15, 16)
	var pressed: StyleBox = _frame("ui_button_hover", 34, 34, 15, 16, Color(0.72, 0.66, 0.56))
	var disabled: StyleBox = _frame("ui_button", 34, 34, 15, 16, Color(0.55, 0.55, 0.55, 0.7))
	for style: StyleBox in [normal, hover, pressed, disabled]:
		_pad(style, 34, 34, 14, 14)

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", _focus_ring())
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK_BRIGHT)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", INK_DIM)
	theme.set_color("font_outline_color", "Button", Color(0.02, 0.04, 0.05, 0.9))
	theme.set_constant("outline_size", "Button", 4)

	var panel: StyleBox = _frame("ui_panel", 40, 40, 40, 40)
	_pad(panel, 38, 38, 32, 32)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)

	# The plain frame, for things that sit inside the ornate one. Riveted iron
	# nested in riveted iron reads as a rendering mistake.
	var dark: StyleBox = _frame("ui_panel_dark", 22, 22, 22, 22)
	_pad(dark, 22, 22, 18, 18)
	theme.set_type_variation("InnerPanel", "PanelContainer")
	theme.set_stylebox("panel", "InnerPanel", dark)

	theme.set_stylebox("background", "ProgressBar", _frame("ui_bar_back", 0, 0, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", _frame("ui_bar_fill", 0, 0, 0, 0))

	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_outline_color", "Label", Color(0.02, 0.04, 0.05, 0.85))
	theme.set_constant("outline_size", "Label", 5)
	theme.set_color("default_color", "RichTextLabel", INK)

	var status: int = ResourceSaver.save(theme, OUTPUT)
	print("Launcher theme written to %s (%d)." % [OUTPUT, status])
	quit(0 if status == OK else 1)


func _frame(id: String, left: int, right: int, top: int, bottom: int,
		tint: Color = Color.WHITE) -> StyleBox:
	var path: String = "%s%s.png" % [ART, id]
	if not ResourceLoader.exists(path):
		push_error("missing %s" % path)
		return StyleBoxFlat.new()
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	style.texture_margin_left = float(left)
	style.texture_margin_right = float(right)
	style.texture_margin_top = float(top)
	style.texture_margin_bottom = float(bottom)
	style.modulate_color = tint
	return style


func _pad(style: StyleBox, left: int, right: int, top: int, bottom: int) -> void:
	style.content_margin_left = float(left)
	style.content_margin_right = float(right)
	style.content_margin_top = float(top)
	style.content_margin_bottom = float(bottom)


func _focus_ring() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(GOLD, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style
