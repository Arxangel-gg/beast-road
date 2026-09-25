extends Node

## Renders the co-op screen so it can be looked at. Diagnostic only.
##
##   godot --path game res://tools/coop_screen_shot.tscn -- --hosting

func _ready() -> void:
	# Held for the whole run: this tool edits `MetaState`, and a tool that
	# edits the account must never be able to write it to the player's disk.
	# See `save_guard_check`, which finds these by reading them.
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var hosting: bool = arguments.has("--hosting")
	# **A full lobby with four different dyes**, which is the one thing a real
	# session cannot be made to show on one machine. The cards are drawn from
	# `party().seats()`, so seating them locally photographs exactly what a
	# guest's roster produces - and the lobby drew every Warden painted until
	# 2026-09-22, including the local player's own.
	var party: bool = arguments.has("--party")
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
	if party:
		# **The cards on a plate rather than in the lobby.** `_update_party_view`
		# returns unless `Coop.is_networked()`, so a party seated locally draws
		# nothing - and what changed is the card, configured exactly as the
		# lobby configures it.
		await _photograph_the_cards(menu)
		return
	if hosting:
		Coop.host(port)
	# Waits for the address rather than counting frames. UPnP takes seconds when
	# it works at all, and the public-address fallback is a round trip to the
	# internet - a fixed forty frames photographed the "looking..." state every
	# time and said nothing about whether either ever answers.
	var deadline: int = Time.get_ticks_msec() + (0 if party else 12000)
	while Time.get_ticks_msec() < deadline and Coop.external_address.is_empty():
		await get_tree().process_frame
	for _f: int in 20:
		await get_tree().process_frame
	coop.call("_refresh")
	for _f: int in 6:
		await get_tree().process_frame
	var path: String = "user://coop_screen%s.png" % ("_party" if party
		else ("_hosting" if hosting else ""))
	get_viewport().get_texture().get_image().save_png(path)
	print("[coop-shot] -> %s" % ProjectSettings.globalize_path(path))
	Coop.leave()
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)


## Four seats, four dyes, on a plate.
func _photograph_the_cards(menu: Node) -> void:
	(menu as CanvasItem).visible = false
	var plate := ColorRect.new()
	plate.color = Color(0.05, 0.06, 0.06)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.position = Vector2(40.0, 120.0)
	add_child(row)
	MetaState.set_look("cloak", 0.35)
	MetaState.set_look("sash", 0.30)
	var dyes: Array = [[], [-0.30, 0.0], [0.0, -0.35], [0.42, 0.42]]
	var names: Array = ["You", "Bren", "Cor", "Del"]
	for index: int in 4:
		var card := CoopPartyPortrait.new()
		row.add_child(card)
		card.configure(index + 1, String(names[index]),
			CoopParty.colour_of(index + 1),
			Balance.PARTY_COLOUR_NAMES[index], index == 0, dyes[index] as Array)
	for _f: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = "user://coop_screen_party.png"
	get_viewport().get_texture().get_image().save_png(path)
	print("[coop-shot] -> %s" % ProjectSettings.globalize_path(path))
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
