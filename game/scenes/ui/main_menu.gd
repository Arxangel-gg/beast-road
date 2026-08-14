class_name MainMenu
extends Control

## The front door. Shows what the unlock pool has grown to, because that is the
## only thing that persists between runs (GDD §10) and it should be visible.

@export var new_run_button: Button
@export var settings_button: Button
@export var quit_button: Button
@export var stats_label: Label
@export var seed_input: LineEdit

var _settings: SettingsPanel


func _ready() -> void:
	MusicPlayer.play("menu")
	new_run_button.pressed.connect(_start_run)
	quit_button.pressed.connect(GameDirector.quit_game)
	seed_input.text_submitted.connect(func(_value: String) -> void: _start_run())

	# All three carry an icon, which also left-aligns them. Without one on the
	# first button its label stayed centred while the two below it were not, and a
	# menu column with one odd row out reads as a mistake before it reads as a
	# menu. The arrow means the same here as on the pause screen: carry on.
	IconKit.on_button(new_run_button, "pressure_arrow", 26)
	IconKit.on_button(settings_button, "settings", 24)
	IconKit.on_button(quit_button, "close", 24)

	_build_settings()
	settings_button.pressed.connect(func() -> void: _show_settings(true))

	stats_label.text = _summary()
	new_run_button.grab_focus()


func _start_run() -> void:
	var requested: int = 0
	var entered: String = seed_input.text.strip_edges()
	if not entered.is_empty():
		if not entered.is_valid_int() or int(entered) <= 0:
			seed_input.text = ""
			seed_input.placeholder_text = "Use 1–999999999"
			seed_input.grab_focus()
			return
		requested = clampi(int(entered), 1, RunState.RNG_MAX_SEED)
	GameDirector.start_run(requested)


## The panel is the shared component, centred over the key art. The menu used to
## hand-roll its own settings box in the scene file, which is how it ended up
## offering exactly one setting while three volume sliders sat unreachable in the
## save file.
func _build_settings() -> void:
	_settings = SettingsPanel.new()
	_settings.set_anchors_preset(Control.PRESET_CENTER)
	_settings.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_settings.grow_vertical = Control.GROW_DIRECTION_BOTH
	_settings.visible = false
	_settings.closed.connect(func() -> void: _show_settings(false))
	add_child(_settings)


func _show_settings(showing: bool) -> void:
	_settings.visible = showing
	if not showing:
		settings_button.grab_focus()


func _summary() -> String:
	return "\n".join([
		"Runs   %d started   ·   %d reached the sanctuary" % [MetaState.runs_started, MetaState.runs_won],
		"Furthest   %d of %d" % [int(MetaState.best_distance), int(Balance.JOURNEY_TOTAL_DISTANCE)],
		"Unlocked   %d towers   ·   %d relics   ·   %d lands" % [
			MetaState.unlocked_towers.size(),
			MetaState.unlocked_relics.size(),
			MetaState.unlocked_terrains.size()],
	])
