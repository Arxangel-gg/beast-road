class_name ProceduralWarden
extends RefCounted

## **A Warden as the road would have made them** (owner, 2026-10-07: "a random
## procedural appearance look and colors for the player as well as randomized
## procedural equipped gear that is harmonious with the expectation for each
## phase of the player's progression where the image would have naturally been
## taken in a player's leveling journey").
##
## The Guide's photographs and the trailer at launch both stand a Warden who is
## nobody in particular and exactly where the journey would have them: a new
## Warden on the Long Road in linen and a knife, bareheaded, in the colours of
## the road; a Warden at the top of the Chainmaker's Road in plate under a great
## helm and a long cape, a maul in their hands that gleams. Between the two every
## slot climbs at its own pace, as gear is found a piece at a time.
##
## **What a roll is**: a look (`WardenLook`), a piece for every slot it wears
## (`Stash.make`, at the rarity and level the tier expects for that act, as
## `curve_report` dresses its expected Warden), the level the tier's own bosses
## expect, and the five attributes placed toward one of a few builds. Nothing in
## a roll is new to the game: every kind is one that drops, every rarity is one
## the tier pays, and a trophy is worn only by somebody who would have won it.
##
## **Wearing one writes the account**, so it is done only while saves are held
## (`MetaState.hold_saves`), which is what the Guide tool and the trailer both
## stand under. A roll is decided entirely by its key, so the same key is the
## same Warden on every machine and every run of the tool.

## How far through a whole career a stage of the journey sits, 0 a new Warden
## and 1 the summit of the hardest road: the Long Road is the first third, the
## Iron Road the second, the Chainmaker's Road the last.
static func journey_share(tier_order: int, act: int) -> float:
	var roads: int = maxi(ContentDB.tiers.size(), 1)
	var within: float = clampf(float(act - 1) / float(maxi(Balance.ACT_COUNT, 1)), 0.0, 1.0)
	return clampf((float(tier_order) + within) / float(roads), 0.0, 1.0)


## When each kind of thing tends to be worn, as a share of the career: what a
## class of weapon, armour, cape or helm looks like early and late. A Warden
## picks near where they stand and now and then far from it - a veteran who
## never gave up a knife is a person, not an error.
const _WEAPON_STAGE: Dictionary = {"knife": 0.04, "short": 0.1, "club": 0.16,
	"sword": 0.3, "axe": 0.42, "long": 0.55, "polearm": 0.64, "maul": 0.8}
const _ARMOUR_STAGE: Dictionary = {"light": 0.08, "medium": 0.45, "heavy": 0.8}
const _CAPE_STAGE: Dictionary = {"half": 0.22, "pelt": 0.4, "long": 0.66}
const _HELM_STAGE: Dictionary = {"hood": 0.08, "circlet": 0.38, "open_helm": 0.5, "great_helm": 0.82}
## How tightly a stage is kept to: a wider spread is more surprise.
const _STAGE_SPREAD: float = 0.24

## The cloth colours as a hue wheel, crimson round to plum and back (indices
## into `WardenLook.CLOTH_COLOURS`), and the neutrals beside them.
const _WHEEL: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const _NEUTRALS: Array[int] = [0, 11, 12, 13]
## The road's own colours, which a new Warden mostly wears, and the ones that
## cost something to dye, which a Warden far along can afford.
const _HUMBLE: Array[int] = [2, 3, 4, 5, 13, 0]
const _NOBLE: Array[int] = [1, 6, 7, 8, 9, 10]
## How often each hair colour is met, most common first-ish. Grey and white
## are commoner the further a Warden has walked.
const _HAIR_WEIGHTS: Array[float] = [22.0, 18.0, 18.0, 10.0, 7.0, 5.0, 8.0, 5.0, 2.0, 1.0]
## The builds attributes lean toward: Might, Vigour, Swiftness, Focus, Resolve.
const _BUILDS: Array = [
	[0.55, 0.2, 0.05, 0.05, 0.15],  # the sword
	[0.35, 0.3, 0.05, 0.05, 0.25],  # the wall
	[0.35, 0.15, 0.35, 0.05, 0.1],  # the quick
	[0.2, 0.15, 0.05, 0.5, 0.1],    # the caster
]

## The pieces the last `wear` put in the stash, taken back out by the next one,
## so a tool that dresses a Warden a picture never fills the stash.
static var _laid: Array[int] = []


## A stage of the journey from a share of the career: the road and the act.
static func stage_at(share: float) -> Dictionary:
	var tiers: Array[CampaignTierData] = ContentDB.tiers_sorted()
	if tiers.is_empty():
		return {"tier": "", "act": 1}
	var place: float = clampf(share, 0.0, 0.9999) * float(tiers.size())
	var road: int = clampi(int(floor(place)), 0, tiers.size() - 1)
	var act: int = clampi(1 + int(round((place - float(road)) * float(Balance.ACT_COUNT))), 1,
		Balance.FINAL_ASCENT_ACT)
	return {"tier": tiers[road].id, "act": act}


## A Warden at this stage of the journey, decided by `key`.
static func roll(key: String, tier_id: String, act: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("procedural-warden:" + key))
	var tier: CampaignTierData = ContentDB.tier(tier_id)
	if tier == null:
		var sorted: Array[CampaignTierData] = ContentDB.tiers_sorted()
		tier = sorted[0] if not sorted.is_empty() else null
	var order: int = tier.order if tier != null else 0
	var share: float = journey_share(order, act)
	var look: Dictionary = _roll_look(rng, share)
	var level: int = tier.expected_level(mini(act, Balance.ACT_COUNT)) if tier != null else 1
	return {
		"key": key,
		"tier": tier.id if tier != null else tier_id,
		"act": act,
		"share": share,
		"look": look,
		"pieces": _roll_pieces(rng, key, tier, act, share),
		"level": level,
		"attributes": _roll_attributes(rng, level),
	}


## A roll at a share of the career rather than a named stage.
static func roll_at(key: String, share: float) -> Dictionary:
	var stage: Dictionary = stage_at(share)
	return roll(key, String(stage["tier"]), int(stage["act"]))


# --- The look ---------------------------------------------------------------

static func _roll_look(rng: RandomNumberGenerator, share: float) -> Dictionary:
	var look: Dictionary = WardenLook.plain()
	var bodies: Array[int] = []
	for body: int in WardenDress.BODIES.size():
		if WardenDress.available(WardenDress.BODIES[body]):
			bodies.append(body)
	var body: int = bodies[rng.randi_range(0, bodies.size() - 1)] if not bodies.is_empty() else 0
	look[WardenLook.KEY_BODY] = body
	var styles: int = int(WardenLook.CHOICES[WardenLook.KEY_HAIR])
	var bald: float = 0.04 if body == 1 else 0.1
	look[WardenLook.KEY_HAIR] = 0 if rng.randf() < bald else rng.randi_range(1, styles - 1)
	var hair: Array[float] = _HAIR_WEIGHTS.duplicate()
	hair[8] += share * 8.0
	hair[9] += share * 5.0
	look[WardenLook.KEY_HAIR_COLOUR] = _weighted(rng, hair)
	var beards: int = int(WardenLook.CHOICES[WardenLook.KEY_BEARD])
	look[WardenLook.KEY_BEARD] = 0 if body == 1 or rng.randf() < 0.42 else rng.randi_range(1, beards - 1)
	look[WardenLook.KEY_SKIN] = rng.randi_range(0, int(WardenLook.CHOICES[WardenLook.KEY_SKIN]) - 1)
	var cloth: Array[int] = _roll_cloth(rng, share)
	look[WardenLook.KEY_CAPE_COLOUR] = cloth[0]
	look[WardenLook.KEY_TOP_COLOUR] = cloth[1]
	look[WardenLook.KEY_BOTTOM_COLOUR] = cloth[2]
	look[WardenLook.KEY_LEATHER] = rng.randf_range(-0.3, 0.3)
	return WardenLook.clean(look)


## The cape, the top and the trousers as one scheme, never three dice: an
## accent on the cape, and the top in a neighbour of it, the accent itself or a
## neutral, over neutral trousers. A new Warden wears the road's own colours;
## the further along, the more often the dear ones.
static func _roll_cloth(rng: RandomNumberGenerator, share: float) -> Array[int]:
	if rng.randf() < lerpf(0.3, 0.06, share):
		return [0, _pick(rng, _NEUTRALS), 0]
	var accent: int = _pick(rng, _NOBLE) if rng.randf() < lerpf(0.2, 0.75, share) else _pick(rng, _HUMBLE)
	var top: int = accent
	var scheme: float = rng.randf()
	if accent > 0 and _WHEEL.has(accent) and scheme < 0.4:
		var at: int = _WHEEL.find(accent)
		top = _WHEEL[posmod(at + (1 if rng.randf() < 0.5 else -1), _WHEEL.size())]
	elif scheme < 0.75:
		top = _pick(rng, _NEUTRALS)
	var bottom: int = _pick(rng, [0, 11, 13, 11]) if top != 11 else _pick(rng, [0, 13, 12])
	return [accent, top, bottom]


# --- The gear ---------------------------------------------------------------

static func _roll_pieces(rng: RandomNumberGenerator, key: String, tier: CampaignTierData,
		act: int, share: float) -> Dictionary:
	var pieces: Dictionary = {}
	var along: float = clampf(float(act - 1) / float(maxi(Balance.ACT_COUNT - 1, 1)), 0.0, 1.0)
	var weapon: GearData = _by_stage(rng, GearData.Slot.WEAPON, _WEAPON_STAGE, share)
	for slot: int in GearData.Slot.size():
		var kind: GearData = null
		match slot:
			GearData.Slot.WEAPON:
				kind = weapon
			GearData.Slot.ARMOUR:
				if rng.randf() >= lerpf(0.3, 0.0, clampf(share * 4.0, 0.0, 1.0)):
					kind = _by_stage(rng, slot, _ARMOUR_STAGE, share)
			GearData.Slot.CAPE:
				if rng.randf() >= lerpf(0.65, 0.18, share):
					kind = _mantle_for(rng, tier)
					if kind == null:
						kind = _by_stage(rng, slot, _CAPE_STAGE, share)
			GearData.Slot.HELMET:
				if rng.randf() >= lerpf(0.65, 0.3, share):
					kind = _by_stage(rng, slot, _HELM_STAGE, share)
			GearData.Slot.OFFHAND:
				var free_hand: bool = weapon == null or weapon.grip == GearData.Grip.ONE_HAND
				if free_hand and rng.randf() < lerpf(0.1, 0.45, share):
					kind = _any(rng, slot)
			_:
				if rng.randf() < lerpf(0.45, 0.95, share):
					kind = _any(rng, slot)
		if kind == null:
			continue
		pieces[slot] = _make(rng, key, slot, kind, tier, along)
	return pieces


## A piece at the rarity and level the tier expects at this point of its road,
## a rung either way now and then - a slot at a time, as `curve_report` dresses
## its expected Warden - and the weapon a little more often a rung up, because
## it is the piece a Warden spends on first.
static func _make(rng: RandomNumberGenerator, key: String, slot: int, kind: GearData,
		tier: CampaignTierData, along: float) -> Dictionary:
	var top: int = Stash.RARITY_NAMES.size() - 1
	var rarity_now: float = 0.0
	var level_now: float = 1.0
	if tier != null:
		rarity_now = lerpf(float(tier.expected_gear_rarity.x), float(tier.expected_gear_rarity.y), along)
		level_now = lerpf(float(tier.expected_gear_level.x), float(tier.expected_gear_level.y), along)
	var nudge: float = rng.randf()
	var step: int = -1 if nudge < 0.22 else (1 if nudge > (0.62 if slot == GearData.Slot.WEAPON else 0.78) else 0)
	var rarity: int = clampi(int(round(rarity_now)) + step, 0, top)
	if kind.trophy:
		rarity = clampi(maxi(rarity, int(round(rarity_now)) + 1), 0, top)
	var level: int = clampi(int(round(level_now)) + rng.randi_range(-1, 1), 1, Stash.MAX_LEVEL)
	var piece: Dictionary = Stash.make(kind.id, rarity, level)
	# A name of its own, from the key: the bonuses a piece rolls are read off its
	# name, so the same Warden wears the same pieces with the same affixes.
	piece["uid"] = (absi(hash("procedural-piece:%s:%d" % [key, slot])) & 0x7FFFFFFF) << 8 | slot
	return piece


## A kind for a slot whose classes have stages, nearest the share most often.
static func _by_stage(rng: RandomNumberGenerator, slot: int, stages: Dictionary, share: float) -> GearData:
	var kinds: Array[GearData] = _wearable(slot)
	if kinds.is_empty():
		return null
	var weights: Array[float] = []
	for kind: GearData in kinds:
		var stage: float = float(stages.get(kind.look, 0.5))
		var gap: float = (stage - share) / _STAGE_SPREAD
		weights.append(exp(-gap * gap) + 0.03)
	return kinds[_weighted(rng, weights)]


static func _any(rng: RandomNumberGenerator, slot: int) -> GearData:
	var kinds: Array[GearData] = _wearable(slot)
	return kinds[rng.randi_range(0, kinds.size() - 1)] if not kinds.is_empty() else null


## The Gatekeeper's Mantle of the road before this one, now and then, on a
## Warden who has walked past it - a trophy worn only where it could have been
## won.
static func _mantle_for(rng: RandomNumberGenerator, tier: CampaignTierData) -> GearData:
	if tier == null or tier.order <= 0 or rng.randf() >= 0.3:
		return null
	for other: CampaignTierData in ContentDB.tiers_sorted():
		if other.order == tier.order - 1:
			var mantle: GearData = ContentDB.gear("gatekeepers_mantle_" + other.id)
			return mantle if mantle != null and mantle.trophy else null
	return null


static var _wearable_cache: Dictionary = {}


## What may be worn in a slot: anything that drops but a trophy, and a weapon
## only with a held picture, since one without is a fist round nothing.
static func _wearable(slot: int) -> Array[GearData]:
	if _wearable_cache.has(slot):
		return _wearable_cache[slot]
	var out: Array[GearData] = []
	for kind: GearData in ContentDB.gear_sorted():
		if kind == null or kind.slot != slot or kind.trophy:
			continue
		if slot == GearData.Slot.WEAPON and WardenDress.held_path(kind).is_empty():
			continue
		out.append(kind)
	if not out.is_empty():
		_wearable_cache[slot] = out
	return out


# --- The Warden -------------------------------------------------------------

## The level's points placed toward one of a few builds, the rest to Might.
static func _roll_attributes(rng: RandomNumberGenerator, level: int) -> Array[int]:
	var build: Array = _BUILDS[rng.randi_range(0, _BUILDS.size() - 1)]
	var points: int = maxi(level - 1, 0)
	var placed: Array[int] = []
	var given: int = 0
	for share: Variant in build:
		var each: int = int(floor(float(points) * float(share)))
		placed.append(each)
		given += each
	while placed.size() < RunState.ATTRIBUTE_NAMES.size():
		placed.append(0)
	placed[0] += points - given
	return placed


## **Puts a rolled Warden on** - the look, the pieces worn, the level and the
## points - and re-dresses every Warden of this machine standing under `root`.
## Only while saves are held: this writes the account, and the callers are a
## tool and the trailer, both of which put the account back.
static func wear(rolled: Dictionary, root: Node = null) -> bool:
	if not MetaState.saves_held():
		return false
	for index: int in range(MetaState.stash.size() - 1, -1, -1):
		var piece := MetaState.stash[index] as Dictionary
		if piece != null and _laid.has(int(piece.get("uid", 0))):
			MetaState.stash.remove_at(index)
	_laid.clear()
	MetaState.equipped.clear()
	var pieces: Dictionary = rolled.get("pieces", {}) as Dictionary
	for slot: Variant in pieces:
		var piece: Dictionary = (pieces[slot] as Dictionary).duplicate(true)
		if MetaState.stash.size() >= Balance.STASH_CAPACITY:
			MetaState.stash.remove_at(0)
		MetaState.stash.append(piece)
		_laid.append(int(piece["uid"]))
		MetaState.equipped[int(slot)] = int(piece["uid"])
	MetaState.look = WardenLook.clean(rolled.get("look", {}))
	var level: int = int(rolled.get("level", MetaState.hero_level))
	MetaState.hero_level = level
	RunState.hero_level = level
	var placed: Array[int] = []
	for value: Variant in rolled.get("attributes", []) as Array:
		placed.append(int(value))
	if placed.size() == RunState.ATTRIBUTE_NAMES.size():
		MetaState.hero_attributes = placed
		RunState.hero_attributes = placed.duplicate()
	Modifiers.rebuild()
	EventBus.stash_changed.emit()
	if root != null:
		for node: Node in root.get_tree().get_nodes_in_group(Hero.GROUP_ANY):
			var hero := node as Hero
			if hero != null and hero.is_local_player() and root.is_ancestor_of(hero):
				hero.redress()
	return true


## Forgets the pieces the last `wear` laid, for a caller that has put the
## account back itself (the trailer reads it back from the disk).
static func forget() -> void:
	_laid.clear()


## The rolled Warden as a partner row would carry them: the look packed and the
## worn kinds in `Hero.DRESS_SLOTS` order - for drawing a Warden that is not
## this machine's (a second figure in a trailer shot) without wearing it.
static func as_partner(rolled: Dictionary) -> Dictionary:
	var kinds: Array[String] = []
	var pieces: Dictionary = rolled.get("pieces", {}) as Dictionary
	for slot: int in Hero.DRESS_SLOTS:
		var piece: Dictionary = pieces.get(slot, {}) as Dictionary
		kinds.append(String(piece.get("kind", "")))
	return {"look": WardenLook.clean(rolled.get("look", {})), "gear": kinds}


static func _weighted(rng: RandomNumberGenerator, weights: Array) -> int:
	var total: float = 0.0
	for weight: Variant in weights:
		total += maxf(float(weight), 0.0)
	var pick: float = rng.randf() * total
	for index: int in weights.size():
		pick -= maxf(float(weights[index]), 0.0)
		if pick <= 0.0:
			return index
	return weights.size() - 1


static func _pick(rng: RandomNumberGenerator, from: Array) -> int:
	return int(from[rng.randi_range(0, from.size() - 1)])
