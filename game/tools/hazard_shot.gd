extends Node

## Photographs one region's harmful plants on a real road, every state on show:
## a thorn patch, a pod full and one spent, a mound hidden and one biting, a bud
## shut and one open. Diagnostic only, never a gate.
##
##   godot --path game res://tools/hazard_shot.tscn -- --act=1 --save=<png>

func _ready() -> void:
	var save: String = ProjectSettings.globalize_path("user://hazard_shot.png")
	var act: int = 1
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save="):
			save = argument.trim_prefix("--save=")
		elif argument.begins_with("--act="):
			act = int(argument.trim_prefix("--act="))
	MetaState.hold_saves()
	RunState.reset(false, 20261009)
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 30:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	field.wave_director.stop()
	field.sky().events_enabled = false
	DayNight._apply(0.36)
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and not enemy.is_camp_mob():
			enemy.queue_free()
	field.wildlife().clear()
	field.wildlife().set("_hush_left", 1.0e9)
	var spot: Vector2 = field.town_position() + Vector2(0.0, 520.0)
	field.hero.global_position = spot + Vector2(0.0, 250.0)
	# Every plant of the act and the act after it, in a row, each shown twice:
	# at rest, and in the state it strikes from.
	var shown: Array[HazardPlantData] = HazardPlants.pool_for(act) + HazardPlants.pool_for(act + 1)
	var x: float = -float(shown.size()) * 110.0
	for data: HazardPlantData in shown:
		for twice: int in 2:
			var plant: HazardPlant = field.hazards().plant_at(data, spot + Vector2(x, -60.0 + 150.0 * float(twice)))
			plant.set_process(false)
			await get_tree().process_frame
			if twice == 1:
				match data.behaviour:
					HazardPlantData.Behaviour.SPORES:
						plant.state = HazardPlant.State.HIDDEN
					HazardPlantData.Behaviour.SNAPPER, HazardPlantData.Behaviour.SPITTER:
						plant.state = HazardPlant.State.OUT
			plant.call("_wear")
		x += 220.0
	for _f: int in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(save)
	print("[hazard-shot] %s" % save)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)
