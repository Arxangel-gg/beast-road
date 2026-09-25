extends Node

## Captures each full-screen interface so they can be compared side by side.
## Diagnostic only, never a gate.
##
##   godot --path game res://tools/ui_shot.tscn -- --viewport=1280x591 --touch=on
##
## The viewport argument matters more than it looks. Four layout faults were
## reported from a phone and none of them existed at 1920x1080: what breaks a
## panel is a screen shorter than the panel was drawn for, and the only way to
## see that here is to open a window that shape.

func _ready() -> void:
	# Held for the whole run: this tool edits `MetaState`, and a tool that
	# edits the account must never be able to write it to the player's disk.
	# See `save_guard_check`, which finds these by reading them.
	MetaState.hold_saves()
	var viewport_size := Vector2i.ZERO
	var touch_layout: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--touch=on":
			touch_layout = true
		elif argument.begins_with("--viewport="):
			var dimensions: PackedStringArray = argument.trim_prefix("--viewport=").split("x")
			if dimensions.size() == 2:
				viewport_size = Vector2i(dimensions[0].to_int(), dimensions[1].to_int())
	if viewport_size.x > 0 and viewport_size.y > 0:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = viewport_size
	if touch_layout:
		MetaState.settings[TouchInput.TOUCH_KEY] = true
		TouchInput.refresh()
		ScreenFit._fit()

	MetaState.settings["tutorial_seen"] = true
	RunState.reset()
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	if touch_layout:
		TouchInput.refresh()
		for _f: int in 4:
			await get_tree().process_frame

	await _shot("town", func() -> void: run.town_panel.open("forge"))
	for page: int in 3:
		var which: int = page
		await _shot("mansion_%d" % which, func() -> void:
			run.town_panel.open("sanctum")
			run.town_panel.set("_mansion_page", which)
			run.town_panel.call("_refresh"))
	# **The reported state, photographed** (owner screenshots, 2026-09-13): a
	# tier-three Mansion in Act V with the Power and Ultimate slots empty. The
	# fix is that the draft offers a way out of it, and the only way to know the
	# offers say so is to look at them.
	await _shot("mansion_dead_slots", func() -> void:
		RunState.act = 5
		RunState.building_tiers["sanctum"] = 3
		RunState.trained_discipline_nodes.clear()
		for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
			if node.discipline == DisciplineNodeData.Discipline.BLOOD \
					and node.role in [DisciplineNodeData.Role.ATTACK,
						DisciplineNodeData.Role.DEFENSE]:
				RunState.trained_discipline_nodes.append(node.id)
		RunState.equipped_discipline_slots = ["", "", "", ""]
		RunState.hero_skill_points = 4
		RunState.refresh_discipline_offers()
		run.town_panel.open("sanctum")
		run.town_panel.set("_mansion_page", 1)
		run.town_panel.call("_refresh"))
	run.town_panel.close()
	# **The HUD itself**, which nothing photographed - and the three pool bars
	# are drawn rather than laid out, so `layout_check` passing says only that
	# they collide with nothing. A name that renders as nothing at all would
	# pass that gate perfectly. Filled first, because an empty bar is a grey
	# rectangle and says nothing about whether the letters arrived.
	await _shot("hud", func() -> void:
		run.hud.visible = true
		EventBus.hero_mana_changed.emit(28.0, 40.0)
		EventBus.hero_stamina_changed.emit(22.0, 40.0))
	# The ride button with a thrown rider's ring on it (2026-09-21). The
	# owner's account has a mount; a fresh one has none and the button is
	# hidden, so one is saddled here for the picture.
	await _shot("hud_thrown", func() -> void:
		var stock: Array[MountData] = ContentDB.mounts_sorted() \
			if ContentDB.has_method("mounts_sorted") else []
		if stock.is_empty():
			return
		MetaState.mounts.clear()
		MetaState.mounts.append(stock[0].id)
		MetaState.mount_saddled = stock[0].id
		var who: Hero = run.battlefield.hero
		who.set("_mount_wait", 0.0)
		who.mount()
		who.health.take_damage(5.0, who.global_position + Vector2(40.0, 0.0))
		run.hud.call("_update_ride_button"))
	await _shot("pause", func() -> void: run.pause_ui.toggle())
	run.pause_ui.set_showing(false)
	get_tree().paused = false
	await _shot("crossroad", func() -> void: run.crossroad_ui.open(1))
	run.crossroad_ui.visible = false
	# The portent screen shares the crossroad's panel and its one-choice rule,
	# so it is one line away and it is the only screen omen art appears on.
	await _shot("portents", func() -> void:
		RunState.pending_omens.clear()
		var offered: int = 0
		for id: Variant in ContentDB.omens:
			if offered >= Balance.OMEN_OFFER_COUNT:
				break
			RunState.pending_omens.append(String(id))
			offered += 1
		run.crossroad_ui.visible = true
		run.crossroad_ui.open_omen_choice())
	run.crossroad_ui.visible = false
	await _shot("results", func() -> void:
		run.hud.show_end_report()
		run.results_ui.show_results(false, {
			"seed": 123456789, "act": 2, "kills": 214, "distance": 1400.0,
			"towers_built": 11, "resources_earned": 900,
		}))
	run.results_ui.visible = false
	await _shot("ending", func() -> void: run.ending_ui.play())
	run.ending_ui.visible = false

	# **The forge** (2026-09-13). It is the newest full screen in the game and
	# it was the only one nothing photographed - and it is the one screen whose
	# whole job is to show numbers before the player spends anything, which is
	# exactly the kind of screen a layout gate passes and an eye does not.
	#
	# Stocked first, because an empty store draws one sentence and says nothing
	# about the screen. Held saves are already on, so none of this reaches a
	# real account.
	var forge := SmithyScreen.new()
	add_child(forge)
	await _shot("forge", func() -> void:
		for kind: MaterialData in ContentDB.materials_sorted():
			MetaState.gain_material(kind.id, 40)
		MetaState.gain_profession_xp("smith", 900)
		forge.open())
	forge.hide_screen()

	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	run.queue_free()
	for _f: int in 20: await get_tree().process_frame
	get_tree().quit(0)


func _shot(name: String, open: Callable) -> void:
	open.call()
	get_tree().paused = false
	for _f: int in 90:
		await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("user://ui_%s.png" % name)
	print("[ui] %s -> %s" % [name,
		ProjectSettings.globalize_path("user://ui_%s.png" % name)])
