extends Node

## **Augments** (owner request, 2026-09-26; `docs/SKILL_TREE_REWORK_2026-09-26.md`
## section 8): a draft on every road rank and on the road's other rewards, cards
## that level I to V, and the tools against luck.
##
## Every door is driven rather than read. The cards level through
## `take_road_card` and the table reads the level; the rank is earned by a real
## kill on the real field; the deal is measured over thousands of draws rather
## than asserted; the draft is opened by the run itself at a breather, holds the
## clock, and is taken by pressing the card a player presses.

var _failures: int = 0
var _checks: int = 0
## Every test stamps this as its last line, so one that aborts on a runtime
## error - which stops that function and nothing else - cannot pass by omission.
var _finished: int = 0
const EXPECTED_TESTS: int = 20
var _run: Run = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260926)
	_test_cards_level()
	_test_a_better_card_keeps_the_levels()
	_test_the_road_rank()
	_test_the_deal()
	_test_the_draft()
	_test_the_tempering()
	_test_the_sources_are_wired()
	_test_a_front_banks_the_draft()
	_test_a_fresh_road_deals_a_fresh_draft()
	_test_the_party_holds_one_hand()
	_test_an_act_start_banks_the_road()
	_test_the_ledger_names_every_blow()
	_test_a_branch_opens_its_keystones()
	_test_every_key_is_read()

	RunState.reset(false, 20260926)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	if _field == null:
		_check(false, "the harness needs a battlefield")
	else:
		if _field.town != null and _field.town.health != null:
			_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
		await _test_a_kill_pays_the_rank()
		await _test_the_breather_opens_the_draft()
		await _test_later_waits_for_the_next_breather()
		await _test_at_once_holds_the_road()
		await _test_the_strip_opens_a_draft()
		_test_the_new_keys_reach_their_readers()

	MetaState.settings[UserSettings.AUGMENT_AT_ONCE_KEY] = false
	RunState.reset(false, 20260926)
	Modifiers.rebuild()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	GameDirector.run_active = false
	MetaState.resume_saves()
	_check(_finished == EXPECTED_TESTS,
		"only %d of %d tests ran to their end" % [_finished, EXPECTED_TESTS])
	if _failures == 0:
		print(("[augments] PASS - %d checks: cards level and the table reads the level, "
			+ "the rank deals drafts, the deal is weighted and bounded, and the draft "
			+ "opens, holds the clock and is taken the way a player takes it") % _checks)
	else:
		push_error("[augments] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	printerr("[augments] FAIL: %s" % why)


## Hold exactly these cards, each at level one, and rebuild the table.
func _hold(ids: Array) -> void:
	var hand: Array[String] = []
	for id: Variant in ids:
		hand.append(String(id))
	RunState.road_cards = hand
	RunState.road_card_levels = {}
	Modifiers.rebuild()


func _sorted_cards() -> Array[RoadCardData]:
	var out: Array[RoadCardData] = []
	var ids: Array = ContentDB.road_cards.keys()
	ids.sort()
	for id: Variant in ids:
		out.append(ContentDB.road_card(String(id)))
	return out


func _first(test: Callable) -> RoadCardData:
	for card: RoadCardData in _sorted_cards():
		if test.call(card):
			return card
	return null


# --- The cards ---------------------------------------------------------------------

## **Taking a held card levels it**, and the table reads the level.
func _test_cards_level() -> void:
	for card: RoadCardData in _sorted_cards():
		if not card.levels():
			_check(card.max_level() == 1, "%s moves a whole number or is a keystone, and levels" % card.id)
			continue
		_check(card.max_level() == Balance.AUGMENT_MAX_LEVEL, "%s levels to %d" % [card.id, card.max_level()])
		_check(is_equal_approx(card.magnitude_at(1), card.effect_magnitude),
			"%s at level one is not the card as authored" % card.id)
		var ceiling: float = maxf(absf(card.effect_magnitude), minf(
			Balance.AUGMENT_LEVELLED_COST_CEILING if card.effect_magnitude < 0.0
				else Balance.AUGMENT_LEVELLED_CEILING,
			float(Balance.AUGMENT_KEY_CEILING.get(card.effect_id, 1.0))))
		_check(ceiling <= Balance.ROAD_CARD_MAX_MAGNITUDE + 0.0001,
			"%s may grow past the single-card bound" % card.id)
		var last: float = 0.0
		for level: int in range(1, card.max_level() + 1):
			var value: float = absf(card.magnitude_at(level))
			_check(value >= last - 0.0001, "%s is worth less at level %d" % [card.id, level])
			_check(value <= ceiling + 0.0001,
				"%s at level %d moves %.2f, past its %.2f ceiling" % [card.id, level, value, ceiling])
			last = value
		_check(absf(card.magnitude_at(card.max_level())) > absf(card.effect_magnitude),
			"%s grows nothing across five levels" % card.id)

	var grower: RoadCardData = _first(func(c: RoadCardData) -> bool: return c.levels())
	_hold([])
	RunState.take_road_card(grower.id)
	for level: int in range(1, Balance.AUGMENT_MAX_LEVEL + 1):
		_check(RunState.card_level(grower.id) == level,
			"%s should be at level %d, is at %d" % [grower.id, level, RunState.card_level(grower.id)])
		_check(is_equal_approx(Modifiers.value(grower.effect_id), grower.magnitude_at(level)),
			"%s at level %d reads %.3f in the table, not %.3f" % [grower.id, level,
				Modifiers.value(grower.effect_id), grower.magnitude_at(level)])
		RunState.take_road_card(grower.id)
	_check(RunState.card_level(grower.id) == Balance.AUGMENT_MAX_LEVEL,
		"a card at its last level grew again")
	_check(RunState.road_cards.size() == 1, "levelling a card added a second copy of it")

	var whole: RoadCardData = _first(func(c: RoadCardData) -> bool:
		return not c.keystone and not c.levels())
	if whole != null:
		_hold([])
		RunState.take_road_card(whole.id)
		RunState.take_road_card(whole.id)
		_check(RunState.card_level(whole.id) == 1,
			"%s moves a whole number and was levelled - a fraction of a chain target is silently zero" % whole.id)
	_hold([])
	_finished += 1


## **A better card for a key already held keeps the levels the old one grew.**
func _test_a_better_card_keeps_the_levels() -> void:
	var low: RoadCardData = null
	var high: RoadCardData = null
	for card: RoadCardData in _sorted_cards():
		if not card.levels():
			continue
		for other: RoadCardData in _sorted_cards():
			if other.levels() and other.effect_id == card.effect_id and other.rarity > card.rarity:
				low = card
				high = other
				break
		if low != null:
			break
	_check(low != null, "no key has two rarities, so an upgrade cannot be tested")
	if low == null:
		return
	_hold([])
	RunState.take_road_card(low.id)
	RunState.take_road_card(low.id)
	RunState.take_road_card(low.id)
	var went: String = RunState.take_road_card(high.id)
	_check(went == low.id and RunState.road_cards == [high.id],
		"the better card did not replace the lesser: %s" % str(RunState.road_cards))
	_check(RunState.card_level(high.id) == 3,
		"taking %s over %s at level III left it at level %d" % [high.id, low.id, RunState.card_level(high.id)])
	_check(is_equal_approx(Modifiers.value(high.effect_id), high.magnitude_at(3)),
		"the inherited level did not reach the table")
	_check(not RunState.road_card_levels.has(low.id), "the card that left kept its level entry")
	# And the draft never offers the lesser card while the better is held.
	var dice := RandomNumberGenerator.new()
	dice.seed = 11
	for _i: int in 400:
		var dealt: Array[String] = Augments.deal(dice, 3, 0, RunState.road_cards,
			RunState.road_card_levels, Balance.ACT_COUNT, [], 0, [])
		_check(not dealt.has(low.id), "%s was dealt while %s is held - a card that makes the hand worse" % [low.id, high.id])
	_hold([])
	_finished += 1


# --- The rank ----------------------------------------------------------------------

func _test_the_road_rank() -> void:
	RunState.reset(false, 20260926)
	_check(RunState.road_rank == 0 and RunState.augments_waiting() == 0, "a road starts at rank nought")
	var first: float = RunState.road_rank_cost(0)
	RunState.gain_road_xp(first - 0.5)
	_check(RunState.road_rank == 0 and RunState.augments_waiting() == 0,
		"a rank came before its cost was paid")
	RunState.gain_road_xp(0.5)
	_check(RunState.road_rank == 1 and RunState.augments_waiting() == 1,
		"paying a rank's cost did not deal a draft (rank %d, %d waiting)"
			% [RunState.road_rank, RunState.augments_waiting()])
	_check(String(RunState.augment_queue[0].get("source", "")) == Augments.SOURCE_RANK,
		"a rank's draft is not a rank's draft")
	_check(RunState.road_rank_cost(5) > RunState.road_rank_cost(1),
		"a later rank should cost more than an early one")
	var three: float = RunState.road_rank_cost(1) + RunState.road_rank_cost(2) + RunState.road_rank_cost(3)
	RunState.gain_road_xp(three)
	_check(RunState.road_rank == 4 and RunState.augments_waiting() == 4,
		"three ranks' worth at once dealt %d ranks and %d drafts" % [RunState.road_rank - 1, RunState.augments_waiting() - 1])
	RunState.walking = true
	RunState.gain_road_xp(1000.0)
	_check(RunState.road_rank == 4, "the Walk earned a road rank")
	RunState.walking = false
	RunState.reset(false, 20260926)
	_finished += 1


# --- The deal ----------------------------------------------------------------------

func _test_the_deal() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 20260926
	var none: Array = []
	var levels: Dictionary = {}
	for _i: int in 2000:
		var dealt: Array[String] = Augments.deal(dice, 3, 0, none, levels, Balance.ACT_COUNT, none, 0, none)
		_check(dealt.size() == 3, "a draft at the last act dealt %d cards" % dealt.size())
		var keys: Dictionary = {}
		var keystones: int = 0
		for id: String in dealt:
			var card: RoadCardData = ContentDB.road_card(id)
			if card.keystone:
				keystones += 1
			else:
				_check(not keys.has(card.effect_id), "two cards on %s were dealt together" % card.effect_id)
				keys[card.effect_id] = true
		_check(keystones <= 1, "two keystones were dealt together")
	for _i: int in 400:
		for id: String in Augments.deal(dice, 3, 0, none, levels, 1, none, 0, none):
			_check(ContentDB.road_card(id).first_act <= 1, "%s was dealt in Act I" % id)

	# **The floor, and the fall.** A boss deals Rare and up; there is no Epic in
	# the deck yet, so a floor of Epic falls to Rare rather than to nothing; and
	# an act with only Commons falls to Common rather than dealing nothing.
	for _i: int in 400:
		for id: String in Augments.deal(dice, 3, Balance.AUGMENT_FLOOR_BOSS, none, levels,
				Balance.ACT_COUNT, none, 0, none):
			_check(int(ContentDB.road_card(id).rarity) >= Balance.AUGMENT_FLOOR_BOSS,
				"a boss's draft dealt %s under its floor" % id)
		var epic: Array[String] = Augments.deal(dice, 3, Balance.AUGMENT_FLOOR_MYTHIC,
			none, levels, Balance.ACT_COUNT, none, 0, none)
		_check(epic.size() == 3, "a floor above the deck dealt %d cards" % epic.size())
	_check(Augments.deal(dice, 3, Balance.AUGMENT_FLOOR_BOSS, none, levels, 1, none, 0, none).size() == 3,
		"a boss's floor in an act of Commons dealt nothing")

	# Banished, and a card at its last level, never.
	var banished: Array = ["whetstone_hour", "loose_boots"]
	var grower: RoadCardData = _first(func(c: RoadCardData) -> bool:
		return c.levels() and c.first_act <= 1 and not banished.has(c.id))
	var hand: Array = [grower.id]
	var full: Dictionary = {grower.id: Balance.AUGMENT_MAX_LEVEL}
	var growing: Dictionary = {grower.id: 2}
	var dealt_growing: int = 0
	for _i: int in 800:
		for id: String in Augments.deal(dice, 3, 0, none, levels, Balance.ACT_COUNT, banished, 0, none):
			_check(not banished.has(id), "%s was dealt after it was banished" % id)
		_check(not Augments.deal(dice, 3, 0, hand, full, 1, none, 0, none).has(grower.id),
			"%s was dealt at its last level" % grower.id)
		if Augments.deal(dice, 3, 0, hand, growing, 1, none, 0, none).has(grower.id):
			dealt_growing += 1
	_check(dealt_growing > 0, "a held card that can still grow was never dealt again")

	# **Luck and lean move the odds and nothing else.**
	var plain: float = _share(dice, func(c: RoadCardData) -> bool: return int(c.rarity) > 0, 0, [])
	var lucky: float = _share(dice, func(c: RoadCardData) -> bool: return int(c.rarity) > 0,
		Balance.AUGMENT_LUCK_CAP, [])
	_check(lucky > plain * 1.2, "a full purse of luck dealt above Common %.2f of the time against %.2f" % [lucky, plain])
	var fire: Callable = func(c: RoadCardData) -> bool: return c.tags.has("Fire")
	var cold: float = _share(dice, fire, 0, [])
	var leaning: float = _share(dice, fire, 0, ["Fire"])
	_check(leaning > cold * 1.15, "leaning toward Fire dealt it %.2f of the time against %.2f" % [leaning, cold])

	# A reroll sees other cards where the deck is deep enough.
	for _i: int in 200:
		var first: Array[String] = Augments.deal(dice, 3, 0, none, levels, Balance.ACT_COUNT, none, 0, none)
		var again: Array[String] = Augments.deal(dice, 3, 0, none, levels, Balance.ACT_COUNT, none, 0, none, first)
		for id: String in again:
			_check(not first.has(id), "a reroll dealt %s straight back from a deep deck" % id)
	_finished += 1


## How often a draft at the last act holds a card `test` picks out.
func _share(dice: RandomNumberGenerator, test: Callable, luck: int, lean: Array) -> float:
	var hits: int = 0
	var total: int = 0
	var none: Array = []
	for _i: int in 3000:
		for id: String in Augments.deal(dice, 3, 0, none, {}, Balance.ACT_COUNT, none, luck, lean):
			total += 1
			if test.call(ContentDB.road_card(id)):
				hits += 1
	return float(hits) / float(maxi(total, 1))


# --- The draft ---------------------------------------------------------------------

func _test_the_draft() -> void:
	RunState.reset(false, 20260926)
	RunState.act = Balance.ACT_COUNT
	RunState.queue_augment(Augments.SOURCE_RANK)
	_check(RunState.deal_next_augment() and RunState.augment_offer.size() == 3,
		"a banked draft did not deal three cards")
	_check(not RunState.resolve_augment("not_a_card"), "a card not on the table was taken")
	var offered: Array[String] = RunState.augment_offer.duplicate()
	var dealt_again: bool = RunState.deal_next_augment()
	_check(dealt_again and RunState.augment_offer == offered,
		"dealing again with a draft on the table dealt a different draft")
	RunState.augment_luck = 3
	_check(RunState.resolve_augment(offered[0]), "the first card on the table could not be taken")
	_check(RunState.road_cards.has(offered[0]) and RunState.augment_offer.is_empty()
			and RunState.augments_waiting() == 0 and RunState.augment_luck == 0,
		"taking a card left the draft half-closed or the luck unspent")

	# **A full hand asks what to leave**, and a take without it changes nothing.
	RunState.reset(false, 20260926)
	RunState.act = Balance.ACT_COUNT
	var keys: Dictionary = {}
	for card: RoadCardData in _sorted_cards():
		if RunState.road_cards.size() >= Balance.ROAD_CARD_HAND:
			break
		if card.keystone or keys.has(card.effect_id) or card.rarity < RoadCardData.Rarity.RARE:
			continue
		keys[card.effect_id] = true
		RunState.take_road_card(card.id)
	_check(RunState.road_card_hand_is_full(), "the harness could not fill a hand")
	var new_key: String = ""
	for _attempt: int in 40:
		RunState.augment_queue = []
		RunState.augment_offer = []
		RunState.queue_augment(Augments.SOURCE_RANK)
		RunState.deal_next_augment()
		for id: String in RunState.augment_offer:
			var card: RoadCardData = ContentDB.road_card(id)
			if not RunState.road_cards.has(id) and not card.keystone and not keys.has(card.effect_id):
				new_key = id
		if not new_key.is_empty():
			break
	_check(not new_key.is_empty(), "no draft over a full hand offered a new key")
	if not new_key.is_empty():
		var before: Array[String] = RunState.augment_offer.duplicate()
		_check(not RunState.resolve_augment(new_key) and RunState.augment_offer == before
				and not RunState.road_cards.has(new_key),
			"a new key was taken into a full hand without leaving one behind")
		var leaving: String = RunState.road_cards[0]
		_check(RunState.resolve_augment(new_key, leaving) and RunState.road_cards.has(new_key)
				and not RunState.road_cards.has(leaving)
				and RunState.road_cards.size() == Balance.ROAD_CARD_HAND,
			"a named swap did not swap exactly one card")

	# **Skip banks a reroll; a reroll spends one and deals again; a banish takes
	# a card out of the road for good and deals its place.**
	RunState.reset(false, 20260926)
	RunState.act = Balance.ACT_COUNT
	RunState.queue_augment(Augments.SOURCE_RANK)
	RunState.deal_next_augment()
	var rerolls: int = RunState.augment_rerolls
	_check(RunState.skip_augment() and RunState.augment_rerolls == rerolls + 1
			and RunState.augments_waiting() == 0, "skipping did not bank a reroll and close the draft")
	RunState.augment_rerolls = Balance.AUGMENT_REROLLS_MAX
	RunState.queue_augment(Augments.SOURCE_RANK)
	RunState.deal_next_augment()
	RunState.skip_augment()
	_check(RunState.augment_rerolls == Balance.AUGMENT_REROLLS_MAX, "skipping banked a reroll past the most a road holds")

	RunState.queue_augment(Augments.SOURCE_RANK)
	RunState.deal_next_augment()
	var first: Array[String] = RunState.augment_offer.duplicate()
	rerolls = RunState.augment_rerolls
	_check(RunState.reroll_augment() and RunState.augment_rerolls == rerolls - 1,
		"a reroll did not spend one")
	var shared: int = 0
	for id: String in RunState.augment_offer:
		if first.has(id):
			shared += 1
	_check(shared == 0, "a reroll from a deep deck dealt %d of the same cards back" % shared)
	RunState.augment_rerolls = 0
	_check(not RunState.reroll_augment(), "a reroll was dealt with none left")

	var banishes: int = RunState.augment_banishes
	var gone: String = RunState.augment_offer[0]
	_check(RunState.banish_augment(gone) and RunState.augment_banished.has(gone)
			and not RunState.augment_offer.has(gone) and RunState.augment_offer.size() == 3
			and RunState.augment_banishes == banishes - 1,
		"a banish did not take the card out and deal its place")
	RunState.resolve_augment(RunState.augment_offer[0])
	var held: String = RunState.road_cards[0]
	RunState.queue_augment(Augments.SOURCE_RANK)
	RunState.deal_next_augment()
	RunState.augment_offer[0] = held
	_check(not RunState.banish_augment(held), "a card in the hand was banished, levels and all")
	RunState.reset(false, 20260926)
	_finished += 1


## **A Tempering deals from the hand** and grows the card chosen; with nothing
## left to grow it becomes a reroll rather than a draft of nothing.
func _test_the_tempering() -> void:
	RunState.reset(false, 20260926)
	var growers: Array[String] = []
	for card: RoadCardData in _sorted_cards():
		if card.levels() and growers.size() < 2:
			growers.append(card.id)
	_hold(growers)
	RunState.queue_augment(Augments.SOURCE_TEMPERING)
	_check(RunState.deal_next_augment(), "a Tempering over a hand that can grow dealt nothing")
	for id: String in RunState.augment_offer:
		_check(growers.has(id), "a Tempering dealt %s, which is not in the hand" % id)
	var chosen: String = RunState.augment_offer[0]
	_check(RunState.resolve_augment(chosen) and RunState.card_level(chosen) == 2
			and RunState.road_cards.size() == 2,
		"the tempered card did not grow a level, or the hand changed size")

	for id: String in growers:
		RunState.road_card_levels[id] = Balance.AUGMENT_MAX_LEVEL
	var rerolls: int = RunState.augment_rerolls
	RunState.queue_augment(Augments.SOURCE_TEMPERING)
	_check(not RunState.deal_next_augment() and RunState.augments_waiting() == 0
			and RunState.augment_rerolls == rerolls + 1,
		"a Tempering with nothing to grow was not turned into a reroll")
	RunState.reset(false, 20260926)
	_finished += 1


# --- The sources -------------------------------------------------------------------

## Each source is asked whether it is wired to the bus - a handler nothing calls
## is the lie this project keeps finding - and then driven through its handler,
## because emitting a boss's fall with no run standing would start its cinematic.
func _test_the_sources_are_wired() -> void:
	RunState.reset(false, 20260926)
	var pairs: Array = [
		[EventBus.boss_defeated, RunState._on_boss_for_augments],
		[EventBus.camp_cleared, RunState._on_camp_for_augments],
		[EventBus.raid_ended, RunState._on_raid_for_augments],
		[EventBus.rift_stage_cleared, RunState._on_rift_for_augments],
		[EventBus.wildlife_killed, RunState._on_wildlife_for_augments],
		[EventBus.wave_started, RunState._on_wave_for_augments],
		[EventBus.wave_cleared, RunState._on_wave_cleared_for_augments],
		[EventBus.coop_augment_hand, RunState._on_coop_augment_hand],
	]
	for pair: Array in pairs:
		var bus: Signal = pair[0]
		_check(bus.is_connected(pair[1] as Callable), "%s deals no draft: nothing listens" % bus.get_name())

	RunState._on_boss_for_augments("boss", 1)
	_check(_last_source() == Augments.SOURCE_BOSS
			and int(RunState.augment_queue.back().get("floor", -1)) == Balance.AUGMENT_FLOOR_BOSS,
		"a boss's draft is not dealt at the boss's floor")
	var before: int = RunState.augments_waiting()
	RunState._on_camp_for_augments(0, 1)
	RunState._on_camp_for_augments(0, 1)
	RunState._on_camp_for_augments(2, 3)
	_check(RunState.augments_waiting() == before + 1,
		"a second camp in one act dealt a second draft")
	RunState.act = 2
	RunState._on_camp_for_augments(0, 1)
	_check(RunState.augments_waiting() == before + 2, "a camp in a new act dealt nothing")
	before = RunState.augments_waiting()
	RunState._on_raid_for_augments({"died": true})
	_check(RunState.augments_waiting() == before, "a raid the Warden died in dealt a draft")
	RunState._on_raid_for_augments({"died": false, "partial": true})
	_check(_last_source() == Augments.SOURCE_RAID, "a raid brought home dealt nothing")
	before = RunState.augments_waiting()
	RunState._on_rift_for_augments(1, 3)
	_check(RunState.augments_waiting() == before, "a dungeon dealt a draft before its last stage")
	RunState._on_rift_for_augments(3, 3)
	_check(_last_source() == Augments.SOURCE_RIFT, "a rift closed dealt nothing")
	before = RunState.augments_waiting()
	RunState._on_wildlife_for_augments("rabbit", 0, Vector2.ZERO, 0, false, false)
	_check(RunState.augments_waiting() == before, "an ordinary animal dealt a draft")
	var legend: String = ""
	for kind: WildlifeData in ContentDB.wildlife():
		if kind.mythic:
			legend = kind.id
			break
	RunState._on_wildlife_for_augments(legend, 0, Vector2.ZERO, 3, false, false)
	_check(_last_source() == Augments.SOURCE_MYTHIC
			and int(RunState.augment_queue.back().get("floor", -1)) == Balance.AUGMENT_FLOOR_MYTHIC,
		"a legend brought down did not deal the rarest draft")

	# **A clean wave is luck; a struck one is not; enough waves temper.**
	RunState.reset(false, 20260926)
	RunState._on_wave_for_augments(1, [])
	RunState._on_wave_cleared_for_augments(1)
	_check(RunState.augment_luck == 1, "a clean wave banked no luck")
	RunState._on_wave_for_augments(2, [])
	RunState.town_hits_taken += 1
	RunState._on_wave_cleared_for_augments(2)
	_check(RunState.augment_luck == 1, "a wave the wall was struck in banked luck")
	for wave: int in range(3, Balance.AUGMENT_HOLDFAST_WAVES + 1):
		RunState._on_wave_for_augments(wave, [])
		RunState._on_wave_cleared_for_augments(wave)
	_check(_last_source() == Augments.SOURCE_TEMPERING,
		"%d waves survived dealt no Tempering" % Balance.AUGMENT_HOLDFAST_WAVES)
	_check(RunState.augment_luck <= Balance.AUGMENT_LUCK_CAP, "luck banked past its cap")
	RunState.reset(false, 20260926)
	_finished += 1


func _last_source() -> String:
	if RunState.augment_queue.is_empty():
		return ""
	return String(RunState.augment_queue.back().get("source", ""))


# --- The road ----------------------------------------------------------------------

## A front banked at a crossroad comes back holding its draft - the cards, their
## levels, the rank, the banked drafts, the tools and the luck.
func _test_a_front_banks_the_draft() -> void:
	RunState.reset(false, 20260926)
	var grower: RoadCardData = _first(func(c: RoadCardData) -> bool: return c.levels())
	RunState.take_road_card(grower.id)
	RunState.take_road_card(grower.id)
	RunState.gain_road_xp(RunState.road_rank_cost(0) + 3.0)
	RunState.queue_augment(Augments.SOURCE_BOSS)
	RunState.augment_banished.append("loose_boots")
	RunState.augment_luck = 4
	RunState.augment_rerolls = 5
	RunState.augment_waves_toward_tempering = 6
	RunState.augment_camps_drafted.append("1")
	var names: Array[String] = ["road_card_levels", "road_rank", "road_xp", "augment_queue",
		"augment_offer", "augment_offer_source", "augment_rerolls", "augment_banishes",
		"augment_banished", "augment_luck", "augment_waves_toward_tempering",
		"augment_camps_drafted"]
	var was: Dictionary = {}
	for key: String in names:
		_check(Expedition.STATE_KEYS.has(key), "a banked front forgets %s" % key)
		_check(RunState.get(key) != null, "%s is in the snapshot and not on RunState" % key)
		was[key] = var_to_str(RunState.get(key))
	var photo: String = Expedition._capture_progress()
	RunState.reset(false, 20260926)
	Expedition._restore_progress(photo)
	for key: String in names:
		_check(var_to_str(RunState.get(key)) == String(was[key]),
			"%s came back as %s, not %s" % [key, var_to_str(RunState.get(key)), was[key]])
	RunState.reset(false, 20260926)
	_finished += 1


func _test_a_fresh_road_deals_a_fresh_draft() -> void:
	RunState.take_road_card(_first(func(c: RoadCardData) -> bool: return c.levels()).id)
	RunState.gain_road_xp(500.0)
	RunState.augment_banished.append("loose_boots")
	RunState.augment_rerolls = 0
	RunState.augment_luck = 5
	RunState.deal_next_augment()
	RunState.reset(false, 20260926)
	_check(RunState.road_cards.is_empty() and RunState.road_card_levels.is_empty()
			and RunState.road_rank == 0 and is_zero_approx(RunState.road_xp)
			and RunState.augment_queue.is_empty() and RunState.augment_offer.is_empty()
			and RunState.augment_banished.is_empty() and RunState.augment_luck == 0
			and RunState.augment_rerolls == Balance.AUGMENT_REROLLS_START
			and RunState.augment_banishes == Balance.AUGMENT_BANISHES_START,
		"a draft survived into a fresh road, which is an account-level power nobody earned")
	_finished += 1


## **One hand for the party** (co-op phase A): the host's hand crosses whole and a
## guest holds exactly it - and a row naming a card this build lacks, or a level
## past the card's last, is cleaned rather than trusted.
func _test_the_party_holds_one_hand() -> void:
	RunState.reset(false, 20260926)
	var grower: RoadCardData = _first(func(c: RoadCardData) -> bool: return c.levels())
	var other: RoadCardData = _first(func(c: RoadCardData) -> bool:
		return c.levels() and c.effect_id != grower.effect_id)
	RunState.take_road_card(grower.id)
	RunState.take_road_card(grower.id)
	RunState.take_road_card(other.id)
	RunState.augment_banished.append("loose_boots")
	RunState.road_rank = 7
	var args: Array = CoopRelay.augment_hand_args()
	var hand: Array[String] = RunState.road_cards.duplicate()
	var levels: Dictionary = RunState.road_card_levels.duplicate()
	RunState.reset(false, 20260926)
	RunState.adopt_augment_hand(args[0] as Array, args[1] as Array, args[2] as Array, int(args[3]))
	_check(RunState.road_cards == hand and RunState.road_card_levels == levels
			and RunState.augment_banished == ["loose_boots"] and RunState.road_rank == 7,
		"the guest's hand is not the host's")
	_check(is_equal_approx(Modifiers.value(grower.effect_id), grower.magnitude_at(2)),
		"the adopted hand did not reach the guest's table")
	RunState.adopt_augment_hand(["not_a_card", grower.id], [3, 99], ["also_not"], -4)
	_check(RunState.road_cards == [grower.id]
			and RunState.card_level(grower.id) == grower.max_level()
			and RunState.augment_banished.is_empty() and RunState.road_rank == 0,
		"a malformed hand was trusted: %s %s" % [str(RunState.road_cards), str(RunState.road_card_levels)])
	RunState.reset(false, 20260926)
	_finished += 1


## **A road begun at an act holds the drafts a walked road would have dealt**,
## banked for the player to choose rather than chosen for them.
func _test_an_act_start_banks_the_road() -> void:
	_check(Balance.ACT_START_DRAFTS.size() == Balance.ACT_START_BUDGET.size()
			and Balance.ACT_START_ROAD_RANK.size() == Balance.ACT_START_BUDGET.size(),
		"the act-start tables do not cover the same acts")
	for index: int in range(1, Balance.ACT_START_DRAFTS.size()):
		_check(Balance.ACT_START_DRAFTS[index] > Balance.ACT_START_DRAFTS[index - 1]
				and Balance.ACT_START_ROAD_RANK[index] > Balance.ACT_START_ROAD_RANK[index - 1],
			"a later act starts with no more drafts than an earlier one")
		_check(Balance.ACT_START_DRAFTS[index] >= Balance.ACT_START_ROAD_RANK[index] + index,
			"act %d starts with fewer drafts than its ranks and bosses deal" % (index + 1))
	# Through the real door, which is the only thing a player presses.
	var kept: float = MetaState.best_distance
	MetaState.best_distance = Balance.act_start_distance(Balance.ACT_COUNT) + 10.0
	for act: int in [1, 2, 7, Balance.ACT_COUNT]:
		RunState.reset(false, 20260926)
		_check(ActStart.begin(act, "measured"), "an act-%d start was refused" % act)
		var index: int = act - 1
		var bosses: int = 0
		for entry: Dictionary in RunState.augment_queue:
			if String(entry.get("source", "")) == Augments.SOURCE_BOSS:
				bosses += 1
		_check(RunState.augments_waiting() == Balance.ACT_START_DRAFTS[index]
				and RunState.road_rank == Balance.ACT_START_ROAD_RANK[index]
				and bosses == act - 1,
			"an act-%d start banked %d drafts (%d bosses) at rank %d" % [act,
				RunState.augments_waiting(), bosses, RunState.road_rank])
	MetaState.best_distance = kept
	RunState.pending_outfit = {}
	RunState.reset(false, 20260926)
	_finished += 1


## **Every blow on a body names what threw it** (`DamageLedger`). The failure is
## an omission - a new door that deals a blow without naming itself files it
## under "other" for ever - so the doors are walked in the source, and then one
## blow of each kind is thrown for real and read back.
func _test_the_ledger_names_every_blow() -> void:
	# Blows on something other than a road body: a hero, a spirit, a wall.
	var not_a_body: Array[String] = ["pet.take_damage(", "spirit.take_damage(",
		"(_target as Companion).take_damage(", "(target as Companion).take_damage(",
		"hurt.take_damage(", "health.take_damage(", "target_health.take_damage("]
	var unnamed: Array[String] = []
	for folder: String in ["res://scenes", "res://scripts"]:
		for path: String in _scripts_under(folder):
			var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
			for index: int in lines.size():
				var line: String = lines[index].strip_edges()
				if line.begins_with("#") or not line.contains(".take_damage(") \
						or line.begins_with("func "):
					continue
				var other: bool = false
				for pattern: String in not_a_body:
					if line.contains(pattern):
						other = true
				if other or path.ends_with("damage_ledger.gd"):
					continue
				if index == 0 or not lines[index - 1].contains("DamageLedger.credit_as("):
					unnamed.append("%s:%d" % [path.get_file(), index + 1])
	_check(unnamed.is_empty(), "blows that name nothing: %s" % ", ".join(unnamed))

	RunState.reset(false, 20260926)
	var tower_card: RoadCardData = _first(func(c: RoadCardData) -> bool:
		return c.effect_id == Modifiers.TOWER_DAMAGE)
	RunState.take_road_card(tower_card.id)
	var total: float = 1.0 + Modifiers.value(Modifiers.TOWER_DAMAGE)
	DamageLedger.note(DamageLedger.TOWER_PREFIX + "ember_spire", 100.0)
	DamageLedger.note(DamageLedger.EARTH, 40.0)
	DamageLedger.note(DamageLedger.WARDEN, 0.0)
	var book: Dictionary = RunState.damage_ledger
	_check(is_equal_approx(float(book.get("tower:ember_spire", 0.0)), 100.0)
			and is_equal_approx(float(book.get(DamageLedger.EARTH, 0.0)), 40.0)
			and not book.has(DamageLedger.WARDEN),
		"the ledger did not write what each blow took: %s" % str(book))
	var credited: float = float(book.get(DamageLedger.AUGMENT_PREFIX + tower_card.id, 0.0))
	_check(is_equal_approx(credited, 100.0 * tower_card.magnitude_at(1) / total),
		"%s was credited %.2f of a 100 blow, not its %.2f share" % [tower_card.id,
			credited, 100.0 * tower_card.magnitude_at(1) / total])
	_check(not book.has(DamageLedger.AUGMENT_PREFIX + tower_card.id + "x")
			and float(book.get(DamageLedger.AUGMENT_PREFIX + tower_card.id, 0.0)) < 100.0,
		"an augment was credited the whole blow")
	DamageLedger.credit_as(DamageLedger.ARROW)
	_check(DamageLedger.take_source() == DamageLedger.ARROW
			and DamageLedger.take_source() == DamageLedger.OTHER,
		"a blow's name outlived the blow and would name the next one")
	var lines: PackedStringArray = DamageLedger.lines(book,
		{tower_card.id: 1})
	_check(lines.size() >= 3 and lines[0].begins_with("DAMAGE"),
		"the debrief's ledger said nothing: %s" % str(lines))
	_check(not DamageLedger.brief(book).is_empty(), "the pause screen's ledger said nothing")
	RunState.reset(false, 20260926)
	_check(RunState.damage_ledger.is_empty(), "a ledger survived into a fresh road")
	_finished += 1


## **Depth in a branch opens its keystones** - three cards the first, six the
## second - and a keystone never counts toward the depth that opens it.
func _test_a_branch_opens_its_keystones() -> void:
	var warden: Array[String] = []
	for card: RoadCardData in _sorted_cards():
		if not card.keystone and card.branch == RoadCardData.Branch.WARDEN:
			warden.append(card.id)
	var first: RoadCardData = _first(func(c: RoadCardData) -> bool:
		return c.keystone and c.branch == RoadCardData.Branch.WARDEN and c.branch_needs == 3)
	var second: RoadCardData = _first(func(c: RoadCardData) -> bool:
		return c.keystone and c.branch == RoadCardData.Branch.WARDEN and c.branch_needs == 6)
	_check(first != null and second != null and warden.size() >= 6,
		"the Warden's branch has no keystone at three and six, or too few cards to reach them")
	if first == null or second == null or warden.size() < 6:
		return
	var dice := RandomNumberGenerator.new()
	dice.seed = 33
	var none: Array = []
	for depth: int in [0, 2, 3, 5, 6]:
		var hand: Array = warden.slice(0, depth)
		var saw_first: bool = false
		var saw_second: bool = false
		for _i: int in 1500:
			var dealt: Array[String] = Augments.deal(dice, 3, 0, hand, {}, Balance.ACT_COUNT,
				none, 0, none)
			saw_first = saw_first or dealt.has(first.id)
			saw_second = saw_second or dealt.has(second.id)
		_check(saw_first == (depth >= 3), "%s at a Warden depth of %d was %s" % [first.id,
			depth, "dealt" if saw_first else "never dealt"])
		_check(saw_second == (depth >= 6), "%s at a Warden depth of %d was %s" % [second.id,
			depth, "dealt" if saw_second else "never dealt"])
	_check(Augments.branch_depth([first.id, second.id], RoadCardData.Branch.WARDEN) == 0,
		"a keystone counted toward the depth that opens it")
	_finished += 1


## **Every key a card may move is read by the game.** A key the table resolves
## and nothing asks for is the `DisciplineEffects` lie on the modifier table:
## the card draws, says the words, levels to V and does nothing. A grep is a weak
## proof of behaviour and a strong proof of wiring, which is the half that goes
## silently false - the five keys wired for the staged content pass have no card
## yet, so nothing else would notice one coming unwired before October.
func _test_every_key_is_read() -> void:
	var sources: Array[String] = []
	for folder: String in ["res://scenes", "res://scripts", "res://autoload"]:
		for path: String in _scripts_under(folder):
			if path.ends_with("Modifiers.gd") or path.ends_with("damage_ledger.gd"):
				continue
			sources.append(FileAccess.get_file_as_string(path))
	var constants: Dictionary = (Modifiers.get_script() as Script).get_script_constant_map()
	for name: Variant in constants:
		var value: Variant = constants[name]
		if typeof(value) != TYPE_STRING or not Modifiers.keys_in_use().has(String(value)):
			continue
		var needle: String = "Modifiers.%s" % String(name)
		var read: bool = false
		for text: String in sources:
			if text.contains(needle):
				read = true
				break
		_check(read, "%s ('%s') is resolved by the table and read by nothing" % [name, value])
	_finished += 1


## **The new keys move what they name**, through the real readers, with a probe
## card slipped into the deck for the length of the test.
func _test_the_new_keys_reach_their_readers() -> void:
	var probe := RoadCardData.new()
	probe.id = "probe_augment"
	probe.effect_magnitude = 0.2
	ContentDB.road_cards[probe.id] = probe
	RunState.road_cards = []
	RunState.road_card_levels = {}
	Modifiers.rebuild()
	var spell_before: float = SpellCaster.focus_power()
	var hero: Hero = _field.hero
	var regen_before: float = hero.mana_regen() if hero != null else 0.0
	for key: String in [Modifiers.SPELL_POWER, Modifiers.MANA_REGEN]:
		probe.effect_id = key
		RunState.road_cards = [probe.id]
		Modifiers.rebuild()
		if key == Modifiers.SPELL_POWER:
			_check(is_equal_approx(SpellCaster.focus_power(), spell_before * 1.2),
				"a spell-power card left spells at %.3f of %.3f" % [SpellCaster.focus_power(), spell_before])
		elif hero != null:
			_check(is_equal_approx(hero.mana_regen(), regen_before * 1.2),
				"a mana card left the Warden's regeneration at %.3f of %.3f" % [hero.mana_regen(), regen_before])
	RunState.road_cards = []
	Modifiers.rebuild()
	ContentDB.road_cards.erase(probe.id)
	_finished += 1


func _scripts_under(folder: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return out
	for name: String in dir.get_files():
		if name.ends_with(".gd"):
			out.append(folder.path_join(name))
	for sub: String in dir.get_directories():
		out.append_array(_scripts_under(folder.path_join(sub)))
	return out


# --- On the field ------------------------------------------------------------------

## A real body, killed the ordinary way, pays the rank.
func _test_a_kill_pays_the_rank() -> void:
	var none: Array[EnemyAffixData] = []
	var body: Enemy = _field.spawn_enemy(ContentDB.enemy("bogkin"), 0, 1.0, 1.0, 1.0,
		false, Enemy.Rank.COMMON, none)
	_check(body != null, "the harness could not stand a body up")
	if body == null:
		return
	_check(is_equal_approx(body.road_xp_worth(), Balance.ROAD_XP_BODY),
		"an ordinary body is worth %.1f to the rank" % body.road_xp_worth())
	var xp_before: float = RunState.road_xp
	var rank_before: int = RunState.road_rank
	# And the ledger, on the funnel every blow goes through.
	DamageLedger.credit_as(DamageLedger.TOWER_PREFIX + "ember_spire")
	body.take_damage(10.0, body.global_position, 0.0)
	_check(float(RunState.damage_ledger.get("tower:ember_spire", 0.0)) > 0.0,
		"a named blow on the field did not reach the ledger")
	body.health.kill(body.global_position)
	await get_tree().process_frame
	_check(RunState.road_xp > xp_before or RunState.road_rank > rank_before,
		"a body killed on the field paid the road rank nothing")
	_finished += 1


## **The run opens a banked draft at the breather**, holds the clock while it is
## read, and takes the card a player presses.
func _test_the_breather_opens_the_draft() -> void:
	var screen: CrossroadScreen = _run.crossroad_ui
	RunState.augment_queue = []
	RunState.augment_offer = []
	RunState.set_phase(RunState.Phase.PREPARATION)
	_run._augments_put_off = false
	_run._preparation_left = 12.0
	_run._breather = true
	RunState.queue_augment(Augments.SOURCE_RANK)
	for _frame: int in 6:
		await get_tree().process_frame
	_check(screen.is_augment_open(), "a banked draft did not open in Preparation")
	var held_at: float = _run._preparation_left
	for _frame: int in 30:
		await get_tree().process_frame
	_check(is_equal_approx(_run._preparation_left, held_at),
		"the breather's clock ran while the draft was being read (%.2f to %.2f)"
			% [held_at, _run._preparation_left])
	var chosen: String = RunState.augment_offer[0] if not RunState.augment_offer.is_empty() else ""
	var button: Button = screen._buttons.get(chosen, null) as Button
	_check(button != null, "the card on the table has no card to press")
	if button != null:
		button.pressed.emit()
	for _frame: int in 4:
		await get_tree().process_frame
	_check(RunState.road_cards.has(chosen) and not screen.is_augment_open()
			and RunState.augments_waiting() == 0,
		"pressing the card did not take it and close the draft")
	for _frame: int in 20:
		await get_tree().process_frame
	_check(_run._preparation_left < held_at, "the clock did not start again once the draft closed")
	_run._breather = false
	_run._preparation_left = 0.0
	_finished += 1


## Later closes the draft and keeps it banked, and it does not reopen until the
## next Preparation.
func _test_later_waits_for_the_next_breather() -> void:
	var screen: CrossroadScreen = _run.crossroad_ui
	RunState.queue_augment(Augments.SOURCE_RANK)
	for _frame: int in 6:
		await get_tree().process_frame
	_check(screen.is_augment_open(), "a second draft did not open")
	screen.close_augment_draft()
	for _frame: int in 20:
		await get_tree().process_frame
	_check(not screen.is_augment_open() and RunState.augments_waiting() == 1,
		"Later lost the draft or opened it again at once")
	_run._enter_preparation(false)
	for _frame: int in 6:
		await get_tree().process_frame
	_check(screen.is_augment_open(), "a put-off draft did not come back at the next Preparation")
	RunState.skip_augment()
	screen.close_augment_draft()
	for _frame: int in 4:
		await get_tree().process_frame
	_finished += 1


## **The strip opens a banked draft**: in a fight, playing alone, the road holds
## for it exactly as At once holds it.
func _test_the_strip_opens_a_draft() -> void:
	var screen: CrossroadScreen = _run.crossroad_ui
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	for _frame: int in 3:
		await get_tree().process_frame
	RunState.queue_augment(Augments.SOURCE_RANK)
	for _frame: int in 3:
		await get_tree().process_frame
	_check(not screen.is_augment_open(), "a draft opened in a fight before anybody asked")
	_check(EventBus.augment_open_requested.is_connected(_run._on_augment_open_requested),
		"nothing answers the strip")
	EventBus.augment_open_requested.emit()
	for _frame: int in 3:
		await get_tree().process_frame
	_check(_field.is_suspended() and screen.is_augment_open(),
		"asking for a banked draft in a fight did not hold the road and open it")
	RunState.skip_augment()
	screen.close_augment_draft()
	for _frame: int in 3:
		await get_tree().process_frame
	_check(not _field.is_suspended(), "closing the asked-for draft did not let the field go")
	RunState.set_phase(RunState.Phase.PREPARATION)
	_finished += 1


## **At once holds the road**: the field freezes, the draft opens, and taking the
## card lets the field go.
func _test_at_once_holds_the_road() -> void:
	var screen: CrossroadScreen = _run.crossroad_ui
	MetaState.settings[UserSettings.AUGMENT_AT_ONCE_KEY] = true
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	for _frame: int in 3:
		await get_tree().process_frame
	RunState.queue_augment(Augments.SOURCE_RANK)
	for _frame: int in 4:
		await get_tree().process_frame
	_check(_field.is_suspended() and screen.is_augment_open(),
		"a draft earned in a fight with At once set did not hold the road (suspended %s, open %s)"
			% [_field.is_suspended(), screen.is_augment_open()])
	var chosen: String = RunState.augment_offer[0] if not RunState.augment_offer.is_empty() else ""
	var button: Button = screen._buttons.get(chosen, null) as Button
	if button != null:
		button.pressed.emit()
	for _frame: int in 4:
		await get_tree().process_frame
	_check(not _field.is_suspended() and not screen.is_augment_open(),
		"taking the card did not let the field go")
	MetaState.settings[UserSettings.AUGMENT_AT_ONCE_KEY] = false
	RunState.queue_augment(Augments.SOURCE_RANK)
	for _frame: int in 4:
		await get_tree().process_frame
	_check(not _field.is_suspended() and not screen.is_augment_open(),
		"a draft opened in the middle of a fight without At once")
	RunState.set_phase(RunState.Phase.PREPARATION)
	_finished += 1
