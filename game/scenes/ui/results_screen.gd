class_name ResultsScreen
extends CanvasLayer

## End of run (GDD §9, §10). Win or lose, the unlock payout has already been
## banked by GameDirector; this only reports it.

@export var panel: Control
@export var title: Label
@export var body: Label
@export var menu_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	# The panel was a fixed 800x600 box. A finished three-act run produces the
	# longest debrief in the game - every act, every road, and the whole unlock
	# payout - and a VBoxContainer does not shrink its children below their
	# minimum size, so the text simply pushed the one button off the bottom.
	# Winning the game left the player on a screen with no way out of it.
	# Wide enough for the longest debrief, and centred rather than stretched: a
	# full-height panel around a short summary is a small block of text at the
	# top of an enormous empty box, which reads as a bug rather than as a screen.
	panel.set_anchors_preset(Control.PRESET_CENTER, false)
	panel.custom_minimum_size = Vector2(1180.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	IconKit.on_button(menu_button, "close", 24)
	# The body sits on its own dark plate rather than directly on the ornate
	# frame. Twelve lines of statistics against riveted ironwork is a lot of
	# texture behind a lot of small type, and the plate is what makes it legible.
	_plate_body()
	menu_button.pressed.connect(func() -> void:
		get_tree().paused = false
		GameDirector.goto_menu())


func _plate_body() -> void:
	if body == null or body.get_parent() == null:
		return
	var column: Node = body.get_parent()
	var index: int = body.get_index()
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"InnerPanel"
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# The statistics scroll and the button does not. Length is content here - a
	# longer run genuinely has more to say - so the fix is to give the text
	# somewhere to go, not to trim what a player earned the right to read.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Grows with the text up to a ceiling, then scrolls. Expanding to fill
	# instead is what left a short debrief floating in a void, and a fixed height
	# would clip the long one - which is the case that had no way out.
	scroll.custom_minimum_size = Vector2(0.0, 0.0)
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	column.remove_child(body)
	plate.add_child(body)
	scroll.add_child(plate)
	column.add_child(scroll)
	column.move_child(scroll, index)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Statistics are read down a column, so they need room between the lines. The
	# default leading packs them tight enough that the eye loses its place.
	body.add_theme_constant_override("line_spacing", 6)


func show_results(victory: bool, summary: Dictionary) -> void:
	title.text = "The sanctuary" if victory else "The road ends here"
	if victory and int(summary.get("endless_waves", 0)) > 0:
		title.text = "The sanctuary, and beyond"

	var unlocks: Array = summary.get("unlocks", [])
	var seconds: int = int(summary.get("time", 0))
	var duration: String = "%d:%02d" % [seconds / 60, seconds % 60]
	var planning_seconds: int = int(summary.get("planning_time", 0))
	var planning_duration: String = "%d:%02d" % [planning_seconds / 60, planning_seconds % 60]
	var wave_id: String = String(summary.get("most_common_wave", ""))
	var wave: WaveArchetypeData = ContentDB.wave_archetype(wave_id)
	var wave_name: String = wave.display_name if wave != null else "—"
	var command_orders: Dictionary = summary.get("command_orders", {})
	var command_order_total: int = 0
	for value: Variant in command_orders.values():
		command_order_total += int(value)
	var road_names: PackedStringArray = []
	for entry: Dictionary in summary.get("roads", []):
		var road: RoadData = ContentDB.road(String(entry.get("road", "")))
		var difficulty: RoadDifficultyData = ContentDB.road_difficulty(
			String(entry.get("difficulty", "")))
		if road != null and difficulty != null:
			road_names.append("%s %s" % [difficulty.display_name, road.display_name])
	var route_lines: PackedStringArray = []
	for start: int in range(0, road_names.size(), 3):
		route_lines.append("  →  ".join(road_names.slice(start, mini(start + 3, road_names.size()))))
	var lines: PackedStringArray = [
		"Run seed   %09d" % int(summary.get("seed", 0)),
		"Route   %s" % ("\n        ".join(route_lines) if not route_lines.is_empty() else "—"),
		"Distance   %d of %d" % [int(summary.get("distance", 0)), int(Balance.JOURNEY_TOTAL_DISTANCE)],
		"Reached act %d   ·   %s combat   ·   %s planning" % [
			int(summary.get("act", 1)), duration, planning_duration],
		"Killed %d   ·   fell %d times" % [int(summary.get("kills", 0)), int(summary.get("deaths", 0))],
		"Raids %d   ·   Oathbound leaders %d" % [int(summary.get("raids", 0)), int(summary.get("chieftains", 0))],
		"",
		"DEFENCE",
		"Town damage %d across %d breaches   ·   peak pressure %d%%" % [
			int(round(float(summary.get("town_damage", 0.0)))),
			int(summary.get("town_hits", 0)),
			int(round(float(summary.get("peak_pressure", 0.0)) * 100.0))],
		"Built %d   ·   upgraded %d   ·   lost %d   ·   sold %d" % [
			int(summary.get("towers_built", 0)), int(summary.get("tower_upgrades", 0)),
			int(summary.get("towers_lost", 0)), int(summary.get("towers_sold", 0))],
		"Resources earned %d   ·   invested %d   ·   signature threat %s" % [
			int(summary.get("resources_earned", 0)), int(summary.get("resources_spent", 0)), wave_name],
		"Command earned %d   ·   orders issued %d" % [
			int(round(float(summary.get("command_earned", 0.0)))), command_order_total],
		"Wounds suffered %d   ·   Hearthmends %d" % [
			int(summary.get("wounds", 0)), int(summary.get("hearthmends", 0))],
		"",
		"Added to the pool: %d" % unlocks.size(),
	]
	var endless_waves: int = int(summary.get("endless_waves", 0))
	if endless_waves > 0:
		var at: int = lines.find("DEFENCE")
		if at > 0:
			lines.insert(at - 1, "Endless   %d waves past the summit" % endless_waves)

	for entry: String in unlocks:
		lines.append("   " + entry.replace(":", "  "))

	# GDD §46 wants the version in the debrief as well as in Settings, and this is
	# the better of the two places: it is the screen somebody is looking at when a
	# run has just gone wrong, which is the moment they screenshot it.
	lines.append("")
	lines.append(BuildInfo.diagnostics())
	body.text = "\n".join(lines)

	# Measured after the text is in, so the panel is only as tall as it needs to
	# be and the scroll only appears when the debrief actually overruns.
	await get_tree().process_frame
	var ceiling: float = float(get_viewport().get_visible_rect().size.y) * 0.78
	var wanted: float = body.get_combined_minimum_size().y
	var scroll_box: ScrollContainer = body.get_parent().get_parent() as ScrollContainer
	if scroll_box != null:
		scroll_box.custom_minimum_size = Vector2(0.0, minf(wanted, ceiling))

	panel.visible = true
	get_tree().paused = true
	menu_button.grab_focus()
