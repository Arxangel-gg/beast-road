extends Node

## The part of a trade that touches real gear, which is the part that can lose it.
##
## `TradeSession` holds the rules with no save and no socket in it; this is the
## thin layer that owns two actual stashes on two actual machines. Everything
## dangerous is here, and it is arranged so that the dangerous thing cannot
## happen rather than so that it is unlikely to.
##
## **The invariant: gear is never created.** A trade may fail, and a failed trade
## may cost one side what it offered - see the note on `settle` - but no sequence
## of packets, disconnections or races may end with a piece existing twice. Every
## decision below is that invariant being paid for.
##
## Three things buy it.
##
## **One authority.** The host decides. The guest describes its own stash and
## asks; it never concludes. That is the same rule the rest of co-op runs on and
## the same reason: two machines that both decide will eventually decide
## differently.
##
## **Names, not positions.** A stash index is not a name for a piece - indices
## shift the moment anything is removed. Offers carry `Stash.uid`, and settling
## resolves those back to positions at the instant it commits.
##
## **Check everything, then move everything.** `settle` validates both sides
## completely before it touches either stash, so there is no half-applied state
## to unwind. Godot has no transaction to roll back to.
##
## **And the stash is locked while a trade is open.** Breaking a piece that is on
## the table would otherwise be a race with a permanent loser.

signal changed()

## The trade in progress, or null.
var _session: TradeSession = null

## Which side this machine is. Decided once when the trade opens, because
## `Coop.is_host` answering differently mid-trade would be a worse problem than
## anything this file guards against.
var _side: String = ""

## The other player's offer, as they described it. Host side this arrives over
## the wire; guest side it is what the host says the host is offering.
var _partner_name: String = ""


## The window, made once and kept.
##
## **Owned here rather than by whichever screen opened the trade**, because a
## trade can begin with the *other* player pressing something. An invitation
## that only appeared to a player already standing in their stash would be an
## invitation half the party never sees.
var _screen: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.coop_request_received.connect(_on_request)
	EventBus.coop_trade_state.connect(_on_state_from_host)
	EventBus.coop_trade_settled.connect(_on_settled_by_host)
	# **A trade needs two players, so it ends when there is one.** Without this
	# the window stays open against nobody: the remaining player can still tick
	# pieces onto a table that will never settle, and on the host the gear is
	# still locked against being broken.
	EventBus.coop_partner_left.connect(func(_peer: int) -> void:
		if is_trading():
			_close_locally("Your partner left. The trade is off."))
	changed.connect(_show_when_running)


## Ends the trade on this machine without asking anybody.
##
## For the cases where there is nobody left to ask - a partner who disconnected,
## a settlement this machine could not honour. The host still announces, because
## a host that closed silently would leave a guest holding a table.
func _close_locally(reason: String) -> void:
	if _session == null:
		return
	_session.close(reason)
	if Coop.is_host():
		EventBus.coop_trade_state.emit(_session.to_wire())
	_session = null
	EventBus.preparation_warning.emit("TRADE  ·  %s" % reason)
	changed.emit()


func _show_when_running() -> void:
	if not is_trading():
		return
	if _screen == null or not is_instance_valid(_screen):
		_screen = (load("res://scenes/ui/trade_screen.gd") as GDScript).new()
		add_child(_screen)


func session() -> TradeSession:
	return _session


func side() -> String:
	return _side


func partner_name() -> String:
	return _partner_name


## Whether a trade is open on this machine.
##
## Asked by the stash screen before it does anything destructive: a piece broken
## while it sits on the trade table is a race whose loser is a player's gear.
func is_trading() -> bool:
	return _session != null and _session.is_running()


func stage() -> int:
	return int(_session.stage) if _session != null else int(TradeSession.Stage.IDLE)


# --- Opening ------------------------------------------------------------------

## Asks the other player for a trade. Either side may start one.
func invite() -> String:
	if not Coop.partner_present():
		return "There is nobody here to trade with."
	if is_trading():
		return "A trade is already open."
	_side = TradeSession.HOST if Coop.is_host() else TradeSession.GUEST
	_partner_name = _read_partner_name()
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay == null:
			return "The connection is not ready."
		relay.request(CoopRelay.Request.TRADE_INVITE, [])
		return ""
	_session = TradeSession.new()
	var refusal: String = _session.invite(TradeSession.HOST)
	if not refusal.is_empty():
		_session = null
		return refusal
	_publish()
	return ""


## Answers an invitation.
func answer_invite(yes: bool) -> String:
	if _session == null:
		return "There is no invitation to answer."
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay == null:
			return "The connection is not ready."
		relay.request(CoopRelay.Request.TRADE_ANSWER, [yes])
		return ""
	return _host_answer(TradeSession.HOST, yes)


# --- Offering -----------------------------------------------------------------

## Puts a set of stash pieces on the table.
##
## Takes stash *indices* from the screen and turns them into named pieces here,
## because the screen is the one place that legitimately thinks in positions and
## everything past this point must not.
## Puts a set of named pieces on the table.
##
## **Named, not positioned.** The screen picks from a list and therefore knows
## indices, and it converts them to names the instant it has them - because a
## stash can change while the window is open. A run ending delivers a drop, a
## partner's settlement removes a piece, and every index after it moves. An
## offer held as positions would then be an offer of whatever slid into those
## positions, which is the exact fault this system's `uid` exists to prevent and
## it would be embarrassing to reintroduce in the screen that uses it.
##
## Names that no longer resolve are dropped rather than refused: a piece that
## left the stash is not an error the player made, and refusing the whole offer
## would strand them with a table they cannot change.
func offer_uids(uids: Array) -> String:
	if _session == null:
		return "There is no trade open."
	var pieces: Array = []
	for entry: Variant in uids:
		var index: int = Stash.index_of(MetaState.stash, int(entry))
		if index < 0:
			continue
		var piece: Dictionary = MetaState.stash[index]
		# **Worn gear is not on the table.** `drop_gear` silently unequips
		# whatever it removes, so trading a worn sword would take it off the hero
		# without saying so - and in the middle of a run, at that.
		if _is_equipped(index):
			return "You are wearing that. Take it off first."
		Stash.uid(piece)
		pieces.append(piece.duplicate(true))
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay == null:
			return "The connection is not ready."
		relay.request(CoopRelay.Request.TRADE_OFFER, [pieces])
		return ""
	return _host_offer(TradeSession.HOST, pieces)


func set_accepted(wanted: bool) -> String:
	if _session == null:
		return "There is no trade open."
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay == null:
			return "The connection is not ready."
		relay.request(CoopRelay.Request.TRADE_ACCEPT, [wanted])
		return ""
	return _host_accept(TradeSession.HOST, wanted)


func set_confirmed(wanted: bool) -> String:
	if _session == null:
		return "There is no trade open."
	# **Checked here, before agreeing rather than after.** This machine is the
	# only one that can see its own stash, so its confirmation *is* its promise
	# that its half is real. The host re-checks its own half at settlement; this
	# is the guest's half being checked at the last moment it still can be.
	if wanted:
		var problem: String = _my_half_is_deliverable()
		if not problem.is_empty():
			return problem
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay == null:
			return "The connection is not ready."
		relay.request(CoopRelay.Request.TRADE_CONFIRM, [wanted])
		return ""
	return _host_confirm(TradeSession.HOST, wanted)


func cancel(reason: String = "Trade cancelled.") -> String:
	if _session == null:
		return ""
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay != null:
			relay.request(CoopRelay.Request.TRADE_CANCEL, [reason])
		return ""
	_host_cancel(reason)
	return ""


# --- Host side ----------------------------------------------------------------

func _on_request(kind: int, args: Array, _from: int) -> void:
	if not Coop.is_host():
		return
	match kind:
		CoopRelay.Request.TRADE_INVITE:
			if _session == null:
				_side = TradeSession.HOST
				_partner_name = _read_partner_name()
				_session = TradeSession.new()
				if not _session.invite(TradeSession.GUEST).is_empty():
					_session = null
					return
				_publish()
		CoopRelay.Request.TRADE_ANSWER:
			if args.size() == 1:
				_host_answer(TradeSession.GUEST, bool(args[0]))
		CoopRelay.Request.TRADE_OFFER:
			if args.size() == 1 and args[0] is Array:
				_host_offer(TradeSession.GUEST, args[0] as Array)
		CoopRelay.Request.TRADE_ACCEPT:
			if args.size() == 1:
				_host_accept(TradeSession.GUEST, bool(args[0]))
		CoopRelay.Request.TRADE_CONFIRM:
			if args.size() == 1:
				_host_confirm(TradeSession.GUEST, bool(args[0]))
		CoopRelay.Request.TRADE_CANCEL:
			_host_cancel(String(args[0]) if args.size() == 1 else "Trade cancelled.")


func _host_answer(who: String, yes: bool) -> String:
	if _session == null:
		return "There is no invitation to answer."
	if not yes:
		_host_cancel("The trade was declined.")
		return ""
	var refusal: String = _session.accept_invite(who)
	if refusal.is_empty():
		_publish()
	return refusal


func _host_offer(who: String, pieces: Array) -> String:
	if _session == null:
		return "There is no trade open."
	# **What arrives from the other machine is checked for shape, not trusted.**
	# A guest describes its own stash and there is no way for this machine to see
	# it, so a determined cheat could offer gear it does not have. What it must
	# not be able to do is offer gear that *cannot exist* - an unknown kind, a
	# rarity past the table, a level past the cap - because that would put a
	# piece in the host's stash that nothing else in the game knows how to price,
	# break or draw.
	for entry: Variant in pieces:
		var problem: String = _well_formed(entry as Dictionary)
		if not problem.is_empty():
			_host_cancel("That offer was not gear: %s" % problem)
			return problem
	var refusal: String = _session.set_offer(who, pieces, Balance.TRADE_MAX_PIECES)
	if refusal.is_empty():
		_publish()
	return refusal


func _host_accept(who: String, wanted: bool) -> String:
	if _session == null:
		return "There is no trade open."
	var refusal: String = _session.set_accepted(who, wanted)
	if refusal.is_empty():
		_publish()
	return refusal


func _host_confirm(who: String, wanted: bool) -> String:
	if _session == null:
		return "There is no trade open."
	var refusal: String = _session.set_confirmed(who, wanted)
	if not refusal.is_empty():
		return refusal
	if _session.ready_to_settle():
		settle()
	else:
		_publish()
	return ""


func _host_cancel(reason: String) -> void:
	if _session == null:
		return
	_session.close(reason)
	_publish()
	_session = null
	changed.emit()


# --- Settling -----------------------------------------------------------------

## Moves the gear. Host only, and only once both sides have confirmed.
##
## **Everything is checked before anything moves.** There is no transaction to
## roll back to, so the validation and the mutation are two separate passes and
## the first one can abort the whole trade without having touched a stash.
##
## The residual risk, stated plainly rather than hidden: if the settlement
## message never reaches the guest, the host will have swapped and the guest will
## not. The host has then given away gear and received none. That is a loss, and
## it is the deliberate direction to fail in - the alternative ordering, where
## the guest gives first, loses the *guest's* gear on the same dropped packet,
## and any ordering where either side adds before the other removes is the one
## outcome that must never happen.
func settle() -> String:
	if _session == null or not _session.ready_to_settle() or not Coop.is_host():
		return "Nothing to settle."
	var mine: Array = _session.offer(TradeSession.HOST)
	var theirs: Array = _session.offer(TradeSession.GUEST)

	var problem: String = _can_deliver(mine, theirs.size())
	if not problem.is_empty():
		_host_cancel(problem)
		return problem
	# The guest checked its own half when it confirmed; this is the shape check
	# on what it described, repeated because the offer could have been replaced
	# between the two and the last word before gear moves belongs here.
	for entry: Variant in theirs:
		var shape: String = _well_formed(entry as Dictionary)
		if not shape.is_empty():
			_host_cancel("That offer was not gear: %s" % shape)
			return shape

	_apply_locally(mine, theirs)
	# The guest is told what *it* gives and gets, in its own terms. Emitted on
	# this machine's own bus rather than sent down the socket by hand: the relay
	# forwards facts by listening to the bus, which is also what puts this one
	# under `_guard` - a guest that ever authored a settlement would be caught by
	# the same rule that catches one inventing an enemy death.
	EventBus.coop_trade_settled.emit(theirs, mine)
	_session.close_settled()
	_publish()
	_session = null
	changed.emit()
	EventBus.trade_completed.emit(mine.size(), theirs.size())
	return ""


## Removes what this machine gives and adds what it receives, in that order.
##
## Removal first, always. Adding first can overflow a full stash and lose the
## overflow to `receive_gear`'s salvage path - which is correct behaviour for a
## battlefield drop and quietly destroys a traded piece.
func _apply_locally(given: Array, received: Array) -> void:
	for entry: Variant in given:
		var piece := entry as Dictionary
		var index: int = Stash.index_of(MetaState.stash, int(piece.get("uid", 0)))
		if index >= 0:
			MetaState.drop_gear(index)
	for entry: Variant in received:
		var piece := (entry as Dictionary).duplicate(true)
		# A fresh name on arrival. Two accounts hand out names independently and
		# the receiving stash is the one that has to keep them apart.
		piece["uid"] = Stash.new_uid()
		MetaState.take_gear(piece)


## Whether this machine can deliver what it has offered and hold what is coming.
##
## The rules are in `TradeSession.deliverable`, over a plain array, so they can
## be driven without a save or a socket - this is only the part that knows where
## this machine's stash lives.
func _can_deliver(given: Array, incoming: int) -> String:
	return TradeSession.deliverable(MetaState.stash, MetaState.equipped, given,
		incoming, Balance.STASH_CAPACITY)


## The same question about this machine's own half, asked before confirming.
func _my_half_is_deliverable() -> String:
	if _session == null:
		return "There is no trade open."
	return _can_deliver(_session.offer(_side),
		_session.offer(TradeSession.other_side(_side)).size())


# --- Guest side ---------------------------------------------------------------

func _on_state_from_host(wire: Array) -> void:
	if Coop.is_host():
		return
	if _session == null:
		_session = TradeSession.new()
		_side = TradeSession.GUEST
		_partner_name = _read_partner_name()
	if not _session.from_wire(wire):
		return
	if not _session.is_running():
		_session = null
	changed.emit()


func _on_settled_by_host(given: Array, received: Array) -> void:
	if Coop.is_host():
		return
	# **Re-checked on arrival.** The host has already moved its own half by the
	# time this lands, so refusing here costs the host its offer - but applying a
	# settlement this machine cannot honour is how a piece ends up in two
	# stashes, and that is the one outcome worth losing gear to avoid.
	var problem: String = _can_deliver(given, received.size())
	if not problem.is_empty():
		EventBus.preparation_warning.emit("TRADE FAILED  ·  %s" % problem)
		_session = null
		changed.emit()
		return
	_apply_locally(given, received)
	_session = null
	changed.emit()
	EventBus.trade_completed.emit(given.size(), received.size())


# --- Shared -------------------------------------------------------------------

func _publish() -> void:
	if Coop.is_host() and _session != null:
		EventBus.coop_trade_state.emit(_session.to_wire())
	changed.emit()


func _is_equipped(index: int) -> bool:
	for slot: Variant in MetaState.equipped:
		if int(MetaState.equipped[slot]) == index:
			return true
	return false


## Whether a piece described by the other machine could exist at all.
func _well_formed(piece: Dictionary) -> String:
	if piece == null or piece.is_empty():
		return "it is empty"
	if ContentDB.gear(String(piece.get("kind", ""))) == null:
		return "there is no such gear as '%s'" % String(piece.get("kind", ""))
	var rarity: int = int(piece.get("rarity", -1))
	if rarity < 0 or rarity >= Stash.RARITY_NAMES.size():
		return "rarity %d is not a rarity" % rarity
	var level: int = int(piece.get("level", 0))
	if level < 1 or level > Stash.MAX_LEVEL:
		return "level %d is not a level" % level
	if int(piece.get("uid", 0)) == 0:
		return "it has no name"
	return ""


func _read_partner_name() -> String:
	for seat: Variant in Coop.party().seats():
		var person := seat as CoopParty.Seat
		if person != null and person.slot != Coop.party().slot():
			return person.name
	return "your partner"
