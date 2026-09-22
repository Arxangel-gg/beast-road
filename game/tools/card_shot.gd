extends Node

## Photographs the Warden's card in the Hold, as the front door opens it.
##
##   godot --path game res://tools/card_shot.tscn
##
## The owner's screenshot of 2026-09-21 showed the card's left column clipped
## by a few pixels - "Ranger" without its R, "Warden" as "Narden". A layout gate
## sees rects and cannot see a glyph under a clip edge, so the card is stood up
## through the real menu (so every adopted door is in its grid) and written to
## `user://card_shot.png`.

const SIZE := Vector2i(1920, 1080)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[card-shot] skipped: a headless display has no pixels to read")
		get_tree().quit(0)
		return
	get_window().size = SIZE
	get_viewport().set_content_scale_size(SIZE)
	MetaState.hold_saves()
	var menu: Control = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child(menu)
	for _frame: int in 4:
		await get_tree().process_frame
	var hub: HubScreen = menu.get("_hub") as HubScreen
	if hub == null:
		print("[card-shot] the menu has no Hold")
		get_tree().quit(1)
		return
	hub.open()
	for _frame: int in 6:
		await get_tree().process_frame
	hub.call("_show_card")
	for _frame: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("user://card_shot.png")
	frame.save_png(path)
	print("[card-shot] card -> %s" % path)
	# And a door open from the card: the Chronicle, which must stand over the
	# Hold rather than over the front door's painting.
	var chronicle: Button = null
	var grid: Node = hub.get("_grid")
	if grid != null:
		for child: Node in grid.get_children():
			if child is Button and String((child as Button).text).contains("Chronicle"):
				chronicle = child as Button
	if chronicle != null:
		chronicle.pressed.emit()
		for _frame2: int in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var door: Image = get_viewport().get_texture().get_image()
		var door_path: String = ProjectSettings.globalize_path("user://card_shot_door.png")
		door.save_png(door_path)
		print("[card-shot] door -> %s" % door_path)
	else:
		print("[card-shot] no Chronicle door in the grid")
	MetaState.resume_saves()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 6:
		await get_tree().process_frame
	get_tree().quit(0)
