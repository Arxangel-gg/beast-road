class_name CaptiveData
extends GameData

## A defeated leader who freely swears one run-long specialist oath (GDD §30).
##
## `id = "bogkin"` -> `res://art/raid/captive_bogkin.png`
##
## The class name and save field remain for migration compatibility. Shipped
## player-facing language is Oathbound throughout.

## What the player is called in relation to this unit, e.g. "Captive", "Oathbound".
@export var role_noun: String = "Oathbound"

## The verb used when acquiring one, e.g. "Bind", "Conscript", "Claim".
@export var acquire_verb: String = "Assign"

## The line shown on the raid victory screen.
@export_multiline var acquire_line: String = ""

## Which enemy breed this came from; drives the sprite and the flavour.
@export var breed_id: String = ""

## Multiplier on the work bonus this unit contributes when assigned.
@export var work_multiplier: float = 1.0

## Buildings this unit may be assigned to. Empty means any that take captives.
@export var allowed_building_ids: Array[String] = []


func get_sprite_path() -> String:
	return GameData.derive_path("raid", "captive_", id)


func can_work_at(building_id: String) -> bool:
	return allowed_building_ids.is_empty() or allowed_building_ids.has(building_id)
