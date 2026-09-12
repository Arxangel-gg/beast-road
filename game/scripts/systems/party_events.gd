class_name PartyEvents
extends Node

## Raids and rifts as a party decision (owner brief, 2026-09-12).
##
## In co-op, one player taking a raid or a rift does not simply vanish into it.
## The rest are asked, with a timer: accept and you go in together; decline and
## you stay where you are. Everyone is told who accepted and who declined, and
## when the party is not unanimous the one who asked decides whether to go
## anyway with those who said yes. When everyone goes, the battlefield waits
## exactly as it was until the first of them returns; when some stay, their
## road carries on while the others' event runs beside it.
##
## **The host counts the votes and announces the outcome.** A guest proposes,
## votes and decides by *asking* the host; what happened comes back as facts,
## so four machines agree on who went because they were all told the same
## thing. Nothing here touches the events themselves - `Run` enters and leaves
## them - this is only the conversation before the door.
##
## Alone, none of this happens: a solo player's raid is entered on the press,
## as it always was.

enum Kind { RAID, RIFT, DUNGEON }

var run: Node = null

## The open proposal, or empty: {kind, subkind, by_slot, deadline, votes,
## deciding, decide_deadline}. `votes` is slot -> bool.
var _proposal: Dictionary = {}
## Whether the battlefield was frozen for the event everyone went into, so the
## first return is what resumes it.
var _frozen_for_all: bool = false
var _local_in_event: bool = false
## Seats off the road in an event of their own while the road runs on.
var _away: Dictionary = {}


func _ready() -> void:
	EventBus.coop_party_event_proposed.connect(_on_proposed)
	EventBus.coop_party_event_votes.connect(_on_votes)
	EventBus.coop_party_event_decide_ask.connect(_on_decide_ask)
	EventBus.coop_party_event_resolved.connect(_on_resolved)
	EventBus.coop_party_event_returned.connect(_on_returned)
	EventBus.coop_party_event_away.connect(_on_away)
	EventBus.coop_request_received.connect(_on_request)


## Whether the conversation applies at all: a party, with somebody in it.
static func party_is_present() -> bool:
	return Coop.is_networked() and Coop.partner_present()


func is_proposing() -> bool:
	return not _proposal.is_empty()


# --- Proposing --------------------------------------------------------------------

## Asks the party. Called by the run in place of entering the event.
func propose(kind: int, subkind: int) -> void:
	if is_proposing():
		return
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay != null:
			relay.request(CoopRelay.Request.PARTY_EVENT_PROPOSE, [kind, subkind])
		return
	_open(kind, subkind, Coop.party().slot())


## Host side: opens the proposal and tells everyone.
func _open(kind: int, subkind: int, by_slot: int) -> void:
	if is_proposing():
		return
	_proposal = {
		"kind": kind, "subkind": subkind, "by_slot": by_slot,
		"deadline": Balance.PARTY_EVENT_VOTE_SECONDS, "votes": {by_slot: true},
		"deciding": false, "decide_deadline": 0.0,
	}
	EventBus.coop_party_event_proposed.emit(kind, subkind, by_slot, Balance.PARTY_EVENT_VOTE_SECONDS)
	_announce_votes()


## Everyone, host included: the prompt appears.
func _on_proposed(kind: int, subkind: int, by_slot: int, seconds: float) -> void:
	if Coop.is_guest():
		_proposal = {"kind": kind, "subkind": subkind, "by_slot": by_slot,
			"deadline": seconds, "votes": {}, "deciding": false, "decide_deadline": 0.0}
	var mine: bool = by_slot == Coop.party().slot()
	EventBus.party_event_prompt.emit(kind, subkind, _name_of(by_slot), seconds, mine)
	Sfx.play("sfx_party_prompt")


# --- Voting -------------------------------------------------------------------------

## This machine's answer, from the HUD.
func answer(accept: bool) -> void:
	if not is_proposing():
		return
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay != null:
			relay.request(CoopRelay.Request.PARTY_EVENT_VOTE, [accept])
		EventBus.party_event_prompt_closed.emit()
		return
	_record_vote(Coop.party().slot(), accept)


## This machine's decision as the proposer, from the HUD.
func decide(go: bool) -> void:
	if not is_proposing():
		return
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay != null:
			relay.request(CoopRelay.Request.PARTY_EVENT_DECIDE, [go])
		EventBus.party_event_prompt_closed.emit()
		return
	_resolve_decision(go)


func _record_vote(slot: int, accept: bool) -> void:
	if not is_proposing() or bool(_proposal["deciding"]):
		return
	(_proposal["votes"] as Dictionary)[slot] = accept
	Sfx.play("sfx_party_accept" if accept else "sfx_party_decline")
	_announce_votes()
	_settle_if_complete()


func _announce_votes() -> void:
	var accepted: Array = []
	var declined: Array = []
	var votes: Dictionary = _proposal["votes"]
	for slot: Variant in votes:
		if bool(votes[slot]):
			accepted.append(int(slot))
		else:
			declined.append(int(slot))
	accepted.sort()
	declined.sort()
	EventBus.coop_party_event_votes.emit(accepted, declined)


func _on_votes(accepted: Array, declined: Array) -> void:
	var words: PackedStringArray = []
	for slot: Variant in accepted:
		words.append("%s accepted" % _name_of(int(slot)))
	for slot: Variant in declined:
		words.append("%s declined" % _name_of(int(slot)))
	var mine: int = Coop.party().slot()
	if accepted.has(mine) or declined.has(mine):
		if is_proposing() and int(_proposal["by_slot"]) != mine:
			# Answered: the prompt goes, the tally stays a line on the strip.
			EventBus.party_event_prompt_closed.emit()
	EventBus.party_event_votes_changed.emit("  ·  ".join(words))


## Every seat has spoken, or the clock ran out: unanimous goes at once; anything
## else is the proposer's call.
func _settle_if_complete() -> void:
	if not is_proposing() or bool(_proposal["deciding"]):
		return
	var votes: Dictionary = _proposal["votes"]
	var seats: Array = Coop.party().seats()
	var all_in: bool = true
	var unanimous: bool = true
	for seat: Variant in seats:
		var slot: int = int(seat.slot)
		if not votes.has(slot):
			all_in = false
		elif not bool(votes[slot]):
			unanimous = false
	if not all_in:
		return
	if unanimous:
		_resolve(_goers())
		return
	_ask_decision()


func _ask_decision() -> void:
	_proposal["deciding"] = true
	_proposal["decide_deadline"] = Balance.PARTY_EVENT_DECIDE_SECONDS
	EventBus.coop_party_event_decide_ask.emit(int(_proposal["by_slot"]), Balance.PARTY_EVENT_DECIDE_SECONDS)


func _on_decide_ask(slot: int, seconds: float) -> void:
	if slot != Coop.party().slot():
		return
	EventBus.party_event_decision_prompt.emit(seconds)
	Sfx.play("sfx_party_prompt")


## The proposer answered: go with those who said yes, or call it off.
func _resolve_decision(go: bool) -> void:
	if not is_proposing():
		return
	_resolve(_goers() if go else [])


func _goers() -> Array:
	var out: Array = []
	var votes: Dictionary = _proposal["votes"]
	for slot: Variant in votes:
		if bool(votes[slot]):
			out.append(int(slot))
	out.sort()
	return out


## Host side: the outcome, as a fact.
func _resolve(goers: Array) -> void:
	var kind: int = int(_proposal["kind"])
	var subkind: int = int(_proposal["subkind"])
	_proposal = {}
	EventBus.coop_party_event_resolved.emit(kind, subkind, goers)


## Everyone: the outcome lands. Those named enter; the rest carry on.
func _on_resolved(kind: int, subkind: int, goers: Array) -> void:
	_proposal = {}
	EventBus.party_event_prompt_closed.emit()
	var mine: int = Coop.party().slot()
	var everyone: bool = goers.size() >= Coop.party().seats().size()
	if goers.is_empty():
		EventBus.preparation_warning.emit("The %s was called off." % _what(kind))
		return
	var names: PackedStringArray = []
	for slot: Variant in goers:
		names.append(_name_of(int(slot)))
	if goers.has(mine):
		_local_in_event = true
		_frozen_for_all = everyone
		if run != null and run.has_method("enter_party_event"):
			run.call("enter_party_event", kind, subkind, everyone)
	else:
		EventBus.preparation_warning.emit("%s entered the %s. The road goes on." % [
			", ".join(names), _what(kind)])
		if everyone:
			_frozen_for_all = true


# --- Returning ----------------------------------------------------------------------

## This machine's event ended. When the field was frozen for everyone, the
## first return is what unfreezes it - for everyone.
func returned() -> void:
	var was_in: bool = _local_in_event
	_local_in_event = false
	if not was_in:
		return
	if not _frozen_for_all:
		return
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay != null:
			relay.request(CoopRelay.Request.PARTY_EVENT_RETURN, [])
		return
	_thaw(Coop.party().slot())


func _thaw(slot: int) -> void:
	if not _frozen_for_all:
		return
	_frozen_for_all = false
	EventBus.coop_party_event_returned.emit(slot)


func _on_returned(slot: int) -> void:
	_frozen_for_all = false
	if run != null and run.has_method("resume_after_party_event"):
		run.call("resume_after_party_event", slot)


## Whether the local player is inside an event the party was asked about.
func local_in_event() -> bool:
	return _local_in_event


# --- Away ---------------------------------------------------------------------------

## Host side: a seat stepped off the road, or came back. Said as a fact so
## every machine hides or shows that body, and the host's road knows whether
## the party is whole.
func mark_away(slot: int, away: bool) -> void:
	if not Coop.is_host():
		return
	if bool(_away.get(slot, false)) == away:
		return
	EventBus.coop_party_event_away.emit(slot, away)


func _on_away(slot: int, away: bool) -> void:
	if away:
		_away[slot] = true
	else:
		_away.erase(slot)


## Whether any seat is off the road in an event of its own. The fork waits
## for them.
func anyone_away() -> bool:
	return not _away.is_empty()


func away_slots() -> Array:
	var out: Array = _away.keys()
	out.sort()
	return out


func frozen_for_all() -> bool:
	return _frozen_for_all


# --- Host: requests from guests --------------------------------------------------

func _on_request(kind: int, args: Array, from_peer: int) -> void:
	if not Coop.is_host():
		return
	var slot: int = Coop.party().slot_for_peer(from_peer)
	match kind:
		CoopRelay.Request.PARTY_EVENT_PROPOSE:
			if args.size() == 2 and run != null and run.has_method("party_event_allowed") \
					and bool(run.call("party_event_allowed", int(args[0]), int(args[1]))):
				_open(int(args[0]), int(args[1]), slot)
		CoopRelay.Request.PARTY_EVENT_VOTE:
			if args.size() == 1:
				_record_vote(slot, bool(args[0]))
		CoopRelay.Request.PARTY_EVENT_DECIDE:
			if args.size() == 1 and is_proposing() and int(_proposal["by_slot"]) == slot:
				_resolve_decision(bool(args[0]))
		CoopRelay.Request.PARTY_EVENT_RETURN:
			_thaw(slot)
		CoopRelay.Request.PARTY_EVENT_AWAY:
			if args.size() == 1 and slot > 0:
				mark_away(slot, bool(args[0]))
		CoopRelay.Request.PARTY_EVENT_REWARD:
			if args.size() == 2 and run != null and run.has_method("pay_party_event"):
				run.call("pay_party_event", int(args[0]), args[1] as Dictionary, slot)
		_:
			pass


# --- The clocks ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_proposing() or not Coop.is_host():
		return
	if bool(_proposal["deciding"]):
		_proposal["decide_deadline"] = float(_proposal["decide_deadline"]) - delta
		if float(_proposal["decide_deadline"]) <= 0.0:
			# Silence from the proposer is a no.
			_resolve_decision(false)
		return
	_proposal["deadline"] = float(_proposal["deadline"]) - delta
	if float(_proposal["deadline"]) <= 0.0:
		# Silence is a decline.
		var votes: Dictionary = _proposal["votes"]
		for seat: Variant in Coop.party().seats():
			if not votes.has(int(seat.slot)):
				votes[int(seat.slot)] = false
		_announce_votes()
		_settle_if_complete()


# --- Words --------------------------------------------------------------------------

func _name_of(slot: int) -> String:
	var name: String = Coop.party().name_of(slot)
	return name if not name.is_empty() else "Warden %d" % slot


static func _what(kind: int) -> String:
	match kind:
		Kind.RAID:
			return "raid"
		Kind.DUNGEON:
			return "dungeon"
		_:
			return "rift"


## The line the prompt says.
static func invitation(kind: int, by_name: String) -> String:
	match kind:
		Kind.RAID:
			return "%s is raiding the camp. Join them?" % by_name
		Kind.DUNGEON:
			return "%s is descending into the dungeon. Join them?" % by_name
		_:
			return "%s is entering the rift. Join them?" % by_name
