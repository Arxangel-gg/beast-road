extends Node
## Measures the lobby's party card against the Hold's card stage (2026-10-06,
## the co-op avatar bug): where each stage puts its Warden, its feet, its
## offset and its dress layers, and a 4x photograph of the party card.
##
##   tools/perf_offscreen.sh <profile> res://tools/coop_portrait_probe.tscn
##
## Diagnostic only, never a gate.

func _ready() -> void:
	MetaState.hold_saves()
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	WardenGlass.mark_offered()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dark := ColorRect.new()
	dark.color = Color(0.1, 0.12, 0.14)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dark)

	var card := CoopPartyPortrait.new()
	card.position = Vector2(40.0, 40.0)
	card.scale = Vector2(4.0, 4.0)
	root.add_child(card)
	card.configure(1, "Warden", Balance.PARTY_COLOURS[0] if "PARTY_COLOURS" in Balance else Color.RED,
		"Red", true)

	# **The lobby's own order**: configured before it is added to the tree,
	# which is how `CoopScreen._update_party_view` builds a seat.
	var late := CoopPartyPortrait.new()
	late.configure(2, "Warden", Color.BLUE, "Blue", true)
	late.position = Vector2(40.0, 560.0)
	late.scale = Vector2(0.8, 0.8)
	root.add_child(late)

	var hold := WardenStage.new()
	hold.turntable = false
	hold.art_scale = 1.4
	hold.position = Vector2(700.0, 40.0)
	hold.custom_minimum_size = Vector2(200.0, 260.0)
	root.add_child(hold)
	hold.show_look(WardenLook.worn())

	for _f: int in 30:
		await get_tree().process_frame
	_say("lobby card stage", card.get("_stage") as WardenStage)
	_say("lobby-order card stage", late.get("_stage") as WardenStage)
	_say("hold card stage", hold)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "user://coop_portrait_probe.png"
	image.save_png(path)
	print("[portrait-probe] -> %s" % ProjectSettings.globalize_path(path))
	MetaState.resume_saves()
	get_tree().quit(0)


func _say(label: String, stage: WardenStage) -> void:
	if stage == null:
		print("[portrait-probe] %s: no stage" % label)
		return
	var viewport: SubViewport = stage.get("_viewport")
	var inner: Node2D = stage.get("_stage")
	var sprite: Sprite2D = stage.sprite()
	print("[portrait-probe] %s: control size %s viewport %s feet_at %.2f art_scale %.3f" % [
		label, stage.size, viewport.size, stage.feet_at, stage.art_scale])
	print("[portrait-probe]   inner position %s scale %s figure_rect %s" % [
		inner.position, inner.scale, stage.figure_rect()])
	print("[portrait-probe]   sprite centered %s offset %s region %s position %s texture %s" % [
		sprite.centered, sprite.offset, sprite.region_rect, sprite.position,
		sprite.texture.resource_path if sprite.texture != null else "none"])
	for child: Node in sprite.get_children():
		_say_part(child, "    ")
	for child: Node in inner.get_children():
		if child is Sprite2D and child != sprite:
			_say_part(child, "    (stage) ")


func _say_part(node: Node, pad: String) -> void:
	var sprite := node as Sprite2D
	if sprite != null:
		print("[portrait-probe] %s%s visible %s position %s offset %s centered %s region %s behind %s" % [
			pad, node.name, sprite.visible, sprite.position, sprite.offset, sprite.centered,
			sprite.region_rect if sprite.region_enabled else Rect2(), sprite.show_behind_parent])
	else:
		print("[portrait-probe] %s%s (%s) visible %s" % [pad, node.name, node.get_class(),
			(node as CanvasItem).visible if node is CanvasItem else true])
	for child: Node in node.get_children():
		_say_part(child, pad + "  ")
