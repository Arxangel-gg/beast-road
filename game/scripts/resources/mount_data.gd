class_name MountData
extends GameData

## **Something to cross ground on, and nothing else** (owner, 2026-09-17).
##
## The brief: *"mounts that players can ride and the ability to get mounts from a
## vendor at the Hold with the right resources ... mounts should also have sprint
## ability. But players need to dismount to fight and they dismount when they
## attack and start fighting where they dismounted."*
##
## **The owner's own dismount rule is what makes a mount safe**, and it is worth
## stating plainly because this project has refused a third power scale about a
## dozen times. A mount cannot fight: mounted, the Warden may not swing, cast,
## loose, gather, fish or take an egg, and the first press of attack puts them on
## their feet where they stand. So a mount can never touch a number in a fight.
##
## **And it is not new speed either.** `gallop` is capped at what a sprint
## already reaches (`Balance.MOUNT_SPEED_CEILING`), so the fastest a Warden may
## cross the field is exactly what it was before mounts existed. What a mount
## buys is that speed *without spending SP* and without the Warden's own legs
## giving out - paid for by being unable to do anything else while it lasts.
## `mount_check` measures the ceiling rather than reading it.
##
## **Its stamina is its own.** A mount that drank from SP would make the pool the
## Warden sprints on a shared resource, which is a coupling nobody asked for and
## the tuning would have to answer for. The horse gets tired; the rider does not.

## What the stable asks for it, in Marks.
##
## **Marks and nothing else.** Materials are an input to the Smithy and nothing
## else (2026-09-13) and run currencies reset, so the only honest currency for a
## thing you keep is the account's own - which is what the stash, the Ledger and
## Orden's commission all already take.
@export var price: int = 400

## How fast this mount walks, against the Warden's own walk.
@export_range(1.0, 3.0) var speed: float = 1.35
## How fast it gallops. Held under `MOUNT_SPEED_CEILING` by the gate, because a
## mount is the speed the Warden already had rather than a new one.
@export_range(1.0, 3.0) var gallop: float = 1.9
## How long it can gallop for, and how fast it gets its wind back.
@export var stamina: float = 100.0
@export var stamina_drain: float = 24.0
@export var stamina_regen: float = 18.0

## How big it is drawn, against its own art. A pony is not a warhorse.
@export_range(0.5, 2.0) var art_scale: float = 1.0
## Where the Warden sits, as a share of the mount's height above its feet. A
## rider drawn at the mount's own origin sits in the ground.
@export_range(0.0, 1.0) var seat: float = 0.62

## The order the stable lists them in, cheapest first by convention.
@export var order: int = 0


func get_sprite_path() -> String:
	return derive_path("mounts", "mount_", id)
