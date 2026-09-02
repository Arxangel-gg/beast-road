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

## The eight places a piece can be worn.
##
## Owner request, 2026-09-01. Three slots meant three decisions a run; eight
## means a loadout has a shape. **The first three keep their ordinal values** so
## every save written before this reads back with its weapon, armour and charm
## exactly where it left them - `equipped` is keyed by this enum's integers.
##
## Two families, and the split is what keeps the reward honest: WEAPON and
## ARMOUR are the *major* pieces and are worth what they always were. The six
## added around them are minor by design - a ring is not a breastplate - and
## `Balance.GEAR_SLOT_WEIGHT` is where that is stated rather than being implied
## by whatever numbers happened to get authored.
enum Slot { WEAPON, ARMOUR, CHARM, HELMET, GLOVES, BOOTS, RING, AMULET }

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

## How far this weapon reaches, and how fast it swings, against the baseline.
##
## **Deliberately zero-sum: the product of the two is 1.** Working rule 7 keeps
## hero power on one capped scale - gear grants attribute points, never raw
## stats - and a weapon that simply reached further would be raw power wearing a
## different word. These two are not power. A maul reaches and is slow, a short
## blade is quick and must be close, and neither out-damages the other over a
## second; what changes is which fight each one wants. `weapon_variety_check`
## holds the product to 1, so this cannot quietly become a stat line.
@export_range(0.5, 2.0) var reach_scale: float = 1.0
@export_range(0.5, 2.0) var swing_scale: float = 1.0


## The player-facing name of a slot. Static so the interface can name a slot it
## has no piece for - an empty Boots row still has to say "Boots".
static func name_of_slot(which: int) -> String:
	match which:
		Slot.WEAPON:
			return "Weapon"
		Slot.ARMOUR:
			return "Armour"
		Slot.CHARM:
			return "Charm"
		Slot.HELMET:
			return "Helmet"
		Slot.GLOVES:
			return "Gloves"
		Slot.BOOTS:
			return "Boots"
		Slot.RING:
			return "Ring"
		_:
			return "Amulet"


func slot_name() -> String:
	return name_of_slot(slot)


func get_sprite_path() -> String:
	return GameData.derive_path("icons/ui", "ui_", id)
