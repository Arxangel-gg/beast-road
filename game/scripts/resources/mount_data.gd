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
## **And it is faster than the Warden on foot, as of 2026-09-21.** The first
## cut held a gallop under what a sprint already reached and gave the horse a
## wind of its own, so a mount was the speed the Warden had without the SP.
## The owner re-cut both: a mount gallops past a sprint, and a mounted sprint
## **spends the rider's SP**, at a rate authored per mount. The bound that makes
## that safe is on `Balance.MOUNT_GALLOP_CEILING` and `MOUNT_GALLOP_RANGE`, and
## `mount_check` measures both through `Hero.move_speed()` and the real tick.
## A rider who spends the pool arrives winded, exactly as a runner does.

## What the stable asks for it, in Marks.
##
## **Marks and nothing else.** Materials are an input to the Smithy and nothing
## else (2026-09-13) and run currencies reset, so the only honest currency for a
## thing you keep is the account's own - which is what the stash, the Ledger and
## Orden's commission all already take.
@export var price: int = 400

## How fast this mount walks, against the Warden's own walk. Spends nothing;
## what a walk in the saddle costs is being unable to fight.
@export_range(1.0, 3.0) var speed: float = 1.35
## How fast it gallops, against the Warden's own walk. Held under
## `Balance.MOUNT_GALLOP_CEILING` by the gate, and above a sprint - a horse
## slower than the Warden's own legs is one nobody would buy.
@export_range(1.0, 3.0) var gallop: float = 1.9
## SP a second while galloping. The rider's pool, not the horse's: tuned against
## `gallop` so that a full pool carries this mount no further than
## `Balance.MOUNT_GALLOP_RANGE`, and further than the Warden's own sprint.
@export var sprint_drain: float = 17.0

## How big it is drawn, against its own art. A pony is not a warhorse.
@export_range(0.5, 2.0) var art_scale: float = 1.0
## Where the Warden sits, as a share of the mount's height above its feet. A
## rider drawn at the mount's own origin sits in the ground.
@export_range(0.0, 1.0) var seat: float = 0.62

## The order the stable lists them in, cheapest first by convention.
@export var order: int = 0


func get_sprite_path() -> String:
	return derive_path("mounts", "mount_", id)
