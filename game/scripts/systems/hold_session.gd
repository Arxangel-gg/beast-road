class_name HoldSession
extends Node

## **Who is standing in the Hold, and whose word that is.**
##
## Owner ruling, 2026-09-17: the Hold stands up with simulated Wardens in it,
## a player who arrives *takes the place of one of them*, it is private by
## default and toggled from inside, a public Hold is matchable, a freed seat
## makes it matchable again, being in one Hold is not being in a party, and a
## host who leaves hands it to somebody staying - preferring a player whose own
## Hold was public, because they have already said they do not mind strangers.
##
## **The bound is the one co-op already lives under: the host is the authority
## and nothing a guest says is trusted.** A seat is *presence* - a name, a
## title and a place to stand - and nothing else. No stranger's save, stash,
## pen or gear is written by anybody but its owner; a simulated Warden holds no
## state at all, so there is nothing in one worth forging. The Ledger still
## publishes prices and never pieces, which is the rule that *is* about
## authority and is untouched by this.
##
## **It is the co-op session, not a second network.** A Hold is a room hosted
## the way the co-op lobby hosts one, found the way the lobby finds one, and
## relayed down the same wire. What makes it a Hold rather than a party is that
## no run has started: `CoopParty` is still what decides who walks the road, so
## three strangers in a yard are three strangers in a yard.
##
## **Migration is a re-gather rather than a seamless transfer, and that is a
## transport fact rather than a preference.** `Coop.host_room()` must `leave()`
## before it can ask for a code, so a successor cannot hand its code back
## through the session it is about to drop. So the host names a successor
## before it goes; the successor opens its own Hold at once and publishes it if
## it is public, and everybody else is told who took it. Nobody is stranded and
## nothing pretends to be a handover it is not.

## What is standing in a seat.
##
## Appended to, never inserted: the wire carries these by number, and this
## project has shipped content pointing at the wrong enum member twice.
enum Seat {
	EMPTY,
	## Nobody. A figure with a name, walking between the same buildings, so the
	## Hold is somewhere people are rather than somewhere people might be.
	SIMULATED,
	## This machine's Warden.
	LOCAL,
	## Another player, in a seat the host gave them.
	REMOTE,
}

## Where private-by-default lives. A new account has no key, which reads as
## private - the ruling's own default, arrived at by the save doing nothing.
const PUBLIC_KEY: String = "hold_public"

signal seats_changed()
signal note(line: String)

var yard: HoldYard = null

## The table, by seat index. Index is the party slot, so every machine agrees
## about which figure is which - the yard's own numbering is local and the
## session maps between them.
var _table: Array[Dictionary] = []
## Which seat this machine is sitting in.
var _mine: int = 0
## Table index to the figure in the yard that is drawing it.
var _figure: Dictionary = {}
var _handed_to: String = ""


func _ready() -> void:
	name = "HoldSession"
	_table.resize(Balance.HOLD_SEATS)
	for index: int in _table.size():
		_table[index] = {"peer": 0, "name": "", "title": "",
			"kind": Seat.SIMULATED, "pen": [], "was_public": false, "look": []}
	EventBus.hold_seats.connect(_on_seats_told)
	EventBus.hold_moved.connect(_on_moved_told)
	EventBus.hold_handover.connect(_on_handover_told)
	EventBus.coop_request_received.connect(_on_request)
	set_process(true)


# ------------------------------------------------------------------ the policy


static func is_public() -> bool:
	return bool(MetaState.settings.get(PUBLIC_KEY, false))


## Opens or closes the doors. Public means *matchable*: the Hold is listed, and
## a player searching may be handed a seat in it without being invited.
func set_public(on: bool) -> void:
	MetaState.settings[PUBLIC_KEY] = on
	MetaState.save_game()
	if on:
		_advertise()
	else:
		_withdraw()
		note.emit("The Hold is private. Only players you invite may come in.")
	seats_changed.emit()


## Called when the Hold opens. A session that already exists is adopted rather
## than replaced: a party that walked in here together is still a party.
func open() -> void:
	_read_session()
	if is_public() and not Coop.is_networked():
		_advertise()
	seats_changed.emit()


## Called when the Hold closes. The listing goes; the session does not - a
## party that is about to take the road is in the middle of doing so.
func close() -> void:
	_withdraw()


## A code to hand somebody. Private Holds are invite-only and this is the
## invitation; it does not list the Hold and does not make it matchable.
func invite() -> String:
	if Coop.is_guest():
		note.emit("Only the Hold's host may invite.")
		return ""
	if not Coop.room_code.is_empty():
		return Coop.room_code
	var code: String = Coop.host_room()
	if code.is_empty():
		note.emit("This build cannot open a room.")
		return ""
	_read_session()
	note.emit("Invite code %s - anybody with it may walk in." % code)
	return code


## Looks for somewhere to be. The same search the co-op lobby uses, because a
## Hold is a room that has not started a run.
func find(done: Callable = Callable()) -> void:
	var directory: CoopDirectory = Coop.directory()
	if directory == null:
		return
	note.emit("Looking for a Hold with room in it...")
	directory.find_party(func(joinable: bool, code: String) -> void:
		if joinable and not code.is_empty():
			Coop.join_room(code)
			note.emit("Walking into somebody else's Hold.")
		else:
			note.emit("Nobody is holding a door open. Yours is the one that is.")
			if is_public():
				_advertise()
		if done.is_valid():
			done.call(joinable))


func _advertise() -> void:
	if Coop.is_guest():
		return
	var code: String = Coop.room_code
	if code.is_empty():
		code = Coop.host_room()
	if code.is_empty():
		return
	var directory: CoopDirectory = Coop.directory()
	if directory == null:
		return
	directory.set_password("")
	directory.publish(code, "%s's Hold" % _my_name())
	note.emit("The Hold is public. Anybody looking for one may walk in.")


func _withdraw() -> void:
	var directory: CoopDirectory = Coop.directory()
	if directory != null and directory.is_listed():
		directory.withdraw()


# ------------------------------------------------------------------- the seats


func _my_name() -> String:
	return MetaState.player_name if not MetaState.player_name.is_empty() else "Oathless"


## Reads the seats off the session this machine is actually in.
##
## The host derives the table from the party - which already knows who is
## connected and in which slot - and says so. A guest reads nothing: it waits
## to be told, which is the whole bound in one line.
func _read_session() -> void:
	if not Coop.is_networked():
		_mine = 0
		for index: int in _table.size():
			_table[index]["kind"] = Seat.LOCAL if index == 0 else Seat.SIMULATED
			_table[index]["name"] = _my_name() if index == 0 else ""
			_table[index]["peer"] = 0
			_table[index]["pen"] = MetaState.pen if index == 0 else []
		_draw_table()
		return
	if Coop.is_host():
		_compose()
		return
	_mine = maxi(Coop.party().slot_for_peer(multiplayer.get_unique_id()), 0)
	_draw_table()


## Host only: who is here, and tell everybody.
func _compose() -> void:
	_mine = 0
	for index: int in _table.size():
		_table[index]["kind"] = Seat.SIMULATED
		_table[index]["name"] = ""
		_table[index]["peer"] = 0
		_table[index]["was_public"] = false
		# A seat nobody is in still has animals in its paddock. See
		# `_simulated_pen`: the Hold is meant to be somewhere people *are*.
		# Keyed the way the yard names these seats, so the Warden called Marrow
		# keeps Marrow's animals - `HoldYard` picks the name from the same
		# expression, and two different keys would put one name over another's pen.
		_table[index]["pen"] = _simulated_pen(MetaState.play_code + str(index))
	_table[0]["kind"] = Seat.LOCAL
	_table[0]["name"] = _my_name()
	_table[0]["title"] = MetaState.warden_title()
	_table[0]["pen"] = MetaState.pen
	_table[0]["look"] = WardenLook.pack(WardenLook.mine())
	var slot: int = 1
	for peer: int in multiplayer.get_peers():
		if slot >= _table.size():
			break
		_table[slot]["kind"] = Seat.REMOTE
		_table[slot]["peer"] = peer
		if String(_table[slot]["name"]).is_empty():
			_table[slot]["name"] = "Warden"
		slot += 1
	_publish_table()
	_draw_table()


## The table on the wire. Rows of strings rather than a dictionary, because a
## packet is read by number and a row that gained a field would be read by an
## older build as a row that lost one.
func _publish_table() -> void:
	if not Coop.is_host():
		return
	var rows: Array = []
	for seat: Dictionary in _table:
		rows.append([int(seat["kind"]), String(seat["name"]), String(seat["title"]),
			_species_of(seat.get("pen", []) as Array), seat.get("look", []) as Array])
	EventBus.hold_seats.emit(rows)


## Guest side: the host's word about who is standing here.
##
## **A guest's own seat is whatever the host says it is.** The kind that
## arrives as LOCAL is the host's seat, so every seat but this machine's own is
## drawn as somebody else - which is why the local index is read from the party
## rather than from the table.
func _on_seats_told(rows: Array) -> void:
	if Coop.is_host():
		return
	for index: int in mini(rows.size(), _table.size()):
		var row: Variant = rows[index]
		if not (row is Array) or (row as Array).size() < 3:
			continue
		var fields: Array = row
		_table[index]["kind"] = int(fields[0])
		_table[index]["name"] = String(fields[1])
		_table[index]["title"] = String(fields[2])
		if fields.size() > 3 and fields[3] is Array and index != _mine:
			_table[index]["pen"] = _roster_from(String(fields[1]), fields[3] as Array)
		if fields.size() > 4 and fields[4] is Array and index != _mine:
			_table[index]["look"] = WardenLook.pack(WardenLook.unpack(fields[4]))
	_draw_table()


## Lays the table onto the yard's figures: this machine's seat is the one it
## drives, and every other occupied seat is a figure it is told about.
func _draw_table() -> void:
	_figure.clear()
	if yard == null:
		seats_changed.emit()
		return
	var next: int = 1
	for index: int in _table.size():
		var seat: Dictionary = _table[index]
		var kind: int = int(seat["kind"])
		if index == _mine:
			_figure[index] = 0
			yard.set_seat(0, Seat.LOCAL, _my_name(), MetaState.warden_title())
			yard.set_pen(0, MetaState.pen)
			yard.set_look(0, WardenLook.pack(WardenLook.mine()))
			continue
		if next >= yard.seats():
			break
		_figure[index] = next
		yard.set_seat(next, kind, String(seat["name"]), String(seat["title"]))
		yard.set_pen(next, seat.get("pen", []) as Array)
		yard.set_look(next, seat.get("look", []) as Array)
		next += 1
	seats_changed.emit()


func occupied() -> int:
	var count: int = 0
	for seat: Dictionary in _table:
		if int(seat["kind"]) == Seat.LOCAL or int(seat["kind"]) == Seat.REMOTE:
			count += 1
	return count


func seat_kind(index: int) -> int:
	if index < 0 or index >= _table.size():
		return Seat.EMPTY
	return int(_table[index]["kind"])


func my_seat() -> int:
	return _mine


# ----------------------------------------------------------------- the walking


## This machine's Warden moved. The host says so; a guest asks.
##
## **By seat, never by figure.** The yard numbers its figures locally so that
## the one you drive is always the first; the wire numbers seats so that four
## machines agree about who is who. Sending a yard index would have every guest
## moving the host.
func report(at: Vector2, facing: Vector2) -> void:
	if not Coop.is_networked():
		return
	if Coop.is_host():
		EventBus.hold_moved.emit(_mine, at, facing)
		return
	var line: CoopRelay = Coop.relay()
	if line != null:
		line.request(CoopRelay.Request.HOLD_MOVE, [at, facing])


func _on_moved_told(seat: int, at: Vector2, facing: Vector2) -> void:
	if seat == _mine:
		return
	if yard == null or not _figure.has(seat):
		return
	yard.move_seat(int(_figure[seat]), at, facing)


## Host side: a guest said where it is, or introduced itself. Neither is
## believed about anything but presence - a name and a place to stand are the
## only things a guest is the authority on, because they are the only things
## that are not the run's.
func _on_request(kind: int, args: Array, from: int) -> void:
	if not Coop.is_host():
		return
	var slot: int = Coop.party().slot_for_peer(from)
	if slot <= 0 or slot >= _table.size():
		return
	match kind:
		CoopRelay.Request.HOLD_HELLO:
			if args.size() < 2:
				return
			_table[slot]["kind"] = Seat.REMOTE
			_table[slot]["peer"] = from
			_table[slot]["name"] = String(args[0]).left(Balance.SCORE_NAME_MAX)
			_table[slot]["title"] = String(args[1]).left(48)
			if args.size() > 2 and args[2] is Array:
				_table[slot]["pen"] = _roster_from(String(_table[slot]["name"]),
					args[2] as Array)
			if args.size() > 3:
				_table[slot]["was_public"] = bool(args[3])
			if args.size() > 4 and args[4] is Array:
				_table[slot]["look"] = WardenLook.pack(WardenLook.unpack(args[4]))
			_publish_table()
			_draw_table()
			note.emit("%s walked in." % String(_table[slot]["name"]))
		CoopRelay.Request.HOLD_MOVE:
			if args.size() < 2:
				return
			EventBus.hold_moved.emit(slot, args[0] as Vector2, args[1] as Vector2)
		CoopRelay.Request.PARTY_RUN_REPLY:
			if args.is_empty():
				return
			_answers[slot] = bool(args[0])
			EventBus.party_run_replied.emit(slot, bool(args[0]))


## Guest side: say who I am, once my seat is known.
func introduce() -> void:
	if not Coop.is_guest():
		return
	var line: CoopRelay = Coop.relay()
	if line != null:
		# **And whether their own doors are open.** The host prefers an
		# ex-public host when it hands the Hold on, which is the owner's own
		# clause - and a preference read off a field nobody ever writes is the
		# `DisciplineEffects` lie in a fourth place. It is presence like the
		# rest: a fact about the speaker's own settings, trusted for nothing
		# but which of them gets asked first.
		line.request(CoopRelay.Request.HOLD_HELLO,
			[_my_name(), MetaState.warden_title(), _species_of(MetaState.pen),
				is_public(), WardenLook.pack(WardenLook.mine())])


## **A pen on the wire is a list of species and nothing else.**
##
## The owner asked that a Warden can see other players' companions in their
## pens *without being able to interact with them*, and this is that rule in
## the data: what crosses is what a stranger would see over a fence. No uid,
## no bond, no rarity, no trait - nothing another account could act on, and
## nothing the receiving machine could write back.
static func _species_of(pen: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for entry: Variant in pen:
		if entry is Dictionary:
			out.append(String((entry as Dictionary).get("species", "")))
	return out


## Turns that list back into something a pen can stand up. The names are the
## seat's own, so two Wardens keeping a fox each get two different foxes -
## `Phenotype` reads the name, and identical names would be identical animals.
## What a simulated Warden keeps in their pen.
##
## The Hold's own ruling says it stands up *"with simulated Wardens in it:
## pens filled, figures about the square"*, and the figures were built while
## the pens were left as empty arrays - so every seat nobody was sitting in
## had an empty paddock beside it, and four empty paddocks is most of the
## width of this place. Photographed on 2026-09-17, which is the only way
## anybody was ever going to notice: nothing errors, the pens simply have
## nothing in them.
##
## **Derived from the name, never rolled.** The same Warden keeps the same
## animals on every machine and on every visit, with no packet and nothing
## saved - which is the rule a companion's sex, a spirit's temperament and a
## coat pattern are all already under. A roll here would give one player a
## different Hold from another's for no reason anybody could explain.
##
## **They are scenery and nothing reads them.** No bond, no collection credit,
## no rarity that pays: a simulated seat holds no state worth forging, which
## is the bound the whole seat design rests on.
static func _simulated_pen(who: String) -> Array:
	# **Never a mythic.** `IDEAS_REVIEW_2026-09-15` staged those as the rarest
	# things in the game - one legend a run, found by a trail of evidence - and
	# a Phoenix standing in a decorative paddock beside a seat nobody is even
	# sitting in takes that away for the price of a scenery roll. Photographed on
	# 2026-09-17 with one in it, which is the only way it would have been seen.
	var kinds: Array[WildlifeData] = []
	for kind: WildlifeData in ContentDB.wildlife():
		if kind != null and not kind.mythic:
			kinds.append(kind)
	if kinds.is_empty() or who.is_empty():
		return []
	var species: Array = []
	# Two or three, so the pens differ from each other at a glance without any
	# of them reading as a menagerie.
	var many: int = 2 + (who.hash() % 2)
	for index: int in many:
		var at: int = absi(hash(who + str(index))) % kinds.size()
		species.append(kinds[at].id)
	return _roster_from(who, species)


static func _roster_from(who: String, species: Array) -> Array:
	var out: Array = []
	for index: int in species.size():
		var id: String = String(species[index])
		if id.is_empty():
			continue
		out.append({"uid": "%s:%d" % [who, index], "species": id})
	return out


# --------------------------------------------------------------- the handover


## The host is leaving. Names who takes the Hold before going.
##
## **Preferring a player whose own Hold is public**, which is the owner's own
## clause and a good rule: somebody who has already opened their doors is the
## one least surprised to find strangers in their yard. Nothing about that is
## trusted for anything - it decides who is asked, never what they may do.
func hand_over() -> void:
	if not Coop.is_host() or occupied() < 2:
		return
	var successor: int = _successor()
	if successor <= 0:
		return
	_handed_to = String(_table[successor]["name"])
	EventBus.hold_handover.emit(_handed_to)
	note.emit("%s has the Hold now." % _handed_to)


func _successor() -> int:
	var fallback: int = -1
	for index: int in range(1, _table.size()):
		if int(_table[index]["kind"]) != Seat.REMOTE:
			continue
		if fallback < 0:
			fallback = index
		if bool(_table[index].get("was_public", false)):
			return index
	return fallback


## Told who took the Hold. The named player opens theirs; everybody else is put
## back in their own with a line saying where the party went.
##
## No code travels, and that is a transport fact: `Coop.host_room()` leaves the
## session before it can ask for one, so a successor cannot hand its code back
## down a wire it has already dropped. A public successor is findable by the
## same search that found this Hold; a private one hands out its own invite.
func _on_handover_told(who: String) -> void:
	_handed_to = who
	if who == _my_name():
		Coop.leave()
		if is_public():
			_advertise()
		note.emit("The Hold is yours. Your doors are %s." %
			("open" if is_public() else "closed"))
	else:
		note.emit("%s has the Hold. Yours is the one you are standing in." % who)
	_read_session()


func handed_to() -> String:
	return _handed_to


# ---------------------------------------------------------------- the road out
#
# Owner brief, 2026-09-17: *"From the hold itself players should be able to form
# parties with other players to go on a run with if they so choose, or a player
# can also go on a run solo as well from the hold too, while still being able to
# go on runs from the main menu without going into the hold as well ... once the
# host is ready to start the run, they will prompt the rest of the party that
# the run is a continue run with the appropriate details about the run and the
# rest of the party will be given a timed chance to accept to join the host on
# their continued run. The host is also able to choose to do a new run or start
# from an act as well with their party besides just continuing a run."*
#
# **A proposal rather than a departure**, which is the shape `PartyEvents`
# already put raids and rifts to a party in: the host owns the run, and a road
# is the one decision that costs everybody the next hour. A continued run in
# particular is *somebody else's* banked front, so the party is told which kind
# of road it is, where it opens, and how long they have to answer.
#
# **The host decides when it is not unanimous**, exactly as it does for a raid,
# and a road nobody answers goes anyway once the clock runs out - a party left
# standing in a yard because one seat walked away from the keyboard is worse
# than a road one player did not want.

## What kind of road is being offered. Appended to, never inserted: the wire
## carries it by number.
enum Road { FRESH, CONTINUE, ACT_START }

## Who has answered, by seat. Host side, cleared when an offer opens.
var _answers: Dictionary = {}
var _offer: int = -1
var _offer_left: float = 0.0


## Host side: put a road to the party. Returns false when there is nobody to
## ask, which is the solo case and is the caller's cue to simply go.
func offer_run(kind: int, act: int, detail: String) -> bool:
	if not Coop.is_host() or occupied() < 2:
		return false
	_answers.clear()
	_offer = kind
	_offer_left = Balance.PARTY_ROAD_ANSWER_SECONDS
	EventBus.party_run_offered.emit(kind, act, detail,
		Balance.PARTY_ROAD_ANSWER_SECONDS)
	return true


## Guest side: yes or no to the road that was put to us.
func reply(accepted: bool) -> void:
	if not Coop.is_guest():
		return
	var line: CoopRelay = Coop.relay()
	if line != null:
		line.request(CoopRelay.Request.PARTY_RUN_REPLY, [accepted])


## Whether every seat has answered. Host side.
func everyone_answered() -> bool:
	return _answers.size() >= maxi(occupied() - 1, 0)


## Who said yes, by seat. Host side.
func accepted_seats() -> Array[int]:
	var out: Array[int] = []
	for key: Variant in _answers:
		if bool(_answers[key]):
			out.append(int(key))
	return out


func offer_seconds_left() -> float:
	return _offer_left


func _process(delta: float) -> void:
	if _offer < 0:
		return
	_offer_left = maxf(_offer_left - delta, 0.0)
	if _offer_left <= 0.0 or everyone_answered():
		_offer = -1
