extends Node

## Photographs the Warden's look, which no headless gate can see.
##
##   godot --path game res://tools/look_shot.tscn
##
## Four Wardens on a plain plate: painted, cloak dyed, sash dyed, both. The
## dye is a shader, and a shader that loads headless can still compile to
## nothing or to the wrong band on a renderer - `warden_look_check` reads the
## wiring off the source and cannot tell a dyed cloak from a dyed skull. This
## can. Written to `user://look_shot.png`; look at it before believing the gate.

const SIZE := Vector2i(1040, 300)
const LOOKS: Array = [
	["painted", [0.0, 0.0]],
	["cloak", [0.35, 0.0]],
	["sash", [0.0, 0.3]],
	["both", [-0.25, 0.5]],
]


func _ready() -> void:
	get_window().size = SIZE
	# One content unit to one pixel, for the reason `blood_shot` records: a
	# photograph at half scale is a model of the thing.
	get_viewport().set_content_scale_size(SIZE)
	RunState.reset(false, 20260921)
	MetaState.hold_saves()
	var plate := ColorRect.new()
	plate.color = Color(0.16, 0.17, 0.15)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(plate)
	var stage := Node2D.new()
	stage.scale = Vector2(1.05, 1.05)
	add_child(stage)
	var heroes: Array[Hero] = []
	for index: int in LOOKS.size():
		var hero: Hero = (load("res://scenes/hero/hero.tscn") as PackedScene).instantiate() as Hero
		# Far enough apart that four bodies do not shove each other: the first
		# cut stood them a body apart and the crowd rule stacked two of them.
		hero.position = Vector2(110.0 + float(index) * 240.0, 175.0)
		stage.add_child(hero)
		heroes.append(hero)
		var tag := Label.new()
		tag.text = String((LOOKS[index] as Array)[0])
		tag.position = Vector2(hero.position.x - 40.0, 12.0)
		tag.add_theme_font_size_override("font_size", 14)
		stage.add_child(tag)
	# The material attaches on the first drawn frame; the dye goes on after.
	for _frame: int in 4:
		await get_tree().process_frame
	for index: int in heroes.size():
		heroes[index].wear_look((LOOKS[index] as Array)[1])
	for _frame: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("user://look_shot.png")
	frame.save_png(path)
	print("look -> %s" % path)
	MetaState.resume_saves()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 6:
		await get_tree().process_frame
	get_tree().quit(0)
