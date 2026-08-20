extends Node

## Renders the beast scope so the walk and the ground can be looked at.
## Diagnostic only, never a gate.
##
##   godot --path game res://tools/beast_shot.tscn -- --act=2
##
## Each act has its own sky and its own ground tileset, and only the first one is
## reachable without playing to it - so the other two shipped unlooked-at twice.

const TERRAINS: Array[String] = ["jungle", "desert", "snow"]

func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	var act: int = 1
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--act="):
			act = clampi(int(argument.trim_prefix("--act=")), 1, TERRAINS.size())
	RunState.act = act
	RunState.terrain_id = TERRAINS[act - 1]
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 8:
		await get_tree().process_frame
	# Walking, not resting: the scope idles during Preparation on purpose, and a
	# shot of the idle would not show the gait or the frames.
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	RunState.distance_travelled = 640.0
	run.switch_scope(GameDirector.Scope.BEAST)
	if run.hud != null:
		run.hud.visible = false
	for _f: int in 20:
		await get_tree().process_frame
	var path: String = "user://beast_shot_act%d.png" % act
	get_viewport().get_texture().get_image().save_png(path)
	print("[beast] act %d (%s) -> %s" % [act, RunState.terrain_id,
		ProjectSettings.globalize_path(path)])
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
