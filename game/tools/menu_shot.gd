extends Node

## Photographs the main menu so the beast and its tail can be looked at.
## Diagnostic only, never a gate.
##
##   godot --path game res://tools/menu_shot.tscn -- --tag=before
##   godot --path game res://tools/menu_shot.tscn -- --tag=fat --feather=0.6
##
## The tail is a separate sprite joined to a generated body frame, and every
## fault reported about it so far - an offset root, a feather on the wrong end,
## a tip that does not match the body's colour - is invisible to every gate in
## the project and obvious in one picture.
##
## `--feather` and `--root` push the join shader's uniforms so the fade can be
## exaggerated until which end it is on is not a matter of opinion.

func _ready() -> void:
	var tag: String = "menu"
	var feather: float = -1.0
	var root: float = -1.0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--tag="):
			tag = argument.trim_prefix("--tag=")
		elif argument.begins_with("--feather="):
			feather = float(argument.trim_prefix("--feather="))
		elif argument.begins_with("--root="):
			root = float(argument.trim_prefix("--root="))
	var menu: Node = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	for _f: int in 40:
		await get_tree().process_frame
	var tail: Sprite2D = _find_tail(menu)
	if tail == null:
		print("[menu-shot] no tail sprite found")
	else:
		var material := tail.material as ShaderMaterial
		print("[menu-shot] tail pos %s offset %s size %s beast-modulate %s"
			% [str(tail.position), str(tail.offset), str(tail.texture.get_size()),
				str((tail.get_parent() as CanvasItem).modulate)])
		if material != null:
			if feather >= 0.0:
				material.set_shader_parameter("feather", feather)
			if root >= 0.0:
				material.set_shader_parameter("root_at", root)
			print("[menu-shot] feather %s root_at %s"
				% [str(material.get_shader_parameter("feather")),
					str(material.get_shader_parameter("root_at"))])
		for _f: int in 4:
			await get_tree().process_frame
	var path: String = "user://menu_shot_%s.png" % tag
	get_viewport().get_texture().get_image().save_png(path)
	print("[menu-shot] %s" % ProjectSettings.globalize_path(path))
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	get_tree().quit(0)


func _find_tail(from: Node) -> Sprite2D:
	if from.name == &"Tail":
		return from as Sprite2D
	for child: Node in from.get_children():
		var found: Sprite2D = _find_tail(child)
		if found != null:
			return found
	return null
