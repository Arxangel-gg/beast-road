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
	## **Appended, never inserted** - `.tres` files index this enum by number,
	## and a member added in the middle silently repoints every resource after
	## it. `Role` and `Trigger` both taught this project that, in silence.
	##
	## Camp-only rank and file: harder than the road's bodies, and never seen on
	## the road. The second and third camp are built from these (owner,
	## 2026-09-15: "second camp should have some unique camp only harder mobs,
	## and third camp should as well"), which is what makes walking into one a
	## different proposition from holding a lane.
	CAMP_BREED,
	## The epic thing at the back of a war camp: a miniboss of its own, rolled
	## in place of the camp's champion. Dragons and wyverns are these.
	CAMP_LORD,
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

## **What this breed sounds like when it notices you**, as a `Sfx` id or group.
##
## Sixty-seven breeds ship and **not one of them has a voice**: an enemy makes an
## impact noise when it is hit (chosen by its `hide`) and a death rattle when it
## falls, and is otherwise silent from the far end of the road to the wall. The
## roster is drawn with horns, megaphones and open jaws and none of it is heard.
##
## Empty is the shipped default and stays silent, so this grows the way the
## soundtrack does - by dropping a file in and naming it here, with no code
## change. `Sfx.play_at` is quiet about an id it does not have, so a breed can be
## authored before its recording exists.
@export var voice_sfx: String = ""

## Seconds between one breed's calls, so a wave of forty does not become a wall
## of noise. Zero uses `Balance.ENEMY_VOICE_GAP`.
@export_range(0.0, 60.0) var voice_gap: float = 0.0


## **Whether this body is one of the fight's set pieces**, rather than one of
## the many.
##
## Every reader of the category used to spell this as `!= Category.BREED`, which
## was exactly right while the enum held three members and quietly wrong the
## moment it held five: `CAMP_BREED` is rank and file that happens to live in a
## camp, and four separate expressions would have started paying it elite loot,
## a guaranteed drop, the elite crate multiplier and an `elite_fell` that buys a
## channel more time. None of that would have errored and all of it would have
## been felt.
##
## So the question has one answer in one place. A camp lord *is* a set piece - it
## is the miniboss at the back of a war camp - and a camp breed is not.
func is_promoted() -> bool:
	return category == Category.ELITE or category == Category.BOSS \
		or category == Category.CAMP_LORD
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

## **Whether mirroring this sprite would move a prop into the wrong hand.**
##
## A `FRONT` sprite is drawn square to the camera, so flipping it does not turn
## it round - it swaps its own left and right. For most bodies that is harmless
## or invisible: a bandit's sword changes hands and reads as having turned, and a
## symmetric brute does not change at all. For a few it is the "facing backwards"
## fault this project has been reported for repeatedly - a shield on the other
## arm, a war horn sounding out of the back of a head.
##
## Those few are what this names, so that everything else may turn. **Mostly
## derived rather than authored**: `brace_chance` above zero already means the
## body carries a shield, which is the large half of the list. This is only for
## the ones no existing field implies.
@export var art_handed: bool = false


## True when flipping this sprite would put something in the wrong hand.
func art_is_handed() -> bool:
	return art_handed or brace_chance > 0.0

## **What a blow lands on.** The sound, the sparks and the hitstop of a hit
## differ by it (the fifth forwarded list, 2026-09-14: "different feedback
## for flesh, armor, shields, stone, towers and bosses"): flesh takes the
## blade with a wet crack and blood, armour rings and throws sparks and holds
## the blade a beat longer, stone chips and dusts, a spirit barely resists.
## Authored per breed, read by `HeroAttack` on the body it struck; nothing
## about damage changes with it.
enum Hide { FLESH, ARMOUR, STONE, SPIRIT }
@export var hide: Hide = Hide.FLESH

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

## **How many blows in quick succession this body will be moved by.**
##
## Each one adds `1 / stagger_tolerance` to its stagger load, and a full load is
## a body that plants rather than reeling (see `Balance.STAGGER_WINDOW`). A
## runner is knocked around for half a fight; a stone golem stops after two.
##
## Never a damage figure: the blows all land for exactly what they are worth.
@export_range(1.0, 12.0) var stagger_tolerance: float = 5.0

## The chance that a heavily staggered body sets its shield instead of reeling,
## refusing the flinch and the shove outright and pushing back whoever is on it.
##
## Zero for anything without a shield, which is most of the roster. This is the
## owner's "a chance to stand their ground" (2026-09-15) and it is a *refusal*
## rather than a counter-attack - it deals nothing.
@export_range(0.0, 1.0) var brace_chance: float = 0.0

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
## **What this breed does that you remember it for** (owner brief, 2026-09-15,
## from a forwarded design review).
##
## The review's test is the right one: "when I see a Bell Priest, I save an
## interrupt for its bell" is an identity, and "the Bell Priest has more health"
## is not. Fourteen breeds threw one bolt between them until the shots were
## authored; most of the roster still *moves* one way between them, and the
## heavy ones differ by their statistics alone.
##
## A behaviour is one committed action with three parts, and all three are the
## point: a **tell** the player can read, a **commitment** that cannot be taken
## back, and a **recovery** that is the opening. An enemy that can cancel is an
## enemy with no counterplay.
##
## - `ANCHOR` plants and raises a guard that covers what is behind it. It cannot
##   move or strike while it holds, and its flanks are bare - so the answer is
##   to go round it or to break it before it sets.
## - `POUNCE` crouches, marks a line, leaps along it and overshoots. The answer
##   is to step off the line and hit it while it is getting up.
## - `WARD` winds up and hands the allies near it one turned blow each. The
##   answer is to interrupt the wind-up, kill the ward, or spend the guards.
## - `STORE` banks a capped share of what is done to it and gives it back as one
##   telegraphed strike along a line. The answer is to leave the line - never to
##   stop shooting, which is why this is a *release* rather than a reflection.
##
## **The bound is the one every addition here is held to: a behaviour changes
## the shape of a fight and never its size.** Nothing below multiplies
## `contact_damage`; a guard turns one blow and is gone; an anchor buys time and
## spends forward progress and attacks for it; a release deals what was banked
## and no more. `curve_report` reads the same waves, and `enemy_behaviour_check`
## measures each of those sentences rather than reading the constants back.
enum Behaviour { NONE, ANCHOR, POUNCE, WARD, STORE }
@export var behaviour: Behaviour = Behaviour.NONE
## How long the tell lasts before the commitment. Zero uses the roster default.
@export_range(0.0, 4.0) var behaviour_warning: float = 0.0
## How long the commitment lasts.
@export_range(0.0, 12.0) var behaviour_seconds: float = 0.0
## How long it is helpless afterwards. This is the opening, and a behaviour with
## no recovery is a behaviour with no answer.
@export_range(0.0, 4.0) var behaviour_recovery: float = 0.0
## How far it reaches: an anchor's shelter, a pounce's leap, a ward's call, a
## release's line.
@export_range(0.0, 900.0) var behaviour_reach: float = 0.0
## What the commitment is worth, as a share of `contact_damage` for a strike or
## a fraction of a blow turned for a guard. Never a number of its own.
@export_range(0.0, 3.0) var behaviour_power: float = 0.0
## How long it waits between commitments.
@export_range(0.0, 60.0) var behaviour_interval: float = 8.0


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


## **The one thing a breed that closes throws on the way in.**
##
## Owner, 2026-09-15, about the ranged roster: "they also need more variety in
## their ranged abilities. So do the ones on the horses." The mounted breeds
## were the one group that could not answer that, because all three of them are
## VANGUARD - they charge, they touch you, and that is the whole of what they
## do. Which is a shame, because all three are *painted* with a javelin raised
## overhand.
##
## So this is not a repertoire and a breed that carries one is not a Howler. A
## Howler stands off and shoots for a living; this is a single thing let go
## once on the approach, after which the body keeps coming and fights the way it
## always has.
##
## **The bound is the one every shot in this game is held to: it changes the
## shape of a blow and never its size.** `thrown_share` is a *fraction* of the
## breed's contact damage, so a rider who opens at range hits softer when it
## arrives than one who simply arrived; it is thrown only at a person, only
## while out of melee reach, and only once every `thrown_interval`, so it can
## never be added to an exchange the body is already winning. A breed that
## authors nothing here is untouched.
@export var thrown_shot_id: String = ""
## How far it will throw, and how often. Zero range means it never throws.
@export_range(0.0, 1600.0) var thrown_range: float = 0.0
@export_range(0.5, 30.0) var thrown_interval: float = 6.0
## The share of its contact blow the throw carries. Never above one: see above.
@export_range(0.0, 1.0) var thrown_share: float = 0.5


## The shot this breed throws on the approach, or null.
##
## Loaded by path for the same reason the repertoire is - `run_tool.gd` runs
## under `--script` with no autoloads, and naming ContentDB in a resource script
## is a compile error there.
func thrown_shot() -> EnemyShotData:
	if thrown_shot_id.is_empty() or thrown_range <= 0.0:
		return null
	var path: String = SHOT_PATH % thrown_shot_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as EnemyShotData


## Whether this breed ever throws anything at all - as a Howler, or on the way
## in. Asked rather than `role == HOWLER` wherever the question is "does this
## thing have an answer at range", so a javelin does not have to be a role.
func throws_something() -> bool:
	return role == Role.HOWLER or thrown_shot() != null


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
