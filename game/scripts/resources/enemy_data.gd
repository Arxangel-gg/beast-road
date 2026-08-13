class_name EnemyData
extends GameData

## A breed, an elite, or a boss (GDD §8). One dominant breed per terrain gives
## readability; the shared elite pool gives variety.
##
## The manifest files these three categories in two folders, so the category
## picks both the folder and the prefix:
##   BREED "bogkin"        -> res://art/enemies/enemy_bogkin.png
##   ELITE "warden"        -> res://art/enemies/elite_warden.png
##   BOSS  "drowned_choir" -> res://art/bosses/boss_drowned_choir.png

enum Category {
	## Terrain-dominant rank and file.
	BREED,
	## Shared pool, can appear in any terrain.
	ELITE,
	## One per act, ends the act.
	BOSS,
}

## Mechanical identities stay data-driven: the shared enemy script interprets
## one role instead of branching on ids. Existing content defaults to a basic
## marcher, so old resources remain valid.
enum Role {
	MARCHER,
	VANGUARD,
	WARDEN,
	HOWLER,
	BURROWER,
}

@export var category: Category = Category.BREED
@export var role: Role = Role.MARCHER

## Stable data ids survive save migration even when a provisional launch sprite
## is replaced by the authored faction roster. Empty keeps the conventional id.
@export var sprite_id: String = ""

@export var max_hp: float = Balance.ENEMY_MAX_HP

## Damage dealt on contact with the hero or the city.
@export var contact_damage: float = Balance.ENEMY_CONTACT_DAMAGE

## Minimum seconds between two contact hits from this enemy.
@export var contact_interval: float = Balance.ENEMY_CONTACT_INTERVAL

## Walk speed. Tune against HERO_MOVE_SPEED and ENEMY_SPAWN_RADIUS as a set —
## this number is what sets the player's reaction window.
@export var move_speed: float = Balance.ENEMY_WALK_SPEED

## Body radius, used for contact and for crowd separation.
@export var body_radius: float = Balance.ENEMY_BODY_RADIUS

## How hard this enemy resists knockback. 1.0 ignores it, 0.0 takes it in full.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0

## Ashfen's bog-kin regenerate; most things do not. HP per second.
@export var hp_regen: float = 0.0

## Raid charge contributed on death, before any war horn multiplier.
@export var raid_charge_value: float = 1.0

## Resources dropped on death.
@export var resource_value: int = 1

## Role parameters. A Howler's aura raises nearby movement and damage; a
## Burrower enters inside the outer tower; a Vanguard is the fast lane threat.
@export var aura_radius: float = 0.0
@export var aura_strength: float = 0.0
@export_range(0.1, 1.0) var spawn_distance_scale: float = 1.0

## Siege-minded enemies prefer a standing tower in their lane over the hero or
## town. Authored on the enemy resource so adding another sapper is content, not
## another id check in Enemy.
@export var targets_towers: bool = false

## Boss encounter phases. Empty for non-bosses. Crossing each health ratio in
## order triggers the matching name, reinforcements, and another step of the
## authored speed/damage escalation. This keeps boss identity in .tres content.
@export var phase_thresholds: Array[float] = []
@export var phase_names: Array[String] = []
@export var phase_reinforcement_enemy_id: String = ""
@export var phase_reinforcements_per_lane: int = 0
@export var phase_reinforcement_lanes: int = 2
@export var phase_speed_bonus: float = 0.0
@export var phase_damage_bonus: float = 0.0


func get_sprite_path() -> String:
	var visual_id: String = sprite_id if not sprite_id.is_empty() else id
	match category:
		Category.ELITE:
			return GameData.derive_path("enemies", "elite_", visual_id)
		Category.BOSS:
			return GameData.derive_path("bosses", "boss_", visual_id)
		_:
			return GameData.derive_path("enemies", "enemy_", visual_id)
