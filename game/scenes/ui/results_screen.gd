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
	plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.remove_child(body)
	plate.add_child(body)
	column.add_child(plate)
	column.move_child(plate, index)
	# Statistics are read down a column, so they need room between the lines. The
	# default leading packs them tight enough that the eye loses its place.
	body.add_theme_constant_override("line_spacing", 6)


func show_results(victory: bool, summary: Dictionary) -> void:
	title.text = "The sanctuary" if victory else "The road ends here"

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
	var lines: PackedStringArray = [
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
	for entry: String in unlocks:
		lines.append("   " + entry.replace(":", "  "))

	# GDD §46 wants the version in the debrief as well as in Settings, and this is
	# the better of the two places: it is the screen somebody is looking at when a
	# run has just gone wrong, which is the moment they screenshot it.
	lines.append("")
	lines.append(BuildInfo.diagnostics())
	body.text = "\n".join(lines)

	panel.visible = true
	get_tree().paused = true
	menu_button.grab_focus()
