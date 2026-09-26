class_name Augments
extends RefCounted

## **The augment draft** (owner request, 2026-09-26;
## `docs/SKILL_TREE_REWORK_2026-09-26.md` section 8).
##
## Road Cards became augments: one deck and one hand, dealt on every road rank
## and on the road's other rewards - a boss, a camp, a raid, a rift, a legend -
## with a Tempering every few waves survived. This is the one place that decides
## what a draft deals, so a source is a name and a floor and nothing else.
##
## **Weighted, never shuffled.** A card's chance is its rarity's weight, lifted
## by the luck clean waves banked, by the tags it shares with what the Warden
## already holds, and toward the next level of a card in the hand. That is what
## lets a player build on purpose - the answer to "Blackjack against a cheating
## AI" - while the rare thing stays rare.
##
## **The bound is the Road Card bound**: a card moves one number `Modifiers`
## already resolves, and nothing here reaches past the hand.
##
## Dealt on the "augments" stream, which only the host draws on. The crossroad's
## draft keeps its own shuffle on "road_cards" (`RoadCardData.offer`), because
## both machines deal that one from the seed.

const SOURCE_RANK: String = "rank"
const SOURCE_BOSS: String = "boss"
const SOURCE_CAMP: String = "camp"
const SOURCE_RAID: String = "raid"
const SOURCE_RIFT: String = "rift"
const SOURCE_MYTHIC: String = "mythic"
const SOURCE_TEMPERING: String = "tempering"

const STREAM: String = "augments"

## The most shared tags a card is lifted for: a card sharing everything with a
## deep build must not crowd the rest of the deck out of every draft.
const LEAN_TAGS_MAX: int = 3


## The rarity floor a source deals at, by `RoadCardData.Rarity`.
static func floor_for(source: String) -> int:
	match source:
		SOURCE_BOSS:
			return Balance.AUGMENT_FLOOR_BOSS
		SOURCE_CAMP:
			return Balance.AUGMENT_FLOOR_CAMP
		SOURCE_RAID:
			return Balance.AUGMENT_FLOOR_RAID
		SOURCE_RIFT:
			return Balance.AUGMENT_FLOOR_RIFT
		SOURCE_MYTHIC:
			return Balance.AUGMENT_FLOOR_MYTHIC
	return Balance.AUGMENT_FLOOR_RANK


## **Whether a card may be dealt at all**, and the one rule for it - asked by
## every draft, the crossroad's included.
##
## A held card only while it can still grow. A card for a key the hand already
## holds only as an upgrade: a lower rarity would be a card that makes the hand
## worse the moment it is taken. And a banished card never.
static func may_deal(card: RoadCardData, hand: Array, levels: Dictionary,
		banished: Array) -> bool:
	if card == null or banished.has(card.id):
		return false
	if card.branch_needs > 0 and branch_depth(hand, int(card.branch)) < card.branch_needs:
		return false
	if hand.has(card.id):
		return card.levels() and _level_of(card.id, levels) < card.max_level()
	if card.keystone:
		return true
	for held: Variant in hand:
		var other: RoadCardData = ContentDB.road_card(String(held))
		if other != null and not other.keystone and other.effect_id == card.effect_id:
			return card.rarity > other.rarity
	return true


## How many cards of `branch` the hand holds, keystones not counted - a keystone
## is what a branch opens, never part of what opens it.
static func branch_depth(hand: Array, branch: int) -> int:
	var depth: int = 0
	for held: Variant in hand:
		var card: RoadCardData = ContentDB.road_card(String(held))
		if card != null and not card.keystone and int(card.branch) == branch:
			depth += 1
	return depth


## The cards a draft may deal from, sorted by id so a seed deals the same deck
## on every machine - `ContentDB.road_cards` is a dictionary and its order is an
## implementation detail.
static func candidates(hand: Array, levels: Dictionary, act: int,
		banished: Array) -> Array[String]:
	var pool: Array[String] = []
	for id_value: Variant in ContentDB.road_cards:
		var card: RoadCardData = ContentDB.road_card(String(id_value))
		if card == null or card.first_act > act:
			continue
		if may_deal(card, hand, levels, banished):
			pool.append(card.id)
	pool.sort()
	return pool


## **How likely a card is to be dealt.**
static func weight(card: RoadCardData, hand: Array, luck: int, lean: Array) -> float:
	var weights: Array[float] = Balance.AUGMENT_RARITY_WEIGHTS
	var rarity: int = int(card.rarity)
	var value: float = weights[clampi(rarity, 0, weights.size() - 1)]
	# Luck lifts every step above Common by the same share, so it moves the
	# odds toward the rare end without ever making a Common impossible.
	value *= 1.0 + Balance.AUGMENT_LUCK_PER_CLEAN_WAVE * float(maxi(luck, 0)) * float(rarity)
	if hand.has(card.id):
		value *= Balance.AUGMENT_HELD_WEIGHT
	if card.keystone:
		value *= Balance.AUGMENT_KEYSTONE_WEIGHT
	var shared: int = 0
	for tag: String in card.tags:
		if lean.has(tag):
			shared += 1
	value *= 1.0 + Balance.AUGMENT_LEAN_PER_TAG * float(mini(shared, LEAN_TAGS_MAX))
	return value


## **Deals `count` cards on `dice`**, at `floor` or above where the deck holds
## enough, falling a rarity at a time where it does not.
##
## `exclude` is what a reroll wants to see something other than; it is honoured
## where the deck is deep enough and dropped where it is not, so a thin deck
## deals the same cards again rather than nothing. Two cards on one key are
## never dealt together, and never two keystones.
static func deal(dice: RandomNumberGenerator, count: int, floor: int, hand: Array,
		levels: Dictionary, act: int, banished: Array, luck: int, lean: Array,
		exclude: Array = []) -> Array[String]:
	if count <= 0:
		return []
	var deck: Array[String] = candidates(hand, levels, act, banished)
	var fresh: Array[String] = deck.filter(func(id: String) -> bool:
		return not exclude.has(id))
	if _distinct_keys(fresh) >= count:
		deck = fresh
	var at: int = clampi(floor, 0, RoadCardData.Rarity.size() - 1)
	var pool: Array[String] = _at_or_above(deck, at)
	while _distinct_keys(pool) < count and at > 0:
		at -= 1
		pool = _at_or_above(deck, at)
	var dealt: Array[String] = []
	while dealt.size() < count and not pool.is_empty():
		var total: float = 0.0
		var weights: Array[float] = []
		for id: String in pool:
			var w: float = weight(ContentDB.road_card(id), hand, luck, lean)
			weights.append(w)
			total += w
		var roll: float = dice.randf() * total
		var chosen: int = pool.size() - 1
		for index: int in pool.size():
			roll -= weights[index]
			if roll < 0.0:
				chosen = index
				break
		var card: RoadCardData = ContentDB.road_card(pool[chosen])
		dealt.append(card.id)
		pool = pool.filter(func(id: String) -> bool:
			var other: RoadCardData = ContentDB.road_card(id)
			if other.id == card.id:
				return false
			if card.keystone:
				return not other.keystone
			return other.keystone or other.effect_id != card.effect_id)
	return dealt


## **What a source deals now**, on the run's own state.
static func deal_for(source: String, floor: int, exclude: Array = [],
		count: int = Balance.ROAD_CARD_OFFER_COUNT, seat: AugmentSeat = null) -> Array[String]:
	var who: AugmentSeat = seat if seat != null else RunState.augment_seat(0)
	# This machine's own seat deals on the stream a draft always used, so a solo
	# road is dealt exactly as it was; a guest's seat on a stream of its own.
	var dice: RandomNumberGenerator = RunState.rng(STREAM) if who == RunState.augment_seat(0) \
		else RunState.rng("%s:%d" % [STREAM, who.slot])
	var hand: Array[String] = RunState.hand_of(who)
	var levels: Dictionary = RunState.levels_of(who)
	if source == SOURCE_TEMPERING:
		return temper(dice, hand, levels, count, exclude)
	return deal(dice, count, floor, hand, levels, RunState.act, who.banished, who.luck,
		RunState.augment_lean_tags(who), exclude)


## **Whether a card is one Warden's rather than the party's**, when a hand is
## split in co-op: a card whose key is read per hero and nowhere else. Every
## keystone re-routes a rule of the shared road, and the shove and the enemy's
## own damage are read by the towers and the bodies as well as the hero, so all
## of those are the party's.
static func seat_keeps(card: RoadCardData) -> bool:
	return card != null and not card.keystone \
		and Modifiers.WARDEN_KEYS.has(card.effect_id) \
		and card.effect_id != Modifiers.KNOCKBACK


## **A Tempering deals from the hand**: the held cards that can still grow, as
## many as a draft holds, and the player's choice among them gains a level.
static func temper(dice: RandomNumberGenerator, hand: Array, levels: Dictionary,
		count: int, exclude: Array = []) -> Array[String]:
	var growing: Array[String] = []
	for held: Variant in hand:
		var card: RoadCardData = ContentDB.road_card(String(held))
		if card != null and card.levels() and _level_of(card.id, levels) < card.max_level():
			growing.append(card.id)
	growing.sort()
	var fresh: Array[String] = growing.filter(func(id: String) -> bool:
		return not exclude.has(id))
	if fresh.size() >= mini(count, growing.size()) and not fresh.is_empty():
		growing = fresh
	var dealt: Array[String] = []
	while dealt.size() < count and not growing.is_empty():
		dealt.append(growing.pop_at(dice.randi() % growing.size()))
	return dealt


static func _at_or_above(deck: Array[String], rarity: int) -> Array[String]:
	return deck.filter(func(id: String) -> bool:
		return int(ContentDB.road_card(id).rarity) >= rarity)


## How many cards a deck could deal together: one a key, and one keystone.
static func _distinct_keys(deck: Array[String]) -> int:
	var keys: Dictionary = {}
	for id: String in deck:
		var card: RoadCardData = ContentDB.road_card(id)
		keys["keystone" if card.keystone else card.effect_id] = true
	return keys.size()


static func _level_of(id: String, levels: Dictionary) -> int:
	return maxi(1, int(levels.get(id, 1)))
