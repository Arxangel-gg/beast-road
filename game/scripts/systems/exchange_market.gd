class_name ExchangeMarket
extends RefCounted

## What a piece is worth on the road, and how fast an order at a given price
## fills. No save, no socket, no autoload.
##
## Owner brief, 2026-09-10: "a runescape grand exchange / diablo auction house
## type of marketplace in game for players to be able to create a trading
## economy for all of the loot in the game".
##
## ## The one decision everything else follows from
##
## **Prices are shared. Custody is not.**
##
## A grand exchange normally means a server holding other people's items while
## they are neither party's. Beast Road has no account server - the Supabase
## project behind the leaderboard answers to an anonymous key that every copy of
## the game carries, so anything a client can write, any client can forge. A
## forged leaderboard row is graffiti. A forged *item* is the end of the loot
## economy, and `CLAUDE.md` records the bound plainly: gear is never created.
##
## So the Long Ledger shares the one thing that is safe to share - **what things
## sold for** - and never the things themselves. The counterparty is always the
## Ledger's own caravans, the escrow is always local, and the worst a forged
## price row can do is make somebody's guide price wrong for a day.
##
## That is not a compromise dressed up. It is what a grand exchange *is* for
## most of the people using one: you post at a price, walk away, and come back
## to money, and the price moves because of what everybody else did. That whole
## experience survives intact.
##
## ## The two bounds that keep it from eating the game
##
## **1. Buying is always dearer than vendoring.** The stash already sells a
## piece for `Stash.sell_price`. If the Ledger could ever be bought from below
## that, the loop is: buy at the Ledger, sell at the stash, repeat, infinite
## Marks. So the lowest bid that can *ever* fill is held strictly above the
## vendor price by `Balance.EXCHANGE_BID_FLOOR`, and `exchange_check` asserts it
## against every rarity and level in the game rather than against a comment.
##
## **2. The Ledger cannot sell what nobody sold it.** Gear is "the reason to
## replay" (owner, 2026-09-01). A shop with an infinite catalogue makes the road
## optional - you would farm Marks and buy the rest. So a buy order fills out of
## *observed supply*: what the community actually listed, read from the price
## feed. With no network there is a thin authored baseline so the feature works
## on day one and on a plane, and that baseline is deliberately worst at the top
## rarities - an Oathbound piece is something you find.

## Which way an order faces.
enum Side {
	## The player is giving gear and wants Marks.
	SELL,
	## The player is giving Marks and wants gear.
	BUY,
}


## What a piece is nominally worth in Marks, before anybody's price.
##
## Anchored to `Stash.sell_price` rather than authored separately, because two
## price tables for one item drift apart the first time somebody retunes one.
## The markup over the vendor is the Ledger's whole reason to exist: a caravan
## pays better than breaking it down in your own hold, and that is why you would
## wait rather than take the immediate money.
static func guide_price(piece: Dictionary, demand: float = 1.0) -> int:
	var vendor: int = Stash.sell_price(piece)
	var lifted: float = float(vendor) * Balance.EXCHANGE_GUIDE_OVER_VENDOR
	return maxi(1, int(round(lifted * clampf(demand,
		Balance.EXCHANGE_DEMAND_FLOOR, Balance.EXCHANGE_DEMAND_CEILING))))


## The least a buyer may offer and still ever be filled.
##
## **This is the anti-laundering bound and it is one line.** Strictly above the
## vendor price, so buying a piece and selling it back always loses Marks.
static func min_bid(piece: Dictionary, demand: float = 1.0) -> int:
	var floored: int = int(ceil(float(guide_price(piece, demand))
		* Balance.EXCHANGE_BID_FLOOR))
	# Belt and braces: even if the two constants above are ever retuned into
	# each other, a bid cannot land at or under what the stash would pay.
	return maxi(floored, Stash.sell_price(piece) + 1)


## The most a seller may ask and still ever be filled.
##
## An ask above this is not refused - a player may write any number in the
## ledger - it simply never finds a caravan, which is the honest behaviour and
## the one that teaches the guide price.
static func max_ask(piece: Dictionary, demand: float = 1.0) -> int:
	return maxi(1, int(round(float(guide_price(piece, demand))
		* Balance.EXCHANGE_ASK_CEILING)))


## How much of an order one unit of road closes, in [0, 1] per distance unit.
##
## Zero means never: an ask nobody will meet, or a bid under the floor. The
## curve between is linear in how far the price is from the guide, because a
## player has to be able to *predict* it - "ask less, sell sooner" is the whole
## skill the screen is teaching, and an opaque curve teaches nothing.
## `side` is a `Side` taken as an int: an enum declared inside one class and a
## variable typed with it from another are not the same type to GDScript's
## checker, and this is called from `ExchangeOrder`.
static func fill_rate(side: int, price: int, guide: int, ceiling: int,
		floor_price: int) -> float:
	if guide <= 0 or price <= 0:
		return 0.0
	if side == Side.SELL:
		if price > ceiling:
			return 0.0
		if price <= guide:
			# At or under the guide there is always a buyer; going lower buys
			# speed up to a cap rather than without limit, so dumping at one
			# Mark is not an instant-sell button.
			var under: float = float(guide - price) / maxf(float(guide), 1.0)
			return Balance.EXCHANGE_FILL_AT_GUIDE * (1.0
				+ minf(under, 1.0) * (Balance.EXCHANGE_FILL_BEST_MULTIPLIER - 1.0))
		# `ceiling + 1`, so the ceiling itself is the last price that *does* find
		# a caravan rather than the first that does not. The screen tells the
		# player "nobody sells over N", and N has to be a number that works.
		var over: float = float(price - guide) / maxf(float(ceiling + 1 - guide), 1.0)
		return Balance.EXCHANGE_FILL_AT_GUIDE * maxf(1.0 - over, 0.0)
	if price < floor_price:
		return 0.0
	if price >= guide:
		var above: float = float(price - guide) / maxf(float(guide), 1.0)
		return Balance.EXCHANGE_FILL_AT_GUIDE * (1.0
			+ minf(above, 1.0) * (Balance.EXCHANGE_FILL_BEST_MULTIPLIER - 1.0))
	# `+ 1` for the same reason the ask ceiling has one: the floor is the last
	# bid that finds a caravan, not the first that does not.
	var under_guide: float = float(guide - price) 		/ maxf(float(guide - floor_price + 1), 1.0)
	return Balance.EXCHANGE_FILL_AT_GUIDE * maxf(1.0 - under_guide, 0.0)


## How much of this rarity the road is carrying, in [0, 1].
##
## The authored fallback, used when the price feed has said nothing. Falls away
## sharply with rarity on purpose: commons are what caravans have crates of, and
## an Oathbound piece is something a Warden found and mostly keeps.
static func baseline_supply(rarity: int) -> float:
	var index: int = clampi(rarity, 0, Balance.EXCHANGE_BASELINE_SUPPLY.size() - 1)
	return Balance.EXCHANGE_BASELINE_SUPPLY[index]


## Demand for a piece, from what the community has been paying for its like.
##
## `feed` is rows of `{"rarity": int, "price": int, "vendor": int}` - what a
## piece went for against what the stash would have paid for it. The ratio is
## the only comparable number across kinds and levels, which is why it is what
## travels rather than a raw price.
##
## Bounded hard at both ends. This is the one number a stranger can influence,
## and the clamp is what makes a forged row worth at most a nudge.
static func demand_from(feed: Array, rarity: int) -> float:
	var total: float = 0.0
	var seen: int = 0
	for entry: Variant in feed:
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		if int(row.get("rarity", -1)) != rarity:
			continue
		var vendor: float = maxf(float(row.get("vendor", 0)), 1.0)
		var paid: float = maxf(float(row.get("price", 0)), 0.0)
		# The observed multiple over vendor, expressed against the guide's own
		# markup so that "everybody paid exactly guide" reads as demand 1.0.
		total += (paid / vendor) / Balance.EXCHANGE_GUIDE_OVER_VENDOR
		seen += 1
	if seen < Balance.EXCHANGE_DEMAND_MIN_SAMPLES:
		return 1.0
	return clampf(total / float(seen), Balance.EXCHANGE_DEMAND_FLOOR,
		Balance.EXCHANGE_DEMAND_CEILING)


## How much of a rarity the community is actually listing, in [0, 1].
##
## Counted rather than averaged: what a buyer needs to know is whether anybody
## is selling these at all. Falls back to the authored baseline until enough
## rows exist to say anything, so an empty feed is "the road as authored" rather
## than "the road is empty".
static func supply_from(feed: Array, rarity: int) -> float:
	var matching: int = 0
	var rows: int = 0
	for entry: Variant in feed:
		if not (entry is Dictionary):
			continue
		rows += 1
		if int((entry as Dictionary).get("rarity", -1)) == rarity:
			matching += 1
	if rows < Balance.EXCHANGE_DEMAND_MIN_SAMPLES:
		return baseline_supply(rarity)
	# Blended rather than replaced. A feed that happens to hold no Oathbound
	# rows this week should make them scarce, not unbuyable forever - the
	# baseline is what stops one quiet day from closing a rarity down.
	var observed: float = float(matching) / float(rows)
	return clampf(lerpf(baseline_supply(rarity), observed,
		Balance.EXCHANGE_SUPPLY_FEED_WEIGHT), 0.0, 1.0)
