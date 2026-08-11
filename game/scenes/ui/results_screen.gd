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
	var lines: PackedStringArray = [
		"Distance   %d of %d" % [int(summary.get("distance", 0)), int(Balance.JOURNEY_TOTAL_DISTANCE)],
		"Reached act %d" % int(summary.get("act", 1)),
		"Killed %d   ·   fell %d times" % [int(summary.get("kills", 0)), int(summary.get("deaths", 0))],
		"Raids %d   ·   chieftains taken %d" % [int(summary.get("raids", 0)), int(summary.get("chieftains", 0))],
		"",
		"Added to the pool: %d" % unlocks.size(),
	]
	for entry: String in unlocks:
		lines.append("   " + entry.replace(":", "  "))
	body.text = "\n".join(lines)

	panel.visible = true
	get_tree().paused = true
	menu_button.grab_focus()
