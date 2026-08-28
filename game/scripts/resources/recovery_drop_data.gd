class_name RecoveryDropData
extends GameData

## A battlefield recovery that is collected immediately rather than carried.

@export_multiline var pickup_line: String = ""
@export_multiline var broken_line: String = ""
@export var active_status: String = ""


func get_sprite_path() -> String:
	return GameData.derive_path("loot", "loot_", id)
