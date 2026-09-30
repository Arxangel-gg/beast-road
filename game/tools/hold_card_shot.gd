extends Node

## Photographs the Warden's card in the Hold with its professions opened far
## enough to show the craft talents (2026-09-30): one craft with a talent kept,
## one at a level with a choice waiting, and the rest dimmed at the level they
## open at.
##
##   godot --path game res://tools/hold_card_shot.tscn
##
## Diagnostic only, never a gate: `craft_talent_check` holds the rules.


func _ready() -> void:
	MetaState.hold_saves()
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1920, 1080)
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	WardenGlass.mark_offered()
	for pair: Array in [["angler", 20], ["woodcutter", 12], ["miner", 4]]:
		var xp: float = 0.0
		for at: int in range(1, int(pair[1])):
			xp += MetaState.profession_xp_to_leave(at)
		MetaState.profession_xp[String(pair[0])] = xp
	MetaState.choose_talent("angler_quick_strike")
	MetaState.choose_talent("angler_deep_lure")
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	for _f: int in 20:
		await get_tree().process_frame
	var hub: Node = menu.get("_hub")
	hub.call("open")
	for _f: int in 10:
		await get_tree().process_frame
	hub.call("_show_card")
	var begun: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - begun < 1200:
		await get_tree().process_frame
	# The professions sit under the portrait: scroll the card down to them.
	for node: Node in hub.find_children("*", "ScrollContainer", true, false):
		var scroll := node as ScrollContainer
		if scroll != null and scroll.is_visible_in_tree():
			var first: Node = hub.find_child("Talents", true, false)
			if first is Control:
				scroll.scroll_vertical = int((first as Control).get_global_rect().position.y
					- scroll.get_global_rect().position.y) - 120
	for _f: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "user://hold_card.png"
	image.save_png(path)
	print("[hold-card-shot] card -> %s" % ProjectSettings.globalize_path(path))
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	menu.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	get_tree().quit(0)
