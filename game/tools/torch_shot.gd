extends Node

## Photographs a road of torches at midnight, on a real renderer.
## Diagnostic only, never a gate.
##
##   godot --path game res://tools/torch_shot.tscn [-- --phase=0.85]
##
## `night_check` proves the torches are worth something with a number - a lift
## of 0.018 luminance inside their pools - and the owner looked at the same road
## and saw nothing lit. Both were right. This is the picture the number was
## missing: the hero stood on the north road among its posts, the sky forced to
## the phase asked for (deep night by default - 0.85 is what night_check stages), and the frame saved.

func _ready() -> void:
	var phase: float = 0.85
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="):
			phase = clampf(float(argument.trim_prefix("--phase=")), 0.0, 1.0)
	RunState.reset()
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	if run.hud != null:
		run.hud.visible = false
	for _f: int in 12:
		await get_tree().process_frame
	var field: Battlefield = run.get("battlefield") as Battlefield
	if field == null or field.hero == null:
		push_error("[torch] no battlefield or hero")
		get_tree().quit(1)
		return
	# Partway up the north road, where the posts stand either side of it.
	field.hero.global_position = Battlefield.lane_vector(0) * 520.0
	DayNight._apply(phase)
	# `--close` (2026-09-25): the camera pulled in on one post, so the embers
	# a flame sheds onto the ink can be judged at a size a player sees them.
	var close: bool = OS.get_cmdline_user_args().has("--close")
	if close and field.camera != null:
		field.camera.set("_wanted_zoom", 2.6)
		field.camera.zoom = Vector2.ONE * 2.6
	# `--bodies` (2026-09-25): four road bodies stood among the posts, frozen,
	# so the light's direction on a body can be judged; `--flat` takes the
	# shading off every one of them for the picture to compare against.
	var bodies: bool = OS.get_cmdline_user_args().has("--bodies")
	var flat: bool = OS.get_cmdline_user_args().has("--flat")
	if bodies:
		field.wave_director.stop()
		var at: Vector2 = field.hero.global_position
		var breeds: Array[String] = ["bogkin", "ember_shaman", "canopy_stalker", "glassguard"]
		for index: int in breeds.size():
			var breed: EnemyData = ContentDB.enemy(breeds[index])
			if breed == null:
				for value: Variant in ContentDB.enemies.values():
					breed = value as EnemyData
					if breed != null and breed.category == EnemyData.Category.BREED:
						break
			var body: Enemy = field.spawn_enemy(breed, 0, 40.0)
			if body == null:
				continue
			await get_tree().process_frame
			body.global_position = at + Vector2(-190.0 + 125.0 * float(index), 90.0 + 30.0 * float(index % 2))
			body.process_mode = Node.PROCESS_MODE_DISABLED
		field.hero.process_mode = Node.PROCESS_MODE_DISABLED
	var gain: float = -1.0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--gain="):
			gain = float(argument.trim_prefix("--gain="))
	if gain >= 0.0:
		for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP) + [field.hero]:
			var sprite := node.get("sprite") as CanvasItem
			if sprite != null and sprite.material is ShaderMaterial:
				(sprite.material as ShaderMaterial).set_shader_parameter("shade_gain", gain)
				(sprite.material as ShaderMaterial).set_shader_parameter("shade_strength", 1.0)
	if flat:
		for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP) + [field.hero]:
			var sprite := node.get("sprite") as CanvasItem
			if sprite != null and sprite.material is ShaderMaterial:
				(sprite.material as ShaderMaterial).set_shader_parameter("shade_strength", 0.0)
	for _f: int in 90:
		await get_tree().process_frame
	var ink: VfxInk = VfxInk.ember_canvas
	print("[torch] embers alive on the ink: %d" % (ink.live_embers() if ink != null else -1))
	var path: String = "user://torch_shot_%02d%s%s%s.png" % [int(round(phase * 100.0)),
		"_close" if close else "", "_bodies" if bodies else "", "_flat" if flat else ("_gain" if gain >= 0.0 else "")]
	get_viewport().get_texture().get_image().save_png(path)
	print("[torch] phase %.2f darkness %.2f -> %s" % [phase, DayNight.darkness,
		ProjectSettings.globalize_path(path)])
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
