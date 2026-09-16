extends Node

## The walk: where an act ends, where a boss is due, and who decides the act.
##
##   godot --headless --path game res://tools/journey_check.tscn
##
## **Written because the walk and every model of it disagreed about the shape of
## the road, and nothing could see it.** `Journey` closed an act on
## `_segment_index % SEGMENTS_PER_ACT`, which is a flat act length.
## `Balance.act_end_distance()` knows the opening act is longer than the rest,
## and it is what `curve_report`, `balance_test` and the HUD's own boss countdown
## all ask. The walk asked none of them, so:
##
## - The Act I boss was met at distance 400 while the readout on screen said 390
##   still to go, and every model reported the act as 790 long.
## - The owner reported "the path to the first act 1 boss was too short" **twice**.
##   Both times `ACT_OPENING_EXTRA_DISTANCE` was raised, both times every model
##   agreed the fix had landed, and both times the game did not move at all.
##
## `balance_reach_check` could not catch it either, and that is the lesson worth
## keeping: the constant *was* read - by `act_end_distance` - so the reach gate
## was satisfied. **A constant read only by a function the game never calls is
## exactly as dead as one nothing reads**, and it is harder to see, because every
## report built on that function says the feature works.
##
## So this gate drives the real `Journey` and reads the distances back off it,
## rather than checking that the constants exist.

var _failures: int = 0
var _checks: int = 0

## Where each act's boss was actually called for, filled by driving the walk.
var _boss_at: Dictionary = {}
## Which acts the run announced the start of, in order, with their distances.
var _act_started: Array[Dictionary] = []
## Distances at which a crossroad was reached.
var _crossroads: Array[float] = []
## What the HUD's countdown said on the frame before each boss was called.
var _countdown_before: Dictionary = {}


func _ready() -> void:
	MetaState.hold_saves()
	_walk_the_whole_road()
	_test_the_boss_is_due_where_the_model_says()
	_test_the_countdown_does_not_lie()
	_test_only_a_fallen_boss_starts_an_act()
	_test_crossroads_still_happen_between_bosses()
	_test_the_opening_act_is_the_long_one()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[journey] PASS - %d checks over %d acts: the walk ends an act "
			+ "where `act_end_distance` says, the countdown agrees, and an act "
			+ "begins only when the act before it is finished")
			% [_checks, Balance.ACT_COUNT])
	else:
		push_error("[journey] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **Driven, never computed.** The whole point is that the walk had its own idea
## of where an act ends, so nothing here may work that out a second way.
func _walk_the_whole_road() -> void:
	RunState.reset()
	var journey := Journey.new()
	add_child(journey)
	EventBus.act_boss_due.connect(_on_boss_due)
	EventBus.act_started.connect(_on_act_started)
	EventBus.crossroad_reached.connect(_on_crossroad)
	journey.start()

	# A frame of walking at the beast's own speed, taken until the last act's
	# boss has been called or the road has plainly stopped advancing.
	var guard: int = 0
	var last_distance: float = -1.0
	while not _boss_at.has(Balance.ACT_COUNT) and guard < 2000000:
		guard += 1
		# The HUD's own readout, sampled every frame so the last value before a
		# boss is called is the one the player would have been looking at.
		var showing: float = RunState.distance_to_boss()
		journey._process(1.0 / 60.0)
		if _boss_at.size() > _countdown_before.size():
			_countdown_before[_boss_at.size()] = showing
		if not bool(journey.get("_crossroad_pending")):
			continue
		# Answer whichever gate the walk is standing at. A boss is settled by
		# the boss director; a fork by the crossroad screen.
		var at_boss: bool = _boss_at.has(RunState.act) \
			and is_equal_approx(float(_boss_at[RunState.act]),
				RunState.distance_travelled)
		if at_boss:
			if RunState.act >= Balance.ACT_COUNT:
				break
			journey.resume_after_boss()
		else:
			journey.resolve_crossroad("")
		last_distance = RunState.distance_travelled
	_check(guard < 2000000,
		"the walk never reached the last act's boss - it stopped at %.0f"
			% last_distance)
	EventBus.act_boss_due.disconnect(_on_boss_due)
	EventBus.act_started.disconnect(_on_act_started)
	EventBus.crossroad_reached.disconnect(_on_crossroad)
	journey.queue_free()


## **Every act's boss is due where the one function says it is.**
func _test_the_boss_is_due_where_the_model_says() -> void:
	for act: int in range(1, Balance.ACT_COUNT + 1):
		_check(_boss_at.has(act),
			"act %d's boss was never called for on a full walk of the road" % act)
		if not _boss_at.has(act):
			continue
		var actual: float = float(_boss_at[act])
		var expected: float = Balance.act_end_distance(act)
		# One frame of the beast's walk is the tolerance: the threshold is
		# crossed inside a frame and the boss is called on that frame.
		var slack: float = Balance.BEAST_BASE_SPEED / 60.0 + 0.5
		_check(absf(actual - expected) <= slack,
			("act %d's boss is due at %.0f and the walk called it at %.0f - the "
				+ "road the player walks is %.0f units %s than every model of it")
				% [act, expected, actual, absf(actual - expected),
					"longer" if actual > expected else "shorter"])


## **The countdown on screen is the same number the walk is using.**
##
## `RunState.distance_to_boss()` is what the HUD draws, and its own comment says
## it exists so that a working boss trigger does not read as a broken one. With
## the walk ending acts somewhere else, it did precisely the opposite: the boss
## arrived with the readout still promising hundreds of units of road.
func _test_the_countdown_does_not_lie() -> void:
	for act: int in range(1, Balance.ACT_COUNT + 1):
		if not _countdown_before.has(act):
			continue
		var showing: float = float(_countdown_before[act])
		_check(showing <= Balance.BEAST_BASE_SPEED / 60.0 + 1.0,
			("act %d's boss walked in while the readout still said %.0f units of "
				+ "road to go") % [act, showing])


## **An act begins in exactly one place: when the act before it is finished.**
##
## A crossroad used to decide this as well, by dividing distance by
## `ACT_DISTANCE`. Two answers to one question is the failure this project keeps
## paying for; here they disagreed for every act on the road.
func _test_only_a_fallen_boss_starts_an_act() -> void:
	var seen: Array[int] = []
	for entry: Dictionary in _act_started:
		var act: int = int(entry["act"])
		_check(not seen.has(act),
			"act %d was announced more than once in one run" % act)
		seen.append(act)
		if act <= 1:
			continue
		var previous_boss: float = float(_boss_at.get(act - 1, -1.0))
		_check(previous_boss >= 0.0,
			"act %d began without act %d's boss ever being called" % [act, act - 1])
		_check(float(entry["distance"]) >= previous_boss - 0.5,
			("act %d began at %.0f, which is %.0f units before act %d's boss was "
				+ "even called for") % [act, float(entry["distance"]),
					previous_boss - float(entry["distance"]), act - 1])
	for act: int in range(2, Balance.ACT_COUNT + 1):
		_check(seen.has(act), "act %d never began on a full walk" % act)


## A road with no forks in it is a corridor.
func _test_crossroads_still_happen_between_bosses() -> void:
	_check(_crossroads.size() >= Balance.ACT_COUNT,
		("%d crossroads on a whole campaign of %d acts - the walk stopped "
			+ "forking") % [_crossroads.size(), Balance.ACT_COUNT])
	for act: int in range(1, Balance.ACT_COUNT + 1):
		var from: float = Balance.act_start_distance(act)
		var to: float = Balance.act_end_distance(act)
		var inside: int = 0
		for at: float in _crossroads:
			if at > from and at < to:
				inside += 1
		_check(inside >= 1,
			("act %d (%.0f to %.0f) holds %d crossroads - an act with no fork in "
				+ "it is a corridor") % [act, from, to, inside])


## **The opening act is longer than the rest, and that is the decision.**
##
## Reported from play twice. It is held here as a property of the road rather
## than as a constant's value, so the figure may be tuned and the shape may not
## quietly go away.
func _test_the_opening_act_is_the_long_one() -> void:
	var opening: float = Balance.act_end_distance(1) - Balance.act_start_distance(1)
	var second: float = Balance.act_end_distance(2) - Balance.act_start_distance(2)
	_check(opening > second,
		("the opening act is %.0f units and the second is %.0f - act I is the one "
			+ "act that starts with nothing built and it is not the longer one")
			% [opening, second])
	if not _boss_at.has(1):
		return
	# And it is long in the *walk*, not only in the table. This is the check that
	# would have failed for the whole life of the fault.
	var walked: float = float(_boss_at[1])
	_check(walked > second,
		("the beast walked %.0f units to the Act I boss against an ordinary act "
			+ "of %.0f - the opening's extra road exists in the table and not on "
			+ "the road") % [walked, second])


func _on_boss_due(act: int) -> void:
	if not _boss_at.has(act):
		_boss_at[act] = RunState.distance_travelled


func _on_act_started(act: int, _terrain: String) -> void:
	_act_started.append({"act": act, "distance": RunState.distance_travelled})


func _on_crossroad(_segment: int) -> void:
	_crossroads.append(RunState.distance_travelled)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[journey] " + why)
