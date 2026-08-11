class_name TowerData
extends GameData

## One of the eight towers (GDD §4). Towers auto-fire and are swappable only
## between segments, so this resource describes a loadout choice, not a
## placement puzzle.
##
## `id = "ember_spire"` -> `res://art/towers/tower_ember_spire.png`

## The four elements. Adjacency between two different elements produces a
## fusion; adjacency between two of the same grants SAME_ELEMENT_DAMAGE_BONUS.
enum Element {
	FIRE,
	FROST,
	STONE,
	STORM,
}

@export var element: Element = Element.FIRE

## Damage per shot, before fusion and terrain modifiers.
@export var damage: float = 10.0

## Seconds between shots. "Fast" towers are ~0.4, "slow, heavy" ones ~1.6.
@export var attack_interval: float = 1.0

## Firing radius. Defaults to the GDD's shared value; a tower that deviates
## from it changes the shape of the whole defensive ring, so deviate on purpose.
@export var attack_range: float = Balance.TOWER_RANGE

## 0 means single target. Anything above is a splash radius in pixels.
@export var aoe_radius: float = 0.0

## Extra targets a shot carries to after the first: chain lightning, piercing
## lines. 0 means the shot stops at its first target.
@export var extra_targets: int = 0

## Movement multiplier applied to things this tower hits. 1.0 is no slow.
@export var slow_factor: float = 1.0

## Seconds the slow lasts.
@export var slow_duration: float = 0.0

## Impulse applied on hit, in px/s.
@export var knockback: float = 0.0

## Bulwark-style: draws enemies to itself and blocks their path.
@export var taunts: bool = false

## Structure HP for towers that can be attacked. 0 means indestructible.
@export var max_hp: float = 0.0


func get_sprite_path() -> String:
	return GameData.derive_path("towers", "tower_", id)
