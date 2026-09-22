class_name EnemyShotData
extends GameData

## One thing a ranged breed knows how to throw, and when it prefers to throw it.
##
## **Why a resource rather than another field on `EnemyData`.** Before this a
## breed authored exactly one `shot`, so fourteen shooters posed one question
## each and a player who learned to sidestep a bolt in Act I had learned that
## breed forever. The owner asked for the Ember Shamans to keep their mortar and
## also carry a fire bolt, "with random uses of both as well as range
## dependent", and for the rest of the roster to grow the same way with variety
## that rises with the breed's difficulty.
##
## A repertoire is a list, and a list of *shared* files is what keeps it
## data-driven: the same `fire_bolt_near` is carried by four breeds, so adding a
## shooter is a reference rather than a new branch (working rule 3).
##
## **The enum is duplicated from `EnemyData.Shot` on purpose.** `EnemyData`
## refers to this class for its repertoire, so this class naming `EnemyData`
## back would be a cyclic `class_name` reference. The two must stay in step and
## `enemy_shot_check` asserts they do, name for name and index for index -
## this project has twice lost content to an enum that grew in the middle
## (`Role`, and `Trigger`), and a silent second copy is exactly that hazard
## wearing a different coat.
enum Kind { BOLT, SPRAY, LOB, HEX, LANCE }

@export var kind: Kind = Kind.BOLT

## **The band this shot is for**, in world units from the target.
##
## A shot is *preferred* inside its band and merely possible outside it, which
## is what makes the choice both range-dependent and random: a shaman at arm's
## length usually snaps a bolt and occasionally still commits to a mortar, and
## one across the field usually lobs. A band that gated absolutely would make
## the breed a state machine the player could read off a tape measure.
##
## `far` of zero means "as far as the breed can throw".
@export_range(0.0, 2400.0) var near: float = 0.0
@export_range(0.0, 2400.0) var far: float = 0.0

## How much this shot is favoured when the target is inside the band, and when
## it is not. The second number is the whole design: at zero this is a range
## gate, and a repertoire of range gates is one shot per distance.
@export_range(0.0, 16.0) var weight: float = 1.0
@export_range(0.0, 16.0) var stray_weight: float = 0.25

## What the shot looks like in flight, for the kinds that fly.
##
## The projectile is drawn from constants rather than from art, so a fire bolt
## is this and nothing else - no new sprite, no new scene. Left fully
## transparent, the projectile keeps the roster's own colours.
@export var tint: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var core_tint: Color = Color(0.0, 0.0, 0.0, 0.0)
## **What the head of a flying shot is shaped like, and how it moves.**
##
## Owner, 2026-09-21: "Enemies should not be reusing the same projectiles as
## each other, each enemy should have its own unique projectiles ... each tuned
## for that enemy". Every breed owns its own shot files now (`enemy_shot_check`
## refuses one shared by two), and what makes them *look* their own is here:
## a head drawn from one of these shapes, at a size, spinning or not, swaying
## off its path or not, with a trail of its own weight, at its own pace. All of
## it is a picture - the node stays on its path, a sway is drawn and never
## flown, and the blow is the same blow - which is the bound every tower shot
## style is held to. `RUNE` is what every shot looked like before this.
enum Head { RUNE, ORB, DART, SHARD, STONE, SKULL, LEAF, BOLA, FLAME, RING, BELL, GEAR }
@export var head: Head = Head.RUNE
@export_range(0.4, 3.0) var head_scale: float = 1.0
## Turns a second the drawn head makes. Zero flies point-first.
@export_range(-6.0, 6.0) var spin: float = 0.0
## How far the picture sways either side of the path, in pixels.
@export_range(0.0, 24.0) var wobble: float = 0.0
## The shell behind the head and the trail; left clear, the roster's own.
@export var shell_tint: Color = Color(0.0, 0.0, 0.0, 0.0)
## The trail's weight against the roster's.
@export_range(0.3, 2.5) var trail_scale: float = 1.0
## How fast it flies against the roster's baseline. Bounded either side of
## one: slower is more dodgeable and faster is less, and both are the *shape*
## of a blow rather than its size, exactly as a hex is already slower.
@export_range(0.6, 1.4) var pace: float = 1.0

## **What a LOB or a LANCE does differently from the next one.**
##
## Both resolve as `EnemyGroundStrike`, and until 2026-09-14 both read their
## size and their warning off a single global constant - so a stone mortar and
## an ember mortar were the same blow in the same colour, and the only thing
## separating two shots of a kind was which breed happened to throw it.
##
## Zero means "use the kind's default", so a shot that authors nothing behaves
## exactly as every shot of its kind always has.
@export_range(0.0, 400.0) var blast_radius: float = 0.0
## How long the telegraph hangs before it lands. A slower blow is a fairer one
## and a bigger one, which is the trade these two numbers make together.
@export_range(0.0, 4.0) var tell_delay: float = 0.0


## Whether the target's distance falls in this shot's band.
func suits(gap: float) -> bool:
	if gap < near:
		return false
	return far <= 0.0 or gap <= far


## What this shot is worth in the draw at that distance.
func draw_weight(gap: float) -> float:
	return weight if suits(gap) else stray_weight


## Whether this shot paints its projectile.
func has_tint() -> bool:
	return tint.a > 0.0


func get_sprite_path() -> String:
	return ""
