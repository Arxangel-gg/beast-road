extends Node

## Photographs the forged burst beside the painted one, which is the only
## judgement docs/VFX_FORGE.md §5 allows: "style match, judged by photograph
## and by nothing else".
##
##   godot --path game res://tools/forge_shot.tscn
##
## Top row: the shipped `burst.png` and its six painted frames. Second and
## third rows: the forge's sheet stepped through its cells, tinted fire and
## tinted water, additive over a dark plate as it is drawn in play. Written to
## `user://forge_shot.png`.

const SIZE := Vector2i(1400, 420)
const CELLS: Array[int] = [0, 2, 4, 6, 8, 10, 12, 14]


func _ready() -> void:
	get_window().size = SIZE
	get_viewport().set_content_scale_size(SIZE)
	MetaState.hold_saves()
	var plate := ColorRect.new()
	plate.color = Color(0.11, 0.13, 0.11)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(plate)
	var stage := Node2D.new()
	add_child(stage)
	var painted: Array[Texture2D] = GameData.load_idle_frames(Vfx.HIT_BURST_ART)
	for index: int in painted.size():
		var sprite := Sprite2D.new()
		sprite.texture = painted[index]
		sprite.position = Vector2(90.0 + float(index) * 160.0, 80.0)
		sprite.scale = Vector2.ONE * (128.0 / maxf(float(painted[index].get_width()), 1.0))
		var glow := CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = glow
		stage.add_child(sprite)
	var sheet: Texture2D = load(Vfx.FORGE_ART_FORMAT % "burst") as Texture2D
	var tints: Array[Color] = [Color(1.0, 0.55, 0.2), Color(0.45, 0.85, 1.0)]
	for row: int in tints.size():
		for index: int in CELLS.size():
			var sprite := Sprite2D.new()
			sprite.texture = sheet
			sprite.hframes = maxi(1, sheet.get_width() / maxi(sheet.get_height(), 1))
			sprite.frame = CELLS[index]
			sprite.modulate = tints[row]
			sprite.position = Vector2(90.0 + float(index) * 160.0, 210.0 + float(row) * 130.0)
			sprite.scale = Vector2.ONE * (128.0 / 96.0)
			var glow := CanvasItemMaterial.new()
			glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			sprite.material = glow
			stage.add_child(sprite)
	var tag := Label.new()
	tag.text = "painted burst (PixelLab)  ·  forged burst, fire  ·  forged burst, water"
	tag.position = Vector2(16.0, 6.0)
	tag.add_theme_font_size_override("font_size", 12)
	add_child(tag)
	for _frame: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("user://forge_shot.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("forge -> %s" % path)
	MetaState.resume_saves()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 6:
		await get_tree().process_frame
	get_tree().quit(0)
