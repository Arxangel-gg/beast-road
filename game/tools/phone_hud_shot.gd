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
	var touch: bool = true
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--desktop":
			touch = false
		if argument.begins_with("--viewport="):
			var dimensions: PackedStringArray = argument.trim_prefix("--viewport=").split("x")
			if dimensions.size() == 2:
				viewport_size = Vector2i(dimensions[0].to_int(), dimensions[1].to_int())
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = viewport_size
	MetaState.settings[TouchInput.TOUCH_KEY] = touch
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

	# The build sheet, in Preparation: where its heading, list, footer and Close
	# button land on this shape. `layout_check` opens it too, and says only that
	# two of its parts overlap.
	RunState.set_phase(RunState.Phase.PREPARATION)
	await _settle(0.4)
	var field: Battlefield = _run.battlefield
	_run.hud._open_build_panel(_plot_in_view(field))
	await _settle(0.6)
	await _shot("sheet")
	_print_tree(_run.hud.get("_build_panel") as Control, 0)
	# The list a player actually reads: the element with the most towers, picked
	# through the rail's own button.
	var fullest: Button = null
	var most: int = -1
	for node: Node in _all(_run.hud.get("_build_list") as Node):
		var row := node as Button
		if row == null or not row.toggle_mode:
			continue
		var count: int = row.text.split(" ")[-1].to_int()
		if count > most:
			most = count
			fullest = row
	if fullest != null:
		fullest.pressed.emit()
	await _settle(0.5)
	await _shot("sheet_list")
	# The hovered offer's ghost (2026-09-25): the first tower card, hovered the
	# way a cursor does, standing on the plot inside its reach.
	for node: Node in _all(_run.hud.get("_build_list") as Node):
		var card := node as Button
		# Disabled rows too: a tower the purse cannot reach yet is the one a
		# player most wants to see the reach of.
		if card != null and not card.toggle_mode and card.get_child_count() > 0:
			card.mouse_entered.emit()
			break
	await _settle(0.8)
	await _shot("ghost")
	# A beat later, so the two pictures can be held against each other: the ghost
	# and the tooltip both play their idle rather than standing still.
	await _settle(0.25)
	await _shot("ghost_b")
	_run.hud.call("_close_build_panel")
	# And the traps: the road sheet, on the nearest road tile.
	var road: Vector2i = _road_in_view(field)
	_run.hud.call("_open_road_panel", road)
	await _settle(0.5)
	await _shot("road")
	for node: Node in _all(_run.hud.get("_road_list") as Node):
		var row := node as Button
		if row != null and row.get_child_count() > 0:
			row.mouse_entered.emit()
			break
	await _settle(0.8)
	await _shot("road_ghost")

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


func _print_tree(control: Control, depth: int) -> void:
	if control == null or depth > 5 or not control.is_visible_in_tree():
		return
	var words: String = ""
	if control is Label:
		words = (control as Label).text.left(28)
	elif control is Button:
		words = (control as Button).text.left(28)
	print("[phone]   %s%s %s %s" % ["  ".repeat(depth), control.get_class(),
		str(control.get_global_rect()), words])
	for child: Node in control.get_children():
		if child is Control:
			_print_tree(child as Control, depth + 1)


func _all(from: Node) -> Array[Node]:
	var out: Array[Node] = []
	if from == null:
		return out
	out.append(from)
	for child: Node in from.get_children():
		out.append_array(_all(child))
	return out


## A road tile the camera can see, left of the middle, for the trap sheet.
func _road_in_view(field: Battlefield) -> Vector2i:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var to_world: Transform2D = field.get_canvas_transform().affine_inverse()
	var aim: Vector2i = BattleGrid.world_to_tile(to_world * (view * Vector2(0.36, 0.52)))
	for radius: int in range(0, 16):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var tile: Vector2i = aim + Vector2i(dx, dy)
				if field.grid.cell_at(tile) == BattleGrid.Cell.ROAD:
					return tile
	return aim


## A legal plot the camera can see, left of the middle where no sheet stands, so
## the hovered offer's ghost is in the picture. The lane pocket the gates use is
## ten paces up the north road, which is off the top of this view.
func _plot_in_view(field: Battlefield) -> Vector2i:
	if field == null:
		return Vector2i.ZERO
	var view: Vector2 = get_viewport().get_visible_rect().size
	var to_world: Transform2D = field.get_canvas_transform().affine_inverse()
	var aim: Vector2i = BattleGrid.world_to_tile(to_world * (view * Vector2(0.36, 0.52)))
	for radius: int in range(0, 12):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var tile: Vector2i = aim + Vector2i(dx, dy)
				if field.placement_problem(tile).is_empty():
					return tile
	return field.free_anchor_near(0)

