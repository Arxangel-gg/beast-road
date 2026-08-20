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

## Video tab widgets, kept so a preset change can push the individual switches
## back into agreement with it.
var _quality_switches: Array[Dictionary] = []
var _preset_buttons: Dictionary = {}
var _fps_buttons: Dictionary = {}
var _colourblind_buttons: Dictionary = {}
var _colourblind_swatches: Array[ColorRect] = []

## Which action the player is currently pressing a key for, or empty.
var _listening_for: StringName = &""
var _listening_button: Button = null

## The erase control is a two-press confirmation; this is how long the second
## press stays available before the button disarms itself.
const ERASE_CONFIRM_SECONDS: float = 4.0
const ERASE_LABEL: String = "Erase saved data"
var _erase_button: Button = null
var _erase_note: Label = null
var _erase_confirm_left: float = 0.0
var _tutorial_toggle: Button = null
var _binding_buttons: Dictionary = {}
var _binding_note: Label = null


func _ready() -> void:
	_build()
	set_process(false)


func _process(delta: float) -> void:
	_tick_erase(delta)
	if _save_left > 0.0:
		_save_left -= delta
		if _save_left <= 0.0:
			_write()
	# Two timers share this frame now, so it stops only when neither wants it.
	# Disarming the erase confirmation is exactly as time-based as the coalesced
	# save, and the first version of this cancelled itself on the next frame.
	if _save_left <= 0.0 and _erase_confirm_left <= 0.0:
		set_process(false)


## Graphics, colourblind and key choices live in their own classes and have to be
## copied into the save before it is written.
func _write() -> void:
	UserSettings.store_presentation()
	MetaState.save_game()


## Coalesces a burst of changes into a single write.
func _queue_save() -> void:
	_save_left = SAVE_DELAY
	set_process(true)


# --- Construction -----------------------------------------------------------

func _build() -> void:
	custom_minimum_size = Vector2(600.0, 0.0)
	# This panel lives in its own full-screen CanvasLayer, but only the centre card
	# should intercept input. Clicking the dimmed world around it must not leak to
	# the paused battlefield or leave HUD controls appearing interactive.
	mouse_filter = Control.MOUSE_FILTER_STOP

	# A little breathing room on top of what the panel frame already reserves.
	# The theme used to provide none at all, which put the rows flush against the
	# border; it now pads generously, so this only adds the difference.
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
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

	# Tabs, once there were three groups. Audio, video and fifteen rebindable keys
	# in one column is a screen nobody scrolls to the bottom of, and the settings
	# players most need - the graphics ones, when the game is running badly - would
	# be the furthest down.
	var tabs := TabContainer.new()
	# Tall enough for the full Video accessibility preview at 1080p; the Video
	# page still scrolls on shorter displays instead of clipping its controls.
	tabs.custom_minimum_size = Vector2(0.0, 700.0)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)

	var audio := VBoxContainer.new()
	audio.name = "Audio"
	audio.add_theme_constant_override("separation", 14)
	for row: Dictionary in VOLUME_ROWS:
		audio.add_child(_volume_row(row))
	audio.add_child(_separator())
	audio.add_child(_shake_row())
	audio.add_child(_gait_row())
	tabs.add_child(audio)

	var video_scroll := ScrollContainer.new()
	video_scroll.name = "Video"
	video_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var video := VBoxContainer.new()
	video.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	video.add_theme_constant_override("separation", 6)
	_build_video(video)
	video_scroll.add_child(video)
	tabs.add_child(video_scroll)

	var controls := VBoxContainer.new()
	controls.name = "Controls"
	controls.add_theme_constant_override("separation", 14)
	_build_controls(controls)
	tabs.add_child(controls)

	var data := VBoxContainer.new()
	data.name = "Data"
	data.add_theme_constant_override("separation", 14)
	_build_data(data)
	tabs.add_child(data)

	_refresh_video()
	_refresh_fps_buttons()
	_refresh_colourblind_buttons()

	# GDD SS46: the version belongs in Settings. Small, quiet, and selectable by
	# eye - it is the first thing to ask for in a bug report and the last thing a
	# player can find without it.
	var build: Label = _label(BuildInfo.diagnostics(), 13)
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build.add_theme_color_override("font_color", Color(0.55, 0.59, 0.57, 0.75))
	build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(build)

	var close := Button.new()
	close.text = "Back"
	close.custom_minimum_size = Vector2(0.0, 54.0)
	IconKit.on_button(close, "close", 22)
	close.pressed.connect(func() -> void:
		# Whatever is pending goes to disk now: the player is leaving, and a
		# setting that reverts because they closed the panel too quickly is worse
		# than no setting at all.
		_save_left = 0.0
		set_process(false)
		_write()
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


func _gait_row() -> HBoxContainer:
	return _slider_row("Beast motion", 0.0, 1.25, 0.05,
		UserSettings.number(UserSettings.GAIT_KEY, 0.65),
		func(v: float) -> String: return "Off" if v <= 0.001 else "%d%%" % int(round(v * 100.0)),
		func(v: float) -> void: UserSettings.set_value(UserSettings.GAIT_KEY, v))


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
	_fullscreen_button.custom_minimum_size = Vector2(196.0, 46.0)
	_fullscreen_button.pressed.connect(_choose_display.bind(UserSettings.DISPLAY_FULLSCREEN))
	row.add_child(_fullscreen_button)

	_windowed_button = Button.new()
	_windowed_button.text = "Windowed"
	_windowed_button.toggle_mode = true
	_windowed_button.custom_minimum_size = Vector2(196.0, 46.0)
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
	_write()


func _refresh_display_buttons() -> void:
	var full: bool = UserSettings.is_fullscreen()
	_fullscreen_button.button_pressed = full
	_windowed_button.button_pressed = not full


# --- Video -------------------------------------------------------------------

## Quality, framerate, display mode and colourblind support.
##
## The preset is offered first and the individual switches below it, because most
## players want one decision ("this is running badly, turn it down") and only some
## want six. Touching any switch moves the preset to Custom rather than silently
## disagreeing with the label above it.
func _build_video(column: VBoxContainer) -> void:
	column.add_child(_label("Quality", 20))
	column.add_child(_preset_row())

	_quality_switches = []
	column.add_child(_toggle_row("Torch shadows", Graphics.KEY_CAST_SHADOWS,
		"The most expensive thing on screen. Turn this off first."))
	column.add_child(_toggle_row("Ground shadows", Graphics.KEY_CONTACT_SHADOWS,
		"Cheaper, and worth more to how the game looks."))
	column.add_child(_toggle_row("Cloud shadows", Graphics.KEY_CLOUDS, ""))
	column.add_child(_amount_row("Particles", Graphics.KEY_PARTICLES))
	column.add_child(_amount_row("Foliage", Graphics.KEY_FOLIAGE))

	column.add_child(_separator())
	column.add_child(_brightness_row())
	column.add_child(_fps_row())
	column.add_child(_display_row())
	column.add_child(_separator())
	column.add_child(_colourblind_row())
	column.add_child(_colourblind_preview())


func _preset_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_label: Label = _label("Preset")
	name_label.custom_minimum_size = Vector2(140.0, 0.0)
	row.add_child(name_label)

	_preset_buttons = {}
	for entry: Array in [
			[Graphics.PRESET_LOW, "Low"],
			[Graphics.PRESET_MEDIUM, "Medium"],
			[Graphics.PRESET_HIGH, "High"],
			[Graphics.PRESET_ULTRA, "Ultra"]]:
		var id: String = entry[0]
		var button := Button.new()
		button.text = entry[1]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(96.0, 40.0)
		button.pressed.connect(func() -> void:
			Graphics.apply_preset(id)
			_refresh_video()
			_queue_save())
		_preset_buttons[id] = button
		row.add_child(button)
	return row


## An on/off switch that also explains itself, because "cast shadows" means
## nothing to somebody who just wants the game to stop stuttering.
func _toggle_row(text: String, key: String, hint: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var name_label: Label = _label(text)
	name_label.custom_minimum_size = Vector2(140.0, 0.0)
	row.add_child(name_label)

	var button := Button.new()
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(118.0, 38.0)
	button.tooltip_text = hint
	name_label.tooltip_text = hint
	button.pressed.connect(func() -> void:
		Graphics.set_switch(key, button.button_pressed)
		_refresh_video()
		_queue_save())
	row.add_child(button)
	box.add_child(row)

	_quality_switches.append({"key": key, "button": button, "kind": "toggle"})
	return box


## A 0..1 density, shown as a percentage.
func _amount_row(text: String, key: String) -> HBoxContainer:
	# Ultra deliberately exceeds the High baseline. A 0..1 slider silently
	# clamped the live 1.75/1.45 values and made Ultra look identical to High.
	var row: HBoxContainer = _slider_row(text, 0.0, Graphics.MAX_DENSITY, 0.05, 1.0,
		func(v: float) -> String: return "Off" if v <= 0.001 else "%d%%" % int(round(v * 100.0)),
		func(v: float) -> void:
			Graphics.set_switch(key, v)
			_refresh_preset_buttons())
	_quality_switches.append({
		"key": key,
		"slider": row.get_child(1) as HSlider,
		"value": row.get_child(2) as Label,
		"kind": "amount",
	})
	return row


## Brightness, for screens darker than the one the night was graded on.
##
## Sits with the display settings rather than the quality ones, and does not
## knock the preset to Custom: it is about the player's screen, not about what
## their machine can afford.
func _brightness_row() -> HBoxContainer:
	return _slider_row("Brightness", 0.0, Graphics.BRIGHTNESS_MAX_LIFT, 0.05,
		Graphics.brightness_lift(),
		func(v: float) -> String:
			return "Graded" if v <= 0.001 else "+%d%%" % int(round(
				v / Graphics.BRIGHTNESS_MAX_LIFT * 100.0)),
		func(v: float) -> void: Graphics.set_display(Graphics.KEY_BRIGHTNESS, v))


func _fps_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_label: Label = _label("Frame cap")
	name_label.custom_minimum_size = Vector2(140.0, 0.0)
	row.add_child(name_label)

	_fps_buttons = {}
	for value: int in Graphics.FPS_CHOICES:
		var button := Button.new()
		button.text = Graphics.fps_label(value)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(84.0, 38.0)
		button.pressed.connect(func() -> void:
			Graphics.set_fps_cap(value)
			_refresh_fps_buttons()
			_queue_save())
		_fps_buttons[value] = button
		row.add_child(button)
	return row


func _colourblind_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label: Label = _label("Colourblind")
	name_label.custom_minimum_size = Vector2(140.0, 0.0)
	row.add_child(name_label)
	_colourblind_buttons = {}
	for entry: Dictionary in Palette.MODES:
		var id: String = String(entry["id"])
		var button := Button.new()
		button.text = String(entry["label"])
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0.0, 34.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			Palette.set_mode(id)
			_refresh_colourblind_buttons()
			_refresh_colourblind_preview()
			_queue_save())
		_colourblind_buttons[id] = button
		row.add_child(button)
	return row


## A live, labelled preview makes the option self-evident before the panel is
## closed. Shape/name remain the primary cue; colour is the redundant channel.
func _colourblind_preview() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var inset := Control.new()
	inset.custom_minimum_size = Vector2(140.0, 0.0)
	row.add_child(inset)
	_colourblind_swatches.clear()
	var names: Array[String] = ["FIRE", "WATER", "EARTH", "AIR"]
	for element: int in names.size():
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(0.0, 28.0)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fill := ColorRect.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(fill)
		var label: Label = _label(names[element], 10)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("101417"))
		chip.add_child(label)
		row.add_child(chip)
		_colourblind_swatches.append(fill)
	_refresh_colourblind_preview()
	return row


func _refresh_colourblind_preview() -> void:
	for element: int in _colourblind_swatches.size():
		_colourblind_swatches[element].color = Palette.element(element)


func _refresh_video() -> void:
	_refresh_preset_buttons()
	for entry: Dictionary in _quality_switches:
		var key: String = String(entry["key"])
		if String(entry["kind"]) == "toggle":
			var on: bool = Graphics.cast_shadows() if key == Graphics.KEY_CAST_SHADOWS \
				else (Graphics.contact_shadows() if key == Graphics.KEY_CONTACT_SHADOWS \
				else Graphics.cloud_shadows())
			var toggle: Button = entry["button"]
			toggle.button_pressed = on
			toggle.text = "On" if on else "Off"
		else:
			var amount: float = Graphics.particle_scale() if key == Graphics.KEY_PARTICLES \
				else Graphics.foliage_scale()
			(entry["slider"] as HSlider).set_value_no_signal(amount)
			(entry["value"] as Label).text = "%d%%" % int(round(amount * 100.0))


func _refresh_preset_buttons() -> void:
	var current: String = Graphics.preset()
	for id: Variant in _preset_buttons:
		(_preset_buttons[id] as Button).button_pressed = String(id) == current


func _refresh_fps_buttons() -> void:
	var current: int = Graphics.fps_cap()
	for value: Variant in _fps_buttons:
		(_fps_buttons[value] as Button).button_pressed = int(value) == current


func _refresh_colourblind_buttons() -> void:
	var current: String = Palette.mode()
	for id: Variant in _colourblind_buttons:
		(_colourblind_buttons[id] as Button).button_pressed = String(id) == current
	_refresh_colourblind_preview()


# --- Controls ----------------------------------------------------------------

## Fifteen rebindable actions, and a reset.
##
## Scrolled, unlike everything else in this panel: fifteen rows is genuinely a
## list, and the alternative is a settings window taller than a 1080p screen.
## Erasing the account.
##
## A roguelite's unlock pool is most of what a returning player is playing
## against, so wanting the first run back is a reasonable thing to want, and
## before this there was no way to ask for it short of deleting a file by hand.
##
## Two presses, not a modal. A confirmation dialog for a destructive action is
## the correct instinct, but a button that changes into its own confirmation and
## changes back after a few seconds cannot be dismissed by reflex the way a
## dialog can, and it cannot be clicked through by somebody who is not reading.
func _build_data(column: VBoxContainer) -> void:
	column.add_child(_label("Tutorial", 22))
	var coach_note: Label = _label(
		"Short prompts that explain the game as you meet each part of it. They "
		+ "turn themselves off once you have seen them all.", 14)
	coach_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coach_note.add_theme_color_override("font_color", Color(0.62, 0.66, 0.64, 0.85))
	column.add_child(coach_note)

	# A toggle rather than a "show it again" button. The prompts switch
	# themselves off after a first run, so the only honest control is one that
	# reports the current state and can be moved either way.
	_tutorial_toggle = Button.new()
	_tutorial_toggle.toggle_mode = true
	_tutorial_toggle.custom_minimum_size = Vector2(0.0, 54.0)
	_tutorial_toggle.button_pressed = not bool(
		MetaState.settings.get(TutorialCoach.SETTING_KEY, false))
	_refresh_tutorial_toggle()
	_tutorial_toggle.toggled.connect(func(on: bool) -> void:
		MetaState.settings[TutorialCoach.SETTING_KEY] = not on
		MetaState.save_game()
		_refresh_tutorial_toggle())
	column.add_child(_tutorial_toggle)

	column.add_child(_separator())
	column.add_child(_label("Saved data", 22))
	var note: Label = _label(
		"Unlocked towers, relics, spells, terrain and buildings, your run "
		+ "statistics, and any Treasury carry-over. Settings and key bindings are kept.", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.62, 0.66, 0.64, 0.85))
	column.add_child(note)

	_erase_button = Button.new()
	_erase_button.text = ERASE_LABEL
	_erase_button.custom_minimum_size = Vector2(0.0, 54.0)
	_erase_button.add_theme_color_override("font_color", Color(0.92, 0.53, 0.45))
	IconKit.on_button(_erase_button, "close", 22)
	_erase_button.pressed.connect(_on_erase_pressed)
	column.add_child(_erase_button)

	_erase_note = _label("", 14)
	_erase_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_erase_note.add_theme_color_override("font_color", Color(0.92, 0.53, 0.45))
	column.add_child(_erase_note)


## The toggle says what it currently is, not what pressing it would do. A
## control labelled with its own action leaves the player guessing which state
## they are in, which is the one thing a settings screen must never do.
func _refresh_tutorial_toggle() -> void:
	if _tutorial_toggle == null:
		return
	var on: bool = _tutorial_toggle.button_pressed
	_tutorial_toggle.text = "Tutorial prompts: on" if on else "Tutorial prompts: off"
	IconKit.on_button(_tutorial_toggle, "upgrade" if on else "close", 22)


func _on_erase_pressed() -> void:
	if _erase_confirm_left <= 0.0:
		_erase_confirm_left = ERASE_CONFIRM_SECONDS
		_erase_button.text = "Press again to erase everything"
		_erase_note.text = "This cannot be undone."
		set_process(true)
		return
	_erase_confirm_left = 0.0
	MetaState.erase_progress()
	_erase_button.text = ERASE_LABEL
	_erase_note.text = "Saved data erased. The next run starts from the beginning."


## Lets the confirmation lapse, so a stray first click does not sit armed.
func _tick_erase(delta: float) -> void:
	if _erase_confirm_left <= 0.0:
		return
	_erase_confirm_left -= delta
	if _erase_confirm_left <= 0.0:
		_erase_button.text = ERASE_LABEL
		_erase_note.text = ""


func _build_controls(column: VBoxContainer) -> void:
	_binding_note = _label("Click a key, then press the one you want. Escape cancels.", 14)
	_binding_note.add_theme_color_override("font_color", Color(0.62, 0.66, 0.64, 0.85))
	_binding_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_binding_note)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	_binding_buttons = {}
	for entry: Dictionary in KeyBindings.REBINDABLE:
		list.add_child(_binding_row(entry))

	var reset := Button.new()
	reset.text = "Reset all keys"
	reset.custom_minimum_size = Vector2(0.0, 44.0)
	IconKit.on_button(reset, "close", 22)
	reset.pressed.connect(func() -> void:
		KeyBindings.reset_all()
		_refresh_bindings()
		_queue_save())
	column.add_child(reset)


func _binding_row(entry: Dictionary) -> HBoxContainer:
	var action: StringName = entry["action"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var name_label: Label = _label(String(entry["label"]))
	name_label.custom_minimum_size = Vector2(180.0, 0.0)
	row.add_child(name_label)

	var button := Button.new()
	button.text = KeyBindings.label_for(action)
	button.custom_minimum_size = Vector2(190.0, 40.0)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(func() -> void: _listen_for(action, button))
	row.add_child(button)

	_binding_buttons[String(action)] = button
	return row


## Puts the panel into capture mode for one action.
func _listen_for(action: StringName, button: Button) -> void:
	if _listening_for != &"":
		_stop_listening()
	_listening_for = action
	_listening_button = button
	button.text = "Press a key…"
	# Godot delivers the click that started this as an input event too, so the
	# panel would immediately capture the mouse button that opened it. Waiting a
	# frame lets that event drain first.
	set_process_input(false)
	await get_tree().process_frame
	if _listening_for == action:
		set_process_input(true)


func _input(event: InputEvent) -> void:
	if _listening_for == &"":
		return

	# Escape cancels rather than binds. It is also the only way out of a capture a
	# player opened by accident, which is why KeyBindings refuses to bind it.
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		_stop_listening()
		_refresh_bindings()
		get_viewport().set_input_as_handled()
		return

	if not KeyBindings.is_bindable(event):
		return

	var clashes: Array[String] = KeyBindings.conflicts(event, _listening_for)
	KeyBindings.rebind(_listening_for, event)
	if not clashes.is_empty():
		# Bound anyway, and said so. Refusing the bind would leave the player
		# guessing which of fifteen rows was in the way.
		_report_conflict(KeyBindings.describe(event), clashes)
	_stop_listening()
	_refresh_bindings()
	_queue_save()
	get_viewport().set_input_as_handled()


func _stop_listening() -> void:
	_listening_for = &""
	_listening_button = null
	set_process_input(false)


func _report_conflict(key_name: String, clashes: Array[String]) -> void:
	if _binding_note == null:
		return
	_binding_note.text = "%s was already %s." % [key_name, ", ".join(clashes)]
	_binding_note.add_theme_color_override("font_color", Color("e8a33d"))


func _refresh_bindings() -> void:
	for action_name: Variant in _binding_buttons:
		(_binding_buttons[action_name] as Button).text = \
			KeyBindings.label_for(StringName(action_name))
