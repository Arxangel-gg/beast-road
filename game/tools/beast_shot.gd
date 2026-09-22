extends Node

## Renders the beast scope so the walk, the ground and the tail can be looked
## at. Diagnostic only, never a gate.
##
##   godot --path game res://tools/beast_shot.tscn -- --act=2
##
## Each act has its own sky and its own ground, and only the first one is
## reachable without playing to it - so the others shipped unlooked-at twice.
## `TailProbe` reads the tail against the hide at the join off the frame, the
## same reading `menu_shot` takes, because the owner reported the tail's grade
## in both scopes and a probe in one of them measured half of the complaint.

func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	var act: int = 1
	var forced: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--act="):
			act = clampi(int(argument.trim_prefix("--act=")), 1, Balance.FINAL_ASCENT_ACT)
		elif argument.begins_with("--force-grade="):
			# **The decisive test for "does the body's grade reach the tail".**
			# Paint the body a colour nothing else in the scene is and look: if
			# the limb comes back that colour, the chain carries it and the
			# argument is about the paintings; if it does not, the chain is the
			# fault. `menu_shot` has carried the same flag since the seventh
			# report and the scope had no equivalent, which is why eleven
			# passes argued about the scope from numbers alone.
			forced = argument.trim_prefix("--force-grade=")
	RunState.act = act
	var terrain: TerrainData = ContentDB.terrain_for_act(act)
	if terrain != null:
		RunState.terrain_id = terrain.id
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
	if not forced.is_empty():
		var parts: PackedStringArray = forced.split(",")
		var painted: CanvasItem = TailProbe.find_body(run)
		# Stopped first: the scope re-grades the beast every frame from the
		# ground, so a forced colour is gone before the photograph.
		var scope: Node = run.get_node_or_null("BeastScope")
		if scope != null:
			scope.set_process(false)
			scope.set_physics_process(false)
		if painted != null and parts.size() >= 3:
			painted.modulate = Color(float(parts[0]), float(parts[1]), float(parts[2]))
			print("[beast] body forced to %s" % str(painted.modulate))
			for _f: int in 6:
				await get_tree().process_frame
	var tail: CanvasItem = TailProbe.find_tail(run)
	if tail == null:
		print("[beast] no tail node found")
	else:
		var body := tail.get_parent() as CanvasItem
		print("[beast] tail self_modulate=%s modulate=%s material=%s | body modulate=%s material=%s"
			% [str(tail.self_modulate), str(tail.modulate), str(tail.material != null),
				str(body.modulate) if body != null else "-",
				str(body.material != null) if body != null else "-"])
		print("[beast] tail on screen at %s  ·  body at %s  ·  scale %s"
			% [str(tail.get_global_transform_with_canvas().origin.round()),
				str(body.get_global_transform_with_canvas().origin.round()) if body != null else "-",
				str(tail.get_global_transform_with_canvas().get_scale())])
		TailProbe.say_the_chain(tail, "beast")
		await RenderingServer.frame_post_draw
		TailProbe.report(get_viewport(), tail, "beast")
	var path: String = "user://beast_shot_act%d.png" % act
	get_viewport().get_texture().get_image().save_png(path)
	print("[beast] act %d (%s) -> %s" % [act, RunState.terrain_id,
		ProjectSettings.globalize_path(path)])
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	for _f: int in 6:
		await get_tree().process_frame
	get_tree().quit(0)
