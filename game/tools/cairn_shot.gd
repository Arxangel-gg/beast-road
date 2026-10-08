extends Node

## **Photographs the Cairn** (2026-10-07): the screen over the Hold with a few
## roads remembered - two fallen, one home, one at the summit - and a
## procedural Warden as the last to fall. Saves are held; nothing is written.
##
##   tools/perf_offscreen.sh <profile> res://tools/cairn_shot.tscn
##
## Written to `user://cairn.png`.

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0)
		return
	MetaState.hold_saves()
	RunState.reset(false, 20261008)
	MetaState.run_history.clear()
	MetaState.run_records = {}
	var roads: Array = [[false, false, 3, 140, "Felled by a Mireback Alligator's bite"],
		[false, true, 5, 420, ""], [true, false, 11, 1800, ""],
		[false, false, 7, 610, "Felled by the Glass Colossus's slam"]]
	for index: int in roads.size():
		var road: Array = roads[index]
		ProceduralWarden.wear(ProceduralWarden.roll_at("cairn:%d" % index, float(index) / 4.0 + 0.1))
		MetaState.remember_run({"victory": road[0], "returned": road[1], "act": road[2],
			"wave": int(road[2]) * 38, "distance": float(int(road[2]) * 950), "kills": road[3],
			"time": float(int(road[2]) * 640), "towers_built": int(road[2]) * 4, "last_blow": road[4]})
		MetaState.run_history[0]["at"] = int(Time.get_unix_time_from_system()) - (roads.size() - index) * 86000
	var hub := HubScreen.new()
	add_child(hub)
	await get_tree().process_frame
	hub.open()
	var cairn := CairnScreen.new()
	add_child(cairn)
	await get_tree().process_frame
	cairn.open()
	for _frame: int in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("user://cairn.png"))
	print("[cairn-shot] user://cairn.png")
	MetaState.resume_saves()
	MusicPlayer.stop_immediately()
	get_tree().quit(0)
