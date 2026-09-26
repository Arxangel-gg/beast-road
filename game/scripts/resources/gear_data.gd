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

## The nine places a piece can be worn.
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
##
## **CAPE is appended, never inserted** (owner ruling, 2026-09-25: "capes should
## have stats"). Every `.tres` names its slot by number and `equipped` is keyed
## by it, so a member slipped in before AMULET would move every amulet in every
## save onto a slot it was never cut for - silently, because a number is always
## a legal slot. A cape is a minor slot, worth what gloves and boots are.
enum Slot { WEAPON, ARMOUR, CHARM, HELMET, GLOVES, BOOTS, RING, AMULET, CAPE }

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

## How a weapon is held on the Warden's body (owner ruling, 2026-09-25: the
## Warden is dressed by what they wear). Appended to, never inserted into -
## data names these by number.
##
## ONE_HAND is the right fist and the one-handed combo; TWO_HAND puts the left
## fist on the haft below it and plays the two-handed combo; PAIRED is a second
## of the same blade in the left fist. **A look and never a number**: the swing
## timings, reach and damage are the weapon's own, whichever grip draws it.
enum Grip { ONE_HAND, TWO_HAND, PAIRED }

@export var grip: Grip = Grip.ONE_HAND

## Which drawn class this kind wears as: an armour's `light`, `medium` or
## `heavy`, a cape's shape, a helmet's head dressing. A class with no art yet
## falls back to the nearest that has some (`WardenDress`), so a kind can name
## the class it belongs to before that class is drawn.
@export var look: String = ""

## A cape's own colour, laid over its drawn shape. Alpha zero leaves the shape
## as it was painted.
@export var look_tint: Color = Color(1.0, 1.0, 1.0, 0.0)


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
		Slot.CAPE:
			return "Cape"
		_:
			return "Amulet"


func slot_name() -> String:
	return name_of_slot(slot)


func get_sprite_path() -> String:
	return GameData.derive_path("icons/ui", "ui_", id)
