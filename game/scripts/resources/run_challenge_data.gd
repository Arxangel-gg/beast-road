class_name RunChallengeData
extends GameData

## One optional, run-local mastery vow. Rules stay in RunState; every sentence
## the player reads lives here so wording can change without touching logic.

@export_multiline var offer_line: String = ""
@export_multiline var condition_line: String = ""
@export_multiline var reward_line: String = ""
@export_multiline var accepted_line: String = ""
@export_multiline var pursuer_line: String = ""
@export_multiline var success_line: String = ""
@export var button_line: String = ""
@export var waiting_line: String = ""
@export var sworn_line: String = ""
@export_multiline var ration_blocked_line: String = ""
@export var active_status: String = ""
@export var pursuer_hunt_status: String = ""
@export var pursuer_defeated_status: String = ""
@export var failure_lines: Dictionary = {}


func failure_line(reason: String) -> String:
	return String(failure_lines.get(reason, description))


func get_sprite_path() -> String:
	return GameData.derive_path("icons/ui", "ui_", id)
