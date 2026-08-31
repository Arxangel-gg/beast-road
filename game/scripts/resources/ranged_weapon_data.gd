class_name RangedWeaponData
extends GameData

## A weapon the hero draws instead of closing (owner decision, 2026-08-31).
##
## `id = "shortbow"` -> `res://art/ranged/ranged_shortbow.png`
##
## **Melee stays the reliable default.** The reason this exists is that every
## fight resolved by walking at the nearest thing; a bow changes *which* enemy
## you deal with first. It is not meant to replace the chain, and the ammunition
## it costs is what stops it doing so - see `AmmoData`.
##
## A new bow is a `.tres`. Nothing here switches on an id.

## Which ammunition fits. A weapon only ever draws from its own family, so
## cycling can never land on something the weapon cannot fire.
@export var family: String = "arrow"

## Damage before the ammunition's own multiplier.
@export_range(1.0, 200.0) var damage: float = 14.0

## Seconds between shots. The draw *is* the cost of range - a bow that fires as
## fast as the melee chain is simply a better melee chain.
@export_range(0.15, 4.0) var draw_time: float = 0.85

## How far a shot stays lethal, and how fast it travels.
@export_range(100.0, 2000.0) var effective_range: float = 720.0
@export_range(200.0, 2400.0) var projectile_speed: float = 900.0

## How many bodies one shot passes through. One is the common case.
@export_range(1, 6) var pierce: int = 1

@export_range(0.0, 600.0) var knockback: float = 90.0

## How much the hero slows while drawing, as a fraction of move speed.
##
## Not zero, and not a stop. Standing still to shoot is a decision the player
## should feel making; being rooted is a decision the game made for them.
@export_range(0.2, 1.0) var draw_move_scale: float = 0.62


func get_sprite_path() -> String:
	return GameData.derive_path("ranged", "ranged_", id)
