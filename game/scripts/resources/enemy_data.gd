class_name EnemyData
extends GameData

## A breed, an elite, or a boss (GDD §8). One dominant breed per terrain gives
## readability; the shared elite pool gives variety.
##
## The manifest files these three categories in two folders, so the category
## picks both the folder and the prefix:
##   BREED "bogkin"        -> res://art/enemies/enemy_coalpaint_raider.png
##                          (via sprite_id; see below)
##   ELITE "warden"        -> res://art/enemies/elite_avalanche_warden.png
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

## **Which way this breed's art faces, if it faces a way at all.**
##
## The field mirrors a body to face its travel, which is right for a sprite
## drawn in profile and wrong for one drawn facing the viewer: mirroring a
## front-facing figure swaps the lantern into the other hand and the shield
## onto the other arm, and the eye reads that as a body turned away. Reported
## on 2026-09-13 against the lantern-bearer, the herald, the stalker and the
## Act IV boss, all of which are front-facing and none of which was ever
## going to look right flipped.
##
## FRONT is the honest default for this roster: most of it is drawn head-on.
## RIGHT and LEFT are for the ones genuinely in profile - the runners, the
## riders and the mounts - and those are the only ones that flip.
enum Facing { FRONT, RIGHT, LEFT }
@export var art_facing: Facing = Facing.FRONT

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

## **What this breed throws.**
##
## Before 2026-09-13 there was one answer and every shooter used it, so the
## fourteen ranged breeds were distinguishable by their sprites and by nothing
## a player had to do differently. Each of these is a different *verb*:
##
## - BOLT - the original. One fast shot, committed at release. Sidestep it.
## - SPRAY - a fan, dividing the strike between its shots. Do not stand in the
##   middle of it.
## - LOB - a mortar at a marked circle after a telegraph. Leave the circle.
## - HEX - slow and following, trading damage for mana. Outrun it.
## - LANCE - a telegraphed line struck along its whole length. Step off it.
##
## A breed that authors nothing here throws BOLT, which is what every breed
## threw before this existed.
enum Shot { BOLT, SPRAY, LOB, HEX, LANCE }
@export var shot: Shot = Shot.BOLT

## How far this breed can throw. Zero means "as far as it can reach", which is
## what the roster did before shots varied.
@export_range(0.0, 2400.0) var shot_range: float = 0.0

## **Everything this breed knows how to throw.**
##
## Empty means the single `shot` above, which is what the whole roster did until
## 2026-09-13. With entries, the breed picks one per attack: weighted toward
## whichever suits the range it is shooting at, and never certain, so a Shaman at
## arm's length usually snaps a bolt and occasionally still commits to a mortar.
## Owner's brief: "random uses of both as well as range dependent", and variety
## that rises with the breed's difficulty.
##
## Shared files rather than fields, so a second breed that throws the same fire
## bolt references it (working rule 3) and the two cannot drift apart. Named by
## id, the way every other cross-reference in this project works - a terrain
## names its `enemy_ids`, a discipline node names its `spell_id` - so a shot may
## be re-tuned in one file and every breed that throws it changes with it.
@export var shot_ids: PackedStringArray = PackedStringArray()

## **Loaded by path rather than through ContentDB, and that is not a style
## choice.** `run_tool.gd` runs under `--script`, which registers no autoloads,
## so an autoload named anywhere in a resource script is a *compile* error there
## - GDScript resolves singletons when it compiles, not when it runs. Reaching
## for ContentDB here took the audit and the asset report down with it and the
## sweep reported three gates DIRTY rather than failed.
##
## The id implies the file, which is the same convention art already uses, and
## Godot caches the load. ContentDB still indexes the folder so gates can
## enumerate every shot that exists.
const SHOT_PATH: String = "res://data/enemy_shots/%s.tres"


## The repertoire, resolved.
##
## One accessor so nothing downstream has to ask which of the two shapes a breed
## is using: the single `shot` that existed before this and the list that
## joined it answer the same question here.
func repertoire() -> Array[EnemyShotData]:
	var out: Array[EnemyShotData] = []
	for id: String in shot_ids:
		var path: String = SHOT_PATH % id
		if not ResourceLoader.exists(path):
			continue
		var entry := load(path) as EnemyShotData
		if entry != null:
			out.append(entry)
	return out


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

# --- What an act boss does that the roster does not (2026-09-13) --------------
#
# A boss with neither authored fights exactly as it did before: slow, and
# dangerous only to whatever it walks into. Anything above zero here is a
# boss that comes at the player.

## The slam: a telegraphed blow in a circle around the boss, on a cadence.
## `boss_slam_damage` is a multiple of `contact_damage`, so a boss that is
## re-tuned stays in proportion with itself.
@export_range(0.0, 8.0) var boss_slam_damage: float = 0.0
@export_range(0.0, 600.0) var boss_slam_radius: float = 0.0
@export_range(0.0, 30.0) var boss_slam_interval: float = 6.0
@export_range(0.0, 900.0) var boss_slam_knockback: float = 260.0

## The volley: shots thrown at whoever it can see, on its own cadence.
@export_range(0.0, 8.0) var boss_volley_damage: float = 0.0
@export_range(0, 12) var boss_volley_shots: int = 0
@export_range(0.0, 30.0) var boss_volley_interval: float = 5.0
@export_range(0.0, 2400.0) var boss_volley_range: float = 900.0


## Whether this body has anything a boss does. Asked rather than
## `category == BOSS`, so a future elite could be given one without the test
## having to learn about it.
func has_boss_abilities() -> bool:
	return boss_slam_damage > 0.0 or (boss_volley_damage > 0.0 and boss_volley_shots > 0)


func get_sprite_path() -> String:
	var visual_id: String = sprite_id if not sprite_id.is_empty() else id
	match category:
		Category.ELITE:
			return GameData.derive_path("enemies", "elite_", visual_id)
		Category.BOSS:
			return GameData.derive_path("bosses", "boss_", visual_id)
		_:
			return GameData.derive_path("enemies", "enemy_", visual_id)
