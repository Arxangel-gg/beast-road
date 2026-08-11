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

@export var category: Category = Category.BREED

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

## How hard this enemy resists knockback. 1.0 takes it in full, 0.0 ignores it.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0

## Ashfen's bog-kin regenerate; most things do not. HP per second.
@export var hp_regen: float = 0.0

## Raid charge contributed on death, before any war horn multiplier.
@export var raid_charge_value: float = 1.0

## Resources dropped on death.
@export var resource_value: int = 1


func get_sprite_path() -> String:
	match category:
		Category.ELITE:
			return GameData.derive_path("enemies", "elite_", id)
		Category.BOSS:
			return GameData.derive_path("bosses", "boss_", id)
		_:
			return GameData.derive_path("enemies", "enemy_", id)
