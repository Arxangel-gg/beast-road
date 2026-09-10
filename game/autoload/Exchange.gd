extends Node

## The Long Ledger: post a price, ride the road, come back to it settled.
##
## Owner brief, 2026-09-10: "a runescape grand exchange / diablo auction house
## type of marketplace in game for players to be able to create a trading
## economy for all of the loot in the game".
##
## `ExchangeMarket` holds what things are worth, `ExchangeOrder` holds what one
## line of the ledger may do, and this owns the player's six lines: the escrow,
## the road that advances them, the save, and the price feed.
##
## ## Why it is a ledger and not a shop
##
## The world already has merchants who arrive, sell, and one day settle in town.
## They are people you meet. The Ledger is the opposite kind of thing: a book of
## standing orders that clerks carry between caravans, so a Warden four roads
## away can take your sword without either of you ever being in the same place.
## That is what makes it an *exchange* rather than a fourth shop, and it is why
## the two exist beside each other rather than one replacing the other.
##
## It also explains the mechanic that matters most: **orders fill as the beast
## walks.** Word travels with the caravans, so distance is the clock. Standing
## still in town settles nothing, and a long run settles a lot. The Ledger pays
## you for playing.
##
## ## The bounds, and where each one is actually enforced
##
## - **Gear is never created.** A listed piece is *in the order*, not in the
##   stash - `ExchangeOrder` documents why a flag would not do. Every path in or
##   out of escrow here is a move, never a copy.
## - **Marks are escrowed too.** A buy takes the money up front, so a bid cannot
##   be posted against Marks that were spent somewhere else first.
## - **A full stash never eats a delivery.** Collecting a purchase asks
##   `MetaState.take_gear` first and keeps the order open if there is no room.
## - **Prices are shared, custody is not.** The feed carries what pieces went
##   for and nothing else; see `ExchangeMarket`.

## The board changed: an order posted, advanced, filled, cancelled or collected.
signal changed()

## An order was met. `side` is an `ExchangeMarket.Side`.
signal order_filled(side: int, piece: Dictionary, marks: int)

const TABLE: String = "exchange_sales"

var _orders: Array[ExchangeOrder] = []

## Recent community sales, as `{"rarity": int, "price": int, "vendor": int}`.
##
## Read once per launch and never depended upon: everything that consults it has
## a defined answer for an empty feed, because most sessions will be offline,
## on a plane, or first.
var _feed: Array = []

## Distance already accounted for, so a resumed run does not pay twice.
var _distance_seen: float = 0.0

var _net: Supabase = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_net = Supabase.new()
	add_child(_net)
	MetaState.save_loaded.connect(_adopt_save)
	_adopt_save()
	# The road is the clock. `RunState` owns the distance and emits when it
	# moves, so nothing here has to poll or keep its own copy - working rule 6.
	EventBus.distance_changed.connect(
		func(total: float, _to_crossroad: float) -> void: _on_distance_changed(total))
	EventBus.run_started.connect(func() -> void: _distance_seen = 0.0)
	refresh_prices()


# --- Reading the board --------------------------------------------------------

func orders() -> Array[ExchangeOrder]:
	return _orders


func slots_used() -> int:
	return _orders.size()


func has_room() -> bool:
	return _orders.size() < Balance.EXCHANGE_SLOTS


## What the Ledger reckons a piece is worth right now.
func guide_price(piece: Dictionary) -> int:
	return ExchangeMarket.guide_price(piece, demand_for(piece))


func min_bid(piece: Dictionary) -> int:
	return ExchangeMarket.min_bid(piece, demand_for(piece))


func max_ask(piece: Dictionary) -> int:
	return ExchangeMarket.max_ask(piece, demand_for(piece))


func demand_for(piece: Dictionary) -> float:
	return ExchangeMarket.demand_from(_feed, int(piece.get("rarity", 0)))


func supply_for(piece: Dictionary) -> float:
	return ExchangeMarket.supply_from(_feed, int(piece.get("rarity", 0)))


## Whether the price feed has enough rows to be saying anything of its own.
##
## The screen says so out loud. A guide price that is really just the authored
## markup should not be dressed up as a market reading - a player deciding what
## to ask deserves to know which of the two they are looking at.
func prices_are_live() -> bool:
	return _feed.size() >= Balance.EXCHANGE_DEMAND_MIN_SAMPLES


# --- Posting ------------------------------------------------------------------

## Lists a stash piece at a price. Returns "" or the reason it was refused.
##
## The piece is taken out of the stash *before* the order exists and put back if
## anything below fails, so there is no window in which it is in both places.
func post_sale(stash_index: int, asking: int) -> String:
	if not has_room():
		return "The ledger holds %d lines. Collect or cancel one first." \
			% Balance.EXCHANGE_SLOTS
	if stash_index < 0 or stash_index >= MetaState.stash.size():
		return "That piece is no longer in your stash."
	if _is_equipped(stash_index):
		return "Worn gear cannot be listed. Take it off first."
	if TradeBooth.is_trading():
		return "Finish the trade you are in before listing anything."
	var piece: Dictionary = MetaState.stash[stash_index]
	if asking < 1:
		return "Name a price of at least one Mark."
	var taken: Dictionary = MetaState.drop_gear(stash_index)
	if taken.is_empty():
		return "That piece is no longer in your stash."
	_orders.append(ExchangeOrder.sell(taken, asking))
	_persist()
	return ""


## Puts in a standing offer for a kind of gear. Returns "" or the refusal.
func post_purchase(kind_id: String, rarity: int, level: int, bidding: int) -> String:
	if not has_room():
		return "The ledger holds %d lines. Collect or cancel one first." \
			% Balance.EXCHANGE_SLOTS
	if ContentDB.gear(kind_id) == null:
		return "Nobody on this road has heard of that."
	var wanted: Dictionary = Stash.make(kind_id, rarity, level)
	var floor_price: int = min_bid(wanted)
	if bidding < floor_price:
		return "No caravan would carry that for less than %d Marks." % floor_price
	if MetaState.marks < bidding:
		return "You have %d Marks and that offer needs %d." % [MetaState.marks, bidding]
	MetaState.marks -= bidding
	_orders.append(ExchangeOrder.buy(wanted, bidding))
	_persist()
	return ""


## Takes a line off the board and gives back whatever it was holding.
func cancel(index: int) -> String:
	if index < 0 or index >= _orders.size():
		return "That line is no longer on the board."
	var order: ExchangeOrder = _orders[index]
	var back: Dictionary = order.cancel()
	if back.is_empty():
		return "That line has already been met."
	# Marks first: they cannot fail to land, so doing them first means a full
	# stash leaves the order sitting as CANCELLED with the piece still in it,
	# rather than half-refunded.
	MetaState.marks += int(back.get("marks", 0))
	var piece: Dictionary = back.get("piece", {}) as Dictionary
	if piece.is_empty():
		_orders.remove_at(index)
		_persist()
		return ""
	if not MetaState.take_gear(piece):
		# Put it back where it was. `cancel` already emptied the order, so this
		# is the one place that has to hand the piece back to it.
		order.piece = piece
		order.stage = ExchangeOrder.Stage.OPEN
		MetaState.marks -= int(back.get("marks", 0))
		return "Your stash is full. Make room before taking that back."
	_orders.remove_at(index)
	_persist()
	return ""


## Collects what a met line owes. Returns "" or the refusal.
func collect(index: int) -> String:
	if index < 0 or index >= _orders.size():
		return "That line is no longer on the board."
	var order: ExchangeOrder = _orders[index]
	if order.stage != ExchangeOrder.Stage.FILLED:
		return "That line has not been met yet."
	var incoming: Dictionary = order.payout_piece
	var landed: bool = true
	if not incoming.is_empty():
		landed = MetaState.take_gear(incoming.duplicate(true))
		if not landed:
			return "Your stash is full. Make room and collect again."
	var paid: Dictionary = order.collect(landed)
	if paid.is_empty():
		return "That line has not been met yet."
	MetaState.marks += int(paid.get("marks", 0))
	_orders.remove_at(index)
	_persist()
	return ""


# --- The road -----------------------------------------------------------------

## Every unit of road gives every open line a chance to be met.
##
## Guest machines do not run this. In co-op the guest's own `RunState.distance`
## is relayed from the host, so it would advance identically - but the Ledger is
## account-level and it is the *player's* road that settles their orders, which
## for a guest is the same road. Both players' ledgers advancing on the shared
## distance is correct and is what happens.
func _on_distance_changed(total: float) -> void:
	var step: float = total - _distance_seen
	if step <= 0.0:
		# A new run resets the odometer; never pay out a negative road.
		_distance_seen = total
		return
	_distance_seen = total
	advance_road(step)


## The tickable half, separated so a gate can drive a journey in one call.
func advance_road(distance: float) -> void:
	if distance <= 0.0 or _orders.is_empty():
		return
	var moved: bool = false
	for order: ExchangeOrder in _orders:
		if not order.is_open():
			continue
		# Priced from the description rather than the escrow, because a buy
		# order has no piece in it at all - only the Marks and what it is for.
		var about: Dictionary = order.about
		var demand: float = demand_for(about)
		var guide: int = ExchangeMarket.guide_price(about, demand)
		var rate: float = ExchangeMarket.fill_rate(int(order.side), order.price, guide,
			ExchangeMarket.max_ask(about, demand),
			ExchangeMarket.min_bid(about, demand))
		var supply: float = ExchangeMarket.supply_from(_feed,
			int(about.get("rarity", 0)))
		var was_selling: bool = order.side == ExchangeMarket.Side.SELL
		var sold: Dictionary = about.duplicate(true)
		if not order.advance(distance, rate, supply):
			continue
		moved = true
		order_filled.emit(int(order.side), sold, order.price)
		if was_selling:
			# Only completed sales are published, and only as a ratio. What
			# travels is "an Oathbound went for 1.4x vendor", never who, never
			# what, never a piece.
			_publish_sale(sold, order.price)
	if moved:
		_persist()


# --- The save -----------------------------------------------------------------

func _adopt_save() -> void:
	_orders = []
	for entry: Variant in MetaState.exchange_orders:
		if not (entry is Dictionary):
			continue
		var order: ExchangeOrder = ExchangeOrder.from_record(entry as Dictionary)
		if order == null:
			continue
		_orders.append(order)
		if _orders.size() >= Balance.EXCHANGE_SLOTS:
			break
	changed.emit()


func _persist() -> void:
	var records: Array = []
	for order: ExchangeOrder in _orders:
		records.append(order.to_record())
	MetaState.exchange_orders = records
	MetaState.save_game()
	changed.emit()


func _is_equipped(index: int) -> bool:
	for slot: Variant in MetaState.equipped:
		if int(MetaState.equipped[slot]) == index:
			return true
	return false


# --- The price feed -----------------------------------------------------------

## Asks the road what things have been going for.
##
## Failure is silence. Every reader has a defined answer for an empty feed, and
## the Ledger works completely offline - the guide price falls back to the
## authored markup and supply to `EXCHANGE_BASELINE_SUPPLY`. A marketplace that
## stopped working when a server did would be worse than not having one.
func refresh_prices() -> void:
	if _net == null:
		return
	var query: String = "%s?select=rarity,price,vendor&order=at.desc&limit=%d" % [
		TABLE, Balance.EXCHANGE_FEED_ROWS]
	_net.request(query, HTTPClient.METHOD_GET, {}, _on_prices)


func _on_prices(ok: bool, body: Variant) -> void:
	if not ok or not (body is Array):
		return
	var rows: Array = []
	for entry: Variant in body as Array:
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		# Read defensively: these rows were written by strangers with the same
		# anonymous key this build carries. A malformed one is dropped, and a
		# well-formed lie can only nudge a bounded multiplier.
		if not row.has("rarity") or not row.has("price") or not row.has("vendor"):
			continue
		rows.append({
			"rarity": clampi(int(row["rarity"]), 0, Stash.RARITY_NAMES.size() - 1),
			"price": maxi(int(row["price"]), 0),
			"vendor": maxi(int(row["vendor"]), 1),
		})
	_feed = rows
	changed.emit()


func _publish_sale(piece: Dictionary, paid: int) -> void:
	if _net == null:
		return
	_net.request(TABLE, HTTPClient.METHOD_POST, {
		"rarity": int(piece.get("rarity", 0)),
		"price": maxi(paid, 0),
		"vendor": maxi(Stash.sell_price(piece), 1),
	}, func(_ok: bool, _body: Variant) -> void: pass)
