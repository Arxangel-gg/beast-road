extends Node

## Two players swap gear, and no sequence of events ever makes a piece twice.
##
## Owner brief, 2026-09-10: RuneScape-style trading between two players. The
## reason this gate is long is that **every failure here is silent and
## permanent**. Gear is account-level and survives runs; a trade that duplicates
## a piece prints nothing, fails nothing, and quietly ruins the loot economy the
## whole between-run layer rests on. A trade that eats a piece is worse and
## equally quiet. Neither is a thing to learn about from a player.
##
## Three families of test, in the order they matter.
##
## **The rules**, driven on `TradeSession` with no save and no socket. Chief
## among them: changing an offer takes back both acceptances. That is the oldest
## trade-window scam there is - agree a deal, wait for the other player to
## accept, swap your side for something worthless in the last half second - and
## it is the reason the second screen exists at all.
##
## **Deliverability**, driven on `TradeSession.deliverable` over plain arrays.
## Each case is a real sequence rather than a hypothetical: a partner breaks a
## duplicate while it sits on the table, a run ends and drops gear into the last
## free slot, a piece is upgraded between the offer and the confirmation.
##
## **Conservation**, driven through `TradeBooth` against a real `MetaState`
## stash. Both halves of a swap are applied and the pieces are counted before
## and after. This is the one that would catch a duplication bug the other two
## families missed, and it is the reason it exists.
##
## **The window**, built for real and walked. This family exists because three
## separate structural faults in it were found by *looking at a screenshot* -
## headings that were cleared along with the rows they captioned, a row laid out
## inside a Button that positions its own content, and a local copy of the table
## that disagreed with the session. None of them failed anything. A window whose
## faults are only visible to a person is a window that ships broken the first
## time nobody looks, so the shapes that went wrong are asserted here.
##
## Headless has no real font, so nothing below measures a pixel: these are
## questions about what exists and what it says, which is where all three faults
## actually lived.

var _failures: int = 0
var _checked: int = 0

## How many of the counted tests below reached their end.
##
## A script error aborts the function it happens in and nothing else, and this
## gate has enough moving parts to hide one. `crossroad_vote_check` grew the
## same counter after going green on a subject that would not compile.
var _finished: int = 0
const EXPECTED_TESTS: int = 16

## The player's real stash, put back exactly as it was.
var _stash_before: Array = []
var _equipped_before: Dictionary = {}


func _ready() -> void:
	# **Held before anything is touched.** This gate rewrites `MetaState.stash`
	# a dozen times, and putting it back at the end is not the same as never
	# having written it: any push_error path, any script error, any early quit
	# leaves the player holding probe gear. `save_guard_check` exists for exactly
	# this and did not catch it, because its list of mutating gates was kept by
	# hand and this one was written after it.
	MetaState.hold_saves()
	await get_tree().process_frame
	_stash_before = MetaState.stash.duplicate(true)
	_equipped_before = MetaState.equipped.duplicate(true)

	_test_only_the_other_side_may_accept()
	_test_changing_an_offer_withdraws_both_acceptances()
	_test_a_change_during_confirmation_goes_back_a_screen()
	_test_the_same_piece_cannot_be_offered_twice()
	_test_the_table_is_bounded()
	_test_the_wire_round_trips()
	_test_deliverability_refuses_every_way_it_can_fail()
	_test_a_whole_swap_conserves_every_piece()
	_test_a_colliding_name_is_renamed_on_arrival()
	_test_a_refused_half_moves_nothing()
	await _test_an_offer_is_named_not_positioned()
	await _test_a_partner_leaving_ends_the_trade()
	await _test_the_headings_survive_a_refresh()
	await _test_every_row_carries_its_own_action()
	await _test_the_confirmation_screen_says_where_the_partner_is()
	_test_a_name_survives_the_save_file()

	if _finished != EXPECTED_TESTS:
		_check(false, "only %d of %d tests ran to completion" % [_finished, EXPECTED_TESTS])
	_finish()


# --- The rules ----------------------------------------------------------------

func _test_only_the_other_side_may_accept() -> void:
	var trade := TradeSession.new()
	_checked += 1
	_check(trade.invite(TradeSession.HOST).is_empty(), "the host could not invite")
	_checked += 1
	_check(not trade.accept_invite(TradeSession.HOST).is_empty(),
		"a side accepted its own invitation, opening a trade nobody agreed to")
	_checked += 1
	_check(trade.accept_invite(TradeSession.GUEST).is_empty(),
		"the invited side could not accept")
	_checked += 1
	_check(trade.stage == TradeSession.Stage.OFFERING,
		"accepting an invitation did not open the table")
	_finished += 1


## **The rule the whole system exists for.**
func _test_changing_an_offer_withdraws_both_acceptances() -> void:
	var trade: TradeSession = _open()
	_offer(trade, TradeSession.HOST, [_piece("a")])
	_offer(trade, TradeSession.GUEST, [_piece("b")])
	trade.set_accepted(TradeSession.HOST, true)
	trade.set_accepted(TradeSession.GUEST, true)
	_checked += 1
	_check(trade.stage == TradeSession.Stage.CONFIRMING,
		"two acceptances did not reach the confirmation screen")

	# The scam: swap your side once the other player has agreed.
	_offer(trade, TradeSession.HOST, [_piece("worthless")])
	_checked += 1
	_check(not trade.has_accepted(TradeSession.GUEST),
		("the partner's acceptance survived a change to the other offer; that is "
			+ "the last-second swap this entire design exists to prevent"))
	_checked += 1
	_check(not trade.has_accepted(TradeSession.HOST),
		"the changing side's own acceptance survived its change")
	_finished += 1


func _test_a_change_during_confirmation_goes_back_a_screen() -> void:
	var trade: TradeSession = _open()
	_offer(trade, TradeSession.HOST, [_piece("a")])
	_offer(trade, TradeSession.GUEST, [_piece("b")])
	trade.set_accepted(TradeSession.HOST, true)
	trade.set_accepted(TradeSession.GUEST, true)
	trade.set_confirmed(TradeSession.HOST, true)
	_offer(trade, TradeSession.GUEST, [_piece("c")])
	_checked += 1
	_check(trade.stage == TradeSession.Stage.OFFERING,
		("a change during confirmation left both players on the confirmation "
			+ "screen, still describing the deal that was agreed"))
	_checked += 1
	_check(not trade.has_confirmed(TradeSession.HOST),
		"a confirmation survived the offer changing under it")
	_checked += 1
	_check(not trade.ready_to_settle(), "the trade was still ready to settle")
	_finished += 1


func _test_the_same_piece_cannot_be_offered_twice() -> void:
	var trade: TradeSession = _open()
	var one: Dictionary = _piece("a")
	_checked += 1
	_check(not trade.set_offer(TradeSession.HOST, [one, one],
			Balance.TRADE_MAX_PIECES).is_empty(),
		"one piece was offered twice, which is how one sword becomes two")
	_checked += 1
	_check(trade.offer(TradeSession.HOST).is_empty(),
		"a refused offer was still put on the table")
	# And a piece with no name cannot be traded at all, because a name is the
	# only thing the settlement can resolve back to a position.
	var nameless: Dictionary = {"kind": "a", "rarity": 0, "level": 1}
	_checked += 1
	_check(not trade.set_offer(TradeSession.HOST, [nameless],
			Balance.TRADE_MAX_PIECES).is_empty(),
		"a piece with no name was accepted onto the table")
	_finished += 1


func _test_the_table_is_bounded() -> void:
	var trade: TradeSession = _open()
	var too_many: Array = []
	for i: int in Balance.TRADE_MAX_PIECES + 1:
		too_many.append(_piece("k%d" % i))
	_checked += 1
	_check(not trade.set_offer(TradeSession.HOST, too_many,
			Balance.TRADE_MAX_PIECES).is_empty(),
		"more than %d pieces went on the table" % Balance.TRADE_MAX_PIECES)
	_finished += 1


## The table survives the wire exactly, because both machines act on it.
func _test_the_wire_round_trips() -> void:
	var trade: TradeSession = _open()
	_offer(trade, TradeSession.HOST, [_piece("a"), _piece("b")])
	_offer(trade, TradeSession.GUEST, [_piece("c")])
	trade.set_accepted(TradeSession.HOST, true)

	var copy := TradeSession.new()
	_checked += 1
	_check(copy.from_wire(trade.to_wire()), "the table did not survive the wire")
	_checked += 1
	_check(copy.stage == trade.stage and copy.invited_by == trade.invited_by,
		"the stage or the inviter changed on the way across")
	_checked += 1
	_check(copy.offer(TradeSession.HOST).size() == 2
			and copy.offer(TradeSession.GUEST).size() == 1,
		"the offers changed size on the way across")
	_checked += 1
	_check(copy.has_accepted(TradeSession.HOST)
			and not copy.has_accepted(TradeSession.GUEST),
		"the acceptances changed on the way across")
	# A malformed packet is refused whole rather than half-applied: a partial
	# table is a table that disagrees with the other machine.
	_checked += 1
	_check(not copy.from_wire([1, 2, 3]), "a malformed table was accepted")
	_finished += 1


# --- Deliverability -----------------------------------------------------------

func _test_deliverability_refuses_every_way_it_can_fail() -> void:
	var kind: String = _any_gear_kind()
	var held: Array = [Stash.make(kind, 1), Stash.make(kind, 2), Stash.make(kind, 3)]
	var equipped: Dictionary = {0: 2}
	var cap: int = 10

	# The ordinary case first, so a blanket refusal cannot pass this test.
	_checked += 1
	_check(TradeSession.deliverable(held, equipped, [held[0]], 1, cap).is_empty(),
		"an ordinary offer was refused")

	# Broken while it sat on the table.
	var vanished: Dictionary = (held[1] as Dictionary).duplicate(true)
	var without: Array = [held[0], held[2]]
	_checked += 1
	_check(not TradeSession.deliverable(without, {}, [vanished], 0, cap).is_empty(),
		"a piece that is no longer in the stash was still handed over")

	# Upgraded between the offer and the confirmation.
	var changed: Dictionary = (held[0] as Dictionary).duplicate(true)
	changed["level"] = int(changed["level"]) + 1
	_checked += 1
	_check(not TradeSession.deliverable(held, {}, [changed], 0, cap).is_empty(),
		"a piece that changed after it was offered was still handed over")

	# Worn.
	_checked += 1
	_check(not TradeSession.deliverable(held, equipped, [held[2]], 0, cap).is_empty(),
		"a worn piece was handed over, which would silently strip the hero")

	# No room for what is coming back.
	_checked += 1
	_check(not TradeSession.deliverable(held, {}, [held[0]], 9, 3).is_empty(),
		"a trade that overflows the stash was allowed; the overflow would be salvaged")

	# And the boundary is exactly the capacity, not one short of it.
	_checked += 1
	_check(TradeSession.deliverable(held, {}, [held[0]], 1, 3).is_empty(),
		"a trade that exactly fills the stash was refused")
	_finished += 1


# --- Conservation -------------------------------------------------------------

## A whole swap, applied to real stashes, creates and destroys nothing.
##
## Both halves run through `TradeBooth` against `MetaState`, one after the other,
## because a machine only ever holds one stash and that is the code that will
## actually run. The pieces are counted by name before and after: the union of
## the two stashes must contain exactly the same names, and each name exactly
## once.
func _test_a_whole_swap_conserves_every_piece() -> void:
	var kind: String = _any_gear_kind()
	var host_stash: Array = [Stash.make(kind, 0), Stash.make(kind, 1)]
	var guest_stash: Array = [Stash.make(kind, 2), Stash.make(kind, 3)]
	var host_gives: Array = [(host_stash[0] as Dictionary).duplicate(true)]
	var guest_gives: Array = [(guest_stash[1] as Dictionary).duplicate(true)]

	var before: int = host_stash.size() + guest_stash.size()
	var host_after: Array = _apply_half(host_stash, host_gives, guest_gives)
	var guest_after: Array = _apply_half(guest_stash, guest_gives, host_gives)

	_checked += 1
	_check(host_after.size() + guest_after.size() == before,
		"a swap of one for one changed the total from %d to %d"
			% [before, host_after.size() + guest_after.size()])
	_checked += 1
	_check(_holds(host_after, kind, 3) and not _holds(host_after, kind, 0),
		"the host did not end up with what it was given, or kept what it gave")
	_checked += 1
	_check(_holds(guest_after, kind, 0) and not _holds(guest_after, kind, 3),
		"the guest did not end up with what it was given, or kept what it gave")

	_finished += 1


## A piece arriving under a name the receiving stash already uses.
##
## **The first version of this test was vacuous and said so under a negative
## control.** It asserted that no two pieces share a name and then never
## arranged for two to - both synthetic stashes were built with fresh random
## names, so deleting the rename that protects against a collision changed
## nothing and the test still passed. An assertion that cannot fail is worse
## than no assertion, because it is counted.
##
## The collision is now built deliberately. Names are handed out independently by
## two accounts, so nothing stops one arriving that the receiver is already
## using - honestly by astronomical luck, or dishonestly because a guest chose
## it. Two pieces under one name break `Stash.index_of`, which is what every
## later settlement resolves offers with: the next trade would hand over
## whichever of the two it found first.
func _test_a_colliding_name_is_renamed_on_arrival() -> void:
	var kind: String = _any_gear_kind()
	var mine: Dictionary = Stash.make(kind, 0)
	var taken: int = Stash.uid(mine)

	# What arrives claims a name this stash is already using.
	var incoming: Dictionary = Stash.make(kind, 4)
	incoming["uid"] = taken

	var after: Array = _apply_half([mine], [], [incoming])
	_checked += 1
	_check(after.size() == 2, "the arriving piece was not taken in")
	var seen: Dictionary = {}
	var repeats: int = 0
	for entry: Variant in after:
		var uid: int = int((entry as Dictionary).get("uid", 0))
		if seen.has(uid):
			repeats += 1
		seen[uid] = true
	_checked += 1
	_check(repeats == 0,
		("a piece arrived under a name the stash already used and kept it; "
			+ "`Stash.index_of` now finds two, and the next settlement would "
			+ "hand over whichever it reached first"))
	# And the pieces are still the two distinct things they were.
	_checked += 1
	_check(_holds(after, kind, 0) and _holds(after, kind, 4),
		"renaming the arrival lost one of the two pieces")
	_finished += 1


## A half that cannot be delivered moves nothing at all.
##
## The important word is *nothing*. There is no transaction to roll back to, so
## the validation and the mutation are two separate passes - and a refusal that
## had already removed the first two pieces before noticing the third is exactly
## the half-applied state this design is arranged to make impossible.
func _test_a_refused_half_moves_nothing() -> void:
	var kind: String = _any_gear_kind()
	MetaState.stash = [Stash.make(kind, 0), Stash.make(kind, 1)]
	MetaState.equipped = {}
	var before: Array = MetaState.stash.duplicate(true)

	# Offering something real *and* something that is not there any more.
	var ghost: Dictionary = Stash.make(kind, 4)
	var given: Array = [(MetaState.stash[0] as Dictionary).duplicate(true), ghost]
	var refusal: String = TradeSession.deliverable(MetaState.stash,
		MetaState.equipped, given, 0, Balance.STASH_CAPACITY)
	_checked += 1
	_check(not refusal.is_empty(), "a half with a missing piece was deliverable")
	_checked += 1
	_check(MetaState.stash.size() == before.size(),
		"checking deliverability changed the stash")
	for index: int in before.size():
		_checked += 1
		_check(Stash.same_gear(MetaState.stash[index] as Dictionary,
				before[index] as Dictionary),
			"the stash changed while a refused half was being checked")
	_finished += 1


## An offer survives the stash moving underneath it.
##
## **This is the fault the whole `uid` design exists for, at the one layer that
## could still have reintroduced it.** The screen picks from a list and therefore
## knows positions; if it kept them, a stash that changed between the pick and
## the settlement would silently turn the offer into whatever slid into those
## slots. A run ending and delivering a drop does exactly that.
##
## Two properties: the offer still names the same piece after the stash is
## disturbed, and a name that has genuinely left is dropped rather than being
## allowed to refuse a table the player can no longer edit.
func _test_an_offer_is_named_not_positioned() -> void:
	var kind: String = _any_gear_kind()
	MetaState.stash = [Stash.make(kind, 0), Stash.make(kind, 3), Stash.make(kind, 1)]
	MetaState.equipped = {}
	var wanted: int = Stash.uid(MetaState.stash[1] as Dictionary)

	TradeBooth.set("_session", _open())
	TradeBooth.set("_side", TradeSession.HOST)
	_checked += 1
	_check(TradeBooth.offer_uids([wanted]).is_empty(), "a plain offer was refused")

	# Something arrives ahead of it, so every position after index 0 moves.
	MetaState.stash.insert(0, Stash.make(kind, 2))
	var table: Array = (TradeBooth.session() as TradeSession).offer(TradeSession.HOST)
	_checked += 1
	if _check(table.size() == 1, "the offer lost its piece when the stash moved"):
		_checked += 1
		_check(int((table[0] as Dictionary).get("uid", 0)) == wanted,
			("the offer now names a different piece; it was holding a position "
				+ "rather than a name"))

	# And a name that has genuinely gone is dropped, leaving a table the player
	# can still change rather than one stuck behind a refusal.
	MetaState.stash = [Stash.make(kind, 0)]
	_checked += 1
	_check(TradeBooth.offer_uids([wanted]).is_empty(),
		"an offer naming a piece that has left the stash was refused outright")
	_checked += 1
	_check((TradeBooth.session() as TradeSession).offer(TradeSession.HOST).is_empty(),
		"a piece that has left the stash was still put on the table")
	TradeBooth.set("_session", null)
	_finished += 1
	await get_tree().process_frame


## A trade needs two players, so it ends when there is one.
##
## Without this the window stays open against nobody: the remaining player can
## still put pieces on a table that will never settle, and the stash stays locked
## against being broken for the rest of the session.
func _test_a_partner_leaving_ends_the_trade() -> void:
	TradeBooth.set("_session", _open())
	TradeBooth.set("_side", TradeSession.HOST)
	_checked += 1
	_check(TradeBooth.is_trading(), "the probe trade did not open")
	EventBus.coop_partner_left.emit(77)
	await get_tree().process_frame
	_checked += 1
	_check(not TradeBooth.is_trading(),
		"the trade survived the partner leaving, and the stash stays locked")
	_finished += 1


## A piece's name means the same thing after the game has been closed.
##
## **The save is JSON, and JSON has no integers.** Every number in it comes back
## as a double, so a name larger than 2^53 is quietly rounded on load - and a
## name that changes is not a name. This was real: uids were sixty-two bits, and
## a piece written as ...900427813 came back as ...900427264. Nothing failed and
## nothing printed; it was found by diffing a save either side of a tool run.
##
## The consequence is not hypothetical either. `index_of` and `same_gear` are
## both equality on this number, and a stash whose names are reshuffled on every
## load is a stash where an offer made before a restart names something else
## afterwards.
func _test_a_name_survives_the_save_file() -> void:
	var mangled: int = 0
	var worst: int = 0
	for _try: int in 400:
		var made: int = Stash.new_uid()
		# Exactly the round trip `MetaState` performs: written with the rest of
		# the save, parsed back on the next launch.
		var text: String = JSON.stringify({"uid": made})
		var back: int = int((JSON.parse_string(text) as Dictionary).get("uid", 0))
		if back != made:
			mangled += 1
			worst = made
	_checked += 1
	_check(mangled == 0,
		("%d of 400 piece names did not survive being written to the save and "
			+ "read back (for instance %d); JSON has no integers and these are "
			+ "past what a double holds") % [mangled, worst])
	_finished += 1


# --- The window ---------------------------------------------------------------

## A caption that survives the list it captions being rebuilt.
##
## `_refresh` empties and refills every box on the screen. The first screenshot
## of this window showed two offers under no headings at all, because the
## headings were inside the boxes being emptied - so they survived exactly until
## the first redraw, which happens before a player ever sees it.
func _test_the_headings_survive_a_refresh() -> void:
	var kinds: Array[String] = _gear_kinds(2)
	MetaState.stash = []
	for id: String in kinds:
		MetaState.stash.append(Stash.make(id, 1))
	MetaState.equipped = {}
	var trade: TradeSession = _open()
	_offer(trade, TradeSession.HOST, [MetaState.stash[0]])
	TradeBooth.set("_session", trade)
	TradeBooth.set("_side", TradeSession.HOST)
	var screen: CanvasLayer = _window()
	await get_tree().process_frame
	# Three times, because a caption that survives one redraw and not the next is
	# the same bug with a longer fuse.
	for _again: int in 3:
		screen.call("_on_trade_changed")
		await get_tree().process_frame
	var said: PackedStringArray = _words(screen)
	for wanted: String in ["You give", "You get"]:
		_checked += 1
		_check(said.has(wanted),
			"the window lost its '%s' heading when the list under it was rebuilt"
				% wanted)
	_checked += 1
	_check(_says_starting_with(said, "Your stash"),
		("the list below the offers has no heading, so its first row reads as a "
			+ "third thing being given away"))
	screen.queue_free()
	TradeBooth.set("_session", null)
	_finished += 1
	await get_tree().process_frame


## Every piece in the list has its own action, and the action tells the truth.
##
## Two faults in one assertion, because they have one cause. The offer is set
## directly on the session here - never through the screen - so a window that
## remembered its own copy of the table would draw "Offer" against a piece it is
## already giving away. That is exactly what a screenshot caught, and it is
## reachable in play by the partner's change arriving, by reopening the window,
## and by a settlement rolling back.
func _test_every_row_carries_its_own_action() -> void:
	var kinds: Array[String] = _gear_kinds(3)
	if not _check(kinds.size() >= 2, "not enough gear kinds to draw a list with"):
		_finished += 1
		return
	MetaState.stash = []
	for id: String in kinds:
		MetaState.stash.append(Stash.make(id, 1))
	MetaState.equipped = {}
	var worn: GearData = ContentDB.gear(kinds[0])
	MetaState.equipped[worn.slot] = 0

	var trade: TradeSession = _open()
	# Straight onto the session, behind the screen's back.
	_offer(trade, TradeSession.HOST, [MetaState.stash[1]])
	TradeBooth.set("_session", trade)
	TradeBooth.set("_side", TradeSession.HOST)
	var screen: CanvasLayer = _window()
	screen.call("_on_trade_changed")
	await get_tree().process_frame

	var labels: Dictionary = {}
	for button: Button in _buttons(screen.get("_stash")):
		labels[button.text] = int(labels.get(button.text, 0)) + 1
	_checked += 1
	_check(int(labels.get("Take back", 0)) == 1,
		("a piece already on the table did not offer to be taken back; the "
			+ "window is keeping its own copy of the offer (%s)") % [labels])
	_checked += 1
	_check(int(labels.get("Offer", 0)) == MetaState.stash.size() - 2,
		"the rows that can be offered do not each have an Offer button (%s)" % [labels])
	_checked += 1
	_check(int(labels.get("Equipped", 0)) == 1,
		"worn gear is missing its disabled row, so it looks tradeable (%s)" % [labels])
	_checked += 1
	_check(not labels.has("Worn"),
		("the equipped row says 'Worn', which is also the name of the lowest "
			+ "rarity - beside a Worn Ashfall Glaive it says nothing"))
	screen.queue_free()
	TradeBooth.set("_session", null)
	_finished += 1
	await get_tree().process_frame


## The screen a player waits on has to say what they are waiting for.
##
## The confirmation screen is where somebody sits after pressing Confirm, and it
## shipped without any word about the other player at all - so waiting and the
## window having hung looked identical. The stash is deliberately gone from this
## screen, and that is asserted here too: a list you can click is an invitation
## to change the deal, on the one screen whose whole purpose is to read it.
func _test_the_confirmation_screen_says_where_the_partner_is() -> void:
	var kinds: Array[String] = _gear_kinds(2)
	MetaState.stash = []
	for id: String in kinds:
		MetaState.stash.append(Stash.make(id, 1))
	MetaState.equipped = {}
	var trade: TradeSession = _open()
	_offer(trade, TradeSession.HOST, [MetaState.stash[0]])
	trade.set_accepted(TradeSession.HOST, true)
	trade.set_accepted(TradeSession.GUEST, true)
	TradeBooth.set("_session", trade)
	TradeBooth.set("_side", TradeSession.HOST)
	var screen: CanvasLayer = _window()
	screen.call("_on_trade_changed")
	await get_tree().process_frame

	_checked += 1
	_check(trade.stage == TradeSession.Stage.CONFIRMING,
		"two acceptances did not reach the confirmation screen")
	var said: PackedStringArray = _words(screen.get("_actions"))
	_checked += 1
	_check(_says_containing(said, "confirmed"),
		("the confirmation screen never says whether the other player has "
			+ "confirmed, so waiting looks like the window having hung (%s)")
			% [said])
	_checked += 1
	_check(_buttons(screen.get("_stash")).is_empty(),
		"the stash is still clickable on the screen whose job is to be read")
	screen.queue_free()
	TradeBooth.set("_session", null)
	_finished += 1
	await get_tree().process_frame


# --- Helpers ------------------------------------------------------------------

## Runs one machine's half of a swap through the real code, on a given stash.
func _apply_half(stash: Array, given: Array, received: Array) -> Array:
	MetaState.stash = stash.duplicate(true)
	MetaState.equipped = {}
	TradeBooth.call("_apply_locally", given, received)
	return MetaState.stash.duplicate(true)


func _holds(stash: Array, kind: String, rarity: int) -> bool:
	for entry: Variant in stash:
		var piece := entry as Dictionary
		if String(piece.get("kind", "")) == kind and int(piece.get("rarity", -1)) == rarity:
			return true
	return false


func _open() -> TradeSession:
	var trade := TradeSession.new()
	trade.invite(TradeSession.HOST)
	trade.accept_invite(TradeSession.GUEST)
	return trade


func _offer(trade: TradeSession, side: String, pieces: Array) -> void:
	trade.set_offer(side, pieces, Balance.TRADE_MAX_PIECES)


## A named piece that does not have to be real gear: the rules do not look at
## what a piece *is*, only at its name. `_well_formed` is what looks at the rest,
## and it is exercised where real gear is required.
func _piece(kind: String) -> Dictionary:
	return {"kind": kind, "rarity": 0, "level": 1, "uid": Stash.new_uid()}


## A real trade window, built the way the booth builds it.
func _window() -> CanvasLayer:
	var screen := (load("res://scenes/ui/trade_screen.gd") as GDScript).new() as CanvasLayer
	add_child(screen)
	return screen


## Every word the window is currently showing.
func _words(from: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if from == null:
		return out
	for node: Node in _walk(from):
		var label := node as Label
		if label != null and not label.text.strip_edges().is_empty():
			out.append(label.text)
	return out


func _says_starting_with(said: PackedStringArray, prefix: String) -> bool:
	for line: String in said:
		if line.begins_with(prefix):
			return true
	return false


func _says_containing(said: PackedStringArray, needle: String) -> bool:
	for line: String in said:
		if line.contains(needle):
			return true
	return false


func _buttons(from: Node) -> Array[Button]:
	var out: Array[Button] = []
	if from == null:
		return out
	for node: Node in _walk(from):
		var button := node as Button
		if button != null:
			out.append(button)
	return out


func _walk(from: Node) -> Array[Node]:
	var out: Array[Node] = [from]
	for child: Node in from.get_children():
		out.append_array(_walk(child))
	return out


## Distinct gear kinds, one per slot, so a drawn list has rows worth comparing.
func _gear_kinds(wanted: int) -> Array[String]:
	var out: Array[String] = []
	var slots: Dictionary = {}
	for value: Variant in ContentDB.gear_kinds.values():
		var kind := value as GearData
		if kind == null or slots.has(kind.slot):
			continue
		slots[kind.slot] = true
		out.append(kind.id)
		if out.size() >= wanted:
			break
	return out


func _any_gear_kind() -> String:
	for value: Variant in ContentDB.gear_kinds.values():
		var kind := value as GearData
		if kind != null:
			return kind.id
	return ""


func _check(condition: bool, why: String) -> bool:
	if condition:
		return true
	_failures += 1
	push_error("[trade] %s" % why)
	return false


func _finish() -> void:
	# The player's own gear, put back exactly as it was found. This gate rewrites
	# `MetaState.stash` several times, and a gate that eats a stash is precisely
	# the failure it was written to prevent.
	print("[probe] at finish ", MetaState.stash.size(), " restoring to ", _stash_before.size())
	MetaState.stash = _stash_before
	MetaState.equipped = _equipped_before
	MetaState.resume_saves()
	if _failures == 0:
		print("[trade] PASS - %d checks; offers cannot be swapped late and gear is never made twice"
			% _checked)
	else:
		push_error("[trade] FAIL - %d of %d" % [_failures, _checked])
	get_tree().quit(1 if _failures > 0 else 0)
