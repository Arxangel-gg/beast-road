class_name WaveArchetypeData
extends GameData

## An authored tactical problem for the wave director.
##
## Raw count and stat growth decide how hard a wave is. This resource decides
## why it is hard: a fast rush, one armoured lane, an opposite-lane pincer, or
## pressure everywhere at once. Keeping these as content means designers can
## tune the run's vocabulary without adding branches to WaveDirector.

enum LanePattern {
	## Uses the normal one-to-four-lane act progression.
	ESCALATING,
	## Concentrates the whole budget into one lane.
	FOCUSED,
	## Always attacks two opposite lanes.
	OPPOSITES,
	## Attacks every lane.
	ALL,
}

@export var lane_pattern: LanePattern = LanePattern.ESCALATING
## The earliest act this formation may be dealt in.
##
## **Was capped at 3 on a ten-act road**, so acts IV to X drew from exactly the
## pool Act I did and the back two thirds of the campaign never met a formation
## of its own. Widened 2026-09-15; the sixth hardcoded three-act range found here.
@export_range(1, 10) var minimum_act: int = 1
@export var minimum_act_wave: int = 1
@export var selection_weight: float = 1.0
@export var night_weight_multiplier: float = 1.0

@export var count_scale: float = 1.0
@export var hp_scale: float = 1.0
@export var damage_scale: float = 1.0
@export var speed_scale: float = 1.0
@export var spawn_spacing_scale: float = 1.0

## A signature unit added to each attacked lane. Empty means the terrain breed
## carries the pattern by itself. The id is validated by the balance gate.
@export var signature_enemy_id: String = ""
## Optional regional role selector. The fallback id preserves compatibility and
## supplies a veteran when the current faction lacks the requested role.
@export_range(-1, 4) var signature_role: int = -1
@export var signature_count_per_lane: int = 0
@export var extra_elites: int = 0

## Sequenced formations may show a small commitment on one road, hold, then
## reveal the real assault next door. Most formations stay fully shuffled.
@export var delayed_adjacent_surge: bool = false
@export var surge_delay: float = 0.0
@export_range(0.1, 0.9) var false_front_fraction: float = 0.35

## **A wave with nothing in it.**
##
## The "quiet before the storm" the forwarded list asked for, and the one thing
## in that library this game could not already express. The road still advances,
## the purse still earns off the trickle, and the player gets the stretch to
## build, gather, fish, work a seam or walk out to a camp - which is the whole
## reason the outskirts exist and the one thing a wave every ninety seconds
## leaves no room for.
##
## **It is not free.** A calm wave pays no kill income at all, so taking one is
## a wave of purse the player does not get - and against a boss ramp that keeps
## climbing, a breather costs something real. That is what stops it being a
## strictly better wave.
##
## Deliberately rare and deliberately late: `selection_weight` and
## `minimum_act` carry that, not a special case here.
@export var calm: bool = false

## **How the formation arrives** (2026-09-24). SCATTERED is the shuffle every
## wave had. VANGUARD sends the leaders ahead of the horde - the signature
## bodies, the elites, and a share of the ordinary bodies drawn from the
## tanking roles (`Balance.WAVE_VANGUARD_SHARE`, `_ROLES`) - so a road reads
## "the shields are here and the rest is behind them", which is the owner's
## "tankier/siege enemies before hordes of lighter units". REARGUARD is the
## reverse: the horde first, the leaders last. **A look at the queue's order
## and never at what is in it**: the same bodies at the same strength, so
## `curve_report` reads the same waves. Appended, never inserted - the data
## indexes this by number.
enum Formation { SCATTERED, VANGUARD, REARGUARD }
@export var formation: Formation = Formation.SCATTERED


func is_available(act: int, act_wave: int) -> bool:
	return act >= minimum_act and act_wave >= minimum_act_wave
