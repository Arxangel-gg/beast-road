class_name CoopParty
extends Node

## Who is in the party, which slot each of them holds, and what colour that is.
##
## **Slots exist because peer ids are not seats.** A transport hands out ids that
## are meaningful to it and nobody else - the host is 1 and a client is whatever
## number the socket produced - and they are not stable, not ordered, and not
## the same on both transports. A slot is a seat at the table: 1 to 4, the host
## is always 1, and everything a player sees about themselves and each other is
## keyed on it. Colour, spawn point, the party list, the chat name.
##
## The host assigns them and says so. That is the only way four machines can
## agree, and it is the same authority rule everything else here follows: a
## guest that picked its own slot would be picking somebody else's colour.

## One player. `peer` is the transport's id, which only the host uses.
class Seat extends RefCounted:
	var slot: int = 0
	var peer: int = 0
	var name: String = ""

	func colour() -> Color:
		return Balance.PARTY_COLOURS[clampi(slot - 1, 0,
			Balance.PARTY_COLOURS.size() - 1)]

	func colour_name() -> String:
		return Balance.PARTY_COLOUR_NAMES[clampi(slot - 1, 0,
			Balance.PARTY_COLOUR_NAMES.size() - 1)]


signal roster_changed()

## Slot number to Seat, for every player in the party including this one.
var _seats: Dictionary = {}

## Which slot this machine holds. 1 on a host, assigned on a guest, 0 when alone.
var _own_slot: int = 0


func _ready() -> void:
	EventBus.coop_party_roster.connect(_on_roster)


## This machine's seat number, or **0 while it does not yet know**.
##
## Zero matters. It used to answer 1 whenever it was unsure, which is right for a
## lone player and actively wrong for a guest whose roster has not landed: every
## guest believed it was seat one, wore red, and put its own hero on top of the
## host's. Two heroes claiming the same seat is not a display bug - it is two
## machines disagreeing about who is who.
##
## So: 1 when genuinely alone, the assigned seat once known, and 0 in between.
## Callers that draw something must handle 0 by waiting.
func slot() -> int:
	if not Coop.is_networked():
		return 1
	return _own_slot


func colour() -> Color:
	return colour_of(maxi(slot(), 1))


## What this machine's colour is called, for anything that says it out loud.
func colour_name_here() -> String:
	return Balance.PARTY_COLOUR_NAMES[clampi(maxi(slot(), 1) - 1, 0,
		Balance.PARTY_COLOUR_NAMES.size() - 1)]


## Every seat, lowest slot first. Ordered because it is drawn.
func seats() -> Array:
	var out: Array = []
	for number: int in range(1, Balance.COOP_MAX_PLAYERS + 1):
		if _seats.has(number):
			out.append(_seats[number])
	return out


func size() -> int:
	return maxi(_seats.size(), 1)


## Which seat a transport id belongs to, or 0. Host side: only the host knows
## peer ids, and it is how an incoming packet is attributed to a player.
func slot_for_peer(peer_id: int) -> int:
	for occupant: Variant in _seats.values():
		var person := occupant as Seat
		if person != null and person.peer == peer_id:
			return person.slot
	return 0


func seat_for_slot(number: int) -> Seat:
	return _seats.get(number, null) as Seat


## Whether anybody else is here. The question most of the game actually asks.
func in_company() -> bool:
	return _seats.size() > 1


func is_full() -> bool:
	return _seats.size() >= Balance.COOP_MAX_PLAYERS


## The colour a slot wears, for anything that draws without holding a seat.
static func colour_of(number: int) -> Color:
	return Balance.PARTY_COLOURS[clampi(number - 1, 0,
		Balance.PARTY_COLOURS.size() - 1)]


# --- Host side ---------------------------------------------------------------

## Starts a party with only this machine in it. Host side.
func open(host_name: String) -> void:
	_seats.clear()
	_own_slot = 1
	var host := Seat.new()
	host.slot = 1
	host.peer = 1
	host.name = _clean(host_name)
	_seats[1] = host
	roster_changed.emit()


## Seats a peer that has just connected, and returns the slot it was given.
##
## **The lowest free slot**, rather than the next number up. A party that loses
## its blue player and gains another should have a blue player again: colours
## are how people refer to each other out loud, and leaving a gap so the new
## arrival is green would make the party's own language wrong.
func seat(peer_id: int, player_name: String) -> int:
	for number: int in range(1, Balance.COOP_MAX_PLAYERS + 1):
		if _seats.has(number):
			continue
		var taken := Seat.new()
		taken.slot = number
		taken.peer = peer_id
		taken.name = _clean(player_name)
		_seats[number] = taken
		roster_changed.emit()
		return number
	return 0


## Removes whoever was on that peer. Host side.
func unseat(peer_id: int) -> void:
	for number: Variant in _seats.keys():
		var occupant := _seats[number] as Seat
		if occupant != null and occupant.peer == peer_id:
			_seats.erase(number)
			roster_changed.emit()
			return


func clear() -> void:
	_seats.clear()
	_own_slot = 0
	roster_changed.emit()


## The roster in the shape it crosses the wire: one row per seat.
func to_wire() -> Array:
	var rows: Array = []
	for occupant: Variant in seats():
		var person := occupant as Seat
		rows.append([person.slot, person.peer, person.name])
	return rows


# --- Guest side --------------------------------------------------------------

## The host said who is here. Everything is replaced rather than merged: the
## host's roster is the roster, and a guest reconciling two versions of it is a
## guest with an opinion about who is in the party.
##
## `own_peer` is this machine's transport id, which is how it finds itself in a
## list that describes everybody.
func _on_roster(rows: Array) -> void:
	if Coop.is_host():
		return
	var own_peer: int = multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	_seats.clear()
	_own_slot = 0
	for entry: Variant in rows:
		var row: Array = entry as Array
		if row == null or row.size() != 3:
			continue
		var number: int = clampi(int(row[0]), 1, Balance.COOP_MAX_PLAYERS)
		var person := Seat.new()
		person.slot = number
		person.peer = int(row[1])
		person.name = _clean(String(row[2]))
		_seats[number] = person
		if person.peer == own_peer:
			_own_slot = number
	roster_changed.emit()


## A name fit to draw, from a string that arrived over the wire.
static func _clean(text: String) -> String:
	var out: String = ""
	for character: String in text:
		if character.unicode_at(0) >= 32 and out.length() < 24:
			out += character
	out = out.strip_edges()
	return out if not out.is_empty() else "Warden"
