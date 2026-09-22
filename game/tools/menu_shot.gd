extends Node

## Photographs the main menu so the beast and its tail can be looked at.
## Diagnostic only, never a gate.
##
##   godot --path game res://tools/menu_shot.tscn -- --tag=before
##   godot --path game res://tools/menu_shot.tscn -- --tag=fat --feather=0.6
##
## The tail is a separate painting joined to a generated body frame, and every
## fault reported about it so far - an offset root, a feather on the wrong end,
## a limb that does not match the body's colour - is invisible to every gate in
## the project and obvious in one picture. `TailProbe` reads the tail against
## the hide at the join off the frame, and the same probe reads the beast scope
## in `beast_shot`, because the owner reported both.
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
	var forced: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--tag="):
			tag = argument.trim_prefix("--tag=")
		elif argument.begins_with("--wait="):
			wait = float(argument.trim_prefix("--wait="))
		elif argument.begins_with("--feather="):
			feather = float(argument.trim_prefix("--feather="))
		elif argument.begins_with("--root="):
			root = float(argument.trim_prefix("--root="))
		elif argument.begins_with("--force-grade="):
			# **The decisive test for "does the tail get the body's grade".**
			# Painting the body a colour nothing else in the scene is and then
			# measuring the limb settles it in one run: if the tail comes back
			# that colour, the grade reaches it. Three numbers, `r,g,b`.
			forced = argument.trim_prefix("--force-grade=")
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
	var camp: Node = menu.find_child("Camp", true, false)
	if camp != null:
		print("[menu-shot] camp %s" % str(camp.call("camp")))
		print("[menu-shot] camp shade=%s firelight=%s furnished=%s"
			% [str(camp.get("shade")), str(camp.get("firelight")),
				str(camp.call("furnished"))])
	var frame: Node = _find_named(menu, "MenuBorder")
	if frame == null:
		print("[menu-shot] no frame node")
	else:
		var control := frame as Control
		print("[menu-shot] frame size %s visible=%s corner=%s"
			% [str(control.size), str(control.visible),
				str(ResourceLoader.exists(MenuFrame.CORNER_ART))])
	if not forced.is_empty():
		var parts: PackedStringArray = forced.split(",")
		var beast: CanvasItem = TailProbe.find_body(menu)
		# **Stop the stage first.** It re-grades the beast every frame from the
		# sky, so a forced colour is gone before the next photograph and the probe
		# measures the ordinary grade while claiming to measure a forced one.
		var stage: Node = _find_named(menu, "Stage")
		if stage != null:
			stage.set_process(false)
			stage.set_physics_process(false)
		if beast != null and parts.size() >= 3:
			beast.modulate = Color(float(parts[0]), float(parts[1]), float(parts[2]))
			print("[menu-shot] body forced to %s" % str(beast.modulate))
			for _f: int in 4:
				await get_tree().process_frame

	var tail: CanvasItem = TailProbe.find_tail(menu)
	if tail == null:
		print("[menu-shot] no tail node found")
	else:
		var parent := tail.get_parent() as CanvasItem
		print(("[menu-shot] tail %s self_modulate=%s modulate=%s material=%s | body "
			+ "modulate=%s self=%s material=%s")
			% [tail.get_class(), str(tail.self_modulate), str(tail.modulate),
				str(tail.material != null),
				str(parent.modulate) if parent != null else "-",
				str(parent.self_modulate) if parent != null else "-",
				str(parent.material != null) if parent != null else "-"])
		# Where it is on screen, so a crop can be taken without hunting for a
		# few dozen pixels in a 2560-wide photograph.
		print("[menu-shot] tail at %s  ·  body at %s  ·  scale %s"
			% [str((tail as Node2D).get_global_position().round()),
				str((tail.get_parent() as Node2D).get_global_position().round()),
				str(tail.get_global_transform().get_scale())])
		await RenderingServer.frame_post_draw
		TailProbe.report(get_viewport(), tail, "menu-shot")
		# The join shader lives on the body: the tail is drawn whole and the
		# beast's own stub is what dissolves into it.
		var material := parent.material as ShaderMaterial if parent != null else null
		if material != null:
			if feather >= 0.0:
				material.set_shader_parameter("fade_px", feather)
			if root >= 0.0:
				material.set_shader_parameter("root_at", root)
			print("[menu-shot] fade_px %s"
				% str(material.get_shader_parameter("fade_px")))
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


func _find_named(from: Node, named: String) -> Node:
	for child: Node in from.get_children():
		if child.name == named:
			return child
		var deeper: Node = _find_named(child, named)
		if deeper != null:
			return deeper
	return null
