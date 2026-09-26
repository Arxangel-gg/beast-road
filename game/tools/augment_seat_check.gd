extends Node

## **Every Warden drafts their own** (per-Warden augment hands, 2026-09-26,
## `docs/SKILL_TREE_REWORK_2026-09-26.md` §8.5, COOP_DESIGN §11).
##
##   godot --headless --path game res://tools/augment_seat_check.tscn
##
## In co-op phase A the host drafted one hand for the party and a guest never
## picked a card. Now the hand is split in company: a card that acts on one
## hero is that Warden's own, every other card is the party's board, every rank
## deals every seat a draft on its own stream, and a guest's choice is asked of
## the host by card id. What this holds:
##
## - **Alone, nothing splits** - the solo hand is the hand it always was.
## - **A split hand routes a card by what it acts on**, and both hands keep
##   their bounds.
## - **A partner reads its own seat's cards**, and this machine's Warden its own.
## - **Every seat drafts**, on its own stream, against its own hand.
## - **A guest's choice is the host's to make real**: by the peer it arrived on,
##   against that seat's own offer, and answered whole every time.
## - **A guest holds what it is told**, and **a front banks every seat**.
## - **The crossroad's card is the party's.**
##
## Run in one process with a guest seated on the party and `hands_split` forced,
## because what is under test is the host's bookkeeping; the wire is
## `coop_check`'s, and a real guest's screen is the two-process harness's.

const SEED: int = 919191
const EXPECTED_TESTS: int = 9
const GUEST_PEER: int = 7171

var _failures: PackedStringArray = []
var _finished: int = 0
var _run: Node = null
var _field: Battlefield = null
var _told: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset(false, SEED)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(_run)
	for _f: int in 16:
		await get_tree().process_frame
	_field = _run.get("battlefield") as Battlefield
	if _field != null and _field.hero != null:
		_field.hero.set_present(true)
	RunState.act = 4
	EventBus.augment_seat_told.connect(func(_slot: int, _packed: Dictionary) -> void:
		_told += 1)

	_test_alone_nothing_splits()
	_split_the_hand()
	_test_a_split_hand_routes_by_what_a_card_acts_on()
	_test_both_hands_keep_their_bounds()
	await _test_a_partner_reads_its_own_seat()
	_test_every_seat_drafts()
	_test_a_guest_choice_is_the_hosts()
	_test_the_crossroad_deals_the_partys()
	_test_a_front_banks_every_seat()
	_test_a_guest_holds_what_it_is_told()
	_check(_finished == EXPECTED_TESTS,
		"%d of %d tests reached their end - a runtime error aborted one, and every check it had not made is unmade"
			% [_finished, EXPECTED_TESTS])

	Coop.party().unseat(GUEST_PEER)
	Coop.party().unseat(1)
	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	_run = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	for problem: String in _failures:
		push_error("[augment-seats] FAIL: " + problem)
	if _failures.is_empty():
		print("[augment-seats] PASS - alone nothing splits; in company every Warden drafts their own, a card goes where it acts, a partner reads its own seat, a guest's choice is the host's, a front banks every seat")
	else:
		push_error("[augment-seats] FAIL - %d problem(s)" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)


func _split_the_hand() -> void:
	var party: CoopParty = Coop.party()
	var _host: int = party.seat(1, "Host")
	var _guest: int = party.seat(GUEST_PEER, "Guest")
	RunState.hands_split = true
	RunState.road_cards = []
	RunState.road_card_levels = {}
	RunState.augment_seats = {}


func _guest_slot() -> int:
	return Coop.party().slot_for_peer(GUEST_PEER)


# --- 1 ------------------------------------------------------------------------------

## **Alone, nothing splits.** A solo road's hand is one hand of every branch.
func _test_alone_nothing_splits() -> void:
	_check(not RunState.hands_split, "a road begun alone split its hand")
	RunState.road_cards = []
	RunState.road_card_levels = {}
	RunState.take_road_card("set_stance")
	RunState.take_road_card("whetstone_hour")
	_check(RunState.road_cards.has("set_stance") and RunState.road_cards.has("whetstone_hour"),
		"alone, a Warden card and a board card did not share the one hand: %s" % str(RunState.road_cards))
	_check(RunState.augment_seat(0).cards.is_empty(), "alone, a card went to a seat's own hand")
	RunState.road_cards = []
	RunState.road_card_levels = {}
	Modifiers.rebuild()
	_finished += 1


# --- 2 ------------------------------------------------------------------------------

## **A split hand routes a card by what it acts on.** One hero's numbers are that
## Warden's; the towers, the town, a keystone's rule, the shove and the enemy's
## own blows are the party's.
func _test_a_split_hand_routes_by_what_a_card_acts_on() -> void:
	var seat: AugmentSeat = RunState.augment_seat(_guest_slot())
	for id: String in ["set_stance", "whetstone_hour", "hunters_mark", "the_quiet_approach",
			"the_long_lever"]:
		var card: RoadCardData = ContentDB.road_card(id)
		_check(card != null, "the harness's card %s is not in the deck" % id)
		if card == null:
			continue
		RunState.take_card_for(seat, id)
		var own: bool = Augments.seat_keeps(card)
		_check(seat.cards.has(id) == own and RunState.road_cards.has(id) == not own,
			"%s (%s) went to the %s" % [id, card.effect_id,
				"seat" if seat.cards.has(id) else "board" if RunState.road_cards.has(id) else "nowhere"])
	_check(Augments.seat_keeps(ContentDB.road_card("set_stance")),
		"a Warden's damage card is not the Warden's own")
	_check(not Augments.seat_keeps(ContentDB.road_card("hunters_mark")),
		"a keystone was one Warden's rather than the party's")
	# This machine's own seat takes into its own hand, and the table reads it.
	var before: float = Modifiers.value(Modifiers.HERO_SPEED)
	RunState.take_road_card("loose_boots")
	_check(RunState.augment_seat(0).cards.has("loose_boots"), "the host's own Warden card went elsewhere")
	_check(Modifiers.value(Modifiers.HERO_SPEED) > before, "the host's own Warden card moved nothing")
	_check(RunState.holds_card("loose_boots") and RunState.card_level("loose_boots") == 1,
		"the screens cannot see the host's own card")
	_finished += 1


# --- 3 ------------------------------------------------------------------------------

## **Both hands keep their bounds**: a seat holds `AUGMENT_SEAT_HAND`, the board
## `ROAD_CARD_HAND`, one card a key and one keystone each, and a full hand takes
## a new key only by naming what it leaves.
func _test_both_hands_keep_their_bounds() -> void:
	var seat: AugmentSeat = RunState.augment_seat(_guest_slot())
	seat.cards = []
	seat.levels = {}
	var probes: Array[String] = []
	for key: String in Modifiers.WARDEN_KEYS:
		if key == Modifiers.KNOCKBACK:
			continue
		var probe := RoadCardData.new()
		probe.id = "probe_seat_%s" % key
		probe.effect_id = key
		probe.effect_magnitude = 0.05
		probe.branch = RoadCardData.Branch.WARDEN
		ContentDB.road_cards[probe.id] = probe
		probes.append(probe.id)
	for id: String in probes:
		RunState.take_card_for(seat, id)
	_check(seat.cards.size() == Balance.AUGMENT_SEAT_HAND,
		"a seat took %d cards of its own against a hand of %d" % [seat.cards.size(), Balance.AUGMENT_SEAT_HAND])
	var spare: String = ""
	for id: String in probes:
		if not seat.cards.has(id):
			spare = id
			break
	if not spare.is_empty():
		var left: String = RunState.take_card_for(seat, spare, "")
		_check(left.is_empty() and not seat.cards.has(spare), "a full seat took a new key without naming what it leaves")
		var drop: String = seat.cards[0]
		RunState.take_card_for(seat, spare, drop)
		_check(seat.cards.has(spare) and not seat.cards.has(drop) and seat.cards.size() == Balance.AUGMENT_SEAT_HAND,
			"a full seat did not trade the card it named: %s" % str(seat.cards))
	# Levels grow in the hand the card is in.
	var grown: String = seat.cards[0] if not seat.cards.is_empty() else ""
	RunState.take_card_for(seat, grown)
	_check(not grown.is_empty() and seat.card_level(grown) == 2, "taking a seat's held card did not level it")
	for id: String in probes:
		ContentDB.road_cards.erase(id)
	seat.cards = []
	seat.levels = {}
	Modifiers.rebuild()
	_finished += 1


# --- 4 ------------------------------------------------------------------------------

## **A partner reads its own seat**, and this machine's Warden its own: the
## host's damage card does not reach the partner, and the partner's speed card
## does not reach the host.
func _test_a_partner_reads_its_own_seat() -> void:
	var heroes: Node = _field.get_node_or_null("CoopHeroes") if _field != null else null
	var partner: Hero = heroes.call("spawn_partner") as Hero if heroes != null else null
	var mine: Hero = _field.hero if _field != null else null
	if partner == null or mine == null:
		_check(false, "the harness needs a partner and a Warden")
		_finished += 1
		return
	partner.party_slot = _guest_slot()
	partner.wear_sheet(WardenSheet.pack_mine())
	_check(partner.sheet != null and partner.sheet.slot == _guest_slot(),
		"the partner's sheet does not know its seat")
	var seat: AugmentSeat = RunState.augment_seat(_guest_slot())
	var own: AugmentSeat = RunState.augment_seat(0)
	own.cards = []
	own.levels = {}
	seat.cards = []
	seat.levels = {}
	Modifiers.rebuild()
	var mine_speed: float = mine.move_speed()
	var partner_speed: float = partner.move_speed()
	var shared_damage: float = WardenSheet.value_of(partner.sheet, Modifiers.HERO_DAMAGE)
	RunState.take_road_card("set_stance")
	RunState.take_card_for(seat, "loose_boots")
	for _f: int in 2:
		await get_tree().process_frame
	_check(Modifiers.value(Modifiers.HERO_DAMAGE) > shared_damage,
		"the host's own damage card did not reach the host")
	_check(is_equal_approx(WardenSheet.value_of(partner.sheet, Modifiers.HERO_DAMAGE), shared_damage),
		"the host's own damage card reached the partner (%.3f against %.3f)"
			% [WardenSheet.value_of(partner.sheet, Modifiers.HERO_DAMAGE), shared_damage])
	_check(partner.move_speed() > partner_speed,
		"the partner's own speed card did not reach the partner")
	_check(is_equal_approx(mine.move_speed(), mine_speed),
		"the partner's speed card reached this machine's Warden")
	own.cards = []
	own.levels = {}
	seat.cards = []
	seat.levels = {}
	Modifiers.rebuild()
	_finished += 1


# --- 5 ------------------------------------------------------------------------------

## **Every seat drafts, on its own stream, against its own hand.**
func _test_every_seat_drafts() -> void:
	var seat: AugmentSeat = RunState.augment_seat(_guest_slot())
	RunState.augment_queue = []
	RunState.augment_offer = []
	seat.queue = []
	seat.offer = []
	var told: int = _told
	RunState.queue_augment(Augments.SOURCE_RANK)
	_check(RunState.augment_queue.size() == 1, "a rank did not bank the host's draft")
	_check(seat.queue.size() == 1 and seat.offer.size() == Balance.ROAD_CARD_OFFER_COUNT,
		"a rank dealt the guest's seat %d cards from a queue of %d" % [seat.offer.size(), seat.queue.size()])
	_check(_told > told, "the guest was never told the draft it was dealt")
	for id: String in seat.offer:
		var card: RoadCardData = ContentDB.road_card(id)
		_check(Augments.may_deal(card, RunState.hand_of(seat), RunState.levels_of(seat), seat.banished),
			"the guest was dealt %s, which its own hand refuses" % id)
	# Its own stream: the host's next deal is not moved by the guest's.
	var host_dice: int = RunState.rng(Augments.STREAM).state
	RunState.deal_next_for(seat)
	RunState.reroll_for(seat)
	_check(RunState.rng(Augments.STREAM).state == host_dice,
		"dealing the guest's draft rolled the host's own dice")
	_finished += 1


# --- 6 ------------------------------------------------------------------------------

## **A guest's choice is the host's to make real**: by the peer it arrived on,
## against that seat's own offer, and answered whole every time - a refusal
## included, or a guest's screen would wait for ever.
func _test_a_guest_choice_is_the_hosts() -> void:
	var seat: AugmentSeat = RunState.augment_seat(_guest_slot())
	if seat.offer.is_empty():
		RunState.queue_augment(Augments.SOURCE_RANK)
	var offered: Array[String] = seat.offer.duplicate()
	_check(not offered.is_empty(), "the guest's seat holds no draft to choose from")
	if offered.is_empty():
		_finished += 1
		return
	var outside: String = ""
	for id: Variant in ContentDB.road_cards:
		if not offered.has(String(id)):
			outside = String(id)
			break
	var told: int = _told
	var hand: Array[String] = RunState.hand_of(seat)
	EventBus.coop_request_received.emit(CoopRelay.Request.AUGMENT_CHOICE, ["take", outside, ""], GUEST_PEER)
	_check(RunState.hand_of(seat) == hand, "a guest took %s, which it was never offered" % outside)
	_check(_told > told, "a refused choice was not answered, so the guest's screen would wait for ever")
	EventBus.coop_request_received.emit(CoopRelay.Request.AUGMENT_CHOICE, ["take", offered[0], ""], 9999)
	_check(RunState.hand_of(seat) == hand, "an unseated peer took a card on the guest's draft")
	# A reroll spends one and deals again; a banish takes a card out of the deck.
	var rerolls: int = seat.rerolls
	EventBus.coop_request_received.emit(CoopRelay.Request.AUGMENT_CHOICE, ["reroll", "", ""], GUEST_PEER)
	_check(seat.rerolls == rerolls - 1, "a guest's reroll spent %d" % (rerolls - seat.rerolls))
	var banished: String = seat.offer[0] if not seat.offer.is_empty() else ""
	EventBus.coop_request_received.emit(CoopRelay.Request.AUGMENT_CHOICE, ["banish", banished, ""], GUEST_PEER)
	_check(banished.is_empty() or seat.banished.has(banished), "a guest's banish did not take %s out" % banished)
	_check(not RunState.augment_banished.has(banished), "a guest's banish reached the host's own deck")
	# And a take lands in the right hand and closes that seat's draft.
	var chosen: String = seat.offer[0] if not seat.offer.is_empty() else ""
	var queued: int = seat.queue.size()
	EventBus.coop_request_received.emit(CoopRelay.Request.AUGMENT_CHOICE, ["take", chosen, ""], GUEST_PEER)
	var card: RoadCardData = ContentDB.road_card(chosen)
	_check(card != null and (seat.cards.has(chosen) if Augments.seat_keeps(card) else RunState.road_cards.has(chosen)),
		"a guest's choice of %s landed in neither hand" % chosen)
	_check(seat.queue.size() == queued - 1, "a guest's take did not close its draft")
	_finished += 1


# --- 7 ------------------------------------------------------------------------------

## **The crossroad's card is the party's**: a fork the whole party chose at never
## deals one Warden's card.
func _test_the_crossroad_deals_the_partys() -> void:
	for attempt: int in 40:
		RunState.act = 1 + attempt % Balance.ACT_COUNT
		for id: String in RoadCardData.offer(RunState.road_cards, RunState.act, Balance.ROAD_CARD_OFFER_COUNT):
			_check(not Augments.seat_keeps(ContentDB.road_card(id)),
				"a crossroad dealt %s, one Warden's card, to the party" % id)
	RunState.act = 4
	_finished += 1


# --- 8 ------------------------------------------------------------------------------

## **A front banks every seat**: the guest's cards and drafts, the host's own
## hand, and the hand's shape.
func _test_a_front_banks_every_seat() -> void:
	var seat: AugmentSeat = RunState.augment_seat(_guest_slot())
	seat.cards = ["loose_boots"]
	seat.levels = {"loose_boots": 3}
	RunState.augment_seat(0).cards = ["set_stance"]
	RunState.augment_seat(0).levels = {"set_stance": 2}
	var offer: Array[String] = seat.offer.duplicate()
	var queued: int = seat.queue.size()
	# A front is banked at a crossroad, which is never before the first wave:
	# `Expedition.is_readable` refuses wave nought, and the first cut of this
	# test read that refusal as the seats failing to come back.
	RunState.wave_number = maxi(RunState.wave_number, 3)
	var snapshot: Dictionary = Expedition.compose(_field)
	RunState.reset(false, SEED)
	_check(not RunState.hands_split and RunState.augment_seats.is_empty(), "a reset kept a split hand")
	_check(Expedition.apply(snapshot), "the harness's front did not apply at all")
	var back: AugmentSeat = RunState.augment_seat(_guest_slot())
	_check(RunState.hands_split, "a front banked in company came back unsplit")
	_check(back.card_level("loose_boots") == 3 and back.offer == offer and back.queue.size() == queued,
		"the guest's seat came back as %s" % str(back.pack()))
	_check(RunState.augment_seat(0).card_level("set_stance") == 2, "the host's own hand did not come back")
	_finished += 1


# --- 9 ------------------------------------------------------------------------------

## **A guest holds what it is told**: its seat, whole, as its own - the cards in
## its table, the draft on its screen, and nothing of anybody else's.
func _test_a_guest_holds_what_it_is_told() -> void:
	var told := AugmentSeat.new(_guest_slot())
	told.cards = ["loose_boots"]
	told.levels = {"loose_boots": 2}
	told.offer = ["set_stance", "second_wind", "short_rations"]
	told.source = Augments.SOURCE_RANK
	told.queue = [{"source": Augments.SOURCE_RANK, "floor": 0}]
	told.rerolls = 5
	var before: float = Modifiers.value(Modifiers.HERO_SPEED)
	RunState.augment_seat(0).cards = []
	RunState.augment_seat(0).levels = {}
	Modifiers.rebuild()
	before = Modifiers.value(Modifiers.HERO_SPEED)
	RunState.adopt_augment_seat(told.pack())
	_check(RunState.augment_offer == told.offer and RunState.augment_rerolls == 5
		and RunState.augments_waiting() == 1, "the guest does not hold the draft it was told")
	_check(RunState.card_level("loose_boots") == 2 and Modifiers.value(Modifiers.HERO_SPEED) > before,
		"the guest's own card is not in its table")
	# A told seat is cleaned: a card this build lacks, a level past the card's.
	var dirty: Dictionary = told.pack()
	dirty["cards"] = ["no_such_card", "loose_boots"]
	dirty["levels"] = [1, 99]
	RunState.adopt_augment_seat(dirty)
	_check(RunState.augment_seat(0).cards == ["loose_boots"]
		and RunState.card_level("loose_boots") == ContentDB.road_card("loose_boots").max_level(),
		"a told seat was not cleaned: %s" % str(RunState.augment_seat(0).pack()))
	RunState.reset(false, SEED)
	_finished += 1


func _check(condition: bool, why: String) -> void:
	if not condition:
		_failures.append(why)
