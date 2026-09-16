extends Node

## Starting a fresh road at an act you have already reached.
##
##   godot --headless --path game res://tools/act_start_check.tscn
##
## **Owner ruling, 2026-09-15**: any act reached is selectable, and the Warden
## arrives on an authored baseline whose *shape* they choose - four doctrines -
## and whose *size* they do not.
##
## **The size bound is the one worth gating, and it is measured rather than
## read.** Every doctrine spends the same budget, so the test is not "does
## `board_share` say 0.9" but "did this doctrine end up holding more than the
## budget was worth". A doctrine that could create value would be a power scale
## nobody is tuning, arriving through a menu - which is the objection omens, Road
## Cards, tower paths and gear sets are each bounded against.
##
## **Four ways this goes wrong, and three of them say nothing:**
##
## - **A doctrine worth more than its budget.** Gold created at the door.
## - **A doctrine that builds nothing.** A misspelt element, an unlock the
##   account lacks, a board with no free anchors - the run opens at Act VII with
##   an empty field and the player cannot tell whether that was the design.
## - **Two doctrines that play the same.** If breadth does not actually buy more
##   emplacements than depth, the choice is a label.
## - **An act start that persists.** The whole system is meant to touch
##   `MetaState` not at all: which acts are open is derived from `best_distance`.

var _failures: int = 0
var _checks: int = 0
var _run: Run = null


func _ready() -> void:
	MetaState.hold_saves()
	_test_every_doctrine_names_something_real()
	_test_the_budget_rises_and_the_opening_is_free()
	_test_reaching_an_act_is_what_opens_it()
	await _stand_up_a_field()
	await _test_a_doctrine_never_exceeds_its_budget()
	await _test_breadth_and_depth_are_different_boards()
	await _test_the_outfit_is_spent_once()
	_test_nothing_about_this_persists()
	_tear_down()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[act-start] PASS - %d checks over %d doctrines: every doctrine "
			+ "spends the same budget differently, none of them creates one, and "
			+ "nothing about starting at an act reaches the save")
			% [_checks, ContentDB.doctrines.size()])
	else:
		push_error("[act-start] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **A misspelt element is a doctrine that quietly has no preference.**
##
## Named rather than numbered precisely so this check can exist: an enum index
## that means the wrong thing is invisible, and this project has shipped that
## twice.
func _test_every_doctrine_names_something_real() -> void:
	_check(ContentDB.doctrines.size() >= 3,
		"%d doctrines - a choice between two is a coin toss wearing a decision's "
			% ContentDB.doctrines.size() + "clothes")
	var boards: Array[float] = []
	var breadths: Array[float] = []
	for value: Variant in ContentDB.doctrines.values():
		var doctrine := value as DoctrineData
		if doctrine == null:
			continue
		_check(doctrine.names_resolve(),
			("%s favours element '%s' and role '%s', and one of those names "
				+ "nothing - so it silently has no preference at all")
				% [doctrine.id, doctrine.favoured_element, doctrine.favoured_role])
		_check(not doctrine.display_name.strip_edges().is_empty(),
			"%s has no name to show" % doctrine.id)
		_check(not doctrine.description.strip_edges().is_empty(),
			"%s says nothing about itself, so the choice is unreadable"
				% doctrine.id)
		boards.append(doctrine.board_share)
		breadths.append(doctrine.breadth)
	# The four have to actually differ, or the screen is offering one thing four
	# times.
	boards.sort()
	breadths.sort()
	_check(boards.size() >= 2 and boards[boards.size() - 1] - boards[0] >= 0.2,
		"every doctrine hands over about the same share as a board")
	_check(breadths.size() >= 2 and breadths[breadths.size() - 1] - breadths[0] >= 0.3,
		"every doctrine builds about the same shape of board")


## **The budget rises with the act, and Act I is free.**
##
## Held as a shape rather than as figures, so the table may be re-measured
## against a moved curve without the gate having to be edited alongside it -
## which is the failure mode the band constants in `curve_report` already had
## once.
func _test_the_budget_rises_and_the_opening_is_free() -> void:
	_check(Balance.ACT_START_BUDGET.size() == Balance.ACT_COUNT,
		"%d budgets for %d acts" % [Balance.ACT_START_BUDGET.size(), Balance.ACT_COUNT])
	_check(ActStart.budget_for(1) == 0,
		("Act I opens with %d Gold - Act I *is* the walk, and starting there is "
			+ "simply a new run") % ActStart.budget_for(1))
	for act: int in range(2, Balance.ACT_COUNT + 1):
		var here: int = ActStart.budget_for(act)
		var before: int = ActStart.budget_for(act - 1)
		_check(here > before,
			("act %d starts on %d Gold against act %d's %d - a later act that "
				+ "arrives poorer is a shortcut nobody would take")
				% [act, here, act - 1, before])
		# And it has to be worth a board at all: the cheapest emplacement in the
		# game, times the four roads, is the floor below which arriving is worse
		# than not arriving.
		var cheapest: int = _cheapest_tower_cost()
		_check(here >= cheapest * Balance.LANE_COUNT,
			("act %d starts on %d Gold and the cheapest tower is %d - that is "
				+ "not one emplacement a road") % [act, here, cheapest])


## **Reaching an act is what opens it, and nothing else.**
func _test_reaching_an_act_is_what_opens_it() -> void:
	var kept: float = MetaState.best_distance
	MetaState.best_distance = 0.0
	_check(ActStart.furthest_act() == 1,
		"a Warden who has walked nowhere may start at act %d"
			% ActStart.furthest_act())
	_check(ActStart.may_start(1), "act I must always be open")
	_check(not ActStart.may_start(2),
		"act II is open to a Warden who has never left act I")
	# Standing anywhere inside an act counts as having reached it.
	MetaState.best_distance = Balance.act_start_distance(5) + 10.0
	_check(ActStart.furthest_act() == 5,
		"standing inside act V reads as act %d" % ActStart.furthest_act())
	_check(ActStart.may_start(5) and not ActStart.may_start(6),
		"reaching act V opened %s"
			% ("too much" if ActStart.may_start(6) else "too little"))
	MetaState.best_distance = kept


## **Nothing a doctrine does may end with more than the budget was worth.**
##
## Driven on the real field: `begin` puts the road down, the battlefield spends
## it through `try_build`, and this reads the purse back. Measured for every
## doctrine at a late act, where the budget is big enough that a fault is
## visible.
func _test_a_doctrine_never_exceeds_its_budget() -> void:
	for value: Variant in ContentDB.doctrines.values():
		var doctrine := value as DoctrineData
		if doctrine == null:
			continue
		var outcome: Dictionary = await _outfit_with(doctrine.id, 6)
		if outcome.is_empty():
			_check(false, "%s outfitted nothing at all at act VI" % doctrine.id)
			continue
		var budget: int = int(outcome["budget"])
		var spent: int = int(outcome["spent"])
		var spare: int = int(outcome["spare"])
		_check(spent + spare <= budget,
			("%s spent %d and kept %d against a budget of %d - %d Gold was "
				+ "created at the door") % [doctrine.id, spent, spare, budget,
					spent + spare - budget])
		_check(spare >= 0, "%s ended owing %d Gold" % [doctrine.id, spare])
		print("[act-start] %-10s budget %6d  spent %6d  towers %3d  spare %6d  (board %.2f breadth %.2f)"
			% [doctrine.id, budget, spent, int(outcome["towers"]), spare,
				doctrine.board_share, doctrine.breadth])
		_check(int(outcome["towers"]) > 0,
			("%s stood up no emplacements at all - a Warden arriving at act VI "
				+ "on an empty board cannot tell that from a broken feature")
				% doctrine.id)


## **Breadth buys more emplacements than depth**, or the choice is a label.
func _test_breadth_and_depth_are_different_boards() -> void:
	var widest: DoctrineData = null
	var deepest: DoctrineData = null
	for value: Variant in ContentDB.doctrines.values():
		var doctrine := value as DoctrineData
		if doctrine == null:
			continue
		if widest == null or doctrine.breadth > widest.breadth:
			widest = doctrine
		if deepest == null or doctrine.breadth < deepest.breadth:
			deepest = doctrine
	if widest == null or deepest == null or widest == deepest:
		_check(false, "there is no widest and deepest doctrine to compare")
		return
	var wide: Dictionary = await _outfit_with(widest.id, 7)
	var deep: Dictionary = await _outfit_with(deepest.id, 7)
	if wide.is_empty() or deep.is_empty():
		_check(false, "one of the two boards was never built")
		return
	_check(int(wide["towers"]) > int(deep["towers"]),
		("%s is the widest doctrine and stood up %d emplacements against %s's "
			+ "%d - breadth and depth are the same board")
			% [widest.id, int(wide["towers"]), deepest.id, int(deep["towers"])])
	# **And the widest is the widest of all of them, not merely wider than the
	# narrowest.** The first cut passed this test while Bulwark built a narrower
	# board than Measured, because the element it favours is expensive - so the
	# doctrine named for its wall was not the one with the most wall.
	for value: Variant in ContentDB.doctrines.values():
		var other := value as DoctrineData
		if other == null or other.id == widest.id:
			continue
		var theirs: Dictionary = await _outfit_with(other.id, 7)
		if theirs.is_empty():
			continue
		_check(int(wide["towers"]) >= int(theirs["towers"]),
			("%s is the widest doctrine at breadth %.2f and stood up %d "
				+ "emplacements, against %s at %.2f standing up %d - the word on "
				+ "the card is not what the board does")
				% [widest.id, widest.breadth, int(wide["towers"]), other.id,
					other.breadth, int(theirs["towers"])])


## **A board built twice is a doctrine worth twice as much.**
func _test_the_outfit_is_spent_once() -> void:
	var outcome: Dictionary = await _outfit_with("measured", 5)
	if outcome.is_empty():
		_check(false, "nothing was outfitted to spend twice")
		return
	_check(RunState.pending_outfit.is_empty(),
		"the outfit was not erased when it was spent")
	var purse: int = RunState.currency(RunState.GOLD)
	var again: Dictionary = ActStart.outfit(_run.battlefield)
	_check(again.is_empty(),
		"outfitting a second time built another %d emplacements"
			% int(again.get("towers", 0)))
	_check(RunState.currency(RunState.GOLD) == purse,
		"a second outfit moved the purse by %d"
			% (RunState.currency(RunState.GOLD) - purse))


## **The save is not touched by any of this.**
func _test_nothing_about_this_persists() -> void:
	var before: String = MetaState.serialized_save()
	ActStart.begin(4, "measured")
	var after: String = MetaState.serialized_save()
	_check(before == after,
		"starting a road at act IV changed the account - the whole system is "
			+ "meant to derive from `best_distance` and write nothing")
	RunState.pending_outfit = {}


# ---------------------------------------------------------------------------


func _stand_up_a_field() -> void:
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame


## Begins a road at that act with that doctrine, on the standing field, and
## hands back what the outfit actually did.
func _outfit_with(doctrine_id: String, act: int) -> Dictionary:
	var field: Battlefield = _run.battlefield
	if field == null:
		return {}
	# **The previous board comes down before the reset, not after.**
	#
	# `RunState.reset()` empties `RunState.towers`, so a sell loop written after
	# it iterates nothing and every emplacement from the last doctrine stays
	# standing on the live field - which is exactly what the first cut did. The
	# board then filled up, later doctrines could not find an anchor, and the
	# widest doctrine measured as the narrowest. The harness, not the feature.
	RunState.set_phase(RunState.Phase.PREPARATION)
	for key: Variant in RunState.towers.keys():
		field.try_sell(key as Vector2i)
	for _frame: int in 3:
		await get_tree().process_frame
	RunState.reset()
	MetaState.best_distance = Balance.act_start_distance(Balance.ACT_COUNT)
	RunState.set_phase(RunState.Phase.PREPARATION)
	if not ActStart.begin(act, doctrine_id):
		return {}
	RunState.towers.clear()
	RunState.currencies[RunState.GOLD] = ActStart.budget_for(act)
	RunState.pending_outfit = {"doctrine": doctrine_id, "budget": ActStart.budget_for(act)}
	var outcome: Dictionary = ActStart.outfit(field)
	for _frame: int in 3:
		await get_tree().process_frame
	return outcome


func _cheapest_tower_cost() -> int:
	var cheapest: int = 1 << 30
	for tower: TowerData in ContentDB.unlocked_base_towers():
		if tower == null or tower.is_combination:
			continue
		cheapest = mini(cheapest, maxi(tower.build_cost(), 1))
	return cheapest if cheapest < (1 << 30) else 1


func _tear_down() -> void:
	if _run == null:
		return
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	_run.queue_free()
	_run = null


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[act-start] " + why)
