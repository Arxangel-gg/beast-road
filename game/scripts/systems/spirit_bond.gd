class_name SpiritBond
extends RefCounted

## The rules of the Wildlife Spirit Companion system, in one place.
##
## Owner decision, 2026-09-01. Every wildlife species can be bonded as a Spirit
## Companion, independently at each of the four wildlife rarities, and again as a
## Shiny of each. The loop is meant to be legible from playing rather than from a
## wiki:
##
##   see an animal → meet that exact variant enough times → its spirit is yours
##
## ## Why this is static rules over plain strings
##
## There is no `SpiritCompanionData` resource and there is deliberately not going
## to be one. Twenty-three species times four rarities times normal-or-shiny is
## 184 variants, and authoring 184 files is how a collection system becomes a
## content chore that nobody extends. A spirit *is* a `WildlifeData` plus a
## rarity plus a shiny flag; everything else — health, damage, recovery, the
## journal row — is derived from those three by the functions below.
##
## Adding a species later is therefore adding one `.tres` to `data/wildlife/`,
## exactly as it is today, and eight spirits come with it for free.
##
## Pure and autoload-free on purpose, so the whole progression can be checked
## without a save file or a scene.

## How an encounter was earned. Both feed one counter - see `credit`.
enum Kind { SLAIN, BONDED }


## The stable key for one variant. Species, rarity, and whether it shone.
##
## A string rather than a struct because it is a save key: it has to survive
## JSON, and a dictionary of dictionaries would need migrating the first time the
## shape changed.
static func key(species_id: String, rarity: int, shiny: bool) -> String:
	return "%s|%d|%d" % [species_id, clampi(rarity, 0, 3), 1 if shiny else 0]


static func species_of(bond_key: String) -> String:
	var parts: PackedStringArray = bond_key.split("|")
	return parts[0] if parts.size() == 3 else ""


static func rarity_of(bond_key: String) -> int:
	var parts: PackedStringArray = bond_key.split("|")
	return clampi(int(parts[1]), 0, 3) if parts.size() == 3 else 0


static func shiny_of(bond_key: String) -> bool:
	var parts: PackedStringArray = bond_key.split("|")
	return parts.size() == 3 and parts[2] == "1"


## How many encounters this variant needs.
##
## Rarer means fewer, which is the whole trick: the rarity that is hard to *find*
## is not also hard to *finish*, so a Legendary sighting is a complete event
## rather than the first of ten. Shiny needs fewer again, because finding the
## shiny is already the grind - nobody should have to meet ten Shiny Common
## Wolves.
static func needed(rarity: int, shiny: bool) -> int:
	var tier: int = clampi(rarity, 0, 3)
	return Balance.SPIRIT_SHINY_ENCOUNTERS[tier] if shiny \
		else Balance.SPIRIT_ENCOUNTERS[tier]


## Where this variant sits on the one power ladder the whole system shares.
##
## Eight steps, and the ordering is the design requirement rather than an
## emergent property:
##
##   common < shiny common < uncommon < shiny uncommon
##         < rare < shiny rare < legendary < shiny legendary
##
## So a Shiny Common is genuinely worth having and still does not invalidate an
## Uncommon. One expression rather than a table, because a table of eight rows is
## eight chances to write the ordering down wrong.
static func power_step(rarity: int, shiny: bool) -> int:
	return clampi(rarity, 0, 3) * 2 + (1 if shiny else 0)


## The multiplier on a species' base numbers at this step.
##
## Bounded deliberately. GDD §17's rule is that a higher tier must feel like a
## real upgrade without making everything below it worthless - so the apex is a
## little over twice the base, not ten times it. Rarity decides power *within* a
## species; which species you took decides what you can do, and that second axis
## is what keeps a Rare Crow interesting next to a Legendary Wolf.
static func power_scale(rarity: int, shiny: bool) -> float:
	var reach: float = float(power_step(rarity, shiny)) / 7.0
	return lerpf(1.0, Balance.SPIRIT_APEX_POWER, reach)


## Seconds a defeated spirit spends re-forming before it returns.
##
## Higher rarity recovers *faster*, which is the opposite of the obvious choice
## and is the right one: punishing the best companion with the longest absence
## makes owning it worse. Where a Legendary is balanced is in its ability
## cooldowns, not in how long it is missing.
static func recovery_seconds(rarity: int, shiny: bool) -> float:
	var tier: int = clampi(rarity, 0, 3)
	var base: float = Balance.SPIRIT_RECOVERY_SECONDS[tier]
	return maxf(base - (Balance.SPIRIT_SHINY_RECOVERY_BONUS[tier] if shiny else 0.0), 1.0)


## The player-facing name of a variant, built from the species' own name.
static func display_name(kind: WildlifeData, rarity: int, shiny: bool) -> String:
	if kind == null:
		return ""
	var tier: String = Balance.SPIRIT_RARITY_NAMES[clampi(rarity, 0, 3)]
	return "%s%s %s Spirit" % ["Shiny " if shiny else "", tier, kind.display_name]


## The colour a variant reads as, anywhere it is drawn.
##
## Shiny takes its own colour rather than a tint of the rarity's, because the
## whole point is that it is recognisable across a field at a glance.
static func tint(rarity: int, shiny: bool) -> Color:
	if shiny:
		return Balance.SPIRIT_SHINY_COLOUR
	return Balance.SPIRIT_RARITY_COLOURS[clampi(rarity, 0, 3)]


## The odds a fresh animal of this species and rarity shines, this player.
##
## Owner request, 2026-09-02: bad luck should not be able to produce "a hundred
## and fifty hours and I still have not seen one". A Common shiny is a one-in-
## fifty sighting, which means a perfectly ordinary player is somewhere around a
## one-in-a-thousand chance of going four hundred sightings without one - and
## that player has done nothing wrong.
##
## **Derived from what the save already holds, so nothing new persists.** The
## collection already counts every encounter with every variant, and the gap
## between "ordinary ones met" and "shiny ones met" *is* the dry streak. No pity
## counter, no new key, no owner question about working rule 7 - the correction
## falls out of data that was already there for the journal.
##
## The rare thing stays rare. Nothing happens at all until a player is well past
## the expected gap, the ramp is gentle after that, and it is capped: a Common
## shiny can reach four times its base and no further. A player is never told any
## of this, which is the point.
static func shiny_chance(species_id: String, rarity: int) -> float:
	var tier: int = clampi(rarity, 0, 3)
	var base: float = Balance.SPIRIT_SHINY_CHANCE[tier]
	if species_id.is_empty() or base <= 0.0:
		return base
	# A shiny encounter credits the plain variant too, so the plain count is
	# every sighting and the difference is the ordinary ones.
	var seen: int = MetaState.spirit_encounter_count(key(species_id, tier, false))
	var shone: int = MetaState.spirit_encounter_count(key(species_id, tier, true))
	var expected: float = 1.0 / base
	var unlucky: float = float(maxi(seen - shone, 0)) \
		- expected * Balance.SPIRIT_PITY_GRACE
	if unlucky <= 0.0:
		return base
	var lift: float = 1.0 + (unlucky / expected) * Balance.SPIRIT_PITY_SLOPE
	return base * minf(lift, Balance.SPIRIT_PITY_CEILING)


## Whether a shiny appears, for one animal of this species and rarity.
##
## Rolled once when the animal is placed and never again, so nothing the player
## does to an animal already on the field can reroll it.
static func rolls_shiny(species_id: String, rarity: int,
		rng: RandomNumberGenerator) -> bool:
	return rng.randf() < shiny_chance(species_id, rarity)


## The personality the animal with this serial is wearing.
##
## **Derived, never rolled.** A trait decided by a random draw would have to be
## carried in the co-op spawn packet or the two machines would disagree about the
## same fox - which is precisely the bug the shiny roll had before it was told by
## the host. Both machines already know the species and the serial, so both can
## work this out and neither has to be told.
##
## The serial is mixed with the species so that the first animal of every kind is
## not always the same personality, which is what a bare `serial % count` gives.
static func trait_for(species_id: String, serial: int) -> SpiritTraitData:
	var kinds: Array[SpiritTraitData] = ContentDB.spirit_trait_list()
	if kinds.is_empty():
		return null
	var mixed: int = absi(hash(species_id) ^ (serial * 2654435761))
	return kinds[mixed % kinds.size()]


## Every variant key a species can offer, in ladder order. For the journal.
static func variants_of(species_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for rarity: int in 4:
		for shiny: bool in [false, true]:
			out.append(key(species_id, rarity, shiny))
	return out


## The `CompanionData` one variant walks as.
##
## Built from the species rather than authored, which is the whole reason there
## is no resource per variant: a spirit's numbers are its animal's numbers, put
## on the companion's scale and multiplied by where the variant sits on the
## ladder. Twenty-three species times eight variants is 184 companions that
## nobody had to write down.
##
## The archetype comes from the animal's own temperament and gait, so a wolf
## hunts, a bear holds ground and a hare stays near - which is what the player
## already believes about them from watching them on the road.
static func companion_form(kind: WildlifeData, bond_key: String) -> CompanionData:
	if kind == null:
		return null
	var rarity: int = rarity_of(bond_key)
	var shiny: bool = shiny_of(bond_key)
	var scale: float = power_scale(rarity, shiny)

	var form := CompanionData.new()
	form.id = kind.id
	form.display_name = display_name(kind, rarity, shiny)
	form.description = kind.description
	# No duration. A spirit is not a spell effect - see CLAUDE.md, 2026-09-01.
	form.duration = INF
	form.colour = tint(rarity, shiny)
	form.flies = kind.flies
	form.scale = kind.scale * Balance.SPIRIT_DRAW_SCALE

	# A harmless animal still fights as a spirit - that is what being a spirit
	# *is* - but it fights as what it was. A hare harries; a bear does not.
	var bite: float = maxf(kind.damage, Balance.SPIRIT_MINIMUM_DAMAGE)
	form.damage = bite * scale
	form.attack_interval = maxf(kind.attack_interval, 0.30)
	form.attack_range = maxf(kind.attack_range, 70.0)
	# `aggro_radius` is how far the living animal looks for trouble, and it is
	# zero for everything harmless - a rabbit hunts nothing. Its spirit does, so
	# the floor is what gives a harmless species a hunting range at all.
	form.hunt_range = maxf(kind.aggro_radius, Balance.SPIRIT_MINIMUM_HUNT)
	form.speed = maxf(kind.speed * Balance.SPIRIT_SPEED_SCALE, 180.0)
	form.follow_distance = clampf(kind.social_spacing, 70.0, 160.0)
	form.knockback = kind.knockback * scale
	return form


## The personality a bonded variant is carrying, or null.
##
## Looked up through `MetaState` rather than stored on the form, because the form
## is rebuilt every time a spirit is summoned and the personality belongs to the
## bond rather than to the summon.
static func trait_of_bond(bond_key: String) -> SpiritTraitData:
	var id: String = MetaState.spirit_trait(bond_key)
	return null if id.is_empty() else ContentDB.spirit_trait(id)
