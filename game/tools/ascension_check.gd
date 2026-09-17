extends Node

## The Gatekeeper's ladder, and the third capped power scale it pays out.
##
##   godot --headless --path game res://tools/ascension_check.tscn
##
## Owner ruling, 2026-09-17: *"ascension must empower significantly so that
## Nightmare is survivable after grinding its gear"*, and three optional trials
## on Acts 3, 5 and 7 with the Gatekeeper himself on Act 9 - **a difficulty
## whose Gatekeeper has not been beaten fights him alongside the Act 10 boss.**
##
## **This project has refused a third power scale about a dozen times** - spirit
## traits, discipline depth, synergies, omens, fish, professions, materials, set
## bonuses - and every one of those refusals was about a scale *nobody was
## tuning*. The objection was never "three is too many"; it was "an untuned one
## is unmeasurable". So the ruling comes with a price, and this gate is it:
##
## - **Capped, and inside one ceiling.** A maxed Warden who has also ascended
##   stands at Resolve's ceiling rather than at the product of two - measured on
##   a real hero through `Health.damage_scale`, not read off the constants.
## - **Survival and nothing else.** At full rank, every other number the hero
##   has must be exactly what it was: level, attribute points, the health pool,
##   the damage multiplier, the walk, the mana. A rank that moved one of those
##   would be the untuned scale the refusals were about.
## - **The ladder itself pays nothing.** `MetaState.gatekeeper` is a record of
##   what was fought. The power arrives only through `ascension`, which has the
##   cap. A build where clearing a trial moved a number directly would have two
##   scales wearing one name.
## - **Modelled.** `curve_report` carries the rank now, so Nightmare and Hell
##   can be re-measured against the Warden who actually arrives at them. The
##   gate holds that the model reads the same constants the hero does.
##
## **The ways the ladder goes wrong:**
##
## - **A rung out of order.** The Gatekeeper on Act 9 reached having skipped
##   every trial is the ladder not existing; a relayed or replayed message must
##   not be able to do it either.
## - **One ladder for every difficulty.** Then clearing Normal takes the
##   Gatekeeper off Nightmare's summit, and the clause that makes the trials
##   worth taking is spent once for all three tiers.
## - **A summit that forgets.** `guards_the_summit` is the whole stake.
## - **A save that does not come back.** The ladder is per-account and per-tier,
##   and a roster that reads back empty loses every trial a player fought.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_shape_of_the_ladder()
	_test_the_rungs_are_climbed_in_order()
	_test_each_difficulty_climbs_its_own()
	_test_the_summit_remembers()
	_test_the_ladder_itself_pays_nothing()
	_test_it_reads_back()
	await _test_the_scale_on_a_real_hero()
	_test_the_model_carries_it()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[ascension] PASS - %d checks: the ladder climbs in order and per "
			+ "difficulty, an unbeaten Gatekeeper holds the summit, the rank is "
			+ "capped inside one ceiling, it moves survival and nothing else, and "
			+ "the curve model carries it") % _checks)
	else:
		push_error("[ascension] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _clear() -> void:
	MetaState.gatekeeper.clear()
	MetaState.ascension = 0


func _a_tier() -> String:
	var tiers: Array[CampaignTierData] = ContentDB.tiers_sorted()
	return tiers[0].id if not tiers.is_empty() else "normal"


# --- The ladder ---------------------------------------------------------------


## **A trial on every act is the road rather than a detour off it.**
func _test_the_shape_of_the_ladder() -> void:
	var acts: Array[int] = GatekeeperTrials.STAGE_ACTS
	_check(acts.size() == GatekeeperTrials.STAGES,
		"the ladder offers %d acts against %d rungs - a rung with no act is a "
			% [acts.size(), GatekeeperTrials.STAGES]
			+ "trial nobody can ever take")
	var last: int = 0
	for act: int in acts:
		_check(act > last + 1,
			("a trial on act %d follows one on act %d - consecutive rungs let a "
				+ "player clear the ladder before the campaign has taught them "
				+ "anything") % [act, last])
		_check(act >= 1 and act <= Balance.ACT_COUNT,
			"act %d is not on a road of %d acts" % [act, Balance.ACT_COUNT])
		last = act
	_check(acts.size() >= 2 and acts[acts.size() - 1] < Balance.ACT_COUNT,
		("the last rung is on act %d of %d - the Gatekeeper has to come *before* "
			+ "the last act's boss, or the ladder and the summit are one fight")
			% [acts[acts.size() - 1], Balance.ACT_COUNT])

	for act: int in range(1, Balance.ACT_COUNT + 1):
		var stage: int = GatekeeperTrials.stage_for_act(act)
		if acts.has(act):
			_check(stage == acts.find(act) + 1,
				"act %d offers rung %d rather than %d" % [act, stage,
					acts.find(act) + 1])
		else:
			_check(stage == 0, "act %d offers rung %d and should offer none"
				% [act, stage])

	# The cap has to be able to hold what the ladder pays, or the last tier's
	# last trial silently grants nothing.
	_check(Balance.ASCENSION_MAX >= GatekeeperTrials.total_rungs(),
		("the ladder pays %d rungs across every difficulty against a cap of %d - "
			+ "the rungs past the cap are trials that reward nothing")
			% [GatekeeperTrials.total_rungs(), Balance.ASCENSION_MAX])


## **A rung is only ever offered in order.**
func _test_the_rungs_are_climbed_in_order() -> void:
	_clear()
	var tier: String = _a_tier()
	var acts: Array[int] = GatekeeperTrials.STAGE_ACTS

	_check(GatekeeperTrials.may_enter(acts[0], tier),
		"the first trial is not open on a fresh ladder")
	for index: int in range(1, acts.size()):
		_check(not GatekeeperTrials.may_enter(acts[index], tier),
			("act %d's trial opened with nothing cleared - the Gatekeeper reached "
				+ "having skipped every rung is the ladder not existing")
				% acts[index])

	# Out of order is refused at the door that writes, not only at the door that
	# offers: a relayed or replayed message never reaches `may_enter`.
	_check(not GatekeeperTrials.record_cleared(tier, GatekeeperTrials.STAGES),
		"the last rung was recorded with none of the rungs before it")
	_check(GatekeeperTrials.cleared_on(tier) == 0,
		"a refused record still moved the ladder to %d"
			% GatekeeperTrials.cleared_on(tier))
	_check(not GatekeeperTrials.record_cleared(tier, 0),
		"rung zero was recorded")
	_check(not GatekeeperTrials.record_cleared(tier, GatekeeperTrials.STAGES + 1),
		"a rung past the end of the ladder was recorded")

	for index: int in acts.size():
		var stage: int = index + 1
		_check(GatekeeperTrials.may_enter(acts[index], tier),
			"rung %d did not open with %d cleared" % [stage, index])
		_check(GatekeeperTrials.record_cleared(tier, stage),
			"rung %d was refused in order" % stage)
		_check(not GatekeeperTrials.record_cleared(tier, stage),
			"rung %d was recorded twice" % stage)
		_check(GatekeeperTrials.cleared_on(tier) == stage,
			"the ladder reads %d after climbing rung %d"
				% [GatekeeperTrials.cleared_on(tier), stage])

	for act: int in acts:
		_check(not GatekeeperTrials.may_enter(act, tier),
			"act %d still offers a trial on a finished ladder" % act)


## **Nightmare and Hell each run their own.**
func _test_each_difficulty_climbs_its_own() -> void:
	var tiers: Array[CampaignTierData] = ContentDB.tiers_sorted()
	_check(tiers.size() >= 2,
		"there must be more than one difficulty for the ladder to be per-difficulty")
	if tiers.size() < 2:
		return
	_clear()
	var first: String = tiers[0].id
	var second: String = tiers[1].id
	for stage: int in range(1, GatekeeperTrials.STAGES + 1):
		GatekeeperTrials.record_cleared(first, stage)
	_check(GatekeeperTrials.cleared_on(first) == GatekeeperTrials.STAGES,
		"%s's ladder is not finished" % first)
	_check(GatekeeperTrials.cleared_on(second) == 0,
		("clearing %s's ladder moved %s's to %d - the clause that makes the "
			+ "trials worth taking would be spent once for every difficulty")
			% [first, second, GatekeeperTrials.cleared_on(second)])
	_check(GatekeeperTrials.may_enter(GatekeeperTrials.STAGE_ACTS[0], second),
		"%s's first trial did not open after %s was finished" % [second, first])


## **The stake.**
func _test_the_summit_remembers() -> void:
	_clear()
	var tier: String = _a_tier()
	for stage: int in range(1, GatekeeperTrials.STAGES + 1):
		_check(GatekeeperTrials.guards_the_summit(tier),
			("the Gatekeeper left the summit with %d of %d rungs climbed - the "
				+ "ladder is the choice between paying four times on the way up "
				+ "or once beside Kharok") % [stage - 1, GatekeeperTrials.STAGES])
		GatekeeperTrials.record_cleared(tier, stage)
	_check(not GatekeeperTrials.guards_the_summit(tier),
		"the Gatekeeper still holds the summit of a finished ladder")

	var tiers: Array[CampaignTierData] = ContentDB.tiers_sorted()
	if tiers.size() >= 2:
		_check(GatekeeperTrials.guards_the_summit(tiers[1].id),
			"beating one difficulty's Gatekeeper took him off another's summit")


## **A record of what was fought, not a reward in itself.**
func _test_the_ladder_itself_pays_nothing() -> void:
	_clear()
	var tier: String = _a_tier()
	var level: int = MetaState.hero_level
	var points: int = MetaState.hero_attribute_points
	var marks: int = MetaState.marks
	var shards: int = MetaState.shards
	var tools: int = MetaState.tools

	# Written straight into the record, bypassing `record_cleared`, because what
	# is being asked is whether *the record* is worth anything - the rank it
	# grants is measured separately and has the cap.
	MetaState.gatekeeper[tier] = GatekeeperTrials.STAGES
	_check(MetaState.hero_level == level,
		"a cleared ladder moved the hero's level")
	_check(MetaState.hero_attribute_points == points,
		"a cleared ladder granted attribute points")
	_check(MetaState.marks == marks and MetaState.shards == shards,
		"a cleared ladder moved a currency")
	_check(MetaState.tools == tools, "a cleared ladder paid a Tool")
	_check(MetaState.ascension == 0,
		("the record alone granted %d ascension - the power must come through "
			+ "`grant_ascension_rank`, which is what carries the cap")
			% MetaState.ascension)


## **A ladder that does not survive a save loses every trial a player fought.**
func _test_it_reads_back() -> void:
	_clear()
	var tier: String = _a_tier()
	GatekeeperTrials.record_cleared(tier, 1)
	GatekeeperTrials.record_cleared(tier, 2)
	var written: String = MetaState.serialized_save()
	var parsed: Variant = JSON.parse_string(written)
	_check(parsed is Dictionary, "the save must be a dictionary")
	if not (parsed is Dictionary):
		return
	_clear()
	MetaState.adopt_save(parsed as Dictionary)
	_check(GatekeeperTrials.cleared_on(tier) == 2,
		"a ladder of 2 read back as %d" % GatekeeperTrials.cleared_on(tier))

	# Additive: a save from before the ladder has no key at all, and reads as an
	# empty ladder on every tier - which is what a new account is.
	var older: Dictionary = (parsed as Dictionary).duplicate(true)
	older.erase("gatekeeper")
	var hero: Dictionary = older.get("hero", {}) as Dictionary
	hero.erase("gatekeeper")
	_clear()
	MetaState.adopt_save(older)
	_check(GatekeeperTrials.cleared_on(tier) == 0,
		"a save with no ladder in it read back as %d rungs"
			% GatekeeperTrials.cleared_on(tier))

	# A tier the roster does not have is dropped rather than trusted, the rule
	# the pen applies to a species it cannot draw.
	_clear()
	MetaState.gatekeeper["a_difficulty_that_does_not_exist"] = 3
	_check(GatekeeperTrials.cleared_on(_a_tier()) == 0,
		"a dangling tier id leaked into a real tier's ladder")


# --- The scale ----------------------------------------------------------------


## **Measured on a real hero, through the same door every blow goes through.**
##
## Reading the constants back would pass on a build where the hero multiplied
## them a second time, or applied ascension outside Resolve's ceiling - which is
## the one arrangement the re-cut had to avoid.
func _test_the_scale_on_a_real_hero() -> void:
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	var who: Hero = field.hero if field != null else null
	_check(who != null, "there must be a hero to ascend")
	if who == null:
		run.queue_free()
		return

	# **Resolve is put to zero for the measurement, and that is the whole
	# reason this reads the same on every machine.** The first run of this gate
	# reported 12.8% against a 12.0% cap, because it was measuring the owner's
	# live save: mitigation is a *sum*, so a Warden who already has Resolve
	# points makes ascension's share a larger fraction of what is left. That is
	# the `curve-report-reads-the-account` lesson arriving in a new gate - a
	# model that reads state measures whatever state it was handed.
	var spent_before: Array = RunState.hero_attributes.duplicate()
	RunState.hero_attributes[RunState.Attribute.RESOLVE] = 0

	var readings: Dictionary = {}
	for rank: int in [0, Balance.ASCENSION_MAX]:
		MetaState.ascension = rank
		who.call("_apply_permanent_bonuses")
		readings[rank] = {
			"damage_scale": who.health.damage_scale,
			"max_hp": who.health.max_hp,
			"damage": who.damage_multiplier(),
			"speed": who.move_speed(),
			"mana": who.mana_max(),
			"level": MetaState.hero_level,
			"points": MetaState.hero_attribute_points,
		}

	var plain: Dictionary = readings[0] as Dictionary
	var ascended: Dictionary = readings[Balance.ASCENSION_MAX] as Dictionary

	# --- It moves survival ---
	_check(float(ascended["damage_scale"]) < float(plain["damage_scale"]),
		("%d ranks changed nothing a blow can feel (%.4f -> %.4f) - the owner "
			+ "asked for ascension to empower significantly")
			% [Balance.ASCENSION_MAX, float(plain["damage_scale"]),
				float(ascended["damage_scale"])])
	# **The difference, not the ratio.** `damage_scale` is `1 - mitigation`, so
	# subtracting the two gives exactly the mitigation ascension added - which
	# is the quantity the cap bounds. A ratio measures ascension's share of
	# whatever was left after everything else, which is a different number.
	var taken: float = float(plain["damage_scale"]) \
		- float(ascended["damage_scale"])
	_check(taken <= Balance.ASCENSION_MITIGATION_CAP + 0.002,
		("a full ladder takes %.1f%% off every blow against a cap of %.1f%%")
			% [taken * 100.0, Balance.ASCENSION_MITIGATION_CAP * 100.0])
	_check(taken >= Balance.ASCENSION_MITIGATION_CAP - 0.002,
		("a full ladder reaches only %.1f%% of its own %.1f%% cap - the rungs "
			+ "past that point are trials that pay nothing")
			% [taken * 100.0, Balance.ASCENSION_MITIGATION_CAP * 100.0])

	# --- And nothing else ---
	for key: String in ["max_hp", "damage", "speed", "mana", "level", "points"]:
		_check(is_equal_approx(float(plain[key]), float(ascended[key])),
			("%d ascension ranks moved %s from %.3f to %.3f - the third scale is "
				+ "survival and nothing else, or it is the untuned one this "
				+ "project has refused a dozen times")
				% [Balance.ASCENSION_MAX, key, float(plain[key]),
					float(ascended[key])])

	# --- One ceiling, not two ---
	#
	# The reason the re-cut is safe: a maxed Warden who also ascended stands at
	# Resolve's ceiling rather than at the product of it and ascension's.
	var spent: Array = spent_before.duplicate()
	RunState.hero_attributes[RunState.Attribute.RESOLVE] = 9999
	MetaState.ascension = Balance.ASCENSION_MAX
	who.call("_apply_permanent_bonuses")
	var both: float = 1.0 - who.health.damage_scale
	_check(both <= Balance.HERO_RESOLVE_MITIGATION_CAP + 0.002,
		("a maxed-Resolve ascended Warden takes %.1f%% less against Resolve's own "
			+ "%.1f%% ceiling - the two scales must stand inside one ceiling "
			+ "rather than multiply") % [both * 100.0,
			Balance.HERO_RESOLVE_MITIGATION_CAP * 100.0])
	_check(Balance.ASCENSION_MITIGATION_CAP < Balance.HERO_RESOLVE_MITIGATION_CAP,
		("ascension's ceiling is %.2f against Resolve's %.2f - the third scale's "
			+ "cap has to be the lower one or it decides where mitigation stops")
			% [Balance.ASCENSION_MITIGATION_CAP,
				Balance.HERO_RESOLVE_MITIGATION_CAP])
	RunState.hero_attributes = spent
	MetaState.ascension = 0
	who.call("_apply_permanent_bonuses")

	# Quiet, then gone, then ten frames - the rule every headless gate here
	# follows, because a sound still playing is 'resources still in use' and a
	# red gate that has nothing to do with the thing being checked.
	Sfx.stop_immediately()
	run.queue_free()
	for _frame: int in 10:
		await get_tree().process_frame


## **An untuned scale is the thing that stays forbidden**, so the model has to
## carry it - and has to read the same constants the hero does, or the two
## drift and only the model says so.
func _test_the_model_carries_it() -> void:
	# **Instantiated for its arithmetic, never run.** The report's own `_ready`
	# walks a whole campaign; what is wanted here is the two static answers it
	# gives, read through the real script so the model and the hero cannot be
	# checked against two different copies of one constant.
	var script := load("res://tools/curve_report.gd") as GDScript
	_check(script != null, "the curve report must be loadable")
	if script == null:
		return
	var report: Object = script.new()
	if report == null:
		_check(false, "the curve report must be instantiable")
		return
	var plain: float = float(report.call("ascension_uptime", 0))
	_check(is_equal_approx(plain, 1.0),
		"a Warden with no rank is modelled at %.3f uptime rather than 1" % plain)
	var full: float = float(report.call("ascension_uptime", Balance.ASCENSION_MAX))
	_check(full > plain,
		"a full ladder is worth nothing at all to the model (%.3f)" % full)
	var wanted: float = 1.0 / (1.0 - minf(Balance.ASCENSION_MITIGATION_CAP,
		Balance.HERO_RESOLVE_MITIGATION_CAP))
	_check(is_equal_approx(full, wanted),
		("the model reads a full ladder as %.4f uptime against the %.4f its own "
			+ "constants give - a model that stops agreeing with the hero is the "
			+ "fault this project has paid for three times") % [full, wanted])

	# And the rank a tier expects is derived from the ladder rather than typed
	# into a run script, so the day a rung is added Nightmare's expectation moves.
	var tiers: Array[CampaignTierData] = ContentDB.tiers_sorted()
	if tiers.size() >= 2:
		var first: int = int(report.call("expected_rank_for_tier", tiers[0].id))
		var second: int = int(report.call("expected_rank_for_tier", tiers[1].id))
		_check(first == 0,
			"the first difficulty expects %d ranks - a new Warden has none" % first)
		_check(second == GatekeeperTrials.STAGES,
			("the second difficulty expects %d ranks against a ladder of %d - a "
				+ "Warden arriving there has climbed the one behind it")
				% [second, GatekeeperTrials.STAGES])

	if report is Node:
		(report as Node).queue_free()


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[ascension] " + why)
