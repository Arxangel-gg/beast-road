class_name ItemData
extends GameData

## A carried consumable (GDD v4 §29, §698).
##
## v4 is explicit that "Relics, Resurrection Draughts, tower blueprints, and
## Oathbound leaders are items or unlock IDs, not currencies" — an item is a
## thing the player is holding, with a carry limit, not a number in a wallet.
##
## `id = "resurrection_draught"` -> `res://art/icons/ui/ui_resurrection_draught.png`
## by the usual path convention.

## How many the player may hold at once. v4 caps the Draught at one so it stays
## an emergency rather than a stack of extra lives.
@export var carry_limit: int = 1

## The line shown when one is awarded.
@export_multiline var acquire_line: String = ""

## Chance a full raid clear yields one, 0..1. Rarity is data, not a branch in the
## raid: a second consumable is a file, not an edit to the reward code.
@export_range(0.0, 1.0, 0.01) var raid_clear_chance: float = 0.0


func get_sprite_path() -> String:
	if id.is_empty():
		return ""
	return "res://art/icons/ui/ui_%s.png" % id
