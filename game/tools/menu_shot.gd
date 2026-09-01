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
	var viewport_size := Vector2i.ZERO
	var touch_layout: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--touch=on":
			touch_layout = true
		elif argument.begins_with("--viewport="):
			var dimensions: PackedStringArray = argument.trim_prefix("--viewport=").split("x")
			if dimensions.size() == 2:
				viewport_size = Vector2i(dimensions[0].to_int(), dimensions[1].to_int())
	if viewport_size.x > 0 and viewport_size.y > 0:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = viewport_size
	if touch_layout:
		MetaState.settings[TouchInput.TOUCH_KEY] = true
		TouchInput.refresh()
		ScreenFit._fit()
	var menu: Control = (load("res://scenes/ui/main_menu.tscn") as PackedScene) \
		.instantiate() as Control
	add_child(menu)
	for _f: int in 12:
		await get_tree().process_frame
	await _shot("menu")

	# That the key art drifts, proven by driving `_process` rather than by
	# waiting: the cycle is ninety-two seconds long on purpose, and a tool that
	# waited for it would be a tool nobody runs.
	var stage: Control = menu.get_node_or_null("Stage") as Control
	var art: Control = stage.get_node_or_null("Backdrop") as Control if stage != null else null
	var beast: Node2D = stage.get_node_or_null("Beast") as Node2D if stage != null else null
	var art_before: Vector2 = art.position if art != null else Vector2.ZERO
	var beast_before: Vector2 = beast.position if beast != null else Vector2.ZERO
	# Sampled across a cycle rather than at one point. Checking a single step
	# reported "no change" once because the idle set is seven frames and the step
	# chosen happened to land back on the first one - a true answer to a question
	# that was not the one being asked.
	var seen: Dictionary = {}
	for _step: int in 24:
		stage.call("_process", Balance.MENU_BEAST_FRAME_TIME)
		if beast != null:
			seen[(beast as Sprite2D).texture] = true
	print("[menu] backdrop drifted %.1f px, beast %.1f px the other way, %d distinct idle frames" % [
		art_before.distance_to(art.position if art != null else Vector2.ZERO),
		beast_before.distance_to(beast.position if beast != null else Vector2.ZERO),
		seen.size()])

	# The board over the menu, which is where a player actually meets it.
	for node: Node in _all(menu):
		if node is Button and node.name == "Leaderboard":
			(node as Button).pressed.emit()
			break
	for _f: int in 12:
		await get_tree().process_frame
	await _shot("menu_leaderboard")

	# The stash over the menu, with something in it.
	#
	# Seeded rather than shown empty: the screen that needed checking is the one a
	# farming player actually sees - forty-odd rows, a filter strip and two bulk
	# actions - and an empty stash exercises none of it.
	# Closed first. The stash and the leaderboard are both on layer 64, so a
	# leaderboard left open is drawn over the screen being photographed.
	for node: Node in _all(menu):
		if node is LeaderboardScreen:
			(node as LeaderboardScreen).hide_screen()
	for _f: int in 4:
		await get_tree().process_frame
	var kinds: Array[GearData] = ContentDB.gear_sorted()
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = 90120
	MetaState.hold_saves()
	MetaState.stash = []
	for _piece: int in 26:
		MetaState.stash.append(Stash.roll(kinds, 1, seed_rng))
	MetaState.equipped = {GearData.Slot.WEAPON: 0}
	# The screen itself, not the button. The button is built without a name and
	# only when the account already has something, so matching on either is a
	# test of the menu rather than of the stash.
	for node: Node in _all(menu):
		if node is StashScreen:
			(node as StashScreen).open()
	for _f: int in 12:
		await get_tree().process_frame
	await _shot("menu_stash")
	MetaState.resume_saves()

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
