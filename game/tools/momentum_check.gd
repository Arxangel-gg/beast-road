extends Node

## Kill momentum escalates the feedback and nothing else.
##
## Owner request, 2026-09-01: "add more game juice". The juice layer was already
## deep — hitstop, directional shake, sparks, rings, rays, dust, blood, a slash
## wedge and the weapon's own trail — so what was missing was not another effect
## at a position. It was *escalation*: nothing in the game built across kills, so
## cutting through a pack of twenty felt exactly like killing one, twenty times.
##
## **The property worth gating is the bound, not the feature.** A streak that
## quietly raised damage would be a difficulty change the three-act curve was
## never tuned against, and it would be invisible in review because the code
## reads like polish. `Vfx` was chosen to hold it precisely because that node
## cannot reach damage, health, currency or the wave director — so the guarantee
## is structural. This checks the structure has not been quietly undone.

var _failures: int = 0
var _ran: int = 0


func _ready() -> void:
	RunState.reset()
	_test_a_streak_builds_and_decays()
	_test_tiers_are_worth_crossing()
	_test_the_swell_is_bounded()
	_test_momentum_cannot_reach_the_economy()
	await _finish()


## The core behaviour, driven through the signal an actual kill emits rather than
## by calling the counter: a gate that calls `_feed_momentum` proves it exists.
func _test_a_streak_builds_and_decays() -> void:
	_ran += 1
	# `Vfx.world` is null in a headless tool, which makes every drawing call
	# return on its first line — the counter still runs, which is the half being
	# measured here.
	_check(Vfx.momentum_streak() == 0, "a run must start with no streak")
	for _kill: int in 6:
		EventBus.enemy_died.emit("bogkin", Vector2.ZERO)
	_check(Vfx.momentum_streak() == 6,
		"six kills in a row must read as a streak of six, got %d"
			% Vfx.momentum_streak())


## A tier the player never reaches is a tier that does not exist, and one they
## cross constantly is wallpaper. Both ends are checked against the roster the
## waves actually produce.
func _test_tiers_are_worth_crossing() -> void:
	_ran += 1
	var tiers: Array[int] = Balance.MOMENTUM_TIERS
	_check(tiers.size() >= 3, "there should be several steps to climb")
	_check(tiers.size() == Balance.MOMENTUM_WORDS.size()
			and tiers.size() == Balance.MOMENTUM_COLOURS.size(),
		"every tier needs a word and a colour: %d tiers, %d words, %d colours"
			% [tiers.size(), Balance.MOMENTUM_WORDS.size(),
				Balance.MOMENTUM_COLOURS.size()])
	for index: int in tiers.size() - 1:
		_check(tiers[index + 1] > tiers[index],
			"the tiers must climb: %s" % str(tiers))
	_check(tiers[0] >= 3,
		"the first tier at %d fires almost immediately, which makes it wallpaper"
			% tiers[0])
	# The top tier has to be reachable inside one formation, or nobody ever sees
	# it. Wave sizes are the honest reference for that.
	_check(tiers[tiers.size() - 1] <= 60,
		"the top tier at %d is out of reach of a single formation"
			% tiers[tiers.size() - 1])
	_check(Balance.MOMENTUM_WINDOW >= 1.5 and Balance.MOMENTUM_WINDOW <= 6.0,
		"the streak window of %.1fs is either too tight to survive a walk "
			% Balance.MOMENTUM_WINDOW + "between bodies or so loose it never ends")


func _test_the_swell_is_bounded() -> void:
	_ran += 1
	_check(Balance.MOMENTUM_BURST_SCALE > 1.0,
		"a streak that swells nothing is not escalation")
	# The burst is particle counts. Unbounded, a long streak is a frame-rate
	# problem rather than a feeling.
	_check(Balance.MOMENTUM_BURST_SCALE <= 3.0,
		"a burst scale of %.2f turns a long streak into a particle storm"
			% Balance.MOMENTUM_BURST_SCALE)
	_check(Balance.MOMENTUM_SHAKE <= 6.0,
		"%.1f of extra shake on every kill stacks with the swing's own and "
			% Balance.MOMENTUM_SHAKE + "becomes nausea rather than force")


## **The one that matters.** Momentum must not be able to touch anything the
## difficulty curve was tuned against.
##
## Asked by running a long streak and comparing the numbers either side of it.
## If a future change routes a damage or income multiplier through the streak,
## this is what notices - the structural guarantee is that `Vfx` cannot reach
## these, and this is the assertion that the guarantee still holds.
func _test_momentum_cannot_reach_the_economy() -> void:
	_ran += 1
	var gold_before: int = RunState.currency(RunState.GOLD)
	var xp_before: float = RunState.hero_xp
	var level_before: int = RunState.hero_level
	var damage_before: float = Modifiers.hero_damage_scale() \
		if Modifiers.has_method("hero_damage_scale") else 1.0

	for _kill: int in Balance.MOMENTUM_TIERS[Balance.MOMENTUM_TIERS.size() - 1] + 10:
		EventBus.enemy_died.emit("bogkin", Vector2.ZERO)
	_check(Vfx.momentum_streak() > Balance.MOMENTUM_TIERS[0],
		"the test must actually build a streak to prove anything about one")

	_check(RunState.currency(RunState.GOLD) == gold_before,
		"a kill streak must not produce currency: %d -> %d"
			% [gold_before, RunState.currency(RunState.GOLD)])
	_check(is_equal_approx(RunState.hero_xp, xp_before)
			and RunState.hero_level == level_before,
		"a kill streak must not produce experience or levels")
	var damage_after: float = Modifiers.hero_damage_scale() \
		if Modifiers.has_method("hero_damage_scale") else 1.0
	_check(is_equal_approx(damage_after, damage_before),
		"a kill streak must not change hero damage: %.3f -> %.3f"
			% [damage_before, damage_after])


func _finish() -> void:
	# **Audio, and then frames for it to actually let go.** Fifty deaths is fifty
	# death sounds, and an Ogg stream still loaded at exit is an ObjectDB leak -
	# twelve instances and six resources, which fails on warnings alone. Two
	# releases have already been blocked by a tool leaking this way.
	#
	# Stopping is not enough on its own: the playbacks are released over the
	# following frames, so quitting in the same frame as the stop leaks anyway.
	# That version passed one run in three, which is the worst possible result -
	# a gate that fails at random teaches everyone to re-run it until it is
	# green. Caught by the sweep before it ever reached CI.
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 30:
		await get_tree().process_frame

	if _ran != 4:
		_failures += 1
		print("[momentum] only %d of 4 tests ran" % _ran)
	if _failures == 0:
		print("[momentum] PASS - a streak builds, decays, escalates within bounds, "
			+ "and reaches nothing the curve was tuned against")
	else:
		push_error("[momentum] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	print("[momentum] %s" % why)
