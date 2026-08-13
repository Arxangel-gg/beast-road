class_name SettingsPanel
extends PanelContainer

## The settings the player can actually change.
##
## Built in code, like the HUD, because it is a list generated from
## `UserSettings` rather than a hand-placed layout — adding a setting should mean
## adding it to that list, not dragging a node into two different scenes.
##
## Used from the main menu *and* from the pause menu. That second one matters
## more than it looks: before this existed, the only way to turn the music down
## mid-run was to abandon the run and go back to the title screen, which is a
## thing no one would ever do — they would alt-tab and mute the whole game
## instead, taking the sound design with it.
##
## Two details that make sliders feel like controls rather than form fields:
##
## * **The value is shown.** A bare slider tells you where the handle is, not
##   what it is set to, and "somewhere left of the middle" is not a volume.
## * **The SFX slider is audible.** You cannot set a sound level you cannot hear,
##   so releasing it plays a sample at the new level.

signal closed()

## Label, key and default for each volume row.
const VOLUME_ROWS: Array[Dictionary] = [
	{"key": "master_volume", "label": "Master", "default": 1.0},
	{"key": "music_volume", "label": "Music", "default": 0.8},
	{"key": "sfx_volume", "label": "Sound", "default": 1.0},
]

## Written to disk this long after the last change, rather than on every frame of
## a drag. Long enough to coalesce a whole slider sweep into one write.
const SAVE_DELAY: float = 0.45

var _save_left: float = 0.0
var _fullscreen_button: Button
var _windowed_button: Button


func _ready() -> void:
	_build()
	set_process(false)


func _process(delta: float) -> void:
	_save_left -= delta
	if _save_left <= 0.0:
		set_process(false)
		MetaState.save_game()


## Coalesces a burst of changes into a single write.
func _queue_save() -> void:
	_save_left = SAVE_DELAY
	set_process(true)


# --- Construction -----------------------------------------------------------

func _build() -> void:
	custom_minimum_size = Vector2(600.0, 0.0)

	# The theme's panel style has no content margin, so without this the rows sit
	# flush against the border on every side.
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 28)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	var icon: TextureRect = IconKit.rect("settings", 30.0)
	if icon != null:
		heading.add_child(icon)
	heading.add_child(_label("Settings", 26))
	column.add_child(heading)

	for row: Dictionary in VOLUME_ROWS:
		column.add_child(_volume_row(row))

	column.add_child(_separator())
	column.add_child(_shake_row())
	column.add_child(_separator())
	column.add_child(_display_row())

	var close := Button.new()
	close.text = "Back"
	close.custom_minimum_size = Vector2(0.0, 44.0)
	IconKit.on_button(close, "close", 22)
	close.pressed.connect(func() -> void:
		# Whatever is pending goes to disk now: the player is leaving, and a
		# setting that reverts because they closed the panel too quickly is worse
		# than no setting at all.
		_save_left = 0.0
		set_process(false)
		MetaState.save_game()
		closed.emit())
	column.add_child(close)


func _label(text: String, size: int = 18) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	return node


func _separator() -> Control:
	var line := HSeparator.new()
	line.add_theme_constant_override("separation", 6)
	return line


## Name on the left, slider in the middle, current value on the right.
func _slider_row(text: String, minimum: float, maximum: float, step: float,
		start: float, readout: Callable, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var name_label: Label = _label(text)
	name_label.custom_minimum_size = Vector2(120.0, 0.0)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = start
	slider.custom_minimum_size = Vector2(300.0, 28.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var value_label: Label = _label(String(readout.call(start)))
	value_label.custom_minimum_size = Vector2(64.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = String(readout.call(v))
		on_change.call(v)
		_queue_save())
	return row


func _volume_row(spec: Dictionary) -> HBoxContainer:
	var key: String = String(spec["key"])
	var row: HBoxContainer = _slider_row(String(spec["label"]), 0.0, 1.0, 0.05,
		UserSettings.number(key, float(spec["default"])),
		func(v: float) -> String: return "%d%%" % int(round(v * 100.0)),
		func(v: float) -> void: UserSettings.set_value(key, v))

	# Releasing the sound slider plays something at the new level. Setting a
	# volume you cannot hear is guesswork.
	if key == "sfx_volume":
		var slider: HSlider = row.get_child(1) as HSlider
		slider.drag_ended.connect(func(changed: bool) -> void:
			if changed:
				Sfx.play("sfx_tower_build"))
	return row


func _shake_row() -> HBoxContainer:
	return _slider_row("Screen shake", 0.0, 1.5, 0.05,
		UserSettings.number(UserSettings.SHAKE_KEY, 1.0),
		func(v: float) -> String: return "Off" if v <= 0.001 else "%d%%" % int(round(v * 100.0)),
		func(v: float) -> void: UserSettings.set_value(UserSettings.SHAKE_KEY, v))


## Two buttons rather than a slider or a dropdown: there are exactly two states,
## and which one is active should be readable without opening anything.
func _display_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var name_label: Label = _label("Display")
	name_label.custom_minimum_size = Vector2(120.0, 0.0)
	row.add_child(name_label)

	_fullscreen_button = Button.new()
	_fullscreen_button.text = "Fullscreen"
	_fullscreen_button.toggle_mode = true
	_fullscreen_button.custom_minimum_size = Vector2(150.0, 40.0)
	_fullscreen_button.pressed.connect(_choose_display.bind(UserSettings.DISPLAY_FULLSCREEN))
	row.add_child(_fullscreen_button)

	_windowed_button = Button.new()
	_windowed_button.text = "Windowed"
	_windowed_button.toggle_mode = true
	_windowed_button.custom_minimum_size = Vector2(150.0, 40.0)
	_windowed_button.pressed.connect(_choose_display.bind(UserSettings.DISPLAY_WINDOWED))
	row.add_child(_windowed_button)

	_refresh_display_buttons()
	return row


func _choose_display(mode: String) -> void:
	UserSettings.set_value(UserSettings.DISPLAY_KEY, mode)
	_refresh_display_buttons()
	# Display mode is worth writing immediately. It is the one setting a player
	# might change and then discover the game is unplayable at, and the fix for
	# that is a restart - which must not restore the broken choice's opposite.
	_save_left = 0.0
	set_process(false)
	MetaState.save_game()


func _refresh_display_buttons() -> void:
	var full: bool = UserSettings.is_fullscreen()
	_fullscreen_button.button_pressed = full
	_windowed_button.button_pressed = not full
