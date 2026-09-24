extends Node

## Photographs the bloom on a real road, on a real renderer. Diagnostic only,
## never a gate: headless there is no grade pass and no screen to read.
##
##   godot --path game res://tools/bloom_shot.tscn -- --save=<png>
##
## Four frames of one place, side by side: midnight without the bloom and with
## it, then midday without and with. What the bloom must do is visible in the
## first pair - torches, a tower's fire and its pool bleeding into the dark - and
## what it must *not* do is visible in the second: a sunlit field that does not
## haze.

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
		push_error("[bloom] no battlefield or hero")
		get_tree().quit(1)
		return
	RunState.gain_every_currency(5000)
	for lane: int in 2:
		field.try_build(field.free_anchor_near(0, 3 + lane), ContentDB.tower("ember_spire"))
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.hero.global_position = Battlefield.lane_vector(0) * 520.0
	var frames: Array[Image] = []
	for phase: float in [0.85, 0.28]:
		for on: bool in [false, true]:
			Graphics.set_display(Graphics.KEY_BLOOM, on)
			DayNight._apply(phase)
			for _f: int in 60:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var frame: Image = get_viewport().get_texture().get_image()
			frame.resize(frame.get_width() / 2, frame.get_height() / 2, Image.INTERPOLATE_BILINEAR)
			frames.append(frame)
			print("[bloom] phase %.2f bloom %s darkness %.2f" % [phase, on, DayNight.darkness])
	var width: int = frames[0].get_width()
	var height: int = frames[0].get_height()
	var sheet := Image.create(width * 2, height * 2, false, Image.FORMAT_RGBA8)
	for index: int in frames.size():
		frames[index].convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(frames[index], Rect2i(Vector2i.ZERO, Vector2i(width, height)),
			Vector2i((index % 2) * width, (index / 2) * height))
	var path: String = save if not save.is_empty() else ProjectSettings.globalize_path("user://bloom_shot.png")
	sheet.save_png(path)
	print("[bloom] saved %s" % path)
	Graphics.set_display(Graphics.KEY_BLOOM, true)
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
