extends Node

## Photographs a Herald on the road (2026-09-30): the gold it wears beside an
## ordinary body of the same breed, the arrow at the screen's edge pointing at a
## second one out of view, and the line the HUD says when one rises.
##
##   godot --path game res://tools/herald_shot.tscn
##
## Diagnostic only, never a gate: `herald_check` holds every rule a Herald has,
## and no number can say whether the gold reads across a field.

var _run: Run = null


func _ready() -> void:
	MetaState.hold_saves()
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1920, 1080)
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset(false, 20260930)
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
	var breed: EnemyData = null
	for id: String in terrain.enemy_ids:
		var candidate: EnemyData = ContentDB.enemy(id)
		if candidate != null and not candidate.targets_towers:
			breed = candidate
			break
	var hero: Hero = field.hero
	# Out on a road, well clear of the wall, so neither body is in reach of the
	# town and the Herald is photographed before its call.
	var probe: Enemy = field.spawn_enemy(breed, 0, 1.0)
	var here: Vector2 = probe.route_point_at(0.55)
	probe.queue_free()
	hero.global_position = here + Vector2(0.0, 260.0)
	# After the road's own opening card, which takes the banner's line back.
	var settle: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - settle < 3000:
		await get_tree().process_frame
	var plain: Enemy = field.spawn_enemy(breed, 0, 60.0, -1.0, 0.001)
	plain.global_position = here + Vector2(-150.0, -60.0)
	var herald: Enemy = field.spawn_enemy(breed, 0, 60.0, -1.0, 0.001)
	herald.global_position = here + Vector2(150.0, -60.0)
	herald.make_herald()
	# A second, off the screen, for the arrow.
	var far: Enemy = field.spawn_enemy(breed, 0, 60.0, -1.0, 0.001)
	far.global_position = here + Vector2(2600.0, 900.0)
	far.make_herald()
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 800:
		await get_tree().process_frame
	var banner := _run.hud.get("_message") as Label
	print("[herald-shot] banner '%s' visible=%s rect=%s" % [banner.text, str(banner.is_visible_in_tree()), str(banner.get_global_rect())])
	await _shot("field")
	print("[herald-shot] plain at %s, herald at %s" % [str(plain.global_position), str(herald.global_position)])
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
	var path: String = "user://herald_%s.png" % name
	image.save_png(path)
	print("[herald-shot] %s -> %s" % [name, ProjectSettings.globalize_path(path)])
