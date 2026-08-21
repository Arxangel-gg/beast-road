extends Node

## Renders the battlefield with both thumb sticks down, so the on-screen
## controls can be looked at rather than only asserted about.
## Diagnostic only, never a gate.

func _ready() -> void:
	# `-- --touch=off` captures the same interface without the thumb controls, so
	# the desktop and mobile layouts can be compared as two pictures of one HUD
	# rather than described to each other.
	var touch: bool = true
	var output_path: String = "user://touch_shot.png"
	var viewport_size := Vector2i.ZERO
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--touch=off":
			touch = false
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--viewport="):
			var dimensions: PackedStringArray = argument.trim_prefix("--viewport=").split("x")
			if dimensions.size() == 2:
				viewport_size = Vector2i(dimensions[0].to_int(), dimensions[1].to_int())
	if viewport_size.x > 0 and viewport_size.y > 0:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = viewport_size
	MetaState.settings[TouchInput.TOUCH_KEY] = touch
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset()
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 18:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	TouchInput.refresh()
	for _f: int in 4:
		await get_tree().process_frame
	# Let the non-blocking region title finish so the shot measures the sustained
	# combat HUD rather than a deliberately temporary opening beat.
	await get_tree().create_timer(3.4).timeout

	# Two thumbs down, pushed as a player would hold them.
	if not TouchInput.is_showing():
		get_viewport().get_texture().get_image().save_png(output_path)
		print("[touch] shot (no thumb controls) -> %s"
			% ProjectSettings.globalize_path(output_path))
		Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
		get_tree().quit(0)
		return

	var left: Vector2 = TouchInput.zone(false).get_center()
	var right: Vector2 = TouchInput.zone(true).get_center()
	_press(left, 0)
	_drag(left + Vector2(-70.0, 60.0), 0)
	_press(right, 1)
	_drag(right + Vector2(90.0, -50.0), 1)
	for _f: int in 4:
		await get_tree().process_frame

	get_viewport().get_texture().get_image().save_png(output_path)
	print("[touch] shot -> %s" % ProjectSettings.globalize_path(output_path))
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)


func _press(at: Vector2, finger: int) -> void:
	var e := InputEventScreenTouch.new()
	e.position = at; e.pressed = true; e.index = finger
	TouchInput._unhandled_input(e)


func _drag(to: Vector2, finger: int) -> void:
	var e := InputEventScreenDrag.new()
	e.position = to; e.index = finger
	TouchInput._unhandled_input(e)
