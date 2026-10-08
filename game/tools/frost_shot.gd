extends Node

## **Photographs the frost** (2026-10-07, `UiFrost`): a door screen opened over
## the Hold - the stash - and the pause menu opened over a road, so the blurred
## world behind each and the plate letting it through can be judged by eye.
## Never headless: there is no screen to blur.
##
##   tools/perf_offscreen.sh <profile> res://tools/frost_shot.tscn
##
## Written to `user://frost_hold.png` and `user://frost_pause.png`.

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[frost-shot] skipped: headless")
		get_tree().quit(0)
		return
	MetaState.hold_saves()
	RunState.reset(false, 20261007)
	var hub := HubScreen.new()
	add_child(hub)
	await get_tree().process_frame
	hub.open()
	DayNight.call("_apply", 0.3)
	var stash := StashScreen.new()
	add_child(stash)
	await get_tree().process_frame
	stash.open()
	await _settle(30)
	await _save("user://frost_hold.png")
	stash.queue_free()
	hub.queue_free()
	await _settle(4)
	GameDirector.run_active = true
	var run := (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	await _settle(40)
	if run.pause_ui != null:
		run.pause_ui.toggle()
	await _settle(30)
	await _save("user://frost_pause.png")
	if run.pause_ui != null:
		run.pause_ui.toggle()
	GameDirector.run_active = false
	MetaState.resume_saves()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().paused = false
	await _settle(4)
	get_tree().quit(0)


func _settle(frames: int) -> void:
	for _frame: int in frames:
		await get_tree().process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))
	print("[frost-shot] %s" % path)
