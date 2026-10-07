extends Node

## Photographs the dead on a real road: every one of the three states lying each
## of its eight ways, a wolf at a fresh carcass and two vultures called down to
## a heap. Diagnostic only, never a gate.
##
##   godot --path game res://tools/corpse_shot.tscn -- --save=<png>

func _ready() -> void:
	var save: String = ProjectSettings.globalize_path("user://corpse_shot.png")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save="):
			save = argument.trim_prefix("--save=")
	MetaState.hold_saves()
	RunState.reset(false, 20261007)
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 30:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	field.wave_director.stop()
	field.sky().events_enabled = false
	DayNight._apply(0.32)
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and not enemy.is_camp_mob():
			enemy.queue_free()
	var animals: Wildlife = field.wildlife()
	animals.clear()
	animals.set("_hush_left", 1.0e9)
	var spot: Vector2 = field.town_position() + Vector2(0.0, 560.0)
	field.hero.global_position = spot + Vector2(0.0, 260.0)
	# Three rows - fresh, eaten, bones - and eight ways across.
	var meats: Array[float] = [1.0, 0.45, 0.1]
	for row: int in 3:
		for way: int in 8:
			var corpse: Dictionary = field.corpses.lay(spot + Vector2(-350.0 + 100.0 * float(way), -140.0 + 90.0 * float(row)),
				spot, 30.0)
			corpse["at"] = spot + Vector2(-350.0 + 100.0 * float(way), -140.0 + 90.0 * float(row))
			corpse["vel"] = Vector2.ZERO
			corpse["vy"] = 0.0
			corpse["height"] = 0.0
			corpse["dir"] = way
			corpse["meat"] = meats[row]
	# A wolf at a fresh carcass, to the right of the grid.
	var meal: Dictionary = field.corpses.lay(spot + Vector2(560.0, -60.0), spot + Vector2(540.0, -60.0), 40.0)
	var wolf_kind := ContentDB.wildlife_kinds.get("wolf", null) as WildlifeData
	if wolf_kind != null:
		var wolf: Dictionary = animals.spawn_born(wolf_kind, spot + Vector2(520.0, -60.0),
			{"stage": WildlifeFamilies.Stage.ADULT, "rarity": 0})
		if not wolf.is_empty():
			wolf["meal"] = meal
			wolf["feeding"] = true
			wolf["state"] = Wildlife.State.SETTLED
			wolf["patience"] = 9999.0
	# Two vultures down on a heap to the left.
	var vulture_kind := ContentDB.wildlife_kinds.get("vulture", null) as WildlifeData
	for index: int in 3:
		field.corpses.lay(spot + Vector2(-600.0 + 30.0 * float(index), -40.0), spot + Vector2(-620.0, -40.0), 30.0)
	if vulture_kind != null:
		for index: int in 2:
			var bird: Dictionary = animals.spawn_born(vulture_kind, spot + Vector2(-640.0 + 70.0 * float(index), -70.0),
				{"stage": WildlifeFamilies.Stage.ADULT, "rarity": 0})
			if not bird.is_empty():
				bird["state"] = Wildlife.State.SETTLED
				bird["patience"] = 9999.0
	for _f: int in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(save)
	print("[corpse-shot] %s" % save)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)
