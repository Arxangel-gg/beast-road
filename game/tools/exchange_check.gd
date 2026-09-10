extends Node

## The Long Ledger: gear is never created, and Marks are never printed.
##
## Owner brief, 2026-09-10: a grand exchange "for players to be able to create a
## trading economy for all of the loot in the game".
##
## This gate is long for the same reason `trade_check` is: **every failure here
## is silent, permanent and economic.** Gear is account-level; Marks are the only
## account currency that buys anything. A marketplace that duplicates a piece,
## eats one, or lets Marks be laundered out of a price gap does not error, does
## not fail a build, and ruins the between-run layer over weeks rather than in an
## instant.
##
## Four families, in the order they matter.
##
## **The spread**, driven on `ExchangeMarket` over every rarity and level in the
## game. If the cheapest possible purchase is ever at or under what the stash
## pays for the same piece, buy-low-vendor-high prints Marks forever. This is
## the one that is a *constant away* from being true, so it is checked against
## the constants rather than against a comment.
##
## **Conservation**, driven through the real autoload against a real stash. A
## piece is listed, the board is saved and read back, orders are cancelled and
## collected, and the pieces are counted at every step. This is the family that
## would catch a duplication the others missed.
##
## **The road**, because an order that never fills is a piece destroyed and an
## order that always fills instantly is a shop. Fill times are measured in units
## of actual journey.
##
## **The feed**, which is the one thing a stranger can write. Its influence is
## bounded, and the bound is asserted against deliberately hostile rows.

var _failures: int = 0
var _checked: int = 0

## How many of the counted tests reached their end. A script error aborts one
## function and nothing else; `crossroad_vote_check` went green on a subject
## that would not compile before this counter existed.
var _finished: int = 0
const EXPECTED_TESTS: int = 11

var _stash_before: Array = []
var _equipped_before: Dictionary = {}
var _marks_before: int = 0
var _orders_before: Array = []


func _ready() -> void:
	# Held before anything is touched. This gate rewrites the stash, the Marks
	# and the ledger, and putting them back at the end is not the same as never
	# having written them.
	MetaState.hold_saves()
	await get_tree().process_frame
	_stash_before = MetaState.stash.duplicate(true)
	_equipped_before = MetaState.equipped.duplicate(true)
	_marks_before = MetaState.marks
	_orders_before = MetaState.exchange_orders.duplicate(true)

	_test_buying_is_always_dearer_than_vendoring()
	_test_a_price_outside_the_band_never_fills()
	_test_the_guide_sits_between_the_two_bounds()
	await _test_listing_moves_a_piece_rather_than_copying_it()
	await _test_cancelling_gives_back_exactly_what_was_escrowed()
	await _test_a_full_stash_never_eats_a_delivery()
	await _test_a_sale_pays_once()
	await _test_the_board_survives_the_save()
	_test_the_road_is_the_clock()
	_test_the_top_rarities_stay_scarce()
	_test_a_hostile_feed_moves_a_price_and_never_an_item()

	if _finished != EXPECTED_TESTS:
		_check(false, "only %d of %d tests ran to completion" % [_finished, EXPECTED_TESTS])
	_finish()


# --- The spread ---------------------------------------------------------------

## **The bound the whole economy rests on.**
##
## The stash sells a piece for `Stash.sell_price`. If the Ledger could ever be
## bought from at or below that, the loop is buy, vendor, repeat - unbounded
## Marks, and Marks buy upgrades. Checked over every rarity and level rather
## than at one point, because the two prices are different curves and a crossing
## in the middle is exactly what a spot check misses.
func _test_buying_is_always_dearer_than_vendoring() -> void:
	var worst: float = 1000.0
	var worst_at: String = ""
	for kind_id: String in _gear_kinds(0):
		for rarity: int in Stash.RARITY_NAMES.size():
			for level: int in range(1, Stash.MAX_LEVEL + 1):
				var piece: Dictionary = Stash.make(kind_id, rarity, level)
				var vendor: int = Stash.sell_price(piece)
				# At both ends of what the feed may ever do to a price.
				for demand: float in [Balance.EXCHANGE_DEMAND_FLOOR, 1.0,
						Balance.EXCHANGE_DEMAND_CEILING]:
					var cheapest: int = ExchangeMarket.min_bid(piece, demand)
					var margin: float = float(cheapest) / maxf(float(vendor), 1.0)
					if margin < worst:
						worst = margin
						worst_at = "%s r%d L%d at demand %.2f: buy %d, vendor %d" % [
							kind_id, rarity, level, demand, cheapest, vendor]
	_checked += 1
	_check(worst > 1.0,
		("the cheapest possible purchase is not dearer than vendoring, so buying "
			+ "to sell back prints Marks (%s)") % worst_at)
	_finished += 1


## A price outside the band is refused by never filling, not by an error.
func _test_a_price_outside_the_band_never_fills() -> void:
	var piece: Dictionary = Stash.make(_gear_kinds(1)[0], 2, 1)
	var guide: int = ExchangeMarket.guide_price(piece)
	var ceiling: int = ExchangeMarket.max_ask(piece)
	var floor_price: int = ExchangeMarket.min_bid(piece)

	_checked += 1
	_check(ExchangeMarket.fill_rate(ExchangeMarket.Side.SELL, ceiling + 1, guide,
			ceiling, floor_price) == 0.0,
		"an ask above the ceiling still found a caravan")
	_checked += 1
	_check(ExchangeMarket.fill_rate(ExchangeMarket.Side.BUY, floor_price - 1, guide,
			ceiling, floor_price) == 0.0,
		"a bid under the floor still found a caravan, which is the laundering gap")
	_checked += 1
	_check(ExchangeMarket.fill_rate(ExchangeMarket.Side.SELL, guide, guide,
			ceiling, floor_price) > 0.0,
		"an ask at exactly the guide never fills, so the guide means nothing")
	# The screen names both edges of the band as prices that work. Both have to.
	_checked += 1
	_check(ExchangeMarket.fill_rate(ExchangeMarket.Side.SELL, ceiling, guide,
			ceiling, floor_price) > 0.0,
		"an ask at exactly the ceiling never fills, and the screen says it does")
	_checked += 1
	_check(ExchangeMarket.fill_rate(ExchangeMarket.Side.BUY, floor_price, guide,
			ceiling, floor_price) > 0.0,
		"a bid at exactly the floor never fills, and the screen says it does")
	_finished += 1


## Cheaper sells faster and dearer buys faster, monotonically.
##
## The screen teaches "ask less, sell sooner". If the curve is not monotone the
## screen is teaching something untrue, and a player optimising against it is
## being punished for paying attention.
func _test_the_guide_sits_between_the_two_bounds() -> void:
	var piece: Dictionary = Stash.make(_gear_kinds(1)[0], 3, 2)
	var guide: int = ExchangeMarket.guide_price(piece)
	var ceiling: int = ExchangeMarket.max_ask(piece)
	var floor_price: int = ExchangeMarket.min_bid(piece)
	_checked += 1
	_check(floor_price < guide and guide < ceiling,
		"the guide is not between the floor and the ceiling (%d < %d < %d)"
			% [floor_price, guide, ceiling])

	var last: float = 1000.0
	var monotone: bool = true
	for ask: int in range(maxi(floor_price, 1), ceiling + 1, maxi((ceiling - floor_price) / 12, 1)):
		var rate: float = ExchangeMarket.fill_rate(ExchangeMarket.Side.SELL, ask,
			guide, ceiling, floor_price)
		if rate > last + 0.000001:
			monotone = false
		last = rate
	_checked += 1
	_check(monotone, "asking more sold faster somewhere on the curve")
	_finished += 1


# --- Conservation -------------------------------------------------------------

## A listed piece is in exactly one place, and that place is the order.
func _test_listing_moves_a_piece_rather_than_copying_it() -> void:
	_reset_board()
	var kind: String = _gear_kinds(1)[0]
	MetaState.stash = [Stash.make(kind, 2, 1), Stash.make(kind, 0, 1)]
	MetaState.equipped = {}
	var listed_uid: int = Stash.uid(MetaState.stash[0] as Dictionary)

	_checked += 1
	_check(Exchange.post_sale(0, Exchange.guide_price(MetaState.stash[0])).is_empty(),
		"a plain listing was refused")
	_checked += 1
	_check(MetaState.stash.size() == 1, "the listed piece is still in the stash too")
	_checked += 1
	_check(Stash.index_of(MetaState.stash, listed_uid) < 0,
		"the listed piece is in the stash *and* the ledger, which is gear made twice")
	_checked += 1
	_check(Exchange.orders().size() == 1 and Stash.uid(Exchange.orders()[0].piece)
			== listed_uid,
		"the ledger is not holding the piece that left the stash")

	# Worn gear cannot be listed: it would be worn and gone at once.
	MetaState.equipped = {int((ContentDB.gear(kind) as GearData).slot): 0}
	_checked += 1
	_check(not Exchange.post_sale(0, 100).is_empty(),
		"worn gear was listed, so the hero is wearing something a caravan has")
	_reset_board()
	_finished += 1
	await get_tree().process_frame


## Cancelling is total: everything escrowed comes back, and only once.
func _test_cancelling_gives_back_exactly_what_was_escrowed() -> void:
	_reset_board()
	var kind: String = _gear_kinds(1)[0]
	MetaState.stash = [Stash.make(kind, 3, 1)]
	MetaState.equipped = {}
	MetaState.marks = 5000
	var uid: int = Stash.uid(MetaState.stash[0] as Dictionary)
	Exchange.post_sale(0, 400)
	_checked += 1
	_check(Exchange.cancel(0).is_empty(), "a plain cancel was refused")
	_checked += 1
	_check(MetaState.stash.size() == 1 and Stash.index_of(MetaState.stash, uid) >= 0,
		"cancelling a listing did not give the piece back")
	_checked += 1
	_check(Exchange.orders().is_empty(), "the cancelled line is still on the board")

	# And a buy: the Marks come back, all of them, once.
	var wanted: Dictionary = Stash.make(kind, 1, 1)
	var bid: int = Exchange.guide_price(wanted)
	var before: int = MetaState.marks
	_checked += 1
	_check(Exchange.post_purchase(kind, 1, 1, bid).is_empty(), "a plain bid was refused")
	_checked += 1
	_check(MetaState.marks == before - bid,
		"a bid did not take the Marks up front, so it could be posted twice over")
	Exchange.cancel(0)
	_checked += 1
	_check(MetaState.marks == before, "cancelling a bid did not refund exactly the bid")
	_checked += 1
	_check(Exchange.cancel(0) != "", "the same line was cancelled twice")
	_reset_board()
	_finished += 1
	await get_tree().process_frame


## A full stash is a real answer, and it never costs the player the delivery.
##
## The failure this prevents is the worst one available: a bought piece arrives,
## there is no room, and it is dropped on the floor. The order stays met and
## collectable instead, which is why `collect` asks `take_gear` before it
## believes anything.
func _test_a_full_stash_never_eats_a_delivery() -> void:
	_reset_board()
	var kind: String = _gear_kinds(1)[0]
	MetaState.marks = 100000
	MetaState.stash = []
	MetaState.equipped = {}
	Exchange.post_purchase(kind, 0, 1, Exchange.guide_price(Stash.make(kind, 0, 1)) * 2)
	Exchange.advance_road(Balance.JOURNEY_TOTAL_DISTANCE * 4.0)
	_checked += 1
	if not _check(Exchange.orders().size() == 1
			and Exchange.orders()[0].stage == ExchangeOrder.Stage.FILLED,
			"a bid well over the guide never filled across four journeys"):
		_reset_board()
		_finished += 1
		return

	# Fill the stash to the brim, then try to collect.
	MetaState.stash = []
	for _slot: int in Balance.STASH_CAPACITY:
		MetaState.stash.append(Stash.make(kind, 0, 1))
	_checked += 1
	_check(not Exchange.collect(0).is_empty(),
		"a delivery into a full stash was reported as collected")
	_checked += 1
	_check(Exchange.orders().size() == 1
			and Exchange.orders()[0].stage == ExchangeOrder.Stage.FILLED,
		"the delivery was lost rather than left waiting for room")

	MetaState.stash.remove_at(0)
	_checked += 1
	_check(Exchange.collect(0).is_empty(), "the delivery could not be collected with room")
	_checked += 1
	_check(MetaState.stash.size() == Balance.STASH_CAPACITY,
		"collecting the delivery did not add exactly one piece")
	_reset_board()
	_finished += 1
	await get_tree().process_frame


## A met sale pays its Marks once, and the piece does not come back with them.
func _test_a_sale_pays_once() -> void:
	_reset_board()
	var kind: String = _gear_kinds(1)[0]
	MetaState.stash = [Stash.make(kind, 1, 1)]
	MetaState.equipped = {}
	MetaState.marks = 0
	var ask: int = 1
	Exchange.post_sale(0, ask)
	Exchange.advance_road(Balance.JOURNEY_TOTAL_DISTANCE * 4.0)
	_checked += 1
	if not _check(Exchange.orders().size() == 1
			and Exchange.orders()[0].stage == ExchangeOrder.Stage.FILLED,
			"a one-Mark ask never sold across four journeys"):
		_reset_board()
		_finished += 1
		return
	_checked += 1
	_check(Exchange.collect(0).is_empty(), "a met sale could not be collected")
	_checked += 1
	_check(MetaState.marks == ask, "a met sale paid %d rather than %d"
		% [MetaState.marks, ask])
	_checked += 1
	_check(MetaState.stash.is_empty(),
		"the sold piece came back as well as the money, which is gear made twice")
	_checked += 1
	_check(Exchange.orders().is_empty(), "the collected line is still on the board")
	_reset_board()
	_finished += 1
	await get_tree().process_frame


## The board survives being written and read, and nothing multiplies on the way.
##
## A listed piece lives only in the save's ledger block. If that block were ever
## dropped or doubled on load, the player would lose or gain gear by quitting -
## and quitting is not a thing anybody thinks of as risky.
func _test_the_board_survives_the_save() -> void:
	_reset_board()
	var kind: String = _gear_kinds(1)[0]
	MetaState.stash = [Stash.make(kind, 4, 3)]
	MetaState.equipped = {}
	MetaState.marks = 9000
	var uid: int = Stash.uid(MetaState.stash[0] as Dictionary)
	Exchange.post_sale(0, 900)
	Exchange.post_purchase(kind, 2, 1, Exchange.guide_price(Stash.make(kind, 2, 1)))

	var text: String = MetaState.serialized_save()
	var parsed: Variant = JSON.parse_string(text)
	_checked += 1
	if not _check(parsed is Dictionary, "the save is not a JSON object"):
		_reset_board()
		_finished += 1
		return
	var written: Array = (((parsed as Dictionary).get("stash", {}) as Dictionary)
		.get("orders", []) as Array)
	_checked += 1
	_check(written.size() == 2, "the ledger wrote %d of its 2 lines" % written.size())

	# Read it back the way a launch does.
	MetaState.call("_read_stash", (parsed as Dictionary).get("stash", {}) as Dictionary)
	Exchange.call("_adopt_save")
	_checked += 1
	_check(Exchange.orders().size() == 2,
		"the ledger came back holding %d lines" % Exchange.orders().size())
	_checked += 1
	_check(Stash.index_of(MetaState.stash, uid) < 0,
		"the escrowed piece came back into the stash as well, which is gear made twice")
	var found: bool = false
	for order: ExchangeOrder in Exchange.orders():
		if Stash.uid(order.piece) == uid:
			found = true
	_checked += 1
	_check(found, "the escrowed piece did not survive the save at all")
	_reset_board()
	_finished += 1
	await get_tree().process_frame


# --- The road -----------------------------------------------------------------

## Orders fill on road travelled, in a time a player would call reasonable.
##
## Both ends are the claim. Too slow and a listing is a piece deleted; too fast
## and the Ledger is a vending machine and the road stops being where gear comes
## from.
func _test_the_road_is_the_clock() -> void:
	var piece: Dictionary = Stash.make(_gear_kinds(1)[0], 1, 1)
	var guide: int = ExchangeMarket.guide_price(piece)
	var at_guide: float = ExchangeMarket.fill_rate(ExchangeMarket.Side.SELL, guide,
		guide, ExchangeMarket.max_ask(piece), ExchangeMarket.min_bid(piece))
	var journeys: float = (1.0 / maxf(at_guide, 0.000001)) / Balance.JOURNEY_TOTAL_DISTANCE
	_checked += 1
	_check(journeys > 0.05 and journeys < 1.0,
		("an order at the guide takes %.2f full journeys to fill; under a "
			+ "twentieth is a vending machine and over one is a piece deleted")
			% journeys)

	var best: float = ExchangeMarket.fill_rate(ExchangeMarket.Side.SELL, 1, guide,
		ExchangeMarket.max_ask(piece), ExchangeMarket.min_bid(piece))
	_checked += 1
	_check(best > at_guide, "undercutting the guide did not sell any faster")
	_checked += 1
	_check(best / at_guide <= Balance.EXCHANGE_FILL_BEST_MULTIPLIER + 0.001,
		"undercutting is worth more than the authored ceiling, so price stops mattering")
	_finished += 1


## The Ledger cannot replace the road as the place good gear comes from.
##
## Owner decision, 2026-09-01: gear is the reason to replay. Supply has to fall
## away at the top or a player farms Marks and buys the rest, and the whole
## between-run layer becomes a shop.
func _test_the_top_rarities_stay_scarce() -> void:
	var last: float = 2.0
	var ordered: bool = true
	for rarity: int in Stash.RARITY_NAMES.size():
		var supply: float = ExchangeMarket.baseline_supply(rarity)
		if supply > last:
			ordered = false
		last = supply
	_checked += 1
	_check(ordered, "a rarer piece is not scarcer on the road than a commoner one")
	_checked += 1
	_check(ExchangeMarket.baseline_supply(Stash.RARITY_NAMES.size() - 1) <= 0.1,
		"the top rarity is buyable often enough that finding one stops mattering")
	_checked += 1
	_check(ExchangeMarket.baseline_supply(0) >= 0.5,
		"even the commonest gear is hard to buy, so the Ledger is decoration")
	_finished += 1


# --- The feed -----------------------------------------------------------------

## The one thing a stranger can write moves a number and never an item.
##
## The price feed is written with the anonymous key every copy of the game
## carries, so it must be assumed hostile. Rows are hammered with nonsense and
## with a coordinated ramp, and the influence stays inside the authored band.
func _test_a_hostile_feed_moves_a_price_and_never_an_item() -> void:
	var junk: Array = [null, 4, "rows", {"rarity": "x"}, {"price": 1},
		{"rarity": 99, "price": -5, "vendor": 0}]
	_checked += 1
	_check(is_equal_approx(ExchangeMarket.demand_from(junk, 2), 1.0),
		"malformed feed rows moved a price")

	# A coordinated ramp: a hundred rows all claiming enormous sales.
	var ramp: Array = []
	for _row: int in 100:
		ramp.append({"rarity": 2, "price": 1000000, "vendor": 1})
	var demand: float = ExchangeMarket.demand_from(ramp, 2)
	_checked += 1
	_check(demand <= Balance.EXCHANGE_DEMAND_CEILING + 0.001,
		"a forged ramp took demand to %.2f, past the authored ceiling" % demand)

	var dump: Array = []
	for _row: int in 100:
		dump.append({"rarity": 2, "price": 0, "vendor": 1000000})
	var crushed: float = ExchangeMarket.demand_from(dump, 2)
	_checked += 1
	_check(crushed >= Balance.EXCHANGE_DEMAND_FLOOR - 0.001,
		"a forged dump took demand to %.2f, under the authored floor" % crushed)

	# And the bound that matters: no reachable demand makes buying cheap enough
	# to launder. This is the spread test again, under attack rather than at
	# authored values.
	var piece: Dictionary = Stash.make(_gear_kinds(1)[0], 2, 1)
	_checked += 1
	_check(ExchangeMarket.min_bid(piece, crushed) > Stash.sell_price(piece),
		"a forged feed opened the buy-low-vendor-high gap")
	_finished += 1


# --- Helpers ------------------------------------------------------------------

func _reset_board() -> void:
	Exchange.set("_orders", [] as Array[ExchangeOrder])
	Exchange.set("_feed", [])
	MetaState.exchange_orders = []


func _gear_kinds(wanted: int) -> Array[String]:
	var out: Array[String] = []
	var slots: Dictionary = {}
	for value: Variant in ContentDB.gear_kinds.values():
		var kind := value as GearData
		if kind == null or slots.has(kind.slot):
			continue
		slots[kind.slot] = true
		out.append(kind.id)
		if wanted > 0 and out.size() >= wanted:
			break
	return out


func _check(condition: bool, why: String) -> bool:
	if condition:
		return true
	_failures += 1
	push_error("[exchange] %s" % why)
	return false


func _finish() -> void:
	# The player's own account, put back exactly as it was found.
	MetaState.stash = _stash_before
	MetaState.equipped = _equipped_before
	MetaState.marks = _marks_before
	MetaState.exchange_orders = _orders_before
	Exchange.call("_adopt_save")
	MetaState.resume_saves()
	if _failures == 0:
		print("[exchange] PASS - %d checks; the ledger never makes gear and never prints Marks"
			% _checked)
	else:
		push_error("[exchange] FAIL - %d of %d" % [_failures, _checked])
	get_tree().quit(1 if _failures > 0 else 0)
