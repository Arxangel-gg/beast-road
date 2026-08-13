class_name PauseMenu
extends CanvasLayer

## Pause overlay. Pauses the tree, so every scope stops together and nothing
## keeps ticking behind it.

@export var panel: Control
@export var resume_button: Button
@export var menu_button: Button

var _settings: SettingsPanel
var _settings_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false

	# An arrow for "carry on" and a cross for "leave". The obvious pairing - a
	# cross on Resume, meaning "close this menu" - puts the quit symbol on the
	# button that does not quit, directly above the one that does.
	IconKit.on_button(resume_button, "pressure_arrow", 24)
	IconKit.on_button(menu_button, "close", 24)

	_build_settings()
	resume_button.pressed.connect(toggle)
	menu_button.pressed.connect(func() -> void:
		get_tree().paused = false
		GameDirector.goto_menu())


## Settings reachable from the pause screen, not only from the title.
##
## This is the case that actually matters. Without it the only route to the
## volume sliders was to abandon the run and go back to the main menu, which
## nobody does — they alt-tab and mute the game at the OS instead, which throws
## away the entire soundtrack and mix to fix one slider being too loud.
func _build_settings() -> void:
	var dim := ColorRect.new()
	dim.name = "SettingsDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.02, 0.022, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	panel.get_parent().add_child(dim)
	_settings = SettingsPanel.new()
	_settings.set_anchors_preset(Control.PRESET_CENTER)
	_settings.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_settings.grow_vertical = Control.GROW_DIRECTION_BOTH
	_settings.visible = false
	_settings.closed.connect(func() -> void: _show_settings(false))
	# On the pause layer, so it is above the paused world like the panel is.
	panel.get_parent().add_child(_settings)

	# Inserted above "Abandon the road", so the destructive option stays last.
	_settings_button = Button.new()
	_settings_button.text = "Settings"
	_settings_button.custom_minimum_size = Vector2(320.0, 48.0)
	IconKit.on_button(_settings_button, "settings", 24)
	_settings_button.pressed.connect(func() -> void: _show_settings(true))
	var box: Node = menu_button.get_parent()
	box.add_child(_settings_button)
	box.move_child(_settings_button, menu_button.get_index())


func _show_settings(showing: bool) -> void:
	_settings.visible = showing
	var dim: ColorRect = panel.get_parent().get_node_or_null("SettingsDim") as ColorRect
	if dim != null:
		dim.visible = showing
	# The pause panel steps aside rather than stacking: two panels overlapping in
	# the middle of the screen is unreadable, and the pause menu has nothing on it
	# worth seeing while the settings are open.
	panel.visible = not showing
	if not showing and _settings_button != null:
		_settings_button.grab_focus()


func toggle() -> void:
	if _settings != null and _settings.visible:
		# Escape out of settings first, rather than unpausing straight into the
		# game from a screen the player is still reading.
		_show_settings(false)
		return
	var showing: bool = not panel.visible
	panel.visible = showing
	get_tree().paused = showing
	if not showing and _settings != null:
		_settings.visible = false
