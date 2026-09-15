extends Node

## Eggs, and the ways a nest quietly stops being one.
##
##   godot --headless --path game res://tools/nesting_check.tscn
##
## Owner brief, 2026-09-15 (the forwarded essay on egg and nesting ecology).
## Half this roster is birds, reptiles and insects, and what they do is leave
## something behind and come back to it.
##
## **Five ways this goes wrong and none of them errors:**
##
## - **A clutch is a second route to a rarer animal.** The inheritance, the
##   shine and the act's budget are decided in `_roll_clutch` for both kinds of
##   birth; a nest that rolled its own would be a way to farm rarity by waiting.
## - **It hatches on the clock.** Then a beast standing still is a hatchery, and
##   the population cap the frame was measured under stops meaning anything.
##   Road walked, exactly as a crop grows.
## - **An egg pays power.** It pays Food and a sighting - a run currency and the
##   credit a birth already pays. An attribute, a bond or a piece of gear here
##   would be the third power scale this project keeps refusing.
## - **Robbery is free.** Taking an egg has to cost something the player feels,
##   and what it costs is that the species comes for them.
## - **The grudge outlives its region.** A species angered in Act I hunting the
##   party in Act X is a difficulty setting picked up by accident.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_content_is_authored()
	await _test_a_nest_is_laid_hatched_and_robbed()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[nesting] PASS - %d checks: a clutch is rolled once, hatches on "
			+ "road rather than on the clock, pays a meal and a sighting, and "
			+ "costs a species that comes for you") % _checks)
	else:
		push_error("[nesting] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **Somebody has to lay.** A flag authored on nothing is a system that never
## runs, which is the failure this project has paid for more than any other.
func _test_the_content_is_authored() -> void:
	var layers: Array[WildlifeData] = []
	for value: Variant in ContentDB.wildlife_kinds.values():
		var kind := value as WildlifeData
		if kind != null and kind.lays_eggs:
			layers.append(kind)
	_check(layers.size() >= 6,
		"only %d species lay eggs, so most of the roster that should is not"
			% layers.size())
	for kind: WildlifeData in layers:
		_check(kind.breeds,
			("%s lays eggs and never breeds, so it can never lay one")
				% kind.id)
		_check(kind.incubation_distance >= 0.0,
			"%s authors a negative incubation" % kind.id)
	_check(ResourceLoader.exists("res://art/battlefield/nest.png")
			and ResourceLoader.exists("res://art/battlefield/nest_empty.png"),
		"a nest needs a picture full and a picture empty")


## **Driven on the real field**, because every one of the bounds above is about
## behaviour rather than about a number in a file.
func _test_a_nest_is_laid_hatched_and_robbed() -> void:
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	var nests: WildlifeNests = field.nests() if field != null else null
	var animals: Wildlife = field.wildlife() if field != null else null
	_check(nests != null and animals != null,
		"the battlefield must carry nests and wildlife")
	if nests == null or animals == null:
		run.queue_free()
		return

	var kind: WildlifeData = null
	for value: Variant in ContentDB.wildlife_kinds.values():
		var candidate := value as WildlifeData
		if candidate != null and candidate.lays_eggs:
			kind = candidate
			break
	if kind == null:
		_check(false, "the gate needs a laying species")
		run.queue_free()
		return

	var at := Vector2(700.0, 700.0)
	var clutch: Array[Dictionary] = []
	for index: int in 3:
		clutch.append({"sex": 0, "rarity": int(kind.rarity), "shiny": false,
			"stage": 0, "born_act": RunState.act, "parents": [0, 0], "family": 0})
	nests.lay(kind, at, clutch, 0)
	_check(nests.report().size() == 1, "a laid clutch must be on the ground")

	# **The clock hatches nothing.** Twenty frames of standing still is the test
	# that keeps a nest from being a thing to farm by waiting.
	for _frame: int in 20:
		await get_tree().process_frame
	_check(nests.report().size() == 1,
		"time alone hatched a nest - incubation must be road walked")

	# **And the road does.** Driven rather than walked, because a gate has no
	# beast; `walk` is the same function the road calls.
	var before: int = animals.living().size()
	# **Its own incubation, not the roster default.** A species authors how far
	# its clutch has to travel, and walking the default hatched nothing for any
	# species that asks for more - which reads exactly like a nest that never
	# opens.
	nests.walk(maxf(kind.incubation_distance,
		Balance.NEST_INCUBATION_DISTANCE) + 1.0)
	await get_tree().process_frame
	_check(nests.report().is_empty(), "a full incubation must open the nest")
	_check(animals.living().size() > before,
		"hatching must put animals on the road (%d from %d)"
			% [animals.living().size(), before])

	# **Robbery: a meal, a sighting, and a species with a reason.**
	var again: Array[Dictionary] = []
	for index: int in 6:
		again.append({"sex": 0, "rarity": int(kind.rarity), "shiny": false,
			"stage": 0, "born_act": RunState.act, "parents": [0, 0], "family": 0})
	nests.lay(kind, at, again, 0)
	var food: int = RunState.currency(RunState.FOOD)
	var hero: Hero = field.hero
	if hero != null:
		hero.global_position = at + Vector2(40.0, 0.0)
	# **The whole clutch, not one egg.** `RunState.gain_currency` trims Food at
	# the door with a fractional carry (`CURRENCY_YIELD_SCALE`, 2026-09-13), so
	# a single small gain legitimately rounds to nothing and carries - and a
	# gate that robbed once read "an egg is worth no meal" about half the time,
	# which is a coin toss wearing a gate's clothes.
	for _egg: int in 6:
		nests.call("_rob", 0, hero)
	_check(RunState.currency(RunState.FOOD) > food,
		"a clutch must be worth a meal (%d from %d)"
			% [RunState.currency(RunState.FOOD), food])
	_check(nests.is_angry(kind.id),
		"%s had an egg taken and did not mind" % kind.id)
	# **And it forgives with the region.**
	nests.forget()
	_check(not nests.is_angry(kind.id),
		"a grudge must not outlive the act it was earned in")

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[nesting] " + why)
