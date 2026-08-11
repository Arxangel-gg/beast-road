class_name CaptiveData
extends GameData

## A defeated chieftain taken back to the town and put to work (GDD §6.3).
##
## `id = "bogkin"` -> `res://art/raid/captive_bogkin.png`
##
## **Every player-facing word about what this is lives in this file's exported
## strings, never in logic.** GDD §6.3 records that the framing is unsettled and
## that v2 argued against it on positioning grounds; the mechanic is "a unit
## assigned to a building produces a bonus", and the fiction sits on top of it.
## Changing enslavement to conscription, oath-binding, or taking a trophy
## standard is editing these fields and the art, and nothing else.

## What the player is called in relation to this unit, e.g. "Captive", "Oathbound".
@export var role_noun: String = "Captive"

## The verb used when acquiring one, e.g. "Bind", "Conscript", "Claim".
@export var acquire_verb: String = "Bind"

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
