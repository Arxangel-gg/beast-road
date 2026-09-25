extends Node

## Photographs the HUD at a landscape phone's shape in the three states the
## owner reported from one (2026-09-25): the opening of a road, Preparation, and
## combat with Command earned and a mount saddled.
##
##   godot --path game res://tools/phone_hud_shot.tscn -- --viewport=1280x592
##
## Diagnostic only, never a gate. `layout_check` runs at this shape already and
## could not see what the owner's screenshots showed: it never earns Command, so
## the command panel is hidden; the dash button is drawn rather than laid out, so
## it has no rect to measure; and it never photographs Preparation. This prints
## the rects that matter beside each picture, so a reading and a photograph can
## be put side by side.

var _run: Run = null


func _ready() -> void:
	# Held for the whole run: this tool edits `MetaState`, and a tool that edits
	# the account must never be able to write it to the player's disk.
	MetaState.hold_saves()
	var viewport_size := Vector2i(1280, 592)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--viewport="):
			var dimensions: PackedStringArray = argument.trim_prefix("--viewport=").split("x")
			if dimensions.size() == 2:
				viewport_size = Vector2i(dimensions[0].to_int(), dimensions[1].to_int())
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = viewport_size
	MetaState.settings[TouchInput.TOUCH_KEY] = true
	TouchInput.refresh()
	ScreenFit._fit()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	Graphics.set_switch(Graphics.KEY_FPS_SHOW, true)
	# A saddled mount puts the Ride button on the bar: the widest the row gets.
	var stock: Array[MountData] = ContentDB.mounts_sorted()
	if not stock.is_empty():
		MetaState.mounts.clear()
		MetaState.mounts.append(stock[0].id)
		MetaState.mount_saddled = stock[0].id

	RunState.reset()
	# Live, or the thumb controls stay off the screen and the dash cluster the
	# owner photographed is never drawn.
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 6:
		await get_tree().process_frame
	TouchInput.refresh()
	await _settle(0.6)
	await _shot("opening")

	RunState.set_phase(RunState.Phase.PREPARATION)
	await _settle(0.6)
	await _shot("preparation")

	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	RunState.command_earned = 40.0
	EventBus.phase_changed.emit(int(RunState.Phase.ROAD_BATTLE), int(RunState.Phase.PREPARATION))
	# The command panel twice (2026-09-25): down to its faded meter while no
	# order is affordable, and open on the one order that is.
	RunState.command = 10.0
	EventBus.command_changed.emit(10.0, Balance.COMMAND_MAX)
	await _settle(0.6)
	await _shot("combat_idle")
	RunState.command = 40.0
	EventBus.command_changed.emit(40.0, Balance.COMMAND_MAX)
	await _settle(0.6)
	await _shot("combat")

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	_run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	get_tree().quit(0)


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "user://phone_hud_%s.png" % name
	image.save_png(path)
	print("[phone] %s -> %s" % [name, ProjectSettings.globalize_path(path)])
	print("[phone]   viewport %s" % str(get_viewport().get_visible_rect().size))
	var hud: HUD = _run.hud
	for field: String in ["_command_panel", "_action_row", "_nav_bar", "_preparation_panel",
			"_journey_bar", "_bottom_row", "_spell_bar", "_sundial", "_top_bar"]:
		var control := hud.get(field) as Control
		if control == null:
			print("[phone]   %-20s none" % field)
			continue
		print("[phone]   %-20s %s  %s" % [field, "shown" if control.is_visible_in_tree() else "hidden",
			str(control.get_global_rect())])
	for spot: String in ["dash_rect", "revive_rect", "loose_rect", "ammo_rect", "cast_rect", "use_rect"]:
		print("[phone]   %-20s %s" % [spot, str(TouchInput.call(spot))])
	print("[phone]   %-20s %s" % ["nav width", str(hud.nav_column_width())])
