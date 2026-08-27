extends Node

const LeaderboardScreenScript = preload("res://scenes/ui/leaderboard_screen.gd")

## Boots the real main menu, so a scene edit cannot break the front door
## silently. The settings box used to be authored into main_menu.tscn; removing
## it in favour of the shared component is exactly the change that would leave a
## dangling NodePath and only fail on someone else's machine.

func _ready() -> void:
	var packed: PackedScene = load("res://scenes/ui/main_menu.tscn")
	var menu: Control = packed.instantiate() as Control
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	var panels: int = 0
	var boards: int = 0
	var board_buttons: int = 0
	var endless_buttons: int = 0
	for node: Node in _all(menu):
		if node is SettingsPanel:
			panels += 1
		if node.get_script() == LeaderboardScreenScript:
			boards += 1
		if node is Button and node.name == "Leaderboard":
			board_buttons += 1
		if node is Button and (node.name == "Endless" \
				or (node as Button).text.to_lower().contains("endless")):
			endless_buttons += 1
	print("[menu] instantiated ok, settings panels=%d, boards=%d, board buttons=%d, endless=%d"
		% [panels, boards, board_buttons, endless_buttons])
	if panels != 1:
		push_error("main menu should own exactly one SettingsPanel")
		get_tree().quit(1)
		return
	if boards != 1 or board_buttons != 1:
		push_error("main menu should own exactly one leaderboard screen and button")
		get_tree().quit(1)
		return
	if endless_buttons != 0:
		push_error("GDD §54 cuts Endless from 1.0; the main menu must not expose it")
		get_tree().quit(1)
		return
	# Let the instantiated menu release its nodes before shutting down. Quitting
	# on the same frame turns a healthy gate into a wall of false-positive
	# ObjectDB warnings, and a gate that cries wolf gets ignored. The menu starts
	# the title music on ready, so the audio autoloads have to be stopped too -
	# the dummy driver releases decoder playbacks asynchronously.
	if OS.get_cmdline_user_args().has("--shot"):
		# Only when asked. The gate runs headless in CI, where there is no
		# framebuffer to capture and asking for one is an error, not a picture.
		menu.call("_show_settings", true) if OS.get_cmdline_user_args().has("--settings") else null
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png("user://menu_shot.png")
		print("[menu] shot -> user://menu_shot.png")

	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	menu.queue_free()
	for _frame: int in 30:
		await get_tree().process_frame
	get_tree().quit(0)

func _all(from: Node) -> Array[Node]:
	var found: Array[Node] = [from]
	for child: Node in from.get_children():
		found.append_array(_all(child))
	return found
