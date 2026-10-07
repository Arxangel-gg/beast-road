class_name Mercenaries
extends RefCounted

## **Mercenaries** (owner, 2026-10-07): the Wardens met in the Hold may be hired
## and taken on the road. The design is `docs/MERCENARIES_2026-10-07.md`; this
## is the record and its arithmetic - who a stranger is when hired, what it
## costs, and the sheet it fights as.
##
## **A record, never a resource**: procedural, rolled from the stranger it was
## hired from, so the mercenary that walks out of the Hold is the Warden who
## stood in it - the same look and the same worn kinds `HoldYard.stranger_of`
## dressed them in. **No stronger for being kept**: nothing here grows a level
## or a piece after the hire. Every rule that changes the roster lives on
## `MetaState`; this file only works things out.

const STATE_READY: String = "ready"
const STATE_RESTING: String = "resting"


## The Warden a stranger in the Hold would be if hired, by the Warden hiring.
## The same stranger rolled twice is the same Warden - their name in the yard
## is the seed.
static func offer(who: String, display: String, warden_level: int, tier: CampaignTierData) -> Dictionary:
	var dice := RandomNumberGenerator.new()
	dice.seed = absi(hash("mercenary:" + who))
	var ceiling: int = clampi(warden_level, 1, Balance.HERO_MAX_LEVEL)
	var level: int = clampi(ceiling - dice.randi_range(0, Balance.MERC_LEVEL_SPREAD), 1, ceiling)
	var stranger: Dictionary = HoldYard.stranger_of(who)
	var kinds: Array = stranger.get("gear", [])
	# Gear from the tier this Warden walks, scaled by how far up that tier's own
	# levels the mercenary stands.
	var rarities: Vector2i = tier.expected_gear_rarity if tier != null else Vector2i(0, 2)
	var levels: Vector2i = tier.expected_gear_level if tier != null else Vector2i(1, 2)
	var along: float = clampf(float(level) / float(maxi(ceiling, 1)), 0.0, 1.0)
	var gear: Array = []
	for index: int in kinds.size():
		var kind_id: String = String(kinds[index])
		if kind_id.is_empty() or ContentDB.gear(kind_id) == null:
			continue
		var rarity: int = clampi(int(round(lerpf(rarities.x, rarities.y, along))) + dice.randi_range(-1, 1),
			0, Stash.RARITY_NAMES.size() - 2)
		var piece_level: int = clampi(int(round(lerpf(levels.x, levels.y, along))), 1, Stash.MAX_LEVEL)
		var piece: Dictionary = Stash.make(kind_id, rarity, piece_level)
		piece["uid"] = absi(hash("%s:gear:%d" % [who, index]))
		gear.append(piece)
	return {
		"uid": "merc-%d" % absi(hash("mercenary-uid:" + who)),
		"who": who,
		"name": display if not display.is_empty() else "A Warden",
		"look": WardenLook.pack(stranger.get("look", WardenLook.plain()) as Dictionary),
		"level": level,
		"attributes": split_points(level - 1),
		"gear": gear,
		"state": STATE_READY,
		"rest_until": 0.0,
		"bill": 0,
		"taking": false,
	}


## A level's points placed as the curve places a Warden's: mostly Might, then
## Vigour and Resolve. The same share `curve_report` dresses its expected
## Warden in, so a mercenary is exactly as strong as the model assumes.
static func split_points(total: int) -> Array[int]:
	var placed: Array[int] = [0, 0, 0, 0, 0]
	var given: int = 0
	for index: int in placed.size():
		var share: float = Balance.EXPECTED_ATTRIBUTE_SHARE[index] if index < Balance.EXPECTED_ATTRIBUTE_SHARE.size() else 0.0
		placed[index] = int(floor(float(total) * share))
		given += placed[index]
	placed[0] += maxi(total - given, 0)
	return placed


## What its gear is worth, in attribute points - what the fee charges for.
static func gear_points(row: Dictionary) -> int:
	var total: int = 0
	for value: Variant in (row.get("gear", []) as Array):
		var piece := value as Dictionary
		if piece == null:
			continue
		var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
		if kind != null:
			total += Stash.points(piece, kind)
	return total


## **The fee**, once, in Marks: a base, the level, and what it wears.
static func fee(row: Dictionary) -> int:
	return Balance.MERC_FEE_BASE + Balance.MERC_FEE_PER_LEVEL * int(row.get("level", 1)) \
		+ Balance.MERC_FEE_PER_GEAR_POINT * gear_points(row)


## **The contract**, every road it joins: a share of its fee.
static func contract(row: Dictionary) -> int:
	return maxi(1, int(ceil(float(fee(row)) * Balance.MERC_CONTRACT_SHARE)))


## **The bill** owed after its third wound.
static func bill(row: Dictionary) -> int:
	return Balance.MERC_BILL_BASE + Balance.MERC_BILL_PER_LEVEL * int(row.get("level", 1))


## Seconds of rest left on the wall clock, never below nothing.
static func rest_left(row: Dictionary, now: float) -> float:
	return maxf(0.0, float(row.get("rest_until", 0.0)) - now)


## Whether it may take the road: on its feet, its bill paid and its rest over.
static func is_ready(row: Dictionary, now: float) -> bool:
	if String(row.get("state", STATE_READY)) == STATE_READY:
		return true
	return int(row.get("bill", 0)) <= 0 and rest_left(row, now) <= 0.0


## The sheet it fights as: a partner's row (`WardenSheet.from_row`) with its
## level, its placed points and its pieces, no tree and no ascension.
static func sheet_row(row: Dictionary) -> Array:
	var pieces: Array = []
	for value: Variant in (row.get("gear", []) as Array):
		var piece := value as Dictionary
		if piece == null:
			continue
		pieces.append({
			"kind": String(piece.get("kind", "")),
			"rarity": int(piece.get("rarity", 0)),
			"level": int(piece.get("level", 1)),
			"uid": int(piece.get("uid", 0)),
			"gems": [],
			"quality": Stash.quality(piece),
			"dur_band": 0,
		})
	return [int(row.get("level", 1)), (row.get("attributes", [0, 0, 0, 0, 0]) as Array).duplicate(),
		0, "", [], ["", "", "", ""], pieces, 1]


## The five kinds it is dressed in, in `Hero.DRESS_SLOTS` order.
static func worn_kinds(row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for slot: int in Hero.DRESS_SLOTS:
		var found: String = ""
		for value: Variant in (row.get("gear", []) as Array):
			var piece := value as Dictionary
			if piece == null:
				continue
			var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
			if kind != null and kind.slot == slot:
				found = kind.id
				break
		out.append(found)
	return out


## A row read off a save, cleaned: a row the game could not have produced is
## refused (an empty dictionary) rather than trusted, the pen's rule.
static func clean(stored: Variant) -> Dictionary:
	var row := stored as Dictionary
	if row == null:
		return {}
	var uid: String = String(row.get("uid", ""))
	var who: String = String(row.get("who", ""))
	if uid.is_empty() or who.is_empty():
		return {}
	var level: int = clampi(int(row.get("level", 1)), 1, Balance.HERO_MAX_LEVEL)
	var placed: Array[int] = []
	var budget: int = level - 1
	for value: Variant in (row.get("attributes", []) as Array):
		var points: int = clampi(int(value), 0, budget)
		budget -= points
		placed.append(points)
	while placed.size() < 5:
		placed.append(0)
	placed.resize(5)
	var gear: Array = []
	for value: Variant in (row.get("gear", []) as Array):
		var piece := value as Dictionary
		if piece == null or ContentDB.gear(String(piece.get("kind", ""))) == null:
			continue
		var clean_piece: Dictionary = Stash.make(String(piece["kind"]),
			clampi(int(piece.get("rarity", 0)), 0, Stash.RARITY_NAMES.size() - 1),
			clampi(int(piece.get("level", 1)), 1, Stash.MAX_LEVEL))
		clean_piece["uid"] = int(piece.get("uid", 0))
		gear.append(clean_piece)
	var state: String = String(row.get("state", STATE_READY))
	if state != STATE_READY and state != STATE_RESTING:
		state = STATE_READY
	return {
		"uid": uid,
		"who": who,
		"name": String(row.get("name", "A Warden")).left(Balance.MERC_NAME_MAX),
		"look": row.get("look", []) if row.get("look", []) is Array else [],
		"level": level,
		"attributes": placed,
		"gear": gear,
		"state": state,
		"rest_until": maxf(0.0, float(row.get("rest_until", 0.0))),
		"bill": clampi(int(row.get("bill", 0)), 0, 1000000),
		"taking": bool(row.get("taking", false)),
	}
