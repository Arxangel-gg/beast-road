class_name CampaignTierData
extends GameData

## One campaign difficulty, in the Diablo sense: the whole game again, harder,
## unlocked by finishing the one below it.
##
## Distinct from `RoadDifficultyData`, which is the choice between two cards at a
## crossroad *within* a run. This is the choice made before a run starts, and it
## is the frame the hero grinds against.
##
## Introduced 2026-08-20 with persistent hero levels (GDD §974, amended). The two
## are one design and neither works alone: tiers without persistence ask a player
## to beat Hell with a level-one hero, and persistence without tiers means a
## hundred levels of growth against a curve that stops at Act III.

## Ascending. 0 is the tier a new player starts on.
@export var order: int = 0

## Enemy scaling for the whole campaign at this tier.
@export var hp_scale: float = 1.0
@export var damage_scale: float = 1.0
@export var speed_scale: float = 1.0

## What a prepared hero is expected to be worth at each act boss.
##
## An expectancy, not a lock. Being under it is meant to be survivable and
## obviously hard — the HUD says so before the gate — because a hard wall that
## says "come back later" wastes the run a player already spent forty minutes on,
## while a fight they can see going badly teaches them what to grind for.
@export var boss_levels: Array[int] = [1, 1, 1]

## Multipliers on what the tier pays out, so a harder run is worth running.
@export var xp_scale: float = 1.0
@export var loot_scale: float = 1.0

## What a run on this tier is worth on the leaderboard.
##
## Applied to the finished score rather than to any one term, so it scales the
## whole run. Boards are read per tier anyway; this is what keeps a Hell run from
## sorting below a Normal one on a combined view.
@export var score_scale: float = 1.0

## Shown on the difficulty picker under the name.
@export var summary: String = ""

# --- Rules, not numbers (2026-09-25) ------------------------------------------
#
# A tier was five multipliers, so Hell was Normal with bigger numbers. These
# make it a different road with the same content: which bodies wear marks, what
# a boss brings with it, and how angry the earth is when the road begins. All
# zero on Normal, which is where every curve in the project is measured.

## The share of ordinary road bodies that wear marks. See `EnemyMarks`.
@export_range(0.0, 0.6) var marked_share: float = 0.0
## How many marks such a body may wear: one to this.
@export_range(0, 3) var marks_max: int = 0
## How many marks an act boss wears. A boss wears a mark's behaviour and never
## its size - see `Enemy._mark_scale`.
@export_range(0, 3) var boss_marks: int = 0
## The floor the earth's wrath never falls below on this tier: where it opens,
## what an act's easing leaves, and what quiet cannot take away.
@export_range(0.0, 0.5) var wrath_floor: float = 0.0


## The hero level this tier expects at the given act's boss.
func expected_level(act: int) -> int:
	if boss_levels.is_empty():
		return 1
	return boss_levels[clampi(act - 1, 0, boss_levels.size() - 1)]


## The tier that must be cleared before this one opens. Empty for the first.
func requires_order() -> int:
	return order - 1
