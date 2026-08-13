extends Node

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
	for node: Node in _all(menu):
		if node is SettingsPanel:
			panels += 1
	print("[menu] instantiated ok, settings panels=%d" % panels)
	if panels != 1:
		push_error("main menu should own exactly one SettingsPanel")
		get_tree().quit(1)
		return
	# Let the instantiated menu release its nodes before shutting down. Quitting
	# on the same frame turns a healthy gate into a wall of false-positive
	# ObjectDB warnings, and a gate that cries wolf gets ignored. The menu starts
	# the title music on ready, so the audio autoloads have to be stopped too -
	# the dummy driver releases decoder playbacks asynchronously.
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
