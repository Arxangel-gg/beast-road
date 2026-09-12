extends Node

## The party's conversation before a raid or a rift (owner brief,
## 2026-09-12): `PartyEvents`, driven as the host with three seats and no
## network.
##
## What this holds:
##
## - a proposal opens once, the proposer's own vote is yes, and every seat is
##   asked; a unanimous yes goes at once and *freezes* the field; a mixed
##   answer is the proposer's call, and their yes takes the yeses without
##   freezing; their no calls it off; silence is a no, on both clocks;
## - the first return from a frozen field thaws it once, for everyone;
## - a guest's packets are attributed by the peer they arrived on: a vote
##   counts for that seat, a proposal from a seat while one is open is
##   refused, and "away" is a fact the road reads.
##
## A stand-in for the run records what the system asks of it, so the test
## reads the decision rather than the raid.

class RunStub extends Node:
	var entered: Array = []
	var resumed: Array = []
	var allowed: bool = true

	func party_event_allowed(_kind: int, _subkind: int) -> bool:
		return allowed

	func enter_party_event(kind: int, subkind: int, freeze: bool) -> void:
		entered.append([kind, subkind, freeze])

	func resume_after_party_event(slot: int) -> void:
		resumed.append(slot)

	func pay_party_event(_kind: int, _result: Dictionary, _slot: int) -> void:
		pass

var _failures: int = 0
var _checked: int = 0
var _prompts: Array = []
var _decisions: int = 0
var _tallies: Array[String] = []
var _resolved: Array = []
var _thaws: Array = []


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260912)
	GameDirector.run_active = true
	EventBus.party_event_prompt.connect(func(kind: int, _sub: int, by: String, _s: float, mine: bool) -> void:
		_prompts.append([kind, by, mine]))
	EventBus.party_event_decision_prompt.connect(func(_s: float) -> void: _decisions += 1)
	EventBus.party_event_votes_changed.connect(func(text: String) -> void: _tallies.append(text))
	EventBus.coop_party_event_resolved.connect(func(kind: int, _sub: int, goers: Array) -> void:
		_resolved.append([kind, goers]))
	EventBus.coop_party_event_returned.connect(func(slot: int) -> void: _thaws.append(slot))
	await get_tree().process_frame

	var party: CoopParty = Coop.party()
	party.open("Ash")
	party.seat(2, "Bren")
	party.seat(3, "Cor")
	_check(party.seats().size() == 3 and party.slot() == 1, "three seats, this machine in the first")
	_check(Coop.is_host() and not Coop.is_guest(), "alone, this machine is the host")

	var stub := RunStub.new()
	add_child(stub)
	var events := PartyEvents.new()
	events.run = stub
	add_child(events)
	await get_tree().process_frame

	_test_unanimous(events, stub)
	_test_mixed(events, stub)
	_test_called_off(events, stub)
	_test_silence(events, stub)
	_test_guest_packets(events, stub)

	events.queue_free()
	stub.queue_free()
	party.clear()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Vfx.clear()
	for _f: int in 10:
		await get_tree().process_frame
	Sfx.stop_immediately()
	GameDirector.run_active = false
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[party] FAIL - %d of %d" % [_failures, _checked])
		get_tree().quit(1)
		return
	print("[party] PASS - %d checks: the proposal, the votes, the decision, the clocks and the thaw" % _checked)
	get_tree().quit(0)


func _test_unanimous(events: PartyEvents, stub: RunStub) -> void:
	events.propose(PartyEvents.Kind.RAID, 0)
	_check(events.is_proposing(), "a proposal opens")
	_check(_prompts.size() == 1 and bool(_prompts[0][2]) and String(_prompts[0][1]) == "Ash",
		"the prompt says who asked, and the proposer sees their own")
	events.propose(PartyEvents.Kind.RIFT, 0)
	_check(int(events._proposal["kind"]) == PartyEvents.Kind.RAID, "a second proposal while one is open is refused")
	_check(not _tallies.is_empty() and _tallies.back().contains("Ash accepted"), "the proposer's own vote is yes")
	events._record_vote(2, true)
	_check(events.is_proposing() and stub.entered.is_empty(), "one seat still to answer: nobody goes yet")
	events._record_vote(3, true)
	_check(not events.is_proposing(), "every yes settles it")
	_check(_resolved.size() == 1 and (_resolved[0][1] as Array) == [1, 2, 3], "everyone goes: %s" % str(_resolved))
	_check(stub.entered.size() == 1 and bool(stub.entered[0][2]), "and the field is frozen for all")
	_check(events.local_in_event() and events.frozen_for_all(), "this machine is inside, and the field waits")
	# The first return thaws the field once.
	events.returned()
	_check(_thaws == [1] and not events.frozen_for_all(), "the first return thaws the field")
	_check(stub.resumed == [1], "and the run is told to resume")
	events.returned()
	_check(_thaws.size() == 1, "a second return does not thaw twice")
	stub.entered.clear()
	stub.resumed.clear()
	_resolved.clear()


func _test_mixed(events: PartyEvents, stub: RunStub) -> void:
	events.propose(PartyEvents.Kind.RIFT, 0)
	events._record_vote(2, true)
	events._record_vote(3, false)
	_check(events.is_proposing() and bool(events._proposal["deciding"]), "a mixed answer waits on the proposer")
	_check(_decisions == 1, "and the proposer is asked")
	_check(_tallies.back().contains("Cor declined") and _tallies.back().contains("Bren accepted"),
		"everyone is told who accepted and who declined: %s" % _tallies.back())
	events._record_vote(3, true)
	_check(bool(events._proposal["votes"][3]) == false, "a vote cannot change once the proposer is deciding")
	events.decide(true)
	_check(_resolved.size() == 1 and (_resolved[0][1] as Array) == [1, 2], "the proposer's yes takes the yeses")
	_check(stub.entered.size() == 1 and not bool(stub.entered[0][2]), "and the field is not frozen: the road goes on")
	_thaws.clear()
	events.returned()
	_check(_thaws.is_empty(), "a return from an unfrozen field thaws nothing")
	# Away is a fact the road reads.
	events.mark_away(2, true)
	_check(events.anyone_away() and events.away_slots() == [2], "a seat stepping off the road is known")
	events.mark_away(2, false)
	_check(not events.anyone_away(), "and its return is known")
	stub.entered.clear()
	_resolved.clear()


func _test_called_off(events: PartyEvents, stub: RunStub) -> void:
	events.propose(PartyEvents.Kind.DUNGEON, 1)
	events._record_vote(2, false)
	events._record_vote(3, false)
	events.decide(false)
	_check(_resolved.size() == 1 and (_resolved[0][1] as Array).is_empty(), "the proposer's no calls it off")
	_check(stub.entered.is_empty() and not events.is_proposing(), "nobody goes")
	_resolved.clear()


func _test_silence(events: PartyEvents, stub: RunStub) -> void:
	events.propose(PartyEvents.Kind.RAID, 0)
	events._process(Balance.PARTY_EVENT_VOTE_SECONDS * 0.5)
	_check(events.is_proposing() and not bool(events._proposal["deciding"]), "half the clock: still waiting")
	events._process(Balance.PARTY_EVENT_VOTE_SECONDS * 0.5 + 0.1)
	_check(bool(events._proposal["deciding"]), "silence is a decline, so the proposer decides")
	events._process(Balance.PARTY_EVENT_DECIDE_SECONDS + 0.1)
	_check(not events.is_proposing() and _resolved.size() == 1 and (_resolved[0][1] as Array).is_empty(),
		"silence from the proposer calls it off")
	_check(stub.entered.is_empty(), "and nobody goes")
	_resolved.clear()


func _test_guest_packets(events: PartyEvents, stub: RunStub) -> void:
	# A guest proposes: attributed by peer, allowed by the run.
	events._on_request(CoopRelay.Request.PARTY_EVENT_PROPOSE, [PartyEvents.Kind.RAID, 0], 2)
	_check(events.is_proposing() and int(events._proposal["by_slot"]) == 2, "a guest's proposal opens under its seat")
	_check(_prompts.back()[1] == "Bren" and not bool(_prompts.back()[2]), "and the host is asked, not told it asked")
	events._on_request(CoopRelay.Request.PARTY_EVENT_PROPOSE, [PartyEvents.Kind.RIFT, 0], 3)
	_check(int(events._proposal["by_slot"]) == 2, "a second proposal from another seat is refused")
	events._on_request(CoopRelay.Request.PARTY_EVENT_VOTE, [true], 3)
	_check(bool((events._proposal["votes"] as Dictionary).get(3, false)), "a guest's vote counts for its seat")
	events._on_request(CoopRelay.Request.PARTY_EVENT_DECIDE, [true], 3)
	_check(events.is_proposing(), "a decision from a seat that did not ask is ignored")
	events.answer(true)
	_check(not events.is_proposing() and (_resolved.back()[1] as Array) == [1, 2, 3], "the host's yes completes it")
	_check(stub.entered.size() == 1 and bool(stub.entered[0][2]), "everyone went, so the field froze")
	_thaws.clear()
	stub.resumed.clear()
	events._on_request(CoopRelay.Request.PARTY_EVENT_RETURN, [], 3)
	_check(_thaws == [3], "a guest's return thaws the field, attributed to its seat")
	_check(stub.resumed == [3], "and this machine resumes")
	events._on_request(CoopRelay.Request.PARTY_EVENT_AWAY, [true], 2)
	_check(events.away_slots() == [2], "a guest away is known by its seat")
	events._on_request(CoopRelay.Request.PARTY_EVENT_AWAY, [false], 2)
	_check(not events.anyone_away(), "and back")
	# The run may refuse a guest's proposal outright.
	stub.allowed = false
	events._on_request(CoopRelay.Request.PARTY_EVENT_PROPOSE, [PartyEvents.Kind.RAID, 0], 2)
	_check(not events.is_proposing(), "a proposal the run refuses never opens")
	stub.allowed = true


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[party] " + message)
