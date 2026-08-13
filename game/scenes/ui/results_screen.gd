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
	menu_button.pressed.connect(func() -> void:
		get_tree().paused = false
		GameDirector.goto_menu())


func show_results(victory: bool, summary: Dictionary) -> void:
	title.text = "The sanctuary" if victory else "The road ends here"

	var unlocks: Array = summary.get("unlocks", [])
	var seconds: int = int(summary.get("time", 0))
	var duration: String = "%d:%02d" % [seconds / 60, seconds % 60]
	var wave_id: String = String(summary.get("most_common_wave", ""))
	var wave: WaveArchetypeData = ContentDB.wave_archetype(wave_id)
	var wave_name: String = wave.display_name if wave != null else "—"
	var lines: PackedStringArray = [
		"Distance   %d of %d" % [int(summary.get("distance", 0)), int(Balance.JOURNEY_TOTAL_DISTANCE)],
		"Reached act %d   ·   %s on the road" % [int(summary.get("act", 1)), duration],
		"Killed %d   ·   fell %d times" % [int(summary.get("kills", 0)), int(summary.get("deaths", 0))],
		"Raids %d   ·   chieftains taken %d" % [int(summary.get("raids", 0)), int(summary.get("chieftains", 0))],
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
		"",
		"Added to the pool: %d" % unlocks.size(),
	]
	for entry: String in unlocks:
		lines.append("   " + entry.replace(":", "  "))
	body.text = "\n".join(lines)

	panel.visible = true
	get_tree().paused = true
	menu_button.grab_focus()
