extends Node

## Photographs the Hold's sandbox door opened (2026-09-30): the act screen as
## the sandbox, built by the real main menu so the Hold is the one the game
## hands its screen to.
##
##   godot --path game res://tools/sandbox_shot.tscn
##
## Diagnostic only, never a gate: `menu_layout_check` measures the screen at the
## phone shapes and `sandbox_check` holds what the road keeps.


func _ready() -> void:
	MetaState.hold_saves()
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1920, 1080)
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	WardenGlass.mark_offered()
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	for _f: int in 20:
		await get_tree().process_frame
	var hub: Node = menu.get("_hub")
	if hub == null:
		print("[sandbox-shot] no Hold on the menu")
		get_tree().quit(1)
		return
	hub.call("open")
	for _f: int in 10:
		await get_tree().process_frame
	hub.call("_road_sandbox")
	var begun: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - begun < 1200:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "user://sandbox_screen.png"
	image.save_png(path)
	print("[sandbox-shot] screen -> %s" % ProjectSettings.globalize_path(path))
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	menu.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	get_tree().quit(0)
