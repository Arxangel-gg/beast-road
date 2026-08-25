class_name RemoteHeroInput
extends HeroInput

## The partner's hero, driven by what arrived over the wire.
##
## Holds the last snapshot rather than a queue. A stick position is a *level*,
## not an event: if two move packets arrive between physics frames, the newer one
## is simply the truth and replaying the older one would be a stutter.
##
## Buttons are the opposite and are treated so. A press is an *edge*, and edges
## are latched until read: packets and physics frames do not line up, so a press
## that arrived between two ticks would otherwise be dropped — the attack that
## never came out, once every few seconds, for no reason the player can see.

var _move: Vector2 = Vector2.ZERO
var _aim: Vector2 = Vector2.ZERO
var _has_aim: bool = false

## Presses received and not yet consumed. OR-ed in, cleared per bit on read.
var _pending: int = 0

## What the partner is holding down right now. Assigned rather than OR-ed: a
## hold is a level, and latching it would keep reviving after they let go.
var _held: int = 0

## Frames since anything arrived, so a silent partner can be told from a still
## one. Nobody reads it yet; step 6 answers what a dropped partner looks like.
var _quiet_for: float = 0.0


## Takes one snapshot from the wire. Shape matches `LocalHeroInput.snapshot`.
func apply(snapshot: Array) -> void:
	if snapshot.size() < 3:
		return
	# Holds were added after the first shape. Tolerated rather than required so a
	# snapshot built by anything that predates them still applies cleanly.
	_held = int(snapshot[3]) if snapshot.size() > 3 else 0
	_move = snapshot[0] as Vector2
	_aim = snapshot[1] as Vector2
	_has_aim = _aim != Vector2.ZERO
	# OR rather than assign: two presses arriving before the hero next ticks are
	# both real, and the second must not erase the first.
	_pending |= int(snapshot[2])
	_quiet_for = 0.0


func tick(delta: float) -> void:
	_quiet_for += delta


## Seconds since the last snapshot arrived.
func quiet_for() -> float:
	return _quiet_for


## Forgets everything, without pretending the partner is still holding a key.
##
## Used when a partner leaves. A remote hero left holding its last move vector
## would walk into a wall forever, which is the same failure the touch controls
## had when a hidden stick kept its action pressed.
func held(mask: int) -> bool:
	return (_held & mask) != 0


func clear() -> void:
	_move = Vector2.ZERO
	_aim = Vector2.ZERO
	_has_aim = false
	_pending = 0
	_held = 0


func move() -> Vector2:
	return _move


func aim(previous: Vector2) -> Vector2:
	return _aim if _has_aim else previous


func pressed(button: int) -> bool:
	if _pending & button == 0:
		return false
	# Consumed by reading, so one press produces one action however many frames
	# pass before the hero asks.
	_pending &= ~button
	return true
