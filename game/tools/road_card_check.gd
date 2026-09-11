extends Node

## A Road Card must reach the numbers it names, and the hand must stay a hand.
##
## Owner ruling, 2026-09-11: build Road Cards, over `IDEAS_REVIEW` §4's refusal
## that disciplines and omens already are a draft. That refusal is the right
## objection, and this gate is what answers it: **the pool is bounded, and the
## bound is enforced in one place.**
##
## Five ways a card pool can be a lie, all with precedent in this project:
##
## - **It grants nothing.** A misspelt effect key lands in the table under a name
##   nothing reads, so the card draws, says the words, and does nothing at all.
##   `omen_check` was written for exactly this and caught one on its first run.
## - **It grants nothing, quietly.** `Tower` reads `chain_targets` with `int()`,
##   so a card granting 0.55 of a chain target grants zero. Two entries were
##   authored that way here before either was written to disk.
## - **It grants everything.** 2.2 where 0.22 was meant looks like every other
##   line in a `.tres` and ends the run it is drawn in.
## - **The hand is not a hand.** If the cap or the one-card-per-key rule can be
##   walked around, twenty crossroads become twenty upgrades and the pool is the
##   third power scale the ruling says it must not be.
## - **It follows you home.** A hand that survived `RunState.reset` would be an
##   account-level difficulty setting nobody chose, and working rule 7 does not
##   sanction one.

var _failures: int = 0
var _checked: int = 0
var _finished: int = 0
const EXPECTED_TESTS: int = 6

## Keys the game reads as a whole number of things rather than as a fraction.
## Kept in step with `omen_check.COUNTED_KEYS` by hand, because both gates have
## to agree about what "counted" means and neither owns the other.
const COUNTED_KEYS: Array[String] = [
	Modifiers.CHAIN_TARGETS, Modifiers.WAVE_FORESIGHT,
]


func _ready() -> void:
	MetaState.hold_saves()
	await get_tree().process_frame

	_test_the_pool_is_deep_enough()
	_test_every_card_is_authored()
	_test_magnitudes_are_sane()
	_test_a_card_reaches_the_modifier_table()
	_test_the_hand_holds()
	_test_a_fresh_run_deals_a_fresh_hand()

	if _finished != EXPECTED_TESTS:
		_check(false, "only %d of %d tests ran to completion" % [_finished, EXPECTED_TESTS])
	_finish()


## Every crossroad on the road must be able to deal a full offer.
##
## Walked rather than counted, because counting is what let the portent pool run
## dry at Act IX: a pool of ten looks ample until you notice that what is dealt
## leaves it.
func _test_the_pool_is_deep_enough() -> void:
	var held: Array[String] = []
	for act: int in range(1, Balance.ACT_COUNT + 1):
		for _crossroad: int in Balance.SEGMENTS_PER_ACT:
			var drawn: Array[String] = RoadCardData.offer(held, act,
				Balance.ROAD_CARD_OFFER_COUNT)
			_checked += 1
			_check(drawn.size() == Balance.ROAD_CARD_OFFER_COUNT,
				("Act %d offers %d cards of %d: the pool ran out, so the draft "
					+ "never appears and nothing says why")
					% [act, drawn.size(), Balance.ROAD_CARD_OFFER_COUNT])
			if drawn.is_empty():
				_finished += 1
				return
			# Hold the taken card so the next draw sees a smaller pool, which is
			# the condition the portent pool failed under.
			if held.size() < Balance.ROAD_CARD_HAND:
				held.append(drawn[0])
	_finished += 1


func _test_every_card_is_authored() -> void:
	for id: Variant in ContentDB.road_cards:
		var card: RoadCardData = _card(String(id))
		_checked += 1
		_check(not card.display_name.is_empty()
				and not card.card_text.strip_edges().is_empty(),
			"%s must have a name and say what it is" % card.id)
		_checked += 1
		_check(ResourceLoader.exists(card.get_sprite_path()),
			"%s has no icon at %s" % [card.id, card.get_sprite_path()])
		_checked += 1
		_check(omen_check_keys().has(card.effect_id),
			("%s names the effect '%s', which `Modifiers` does not resolve; it "
				+ "will land in the table under a name nothing reads")
				% [card.id, card.effect_id])
	_finished += 1


## The typo net, and the counted-key trap.
func _test_magnitudes_are_sane() -> void:
	for id: Variant in ContentDB.road_cards:
		var card: RoadCardData = _card(String(id))
		_checked += 1
		_check(not is_zero_approx(card.effect_magnitude),
			"%s moves nothing" % card.id)
		if COUNTED_KEYS.has(card.effect_id):
			_checked += 1
			_check(is_equal_approx(card.effect_magnitude,
					round(card.effect_magnitude))
					and absf(card.effect_magnitude) >= 1.0,
				("%s moves '%s' by %+.2f, and the game reads that key as a whole "
					+ "number - so anything under one is silently zero")
					% [card.id, card.effect_id, card.effect_magnitude])
			continue
		_checked += 1
		_check(absf(card.effect_magnitude) <= Balance.ROAD_CARD_MAX_MAGNITUDE,
			("%s moves '%s' by %+.2f, past the %.2f ceiling. A decimal point in "
				+ "the wrong place looks exactly like this")
				% [card.id, card.effect_id, card.effect_magnitude,
					Balance.ROAD_CARD_MAX_MAGNITUDE])

		# A card that helps the player must help: a Common that hurt would be a
		# portent's bane with no boon attached to pay for it.
		#
		# Guarded rather than indexed straight: a card naming a key the table
		# does not know is already reported above, and reading it here would
		# take the whole gate down with an index error instead.
		var directions: Dictionary = omen_check_keys()
		if not directions.has(card.effect_id):
			continue
		var helps: bool = bool(directions[card.effect_id])
		var good: bool = card.effect_magnitude > 0.0 if helps \
			else card.effect_magnitude < 0.0
		_checked += 1
		_check(good, "%s (%s %+.2f) is a cost, and a card has no bane to pay it"
			% [card.id, card.effect_id, card.effect_magnitude])
	_finished += 1


## Taking one moves the number a tower would read.
func _test_a_card_reaches_the_modifier_table() -> void:
	for id: Variant in ContentDB.road_cards:
		var card: RoadCardData = _card(String(id))
		RunState.road_cards = []
		Modifiers.rebuild()
		var before: float = Modifiers.value(card.effect_id)
		RunState.road_cards = [card.id]
		Modifiers.rebuild()
		_checked += 1
		_check(is_equal_approx(Modifiers.value(card.effect_id) - before,
				card.effect_magnitude),
			"%s did not reach the modifier table" % card.id)
	RunState.road_cards = []
	Modifiers.rebuild()
	_finished += 1


## **The one this gate is for.** Five slots, one card per key, no way around it.
##
## Driven through `RunState.take_road_card` rather than by assembling an array,
## because the claim is that the *game* holds the rule. Every protection here
## has been checked by removing it.
func _test_the_hand_holds() -> void:
	var by_key: Dictionary = {}
	var ids: Array[String] = []
	for id: Variant in ContentDB.road_cards:
		ids.append(String(id))
	ids.sort()
	for id: String in ids:
		var card: RoadCardData = _card(id)
		if not by_key.has(card.effect_id):
			by_key[card.effect_id] = []
		(by_key[card.effect_id] as Array).append(id)

	# Six distinct keys into five slots: the sixth must be refused unless it
	# names something to leave.
	var distinct: Array[String] = []
	for key: Variant in by_key:
		distinct.append(String((by_key[key] as Array)[0]))
	distinct.sort()
	_checked += 1
	_check(distinct.size() > Balance.ROAD_CARD_HAND,
		"the pool needs more than %d effect keys to test the cap"
			% Balance.ROAD_CARD_HAND)
	if distinct.size() <= Balance.ROAD_CARD_HAND:
		_finished += 1
		return

	RunState.road_cards = []
	for index: int in Balance.ROAD_CARD_HAND:
		RunState.take_road_card(distinct[index])
	_checked += 1
	_check(RunState.road_cards.size() == Balance.ROAD_CARD_HAND,
		"a hand of %d did not fill to %d"
			% [RunState.road_cards.size(), Balance.ROAD_CARD_HAND])

	var overflow: String = distinct[Balance.ROAD_CARD_HAND]
	_checked += 1
	_check(RunState.take_road_card(overflow).is_empty()
			and not RunState.road_cards.has(overflow),
		("a sixth card on a new key was taken without leaving one behind, so "
			+ "the hand is not a hand"))
	_checked += 1
	_check(RunState.take_road_card(overflow, "not_a_card").is_empty()
			and not RunState.road_cards.has(overflow),
		"a drop that is not in the hand was accepted, which would lose a card")

	var leaving: String = RunState.road_cards[0]
	var dropped: String = RunState.take_road_card(overflow, leaving)
	_checked += 1
	_check(dropped == leaving and RunState.road_cards.has(overflow)
			and not RunState.road_cards.has(leaving)
			and RunState.road_cards.size() == Balance.ROAD_CARD_HAND,
		"a named swap did not swap exactly one card")

	# Two cards on one key: the second replaces the first rather than stacking.
	var pair: Array = []
	for key: Variant in by_key:
		if (by_key[key] as Array).size() >= 2:
			pair = by_key[key] as Array
			break
	if pair.size() >= 2:
		RunState.road_cards = []
		RunState.take_road_card(String(pair[0]))
		var went: String = RunState.take_road_card(String(pair[1]))
		_checked += 1
		_check(went == String(pair[0]) and RunState.road_cards.size() == 1
				and RunState.road_cards.has(String(pair[1])),
			("two cards naming one effect were both held, which is the stack "
				+ "this design exists to refuse"))
		var card: RoadCardData = _card(String(pair[1]))
		Modifiers.rebuild()
		_checked += 1
		_check(is_equal_approx(Modifiers.value(card.effect_id),
				card.effect_magnitude),
			"an upgraded key is worth more than the card that holds it")
	RunState.road_cards = []
	Modifiers.rebuild()
	_finished += 1


func _test_a_fresh_run_deals_a_fresh_hand() -> void:
	var first: String = ""
	for id: Variant in ContentDB.road_cards:
		first = String(id)
		break
	RunState.road_cards = [first]
	RunState.pending_road_cards = [first]
	RunState.reset()
	_checked += 1
	_check(RunState.road_cards.is_empty() and RunState.pending_road_cards.is_empty(),
		("a hand survived into a fresh run, which is an account-level "
			+ "difficulty setting nobody chose"))
	Modifiers.rebuild()
	_finished += 1


## The direction table lives in `omen_check`; rebuilt here rather than imported
## so that neither gate can be broken by the other being edited.
func omen_check_keys() -> Dictionary:
	return {
		Modifiers.TOWER_DAMAGE: true, Modifiers.TOWER_RANGE: true,
		Modifiers.TOWER_ARMOUR: true, Modifiers.CHAIN_TARGETS: true,
		Modifiers.BURN_DAMAGE: true, Modifiers.SLOW_STRENGTH: true,
		Modifiers.KNOCKBACK: true, Modifiers.HERO_DAMAGE: true,
		Modifiers.HERO_SPEED: true, Modifiers.HERO_MAX_HP: true,
		Modifiers.TOWN_MAX_HP: true, Modifiers.RESOURCE_RATE: true,
		Modifiers.KILL_RESOURCES: true, Modifiers.CAPTIVE_OUTPUT: true,
		Modifiers.BEAST_SPEED: true, Modifiers.RAID_CHARGE: true,
		Modifiers.WAVE_FORESIGHT: true,
		Modifiers.BUILD_COST: false, Modifiers.ENEMY_DAMAGE: false,
		Modifiers.DASH_COOLDOWN: false,
	}


func _card(id: String) -> RoadCardData:
	return ContentDB.road_card(id)


func _check(passed: bool, message: String) -> void:
	if passed:
		return
	_failures += 1
	print("[road-cards] %s" % message)


func _finish() -> void:
	RunState.road_cards = []
	RunState.pending_road_cards = []
	Modifiers.rebuild()
	MetaState.resume_saves()
	if _failures == 0:
		print("[road-cards] PASS - %d checks across %d cards; the hand holds"
			% [_checked, ContentDB.road_cards.size()])
	else:
		push_error("[road-cards] FAIL - %d of %d" % [_failures, _checked])
	get_tree().quit(1 if _failures > 0 else 0)
