extends Node

## Photographs a row of the road's insects at play zoom: crawlers, flyers and
## swarms, held still beside the Warden. Diagnostic only, never a gate.
##
##   godot --path game res://tools/insect_shot.tscn -- --save=<png>

const SHOWN: Array[String] = ["bullet_ant", "stingfly_swarm", "sand_spider", "locust_swarm",
	"frost_tick", "snow_gnat_swarm", "rust_mantis", "amber_fireflies", "iron_hornet", "chainback_beetle"]


func _ready() -> void:
	var save: String = ProjectSettings.globalize_path("user://insect_shot.png")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save="):
			save = argument.trim_prefix("--save=")
	MetaState.hold_saves()
	RunState.reset(false, 20261010)
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
	var animals: Wildlife = field.wildlife()
	animals.clear()
	animals.set("_hush_left", 1.0e9)
	var spot: Vector2 = field.town_position() + Vector2(0.0, 520.0)
	field.hero.global_position = spot + Vector2(0.0, 230.0)
	var x: float = -float(SHOWN.size()) * 55.0
	for id: String in SHOWN:
		var kind := ContentDB.wildlife_kinds.get(id, null) as WildlifeData
		if kind != null:
			var animal: Dictionary = animals.spawn_born(kind, spot + Vector2(x, 0.0),
				{"stage": WildlifeFamilies.Stage.ADULT, "rarity": kind.rarity})
			if not animal.is_empty():
				animal["patience"] = 9999.0
				animal["state"] = Wildlife.State.SETTLED
				animal["goal"] = spot + Vector2(x, 0.0)
				animal["home"] = spot + Vector2(x, 0.0)
		x += 110.0
	for _f: int in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(save)
	print("[insect-shot] %s" % save)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)
