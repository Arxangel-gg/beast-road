class_name GameSpeed
extends RefCounted

## The one owner of the clock's base rate (2026-09-21).
##
## A twelve-hour tower-defence campaign without a fast-forward is a pacing
## complaint in every review, and the record had nothing: `Engine.time_scale`
## was written by the hitstop, the boss-fall slow and three doors in
## `GameDirector`, every one of them putting it back to *1.0* when it was done.
## A 2x toggle laid beside those would have been undone by the first hit that
## landed - so the base rate lives here and everything that borrows the clock
## gives it back through `restore()` rather than to a literal.
##
## **Solo only, and that is a fact about the wire rather than a preference.**
## A guest's world is facts the host sends on the host's clock; a guest at 2x
## runs its own pictures twice as fast between them, and a host at 2x sends
## twice as much road per real second to a guest that cannot keep up. A session
## that is merely *hosting* refuses too, because a partner may join it.
##
## Run-scoped: `reset()` is what every door in `GameDirector` that used to write
## `Engine.time_scale = 1.0` calls now, so a run, a walk and the menu all open at
## one speed however the last one ended. Nothing persists.

static var _fast: bool = false


static func is_fast() -> bool:
	return _fast


## What the clock runs at when nothing is borrowing it.
static func chosen() -> float:
	return Balance.GAME_SPEED_FAST if _fast else 1.0


static func allowed() -> bool:
	return Coop.is_alone()


static func set_fast(on: bool) -> void:
	_fast = on and allowed()
	Engine.time_scale = chosen()


## An override - a hitstop, a slow - has ended: back to the base rate, which is
## not necessarily one.
static func restore() -> void:
	Engine.time_scale = chosen()


## A run, a walk or the menu is beginning: one speed, whatever was chosen.
static func reset() -> void:
	_fast = false
	Engine.time_scale = 1.0
