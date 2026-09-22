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
var _tags: Array[Label] = []

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
		_tags.append(tag)
	# The material attaches on the first drawn frame; the dye goes on after.
	# Pinned as it settles: four bodies a quarter of a screen apart still shove
	# each other, and the first cut photographed two standing inside a third.
	for _frame: int in 4:
		for index: int in heroes.size():
			heroes[index].position = Vector2(110.0 + float(index) * 240.0, 175.0)
		await get_tree().process_frame
	for index: int in heroes.size():
		heroes[index].wear_look((LOOKS[index] as Array)[1])
	for _frame: int in 4:
		for index: int in heroes.size():
			heroes[index].position = Vector2(110.0 + float(index) * 240.0, 175.0)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	# **And the same dye under each of the four seat tints.** `look_shot` stood
	# four Wardens with no session, so `Hero._apply_party_colour` never ran and
	# the party tint has never been in a picture anyone looked at - which is how
	# the bands came to be read off a tinted colour. Seat 1 used to lose its
	# cloak band entirely; if it ever does again, this row shows it.
	for index: int in heroes.size():
		# **A packed row, not a dictionary.** `wear_look` unpacks what it is
		# given and a dictionary unpacks to the painted Warden - by design, so a
		# malformed packet draws rather than errors - so the first cut of this
		# row photographed four undyed Wardens and read as the dye being
		# destroyed by the tint, which is the fault it exists to watch for.
		heroes[index].wear_look([0.35, 0.30])
		var seat: Color = Balance.PARTY_COLOURS[index % Balance.PARTY_COLOURS.size()]
		# **Stilled first.** `_apply_party_colour` runs every frame and writes
		# `sprite.modulate` back to white when `Coop.player_count()` is one -
		# which it is here - so a tint set beside a live hero is overwritten
		# before the frame is drawn, and the first run of this row photographed
		# four untinted Wardens.
		heroes[index].set_process(false)
		heroes[index].set_physics_process(false)
		if heroes[index].sprite != null:
			heroes[index].sprite.modulate = Color.WHITE.lerp(seat,
				Balance.PARTY_TINT_STRENGTH)
		# The first row's caption taken away rather than drawn over: both
		# captures share one stage, so a label left standing says the wrong
		# thing in the second - which the first run of this row did.
		if index < _tags.size():
			_tags[index].visible = false
		var tag := Label.new()
		tag.text = "%s seat" % Balance.PARTY_COLOUR_NAMES[
			index % Balance.PARTY_COLOUR_NAMES.size()]
		tag.position = Vector2(heroes[index].position.x - 46.0, 12.0)
		tag.add_theme_font_size_override("font_size", 14)
		stage.add_child(tag)
	# Pinned every frame: four bodies a quarter of a screen apart still shove
	# each other over enough frames, and the first run of this row photographed
	# two of them standing inside a third.
	for _frame: int in 4:
		for index: int in heroes.size():
			heroes[index].position = Vector2(110.0 + float(index) * 240.0, 175.0)
		await get_tree().process_frame
	for index: int in heroes.size():
		heroes[index].position = Vector2(110.0 + float(index) * 240.0, 175.0)
	await RenderingServer.frame_post_draw
	var party: Image = get_viewport().get_texture().get_image()
	var sheet := Image.create(SIZE.x, SIZE.y * 2, false, party.get_format())
	if frame.get_format() != party.get_format():
		frame.convert(party.get_format())
	sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, SIZE), Vector2i.ZERO)
	sheet.blit_rect(party, Rect2i(Vector2i.ZERO, SIZE), Vector2i(0, SIZE.y))
	frame = sheet

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
