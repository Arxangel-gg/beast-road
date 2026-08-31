class_name BlueprintData
extends GameData

## Permanent knowledge (owner decision, 2026-08-31).
##
## `id = "ember_arrow_plan"` -> `res://art/icons/blueprints/blueprint_ember_arrow_plan.png`
##
## **A blueprint unlocks a recipe, and that is all it does.** It is not an item,
## it is not consumed, and it does not sit in a bag once learned. Learning one is
## an entry in `MetaState.unlocked` - the list that already carries every other
## permanent unlock - so this system adds no new save shape and working rule 7 is
## untouched by it.
##
## What it buys is the thing the design was missing: a boss that changes your
## *future* runs rather than dropping one more sword.

## What learning this makes craftable. The id names an `AmmoData` or a
## `RangedWeaponData`; the kind says which table to look in.
@export var unlocks_kind: String = "ammo"
@export var unlocks_id: String = ""

## How significant the unlock is. Unlike item rarity this is a promise rather
## than a roll - a Rare blueprint is rare because what it teaches matters.
@export_enum("common", "uncommon", "rare", "legendary") var rarity: String = "common"

## Where it is found, for the codex entry. Player-facing, so it lives here
## rather than in a script (working rule 9).
@export var source_line: String = ""


## A plan looks like the thing it teaches.
##
## **Derived from what it unlocks, not from its own id.** Six plans would
## otherwise need six icons that all say "a rolled-up drawing", which tells the
## player nothing about what they just found - and the interesting information is
## exactly *which* recipe it is. It also means adding a plan costs no art at all,
## which is the whole spirit of deriving paths from ids.
func get_sprite_path() -> String:
	var made: GameData = null
	if unlocks_kind == "ammo":
		made = ContentDB.ammo_kinds.get(unlocks_id, null) as GameData
	elif unlocks_kind == "ranged":
		made = ContentDB.ranged_weapons.get(unlocks_id, null) as GameData
	return made.get_sprite_path() if made != null else ""
