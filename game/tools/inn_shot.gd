extends Node

## Photographs the Inn: one mercenary on its feet, one in a bed owing its bill,
## and two strangers in the yard to hire. Diagnostic only, never a gate.
##
##   godot --path game res://tools/inn_shot.tscn -- --save=<png>

func _ready() -> void:
	var save: String = ProjectSettings.globalize_path("user://inn_shot.png")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save="):
			save = argument.trim_prefix("--save=")
	MetaState.hold_saves()
	MetaState.hero_level = 42
	MetaState.marks = 6000
	MetaState.mercenaries = []
	MetaState.hire_mercenary(Mercenaries.offer("shot:1", "Marrow", 42, RunState.tier()))
	MetaState.hire_mercenary(Mercenaries.offer("shot:2", "Ash", 42, RunState.tier()))
	MetaState.set_mercenary_taking(String(MetaState.mercenaries[0]["uid"]), true)
	MetaState.send_mercenary_to_bed(String(MetaState.mercenaries[1]["uid"]))
	var inn := InnScreen.new()
	inn.strangers = func() -> Array:
		return [{"who": "shot:3", "name": "Rue"}, {"who": "shot:4", "name": "Fen"}]
	add_child(inn)
	await get_tree().process_frame
	inn.open()
	for _f: int in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(save)
	print("[inn-shot] %s" % save)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	get_tree().quit(0)
