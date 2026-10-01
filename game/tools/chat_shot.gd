extends Node

## Photographs the chat (2026-10-01): the log as it reads in a fight, and the
## box open over its history. Diagnostic only, never a gate.
##
##   godot --path game res://tools/chat_shot.tscn
##
## Writes `user://chat_closed.png` and `user://chat_open.png`.


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset()
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 20:
		await get_tree().process_frame
	run.battlefield.wave_director.stop()
	RunState.run_time_seconds = 754.0
	var lines: Array = [
		[1, "east gate is thin, I'll take it"],
		[2, "/me plants a banner on the bridge"],
		[1, "/roll 57 100"],
		[3, "boss in 400, save the horn"],
		[2, "a [bracket] stays a bracket"],
	]
	for line: Array in lines:
		EventBus.coop_chat.emit(int(line[0]), String(line[1]))
	EventBus.party_notice.emit(2, "Blue built a Glacial Mortar")
	for _f: int in 6:
		await get_tree().process_frame
	await _save("chat_closed")
	run.hud.open_chat()
	(run.hud.get("_chat_box") as LineEdit).text = "on my way"
	for _f: int in 6:
		await get_tree().process_frame
	await _save("chat_open")
	MetaState.resume_saves()
	get_tree().quit()


func _save(name_text: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("user://%s.png" % name_text)
	print("[chat-shot] wrote user://%s.png" % name_text)
