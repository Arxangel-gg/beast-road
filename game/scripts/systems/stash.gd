class_name Stash
extends RefCounted

## The rules for owned gear: rolling it, pricing it, upgrading it, breaking it.
##
## Pure functions over plain dictionaries, with no autoload reach, so the whole
## economy can be checked without a save file or a scene. `MetaState` owns the
## list; this owns what the numbers mean.
##
## ## Why gear grants attribute points
##
## A piece of gear adds hero *attribute points*, not raw damage or health. That
## keeps one number governing hero power — the same number levelling feeds — so
## a lucky drop cannot quietly out-scale the curve the campaign tiers are tuned
## against, and a player can compare a sword to two levels without arithmetic.
##
## ## Two currencies, and why
##
## Gold is a *run* currency: it buys towers, it is spent under pressure, and it
## resets. Marks are what the account keeps. Mixing them would mean either a
## player hoarding gold instead of defending, or a stash purchase competing with
## the wall about to be overrun — and neither decision belongs to the other.
##
## Shards are what broken gear becomes. They only buy upgrades, so the choice a
## duplicate poses is "sell it for marks or break it for shards", which is a
## real decision precisely because the two cannot be exchanged.

## Rarity names, in order. The index is stored, not the name.
const RARITY_NAMES: Array[String] = ["Worn", "Sound", "Fine", "Runed", "Oathbound"]

## Multiplier on a kind's base points, per rarity.
const RARITY_POINTS: Array[float] = [1.0, 1.35, 1.8, 2.4, 3.2]

## What each rarity is worth when sold, and yields when broken.
const RARITY_MARKS: Array[int] = [12, 26, 55, 120, 260]
const RARITY_SHARDS: Array[int] = [1, 2, 5, 11, 24]

## Levels a piece may be upgraded through, and what each level adds.
const MAX_LEVEL: int = 5
const LEVEL_POINTS: float = 0.28


## A fresh, unowned piece.
static func make(kind_id: String, rarity: int, level: int = 1) -> Dictionary:
	return {
		"kind": kind_id,
		"rarity": clampi(rarity, 0, RARITY_NAMES.size() - 1),
		"level": clampi(level, 1, MAX_LEVEL),
	}


## Rolls a piece for a tier, weighted toward the common.
##
## Rarity is drawn against a curve rather than a flat table so the top rarity
## stays an event. The tier shifts the curve rather than unlocking a rarity: a
## Hell drop is *more likely* to be Oathbound, and a Normal drop is never
## impossible, which keeps the first tier worth playing after the third opens.
static func roll(kinds: Array, tier_order: int, rng: RandomNumberGenerator) -> Dictionary:
	var eligible: Array = []
	var total: float = 0.0
	for kind: GearData in kinds:
		if kind.min_tier > tier_order:
			continue
		eligible.append(kind)
		total += maxf(kind.weight, 0.0)
	if eligible.is_empty() or total <= 0.0:
		return {}

	var target: float = rng.randf() * total
	var chosen: GearData = eligible[0]
	for kind: GearData in eligible:
		target -= maxf(kind.weight, 0.0)
		if target <= 0.0:
			chosen = kind
			break

	# Each step up is a fresh roll against the same odds, nudged by tier. Four
	# consecutive successes is what an Oathbound costs.
	var step: float = 0.30 + float(tier_order) * 0.09
	var rarity: int = 0
	while rarity < RARITY_NAMES.size() - 1 and rng.randf() < step:
		rarity += 1
	return make(chosen.id, rarity)


## Attribute points a piece grants.
static func points(piece: Dictionary, kind: GearData) -> int:
	if kind == null:
		return 0
	var rarity: int = clampi(int(piece.get("rarity", 0)), 0, RARITY_POINTS.size() - 1)
	var level: int = clampi(int(piece.get("level", 1)), 1, MAX_LEVEL)
	var scaled: float = float(kind.base_points) * RARITY_POINTS[rarity] \
		* (1.0 + float(level - 1) * LEVEL_POINTS)
	return maxi(1, int(round(scaled)))


static func rarity_name(piece: Dictionary) -> String:
	return RARITY_NAMES[clampi(int(piece.get("rarity", 0)), 0, RARITY_NAMES.size() - 1)]


## The colour a rarity reads as, anywhere it is drawn. Kept here rather than in
## whichever screen happens to need it first, so the stash list, the loot beam
## and the blade in the hero's hand cannot drift apart.
const RARITY_COLOURS: Array[Color] = [
	Color("b7ada0"),  # Worn
	Color("dfe4e8"),  # Sound
	Color("6fbf7d"),  # Fine
	Color("6f8fdf"),  # Runed
	Color("e0a94f"),  # Oathbound
]


static func rarity_colour(piece: Dictionary) -> Color:
	return RARITY_COLOURS[clampi(int(piece.get("rarity", 0)), 0, RARITY_COLOURS.size() - 1)]


## Marks paid for selling a piece. Levels are refunded at a loss, because an
## upgrade is a commitment: getting it all back would make upgrading free to
## undo and the decision meaningless.
static func sell_price(piece: Dictionary) -> int:
	var rarity: int = clampi(int(piece.get("rarity", 0)), 0, RARITY_MARKS.size() - 1)
	var level: int = clampi(int(piece.get("level", 1)), 1, MAX_LEVEL)
	return RARITY_MARKS[rarity] + int(round(float(level - 1) * float(RARITY_MARKS[rarity]) * 0.22))


## Shards yielded by breaking a piece.
static func salvage_yield(piece: Dictionary) -> int:
	var rarity: int = clampi(int(piece.get("rarity", 0)), 0, RARITY_SHARDS.size() - 1)
	var level: int = clampi(int(piece.get("level", 1)), 1, MAX_LEVEL)
	return RARITY_SHARDS[rarity] + (level - 1)


## What the next level costs, in shards and marks. Empty when already capped.
##
## Both, deliberately. Shards alone and a player with a full stash upgrades
## everything for free; marks alone and salvage has no purpose. Needing the two
## together is what makes "which piece do I break" a question worth asking.
static func upgrade_cost(piece: Dictionary) -> Dictionary:
	var level: int = clampi(int(piece.get("level", 1)), 1, MAX_LEVEL)
	if level >= MAX_LEVEL:
		return {}
	var rarity: int = clampi(int(piece.get("rarity", 0)), 0, RARITY_SHARDS.size() - 1)
	return {
		"shards": RARITY_SHARDS[rarity] * level + 2,
		"marks": int(round(float(RARITY_MARKS[rarity]) * 0.45 * float(level))),
	}


## Whether `candidate` beats `held` for the same slot, for the "new best" marker.
static func is_upgrade_over(candidate: Dictionary, held: Dictionary,
		kinds: Dictionary) -> bool:
	if held.is_empty():
		return true
	var a: GearData = kinds.get(String(candidate.get("kind", "")), null)
	var b: GearData = kinds.get(String(held.get("kind", "")), null)
	if a == null:
		return false
	if b == null:
		return true
	if a.slot != b.slot:
		return false
	return points(candidate, a) > points(held, b)
