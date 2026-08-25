class_name TrapData
extends GameData

## One kind of trap, laid on a road during Preparation.
##
## **Traps go *on* the road, which is the opposite of every other placement rule
## in the game.** A tower may not stand on a lane; a trap is worthless anywhere
## else. That inversion is the whole reason this is its own resource and its own
## placement path rather than a `TowerData` with a flag — a flag would mean every
## caller of `placement_problem` had to remember which way round it was reading.
##
## **They are Preparation-placed, and that is not negotiable.** CLAUDE.md §1 locks
## construction to Preparation and says not to reopen it. A trap dropped
## mid-combat would reopen exactly that decision, so laying one asks the same
## `RunState.can_build_now()` every other build path asks — the single gate that
## makes the decision reversible in one line if it ever is reversed.
##
## They are **consumed**: a trap has a number of triggers and then it is gone.
## That is what stops a lane being solved once and stopping being a lane, and it
## is why a trap can be strong without being a tower that costs less.

## How many times it can fire before it is spent.
@export_range(1, 20) var triggers: int = 3

## Seconds after being laid before it will fire.
##
## Small, but not zero. A trap that arms instantly can be dropped on top of
## something already standing on it, which reads as a mistake rather than as a
## trap.
@export_range(0.0, 6.0) var arm_seconds: float = 0.8

## Damage per trigger, before any hero modifier — a trap is the *town's*, not the
## hero's, so it is deliberately unscaled by hero damage.
@export_range(0.0, 900.0) var damage: float = 90.0

## How far the effect reaches from the trap's own tile.
@export_range(16.0, 400.0) var radius: float = 96.0

## Knockback dealt to everything caught.
@export_range(0.0, 900.0) var knockback: float = 0.0

## Movement multiplier applied to everything caught. 1 means no slow.
@export_range(0.05, 1.0) var slow_factor: float = 1.0

## How long that slow lasts.
@export_range(0.0, 20.0) var slow_duration: float = 0.0

## Burn damage per second applied to everything caught, and for how long.
@export_range(0.0, 200.0) var burn_dps: float = 0.0
@export_range(0.0, 20.0) var burn_duration: float = 0.0

## What it costs to lay. Keys match `RunState`'s currency ids.
@export var cost: Dictionary = {}

## Tint for the arming pulse and the trigger burst.
@export var colour: Color = Color(0.9, 0.76, 0.42)


func get_sprite_path() -> String:
	return GameData.derive_path("traps", "trap_", id)
