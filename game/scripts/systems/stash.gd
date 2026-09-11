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
		"uid": new_uid(),
	}


# --- Identity -----------------------------------------------------------------
#
# **A stash index is not a name for a piece**, and trading is the first system
# that needed one.
#
# Indices shift the moment anything is removed - `drop_gear` exists to fix up
# the equipped map for exactly that reason. During a trade both stashes can move
# under the offer: a partner breaks a duplicate, a run ends and delivers a drop.
# An offer recorded as "index 7" is then an offer of whatever happens to be at
# index 7 when it settles, which is how a player ends up handing over the sword
# they were wearing.
#
# So a piece carries its own name. The offer is a list of those, the settlement
# resolves them back to positions at the moment it commits, and a name that no
# longer resolves aborts the trade rather than taking the nearest thing.
#
# Additive to the save, like `favourite` before it: a piece written before this
# has no `uid` and is given one when it loads, so `SAVE_VERSION` did not move.

## A name no other piece will share.
##
## Random rather than sequential, because two accounts assign these
## independently and a counter on each machine would hand out the same names.
##
## **Fifty-two bits, because a name has to survive the save file.** The save is
## JSON, and every number in JSON comes back as a double: anything past 2^53 is
## silently rounded on load. This was sixty-two bits, and a piece written as
## ...900427813 read back as ...900427264 - found by diffing a save either side
## of a tool run, not by anything failing. Fifty-two bits still leaves a
## collision between two stashes of a hundred and sixty vanishingly unlikely,
## and it is a number that means the same thing on both sides of a write.
##
## `randi` is a full unsigned 32 bits, so both halves are masked: the old shift
## also let the two draws overlap in bit 31 and reach the sign bit.
static func new_uid() -> int:
	return ((absi(randi()) & 0x7FFFFFFF) << 21) | (absi(randi()) & 0x1FFFFF)


## This piece's name, assigned in place if it has never had one.
static func uid(piece: Dictionary) -> int:
	if not piece.has("uid"):
		piece["uid"] = new_uid()
	return int(piece["uid"])


## Where a named piece sits in a stash, or -1.
static func index_of(pieces: Array, wanted_uid: int) -> int:
	for index: int in pieces.size():
		var piece := pieces[index] as Dictionary
		if piece != null and int(piece.get("uid", 0)) == wanted_uid:
			return index
	return -1


## Whether two pieces are the same gear, ignoring their names.
##
## The settlement asks this as well as the name, so a trade cannot be completed
## against a piece that was named correctly and then changed - upgraded a level,
## say - between the offer and the confirmation.
static func same_gear(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("kind", "")) == String(b.get("kind", "")) \
		and int(a.get("rarity", -1)) == int(b.get("rarity", -2)) \
		and int(a.get("level", -1)) == int(b.get("level", -2))


## Whether the player has marked this piece to be left alone.
##
## Owner request, 2026-09-02. The stash holds 160 and has two bulk-break buttons
## in it; the one thing those must never do is take the piece somebody was
## saving. Read through a function rather than the raw key so nothing has to
## remember that an unmarked piece has no key at all.
static func is_favourite(piece: Dictionary) -> bool:
	return bool(piece.get("favourite", false))


## Marks or unmarks a piece. Returns what it now is.
static func set_favourite(piece: Dictionary, wanted: bool) -> bool:
	if wanted:
		piece["favourite"] = true
	else:
		piece.erase("favourite")
	return wanted


## Whether a bulk sweep may take this piece.
##
## **One function, asked by the button and by the gate.** The rules were three
## conditions written inline in the stash screen, which is exactly the shape that
## cannot be tested - and the thing being decided is permanent destruction of a
## player's gear. Wornness stays with the caller because it is a question about
## an index rather than about a piece.
static func may_break(piece: Dictionary, rarity_ceiling: int) -> bool:
	if is_favourite(piece):
		return false
	if int(piece.get("rarity", 0)) > rarity_ceiling:
		return false
	# An upgraded piece is one somebody spent on. Never swept, marked or not.
	return int(piece.get("level", 1)) <= 1


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
	# The slot's own worth. A ring is not a breastplate, and this is where
	# that is stated rather than being implied by whichever numbers happened
	# to get authored.
	var worn: float = 1.0
	if kind.slot >= 0 and kind.slot < Balance.GEAR_SLOT_WEIGHT.size():
		worn = Balance.GEAR_SLOT_WEIGHT[kind.slot]
	var scaled: float = float(kind.base_points) * RARITY_POINTS[rarity] \
		* (1.0 + float(level - 1) * LEVEL_POINTS) * worn
	# Never zero. A minor slot grants less; it never grants nothing, or
	# wearing something would be indistinguishable from wearing nothing.
	return maxi(1, int(round(scaled)))


## How many attributes a hero has. Here rather than reached for through an
## autoload, because this class is deliberately checkable without a scene.
const ATTRIBUTE_COUNT: int = 4


## Every attribute this piece bonuses, and by how much.
##
## Returns one entry per bonus as `{"attribute": int, "points": int}`, the
## kind's own attribute first. A Worn piece has one, exactly as every piece did
## before affixes; an Oathbound has three.
##
## **Derived, never stored.** The secondaries come from the piece's own `uid` -
## the name it already carries so a trade can refer to it - so a piece is still
## `{kind, rarity, level, uid}` on disk. Nothing was added to the save, there is
## no migration to get wrong, and a piece that existed before affixes grows them
## the moment it is read. The alternative was a fourth field that every trade,
## every Ledger order and every round trip would have had to carry.
##
## **And derived arithmetically, not with an RNG.** `RunState.attribute` asks
## `MetaState.gear_attribute_points` on every call, and the hero asks that for
## movement, damage and mana several times a frame - so this runs a few hundred
## times a second with eight pieces worn. A `RandomNumberGenerator` per piece
## per call would have been an allocation in the hot path; a couple of integer
## operations is not, and it is exactly as deterministic.
##
## The *total* is `points()` and the split is authored in `Balance`, so this
## function cannot inflate a piece however the numbers move.
static func affixes(piece: Dictionary, kind: GearData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if kind == null:
		return out
	var budget: int = points(piece, kind)
	var rarity: int = clampi(int(piece.get("rarity", 0)), 0,
		Balance.GEAR_AFFIX_COUNT.size() - 1)
	# **Never more bonuses than the budget can pay for.** Every share has a
	# floor of one point - a bonus of nothing is not a bonus - so a piece worth
	# two points split three ways would have granted three, which is the exact
	# inflation this whole design exists to avoid. A cheap piece simply has
	# fewer bonuses; found by arithmetic before it ever ran.
	var wanted: int = clampi(mini(Balance.GEAR_AFFIX_COUNT[rarity], budget), 1,
		mini(Balance.GEAR_AFFIX_SPLIT.size(), ATTRIBUTE_COUNT))
	var split: Array = Balance.GEAR_AFFIX_SPLIT[wanted - 1]
	var primary: int = clampi(kind.attribute, 0, ATTRIBUTE_COUNT - 1)

	# The attributes this piece does *not* already bonus, in order, then drawn
	# from by index. Choosing by removal rather than by rejection means no loop
	# can spin, and the same name always draws the same hand.
	var pool: Array[int] = []
	for which: int in ATTRIBUTE_COUNT:
		if which != primary:
			pool.append(which)
	var draw: int = _mixed(uid(piece))
	var chosen: Array[int] = [primary]
	while chosen.size() < wanted and not pool.is_empty():
		var at: int = draw % pool.size()
		chosen.append(pool[at])
		pool.remove_at(at)
		draw /= maxi(pool.size(), 1)

	# Handed out smallest-first and the remainder given to the primary, so the
	# parts always sum to the budget however the fractions round. Without this a
	# three-way split quietly loses a point or gains one, and the totals the
	# gate compares would drift by rarity.
	var spent: int = 0
	var tail: Array[Dictionary] = []
	for index: int in range(chosen.size() - 1, 0, -1):
		var share: int = maxi(1, int(round(float(budget) * float(split[index]))))
		spent += share
		tail.push_front({"attribute": chosen[index], "points": share})
	out.append({"attribute": primary, "points": maxi(1, budget - spent)})
	out.append_array(tail)
	return out


## Stirs a name into something whose low digits are not its low digits.
##
## A uid is two random draws stitched together, so its bottom bits are already
## well distributed - but `% 3` on a raw id ties the second attribute to the
## bottom of the second draw, and the third to the same bits again. Knuth's
## multiplicative constant spreads the whole word before any of it is used, and
## the mask keeps the result positive so `%` cannot return a negative index.
static func _mixed(name: int) -> int:
	return absi((name * 2654435761) & 0x3FFFFFFF)


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
