extends Node

## Photographs the road settling after a held wave (2026-09-30, `Settling`):
## the haze and the embers over the stretch where bodies fell, at play zoom.
##
##   godot --path game res://tools/settling_shot.tscn
##
## Windowed, because a headless display has no pixels. Diagnostic only:
## `feel_check` holds what the settling does.

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[settling-shot] skipped: a headless display has no pixels to read")
		get_tree().quit(0)
		return
	MetaState.hold_saves()
	RunState.reset(false, 20260930)
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 30:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	field.wave_director.stop()
	# The title card fades first; the spot is open road beside the town.
	var faded: float = 0.0
	while faded < 5.0:
		await get_tree().process_frame
		faded += get_process_delta_time()
	var spot: Vector2 = field.hero.global_position + Vector2(380.0, -120.0)
	for index: int in 8:
		field.settling()._on_enemy_died("bogkin", spot + Vector2(randf_range(-40.0, 40.0), randf_range(-30.0, 30.0)))
	field.settling()._on_wave_cleared(1)
	for second: int in 3:
		var waited: float = 0.0
		while waited < 0.9:
			await get_tree().process_frame
			waited += get_process_delta_time()
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = "user://settling_%d.png" % second
		image.save_png(path)
		print("[settling-shot] -> ", ProjectSettings.globalize_path(path))
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 10:
		await get_tree().process_frame
	GameDirector.run_active = false
	MetaState.resume_saves()
	get_tree().quit(0)
