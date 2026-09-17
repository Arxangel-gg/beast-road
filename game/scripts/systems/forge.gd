class_name Forge
extends RefCounted

## What a smith can make out of what the road gave up.
##
## Owner brief, 2026-09-13: smithing beside woodcutting and mining, gems out of
## the ground, and "a gem plus smithing level gives a chance at rarity".
##
## **A forged piece is gear, which is why materials are allowed to persist at
## all.** `MaterialData` states the bound and this is where it is kept: the
## Smithy spends wood, ore and a gem and returns a piece rolled on the same
## `Stash` tables a dropped one is rolled on, at a rarity the gem and the
## smith's own practice *tilt*. So the forge is another way to reach the loot
## ladder and never a way to climb past it - working rule 7 is untouched, and
## `gathering_check` asserts that a forged piece is indistinguishable from a
## found one once it is in the stash.
##
## **The gem is a lottery ticket, not a guarantee**, and that is deliberate.
## A gem of rarity R gives R steps of *chance* rather than R steps of rarity, so
## a Duskstone makes a good piece likely and never certain; otherwise the top
## rarities stop being found and start being bought, which is the exact failure
## `exchange_check` exists to prevent on the other side of the economy.
##
## Static, with `MetaState` as the only state it touches, so the gate can drive
## the real thing rather than a copy of it.


## Everything that can refuse a piece, in one place, so the screen and the gate
## ask the same question. Returns "" when the forge would work.
static func refusal(wood_id: String, ore_id: String, gem_id: String) -> String:
	var wood: MaterialData = ContentDB.material(wood_id)
	var ore: MaterialData = ContentDB.material(ore_id)
	var gem: MaterialData = ContentDB.material(gem_id)
	if wood == null or wood.kind != MaterialData.Kind.WOOD:
		return "The forge needs wood."
	if ore == null or ore.kind != MaterialData.Kind.ORE:
		return "The forge needs ore."
	if gem == null or gem.kind != MaterialData.Kind.GEM:
		return "The forge needs a gem to set."
	if MetaState.material_count(wood_id) < Balance.FORGE_WOOD_COST:
		return "Not enough %s: %d of %d." % [wood.display_name,
			MetaState.material_count(wood_id), Balance.FORGE_WOOD_COST]
	if MetaState.material_count(ore_id) < Balance.FORGE_ORE_COST:
		return "Not enough %s: %d of %d." % [ore.display_name,
			MetaState.material_count(ore_id), Balance.FORGE_ORE_COST]
	if MetaState.material_count(gem_id) < Balance.FORGE_GEM_COST:
		return "No %s to set." % gem.display_name
	var wanted: int = Balance.FORGE_GEM_LEVEL[clampi(gem.rarity, 0,
		Balance.FORGE_GEM_LEVEL.size() - 1)]
	if MetaState.profession_level("smith") < wanted:
		return "Setting %s wants a Smith of level %d; yours is %d." % [
			gem.display_name, wanted, MetaState.profession_level("smith")]
	if MetaState.stash.size() >= Balance.STASH_CAPACITY:
		return "The stash is full. Nothing may be forged into nowhere."
	return ""


## Forges a piece. Returns the piece, or an empty dictionary and a refusal.
##
## **Validate, then spend, then make.** The order matters: a forge that spent
## first and failed second would eat the gem, which is the scarce half of the
## price and the one a player went out past the camps for.
static func forge(wood_id: String, ore_id: String, gem_id: String) -> Dictionary:
	var refused: String = refusal(wood_id, ore_id, gem_id)
	if not refused.is_empty():
		return {"error": refused}
	if not MetaState.spend_material(wood_id, Balance.FORGE_WOOD_COST):
		return {"error": "The wood was gone."}
	if not MetaState.spend_material(ore_id, Balance.FORGE_ORE_COST):
		# Put the wood back. Nothing else in this project un-spends, and this
		# one does because the alternative is silently eating a full stack on a
		# race that should not be possible.
		MetaState.gain_material(wood_id, Balance.FORGE_WOOD_COST)
		return {"error": "The ore was gone."}
	if not MetaState.spend_material(gem_id, Balance.FORGE_GEM_COST):
		MetaState.gain_material(wood_id, Balance.FORGE_WOOD_COST)
		MetaState.gain_material(ore_id, Balance.FORGE_ORE_COST)
		return {"error": "The gem was gone."}

	var piece: Dictionary = _strike(wood_id, ore_id, gem_id)
	var before: int = MetaState.profession_level("smith")
	var after: int = MetaState.gain_profession_xp("smith", Balance.FORGE_XP)
	if after > before:
		EventBus.craft_levelled.emit("smith", after)
	if not MetaState.take_gear(piece):
		# Unreachable while `refusal` checks the stash first, and put back
		# anyway: the one thing this function must never do is take a gem and
		# hand back nothing, and "it cannot happen" is how that happens.
		MetaState.gain_material(wood_id, Balance.FORGE_WOOD_COST)
		MetaState.gain_material(ore_id, Balance.FORGE_ORE_COST)
		MetaState.gain_material(gem_id, Balance.FORGE_GEM_COST)
		return {"error": "The stash is full."}
	return piece


## The piece itself: a kind off the same tables, at a rarity the gem and the
## smith argued for.
static func _strike(wood_id: String, ore_id: String, gem_id: String,
		hands: int = -1) -> Dictionary:
	var wood: MaterialData = ContentDB.material(wood_id)
	var ore: MaterialData = ContentDB.material(ore_id)
	var gem: MaterialData = ContentDB.material(gem_id)
	var kinds: Array[GearData] = ContentDB.gear_sorted()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var kind: GearData = kinds[rng.randi_range(0, kinds.size() - 1)]

	# The level a forged piece comes out at is decided by the *stock*, which is
	# what makes better wood and better ore worth carrying home rather than
	# being a second currency for the same result.
	var stock: int = wood.rarity + ore.rarity
	var level: int = clampi(1 + stock, 1, Stash.MAX_LEVEL)

	# And the rarity is a ladder climbed one rung at a time, each rung its own
	# roll. A gem of rarity R offers R+1 attempts at the gem's own odds; the
	# smith's practice adds a share of one more. Compounding this way is what
	# keeps the top of the ladder rare: four rungs at seven tenths each is a
	# quarter of the time, not a certainty.
	var rarity: int = Balance.FORGE_BASE_RARITY
	var gem_odds: float = Balance.FORGE_GEM_RARITY_CHANCE[clampi(gem.rarity, 0,
		Balance.FORGE_GEM_RARITY_CHANCE.size() - 1)]
	# Whose practice argued for the rarity. The Warden's own unless somebody
	# else is at the anvil - a commission is struck by Orden, and his hands are
	# middling rather than masterful (`COMMISSION_SMITH_SKILL`).
	var skill: int = hands if hands > 0 else MetaState.profession_level("smith")
	var share: float = float(skill - 1) / maxf(float(Balance.PROFESSION_MAX_LEVEL - 1), 1.0)
	var odds: float = clampf(gem_odds + share * Balance.FORGE_SKILL_RARITY_CHANCE, 0.0, 0.95)
	var steps: int = mini(gem.rarity + 1, Balance.FORGE_MAX_RARITY_STEPS)
	for _rung: int in steps:
		if rng.randf() >= odds:
			break
		rarity += 1
	rarity = clampi(rarity, 0, Stash.RARITY_NAMES.size() - 1)

	# Through `Stash.make`, so a forged piece is built by exactly the function
	# that builds a dropped one. A second constructor here is how the two would
	# eventually disagree about what a piece is.
	return Stash.make(kind.id, rarity, level)


## What the forge would cost, for the screen to draw before anything is spent.
static func price(wood_id: String, ore_id: String, gem_id: String) -> Array[Dictionary]:
	return [
		{"id": wood_id, "need": Balance.FORGE_WOOD_COST,
			"have": MetaState.material_count(wood_id)},
		{"id": ore_id, "need": Balance.FORGE_ORE_COST,
			"have": MetaState.material_count(ore_id)},
		{"id": gem_id, "need": Balance.FORGE_GEM_COST,
			"have": MetaState.material_count(gem_id)},
	]


## The chance of climbing one rung, for the screen to show honestly. A forge
## that hid its odds would be a slot machine.
static func rung_odds(gem_id: String) -> float:
	var gem: MaterialData = ContentDB.material(gem_id)
	if gem == null:
		return 0.0
	var share: float = float(MetaState.profession_level("smith") - 1) \
		/ maxf(float(Balance.PROFESSION_MAX_LEVEL - 1), 1.0)
	return clampf(Balance.FORGE_GEM_RARITY_CHANCE[clampi(gem.rarity, 0,
		Balance.FORGE_GEM_RARITY_CHANCE.size() - 1)]
		+ share * Balance.FORGE_SKILL_RARITY_CHANCE, 0.0, 0.95)


# --- The commission ----------------------------------------------------------
#
# Owner brief, 2026-09-17: *"if players are lacking resources necessary to make
# an item they could speak to the blacksmith and ask him to make it for them so
# they don't have to smith it themselves, however there should be an appropriate
# cost that is more expensive than players smithing it themselves ... and even
# then there should be more to it than just having enough gold for it but doing
# so should be a bit more demanding as well."*
#
# **He supplies the stock; the Warden supplies the gem.** Wood and ore are what
# somebody who has not been out to the seams is short of, and they are what a
# blacksmith has. The gem is the rare thing that decides the rarity, and a gem
# bought with Marks would be the failure `exchange_check` exists to prevent on
# the other side of the economy.
#
# **And the demanding half is not the fee.** A commission teaches the Warden
# nothing - no Smith experience is paid - and it comes off Orden's ordinary
# stock, so the piece is the level ordinary timber makes. Marks cannot buy
# practice and cannot buy good stock; they buy a piece today.


## What Orden asks in Marks. Scaled by what he is being asked to make, so
## commissioning a great piece costs like a great piece.
static func commission_fee(gem_id: String) -> int:
	var gem: MaterialData = ContentDB.material(gem_id)
	if gem == null:
		return 0
	var reach: int = clampi(Balance.FORGE_BASE_RARITY + gem.rarity + 1, 0,
		Stash.RARITY_MARKS.size() - 1)
	return maxi(int(round(float(Stash.RARITY_MARKS[reach])
		* Balance.COMMISSION_MARK_MULTIPLE)), 1)


## Everything that can refuse a commission, in one place, so the screen and the
## gate ask the same question. Returns "" when Orden would take the work.
static func commission_refusal(gem_id: String) -> String:
	var gem: MaterialData = ContentDB.material(gem_id)
	if gem == null or gem.kind != MaterialData.Kind.GEM:
		return "Orden wants a gem to set. He has stock; he has no stones."
	if MetaState.material_count(gem_id) < Balance.FORGE_GEM_COST:
		return "No %s to give him." % gem.display_name
	if MetaState.profession_level("smith") < Balance.COMMISSION_SMITH_LEVEL:
		return ("Orden works for smiths. Strike something yourself first - a "
			+ "Smith of %d will do." % Balance.COMMISSION_SMITH_LEVEL)
	var fee: int = commission_fee(gem_id)
	if MetaState.marks < fee:
		return "Orden asks %d Marks. You have %d." % [fee, MetaState.marks]
	if MetaState.stash.size() >= Balance.STASH_CAPACITY:
		return "The stash is full. Nothing may be forged into nowhere."
	return ""


## The stock Orden works from: the commonest wood and the commonest ore the
## world has. Read off the content rather than named here, so a region added
## later cannot leave him working from something that does not exist.
static func commission_stock() -> Array[String]:
	var wood: String = ""
	var ore: String = ""
	var wood_rarity: int = 99
	var ore_rarity: int = 99
	for kind: MaterialData in ContentDB.materials_sorted():
		if kind.kind == MaterialData.Kind.WOOD and kind.rarity < wood_rarity:
			wood_rarity = kind.rarity
			wood = kind.id
		elif kind.kind == MaterialData.Kind.ORE and kind.rarity < ore_rarity:
			ore_rarity = kind.rarity
			ore = kind.id
	return [wood, ore]


## Asks Orden to make it. Returns the piece, or a dictionary carrying `error`.
##
## **Validate, then spend, then make**, the order `forge` commits in and for the
## same reason: the gem is the scarce half of the price, and a commission that
## ate one on a race nobody can reproduce is worse than one that refuses.
static func commission(gem_id: String) -> Dictionary:
	var refused: String = commission_refusal(gem_id)
	if not refused.is_empty():
		return {"error": refused}
	var stock: Array[String] = commission_stock()
	if stock[0].is_empty() or stock[1].is_empty():
		return {"error": "Orden's stock is empty."}
	var fee: int = commission_fee(gem_id)
	if not MetaState.spend_material(gem_id, Balance.FORGE_GEM_COST):
		return {"error": "The gem was gone."}
	if MetaState.marks < fee:
		MetaState.gain_material(gem_id, Balance.FORGE_GEM_COST)
		return {"error": "The Marks were gone."}
	MetaState.marks -= fee
	# His hands, his stock, and **no experience for the Warden**: a commission
	# is a piece bought rather than a piece learnt.
	var piece: Dictionary = _strike(stock[0], stock[1], gem_id,
		Balance.COMMISSION_SMITH_SKILL)
	if not MetaState.take_gear(piece):
		MetaState.gain_material(gem_id, Balance.FORGE_GEM_COST)
		MetaState.marks += fee
		return {"error": "The stash is full."}
	MetaState.save_game()
	return piece
