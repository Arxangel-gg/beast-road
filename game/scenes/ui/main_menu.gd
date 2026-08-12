class_name MainMenu
extends Control

## The front door. Shows what the unlock pool has grown to, because that is the
## only thing that persists between runs (GDD §10) and it should be visible.

@export var new_run_button: Button
@export var settings_button: Button
@export var quit_button: Button
@export var stats_label: Label
@export var settings_panel: PanelContainer
@export var shake_slider: HSlider


func _ready() -> void:
	MusicPlayer.play("menu")
	new_run_button.pressed.connect(GameDirector.start_run)
	quit_button.pressed.connect(GameDirector.quit_game)
	settings_button.pressed.connect(func() -> void: settings_panel.visible = not settings_panel.visible)
	settings_panel.visible = false

	shake_slider.value = float(MetaState.settings.get("screen_shake", 1.0))
	shake_slider.value_changed.connect(func(v: float) -> void:
		MetaState.settings["screen_shake"] = v
		MetaState.save_game())

	stats_label.text = _summary()
	new_run_button.grab_focus()


func _summary() -> String:
	return "\n".join([
		"Runs   %d started   ·   %d reached the sanctuary" % [MetaState.runs_started, MetaState.runs_won],
		"Furthest   %d of %d" % [int(MetaState.best_distance), int(Balance.JOURNEY_TOTAL_DISTANCE)],
		"Unlocked   %d towers   ·   %d relics   ·   %d lands" % [
			MetaState.unlocked_towers.size(),
			MetaState.unlocked_relics.size(),
			MetaState.unlocked_terrains.size()],
	])
