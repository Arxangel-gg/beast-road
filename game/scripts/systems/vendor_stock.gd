class_name VendorStock

## **The Market's own wares, and the rules that stop them being re-rolled.**
##
## Owner brief, 2026-09-17: *"the Long Ledger should be something inside of a
## vendor shop, who also offers their own wares randomly refreshing each time a
## player returns from a run or every 10 minutes, whichever comes first, so
## that players do not just keep closing their game and reopening it to keep
## spam refreshing the vendor. It should retain the same inventory it had last
## time the game was opened if a run was not attempted. If a run is attempted
## for less than 2 minutes, it also will not count towards the vendor inventory
## refresh. Gear that the vendor sells should have some range of less than and
## rarely better than gear that the player should be able to be at and able to
## find, similar to diablo style."*
##
## **The anti-abuse rule is what decides the storage.** A stock rolled in
## memory is re-rolled by restarting the game, which is precisely the thing the
## brief forbids - so the stock and the moment it was rolled are written to the
## save, and the clock is *wall clock* rather than session time. Quitting and
## relaunching therefore changes nothing at all: the same eight things are on
## the shelf, with the same time left on them.
##
## **It amends working rule 7, and it is the mildest amendment in the file.**
## `MetaState.vendor` holds gear that is **not the player's**: unowned pieces on
## a shelf, with the timestamp that decides when they are swept off it. Nothing
## in it grants an attribute, a level, a currency or an unlock; buying one
## spends Marks and puts a piece in the stash, which rule 7 has sanctioned since
## gear existed. Delete the whole block and a player loses a shop window.
## Additive: a save from before this has no `vendor` key and reads as a shelf
## that has never been stocked, which is also what a new account is, so
## `SAVE_VERSION` did not move.
##
## **Marks buy it, and buying is always dearer than selling.** That is the same
## bound `exchange_check` holds over the Long Ledger and for the same reason: if
## a piece could ever be bought below what the stash pays for it,
## buy-sell-repeat prints Marks forever. `VENDOR_MARKUP` is over one and the
## gate reads the two prices rather than the constant.
##
## **And it sells no materials.** A material is an input to the Smithy and
## nothing else (2026-09-13); letting Marks buy one would make the seams and the
## timber on the outskirts optional, which is a road the player stops walking
## rather than a shop. Gear only.

## How many things are on the shelf. Enough that a refresh is worth looking at,
## few enough that reading it is not a chore.
const WARES: int = 8


static func _shelf() -> Dictionary:
	if not (MetaState.vendor is Dictionary):
		MetaState.vendor = {}
	return MetaState.vendor


static func _now() -> float:
	return Time.get_unix_time_from_system()


## What is on the shelf, rolling a fresh stock first if one is owed.
static func wares() -> Array:
	refresh_if_due()
	return _shelf().get("stock", []) as Array


## Seconds until the clock alone would refresh it. Zero means it is owed now.
static func seconds_left() -> float:
	var at: float = float(_shelf().get("rolled_at", 0.0))
	if at <= 0.0:
		return 0.0
	return maxf(Balance.VENDOR_REFRESH_SECONDS - (_now() - at), 0.0)


## **A run came home.** Only a real one counts: the brief's own two minutes,
## which is what stops "start a run, quit to the menu" being a refresh button.
##
## It does not roll here. A refresh is *owed* and taken the next time the shop
## is opened, so the stock a player is about to look at is rolled against the
## account as it stands when they look - after the run's gear, Marks and levels
## have been settled.
static func note_run(seconds: float) -> void:
	if seconds < Balance.VENDOR_RUN_MINIMUM_SECONDS:
		return
	_shelf()["owed"] = true
	MetaState.save_game()


## Whether the shelf would be swept if it were opened now. For the screen's own
## line and for the gate.
static func is_due() -> bool:
	var shelf: Dictionary = _shelf()
	if bool(shelf.get("owed", false)):
		return true
	if not (shelf.get("stock", []) is Array) or (shelf["stock"] as Array).is_empty():
		return true
	return seconds_left() <= 0.0


static func refresh_if_due() -> void:
	if is_due():
		refresh()


## Sweeps the shelf and stocks it again.
##
## **Seeded off the moment rather than off the run.** The shop is not on the
## road and never crosses the wire - each player's store is their own (owner,
## 2026-09-17) - so it may not draw from the run's stream, which every machine
## keeps in step. A decoration with its own dice, the rule the fireflies, the
## ponds' glints and the raccoon's cover are all drawn under.
static func refresh() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var stock: Array = []
	var kinds: Array = ContentDB.gear_kinds.values()
	var tier: int = maxi(MetaState.tier_cleared + 1, 0)
	for _index: int in WARES:
		var piece: Dictionary = Stash.roll(kinds, tier, rng)
		if piece.is_empty():
			continue
		piece["rarity"] = _shelf_rarity(rng)
		# Mostly as it came out of the ground. A shop full of upgraded gear
		# would be selling the Shards the player is supposed to be spending.
		if rng.randf() < Balance.VENDOR_UPGRADED_CHANCE:
			piece["level"] = 2
		piece["uid"] = Stash.new_uid()
		stock.append(piece)
	var shelf: Dictionary = _shelf()
	shelf["stock"] = stock
	shelf["rolled_at"] = _now()
	shelf["owed"] = false
	MetaState.save_game()


## **Diablo's shape: mostly a little behind you, rarely a step ahead.**
##
## The ladder the player is on is what they have actually held, not what the
## tables could produce - a Warden with nothing but Common gear is not helped by
## a window full of Oathbound they cannot pay for, and one in Chainbroken is not
## tempted by Commons. So the band is read off the stash and the worn set, and
## it *trails*: two rungs below at its deepest, and only `VENDOR_BETTER_CHANCE`
## of the time one rung above.
static func _shelf_rarity(rng: RandomNumberGenerator) -> int:
	var reach: int = reached()
	if rng.randf() < Balance.VENDOR_BETTER_CHANCE:
		return clampi(reach + 1, 0, Stash.RARITY_NAMES.size() - 1)
	var below: int = rng.randi_range(0, Balance.VENDOR_RARITY_TRAIL)
	return clampi(reach - below, 0, Stash.RARITY_NAMES.size() - 1)


## The best rarity this account has actually held. Worn gear counts, because a
## piece taken out of the stash and put on is still something they own.
static func reached() -> int:
	var best: int = 0
	for piece: Variant in MetaState.stash:
		if piece is Dictionary:
			best = maxi(best, int((piece as Dictionary).get("rarity", 0)))
	for slot: Variant in MetaState.equipped.values():
		if slot is Dictionary:
			best = maxi(best, int((slot as Dictionary).get("rarity", 0)))
	return clampi(best, 0, Stash.RARITY_NAMES.size() - 1)


## Marks asked for a piece. Read off the same sale price the stash pays, so the
## two can never disagree about what a Beastcalled is worth - and always above
## it, which is the whole bound.
static func price(piece: Dictionary) -> int:
	return maxi(int(round(float(Stash.sell_price(piece)) * Balance.VENDOR_MARKUP)), 1)


## Takes a piece off the shelf. Returns "" on success, or why not.
##
## Validate, then spend, then deliver - the order the Forge commits in, for the
## same reason: a shop that took the Marks and then found the stash full is
## worse than one that refuses.
static func buy(index: int) -> String:
	var stock: Array = _shelf().get("stock", []) as Array
	if index < 0 or index >= stock.size():
		return "That is already sold."
	var piece: Dictionary = stock[index] as Dictionary
	var asking: int = price(piece)
	if MetaState.marks < asking:
		return "You are %d Marks short." % (asking - MetaState.marks)
	if MetaState.stash.size() >= Balance.STASH_CAPACITY:
		return "The stash is full."
	MetaState.marks -= asking
	stock.remove_at(index)
	MetaState.receive_gear(piece)
	MetaState.save_game()
	return ""


## How the shelf reads its own clock, for the screen. One line rather than a
## countdown to the second: a shop with a timer on it is a shop people wait at.
static func refresh_line() -> String:
	if is_due():
		return "New wares are being laid out."
	var left: float = seconds_left()
	if left <= 60.0:
		return "New wares within the minute, or when you come back from the road."
	return "New wares in about %d minutes, or when you come back from the road." % (
		int(ceil(left / 60.0)))
