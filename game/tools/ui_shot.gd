extends Node

## Captures each full-screen interface so they can be compared side by side.
## Diagnostic only, never a gate.

func _ready() -> void:
	MetaState.settings["tutorial_seen"] = true
	RunState.reset()
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame

	await _shot("crossroad", func() -> void: run.crossroad_ui.open(1))
	await _shot("town", func() -> void: run.town_panel.open("forge"))
	await _shot("pause", func() -> void: run.pause_ui.toggle())
	await _shot("results", func() -> void: run.results_ui.show_results(false, {
		"seed": 123456789, "act": 2, "kills": 214, "distance": 1400.0,
		"towers_built": 11, "resources_earned": 900,
	}))

	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	run.queue_free()
	for _f: int in 20: await get_tree().process_frame
	get_tree().quit(0)


func _shot(name: String, open: Callable) -> void:
	open.call()
	get_tree().paused = false
	for _f: int in 10:
		await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("user://ui_%s.png" % name)
	print("[ui] %s" % name)
