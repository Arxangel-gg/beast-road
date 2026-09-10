class_name ExchangeOrder
extends RefCounted

## One line in the Long Ledger: a piece and a price, waiting for a caravan.
##
## Pure, like `TradeSession` and for the same reason. What must never go wrong
## here is that a piece exists twice or not at all, and that is a property of
## *state transitions* rather than of a screen or a socket - so the transitions
## live somewhere `exchange_check` can drive ten thousand of them without a save
## file.
##
## ## Escrow, and why the gear is in here rather than in the stash
##
## A listed piece leaves the stash and is carried by the order. It is still the
## player's, and cancelling gives it straight back - but while it is listed it
## cannot be worn, broken, traded or sold, because it is not there to be.
##
## The alternative is a flag on a stash entry, and that fails the moment
## anything iterates the stash without knowing about the flag: a bulk break, a
## trade offer, a full-stash drop delivering into the slot. One list or the
## other, never a piece in both, is a rule that a reader cannot get wrong by
## forgetting something.

## What the order is waiting for.
enum Stage {
	## On the board. A caravan may still meet it.
	OPEN,
	## Met. The proceeds are sitting here until the player collects them.
	FILLED,
	## Taken off the board by the player. Whatever was escrowed comes back.
	CANCELLED,
	## Collected. Nothing is owed either way and the slot is free.
	CLOSED,
}

var side: ExchangeMarket.Side = ExchangeMarket.Side.SELL
var stage: Stage = Stage.OPEN

## The gear this order is about.
##
## For a sell it is the escrowed piece itself, uid and all. For a buy it is what
## the player asked for - kind, rarity and level - and the uid is assigned when
## a caravan actually delivers, because until then there is no piece.
var piece: Dictionary = {}

## Marks per piece, as the player wrote it.
var price: int = 0

## Marks taken from the player up front, for a buy. Escrow, exactly like the
## gear on a sell: a buy order that had not taken the money could be posted
## against Marks already spent elsewhere.
var escrowed_marks: int = 0

## How close a caravan is to meeting it, in [0, 1].
var progress: float = 0.0

## What the player has waiting: Marks from a sale, or gear from a purchase.
var payout_marks: int = 0
var payout_piece: Dictionary = {}

## What this line is *about*, for the board to draw. Never gear.
##
## **A description, not a piece.** It carries no uid, is never given to anybody,
## and nothing may ever put it in a stash - `Stash.uid` would mint one on the
## spot and the copy would become real. It exists because a met sale has handed
## its piece to a caravan and cleared it, and a board that then showed "Unknown"
## would be unable to say what the Marks waiting there were *for*.
var about: Dictionary = {}


## A sell: the piece is handed over now, the Marks arrive later.
static func sell(escrowed: Dictionary, asking: int) -> ExchangeOrder:
	var order := ExchangeOrder.new()
	order.side = ExchangeMarket.Side.SELL
	order.piece = escrowed.duplicate(true)
	order.about = _describe(order.piece)
	order.price = maxi(asking, 1)
	return order


## A buy: the Marks are handed over now, the piece arrives later.
static func buy(wanted: Dictionary, bidding: int) -> ExchangeOrder:
	var order := ExchangeOrder.new()
	order.side = ExchangeMarket.Side.BUY
	order.piece = wanted.duplicate(true)
	order.about = _describe(order.piece)
	order.piece.erase("uid")
	# A bought piece never arrives marked kept or worn - those are things the
	# owner did to it, and this one has had no owner.
	order.piece.erase("favourite")
	order.price = maxi(bidding, 1)
	order.escrowed_marks = order.price
	return order


## Kind, rarity and level, and deliberately nothing that could name a piece.
static func _describe(piece: Dictionary) -> Dictionary:
	return {
		"kind": String(piece.get("kind", "")),
		"rarity": int(piece.get("rarity", 0)),
		"level": int(piece.get("level", 1)),
	}


func is_open() -> bool:
	return stage == Stage.OPEN


## Whether anything is still owed to the player by this order.
##
## The one question the screen and the save both need, and the reason it is a
## function: "can this slot be reused" and "is this order finished" are the same
## question asked twice, and answering them separately is how a slot leaks.
func is_settled() -> bool:
	return stage == Stage.CLOSED


## Advances the order by one step of road.
##
## Returns true on the step that fills it. `rate` is what
## `ExchangeMarket.fill_rate` said, and `supply` gates a buy only: a caravan
## cannot hand over a piece nobody is carrying, however much you offer.
func advance(distance: float, rate: float, supply: float) -> bool:
	if stage != Stage.OPEN or distance <= 0.0 or rate <= 0.0:
		return false
	var moved: float = distance * rate
	if side == ExchangeMarket.Side.BUY:
		moved *= clampf(supply, 0.0, 1.0)
	if moved <= 0.0:
		return false
	progress = clampf(progress + moved, 0.0, 1.0)
	if progress < 1.0:
		return false
	stage = Stage.FILLED
	if side == ExchangeMarket.Side.SELL:
		payout_marks = price
		payout_piece = {}
		# The piece has gone to a caravan. Clearing it here rather than leaving
		# it sitting in `piece` is what makes "escrow holds it" true at every
		# moment rather than mostly: after this the order owes Marks and holds
		# no gear, and a collect that ran twice could not hand a piece back.
		piece = {}
	else:
		payout_piece = piece.duplicate(true)
		payout_piece["uid"] = Stash.new_uid()
		payout_marks = 0
		escrowed_marks = 0
		piece = {}
	return true


## Takes the order off the board. Returns what the player gets back.
##
## Cancelling an unfilled order is free and always gives back exactly what was
## escrowed - a piece for a sell, Marks for a buy. There is no partial fill in
## this design precisely so that this stays a single, total, obvious move.
func cancel() -> Dictionary:
	if stage != Stage.OPEN:
		return {}
	stage = Stage.CANCELLED
	var back: Dictionary = {"marks": escrowed_marks, "piece": piece.duplicate(true)}
	escrowed_marks = 0
	piece = {}
	return back


## Hands over what is waiting and frees the slot.
##
## The caller has to actually place the piece before this is believed - a full
## stash is a real answer and losing the piece to it would be the fault this
## whole file exists to prevent - so `taken` says whether the gear landed.
## Marks cannot fail to land, having no capacity.
func collect(taken: bool) -> Dictionary:
	if stage != Stage.FILLED and stage != Stage.CANCELLED:
		return {}
	if not payout_piece.is_empty() and not taken:
		return {}
	var paid: Dictionary = {"marks": payout_marks, "piece": payout_piece.duplicate(true)}
	payout_marks = 0
	payout_piece = {}
	stage = Stage.CLOSED
	return paid


## The order as plain data for the save.
func to_record() -> Dictionary:
	return {
		"side": int(side),
		"stage": int(stage),
		"piece": piece.duplicate(true),
		"price": price,
		"escrowed_marks": escrowed_marks,
		"progress": progress,
		"payout_marks": payout_marks,
		"payout_piece": payout_piece.duplicate(true),
		"about": about.duplicate(true),
	}


## Reads one back, or null.
##
## **Refuses rather than repairs.** A save is a file on a player's disk, and an
## order read half-way is an order holding a piece that also exists in the
## stash. Dropping a malformed row loses at most one listing; accepting one can
## duplicate gear, which is the thing that must never happen.
static func from_record(record: Dictionary) -> ExchangeOrder:
	if not (record.get("piece", null) is Dictionary):
		return null
	if not (record.get("payout_piece", {}) is Dictionary):
		return null
	var order := ExchangeOrder.new()
	order.side = clampi(int(record.get("side", 0)), 0, 1) as ExchangeMarket.Side
	order.stage = clampi(int(record.get("stage", 0)), 0,
		Stage.size() - 1) as Stage
	order.piece = (record["piece"] as Dictionary).duplicate(true)
	order.price = maxi(int(record.get("price", 0)), 0)
	order.escrowed_marks = maxi(int(record.get("escrowed_marks", 0)), 0)
	order.progress = clampf(float(record.get("progress", 0.0)), 0.0, 1.0)
	order.payout_marks = maxi(int(record.get("payout_marks", 0)), 0)
	order.payout_piece = (record.get("payout_piece", {}) as Dictionary).duplicate(true)
	var described: Variant = record.get("about", {})
	order.about = _describe(described as Dictionary) if described is Dictionary \
		else {}
	# A line written before the board drew descriptions, or one whose piece is
	# still in escrow, describes itself from what it is holding.
	if String(order.about.get("kind", "")).is_empty():
		order.about = _describe(order.piece if not order.piece.is_empty()
			else order.payout_piece)
	# A closed order owes nothing and holds nothing; it has no business being
	# written at all, and one that was is dropped rather than restored into a
	# slot the player cannot clear.
	if order.stage == Stage.CLOSED:
		return null
	return order
