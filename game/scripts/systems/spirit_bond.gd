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


## Whether a shiny appears, for one animal of this rarity.
##
## Rolled once when the animal is placed and never again, so nothing the player
## does to an animal already on the field can reroll it.
static func rolls_shiny(rarity: int, rng: RandomNumberGenerator) -> bool:
	return rng.randf() < Balance.SPIRIT_SHINY_CHANCE[clampi(rarity, 0, 3)]


## Every variant key a species can offer, in ladder order. For the journal.
static func variants_of(species_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for rarity: int in 4:
		for shiny: bool in [false, true]:
			out.append(key(species_id, rarity, shiny))
	return out
