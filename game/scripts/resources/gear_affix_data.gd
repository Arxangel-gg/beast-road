class_name GearAffixData
extends GameData

## A legendary affix: the one thing a rare piece of gear does beyond its
## attribute points (owner brief, 2026-09-12: "legendary gear with affixes
## similar to Diablo").
##
## **An affix moves a number `Modifiers` already resolves, and nothing else.**
## That is the omen bound and the Road Card bound applied to gear: a piece
## "of Embers" adds to `tower_damage` exactly as a socketed relic does, so
## nothing downstream learns that gear can carry effects, and the curve the
## acts are tuned against can be read with the affixes in it. An affix that
## added a *mechanic* would be a content system wearing an item's clothes.
##
## **Small on purpose.** Attribute points are the capped scale gear is
## measured on (working rule 7). An affix is a flavour of that piece rather
## than a second scale beside it: a few percent, never a multiplier that makes
## the hunt for one the whole game. `gear_affix_check` holds the ceiling.
##
## **Rolled from the piece's own name.** A piece is still `{kind, rarity,
## level, uid}` on disk; which affixes it wears is arithmetic on its uid, the
## same way its attribute bonuses are - no save change, no migration, and a
## piece from before affixes wears them the moment it is read.

## The `Modifiers` key this affix adds to.
@export var effect_id: String = ""
## What it adds. A fraction for the scaled keys; a whole number for the
## counted ones (`chain_targets`, `wave_foresight`).
@export var magnitude: float = 0.05
## The lowest rarity index (into `Stash.RARITY_NAMES`) that may carry it.
@export_range(0, 6) var min_rarity: int = 3
## Which slots may carry it, as `GearData.Slot` values. Empty means any.
@export var slots: Array[int] = []
@export_range(0.0, 10.0) var weight: float = 1.0


## Whether the magnitude is a whole count rather than a fraction.
func is_counted() -> bool:
	return effect_id == "chain_targets" or effect_id == "wave_foresight"


## The line a screen shows: "+6% tower damage" or "+1 chain target".
func line() -> String:
	if is_counted():
		return description % ("%d" % int(round(magnitude)))
	return description % ("%d%%" % int(round(absf(magnitude) * 100.0)))
