extends Node

## Photographs the company on a real road: two hired Wardens beside the player,
## one saying a line, and the talk card open. Diagnostic only, never a gate.
##
##   godot --path game res://tools/mercenary_shot.tscn -- --save=<png>

func _ready() -> void:
	var save: String = ProjectSettings.globalize_path("user://mercenary_shot.png")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save="):
			save = argument.trim_prefix("--save=")
	MetaState.hold_saves()
	MetaState.hero_level = 36
	MetaState.marks = 50000
	MetaState.mercenaries = []
	for index: int in 2:
		MetaState.hire_mercenary(Mercenaries.offer("shot:%d" % index, ["Marrow", "Ash"][index], 36, RunState.tier()))
	for row: Dictionary in MetaState.mercenaries:
		MetaState.set_mercenary_taking(String(row["uid"]), true)
	RunState.reset(false, 20261007)
	GameDirector.run_active = true
	GameDirector._muster()
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 30:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	field.wave_director.stop()
	field.sky().events_enabled = false
	DayNight._apply(0.32)
	var spot: Vector2 = field.town_position() + Vector2(0.0, 420.0)
	field.hero.global_position = spot
	var bodies: Array[Hero] = field.company.bodies()
	for index: int in bodies.size():
		bodies[index].global_position = spot + Vector2(-110.0 + 220.0 * float(index), 50.0)
		(bodies[index].input as MercenaryInput).command(MercenaryInput.Order.GUARD)
	for _f: int in 30:
		await get_tree().process_frame
	if not bodies.is_empty():
		field.company.voice.say(bodies[0].mercenary_uid, "boss_coming", true)
		field.company.talk_to(bodies[1].mercenary_uid if bodies.size() > 1 else bodies[0].mercenary_uid)
	for _f: int in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(save)
	print("[mercenary-shot] %s" % save)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)
