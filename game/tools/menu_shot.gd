extends Node

## Captures the main menu, and the leaderboard over it, so the front door can be
## looked at. Diagnostic only, never a gate.
##
##   godot --path game res://tools/menu_shot.tscn --resolution 1600x900
##
## The menu is the one screen every player sees and the only one no other shot
## tool covered: `ui_shot` captures the in-run interfaces, which all need a Run
## to exist, and the menu deliberately does not.

func _ready() -> void:
	var menu: Control = (load("res://scenes/ui/main_menu.tscn") as PackedScene) \
		.instantiate() as Control
	add_child(menu)
	for _f: int in 12:
		await get_tree().process_frame
	await _shot("menu")

	# That the key art drifts, proven by driving `_process` rather than by
	# waiting: the cycle is ninety-two seconds long on purpose, and a tool that
	# waited for it would be a tool nobody runs.
	var art: Control = menu.get_node_or_null("Art") as Control
	var before: Vector2 = art.position if art != null else Vector2.ZERO
	menu.call("_process", 23.0)
	var after: Vector2 = art.position if art != null else Vector2.ZERO
	print("[menu] key art drifted %.1f px over a quarter cycle" % before.distance_to(after))

	# The board over the menu, which is where a player actually meets it.
	for node: Node in _all(menu):
		if node is Button and node.name == "Leaderboard":
			(node as Button).pressed.emit()
			break
	for _f: int in 12:
		await get_tree().process_frame
	await _shot("menu_leaderboard")

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)


func _shot(name: String) -> void:
	var path: String = "user://%s_shot.png" % name
	get_viewport().get_texture().get_image().save_png(path)
	print("[menu] %s -> %s" % [name, ProjectSettings.globalize_path(path)])
	await get_tree().process_frame


func _all(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_all(child))
	return out
