extends Node

## Photographs footprints (`Tracks`, 2026-09-30): a column of the road's own
## bodies walks past where the Warden stands, and the road behind them is
## trodden.
##
##   godot --path game res://tools/tracks_shot.tscn
##
## Diagnostic only, never a gate: `footfall_check` holds the prints' rules, and
## no number can say whether they read as footprints on the ground.

var _run: Run = null


func _ready() -> void:
	MetaState.hold_saves()
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1920, 1080)
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset(false, 20260930)
	# `--act=N` photographs a region's own ground: prints read best in snow and
	# sand, and a jungle road's cobbles hide most of them.
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--act="):
			RunState.act = clampi(int(argument.trim_prefix("--act=")), 1, Balance.ACT_COUNT)
			var region: TerrainData = ContentDB.terrain_for_act(RunState.act)
			if region != null:
				RunState.terrain_id = region.id
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 20:
		await get_tree().process_frame
	var field: Battlefield = _run.battlefield
	field.wave_director.stop()
	field.sky().events_enabled = false
	field.town.health.floor_hp = field.town.health.max_hp * 0.5
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	var fog: Node = field.get_node_or_null("FogOfWar")
	if fog != null and fog.has_method("reveal_all"):
		fog.call("reveal_all")
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	var breeds: Array[EnemyData] = []
	for id: String in terrain.enemy_ids:
		var candidate: EnemyData = ContentDB.enemy(id)
		if candidate != null and candidate.category == EnemyData.Category.BREED:
			breeds.append(candidate)
	var probe: Enemy = field.spawn_enemy(breeds[0], 0, 1.0)
	var watch: Vector2 = probe.route_point_at(0.62)
	var start_at: float = 0.42
	probe.queue_free()
	field.hero.global_position = watch
	# The Warden steps out of the world so the column walks on past rather than
	# stopping to fight; the camera stays where they stood.
	field.set_hero_away(true)
	for index: int in 9:
		var body: Enemy = field.spawn_enemy(breeds[index % breeds.size()], 0, 60.0, -1.0, 1.0)
		if body != null:
			body.global_position = body.route_point_at(start_at - float(index) * 0.012)
	var begun: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - begun < 9000:
		await get_tree().process_frame
	await _shot("road")
	var tracks: Tracks = null
	var feet: Node = field.get("_footfalls") as Node
	if feet != null and feet.has_method("tracks"):
		tracks = feet.call("tracks") as Tracks
	print("[tracks-shot] prints showing %d on %d canvases" % [
		tracks.showing() if tracks != null else -1, tracks.chunk_count() if tracks != null else -1])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	_run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	get_tree().quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "user://tracks_%s.png" % name
	image.save_png(path)
	print("[tracks-shot] %s -> %s" % [name, ProjectSettings.globalize_path(path)])
