extends Node

## The pixel grid, photographed and **measured**, which nothing has ever done.
##
##   godot --path game res://tools/pixel_shot.tscn
##   godot --path game res://tools/pixel_shot.tscn -- --scene=menu
##
## `pixel_filter_check` says of itself that "nothing here needs a frame to read",
## and that is true of every rule it holds: the order of the layers, the master
## switch narrowing the second, the slider clamped on the way out, a muted font
## colour. **None of those is the picture.** The owner reported on 2026-09-17
## that the grid "is not working like it used to" and that "changing the grid
## size for the pixelshader doesn't do anything currently" - with that gate
## green, because a headless run has no frame for a screen-reading shader to
## read and no pixels for anybody to count.
##
## So this counts them. For each block size it stands the real scene up, turns
## the grid on, photographs it, and measures **the block actually on screen** by
## the length of the runs of identical colour along a row. A working grid at
## block 8 reads about 8; a grid that is off reads about 1; a slider that does
## nothing reads the same number at every setting.
##
## It also reads back where the type sits, because the owner's second report is
## that turning the interface grid on "causes the text to get misaligned and out
## of position from where the texts used to be". A label's rect is a number, so
## the drift is measurable rather than a matter of opinion: the same labels are
## measured with the interface grid off and on and any that moved are named.
##
## **Never headless.** There is no frame to copy, so the shader has nothing to
## read and this would photograph a black rectangle and report a working grid as
## broken.

const SIZE := Vector2i(1280, 720)

## The settings the plates are taken at. 1 is the floor, which is "no grid".
const BLOCKS: Array[int] = [1, 3, 8]

var _scene: Node = null
var _which: String = "menu"


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[pixel-shot] skipped: a headless display has no pixels to read")
		get_tree().quit(0)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			_which = argument.trim_prefix("--scene=")
	get_window().size = SIZE
	get_viewport().set_content_scale_size(SIZE)

	var path: String = "res://scenes/ui/main_menu.tscn"
	_scene = (load(path) as PackedScene).instantiate()
	add_child(_scene)
	for _settle: int in 50:
		await get_tree().process_frame

	# **The off plate first**, because "is the grid doing anything" is answered
	# by the difference between two pictures rather than by either one of them.
	Graphics.set_display(Graphics.KEY_PIXEL_FILTER, false)
	Graphics.set_display(Graphics.KEY_PIXEL_FILTER_UI, false)
	var off: Image = await _plate("off")

	Graphics.set_display(Graphics.KEY_PIXEL_FILTER, true)
	for block: int in BLOCKS:
		Graphics.set_display(Graphics.KEY_PIXEL_FILTER_BLOCK, float(block))
		var shot: Image = await _plate("block%d" % block)
		_say_the_uniforms(block)
		# **Parenthesised.** `%` binds tighter than `+`, so without these the
		# format applies to the last fragment alone.
		print(("[pixel-shot] block %d asked -> %.1f measured, %.1f%% of the "
			+ "frame differs from the unfiltered plate")
			% [block, _measured_block(shot), _difference(off, shot) * 100.0])

	# And the interface grid, which is the switch that moves the type.
	Graphics.set_display(Graphics.KEY_PIXEL_FILTER_BLOCK, 4.0)
	Graphics.set_display(Graphics.KEY_PIXEL_FILTER_UI, false)
	await _settle_frames()
	var before: Dictionary = _type_rects()
	await _plate("ui_off")
	Graphics.set_display(Graphics.KEY_PIXEL_FILTER_UI, true)
	await _settle_frames()
	var after: Dictionary = _type_rects()
	await _plate("ui_on")
	_report_drift(before, after)
	get_tree().quit(0)


## What the material was actually told, and whether the rect that wears it is
## on screen. **The picture said the grid does nothing; this says which half.**
func _say_the_uniforms(asked: int) -> void:
	var grid: Node = _scene.find_child("PixelGridWorld", true, false)
	if grid == null:
		print("[pixel-shot] no PixelGridWorld on the menu")
		return
	var rect := grid.get_node_or_null("Screen") as ColorRect
	var copy := grid.get_node_or_null("Copy") as BackBufferCopy
	if rect == null:
		print("[pixel-shot] the grid has no Screen rect")
		return
	var mat := rect.material as ShaderMaterial
	var band := grid as Control
	var owner_control := band.get_parent() as Control
	print(("[pixel-shot]   band rect=%s anchors=%s..%s offsets=%s..%s | parent=%s "
		+ "%s size=%s")
		% [str(band.get_global_rect()),
			str(Vector2(band.anchor_left, band.anchor_top)),
			str(Vector2(band.anchor_right, band.anchor_bottom)),
			str(Vector2(band.offset_left, band.offset_top)),
			str(Vector2(band.offset_right, band.offset_bottom)),
			band.get_parent().get_class(), band.get_parent().name,
			str(owner_control.size) if owner_control != null else "(not a Control)"])
	print(("[pixel-shot]   asked %d | rect visible=%s global=%s | copy=%s | "
		+ "grid=%s viewport=%s strength=%s | shader=%s")
		% [asked, str(rect.visible), str(rect.get_global_rect()),
			str(copy.copy_mode) if copy != null else "-",
			str(mat.get_shader_parameter("grid")) if mat != null else "-",
			str(mat.get_shader_parameter("viewport")) if mat != null else "-",
			str(mat.get_shader_parameter("strength")) if mat != null else "-",
			str(mat.shader.resource_path) if mat != null and mat.shader != null else "-"])


func _settle_frames() -> void:
	for _settle: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _plate(what: String) -> Image:
	await _settle_frames()
	var frame: Image = get_viewport().get_texture().get_image()
	var path: String = "user://pixel_shot_%s.png" % what
	frame.save_png(ProjectSettings.globalize_path(path))
	print("[pixel-shot] %s -> %s" % [what, ProjectSettings.globalize_path(path)])
	return frame


## How wide a run of one colour is, averaged over the busiest rows.
##
## **The busiest rows, not all of them.** A menu is mostly flat sky and a flat
## region is one enormous run whatever the grid is doing, so averaging over the
## whole frame measures the sky. Rows are ranked by how many colour changes they
## carry and the top tenth is measured, which is where the painted art is.
func _measured_block(frame: Image) -> float:
	var wide: int = frame.get_width()
	var tall: int = frame.get_height()
	var rows: Array[Vector2i] = []
	for y: int in range(0, tall, 4):
		var changes: int = 0
		var last: Color = frame.get_pixel(0, y)
		for x: int in range(1, wide):
			var here: Color = frame.get_pixel(x, y)
			if not _same(here, last):
				changes += 1
				last = here
		rows.append(Vector2i(changes, y))
	rows.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x > b.x)
	var busiest: int = maxi(1, rows.size() / 10)
	var runs: int = 0
	var pixels: int = 0
	for index: int in busiest:
		var y: int = rows[index].y
		var last: Color = frame.get_pixel(0, y)
		for x: int in range(1, wide):
			var here: Color = frame.get_pixel(x, y)
			pixels += 1
			if not _same(here, last):
				runs += 1
				last = here
	return float(pixels) / float(maxi(runs, 1))


## Two colours the eye would call the same. A grid quantises position, not
## colour, so two neighbouring blocks are usually plainly different - but a
## gradient sampled twice can land a hair apart and count as a change.
func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.012


## What share of the frame the filter changed.
func _difference(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return 1.0
	var moved: int = 0
	var seen: int = 0
	for y: int in range(0, a.get_height(), 3):
		for x: int in range(0, a.get_width(), 3):
			seen += 1
			if not _same(a.get_pixel(x, y), b.get_pixel(x, y)):
				moved += 1
	return float(moved) / float(maxi(seen, 1))


## Where every label on screen is, by path.
func _type_rects() -> Dictionary:
	var out: Dictionary = {}
	_walk_type(_scene, out)
	return out


func _walk_type(from: Node, into: Dictionary) -> void:
	if from == null:
		return
	var label := from as Label
	if label != null and label.visible and not label.text.is_empty():
		into[String(label.get_path())] = label.get_global_rect()
	var rich := from as RichTextLabel
	if rich != null and rich.visible:
		into[String(rich.get_path())] = rich.get_global_rect()
	var button := from as Button
	if button != null and button.visible and not button.text.is_empty():
		into[String(button.get_path())] = button.get_global_rect()
	for child: Node in from.get_children():
		_walk_type(child, into)


func _report_drift(before: Dictionary, after: Dictionary) -> void:
	var moved: int = 0
	var gone: int = 0
	for path: Variant in before:
		if not after.has(path):
			gone += 1
			continue
		var was: Rect2 = before[path] as Rect2
		var now: Rect2 = after[path] as Rect2
		if was.position.distance_to(now.position) > 0.5 \
				or was.size.distance_to(now.size) > 0.5:
			moved += 1
			print("[pixel-shot] MOVED %s: %s -> %s"
				% [str(path).get_file(), str(was), str(now)])
	print(("[pixel-shot] type: %d of %d pieces moved when the interface grid "
		+ "came on, %d disappeared") % [moved, before.size(), gone])
