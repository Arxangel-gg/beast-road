extends Node

## Photographs the cinematic half of the grade on a real road, on a real
## renderer. Diagnostic only, never a gate: headless there is no grade pass.
##
##   godot --path game res://tools/grade_shot.tscn -- --save=<png>
##
## Four frames of one place: midday with the cinematic half switched off and
## on (the shoulder and the split toning), then a marsh mist's haze, then a
## heatwave in a boss fight with a heavy blow landing - the shimmer, the
## tightened frame and the lens fringe.

func _ready() -> void:
	var save: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save="):
			save = argument.trim_prefix("--save=")
	MetaState.hold_saves()
	RunState.reset()
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	if run.hud != null:
		run.hud.visible = false
	for _f: int in 12:
		await get_tree().process_frame
	var field: Battlefield = run.get("battlefield") as Battlefield
	if field == null or field.hero == null:
		push_error("[grade] no battlefield or hero")
		get_tree().quit(1)
		return
	RunState.gain_every_currency(5000)
	for lane: int in 2:
		field.try_build(field.free_anchor_near(0, 3 + lane), ContentDB.tower("ember_spire"))
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.hero.global_position = Battlefield.lane_vector(0) * 520.0
	DayNight._apply(0.32)
	var grade: ColorGrade = _find_grade(run)
	var frames: Array[Image] = []
	for panel: int in 4:
		ColorGrade.cinematic_off = panel == 0
		RunState.weather_id = ["clear", "clear", "marsh_mist", "heatwave"][panel]
		EventBus.weather_changed.emit(RunState.weather_id)
		if panel == 3:
			RunState.phase = RunState.Phase.BOSS
		var wait: int = 200 if panel >= 2 else 60
		for _f: int in wait:
			await get_tree().process_frame
		if panel == 3:
			var camera: Camera2D = get_viewport().get_camera_2d()
			if camera != null:
				EventBus.camera_impact.emit(camera.get_screen_center_position(), 1.0)
			for _f: int in 2:
				await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = get_viewport().get_texture().get_image()
		frame.resize(frame.get_width() / 2, frame.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		frames.append(frame)
		if grade != null:
			print("[grade] panel %d haze %.3f heat %.4f boss %.2f fringe %.4f"
				% [panel, grade.haze_share(), grade.heat_share(), grade.boss_share(), grade.fringe()])
	ColorGrade.cinematic_off = false
	var width: int = frames[0].get_width()
	var height: int = frames[0].get_height()
	var sheet := Image.create(width * 2, height * 2, false, Image.FORMAT_RGBA8)
	for index: int in frames.size():
		frames[index].convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(frames[index], Rect2i(Vector2i.ZERO, Vector2i(width, height)),
			Vector2i((index % 2) * width, (index / 2) * height))
	var path: String = save if not save.is_empty() else ProjectSettings.globalize_path("user://grade_shot.png")
	sheet.save_png(path)
	print("[grade] saved %s" % path)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)


func _find_grade(from: Node) -> ColorGrade:
	for child: Node in from.get_children():
		if child is ColorGrade:
			return child as ColorGrade
		var deeper: ColorGrade = _find_grade(child)
		if deeper != null:
			return deeper
	return null
