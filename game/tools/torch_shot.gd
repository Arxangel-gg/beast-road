extends Node

## Photographs a road of torches at midnight, on a real renderer.
## Diagnostic only, never a gate.
##
##   godot --path game res://tools/torch_shot.tscn [-- --phase=0.85]
##
## `night_check` proves the torches are worth something with a number - a lift
## of 0.018 luminance inside their pools - and the owner looked at the same road
## and saw nothing lit. Both were right. This is the picture the number was
## missing: the hero stood on the north road among its posts, the sky forced to
## the phase asked for (deep night by default - 0.85 is what night_check stages), and the frame saved.

func _ready() -> void:
	var phase: float = 0.85
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="):
			phase = clampf(float(argument.trim_prefix("--phase=")), 0.0, 1.0)
	RunState.reset()
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	if run.hud != null:
		run.hud.visible = false
	for _f: int in 12:
		await get_tree().process_frame
	var field: Battlefield = run.get("battlefield") as Battlefield
	if field == null or field.hero == null:
		push_error("[torch] no battlefield or hero")
		get_tree().quit(1)
		return
	# Partway up the north road, where the posts stand either side of it.
	field.hero.global_position = Battlefield.lane_vector(0) * 520.0
	DayNight._apply(phase)
	# `--close` (2026-09-25): the camera pulled in on one post, so the embers
	# a flame sheds onto the ink can be judged at a size a player sees them.
	var close: bool = OS.get_cmdline_user_args().has("--close")
	if close and field.camera != null:
		field.camera.set("_wanted_zoom", 2.6)
		field.camera.zoom = Vector2.ONE * 2.6
	for _f: int in 90:
		await get_tree().process_frame
	var ink: VfxInk = VfxInk.ember_canvas
	print("[torch] embers alive on the ink: %d" % (ink.live_embers() if ink != null else -1))
	var path: String = "user://torch_shot_%02d%s.png" % [int(round(phase * 100.0)), "_close" if close else ""]
	get_viewport().get_texture().get_image().save_png(path)
	print("[torch] phase %.2f darkness %.2f -> %s" % [phase, DayNight.darkness,
		ProjectSettings.globalize_path(path)])
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
