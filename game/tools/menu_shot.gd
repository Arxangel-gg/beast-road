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
			# Nine reports and three passes have argued about inheritance from the
			# code. Painting the body a colour nothing else in the scene is and
			# then measuring the limb settles it in one run: if the tail comes
			# back red, the grade reaches it; if it stays grey, it does not.
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
		var beast: CanvasItem = _find_beast(menu)
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

	var tail: CanvasItem = _find_tail(menu)
	if tail == null:
		print("[menu-shot] no tail node found")
	else:
		var parent := tail.get_parent() as CanvasItem
		print(("[menu-shot] tail %s self_modulate=%s modulate=%s | body "
			+ "modulate=%s self=%s material=%s")
			% [tail.get_class(), str(tail.self_modulate), str(tail.modulate),
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
		_compare_the_paint(tail, parent)
		var material := tail.material as ShaderMaterial
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


## **A `Node2D`, not a `Sprite2D`.**
##
## **What the screen actually shows**, which is the only measurement that has
## ever settled this.
##
## Seven passes compared the two *paintings* and an eighth compared the two
## `modulate` properties, and all eight agreed the tail was fine while the owner
## was looking at a grey limb on a warm animal. A child's own `modulate` always
## reads white whatever its parent is doing to it at draw time, and source art
## says nothing about what a shader or an inherited tint did to it afterwards.
##
## This reads the frame: the mean hue, luminance and saturation of the lit pixels
## inside each node's own on-screen rectangle, and the gap between them.
func _compare_the_paint(tail: CanvasItem, body: CanvasItem) -> void:
	var frame: Image = get_viewport().get_texture().get_image()
	# **Along the limb's own chain**, not a box on its origin. A spline draws
	# away from its origin, so a square centred there is mostly sky - and sky is
	# blue, which is why two runs with and without a deliberate fault reported
	# byte-identical readings. Proven by exactly that: the measurement has to
	# move when the thing it measures does.
	var limb: Dictionary = _paint_along(frame, tail)
	var hide: Dictionary = _paint_in(frame, _screen_rect(body, frame))
	if limb.is_empty() or hide.is_empty():
		print("[menu-shot] paint: nothing lit to measure")
		return
	print("[menu-shot] paint  tail rgb(%3d,%3d,%3d) hue %5.1f sat %.3f lum %.3f"
		% [int(limb["r"]), int(limb["g"]), int(limb["b"]),
			limb["hue"], limb["sat"], limb["lum"]])
	print("[menu-shot] paint  body rgb(%3d,%3d,%3d) hue %5.1f sat %.3f lum %.3f"
		% [int(hide["r"]), int(hide["g"]), int(hide["b"]),
			hide["hue"], hide["sat"], hide["lum"]])
	var hue_gap: float = absf(fposmod(float(limb["hue"]) - float(hide["hue"]) + 180.0, 360.0) - 180.0)
	print("[menu-shot] paint  gap: hue %.1f deg, lum %+.1f%%, sat %+.3f"
		% [hue_gap,
			(float(limb["lum"]) / maxf(float(hide["lum"]), 0.0001) - 1.0) * 100.0,
			float(limb["sat"]) - float(hide["sat"])])


## The paint on the limb itself, gathered in small discs along its chain.
##
## `BeastTailSpline.chain()` is where the thing is actually drawn, so this walks
## it and samples around each link - which is paint rather than the night behind
## it, and which moves when the limb's tint moves.
func _paint_along(frame: Image, tail: CanvasItem) -> Dictionary:
	if not tail.has_method("chain"):
		return _paint_in(frame, _screen_rect(tail, frame))
	var links: PackedVector2Array = tail.call("chain") as PackedVector2Array
	if links.is_empty():
		return _paint_in(frame, _screen_rect(tail, frame))
	var to_screen: Transform2D = (tail as Node2D).get_global_transform()
	print("[menu-shot] chain %d links, first %s last %s (screen)"
		% [links.size(), str((to_screen * links[0]).round()),
			str((to_screen * links[links.size() - 1]).round())])
	var grain: Vector2 = _frame_scale(frame)
	var total := Vector3.ZERO
	var lit: int = 0
	for link: Vector2 in links:
		var at: Vector2 = (to_screen * link) * grain
		for step: int in 81:
			var dx: int = step % 9 - 4
			var dy: int = step / 9 - 4
			var x: int = int(at.x) + dx * 2
			var y: int = int(at.y) + dy * 2
			if x < 0 or y < 0 or x >= frame.get_width() or y >= frame.get_height():
				continue
			var pixel: Color = frame.get_pixel(x, y)
			if pixel.r + pixel.g + pixel.b < 0.16:
				continue
			total += Vector3(pixel.r, pixel.g, pixel.b)
			lit += 1
	if lit == 0:
		return {}
	var mean: Vector3 = total / float(lit)
	var paint := Color(mean.x, mean.y, mean.z)
	return {
		"r": mean.x * 255.0, "g": mean.y * 255.0, "b": mean.z * 255.0,
		"hue": paint.h * 360.0, "sat": paint.s, "lum": paint.v, "lit": lit,
	}


## A node's rectangle on the screen, in pixels of the captured frame.
## **The photograph is not in the game's own units, and nine reports were
## measured as though it were.**
##
## `get_viewport().get_texture().get_image()` comes back at the *window's*
## resolution, and the project draws at a content scale under it - so on this
## machine the frame is 2560x1440 while every node's global position is in a
## 1920x1080 space. Every sample this file has ever taken was therefore read
## at three quarters of the way to where it meant to look: the limb's colour
## was measured off the sky behind it, and the hide's off whatever the beast's
## bounding box happened to contain.
##
## That is the same trap `blood_shot` records - the window in pixels and the
## subject in content units - and it is why six passes could not settle a
## question that is one multiplication away from being answerable.
func _frame_scale(frame: Image) -> Vector2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return Vector2.ONE
	return Vector2(float(frame.get_width()) / view.x,
		float(frame.get_height()) / view.y)


func _screen_rect(item: CanvasItem, frame: Image) -> Rect2i:
	var grain: Vector2 = _frame_scale(frame)
	var view: Vector2 = Vector2(frame.get_width(), frame.get_height())
	var here: Vector2 = (item as Node2D).get_global_position() * grain
	var scale: Vector2 = item.get_global_transform().get_scale() * grain
	# A square around the node, sized by how big it is drawn. Generous enough to
	# hold paint and small enough not to wander onto the sky.
	var reach: float = maxf(40.0, 26.0 * maxf(scale.x, scale.y))
	return Rect2i(Vector2i(maxf(here.x - reach, 0.0), maxf(here.y - reach, 0.0)),
		Vector2i(minf(reach * 2.0, view.x), minf(reach * 2.0, view.y)))


## The mean colour of the lit pixels in a rectangle, and its hue and saturation.
##
## Near-black pixels are skipped: both subjects stand against a night sky, and
## averaging the sky in would report two very similar blacks and call it a match.
func _paint_in(frame: Image, box: Rect2i) -> Dictionary:
	var total := Vector3.ZERO
	var lit: int = 0
	for y: int in range(box.position.y, mini(box.end.y, frame.get_height())):
		for x: int in range(box.position.x, mini(box.end.x, frame.get_width())):
			var pixel: Color = frame.get_pixel(x, y)
			if pixel.r + pixel.g + pixel.b < 0.16:
				continue
			total += Vector3(pixel.r, pixel.g, pixel.b)
			lit += 1
	if lit == 0:
		return {}
	var mean: Vector3 = total / float(lit)
	var paint := Color(mean.x, mean.y, mean.z)
	return {
		"r": mean.x * 255.0, "g": mean.y * 255.0, "b": mean.z * 255.0,
		"hue": paint.h * 360.0, "sat": paint.s, "lum": paint.v, "lit": lit,
	}


## This cast to `Sprite2D` and so returned null for every run since the tail
## became `BeastTailSpline` - a spline is a `Node2D` that draws slices. The tool
## has been printing "no tail sprite found" over a tail that is plainly on
## screen, which is a diagnostic lying about the one thing it exists to report.
func _find_tail(from: Node) -> CanvasItem:
	if from.name == &"Tail":
		return from as CanvasItem
	for child: Node in from.get_children():
		var found: CanvasItem = _find_tail(child)
		if found != null:
			return found
	return null


## The body the tail hangs off: the tail's own parent, which is the one
## definition that cannot disagree with the scene.
func _find_beast(from: Node) -> CanvasItem:
	var tail: CanvasItem = _find_tail(from)
	return tail.get_parent() as CanvasItem if tail != null else null


func _find_named(from: Node, named: String) -> Node:
	for child: Node in from.get_children():
		if child.name == named:
			return child
		var deeper: Node = _find_named(child, named)
		if deeper != null:
			return deeper
	return null
