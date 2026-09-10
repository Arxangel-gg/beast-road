extends Node

## The merchant system holds its bounds, and every shelf it can roll is real.
##
## Written with the system on 2026-09-09. Two of these assertions exist because
## the same fault has now been found twice in this codebase and once in this
## file's own subject:
##
## - `item_check` was written after an item effect that nothing read shipped,
##   and `DisciplineEffects` after twenty-one discipline effects did the same.
##   An offer kind that `_deliver` does not fulfil would be identical: priced,
##   drawn, pressable, and it would take the player's Gold and hand back
##   nothing. `_test_every_kind_delivers` buys one of each and looks at what
##   arrived.
## - Working rule 7 says run currency and account currency deliberately do not
##   exchange, "a stash purchase must never compete with the wall about to be
##   overrun". A merchant is the most natural place in the entire game to break
##   that by accident, so `_test_nothing_permanent_is_for_sale` asserts that no
##   shelf anywhere sells gear, a blueprint, or anything else that outlives the
##   run - and that the money only ever moves one way.
##
## The rest is what a shop has to be to be worth opening: a traveller has to
## actually turn up, actually leave, and actually settle; and prices have to be
## affordable at the point the merchant appears rather than in theory.

var _failures: int = 0
var _checked: int = 0

## The trading history as the player left it.
##
## Settling is derived from `MetaState.codex_seen`, so this gate cannot test it
## without writing to it - and buying things is most of what this gate does.
## Two consequences, both handled here rather than hoped about:
##
## - Tests contaminate each other. The first version bought every good on every
##   shelf and *then* asked whether travellers arrive; by that point all three
##   had settled, and a settled merchant never arrives. It reported zero
##   arrivals from a system that was working correctly.
## - A gate must not eat the player's progress. This is run against an isolated
##   profile in CI, but not when somebody runs it by hand.
## Prefix for the fake goods `_test_settling_is_earned_and_permanent` records.
##
## Distinctive on purpose, and filtered out of the snapshot below. A crash
## between recording one and restoring the codex would otherwise leave the
## player permanently owed a merchant they never traded with - which is exactly
## what happened on this machine while the gate was being written, and took a
## screenshot of a settled Alchemist to notice.
const PROBE_GOOD: String = "gate_probe_good_"

var _codex_before: Array[String] = []

## Counted by the signal handlers below.
##
## Members rather than locals because **GDScript lambdas capture locals by
## value**. `var n := 0` followed by a handler doing `n += 1` increments a copy,
## the outer `n` stays at zero, and the gate reports that no merchant ever
## arrives from a system that is arriving correctly. That cost a wrong diagnosis
## here before the capture rule was remembered.
var _arrivals: int = 0
var _departures: int = 0


func _ready() -> void:
	# Held for the whole run: this tool edits `MetaState`, and a tool that
	# edits the account must never be able to write it to the player's disk.
	# See `save_guard_check`, which finds these by reading them.
	MetaState.hold_saves()
	await get_tree().process_frame
	_codex_before = []
	for entry: String in MetaState.codex_seen:
		if not entry.contains(PROBE_GOOD):
			_codex_before.append(entry)
	_strip_trades()
	_test_every_kind_delivers()
	_test_nothing_permanent_is_for_sale()
	_test_travellers_arrive_and_leave()
	_test_settling_is_earned_and_permanent()
	_test_prices_are_reachable()
	_test_buying_ammo_costs_more_than_making_it()
	_test_refusals_all_speak()
	_finish()


func _fresh_run() -> void:
	RunState.reset()
	RunState.set_phase(RunState.Phase.PREPARATION)


## Every offer kind a roll can produce is one a purchase actually hands over.
##
## Driven by buying, not by reading the match statement: an arm that compiles
## and does nothing looks identical to a correct one from the outside, which is
## exactly how the discipline effects survived review for so long.
func _test_every_kind_delivers() -> void:
	var seen: Dictionary = {}
	for data: MerchantData in MerchantYard.all_sorted():
		_fresh_run()
		RunState.act = 3
		RunState.gain_every_currency(4000)
		# Ammunition needs a bow before the quiver will take anything.
		RunState.gain_ammo("plain_arrow", 1)
		MerchantYard._open_visit(data, false)
		var shelf: Array = MerchantYard.stock(data.id)
		_checked += 1
		_check(not shelf.is_empty(), "%s rolled an empty shelf with everything available"
			% data.id)
		for index: int in shelf.size():
			var offer: Dictionary = shelf[index]
			var kind: String = String(offer.get("kind", ""))
			_checked += 1
			_check(MerchantYard.KINDS.has(kind),
				"%s offers kind '%s', which is not one this system knows" % [data.id, kind])
			# Emptied between rows on purpose. A quartermaster's cart deliberately
			# holds more ammunition than a 48-bulk quiver can take at once - that
			# is the choice the shelf exists to pose - so buying all three in a
			# row is refused for room, correctly, and this test is about whether
			# each kind *delivers*, not about capacity. `_test_refusals_all_speak`
			# owns the refusal.
			RunState.ammo.clear()
			RunState.gain_ammo("plain_arrow", 1)
			var before: int = _holding(offer)
			var problem: String = MerchantYard.buy(data.id, index)
			_checked += 1
			_check(problem.is_empty(), "%s could not sell offer %d: %s"
				% [data.id, index, problem])
			_checked += 1
			_check(_holding(offer) > before,
				"%s took payment for a %s and the player is holding no more of it"
					% [data.id, kind])
			seen[kind] = true
	for kind: String in MerchantYard.KINDS:
		_checked += 1
		_check(seen.has(kind),
			"no authored merchant can ever offer a '%s', so that arm is dead code" % kind)


## What the player holds of whatever an offer is selling.
func _holding(offer: Dictionary) -> int:
	var id: String = String(offer.get("id", ""))
	match String(offer.get("kind", "")):
		MerchantYard.KIND_ITEM:
			return RunState.item_count(id)
		MerchantYard.KIND_RELIC:
			return 1 if RunState.held_relics.has(id) else 0
		MerchantYard.KIND_AMMO:
			return RunState.ammo_count(id)
	return 0


## Working rule 7, held at the shelf.
##
## Two halves. Nothing sold outlives the run - so no gear, no blueprint, no
## permanent unlock, checked by asserting that a full shopping spree changes
## nothing in `MetaState` except the record of having traded. And nothing paid
## for it is an account currency: Marks and Shards must not move.
func _test_nothing_permanent_is_for_sale() -> void:
	for data: MerchantData in MerchantYard.all_sorted():
		_fresh_run()
		RunState.act = 3
		RunState.gain_every_currency(4000)
		RunState.gain_ammo("plain_arrow", 1)
		var marks: int = MetaState.marks
		var shards: int = MetaState.shards
		var stash: int = MetaState.stash.size()
		var recipes: int = MetaState.unlocked_blueprints.size()
		var towers: int = MetaState.unlocked_towers.size()
		MerchantYard._open_visit(data, false)
		for index: int in MerchantYard.stock(data.id).size():
			var offer: Dictionary = MerchantYard.stock(data.id)[index]
			var cost: Dictionary = offer.get("cost", {}) as Dictionary
			for key: Variant in cost:
				_checked += 1
				_check(RunState.CURRENCIES.has(String(key)),
					"%s prices something in '%s', which is not a run currency"
						% [data.id, String(key)])
			MerchantYard.buy(data.id, index)
		_checked += 1
		_check(MetaState.marks == marks and MetaState.shards == shards,
			"%s moved an account currency" % data.id)
		_checked += 1
		_check(MetaState.stash.size() == stash,
			"%s put something permanent in the stash" % data.id)
		_checked += 1
		_check(MetaState.unlocked_blueprints.size() == recipes
				and MetaState.unlocked_towers.size() == towers,
			"%s sold a permanent unlock for run currency" % data.id)


## A traveller turns up within a reasonable number of Preparations, and is gone
## again after their welcome runs out.
##
## Seeded rather than probabilistic: `MERCHANT_ARRIVAL_CHANCE` is a third, so a
## single seed that happens to roll badly proves nothing. Forty runs is enough
## that a system which never fires is unmistakable.
func _test_travellers_arrive_and_leave() -> void:
	_strip_trades()
	_arrivals = 0
	_departures = 0
	# Counted from the signal rather than inferred from who is standing in town.
	# Inferring got this wrong first time: `_expire_departed` runs immediately
	# before `_maybe_arrive`, so one merchant in three leaves and is replaced by
	# *itself* in the same Preparation, and a presence check sees no gap at all.
	var on_arrive: Callable = func(_id: String) -> void: _arrivals += 1
	var on_depart: Callable = func(_id: String) -> void: _departures += 1
	EventBus.merchant_arrived.connect(on_arrive)
	EventBus.merchant_departed.connect(on_depart)
	for seed_index: int in 40:
		_fresh_run()
		RunState.run_seed = 5000 + seed_index
		RunState.act = 3
		for wave: int in 12:
			RunState.wave_number = wave + 1
			MerchantYard.begin_preparation()
	EventBus.merchant_arrived.disconnect(on_arrive)
	EventBus.merchant_departed.disconnect(on_depart)
	_checked += 1
	_check(_arrivals >= 40,
		"only %d arrivals across 40 seeded runs of twelve waves" % _arrivals)
	_checked += 1
	_check(_departures >= 30,
		"%d arrivals but only %d departures; welcomes are not running out"
			% [_arrivals, _departures])


## Settling costs distinct business, is derived rather than stored, and once
## earned it is permanent and needs no arrival roll.
func _test_settling_is_earned_and_permanent() -> void:
	var data: MerchantData = MerchantYard.all_sorted()[0]
	_strip_trades()
	_checked += 1
	_check(not MerchantYard.settled(data.id),
		"%s counts as settled with no business done" % data.id)

	for i: int in data.settle_trades - 1:
		MetaState.record_seen("traded:%s" % data.id, "%s%d" % [PROBE_GOOD, i])
	_checked += 1
	_check(not MerchantYard.settled(data.id),
		"%s settled one trade early" % data.id)

	# The same good again must not count. Distinct is the whole point: a
	# threshold a player can grind by buying one tonic nine times is a counter
	# wearing a progression's clothes.
	MetaState.record_seen("traded:%s" % data.id, PROBE_GOOD + "0")
	_checked += 1
	_check(not MerchantYard.settled(data.id),
		"%s settled on a repeat purchase" % data.id)

	MetaState.record_seen("traded:%s" % data.id, PROBE_GOOD + "last")
	_checked += 1
	_check(MerchantYard.settled(data.id), "%s never settles" % data.id)

	_fresh_run()
	RunState.act = 3
	MerchantYard.begin_preparation()
	_checked += 1
	_check(MerchantYard.in_town().has(data.id),
		"%s is settled but was not in town at the start of a run" % data.id)
	_checked += 1
	_check(MerchantYard.waves_left(data.id) < 0,
		"%s is settled and still counting down to leaving" % data.id)



func _strip_trades() -> void:
	var kept: Array[String] = []
	for entry: String in MetaState.codex_seen:
		if not entry.begins_with("traded:"):
			kept.append(entry)
	MetaState.codex_seen = kept


## A price has to be payable at the point the merchant can appear, and clearing
## a shelf has to cost more than a tower - or the shop is a vending machine.
##
## Affordability is computed against a purse rather than by spending, because
## the first version of this test called `RunState.reset()` to lower the purse
## and reset cleared `merchant_visits` with it. The shelf it then measured was
## empty, so "nothing here is expensive" passed on a shop with no goods in it.
func _test_prices_are_reachable() -> void:
	_strip_trades()
	for data: MerchantData in MerchantYard.all_sorted():
		_fresh_run()
		RunState.act = data.first_act
		MerchantYard._open_visit(data, false)
		var shelf: Array = MerchantYard.stock(data.id)
		_checked += 1
		_check(not shelf.is_empty(), "%s arrives with an empty cart" % data.id)

		# What a careful player is plausibly holding when this merchant first
		# travels: a few waves of kills, minus a tower or two.
		var purse: int = Balance.TOWER_BUILD_COST * (2 + data.first_act * 2)
		var affordable: int = 0
		var shelf_total: int = 0
		for offer: Variant in shelf:
			var cost: Dictionary = (offer as Dictionary).get("cost", {}) as Dictionary
			if _affordable_with(cost, purse):
				affordable += 1
			for key: Variant in cost:
				shelf_total += int(cost[key])
		_checked += 1
		_check(affordable > 0,
			"%s arrives in act %d with nothing a %d-purse player can buy"
				% [data.id, data.first_act, purse])
		# The other end. Per-offer would be the wrong bound: ammunition is meant
		# to be cheap by the bundle, and a quartermaster whose arrows each cost a
		# tower would be unusable. What must hurt is taking the whole cart.
		_checked += 1
		_check(shelf_total > Balance.TOWER_BUILD_COST,
			"clearing %s's cart costs %d, less than one tower" % [data.id, shelf_total])


static func _affordable_with(cost: Dictionary, purse: int) -> bool:
	for key: Variant in cost:
		if int(cost[key]) > purse:
			return false
	return true


## Ammunition costs more from a merchant than from the forge. Blueprints are the
## permanent half of the crafting economy, and a quartermaster who undercut them
## would make learning one pointless.
func _test_buying_ammo_costs_more_than_making_it() -> void:
	for data: MerchantData in MerchantYard.all_sorted():
		if data.trade != MerchantData.Trade.MUNITIONS:
			continue
		_fresh_run()
		RunState.act = data.first_act
		MerchantYard._open_visit(data, false)
		for offer: Variant in MerchantYard.stock(data.id):
			var row: Dictionary = offer as Dictionary
			var kind := ContentDB.ammo_kinds.get(String(row.get("id", "")), null) as AmmoData
			if kind == null:
				continue
			var shop: int = 0
			var forge: int = 0
			for key: Variant in (row.get("cost", {}) as Dictionary):
				shop += int((row.get("cost", {}) as Dictionary)[key])
			for key: Variant in kind.craft_cost:
				forge += int(kind.craft_cost[key])
			_checked += 1
			_check(shop > forge,
				"%s sells %s for %d; the forge makes the same batch for %d"
					% [data.id, kind.id, shop, forge])


## Every way a purchase can fail says something. A shop that refuses in silence
## reads as a broken button, which is the fault the Hero Mansion was rewritten
## for and the one most likely to be reported as "the merchant does not work".
func _test_refusals_all_speak() -> void:
	var data: MerchantData = MerchantYard.all_sorted()[0]
	_fresh_run()
	RunState.act = 3
	MerchantYard._open_visit(data, false)

	_checked += 1
	_check(not MerchantYard.buy(data.id, 99).is_empty(),
		"buying an offer that is not there refused silently")
	_checked += 1
	_check(not MerchantYard.buy("nobody_at_all", 0).is_empty(),
		"buying from a merchant who does not exist refused silently")
	_checked += 1
	_check(not MerchantYard.buy(data.id, 0).is_empty(),
		"buying with an empty purse refused silently")

	RunState.gain_every_currency(4000)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_checked += 1
	_check(not MerchantYard.buy(data.id, 0).is_empty(),
		"buying mid-battle refused silently")

	RunState.set_phase(RunState.Phase.PREPARATION)
	_checked += 1
	_check(MerchantYard.buy(data.id, 0).is_empty(),
		"a funded purchase in Preparation was refused")
	_checked += 1
	_check(not MerchantYard.buy(data.id, 0).is_empty(),
		"the same row sold twice")


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[merchants] %s" % why)


func _finish() -> void:
	MetaState.codex_seen = _codex_before
	MetaState.save_game()
	if _failures == 0:
		print("[merchants] PASS - %d assertions across %d merchants; every offer kind delivers"
			% [_checked, MerchantYard.all_sorted().size()])
	else:
		push_error("[merchants] FAIL - %d of %d assertions" % [_failures, _checked])
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(1 if _failures > 0 else 0)
