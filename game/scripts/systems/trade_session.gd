class_name TradeSession
extends RefCounted

## The rules of a two-player trade, with no network and no save in them.
##
## Owner brief, 2026-09-10: "players to be able to initiate trades with each
## other! Trading stash items between 2 players at a time if they request a
## trade and have it accepted similar to runescape style".
##
## **Everything that can go wrong here is silent and permanent**, which is why
## this file has no socket and no `MetaState` in it. Gear is account-level and
## survives runs; a trade that duplicates a piece prints nothing, fails nothing,
## and quietly ruins the loot economy the whole between-run layer rests on. A
## trade that eats a piece is worse and equally quiet. Neither is a thing to
## find out about from a player.
##
## So the rules live in a pure object that `trade_check` can drive thousands of
## times without a peer, and the machinery that owns real stashes - `TradeBooth`
## - is the thin part on top. It is the same split `CrossroadScreen.winning_road`
## uses and for the same reason: the part that must be identical on both
## machines is the part worth testing, and neither is true of a function that
## needs a live socket to call.
##
## **The one rule this system exists for** is that changing an offer takes back
## both acceptances. It is the oldest trade-window scam there is: agree a deal,
## wait for the other player to accept, swap your side for something worthless
## in the last half second. RuneScape's answer is that any change puts everybody
## back to unaccepted, and there is a second screen after that showing what is
## actually about to happen. Both are here.

enum Stage {
	## Nobody has asked for anything.
	IDLE,
	## One side has asked; the other has not answered.
	INVITED,
	## Both are here, and either may change what they are offering.
	OFFERING,
	## Both accepted the offers as they stand. The second screen.
	CONFIRMING,
	## Both confirmed. `TradeBooth` may now move gear, and only now.
	SETTLING,
	## Over, one way or another. `outcome` says which.
	CLOSED,
}

const HOST: String = "host"
const GUEST: String = "guest"
const SIDES: Array[String] = [HOST, GUEST]

var stage: Stage = Stage.IDLE

## Why the trade closed, for the player. Empty while it is still running.
var outcome: String = ""

## Which side asked. Only the other one may answer the invitation.
var invited_by: String = ""

var _offers: Dictionary = {HOST: [], GUEST: []}
var _accepted: Dictionary = {HOST: false, GUEST: false}
var _confirmed: Dictionary = {HOST: false, GUEST: false}


static func other_side(side: String) -> String:
	return GUEST if side == HOST else HOST


func offer(side: String) -> Array:
	return _offers.get(side, []) as Array


func has_accepted(side: String) -> bool:
	return bool(_accepted.get(side, false))


func has_confirmed(side: String) -> bool:
	return bool(_confirmed.get(side, false))


func is_running() -> bool:
	return stage != Stage.IDLE and stage != Stage.CLOSED


# --- Opening ------------------------------------------------------------------

## One player asks the other for a trade.
func invite(side: String) -> String:
	if not SIDES.has(side):
		return "There is nobody by that name to trade with."
	if is_running():
		return "A trade is already open."
	stage = Stage.INVITED
	invited_by = side
	outcome = ""
	return ""


## The other player says yes.
##
## Only the other player. A side accepting its own invitation would open a trade
## the second player never agreed to, and in a system where the next screen moves
## permanent gear that is not a nicety.
func accept_invite(side: String) -> String:
	if stage != Stage.INVITED:
		return "There is no invitation to answer."
	if side == invited_by:
		return "You cannot accept your own invitation."
	if not SIDES.has(side):
		return "There is nobody by that name to trade with."
	stage = Stage.OFFERING
	return ""


# --- Offering -----------------------------------------------------------------

## Replaces one side's offer.
##
## **This is where both acceptances are taken back**, and it is the whole reason
## the stage exists. Changing what is on the table after somebody has agreed to
## it is the oldest scam in every game that has ever had a trade window, and the
## answer everywhere is the same: any change and everybody agrees again.
##
## Set wholesale rather than added to one piece at a time. An offer is a list,
## the wire carries the list, and both machines then hold the same list by
## construction rather than by having applied the same sequence of edits in the
## same order.
func set_offer(side: String, pieces: Array, capacity: int) -> String:
	if stage != Stage.OFFERING and stage != Stage.CONFIRMING:
		return "The trade is not open for changes."
	if not SIDES.has(side):
		return "There is nobody by that name to trade with."
	if pieces.size() > capacity:
		return "You cannot put more than %d pieces on the table." % capacity

	# **The same piece may not appear twice in one offer.** Offering index 4 and
	# index 4 again is how one sword becomes two, and it costs nothing to refuse.
	var seen: Dictionary = {}
	for entry: Variant in pieces:
		var piece := entry as Dictionary
		if piece == null or piece.is_empty():
			return "That is not a piece of gear."
		var uid: int = int(piece.get("uid", 0))
		if uid == 0:
			return "That piece has no name and cannot be traded."
		if seen.has(uid):
			return "You have put the same piece on the table twice."
		seen[uid] = true

	_offers[side] = pieces.duplicate(true)
	_unaccept_everybody()
	return ""


## Says this side is happy with the table as it stands.
func set_accepted(side: String, wanted: bool) -> String:
	if stage != Stage.OFFERING:
		return "The trade is not waiting for that."
	if not SIDES.has(side):
		return "There is nobody by that name to trade with."
	_accepted[side] = wanted
	if has_accepted(HOST) and has_accepted(GUEST):
		stage = Stage.CONFIRMING
		_confirmed = {HOST: false, GUEST: false}
	return ""


## The second screen: says this side has read what is about to happen.
func set_confirmed(side: String, wanted: bool) -> String:
	if stage != Stage.CONFIRMING:
		return "There is nothing to confirm yet."
	if not SIDES.has(side):
		return "There is nobody by that name to trade with."
	_confirmed[side] = wanted
	if has_confirmed(HOST) and has_confirmed(GUEST):
		stage = Stage.SETTLING
	return ""


## Both sides have read the second screen and agreed to it.
func ready_to_settle() -> bool:
	return stage == Stage.SETTLING


# --- Closing ------------------------------------------------------------------

## Ends the trade with nothing moved. Anybody may do this at any point up to the
## moment it settles, which is the other half of the second screen being worth
## anything.
func close(reason: String) -> void:
	stage = Stage.CLOSED
	outcome = reason
	_offers = {HOST: [], GUEST: []}
	_unaccept_everybody()


## Marks a settlement that actually happened.
func close_settled() -> void:
	stage = Stage.CLOSED
	outcome = "Trade complete."
	_unaccept_everybody()


func _unaccept_everybody() -> void:
	_accepted = {HOST: false, GUEST: false}
	_confirmed = {HOST: false, GUEST: false}
	# A change during the second screen puts everybody back on the first one.
	# Leaving them on the confirmation screen with the acceptances silently
	# withdrawn is the same scam wearing a different hat: the words on screen
	# would still describe the deal that was agreed.
	if stage == Stage.CONFIRMING or stage == Stage.SETTLING:
		stage = Stage.OFFERING


# --- Can this actually happen? -------------------------------------------------
#
# Static and over a plain array, so `trade_check` can drive every way a
# settlement can fail without a save file, a socket or a second machine. The
# cases below are the ones that end with gear in two places or in none, and each
# of them is a real sequence of events rather than a hypothetical: a partner
# breaking a duplicate while it sits on the table, a run ending and delivering a
# drop into the last free slot, a piece upgraded between the offer and the
# confirmation.

## Whether a stash can hand over `given` and take `incoming` pieces back.
##
## Returns "" or the reason. **Every reason aborts the whole trade** rather than
## trimming it to what fits: a trade that quietly delivers half of what was
## agreed is a worse outcome than one that plainly did not happen, because the
## player has already been shown the table they said yes to.
static func deliverable(stash: Array, equipped: Dictionary, given: Array,
		incoming: int, capacity: int) -> String:
	var seen: Dictionary = {}
	for entry: Variant in given:
		var piece := entry as Dictionary
		if piece == null or piece.is_empty():
			return "Something on the table is not a piece of gear."
		var uid: int = int(piece.get("uid", 0))
		if uid == 0:
			return "A piece on the table has no name."
		if seen.has(uid):
			return "The same piece is on the table twice."
		seen[uid] = true
		var index: int = Stash.index_of(stash, uid)
		if index < 0:
			return "A piece on the table is no longer in the stash."
		if not Stash.same_gear(stash[index] as Dictionary, piece):
			return "A piece on the table has changed since it was offered."
		if _worn_at(equipped, index):
			return "A piece on the table is being worn."
	var after: int = stash.size() - given.size() + incoming
	if after > capacity:
		return "There is no room for %d more pieces." % incoming
	return ""


static func _worn_at(equipped: Dictionary, index: int) -> bool:
	for slot: Variant in equipped:
		if int(equipped[slot]) == index:
			return true
	return false


## The whole state, flattened for the wire.
##
## One message rather than a stream of edits. Both machines then hold the same
## table because they were told the same table, not because they replayed the
## same sequence of changes in the same order - and a dropped edit in the middle
## of that sequence is a desync in a screen that moves permanent gear.
func to_wire() -> Array:
	return [int(stage), invited_by, _offers[HOST], _offers[GUEST],
		_accepted[HOST], _accepted[GUEST], _confirmed[HOST], _confirmed[GUEST],
		outcome]


## Takes the host's account of the trade. Guest side.
##
## Returns false on anything malformed rather than half-applying it: a partial
## table is a table that disagrees with the other machine, which is the one
## thing this whole design is arranged to prevent.
func from_wire(wire: Array) -> bool:
	if wire.size() != 9:
		return false
	if not (wire[2] is Array) or not (wire[3] is Array):
		return false
	stage = int(wire[0]) as Stage
	invited_by = String(wire[1])
	_offers = {HOST: (wire[2] as Array).duplicate(true),
		GUEST: (wire[3] as Array).duplicate(true)}
	_accepted = {HOST: bool(wire[4]), GUEST: bool(wire[5])}
	_confirmed = {HOST: bool(wire[6]), GUEST: bool(wire[7])}
	outcome = String(wire[8])
	return true
