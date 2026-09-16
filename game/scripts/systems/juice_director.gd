class_name JuiceDirector
extends RefCounted

## **What is the most important thing on screen right now.** Static only.
##
## Owner's forwarded list of 2026-09-16 put a juice director first of two
## hundred items and `docs/IDEAS_REVIEW_2026-09-16.md` agreed with that
## placement. Every effect in this game is emitted at its call site - `Enemy`
## decides its own sparks, `Tower` its own kick, `Meteor` its own rings - which
## is *correct*, and is why the game feels as it does. What it cannot do is
## answer two questions: **is this worth the player's attention compared to
## everything else happening**, and **can this whole class of effect be turned
## down**.
##
## So this is not a second effects system and must never become one. It is one
## number - a weight between a floor and one - that the places which finally
## decide a presentation multiply by.
##
## **The bound, and it is the one every feel change in this project is held
## to:** a director may change how something is *presented* and never whether it
## happened. Turn every scale to zero, fill the clutter to its ceiling, and the
## run is byte-identical - same damage, same drops, same kills, same wave.
## `juice_director_check` proves that by driving a real body to death with
## everything off and reading the payout back.
##
## **Clutter is derived rather than ticked**, which is what lets this be a
## static class with no node, no `_process` and no place in the scene tree: each
## note records a load and a time, and a read decays from the elapsed time on
## the spot. That also makes it exactly reproducible for a gate, which can hand
## in its own clock instead of waiting.

## What a moment is for, in the order the accessibility notes ask for:
## telegraph, hazard, boss, player, cosmetic.
##
## **The order is the whole design.** A telegraph is the game telling the player
## what is about to hurt them; it is never damped, whatever else is on screen,
## because a warning that is turned down under load is turned down at exactly
## the moment it is needed. Everything below it gives way in order, so what a
## busy frame loses is decoration rather than information.
enum Priority { TELEGRAPH, HAZARD, BOSS, PLAYER, COSMETIC }

## How much a moment of each priority adds to the load.
##
## A telegraph adds nothing at all: it must not crowd itself out, and two
## warnings on screen is a situation the player needs to see both halves of.
const LOAD: Array[float] = [0.0, 0.5, 0.45, 0.3, 0.22]

## The least a moment of each priority may ever be turned down to.
##
## A telegraph never moves. A cosmetic effect may fall to a fifth - still
## present, because an effect that vanishes reads as a bug rather than as
## restraint, and the player should never be unable to tell that something
## happened.
const FLOOR: Array[float] = [1.0, 0.72, 0.68, 0.48, 0.2]

## Load at which a priority reaches its floor. Below this the weight rides down
## smoothly, so an ordinary fight is untouched and only a genuinely busy one
## gives anything up.
const FULL_LOAD: float = 4.0

## Where the damping begins. Under this nothing is turned down at all - the
## quiet game must feel exactly as it always did.
const QUIET_LOAD: float = 1.1

## How long a moment's load takes to fall to about a third of itself.
const DECAY_SECONDS: float = 1.35

## The ceiling on accumulated load, so a wave of forty bodies does not park the
## director at its floor for the rest of the act.
const MAX_LOAD: float = 6.0

static var _load: float = 0.0
static var _at_msec: int = 0


## The weight a moment of this priority is worth right now, between its floor
## and one. Multiply a magnitude by it; never a number that matters.
static func weight(priority: int) -> float:
	var floor_at: float = FLOOR[clampi(priority, 0, FLOOR.size() - 1)]
	if floor_at >= 1.0:
		return 1.0
	var busy: float = clampf((load_now() - QUIET_LOAD) / maxf(FULL_LOAD - QUIET_LOAD, 0.01),
		0.0, 1.0)
	# Smoothed rather than linear, so the moment the room gets busy is not a step
	# the player can see everything change on.
	return lerpf(1.0, floor_at, busy * busy * (3.0 - 2.0 * busy))


## Records that a moment of this priority happened. Called by whatever is about
## to draw it, after asking for its weight - so a moment pays for the room it
## takes up rather than for the room it asked about.
static func note(priority: int) -> void:
	var add: float = LOAD[clampi(priority, 0, LOAD.size() - 1)]
	if add <= 0.0:
		return
	_load = minf(load_now() + add, MAX_LOAD)
	_at_msec = Time.get_ticks_msec()


## The load as it stands, decayed from when it was last written.
static func load_now() -> float:
	if _load <= 0.0:
		return 0.0
	var since: float = float(Time.get_ticks_msec() - _at_msec) * 0.001
	if since <= 0.0:
		return _load
	return _load * exp(-since / maxf(DECAY_SECONDS, 0.01))


## Forgets everything. Called where a scope changes - a raid, a rift, a new run -
## because the load is a fact about what is on *this* screen.
static func clear() -> void:
	_load = 0.0
	_at_msec = Time.get_ticks_msec()


## For a gate: sets the load directly and dates it now, so a busy screen can be
## tested without spending a second and a half producing one.
static func set_load_for_test(value: float) -> void:
	_load = clampf(value, 0.0, MAX_LOAD)
	_at_msec = Time.get_ticks_msec()


# --- What the player asked for ------------------------------------------------
#
# The accessibility notes (#182-#195 of the forwarded list) ask for these as
# *scales* rather than as switches, which is the part `Graphics` was missing: it
# could turn the fog off and the phenotypes off, and it had nothing to say to a
# player who wants half the shake rather than none of it.

## How hard the camera may be moved, as a share of what was asked for.
##
## The slider itself is older than this class; what is new is that it is read
## here rather than off `MetaState.settings` at the one site that happened to
## remember it.
static func shake_scale() -> float:
	return clampf(UserSettings.number(UserSettings.SHAKE_KEY, 1.0), 0.0, 1.0)


## How bright a full-screen flash may be, as a share of what was asked for.
static func flash_scale() -> float:
	return clampf(UserSettings.number(UserSettings.FLASH_KEY, 1.0), 0.0, 1.0)


## Whether a damage number of this importance is drawn at all.
##
## Density rather than a switch: at a half the ordinary numbers thin out and the
## big ones - a critical, a finisher - still land, because what a player turning
## this down wants is fewer numbers rather than less information.
static func wants_number(big: bool) -> bool:
	var density: float = clampf(
		UserSettings.number(UserSettings.NUMBER_DENSITY_KEY, 1.0), 0.0, 1.0)
	if density >= 1.0:
		return true
	if density <= 0.0:
		return false
	if big:
		# A big number survives until the density is nearly off.
		return density > 0.15
	return randf() < density
