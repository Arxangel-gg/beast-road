extends Node

## Renders the co-op screen so it can be looked at. Diagnostic only.
##
##   godot --path game res://tools/coop_screen_shot.tscn -- --hosting

func _ready() -> void:
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var hosting: bool = arguments.has("--hosting")
	var port: int = Balance.COOP_PORT
	for argument: String in arguments:
		if argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
	var menu: MainMenu = (load("res://scenes/ui/main_menu.tscn") as PackedScene) \
		.instantiate() as MainMenu
	add_child(menu)
	for _f: int in 14:
		await get_tree().process_frame
	var coop: CanvasLayer = menu.get("_coop") as CanvasLayer
	coop.call("open")
	if hosting:
		Coop.host(port)
	# Waits for the address rather than counting frames. UPnP takes seconds when
	# it works at all, and the public-address fallback is a round trip to the
	# internet - a fixed forty frames photographed the "looking..." state every
	# time and said nothing about whether either ever answers.
	var deadline: int = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline and Coop.external_address.is_empty():
		await get_tree().process_frame
	for _f: int in 20:
		await get_tree().process_frame
	coop.call("_refresh")
	for _f: int in 6:
		await get_tree().process_frame
	var path: String = "user://coop_screen%s.png" % ("_hosting" if hosting else "")
	get_viewport().get_texture().get_image().save_png(path)
	print("[coop-shot] -> %s" % ProjectSettings.globalize_path(path))
	Coop.leave()
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
