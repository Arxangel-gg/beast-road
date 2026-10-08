class_name WildlifeLevels
extends RefCounted

## **Levels for the animals of the road and the companions at the Warden's side**
## (owner, 2026-10-08: "Wildlife should have levels and be able to level up from
## xp earned ... Peaceful wildlife should level slower naturally, and predatory
## wildlife should level faster earned from the damage they inflict and from
## kills they get as well as assists on any targets. Leveling up causes wildlife
## to grow bigger. Their levels are also hidden until they are hurt ... Companion
## spirits should also be able to level up from their earned XP to a lesser cap,
## while alive wildlife companions are able to reach a higher max level cap ...
## Each rarity for any unlocked spirit companions get their own level.")
##
## The rules only - the curve, the scales and the arrival level. What earns an
## animal experience is `Wildlife`'s to notice; what earns a companion some is
## `Companion`'s; where a companion's experience is kept is `MetaState`'s.
##
## **A wild animal's level is the road's and never persists.** A companion's is
## the account's, by spirit species and rarity or by the raised creature itself.


## Experience from `level` to the one after it.
static func xp_to_next(level: int, base: float = Balance.WILDLIFE_LEVEL_XP_BASE,
		curve: float = Balance.WILDLIFE_LEVEL_XP_CURVE) -> float:
	return base * pow(float(maxi(level, 1)), curve)


## The level a total of `xp` reaches, never past `cap`.
static func level_for_xp(xp: float, cap: int, base: float = Balance.WILDLIFE_LEVEL_XP_BASE,
		curve: float = Balance.WILDLIFE_LEVEL_XP_CURVE) -> int:
	var level: int = 1
	var spent: float = 0.0
	while level < cap:
		var step: float = xp_to_next(level, base, curve)
		# A hair of tolerance: experience kept at a threshold comes back through
		# the save's JSON a rounding under it, and must not lose the level.
		if xp + 0.001 < spent + step:
			break
		spent += step
		level += 1
	return level


## The total experience a level begins at.
static func xp_at(level: int, base: float = Balance.WILDLIFE_LEVEL_XP_BASE,
		curve: float = Balance.WILDLIFE_LEVEL_XP_CURVE) -> float:
	var total: float = 0.0
	for step: int in range(1, maxi(level, 1)):
		total += xp_to_next(step, base, curve)
	return total


## How much bigger a level grows an animal: growing is what a level looks like.
static func size_scale(level: int) -> float:
	return 1.0 + Balance.WILDLIFE_LEVEL_GROWTH * float(clampi(level, 1, Balance.WILDLIFE_LEVEL_MAX) - 1)


## How much deeper a level makes its pool.
static func health_scale(level: int) -> float:
	return 1.0 + Balance.WILDLIFE_LEVEL_HEALTH * float(clampi(level, 1, Balance.WILDLIFE_LEVEL_MAX) - 1)


## How much more a level's kill pays in Food and experience.
static func yield_scale(level: int) -> float:
	return 1.0 + Balance.WILDLIFE_LEVEL_YIELD * float(clampi(level, 1, Balance.WILDLIFE_LEVEL_MAX) - 1)


## **The level an animal arrives at**: one in the opening act, and up to one
## more for every `WILDLIFE_LEVEL_ARRIVAL_ACTS` acts after it. Read off the
## animal's own name and the run's seed rather than a die, so no roll the
## arrivals are drawn on moves and a guest told the same name arrives the same.
static func arrival_level(net_id: int, act: int) -> int:
	var most: int = 1 + maxi(act - 1, 0) / maxi(Balance.WILDLIFE_LEVEL_ARRIVAL_ACTS, 1)
	most = mini(most, Balance.WILDLIFE_LEVEL_MAX)
	if most <= 1:
		return 1
	return 1 + absi(hash("wild-level:%d:%d" % [RunState.run_seed, net_id])) % most


## Whether an animal learns by fighting rather than by living: the ones that
## fight rather than flee.
static func is_predatory(kind: WildlifeData) -> bool:
	return kind != null and kind.is_hostile()


## Experience for being alive a while: slow for the peaceful, slower still for a
## hunter, which learns by its teeth.
static func time_rate(kind: WildlifeData) -> float:
	return Balance.WILDLIFE_LEVEL_TIME_XP_PREDATOR if is_predatory(kind) \
		else Balance.WILDLIFE_LEVEL_TIME_XP_PEACEFUL


# --- Companions ------------------------------------------------------------------


## The highest a companion may reach: a spirit lower, a raised creature higher,
## because it is still mortal.
static func companion_cap(from_pen: bool) -> int:
	return Balance.COMPANION_LEVEL_MAX_PEN if from_pen else Balance.COMPANION_LEVEL_MAX_SPIRIT


static func companion_level(xp: float, from_pen: bool) -> int:
	return level_for_xp(xp, companion_cap(from_pen), Balance.COMPANION_LEVEL_XP_BASE,
		Balance.COMPANION_LEVEL_XP_CURVE)


static func companion_xp_at(level: int) -> float:
	return xp_at(level, Balance.COMPANION_LEVEL_XP_BASE, Balance.COMPANION_LEVEL_XP_CURVE)


## A companion's blow at a level, as a multiple of level one.
static func companion_power(level: int) -> float:
	return 1.0 + Balance.COMPANION_LEVEL_POWER * float(clampi(level, 1, Balance.COMPANION_LEVEL_MAX_PEN) - 1)


## A companion's pool at a level, as a multiple of level one.
static func companion_health(level: int) -> float:
	return 1.0 + Balance.COMPANION_LEVEL_HEALTH * float(clampi(level, 1, Balance.COMPANION_LEVEL_MAX_PEN) - 1)


## **Each rarity of a spirit has its own level** (owner, 2026-10-08): keyed by
## species and rarity, so a shiny and a plain spirit of one rarity share one,
## and a Rare wolf and a Common wolf do not.
static func spirit_level_key(spirit_key: String) -> String:
	if spirit_key.is_empty():
		return ""
	return "%s|%d" % [SpiritBond.species_of(spirit_key), SpiritBond.rarity_of(spirit_key)]
