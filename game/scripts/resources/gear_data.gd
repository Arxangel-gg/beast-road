class_name GearData
extends GameData

## A *kind* of gear. What the player owns is an instance of one of these, rolled
## at a rarity and upgraded to a level — see `Stash`.
##
## Split that way on purpose. A "Rimeplate Cuirass" is authored content: a name,
## a slot, an icon, which attribute it favours. Its rarity and level are things
## that happened to one particular copy in one particular run, and storing those
## on the resource would mean every save wrote back into the content files.
##
## Distinct from `ItemData`, which is a consumable the player carries for a run.
## Gear persists (owner ruling, 2026-08-20) and is worn.

enum Slot { WEAPON, ARMOUR, CHARM }

@export var slot: Slot = Slot.WEAPON

## Which hero attribute this kind of gear pushes, as a `RunState.Attribute`.
## Gear grants attribute *points* rather than raw stats, so one number governs
## hero power and a relic cannot quietly out-scale a levelling curve.
@export var attribute: int = 0

## Points at rarity 0, level 1. Rarity and level multiply this.
@export_range(1, 12) var base_points: int = 2

## Roughly how often this kind drops relative to its siblings.
@export_range(0.0, 10.0) var weight: float = 1.0

## Earliest campaign tier that may drop it, by order.
@export var min_tier: int = 0


func slot_name() -> String:
	match slot:
		Slot.WEAPON:
			return "Weapon"
		Slot.ARMOUR:
			return "Armour"
		_:
			return "Charm"


func get_sprite_path() -> String:
	return GameData.derive_path("icons/ui", "ui_", id)
