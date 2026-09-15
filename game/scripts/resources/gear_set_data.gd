class_name GearSetData
extends GameData

## A matched set of gear, and what wearing enough of it is worth.
##
## **Owner brief, 2026-09-15:** *"set items similar to Diablo's style which grant
## extra bonuses at appropriate increments in wearing enough of the set pieces.
## A wide variety of sets that are perfect and polished for our game! Wearing a
## full set should have a visual vfx game juicy effect on players!"*
##
## **A set bonus moves a number `Modifiers` already resolves and nothing else.**
## That is the omen bound, the Road Card bound and the legendary-affix bound
## applied once more: the whole set lands in the same flat table a socketed relic
## feeds, so a tower asking for `tower_damage` gets one number and nothing
## downstream learns that sets exist. A tier that granted a *mechanic* would be a
## content system wearing an item's clothes, and the ten-act curve could not be
## read against it.
##
## **What a set costs is choice, and that is the honest answer to "extra".**
## Gear grants attribute points on the capped scale levelling shares (working
## rule 7), and a set changes none of that - every piece still grants exactly
## what its kind, rarity and level say. What the player gives up is the freedom
## to pick: six of eight slots locked to *particular kinds* is six slots where
## you cannot chase the attribute you wanted, the rarity you found, or the
## affixes you were hunting. A set is a different build rather than a better one.
##
## **Nothing is added to the save.** A piece is still `{kind, rarity, level,
## uid}`; whether it belongs to a set is a property of its *kind*, read from
## here. So gear found before sets existed belongs to one the moment it is read,
## there is no migration, and `SAVE_VERSION` did not move.
##
## **Rarity is deliberately not a member condition.** A Common piece of the
## Held Line still counts toward the Held Line. Sets that only assembled at the
## top rarity would be a second lottery on top of the drop tables, and the
## `exchange_check` argument applies - the thing to hunt should be the *match*,
## which the road can actually give you.

## The `GearData` ids that belong to this set. One per slot at most, or the set
## could never be completed - `gear_set_check` refuses a duplicate slot.
@export var members: Array[String] = []

## How many pieces each tier wants, ascending. `[2, 4]` is a two-step set.
@export var tier_counts: Array[int] = []
## The `Modifiers` key each tier adds to. Parallel to `tier_counts`.
@export var tier_effects: Array[String] = []
## What each tier adds. A fraction for the scaled keys, a whole number for the
## counted ones. Bounded by `Balance.GEAR_SET_CEILING`.
@export var tier_magnitudes: Array[float] = []
## What each tier says to the player. In data, because player-facing strings
## live in data (working rule 9).
@export var tier_lines: Array[String] = []

## The colour the full-set aura turns at the wearer's feet. Authored per set
## rather than derived from an effect key, because two sets that happen to move
## `tower_damage` are not the same set and should not look like it.
@export var aura_colour: Color = Color(0.92, 0.84, 0.55, 0.85)


## Whether this kind belongs to the set.
func has_member(kind_id: String) -> bool:
	return members.has(kind_id)


## How many tiers this set offers.
func tier_count() -> int:
	return mini(tier_counts.size(), mini(tier_effects.size(),
		mini(tier_magnitudes.size(), tier_lines.size())))


## Which tiers are active for this many matching pieces worn, as indices.
func tiers_at(worn: int) -> Array[int]:
	var out: Array[int] = []
	for tier: int in tier_count():
		if worn >= tier_counts[tier]:
			out.append(tier)
	return out


## Whether a magnitude at this tier is a whole count rather than a fraction.
## The same two keys the legendary affixes have to be careful of: `Tower` reads
## `chain_targets` with `int()` and `RunState` rounds `wave_foresight`, so a
## fraction there charges the player a set and hands out nothing.
func is_counted(tier: int) -> bool:
	if tier < 0 or tier >= tier_effects.size():
		return false
	return tier_effects[tier] == Modifiers.CHAIN_TARGETS \
		or tier_effects[tier] == Modifiers.WAVE_FORESIGHT
