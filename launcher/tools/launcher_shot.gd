extends Node

## Photographs the launcher so its look can be judged rather than asserted.
## Diagnostic only, never a gate.

func _ready() -> void:
	var packed: PackedScene = load("res://scenes/launcher.tscn") as PackedScene
	if packed == null:
		print("[launcher-shot] no launcher scene")
		get_tree().quit(1)
		return
	add_child(packed.instantiate())
	for _f: int in 90:
		await get_tree().process_frame
	var path: String = "user://launcher_shot.png"
	get_viewport().get_texture().get_image().save_png(path)
	print("[launcher-shot] %s" % ProjectSettings.globalize_path(path))
	for _f: int in 6:
		await get_tree().process_frame
	get_tree().quit(0)
