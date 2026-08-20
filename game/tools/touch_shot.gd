extends Node

## Renders the battlefield with both thumb sticks down, so the on-screen
## controls can be looked at rather than only asserted about.
## Diagnostic only, never a gate.

func _ready() -> void:
	# `-- --touch=off` captures the same interface without the thumb controls, so
	# the desktop and mobile layouts can be compared as two pictures of one HUD
	# rather than described to each other.
	var touch: bool = true
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--touch=off":
			touch = false
	MetaState.settings[TouchInput.TOUCH_KEY] = touch
	RunState.reset()
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 14:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	TouchInput.refresh()
	for _f: int in 4:
		await get_tree().process_frame

	# Two thumbs down, pushed as a player would hold them.
	if not TouchInput.is_showing():
		get_viewport().get_texture().get_image().save_png("user://touch_shot.png")
		print("[touch] shot (no thumb controls) -> %s"
			% ProjectSettings.globalize_path("user://touch_shot.png"))
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

	get_viewport().get_texture().get_image().save_png("user://touch_shot.png")
	print("[touch] shot -> %s" % ProjectSettings.globalize_path("user://touch_shot.png"))
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
