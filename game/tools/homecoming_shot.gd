extends Node

## Photographs the pass behind the party - the road-home offer after an act's
## boss - and the "Home again" debrief a return leads to. Diagnostic only,
## never a gate.
##
##   godot --path game res://tools/homecoming_shot.tscn [-- <act>]


func _ready() -> void:
	var act: int = 4
	for arg: String in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			act = int(arg)
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset(false, 20260914)
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 16:
		await get_tree().process_frame
	run.ask_homecoming = true
	RunState.act = act
	EventBus.boss_defeated.emit("probe", act)
	for _f: int in 30:
		await get_tree().process_frame
	_shoot("pass")
	var ui: CrossroadScreen = run.crossroad_ui
	if ui._buttons.has("home"):
		(ui._buttons["home"] as Button).pressed.emit()
	for _f: int in 40:
		await get_tree().process_frame
	_shoot("home")
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	MetaState.resume_saves()
	get_tree().quit(0)


func _shoot(what: String) -> void:
	var path: String = "user://homecoming_shot_%s.png" % what
	get_viewport().get_texture().get_image().save_png(path)
	print("[homecoming] %s -> %s" % [what, ProjectSettings.globalize_path(path)])
