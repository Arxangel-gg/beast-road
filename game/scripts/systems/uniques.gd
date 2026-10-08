class_name Uniques
extends RefCounted

## **The uniques** (docs/UNIQUES_DESIGN_2026-10-07.md): eleven trophy pieces,
## one an act boss, each a rule of the Warden's fight re-routed - when an effect
## fires or what it fires on, never how hard. Paid once a road by the boss's
## first fall there, laid at the Warden's feet on the machine whose account
## earned it, and now and then again by a later fall.
##
## Every rule is a `Modifiers.UNIQUE_*` flag the worn piece puts in the table and
## one door reads, through `WardenSheet.value_of`, so a partner's unique works
## on the host's copy of the partner.


## Every unique kind, by its act.
static func all() -> Array[GearData]:
	var out: Array[GearData] = []
	for value: Variant in ContentDB.gear_kinds.values():
		var kind := value as GearData
		if kind != null and kind.is_unique():
			out.append(kind)
	out.sort_custom(func(a: GearData, b: GearData) -> bool: return a.unique_act < b.unique_act)
	return out


## The unique an act's boss pays, or null.
static func kind_for_act(act: int) -> GearData:
	for kind: GearData in all():
		if kind.unique_act == act:
			return kind
	return null


## The piece a boss pays on a road: the act's unique at the road's trophy rarity
## - Oathbound on the Long Road, a rung higher each road after - and made well,
## as the Gatekeeper's Mantle is. Empty for an act with none.
static func piece_for(act: int, tier_id: String) -> Dictionary:
	var kind: GearData = kind_for_act(act)
	if kind == null:
		return {}
	var tier: CampaignTierData = ContentDB.tiers.get(tier_id, null) as CampaignTierData
	var order: int = tier.order if tier != null else 0
	var rarity: int = clampi(Stash.RARITY_NAMES.find("Oathbound") + order, 0, Stash.RARITY_NAMES.size() - 1)
	var piece: Dictionary = Stash.make(kind.id, rarity)
	piece["quality"] = Stash.QUALITY_NAMES.size() - 1
	return piece


## Whether a Warden - null for this machine's own - wears the rule.
static func worn(sheet: WardenSheet, key: String) -> bool:
	return WardenSheet.value_of(sheet, key) > 0.0


## What a perfect evade's empowerment is worth, authored on No Ground Given -
## the share Gearwright's Charm lends a finisher when a tower falls.
static func guard_share() -> float:
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.effect_id == "block_finisher":
			return node.effect_value
	return 0.0
