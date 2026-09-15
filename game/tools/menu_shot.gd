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
	# **How long to let the scene run before photographing it.** The menu has
	# things on it now that are not there on the first frame - a bird crosses
	# every few seconds and a firefly is dark most of the time - so a shot at
	# forty frames is a photograph of an empty sky and says nothing about
	# either. `--wait=12` is enough for both.
	var wait: float = 0.0
	var feather: float = -1.0
	var root: float = -1.0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--tag="):
			tag = argument.trim_prefix("--tag=")
		elif argument.begins_with("--wait="):
			wait = float(argument.trim_prefix("--wait="))
		elif argument.begins_with("--feather="):
			feather = float(argument.trim_prefix("--feather="))
		elif argument.begins_with("--root="):
			root = float(argument.trim_prefix("--root="))
	var menu: Node = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	for _f: int in 40:
		await get_tree().process_frame
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	var flock: Node = menu.find_child("Birds", true, false)
	if flock == null:
		print("[menu-shot] no Birds node")
	else:
		print("[menu-shot] birds flying=%d widest=%0.1f visible=%s modulate=%s"
			% [int(flock.call("flying")), float(flock.call("widest")),
				str((flock as CanvasItem).visible), str((flock as CanvasItem).modulate)])
		print("[menu-shot] birds at %s" % str(flock.call("perches")))
		print("[menu-shot] birds winged=%s global=%s"
			% [str(flock.call("winged")), str((flock as Node2D).global_position)])
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
