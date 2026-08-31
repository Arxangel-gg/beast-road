class_name EnemyAffixData
extends GameData

## One thing that can be true of a promoted enemy (owner decision, 2026-08-31).
##
## `id = "rimewarded"` -> `res://art/icons/affixes/affix_rimewarded.png`
##
## **An affix is a modifier, never a branch.** Everything here is a number or a
## flag the shared enemy script already knows how to apply, which is what lets
## two of them combine without anybody writing the combination: Frozen and
## Volatile is a body that slows you and then detonates, and no code says so.
##
## Adding an affix is adding a `.tres`. That is the whole point, and it is why
## twelve breeds can become hundreds of encounters without new art or new AI.

## Multiplied into the promoted enemy's numbers.
@export_range(0.5, 6.0) var health_scale: float = 1.0
@export_range(0.5, 4.0) var damage_scale: float = 1.0
@export_range(0.4, 3.0) var speed_scale: float = 1.0

## What the body does beyond its numbers, applied by the enemy script.
##
## Kept as separate fields rather than one enum so two affixes can each
## contribute and the result is simply both - an enum would force a choice and
## make combinations impossible without a lookup table of every pair.

## Leaves a damaging bloom where it dies.
@export_range(0.0, 400.0) var death_blast_radius: float = 0.0
@export_range(0.0, 200.0) var death_blast_damage: float = 0.0

## Chills whatever it strikes.
@export_range(0.1, 1.0) var on_hit_slow: float = 1.0
@export_range(0.0, 8.0) var on_hit_slow_duration: float = 0.0

## Burns whatever it strikes.
@export_range(0.0, 120.0) var on_hit_burn: float = 0.0
@export_range(0.0, 10.0) var on_hit_burn_duration: float = 0.0

## Takes less from everything. A flat share, so it never reaches immunity.
@export_range(0.0, 0.7) var damage_resistance: float = 0.0

## Heals itself each second, as a share of its own maximum.
@export_range(0.0, 0.1) var regeneration: float = 0.0

## The tint laid over the sprite, and the colour of the outline that marks it.
## Player-facing identity: an affix the player cannot see is one they cannot
## learn to read.
@export var mark_colour: Color = Color(0.9, 0.6, 0.3)

## Which act this may first appear in, so Act I is not answering Act III.
@export_range(1, 3) var from_act: int = 1


func get_sprite_path() -> String:
	return GameData.derive_path("icons/affixes", "affix_", id)
