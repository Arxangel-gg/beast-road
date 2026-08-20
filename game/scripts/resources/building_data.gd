class_name BuildingData
extends GameData

## A town building (GDD §5). Construction is gated by distance travelled, not
## resources and not real time — surviving is building.
##
## `id = "forge"` -> `res://art/city/building_forge.png`

## What upgrading this building actually does. The effect is a key plus a
## magnitude rather than a script per building, so six buildings stay six rows
## of data instead of six subclasses.
enum Effect {
	## Adds Town Hall relic sockets.
	RELIC_SLOTS,
	## Unlocks and improves tower blueprints.
	BLUEPRINTS,
	## Hero max HP, move speed and spell cooldown.
	HERO_UPGRADE,
	## Resource generation rate.
	RESOURCE_RATE,
	## Accepts captives, converting them into resource rate.
	CAPTIVE_LABOUR,
	## Reveals the composition of the next wave.
	WAVE_FORESIGHT,
	## Produces one named run currency per distance survived.
	PRODUCTION,
	## Enables a capped one-run cache.
	TREASURY_CACHE,
	## Enables bounded loss-making exchange and a rotating act service.
	MARKET,
}

@export var effect: Effect = Effect.RESOURCE_RATE

## Magnitude gained per tier, indexed by tier - 1.
@export var effect_per_tier: Array[float] = [1.0, 2.0, 3.0]

@export var max_tier: int = 3

## Whether captives can be assigned here.
@export var accepts_captives: bool = false

## Buildings unlocked from the start of a run; the rest need blueprints.
@export var available_from_start: bool = true

## Where this building sits on the town's ring, in degrees. The Town Hall sits
## at the centre and ignores this.
@export var plot_angle_degrees: float = 0.0

@export var is_town_hall: bool = false

## Currency produced by PRODUCTION buildings.
@export var produced_currency: String = ""

## 0 is in the starting construction pool. 1/2/3 unlock after that act is first
## cleared. Scavenger Lodge uses the Oathbound milestone and keeps this at 0.
@export_range(0, 3) var unlock_act: int = 0

## True when the plot needs a permanent content milestone before it can be
## commissioned. This unlocks a decision, never a pre-built tier.
@export var requires_unlock: bool = false

## Wood paid immediately when the project is commissioned; travel distance is
## still the construction clock.
@export var wood_costs: Array[int] = []


func get_sprite_path() -> String:
	return GameData.derive_path("city", "building_", id)


## Tier one keeps the canonical path. Higher tiers are derived from the same id
## and remain optional at runtime, so an interrupted art install falls back to
## the last known-good base rather than making a building invisible.
func get_sprite_path_for_tier(tier: int) -> String:
	var base: String = get_sprite_path()
	var candidate: String = get_tier_sprite_path(tier)
	return candidate if ResourceLoader.exists(candidate) else base


## Exact authored path, without the runtime fallback. Production art gates use
## this form so a missing higher tier cannot hide behind a perfectly valid tier
## one sprite.
func get_tier_sprite_path(tier: int) -> String:
	var base: String = get_sprite_path()
	if tier <= 1:
		return base
	return "%s_tier_%02d.png" % [base.get_basename(), tier]


## Distance units needed to construct the given tier.
static func tier_cost(tier: int) -> float:
	match tier:
		1:
			return Balance.BUILD_COST_TIER_1
		2:
			return Balance.BUILD_COST_TIER_2
		_:
			return Balance.BUILD_COST_TIER_3


func effect_at(tier: int) -> float:
	if tier <= 0 or effect_per_tier.is_empty():
		return 0.0
	return effect_per_tier[clampi(tier - 1, 0, effect_per_tier.size() - 1)]


func wood_cost_at(tier: int) -> int:
	if tier <= 0:
		return 0
	if not wood_costs.is_empty():
		return wood_costs[clampi(tier - 1, 0, wood_costs.size() - 1)]
	return Balance.BUILD_WOOD_COSTS[clampi(tier - 1, 0, Balance.BUILD_WOOD_COSTS.size() - 1)]
