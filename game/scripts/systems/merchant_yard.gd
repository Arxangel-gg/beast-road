class_name MerchantYard
extends RefCounted

## Who is in town selling things, what they have, and what it costs.
##
## Built 2026-09-09 from the owner's brief: "unlockable stationary town vendors
## as well as traveling merchants that appear in town sometimes... maybe an
## alchemist who can sell the players potions". `MerchantData` records why those
## are one system rather than three; this is the half that decides *when*.
##
## **Two rules shape every price and every stock roll in here.**
##
## The first is working rule 7, and it is why no merchant sells gear. Gold is a
## run currency, Marks and Shards are account currencies, and they deliberately
## do not exchange - "a stash purchase must never compete with the wall about to
## be overrun". A merchant taking run Gold for permanent power would be exactly
## that exchange with a face drawn on it. So everything on these shelves is
## run-scoped: potions the run consumes, relics the run gives back, ammunition
## the run fires. What Gold buys from a merchant is always a better *tonight*.
##
## The second is that a shop has to cost something to use. Every price is quoted
## against `Balance.TOWER_BUILD_COST`, because the thing actually given up is a
## tower that would have been standing on the next road. A merchant whose prices
## do not hurt is a vending machine, and a vending machine is not a decision.
##
## Arrivals and stock both draw the "merchants" RNG stream, so a seed reproduces
## the same caravan carrying the same goods - the guarantee the wave table and
## the relic offers already make.

## What an offer can be. Every arm is fulfilled twice, in `_roll` and in
## `_deliver`, and `merchant_check` fails the build when one is not - for the
## same reason `item_check` does: a kind nothing delivers would be authorable,
## priced, drawn, purchasable, and would hand the player nothing.
const KIND_ITEM: String = "item"
const KIND_RELIC: String = "relic"
const KIND_AMMO: String = "ammo"

const KINDS: Array[String] = [KIND_ITEM, KIND_RELIC, KIND_AMMO]

## **A barricade was the obvious fourth kind and it is deliberately not here.**
## Barricades live on road tiles, keyed by `Vector2i`, and there is no inventory
## of unplaced ones - `RunState.set_barricade` writes a wall straight onto a
## tile. Selling one would have meant either handing the player a wall on a tile
## they did not choose, or inventing a "carried barricade" that every other
## system would then have to learn about. Both are worse than the shelf being
## three kinds deep, and an arm that cannot deliver is the exact failure the
## comment above is about.


# --- Who is here -------------------------------------------------------------

## Every merchant who has settled in town, in a stable order.
##
## Settling is *derived* rather than stored, from the distinct goods bought from
## them across every run. Derived cannot desync from the thing that earned it,
## and it needs no key in the save file: each purchase writes a
## `traded:<merchant>:<good>` entry into the same codex list that records having
## met an enemy, and `MetaState.seen_count` counts the prefix. That list is
## unlocked IDs, which working rule 7 already sanctions.
static func residents() -> Array[MerchantData]:
	var out: Array[MerchantData] = []
	for data: MerchantData in all_sorted():
		if settled(data.id):
			out.append(data)
	return out


static func all_sorted() -> Array[MerchantData]:
	var ids: Array = ContentDB.merchants.keys()
	ids.sort()
	var out: Array[MerchantData] = []
	for id: Variant in ids:
		var data := ContentDB.merchants[id] as MerchantData
		if data != null:
			out.append(data)
	return out


## How many different goods this merchant has ever sold the player.
static func trades_done(merchant_id: String) -> int:
	return MetaState.seen_count("traded:%s" % merchant_id)


static func settled(merchant_id: String) -> bool:
	var data: MerchantData = ContentDB.merchant(merchant_id)
	if data == null:
		return false
	return trades_done(merchant_id) >= data.settle_trades


## Everyone with a sheet the player can open right now: the residents, plus
## whichever traveller is currently visiting.
static func in_town() -> Array[String]:
	var out: Array[String] = []
	for data: MerchantData in residents():
		if RunState.merchant_visits.has(data.id):
			out.append(data.id)
	for key: Variant in RunState.merchant_visits:
		var id: String = String(key)
		if not out.has(id):
			out.append(id)
	return out


# --- Arrivals ----------------------------------------------------------------

## Called at the top of every Preparation. Residents restock; travellers arrive,
## stay their welcome, and leave.
##
## Residents restock on the same beat rather than holding one shelf forever,
## because a settled merchant whose three goods never change is furniture. What
## settling buys is *reliability* - they are always there - not a fixed stock.
static func begin_preparation() -> void:
	_expire_departed()
	for data: MerchantData in residents():
		_open_visit(data, true)
	_maybe_arrive()


static func _expire_departed() -> void:
	for key: Variant in RunState.merchant_visits.keys():
		var id: String = String(key)
		if settled(id):
			continue
		var visit: Dictionary = RunState.merchant_visits[key]
		if RunState.wave_number > int(visit.get("until_wave", 0)):
			RunState.merchant_visits.erase(key)
			EventBus.merchant_departed.emit(id)


static func _maybe_arrive() -> void:
	# One traveller at a time. Two caravans in one Preparation is a marketplace,
	# and the marketplace is a building that already exists and is already
	# balanced against.
	for key: Variant in RunState.merchant_visits:
		if not settled(String(key)):
			return
	var rng: RandomNumberGenerator = RunState.rng("merchants")
	if rng.randf() > Balance.MERCHANT_ARRIVAL_CHANCE:
		return
	var pool: Array[MerchantData] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for data: MerchantData in all_sorted():
		if settled(data.id) or RunState.act < data.first_act:
			continue
		pool.append(data)
		weights.append(data.arrival_weight)
		total += data.arrival_weight
	if pool.is_empty() or total <= 0.0:
		return
	var roll: float = rng.randf() * total
	for i: int in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			_open_visit(pool[i], false)
			EventBus.merchant_arrived.emit(pool[i].id)
			return


static func _open_visit(data: MerchantData, resident: bool) -> void:
	RunState.merchant_visits[data.id] = {
		"stock": _roll(data),
		"sold": [],
		"until_wave": RunState.wave_number + (RESIDENT_STAY if resident else data.stay_waves),
	}
	EventBus.merchant_stock_changed.emit(data.id)


## A resident's visit still carries a departure wave, rather than a null or a
## flag, so that every visit is the same shape and nothing downstream has to ask
## which kind it is holding. It is simply further away than a run is long.
const RESIDENT_STAY: int = 100000


## Waves left before this merchant leaves, or -1 for a resident who never does.
static func waves_left(merchant_id: String) -> int:
	if settled(merchant_id):
		return -1
	var visit: Dictionary = RunState.merchant_visits.get(merchant_id, {})
	if visit.is_empty():
		return 0
	return maxi(int(visit.get("until_wave", 0)) - RunState.wave_number + 1, 0)


# --- Stock -------------------------------------------------------------------

static func stock(merchant_id: String) -> Array:
	var visit: Dictionary = RunState.merchant_visits.get(merchant_id, {})
	return visit.get("stock", []) as Array


static func sold(merchant_id: String, index: int) -> bool:
	var visit: Dictionary = RunState.merchant_visits.get(merchant_id, {})
	var done: Array = visit.get("sold", []) as Array
	return done.has(index)


static func _roll(data: MerchantData) -> Array:
	var rng: RandomNumberGenerator = RunState.rng("merchants")
	match data.trade:
		MerchantData.Trade.POTIONS:
			return _roll_potions(data, rng)
		MerchantData.Trade.RELICS:
			return _roll_relics(data, rng)
		MerchantData.Trade.MUNITIONS:
			return _roll_munitions(data, rng)
	return []


static func _roll_potions(data: MerchantData, rng: RandomNumberGenerator) -> Array:
	var ids: Array = ContentDB.items.keys()
	ids.sort()
	_shuffle(ids, rng)
	var offers: Array = []
	for id: Variant in ids:
		if offers.size() >= data.stock_size:
			break
		var kind: ItemData = ContentDB.item(String(id))
		if kind == null:
			continue
		offers.append({
			"kind": KIND_ITEM,
			"id": kind.id,
			"amount": 1,
			"label": kind.display_name,
			"detail": kind.description,
			"cost": _price(data, rng, _item_price_scale(kind)),
		})
	return offers


## A Draught you may hold exactly one of is worth more than a tonic you may
## stack, and the carry limit is the game already saying so. Reading the price
## off the limit means a newly authored consumable arrives priced without anyone
## editing this file - the same reason `ItemData` carries an effect key instead
## of an `if item_id ==` chain.
static func _item_price_scale(kind: ItemData) -> float:
	return Balance.MERCHANT_SCARCE_ITEM_SCALE if kind.carry_limit <= 1 else 1.0


static func _roll_relics(data: MerchantData, rng: RandomNumberGenerator) -> Array:
	var ids: Array = []
	for value: Variant in ContentDB.relics.values():
		var relic := value as RelicData
		if relic == null or relic.is_boss_core:
			continue
		# Any act the run has reached, which is the peddler's whole reason to
		# exist: a crossroad only ever offers the act you are standing in, so an
		# Act 1 relic is unbuyable from Act 2 onward without this shelf.
		if relic.region > RunState.act:
			continue
		if RunState.held_relics.has(relic.id) or RunState.socketed_relics.has(relic.id):
			continue
		ids.append(relic.id)
	ids.sort()
	_shuffle(ids, rng)
	var offers: Array = []
	for id: Variant in ids:
		if offers.size() >= data.stock_size:
			break
		var relic: RelicData = ContentDB.relic(String(id))
		offers.append({
			"kind": KIND_RELIC,
			"id": relic.id,
			"amount": 1,
			"label": relic.display_name,
			"detail": relic.description,
			"cost": _price(data, rng, 1.0),
		})
	return offers


static func _roll_munitions(data: MerchantData, rng: RandomNumberGenerator) -> Array:
	var ids: Array = ContentDB.ammo_kinds.keys()
	ids.sort()
	_shuffle(ids, rng)
	var offers: Array = []
	for id: Variant in ids:
		if offers.size() >= data.stock_size:
			break
		var kind := ContentDB.ammo_kinds[id] as AmmoData
		if kind == null:
			continue
		var batch: int = maxi(kind.craft_batch, 1) * Balance.MERCHANT_AMMO_BUNDLE
		offers.append({
			"kind": KIND_AMMO,
			"id": kind.id,
			"amount": batch,
			"label": "%s x%d" % [kind.display_name, batch],
			"detail": kind.description,
			# Priced off what crafting the same batch costs, times a markup. A
			# quartermaster who undercut the forge would make blueprints
			# pointless, and blueprints are the permanent half of this economy.
			"cost": _marked_up(kind.craft_cost, Balance.MERCHANT_AMMO_BUNDLE),
		})
	return offers


static func _marked_up(cost: Dictionary, bundles: int) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in cost:
		out[String(key)] = int(ceilf(
			float(cost[key]) * float(bundles) * Balance.MERCHANT_AMMO_MARKUP))
	return out


## The authored price, jittered per visit so two runs are not the same shop.
## Bounded both ways: a bargain the player cannot recognise as one is noise, and
## a gouge they cannot afford is an empty shelf with extra steps.
static func _price(data: MerchantData, rng: RandomNumberGenerator, scale: float) -> Dictionary:
	var jitter: float = rng.randf_range(1.0 - Balance.MERCHANT_PRICE_JITTER,
		1.0 + Balance.MERCHANT_PRICE_JITTER)
	var cost: Dictionary = {}
	var gold: int = int(roundf(float(data.price_gold) * scale * jitter))
	if gold > 0:
		cost[RunState.GOLD] = gold
	if not data.price_currency.is_empty() and data.price_amount > 0:
		cost[data.price_currency] = maxi(int(roundf(float(data.price_amount) * scale * jitter)), 1)
	return cost


static func _shuffle(ids: Array, rng: RandomNumberGenerator) -> void:
	for index: int in range(ids.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: Variant = ids[index]
		ids[index] = ids[other]
		ids[other] = swap


# --- Buying ------------------------------------------------------------------

## Buys one offer. Returns "" on success, or the sentence to show the player.
##
## Every refusal has words. The Hero Mansion's four silent refusals are recorded
## in `town_panel` as the reason that sheet was rewritten, and a shop is the one
## screen where nothing happening is guaranteed to read as a broken button.
static func buy(merchant_id: String, index: int) -> String:
	var data: MerchantData = ContentDB.merchant(merchant_id)
	if data == null:
		return "There is nobody here to trade with."
	if not RunState.can_build_now():
		return "Trade happens in Preparation. The road is moving."
	var shelf: Array = stock(merchant_id)
	if index < 0 or index >= shelf.size():
		return "That is no longer on the table."
	if sold(merchant_id, index):
		return "You have already taken that one."
	var offer: Dictionary = shelf[index]
	var cost: Dictionary = offer.get("cost", {}) as Dictionary
	if not RunState.can_afford_cost(cost):
		return "You cannot afford it: %s." % RunState.format_cost(cost)

	# Room is checked *before* the money changes hands. Both the quiver and the
	# item carry limit refuse silently, and paying for a tonic that will not fit
	# is the worst failure a shop can have.
	var problem: String = _room_for(offer)
	if not problem.is_empty():
		return problem

	if not RunState.spend_cost(cost):
		return "You cannot afford it: %s." % RunState.format_cost(cost)
	_deliver(offer)

	var visit: Dictionary = RunState.merchant_visits.get(merchant_id, {})
	var done: Array = visit.get("sold", []) as Array
	done.append(index)
	visit["sold"] = done
	RunState.merchant_visits[merchant_id] = visit

	var was_settled: bool = settled(merchant_id)
	MetaState.record_seen("traded:%s" % merchant_id, String(offer.get("id", "")))
	EventBus.merchant_traded.emit(merchant_id, String(offer.get("id", "")))
	if not was_settled and settled(merchant_id):
		EventBus.merchant_settled.emit(merchant_id)
	EventBus.merchant_stock_changed.emit(merchant_id)
	return ""


static func _room_for(offer: Dictionary) -> String:
	var id: String = String(offer.get("id", ""))
	match String(offer.get("kind", "")):
		KIND_ITEM:
			if not RunState.can_take_item(id):
				return "You are already carrying all of those you can."
		KIND_AMMO:
			var kind := ContentDB.ammo_kinds.get(id, null) as AmmoData
			var bulk: int = maxi(kind.bulk if kind != null else 1, 1)
			if RunState.ammo_room() < bulk * int(offer.get("amount", 1)):
				return "Your quiver will not hold that many."
	return ""


static func _deliver(offer: Dictionary) -> void:
	var id: String = String(offer.get("id", ""))
	match String(offer.get("kind", "")):
		KIND_ITEM:
			RunState.take_item(id)
		KIND_RELIC:
			RunState.held_relics.append(id)
		KIND_AMMO:
			RunState.gain_ammo(id, int(offer.get("amount", 1)))
