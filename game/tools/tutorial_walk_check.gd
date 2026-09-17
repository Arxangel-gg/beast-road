extends Node

## The Walk: the stops, the ledger, and everything it promises not to touch.
##
##   godot --headless --path game res://tools/tutorial_walk_check.tscn
##
## Owner brief, 2026-09-17: a guided valley that teaches the essentials and ends
## with the chain coming off - and, critically, a tutorial that hands a new
## player a fair start without handing anybody a second account's worth of
## progress.
##
## **The ways this goes wrong, hardest first:**
##
## - **The ledger pays every launch.** A once-only flag that is written and
##   never read back fires on every start. This project has shipped exactly that
##   fault and it handed out a free sword each time, so the guard is round
##   tripped through the real save here rather than assumed.
## - **The Walk settles as a run.** `_settle_run` writes statistics, pays Tools,
##   awards a Sigil, completes Chronicle objectives, publishes a score, banks the
##   Treasury cache and opens co-op. The tutorial promises none of that happens;
##   the honest place to keep that promise is the first line of the function
##   that would break it, and the honest way to check it is to call the function.
## - **A statistic moves.** `runs_started` is what offers the Walk in the first
##   place and `best_distance` decides which acts may be started from. A Walk
##   that wrote either would unlock an act for somebody who has not played, and
##   hide the tutorial from them.
## - **The Walk grants power.** Gold, a level, a spell, worn gear or a tower
##   unlock would each move a number `curve_report` and the opening envelope are
##   measured against.
## - **A stop nobody can finish.** An objective the game never emits, or an
##   anchor the placer does not know, is a stop the Walk waits at for ever - and
##   a tutorial that cannot be finished is worse than no tutorial.
## - **The coach and the Walk teach at once.** Two cards in one corner is
##   neither of them teaching.

## Every anchor `TutorialWalk._place` knows how to resolve. A stop naming
## anything else falls back to the road, which is survivable and is not what the
## author meant - so it is a failure here rather than a surprise on the field.
const ANCHORS: Array[String] = ["road", "pond", "trunk", "seam", "build", "town"]

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_stops_are_walkable()
	_test_the_ledger_pays_once()
	_test_the_guard_survives_a_save()
	_test_the_account_is_unmoved()
	_test_the_walk_never_settles()
	_test_it_is_offered_only_to_a_new_account()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[walk] PASS - %d checks: %d stops in order and finishable, the "
			+ "ledger pays once and survives a save, and the valley moves no "
			+ "statistic, no level and no purse")
			% [_checks, ContentDB.tutorial_stops.size()])
	else:
		push_error("[walk] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _stops() -> Array[TutorialStopData]:
	var out: Array[TutorialStopData] = []
	for value: Variant in ContentDB.tutorial_stops.values():
		var stop := value as TutorialStopData
		if stop != null:
			out.append(stop)
	out.sort_custom(func(a: TutorialStopData, b: TutorialStopData) -> bool:
		return a.order < b.order)
	return out


func _test_the_stops_are_walkable() -> void:
	var stops: Array[TutorialStopData] = _stops()
	_check(stops.size() >= 12,
		"the valley has a walk in it (%d stops)" % stops.size())
	var seen: Dictionary = {}
	var last: int = 0
	for stop: TutorialStopData in stops:
		_check(not seen.has(stop.order),
			"%s is the only stop at order %d" % [stop.id, stop.order])
		seen[stop.order] = true
		_check(stop.order > last,
			"%s comes after the stop before it (%d then %d)"
				% [stop.id, last, stop.order])
		last = stop.order
		_check(ANCHORS.has(stop.anchor),
			"%s names an anchor the Walk can resolve, not \"%s\""
				% [stop.id, stop.anchor])
		_check(stop.done >= 0 and stop.done < TutorialStopData.Done.size(),
			"%s finishes on something the enum has (%d)" % [stop.id, stop.done])
		_check(stop.instruction.strip_edges().length() >= 20,
			"%s says something worth reading" % stop.id)
		_check(stop.seconds >= 4.0,
			"%s stands long enough to be read (%.1fs)" % [stop.id, stop.seconds])
		_check(stop.count >= 1, "%s asks for at least one of whatever it counts" % stop.id)
		_check(stop.radius > 0.0, "%s has ground to stand on" % stop.id)

	# **Every objective is one something in the game actually emits.** A stop
	# waiting on a signal nothing sends is a Walk that stops there for ever, and
	# nothing about it errors: the card simply never changes.
	var wired: Array[int] = [
		TutorialStopData.Done.ENTERED,
		TutorialStopData.Done.KILLED,
		TutorialStopData.Done.GATHERED,
		TutorialStopData.Done.CAUGHT,
		TutorialStopData.Done.BUILT,
		TutorialStopData.Done.WAVE_HELD,
	]
	for stop: TutorialStopData in stops:
		_check(wired.has(stop.done),
			"%s finishes on something `TutorialWalk` listens for" % stop.id)


## **Paid once, and the second call pays nothing.**
##
## Driven rather than read: the guard is a field on the account, and a check
## that asked the field instead of calling the function would pass with the
## guard removed.
func _test_the_ledger_pays_once() -> void:
	MetaState.tutorial_walk_done = false
	MetaState.unlocked_blueprints.clear()
	MetaState.spirit_bonded.clear()
	MetaState.fish.clear()
	MetaState.materials.clear()
	MetaState.profession_xp.clear()

	var given: Dictionary = TutorialGrants.award()
	_check(not given.is_empty(), "the first walk is paid")
	_check(MetaState.tutorial_walk_done, "and the guard is set by paying it")
	_check(MetaState.unlocked_blueprints.size() == 1,
		"one plan, not a ladder (%d)" % MetaState.unlocked_blueprints.size())
	_check(MetaState.spirit_bonded.size() == 1,
		"one bond (%d)" % MetaState.spirit_bonded.size())
	_check(not MetaState.materials.is_empty(), "a handful of stock")
	_check(not MetaState.profession_xp.is_empty(), "and a little practice")

	var blueprints: int = MetaState.unlocked_blueprints.size()
	var bonds: int = MetaState.spirit_bonded.size()
	var again: Dictionary = TutorialGrants.award()
	_check(again.is_empty(), "a second call pays nothing")
	_check(MetaState.unlocked_blueprints.size() == blueprints,
		"and hands out no second plan")
	_check(MetaState.spirit_bonded.size() == bonds,
		"and no second companion")


## **The guard is read back from disk, not only written to it.**
##
## A flag that is serialized and never parsed fires every launch. Driven through
## the loader itself rather than through a copy of the one line that reads it.
func _test_the_guard_survives_a_save() -> void:
	MetaState.tutorial_walk_done = true
	var text: String = MetaState.serialized_save()
	_check(text.contains("tutorial_walk_done"),
		"the guard is written to the save")
	MetaState.tutorial_walk_done = false
	MetaState.adopt_save(MetaState.parse_save_text(text))
	_check(MetaState.tutorial_walk_done,
		"and read back out of it - without this the ledger pays every launch")


## **Nothing the Walk grants is power**, and the check is the inverse: a set of
## account fields that must be exactly what they were.
func _test_the_account_is_unmoved() -> void:
	MetaState.tutorial_walk_done = false
	var before: Dictionary = _snapshot()
	TutorialGrants.award()
	var after: Dictionary = _snapshot()
	for key: Variant in before:
		_check(before[key] == after[key],
			"the Walk moved %s from %s to %s, which it promises not to"
				% [String(key), str(before[key]), str(after[key])])


## Everything a tutorial must not touch. Levelling and gear are the two capped
## scales the campaign tiers are tuned against; the statistics decide what the
## menu offers; the currencies are the run's and reset anyway.
func _snapshot() -> Dictionary:
	return {
		"hero_level": MetaState.hero_level,
		"hero_xp": MetaState.hero_xp,
		"attribute_points": MetaState.hero_attribute_points,
		"skill_points": MetaState.hero_skill_points,
		"ascension": MetaState.ascension,
		"tools": MetaState.tools,
		"sigils": MetaState.sigils,
		"marks": MetaState.marks,
		"shards": MetaState.shards,
		"runs_started": MetaState.runs_started,
		"runs_won": MetaState.runs_won,
		"best_distance": MetaState.best_distance,
		"highest_act": MetaState.highest_act,
		"tier_cleared": MetaState.tier_cleared,
		"tutorial_done": MetaState.tutorial_done,
		"gear": MetaState.stash.size(),
		"spells": MetaState.unlocked_spells.size(),
		"towers": MetaState.unlocked_towers.size(),
	}


## **The Walk may not settle as a run.** Called for real, because the promise
## lives on the first line of `_settle_run` and a check that asserted the flag
## instead would pass with that line removed.
func _test_the_walk_never_settles() -> void:
	var was_walking: bool = RunState.walking
	var was_active: bool = GameDirector.run_active
	RunState.walking = true
	GameDirector.run_active = true
	var before: Dictionary = _snapshot()
	GameDirector.end_run(false)
	var after: Dictionary = _snapshot()
	for key: Variant in before:
		_check(before[key] == after[key],
			"ending a walk moved %s, so the valley settles as a run"
				% String(key))
	_check(GameDirector.run_active,
		"and the walk is still running - `_settle_run` returned before it ended it")
	RunState.walking = was_walking
	GameDirector.run_active = was_active


## **Derived rather than stored.** A flag defaulting false would send every
## existing account to the tutorial on its next launch.
func _test_it_is_offered_only_to_a_new_account() -> void:
	var runs: int = MetaState.runs_started
	var walked: bool = MetaState.tutorial_walk_done

	MetaState.runs_started = 0
	MetaState.tutorial_walk_done = false
	_check(TutorialGrants.should_offer(),
		"a brand new account is offered the valley")
	MetaState.runs_started = 1
	_check(not TutorialGrants.should_offer(),
		"an account that has taken a road is not")
	MetaState.runs_started = 0
	MetaState.tutorial_walk_done = true
	_check(not TutorialGrants.should_offer(),
		"and neither is one that has already walked it")

	MetaState.runs_started = runs
	MetaState.tutorial_walk_done = walked


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[walk] " + why)
