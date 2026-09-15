extends Node

## A contact sheet of one species wearing eight different coats.
##
##   godot --path game res://tools/phenotype_shot.tscn
##
## **The one thing `phenotype_check` cannot do.** That gate holds everything
## about a coat that is not the picture - that it is stable, that it varies,
## that it stays inside its ceilings, that the shader reads every uniform. It
## cannot say whether a dappled deer looks like a deer, and no gate can: a
## headless renderer compiles no shader at all.
##
## So this draws eight of the same animal side by side with consecutive serials,
## on a flat plate, at play scale, and writes it to `build/shots/`. Read it for
## two things: that no two are the same, and that all eight are still obviously
## the same species. A sheet where one of them reads as a different animal means
## the species' spread is too wide, whatever the ceilings say.

const OUT: String = "user://phenotype.png"
const ACROSS: int = 8


func _ready() -> void:
	MetaState.hold_saves()
	await get_tree().process_frame
	var which: String = "deer"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		which = args[0]
	var kind := ContentDB.wildlife_kinds.get(which) as WildlifeData
	if kind == null:
		push_error("[phenotype-shot] no such animal: %s" % which)
		get_tree().quit(1)
		return
	var art: Texture2D = load(kind.get_sprite_path()) as Texture2D
	if art == null:
		push_error("[phenotype-shot] %s has no painting" % which)
		get_tree().quit(1)
		return

	var plate := ColorRect.new()
	plate.color = Color(0.10, 0.11, 0.12)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(plate)
	var wide: float = float(get_viewport().size.x) / float(ACROSS)
	for index: int in ACROSS:
		var sprite := Sprite2D.new()
		sprite.texture = art
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(wide * (float(index) + 0.5),
			float(get_viewport().size.y) * 0.5)
		sprite.scale = Vector2.ONE * minf(wide / float(art.get_width()), 3.0)
		add_child(sprite)
		# The real door, so the sheet is a photograph of what the field does
		# rather than of what this tool thinks the field does.
		Phenotype.dress(ActorPolish.attach(sprite), kind, index + 1)

	# Two frames: one to build, one to draw what was built.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var shot: Image = get_viewport().get_texture().get_image()
	shot.save_png(OUT)
	print("[phenotype-shot] %s x%d -> %s"
		% [which, ACROSS, ProjectSettings.globalize_path(OUT)])
	MetaState.resume_saves()
	get_tree().quit(0)
