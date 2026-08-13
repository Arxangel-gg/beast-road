class_name TowerData
extends GameData

## A tower (GDD §4). Eight base towers, two per element, plus ten combination
## towers built in a lane's middle slot from the two elements flanking it.
##
## `id = "ember_spire"` -> `res://art/towers/tower_ember_spire.png`

## The four elements. Renamed in GDD v3 from Fire/Frost/Stone/Storm; the tower
## identities and art paths were kept, so nothing in /art moved.
enum Element {
	FIRE,
	WATER,
	EARTH,
	AIR,
}

## Per-built-tower targeting doctrines. Stored in RunState with the slot, so the
## player's choice survives scope changes and upgrades.
enum TargetPriority {
	FIRST,
	STRONG,
	FAST,
	SPECIAL,
}

@export var element: Element = Element.FIRE

## Combination towers are built in the middle slot only, and only when both
## flanking slots are filled. `parent_a` / `parent_b` are the elements that
## produce this tower; order does not matter when matching.
@export var is_combination: bool = false
@export var parent_a: Element = Element.FIRE
@export var parent_b: Element = Element.FIRE

## Damage per shot at level 1, before level, lane and terrain modifiers.
@export var damage: float = 10.0

## Seconds between shots at level 1.
@export var attack_interval: float = 1.0

@export var attack_range: float = Balance.TOWER_RANGE

## 0 means single target; above that, a splash radius in pixels.
@export var aoe_radius: float = 0.0

## Extra targets a shot carries to after the first — chain lightning, piercing.
@export var extra_targets: int = 0

## Movement multiplier applied to things hit. 1.0 is no slow.
@export var slow_factor: float = 1.0
@export var slow_duration: float = 0.0

## Damage per second left burning on a hit target.
@export var burn_dps: float = 0.0
@export var burn_duration: float = 0.0

@export var knockback: float = 0.0

## Bulwark-style: pulls enemies to it and blocks the lane.
@export var taunts: bool = false

## Structure HP. All towers are vulnerable; dedicated blockers override the
## standard value with their heavier authored durability.
@export var max_hp: float = Balance.TOWER_BASE_MAX_HP

## Leaves a damaging zone on the ground where it hits.
@export var ground_zone_dps: float = 0.0
@export var ground_zone_duration: float = 0.0

## Chance per hit to freeze the target solid, 0..1.
@export_range(0.0, 1.0) var freeze_chance: float = 0.0

## Flat armour granted to other towers in the same lane.
@export var lane_armour_bonus: float = 0.0


func get_sprite_path() -> String:
	return GameData.derive_path("towers", "tower_", id)


## Resource cost to place this tower at level 1.
func build_cost() -> int:
	return Balance.TOWER_COMBO_BUILD_COST if is_combination else Balance.TOWER_BUILD_COST


## Cost to go from `level` to `level + 1`. Returns -1 when already maxed.
static func upgrade_cost(level: int) -> int:
	if level < 1 or level >= Balance.TOWER_MAX_LEVEL:
		return -1
	return Balance.TOWER_UPGRADE_COSTS[level - 1]


func damage_at(level: int) -> float:
	return damage * Balance.TOWER_LEVEL_DAMAGE[_level_index(level)]


func interval_at(level: int) -> float:
	return attack_interval / Balance.TOWER_LEVEL_RATE[_level_index(level)]


func utility_at(level: int) -> float:
	return Balance.TOWER_LEVEL_UTILITY[_level_index(level)]


func range_at(level: int) -> float:
	return attack_range * Balance.TOWER_LEVEL_RANGE[_level_index(level)]


## True when this combination is the one produced by the given pair, in either
## order. This is the whole lookup — combinations are data, not a branch.
func matches_parents(a: Element, b: Element) -> bool:
	if not is_combination:
		return false
	return (parent_a == a and parent_b == b) or (parent_a == b and parent_b == a)


static func element_name(e: Element) -> String:
	match e:
		Element.WATER:
			return "Water"
		Element.EARTH:
			return "Earth"
		Element.AIR:
			return "Air"
		_:
			return "Fire"


## Every element colour in the game comes through here - tower buttons,
## projectiles, lights, upgrade bursts - which is what makes colourblind support a
## single table rather than a hunt through twenty call sites.
static func element_colour(e: Element) -> Color:
	return Palette.element(int(e))


static func target_priority_name(priority: int) -> String:
	match priority:
		TargetPriority.STRONG:
			return "Strong"
		TargetPriority.FAST:
			return "Fast"
		TargetPriority.SPECIAL:
			return "Special"
		_:
			return "First"


static func target_priority_description(priority: int) -> String:
	match priority:
		TargetPriority.STRONG:
			return "Highest maximum health first. Best for heavy single-target fire."
		TargetPriority.FAST:
			return "Fastest mover first. Stops brittle runners from slipping through."
		TargetPriority.SPECIAL:
			return "Bosses, Howlers, Burrowers and other specialist threats first."
		_:
			return "Closest to the town first. The safest general defence."


func _level_index(level: int) -> int:
	return clampi(level - 1, 0, Balance.TOWER_MAX_LEVEL - 1)
