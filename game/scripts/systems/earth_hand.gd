class_name EarthHand
extends RefCounted

## **Whether the blow landing now is the earth's own** (2026-10-07).
##
## The earth minds blood (owner, 2026-10-07: *"Earth's wrath ... should be
## affected to a much much smaller amount by the bloodshed of enemies as well
## as players"*), and a spectator does not hold against anybody the blood its
## own blows drew - an earth that raged at what its own quake cost would feed
## itself, which is the rule the grief of 2026-10-01 is built on too.
##
## Every blow of the earth's on a Warden - a bolt, a stone, a funnel's wake
## and its carry, a blaze, the ground wave, the hazards - opens this before it
## strikes and closes it after. A value, never an object, so the static
## outlives nothing; and the sky settles it every frame, so a blow that aborted
## half way can never leave the earth's hand raised over the next fight.

static var _depth: int = 0


static func open() -> void:
	_depth += 1


static func close() -> void:
	_depth = maxi(_depth - 1, 0)


static func striking() -> bool:
	return _depth > 0


## Once a frame, from the sky: nothing is struck across a frame boundary.
static func settle() -> void:
	_depth = 0
