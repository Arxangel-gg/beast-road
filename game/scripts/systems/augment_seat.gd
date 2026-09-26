class_name AugmentSeat
extends RefCounted

## **One Warden's draft, and in co-op one Warden's own hand** (2026-09-26,
## `docs/SKILL_TREE_REWORK_2026-09-26.md` §8.5, COOP_DESIGN §11).
##
## Alone, a road has one of these - this machine's - and it is what the
## `RunState.augment_*` fields have always been: they forward to it, so every
## caller that read them reads the same thing. In co-op the host keeps one more
## for every guest seat, dealt on that seat's own stream, and every rank deals
## every seat a draft.
##
## **The hand is split in co-op, by what a card acts on.** A card whose key is
## read per hero (`Augments.seat_keeps`) - damage, health, speed, dash, mana,
## spell power, companion damage - is this Warden's and lives in `cards`. Every
## other card acts on the shared world - the towers, the town, the purse, a
## keystone's rule - and lives in the party's board hand, `RunState.road_cards`.
## Alone, nothing is split and every card is in `road_cards`, as it always was.

var slot: int = 1
## The seat's own cards, in co-op. Empty alone.
var cards: Array[String] = []
var levels: Dictionary = {}
## Drafts banked and not yet opened, oldest first.
var queue: Array[Dictionary] = []
var offer: Array[String] = []
var source: String = ""
var rerolls: int = 0
var banishes: int = 0
var banished: Array[String] = []
var luck: int = 0
## Tags the Warden's learned Disciplines carry, for the deck's lean. This
## machine's own seat reads its account instead; a guest's seat is told them
## with its sheet (`CoopHeroes`).
var learned_tags: Array[String] = []


func _init(seat_slot: int = 1) -> void:
	slot = seat_slot
	rerolls = Balance.AUGMENT_REROLLS_START
	banishes = Balance.AUGMENT_BANISHES_START


func card_level(card_id: String) -> int:
	if not cards.has(card_id):
		return 0
	return maxi(1, int(levels.get(card_id, 1)))


## The seat as plain data, for a banked front and for the wire.
func pack() -> Dictionary:
	var packed_queue: Array = []
	for entry: Dictionary in queue:
		packed_queue.append([String(entry.get("source", "")), int(entry.get("floor", 0))])
	var packed_levels: Array = []
	for id: String in cards:
		packed_levels.append(card_level(id))
	return {
		"slot": slot, "cards": cards.duplicate(), "levels": packed_levels,
		"queue": packed_queue, "offer": offer.duplicate(), "source": source,
		"rerolls": rerolls, "banishes": banishes, "banished": banished.duplicate(),
		"luck": luck,
	}


## Read back, dropping anything this build does not have: a banked front and a
## host's word are both data from outside this process.
static func unpack(data: Variant) -> AugmentSeat:
	var given: Dictionary = data if data is Dictionary else {}
	var seat := AugmentSeat.new(clampi(int(given.get("slot", 1)), 1, Balance.COOP_MAX_PLAYERS))
	var ids: Array = given.get("cards", []) if given.get("cards", []) is Array else []
	var packed_levels: Array = given.get("levels", []) if given.get("levels", []) is Array else []
	for index: int in ids.size():
		var id: String = String(ids[index]) if ids[index] is String else ""
		var card: RoadCardData = ContentDB.road_card(id)
		if card == null or seat.cards.has(id) or seat.cards.size() >= Balance.AUGMENT_SEAT_HAND:
			continue
		seat.cards.append(id)
		var level: int = int(packed_levels[index]) if index < packed_levels.size() \
			and (packed_levels[index] is int or packed_levels[index] is float) else 1
		seat.levels[id] = clampi(level, 1, card.max_level())
	var raw_queue: Array = given.get("queue", []) if given.get("queue", []) is Array else []
	for entry: Variant in raw_queue:
		if entry is Array and (entry as Array).size() >= 2:
			seat.queue.append({"source": String((entry as Array)[0]),
				"floor": clampi(int((entry as Array)[1]), 0, RoadCardData.Rarity.size() - 1)})
	var raw_offer: Array = given.get("offer", []) if given.get("offer", []) is Array else []
	for id: Variant in raw_offer:
		if id is String and ContentDB.road_card(String(id)) != null:
			seat.offer.append(String(id))
	seat.source = String(given.get("source", "")) if given.get("source", "") is String else ""
	seat.rerolls = clampi(int(given.get("rerolls", Balance.AUGMENT_REROLLS_START)), 0, Balance.AUGMENT_REROLLS_MAX)
	seat.banishes = maxi(int(given.get("banishes", Balance.AUGMENT_BANISHES_START)), 0)
	var raw_banished: Array = given.get("banished", []) if given.get("banished", []) is Array else []
	for id: Variant in raw_banished:
		if id is String and ContentDB.road_card(String(id)) != null:
			seat.banished.append(String(id))
	seat.luck = clampi(int(given.get("luck", 0)), 0, Balance.AUGMENT_LUCK_CAP)
	return seat
