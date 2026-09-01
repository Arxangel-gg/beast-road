class_name HeroInput
extends RefCounted

## Where one hero's intentions come from.
##
## Step 3 of `docs/COOP_DESIGN.md`. The hero used to read `Input` directly in
## five places — attack, dash, four spell slots, movement and aim. That is
## exactly right for one hero on one machine, and co-op has two of each.
##
## The alternative was a `is this hero mine` test at each of those sites, which
## is the thing CLAUDE.md rule 5 exists to prevent: five separate decisions, five
## places to forget, and a hero that half-works when the answer is wrong. Instead
## a hero asks **its own** source and never learns which kind it is.
##
## The base returns "no input", deliberately. A hero handed a source that does
## not answer stands still rather than doing something arbitrary, and a bug in
## the wiring reads as a motionless hero instead of one that mirrors its partner.

## Buttons, as bits, so a frame of intent fits in one integer on the wire.
##
## Spells start above the two fixed buttons and are indexed by slot, so adding a
## slot costs nothing here. Values are append-only for the same reason the relay's
## enums are: an older build must not read a newer one's mask as a different key.
const BUTTON_ATTACK: int = 1 << 0
const BUTTON_DASH: int = 1 << 1
const SPELL_BIT_OFFSET: int = 2

## Things that are *held* rather than pressed, in their own mask.
##
## Separate from the button mask because the two are read differently and mixing
## them would break both: a button is an edge and is latched until read, while a
## hold is a level and must stop being true the instant the key comes up. A
## latched hold would revive a partner somebody had already let go of.
## **Numbered clear of the button bits, and that is not cosmetic.**
##
## `held()` dispatches on the mask *value*, so a hold sharing a bit with a button
## is indistinguishable from it. `HOLD_REVIVE` was `1 << 0` — the same as
## `BUTTON_ATTACK` — and the first branch won: holding the attack button filled a
## partner's revive bar and the revive key did nothing at all. Reported from
## play as "it says Hold E but it wants left mouse".
##
## Two namespaces sharing one dispatch need two ranges. Holds start at bit 8,
## which leaves room for six more spell slots before anything can collide again.
const HOLD_REVIVE: int = 1 << 8

## Touch auto-attack is a held intention and must cross the wire as one. Keeping
## it out of BUTTON_ATTACK preserves keyboard/mouse edge-triggered attacks while
## a phone's right stick can continue a chain for as long as the thumb is down.
const HOLD_ATTACK: int = 1 << 9

## Ranged combat (owner decision, 2026-08-31).
##
## **Bit 12 and up, clear of both namespaces.** Bits 2 to 7 are spoken for by
## spell slots and 8 to 11 by holds; putting a button in either range is the
## collision the comment above is about, and it was found the hard way once
## already. There is no shortage of bits, so the fix is to leave the ranges
## alone rather than to reuse the gaps in them.
const BUTTON_RANGED: int = 1 << 12
const BUTTON_AMMO_CYCLE: int = 1 << 13

## The hero this speaks for. Needed by the local source, which asks the hero
## where it is in order to aim from the mouse.
var hero: Node2D = null


func _init(for_hero: Node2D = null) -> void:
	hero = for_hero


## The bit for a spell slot.
static func spell_button(slot: int) -> int:
	return 1 << (SPELL_BIT_OFFSET + slot)


## Direction the player is asking for, unnormalised, zero when still.
func move() -> Vector2:
	return Vector2.ZERO


## Where the hero is pointing.
##
## `previous` is returned when there is nothing to say. Both real sources fall
## back to it rather than to a default direction, because a hero that snaps east
## every time a stick centres reads as broken.
func aim(previous: Vector2) -> Vector2:
	return previous


## Whether a button was pressed *this frame*. Edge-triggered, not held.
func pressed(button: int) -> bool:
	return false


## Whether something is being held down right now. Level, not edge.
func held(_mask: int) -> bool:
	return false


## True for the hero this machine's player is driving.
##
## The camera follows it, the HUD describes it, and it is the one whose input is
## worth sending anywhere.
func is_local() -> bool:
	return false


## Where the player is pointing, from the point a shot actually leaves.
##
## Static and taking its origin as an argument, because **the origin is the part
## that was wrong**. Aim used to be measured from `hero.global_position`, which
## is the hero's *feet* - the node is deliberately moved down to its ground
## contact so the shared Y sorter has a meaningful depth key - while every arrow,
## swing and spell leaves from `combat_origin()`, the same point lifted back up
## to the chest. Two parallel lines about fifty units apart: at three hundred
## units of range that is nearly ten degrees, and much worse up close.
##
## Written here, once, so a second caller cannot make the same choice again, and
## so `ranged_check` can hold the rule without standing up a battlefield.
static func aim_at(origin: Vector2, cursor: Vector2, previous: Vector2) -> Vector2:
	var delta: Vector2 = cursor - origin
	# Below a unit the cursor is on top of the hero and there is no direction to
	# read; snapping east there would spin the hero every time it passed under
	# the pointer.
	return delta.normalized() if delta.length() > 1.0 else previous
