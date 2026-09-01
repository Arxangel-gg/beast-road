extends Node

## Captures each full-screen interface so they can be compared side by side.
## Diagnostic only, never a gate.
##
##   godot --path game res://tools/ui_shot.tscn -- --viewport=1280x591 --touch=on
##
## The viewport argument matters more than it looks. Four layout faults were
## reported from a phone and none of them existed at 1920x1080: what breaks a
## panel is a screen shorter than the panel was drawn for, and the only way to
## see that here is to open a window that shape.

func _ready() -> void:
	var viewport_size := Vector2i.ZERO
	var touch_layout: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--touch=on":
			touch_layout = true
		elif argument.begins_with("--viewport="):
			var dimensions: PackedStringArray = argument.trim_prefix("--viewport=").split("x")
			if dimensions.size() == 2:
				viewport_size = Vector2i(dimensions[0].to_int(), dimensions[1].to_int())
	if viewport_size.x > 0 and viewport_size.y > 0:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = viewport_size
	if touch_layout:
		MetaState.settings[TouchInput.TOUCH_KEY] = true
		TouchInput.refresh()
		ScreenFit._fit()

	MetaState.settings["tutorial_seen"] = true
	RunState.reset()
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	if touch_layout:
		TouchInput.refresh()
		for _f: int in 4:
			await get_tree().process_frame

	await _shot("town", func() -> void: run.town_panel.open("forge"))
	for page: int in 3:
		var which: int = page
		await _shot("mansion_%d" % which, func() -> void:
			run.town_panel.open("sanctum")
			run.town_panel.set("_mansion_page", which)
			run.town_panel.call("_refresh"))
	run.town_panel.close()
	await _shot("pause", func() -> void: run.pause_ui.toggle())
	run.pause_ui.set_showing(false)
	get_tree().paused = false
	await _shot("crossroad", func() -> void: run.crossroad_ui.open(1))
	run.crossroad_ui.visible = false
	await _shot("results", func() -> void:
		run.hud.show_end_report()
		run.results_ui.show_results(false, {
			"seed": 123456789, "act": 2, "kills": 214, "distance": 1400.0,
			"towers_built": 11, "resources_earned": 900,
		}))
	run.results_ui.visible = false
	await _shot("ending", func() -> void: run.ending_ui.play())

	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	run.queue_free()
	for _f: int in 20: await get_tree().process_frame
	get_tree().quit(0)


func _shot(name: String, open: Callable) -> void:
	open.call()
	get_tree().paused = false
	for _f: int in 90:
		await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("user://ui_%s.png" % name)
	print("[ui] %s -> %s" % [name,
		ProjectSettings.globalize_path("user://ui_%s.png" % name)])
