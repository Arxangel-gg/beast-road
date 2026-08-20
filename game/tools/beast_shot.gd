extends Node

## Renders the beast scope so the walk and the ground can be looked at.
## Diagnostic only, never a gate.

func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
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
	get_viewport().get_texture().get_image().save_png("user://beast_shot.png")
	print("[beast] shot -> %s" % ProjectSettings.globalize_path("user://beast_shot.png"))
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
