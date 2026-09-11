extends Node

## A portent must actually cost something, and reach the numbers it names.
##
## Owner brief, 2026-09-10, from the ideas document: Infernal Hordes' trick of
## letting a player wreck their own run for more reward.
##
## **The failure this gate exists for is an omen that is a free upgrade.** A
## card reading "Bane: enemies come faster / Boon: everything drops more" is a
## sentence, and a sentence is not a mechanic. If the bane's effect key is
## misspelt, or points at something nothing reads, or is signed the wrong way,
## the card still draws, still says the words, and quietly hands out the boon
## for nothing. Nothing errors. The run gets easier the more portents you read,
## which is the exact opposite of the design.
##
## So every claim on every card is checked against `Modifiers` for real: the
## omen is taken, the table is rebuilt, and the number is read back out.

var _failures: int = 0
var _checked: int = 0
var _finished: int = 0
const EXPECTED_TESTS: int = 7

## Which direction each effect key helps the player.
##
## Written down here rather than inferred, because "positive is good" is false
## for half of them: `build_cost` and `enemy_damage` hurt when they rise, and
## `dash_cooldown` hurts when it rises too. An omen's bane has to move a number
## the *wrong* way for the player, and that cannot be checked without knowing
## which way is wrong for each one.
const HELPS_WHEN_POSITIVE: Dictionary = {
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


func _ready() -> void:
	MetaState.hold_saves()
	await get_tree().process_frame

	_test_there_are_enough_to_choose_from()
	_test_every_half_is_authored()
	_test_every_effect_key_is_real()
	_test_the_bane_actually_costs_something()
	_test_a_taken_omen_reaches_the_modifier_table()
	_test_they_stack_and_a_run_clears_them()
	_test_the_same_seed_shows_the_same_three()

	if _finished != EXPECTED_TESTS:
		_check(false, "only %d of %d tests ran to completion" % [_finished, EXPECTED_TESTS])
	_finish()


## Enough that a choice is a choice, at every act.
##
## `Run._offer_omens` refuses to open at all rather than showing two cards, so a
## thin pool is a feature that silently never appears - which is the quietest
## way for content to be missing.
func _test_there_are_enough_to_choose_from() -> void:
	_checked += 1
	_check(ContentDB.omens.size() >= Balance.OMEN_OFFER_COUNT * 2,
		("%d omens is not enough to offer %d of them across three acts without "
			+ "repeating the whole pool") % [ContentDB.omens.size(),
			Balance.OMEN_OFFER_COUNT])
	# Three acts are read, and an omen already taken is out of the pool, so the
	# third act needs the pool to still hold a full offer.
	var earliest: int = 0
	for id: Variant in ContentDB.omens:
		if _omen(String(id)).first_act <= 1:
			earliest += 1
	_checked += 1
	_check(earliest >= Balance.OMEN_OFFER_COUNT,
		"only %d omens may be read in Act I, and %d are offered at once"
			% [earliest, Balance.OMEN_OFFER_COUNT])
	_finished += 1


## Both halves, and words for both.
func _test_every_half_is_authored() -> void:
	for id: Variant in ContentDB.omens:
		var omen: OmenData = _omen(String(id))
		_checked += 1
		_check(not omen.bane_effect.is_empty() and not omen.boon_effect.is_empty(),
			"%s is missing a half; a portent with one side is a relic" % omen.id)
		_checked += 1
		_check(not omen.bane_text.strip_edges().is_empty()
				and not omen.boon_text.strip_edges().is_empty(),
			"%s does not say what it costs and gives" % omen.id)
		_checked += 1
		_check(not omen.portent.strip_edges().is_empty(),
			("%s has no portent line. The road is supposed to be telling you "
				+ "something, and a number is not it") % omen.id)
		# **And the card has a face.** Omens deliberately had no art until
		# 2026-09-10; now that they do, a new portent authored without one draws
		# a blank card, and the portent screen is a choice between three of them
		# read under time pressure. The asset report catches a manifest row with
		# no file; nothing but this catches a `.tres` with no row.
		_checked += 1
		_check(ResourceLoader.exists(omen.get_sprite_path()),
			"%s has no icon at %s" % [omen.id, omen.get_sprite_path()])
	_finished += 1


## Every key names something `Modifiers` actually resolves.
##
## A misspelt key is the quiet one: it lands in the table under a name nothing
## reads, so the effect simply does not happen and the card lies.
func _test_every_effect_key_is_real() -> void:
	for id: Variant in ContentDB.omens:
		var omen: OmenData = _omen(String(id))
		for key: String in [omen.bane_effect, omen.boon_effect]:
			_checked += 1
			_check(HELPS_WHEN_POSITIVE.has(key),
				("%s names the effect '%s', which `Modifiers` does not resolve; "
					+ "it will land in the table under a name nothing reads")
					% [omen.id, key])
	_finished += 1


## **The one this gate is for.** The bane has to hurt.
func _test_the_bane_actually_costs_something() -> void:
	for id: Variant in ContentDB.omens:
		var omen: OmenData = _omen(String(id))
		if not HELPS_WHEN_POSITIVE.has(omen.bane_effect):
			continue
		var helps: bool = bool(HELPS_WHEN_POSITIVE[omen.bane_effect])
		var hurts: bool = omen.bane_magnitude < 0.0 if helps \
			else omen.bane_magnitude > 0.0
		_checked += 1
		_check(hurts,
			("%s's bane (%s %+.2f) helps the player. The card promises a price "
				+ "and charges none, which makes reading portents free")
				% [omen.id, omen.bane_effect, omen.bane_magnitude])

		if not HELPS_WHEN_POSITIVE.has(omen.boon_effect):
			continue
		var boon_helps: bool = bool(HELPS_WHEN_POSITIVE[omen.boon_effect])
		var good: bool = omen.boon_magnitude > 0.0 if boon_helps \
			else omen.boon_magnitude < 0.0
		_checked += 1
		_check(good, "%s's boon (%s %+.2f) is a second cost"
			% [omen.id, omen.boon_effect, omen.boon_magnitude])
	_finished += 1


## Taking one moves the number a tower would read.
##
## Driven through `Modifiers.rebuild` rather than by inspecting the resource: the
## claim is that the card reaches the game, and the resource cannot say that.
func _test_a_taken_omen_reaches_the_modifier_table() -> void:
	for id: Variant in ContentDB.omens:
		var omen: OmenData = _omen(String(id))
		RunState.taken_omens = []
		Modifiers.rebuild()
		var before_bane: float = Modifiers.value(omen.bane_effect)
		var before_boon: float = Modifiers.value(omen.boon_effect)
		RunState.taken_omens = [omen.id]
		Modifiers.rebuild()
		_checked += 1
		_check(is_equal_approx(Modifiers.value(omen.bane_effect) - before_bane,
				omen.bane_magnitude),
			"%s's bane did not reach the modifier table" % omen.id)
		_checked += 1
		_check(is_equal_approx(Modifiers.value(omen.boon_effect) - before_boon,
				omen.boon_magnitude),
			"%s's boon did not reach the modifier table" % omen.id)
	RunState.taken_omens = []
	Modifiers.rebuild()
	_finished += 1


## They accumulate, which is the whole point, and a new run is clean.
##
## A run that inherited the last one's portents would be an account-level
## difficulty setting nobody chose - and working rule 7 does not sanction one.
func _test_they_stack_and_a_run_clears_them() -> void:
	var ids: Array[String] = []
	for id: Variant in ContentDB.omens:
		ids.append(String(id))
	ids.sort()
	var same: Array[String] = []
	var wanted: String = ""
	for id: String in ids:
		var omen: OmenData = _omen(id)
		if wanted.is_empty():
			wanted = omen.boon_effect
		if omen.boon_effect == wanted:
			same.append(id)
	if same.size() >= 2:
		RunState.taken_omens = []
		Modifiers.rebuild()
		var alone: float = 0.0
		RunState.taken_omens = [same[0]]
		Modifiers.rebuild()
		alone = Modifiers.value(wanted)
		RunState.taken_omens = [same[0], same[1]]
		Modifiers.rebuild()
		_checked += 1
		_check(Modifiers.value(wanted) > alone,
			"two portents naming the same effect did not stack")

	RunState.taken_omens = [ids[0]]
	RunState.pending_omens = [ids[0]]
	RunState.reset()
	_checked += 1
	_check(RunState.taken_omens.is_empty() and RunState.pending_omens.is_empty(),
		("portents survived into a fresh run, which is an account-level "
			+ "difficulty setting nobody chose"))
	Modifiers.rebuild()
	_finished += 1


## Both players see the same portents, without a packet.
##
## **The fault this was written for was nearly shipped.** The first version
## rolled the offer on the host only, with the unseeded global RNG. A guest was
## therefore offered nothing, its `pending_omens` stayed empty, and when the host
## chose, the guest refused an id it had never been shown - so it played the rest
## of the run without the modifiers its partner had, and nothing said so.
##
## The fix is the pattern the regional relic offer already uses: derive it on
## both machines from the run's own stream. So the property to hold is that the
## same seed produces the same three - which is also what makes a shared seed
## reproduce a run at all.
func _test_the_same_seed_shows_the_same_three() -> void:
	var first: Array[String] = []
	var second: Array[String] = []
	for pass_index: int in 2:
		RunState.reset(false, 4242)
		# **The second pass burns global randomness first**, and that is the
		# whole test. `set_seed` seeds the global stream too, so a plain
		# `Array.shuffle()` is reproducible right up until anything else rolls -
		# and two machines in a co-op run never roll the same things in the same
		# order. Named streams exist so systems cannot consume each other's
		# sequence, and this is what proves the draw uses one.
		if pass_index == 1:
			for _burn: int in 37:
				randi()
		var drawn: Array[String] = OmenData.offer([], 1, Balance.OMEN_OFFER_COUNT)
		if pass_index == 0:
			first = drawn
		else:
			second = drawn
	_checked += 1
	if not _check(first.size() == Balance.OMEN_OFFER_COUNT,
			"a seeded offer drew %d portents rather than %d"
				% [first.size(), Balance.OMEN_OFFER_COUNT]):
		_finished += 1
		return
	_checked += 1
	_check(first == second,
		("the same seed offered different portents (%s then %s) once something "
			+ "else had rolled first. The draw is on the global stream, and two "
			+ "machines in a co-op run never roll the same things in the same "
			+ "order - so the host and the guest would be shown different cards")
			% [first, second])

	# And a different seed is allowed to differ, or the draw is not a draw.
	# Sampled across many seeds rather than asserted on one pair: two seeds may
	# legitimately collide, and a gate that failed on that would be flaky.
	var seen: Dictionary = {}
	for seed_value: int in range(1, 25):
		RunState.reset(false, seed_value)
		seen[", ".join(OmenData.offer([], 3, Balance.OMEN_OFFER_COUNT))] = true
	_checked += 1
	_check(seen.size() > 1,
		"every seed offered the identical three portents, so the draw is not seeded")

	# A portent already read is out of the pool.
	RunState.reset(false, 4242)
	var taken: String = first[0]
	var again: Array[String] = OmenData.offer([taken], 1, Balance.OMEN_OFFER_COUNT)
	_checked += 1
	_check(not again.has(taken), "a portent already read was offered a second time")
	RunState.pending_omens = []
	_finished += 1


func _omen(id: String) -> OmenData:
	return ContentDB.omen(id)


func _check(condition: bool, why: String) -> bool:
	if condition:
		return true
	_failures += 1
	push_error("[omen] %s" % why)
	return false


func _finish() -> void:
	RunState.taken_omens = []
	RunState.pending_omens = []
	Modifiers.rebuild()
	MetaState.resume_saves()
	if _failures == 0:
		print("[omen] PASS - %d checks; every portent charges what it promises"
			% _checked)
	else:
		push_error("[omen] FAIL - %d of %d" % [_failures, _checked])
	get_tree().quit(1 if _failures > 0 else 0)
