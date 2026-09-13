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
static func _strike(wood_id: String, ore_id: String, gem_id: String) -> Dictionary:
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
	var share: float = float(MetaState.profession_level("smith") - 1) \
		/ maxf(float(Balance.PROFESSION_MAX_LEVEL - 1), 1.0)
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
