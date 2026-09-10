extends Node

## A fork is settled by counting votes, not by whoever clicked first.
##
## The old rule was first-click-wins, which meant the fastest player chose every
## road for the whole party and everyone else watched their run being decided.
## Counting is better but it has failure modes the race did not: a tie has to
## break the same way on every machine or two players walk different roads, and
## a vote that waits for everybody is a vote one idle player can stall forever.
##
## Both are properties of one pure function and a timeout, so both are tested
## here without a socket or a built screen - `CrossroadScreen.winning_road` is
## static for exactly that reason.

const HOST: int = CrossroadScreen.HOST_VOTER
const EXPECTED_TESTS: int = 7

var _failures: int = 0

## How many of the tests below actually finished.
##
## **A script error aborts the function it happens in and nothing else.** The
## first version of this gate could not compile its own subject: every call
## raised, every test returned before reaching a single assertion, and it
## printed PASS with a failure count of zero. A gate that goes green when its
## subject does not even load is worse than no gate, so the tests are counted as
## well as their assertions - and this counter has already caught two of its own
## instrumentation bugs since.
var _ran: int = 0


func _ready() -> void:
	_test_unanimous()
	_test_majority()
	_test_tie_goes_to_the_host()
	_test_tie_without_the_host_is_still_deterministic()
	_test_nobody_voted()
	_test_the_timeout_is_bounded()
	await _test_a_host_vote_does_not_lock_the_fork()

	if _ran != EXPECTED_TESTS:
		_failures += 1
		push_error("[crossroad-vote] only %d of %d tests ran to completion"
			% [_ran, EXPECTED_TESTS])
	if _failures == 0:
		print("[crossroad-vote] PASS - %d tests; votes elect a road, ties break the same way everywhere"
			% _ran)
	else:
		push_error("[crossroad-vote] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## The host voting must not stop anybody else from voting.
##
## **This is the deadlock that stopped co-op runs**, reported from play on
## 2026-09-10: "voting at crossroads got stuck with only 1 of the 2 player's
## votes and not allowing for the other player to vote".
##
## After casting its own vote the host called the same lock a guest uses while
## its request is in flight, which sets `_resolving`. Three things test that
## flag before doing anything: `cast_vote` refuses, `_tick_vote` refuses, and
## `_resolve_votes` refuses. So the partner's vote was dropped on arrival, the
## countdown that exists to settle an unfinished fork stopped counting, and the
## resolution declined to run.
##
## **Everything above this test was already green while that was true.** The
## other six drive `winning_road`, which is a pure function and was never wrong;
## the fault was entirely in the sequencing around it. That is the difference
## between gating a rule and gating the road to it.
##
## Driven through `cast_vote`, which is the one door both a host click and a
## guest request arrive at, with two seats taken so the fork is genuinely
## waiting for two answers.
func _test_a_host_vote_does_not_lock_the_fork() -> void:
	RunState.reset()
	var party: CoopParty = Coop.party()
	var guest: int = 77
	# Opened first: `seat` fills the lowest free slot, and with no party open the
	# host has not taken slot 1 - so seating the guest alone made a party of one
	# and the fork settled on a single vote, which is the opposite of the bug and
	# just as wrong.
	party.open("Host")
	party.seat(guest, "Probe")
	if party.size() != 2:
		_failures += 1
		push_error("[crossroad-vote] the probe party has %d seats, not 2" % party.size())
	var screen := (load("res://scenes/ui/crossroad_screen.tscn") as PackedScene)		.instantiate() as CrossroadScreen
	add_child(screen)
	await get_tree().process_frame
	screen.open(0)
	await get_tree().process_frame

	var roads: Array = screen.road_ids()
	if roads.size() < 2:
		_failures += 1
		push_error("[crossroad-vote] the fork offered %d roads; two are needed to disagree"
			% roads.size())
		screen.queue_free()
		return

	# Through `host_vote`, which is the host's actual turn - `_choose` branches on
	# a live peer and cannot be reached here, and calling `cast_vote` alone skips
	# the two lines the deadlock was in. The first version of this test did
	# exactly that and went green with the bug put back.
	screen.host_vote(String(roads[0]), "")
	if screen.vote_count() != 1:
		_failures += 1
		push_error("[crossroad-vote] the host's own vote was not counted")
	if screen.is_settled():
		_failures += 1
		push_error("[crossroad-vote] the fork settled on one vote of two")
	# The flag itself, named, because it is the mechanism rather than a symptom.
	if screen.is_resolving():
		_failures += 1
		push_error(("[crossroad-vote] the host locked the fork by voting in it; "
			+ "`cast_vote`, `_tick_vote` and `_resolve_votes` all refuse while "
			+ "that flag is set, so the partner can never answer"))

	screen.cast_vote(guest, String(roads[1]), "")
	if screen.vote_count() < 2 and not screen.is_settled():
		_failures += 1
		push_error("[crossroad-vote] the partner's vote was dropped after the host voted")
	if not screen.is_settled():
		_failures += 1
		push_error("[crossroad-vote] two votes of two did not settle the fork")
	_ran += 1
	screen.queue_free()
	await get_tree().process_frame


func _test_unanimous() -> void:
	_check(CrossroadScreen.winning_road({HOST: "mire", 2: "mire", 3: "mire"}) == "mire",
		"three votes for one road must elect it")
	_ran += 1


## The host counts the votes; it does not get to pick.
func _test_majority() -> void:
	_check(CrossroadScreen.winning_road({HOST: "ridge", 2: "mire", 3: "mire"}) == "mire",
		"a majority must beat the host's own vote")
	_check(CrossroadScreen.winning_road({2: "mire", 3: "ridge", 4: "ridge"}) == "ridge",
		"a majority among guests must elect their road")
	_ran += 1


func _test_tie_goes_to_the_host() -> void:
	_check(CrossroadScreen.winning_road({HOST: "ridge", 2: "mire"}) == "ridge",
		"a two-way tie must go to the host")
	_check(CrossroadScreen.winning_road({2: "mire", HOST: "ridge"}) == "ridge",
		"the host wins a tie regardless of who voted first")
	_check(CrossroadScreen.winning_road({HOST: "ridge", 2: "mire", 3: "fen"}) == "ridge",
		"a three-way split must go to the host")
	_ran += 1


## The rule still has to be a *rule* when the host abstains, or two machines
## resolving the same votes could walk different roads.
func _test_tie_without_the_host_is_still_deterministic() -> void:
	var votes: Dictionary = {2: "mire", 3: "ridge"}
	var first: String = CrossroadScreen.winning_road(votes)
	_check(first == "mire", "a hostless tie must fall to the first road cast")
	for _repeat: int in 20:
		_check(CrossroadScreen.winning_road(votes) == first,
			"the same votes must always elect the same road")
	_ran += 1


func _test_nobody_voted() -> void:
	_check(CrossroadScreen.winning_road({}) == "",
		"no votes must elect nothing rather than guessing")
	_ran += 1


## The timer answers one player walking away from the keyboard, and nothing
## else - so it has to be long enough never to fire on a party that is actually
## answering, and short enough that walking away does not end the session.
##
## Only the bound is checked here. **Whether the timer actually fires cannot be
## tested in one process**: `cast_vote` and `_tick_vote` both require
## `Coop.is_host()`, and a lone instance is neither host nor guest. That property
## belongs to `tools/coop_ui.sh`, which runs two real games - and a version of
## this test that stood up a screen and quietly asserted nothing would be the
## exact failure this gate was built to stop.
func _test_the_timeout_is_bounded() -> void:
	_check(Balance.CROSSROAD_VOTE_SECONDS >= 6.0,
		"the fork must give a hesitating player a real chance to answer (%.0fs)"
			% Balance.CROSSROAD_VOTE_SECONDS)
	# Tightened from sixty after the two-process harness showed what waiting
	# actually costs: an unsettled fork stops the run, so every second here is a
	# second the other players spend looking at a screen that will not move.
	_check(Balance.CROSSROAD_VOTE_SECONDS <= 15.0,
		"a hesitating player must not stall the whole party for %.0fs"
			% Balance.CROSSROAD_VOTE_SECONDS)
	_ran += 1


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	print("[crossroad-vote] %s" % why)
