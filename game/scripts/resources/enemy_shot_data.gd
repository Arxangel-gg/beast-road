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
