extends Node

## Renders the battlefield road to a PNG so the autotiling can be looked at.
## Diagnostic only, never a gate.

func _ready() -> void:
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset()
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	# `-- <terrain_id>` re-skins the field before the shot, so one tool proves the
	# whole regional pipeline: the ground swap, the per-region road set, and the
	# fallback for a region that has no set of its own.
	var terrain_id: String = ""
	var output_path: String = "user://road_shot.png"
	var viewport_size := Vector2i.ZERO
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--viewport="):
			var dimensions: PackedStringArray = argument.trim_prefix("--viewport=").split("x")
			if dimensions.size() == 2:
				viewport_size = Vector2i(dimensions[0].to_int(), dimensions[1].to_int())
		elif ContentDB.terrain(argument) != null:
			terrain_id = argument
	if viewport_size.x > 0 and viewport_size.y > 0:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = viewport_size
	if not terrain_id.is_empty():
		RunState.terrain_id = terrain_id
		run.battlefield.refresh_terrain()
		for _f: int in 4:
			await get_tree().process_frame

	var cam := run.battlefield.camera as Camera2D
	if cam != null:
		cam.zoom = Vector2(0.21, 0.21)
		cam.global_position = Vector2.ZERO
	if run.hud != null:
		run.hud.visible = false
	for _f: int in 8:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(output_path)
	print("[road] shot -> %s" % ProjectSettings.globalize_path(output_path))
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	run.queue_free()
	for _f: int in 20: await get_tree().process_frame
	get_tree().quit(0)
