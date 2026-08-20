extends Node

## Every tuning constant in the game, in one place.
##
## Autoloaded as `Balance`. Gameplay scripts must never contain a magic number —
## if a value could ever be argued about, it belongs here with a GDD reference.
##
## Section markers (§) point at docs/Game_Design_v3.md. Values the GDD tags
## `[TUNE]` are starting values chosen to make the system buildable, not balance
## claims. Expect all of them to move.
##
## No `class_name` here: the autoload singleton is already named `Balance`, and
## declaring a global class of the same name is a hard error in Godot 4.

# ==============================================================================
# BATTLEFIELD — GDD §3.1
# ==============================================================================

## Radius from the city centre to each of the four N/S/E/W tower slots. [TUNE]
const TOWER_SLOT_RADIUS: float = 270

## Radius of the arena edge; enemies spawn on this ring. [TUNE]
const ENEMY_SPAWN_RADIUS: float = 720

## Hero base movement speed. The GDD calls this the hero's most valuable stat:
## N tower -> S tower is ~2.5s, long enough that the choice costs something. [TUNE]
const HERO_MOVE_SPEED: float = 200.0

## Enemy walk speed. Spawn ring -> tower ring is ~9s, the player's reaction
## window. Tune as a set with HERO_MOVE_SPEED and ENEMY_SPAWN_RADIUS. [TUNE]
const ENEMY_WALK_SPEED: float = 33

## Tower firing range. Slight overlap between adjacent slots so the diagonals
## have no dead zones. [TUNE]
const TOWER_RANGE: float = 350

## Duration of the dash's invulnerability window. [TUNE]
const HERO_DASH_IFRAMES: float = 0.3

## Dash cooldown. [TUNE]
const HERO_DASH_COOLDOWN: float = 4.0

## Maximum spells equipped at once (GDD §2, decision 4).
const HERO_MAX_SPELL_SLOTS: int = 4
const HERO_ACTIVE_SLOTS: int = 4
const DISCIPLINE_IDS: Array[String] = ["blood", "holy", "berserk"]
const DISCIPLINE_MAX_TRAINED: int = 6

# --- Hero levelling ----------------------------------------------------------
#
# Run-scoped, and that is a v4 requirement rather than a simplification: SS974
# reads "No uncapped stat bonus, hero level, building tier, captive level, or
# automatic damage growth persists." A hero may grow enormously inside a run and
# starts the next one at level one, which is also what keeps the difficulty curve
# meaningful - a run that begins strong has nothing left to earn.

# --- Loot ---------------------------------------------------------------------
#
# Drops are a *bonus* on top of the guaranteed kill payout, never a replacement
# for it. The difficulty curve was tuned against guaranteed income, so making the
# base collectable would quietly cut a passive player's economy and re-harden a
# game that had just been balanced. A bonus can only add.

## Share of a kill's resources dropped again as collectable loot. [TUNE]
const LOOT_BONUS_SHARE: float = 0.45

## Chance a kill drops anything at all. Below one so drops are an event rather
## than a constant stream of coins to walk over. [TUNE]
const LOOT_DROP_CHANCE: float = 0.34

## An elite or boss always drops, and drops more.
const LOOT_ELITE_MULTIPLIER: float = 3.0

## Distance at which a drop starts flying to the hero.
##
## Generous on purpose: chasing coins is not the interesting part, being out on
## the road is. The magnet is what makes fighting forward pay without turning the
## reward into a second job. [TUNE]
const LOOT_MAGNET_RANGE: float = 260.0
const LOOT_COLLECT_RANGE: float = 34.0
const LOOT_MAGNET_SPEED: float = 780.0
const LOOT_MAGNET_ACCELERATION: float = 2600.0

## How a drop leaves the corpse, so a pack that dies together scatters.
const LOOT_SCATTER_SPEED: float = 190.0
const LOOT_DRAG: float = 420.0

## Seconds before an uncollected drop pays out on its own and fades.
##
## It pays rather than expiring. Losing a reward already earned by killing the
## thing teaches a player to stop fighting and stand on the road hoovering, which
## is worse than either extreme. [TUNE]
const LOOT_LIFETIME: float = 24.0

## Painted drop art, by currency id. Absent falls back to the UI icon.
const LOOT_ART_FORMAT: String = "res://art/loot/loot_%s.png"

## The pool of light under a drop, which is what makes it findable on a lit road.
const LOOT_GLOW_COLOUR: Color = Color(1.0, 0.86, 0.52, 0.5)
const LOOT_GLOW_SIZE: float = 72.0
const LOOT_GLOW_SPEED: float = 3.1

const LOOT_ICON_SIZE: float = 26.0
const LOOT_BOB_SPEED: float = 5.0
const LOOT_BOB_HEIGHT: float = 3.0
const LOOT_Z_INDEX: int = -2

## How much gear the stash holds.
##
## Finite on purpose. An unlimited stash means a player never chooses what to
## keep, and "which of these do I break for shards" is the decision the
## blacksmith exists to pose. [TUNE]
const STASH_CAPACITY: int = 40

## Chance a raid chest also yields a piece of gear.
const GEAR_CHEST_CHANCE: float = 0.34

## Marks paid for finishing a run, before the tier multiplier.
const RUN_MARKS_REWARD: int = 45

## What a losing run still pays, as a share of a winning one. [TUNE]
const RUN_MARKS_LOSS_SHARE: float = 0.55

const HERO_MAX_LEVEL: int = 100

## Runs per tier that `tools/level_curve.tscn` simulates. Reporting only.
const LEVEL_CURVE_RUNS_PER_TIER: int = 3

## XP needed to leave level L is HERO_XP_BASE * L^HERO_XP_CURVE.
##
## Superlinear so late levels are earned rather than collected, but well under
## quadratic: at 2.0 the last ten levels cost more than the first ninety and the
## curve stops paying out exactly when the player most needs it to. [TUNE]
const HERO_XP_BASE: float = 17.0
const HERO_XP_CURVE: float = 1.42

## XP a kill is worth, per point of the enemy's maximum health.
##
## Tied to health rather than to a per-enemy authored number so that an elite is
## worth more than a runner without anyone maintaining a second table, and so
## that act scaling carries the curve forward on its own. Calibrated by
## `tools/level_curve.gd` against a full three-act run. [TUNE]
## Solved against a measured run rather than guessed: `tools/level_curve.tscn`
## counts 640 kills carrying about 48,000 points of health across three acts, and
## reaching 100 over that needs roughly ten XP per point. The first guess of 0.62
## ended the game at level 31.
## Trimmed after the rebalance raised enemy health, which raised XP with it.
## The hero should arrive at the summit still a few levels short: reaching the
## cap on the last kill of Act III leaves the Final Ascent - the longest fight in
## the run - with nothing left to earn.
## Retuned 2026-08-20 for persistent levels across three campaign tiers.
##
## At 5.4 a single run took the hero from 1 to 97, which was right when levels
## reset and is wrong now that they do not: the whole climb would be over before
## Nightmare had been unlocked, and there would be nothing to grind for.
##
## The target is a Normal clear landing near 30 - the tier's own Act III boss
## expectancy - with Nightmare and Hell carrying the rest through their own XP
## multipliers. Measured with `tools/level_curve.tscn`. [TUNE]
const HERO_XP_PER_HP: float = 0.30

## Levels between skill points. Twenty across a full run.
const HERO_SKILL_POINT_EVERY: int = 5

## Levels between one more discipline node being allowed.
##
## The trained cap starts at DISCIPLINE_MAX_TRAINED and grows with this, so
## levelling opens the tree rather than only filling a bar.
const HERO_DISCIPLINE_CAP_EVERY: int = 20

## Per-point attribute gains, as fractions.
##
## Small individually and bounded by the point total: a hundred points is one
## run's entire growth, so a single-attribute build ends around +110% of its
## chosen stat. Deliberately not enough to carry a player who never builds a
## tower, and enough that fighting well is worth more than standing at the base.
## [TUNE]
const HERO_MIGHT_PER_POINT: float = 0.011
const HERO_VIGOUR_PER_POINT: float = 0.010
const HERO_SWIFTNESS_MOVE_PER_POINT: float = 0.0055
const HERO_SWIFTNESS_ATTACK_PER_POINT: float = 0.006
const HERO_FOCUS_COMMAND_PER_POINT: float = 0.009
const HERO_FOCUS_SPELL_PER_POINT: float = 0.008
const DISCIPLINE_RESPEC_BASE_COST: int = 45
const DISCIPLINE_RESPEC_COST_STEP: int = 30

## Spells offered to choose from on level-up; the player picks one (GDD §2).
const SPELLS_OFFERED_ON_LEVEL_UP: int = 3

# ------------------------------------------------------------------------------
# War horn — GDD §3.1
# ------------------------------------------------------------------------------

## How long the horn's pull window lasts.
const WAR_HORN_DURATION: float = 25

## Permanent enemy HP and damage increase applied per horn use, for the rest of
## the run. This is the horn's delayed cost. [TUNE]
const WAR_HORN_ESCALATION_PER_USE: float = 0.1

# ==============================================================================
# CITY — GDD §3.2
# ==============================================================================

## Construction is gated by distance travelled, not real time. A tier-1 build is
## roughly 2.5 minutes of walking at full beast speed. [TUNE]
const BUILD_COST_TIER_1: float = 150.0
const BUILD_COST_TIER_2: float = 300.0
const BUILD_COST_TIER_3: float = 500.0

## Only one construction may be in progress at a time. Queueing is the
## difference between a decision and a checklist.
const CITY_BUILD_SLOTS: int = 1

## Relic sockets granted by each Town Hall tier (index 0 = tier 1).
const TOWN_HALL_RELIC_SLOTS: Array[int] = [1, 2, 3, 4]

# ==============================================================================
# MACRO / THE JOURNEY — GDD §3.3
# ==============================================================================

const ACT_COUNT: int = 3
const SEGMENTS_PER_ACT: int = 3

## Distance units in one segment; segment boundaries are crossroads.
const SEGMENT_DISTANCE: float = 300.0

## 3 segments per act.
const ACT_DISTANCE: float = 900.0

## 3 acts. Filling this bar is the win condition (GDD §2, decision 1).
const JOURNEY_TOTAL_DISTANCE: float = 2700.0

## The Final Ascent (GDD v4 §"Final Ascent - Crown of the World").
##
## A short authored climb after Act III rather than a fourth act: no crossroads,
## no fork, one road to the summit. v4 budgets 6-8 minutes for the ascent and the
## Chainmaker together, and 600 is about two segments of walking with the boss at
## the end of it. [TUNE]
const FINAL_ASCENT_DISTANCE: float = 600.0

## The act index the ascent reports. One past ACT_COUNT on purpose: every
## per-act table clamps to its last entry, so the ascent inherits Act III's
## scaling rather than needing a fourth column in each of them.
const FINAL_ASCENT_ACT: int = ACT_COUNT + 1

## Beast walking speed in distance units per second. At full speed this is
## ~15 min per act, ~45 min per run. [TUNE]
const BEAST_BASE_SPEED: float = 1.0

## The beast never slows below this, so a bad stretch is punishing but not a
## death spiral. [TUNE]
const BEAST_SPEED_FLOOR: float = 0.5

## Enemy count spikes over the final stretch of each act as the ramp signal
## into the boss (GDD §6).
const ACT_BOSS_RAMP_DISTANCE: float = 100.0

# ==============================================================================
# RAID — GDD §3.4
# ==============================================================================

## Length of a raid. The battlefield keeps simulating for all of it. [TUNE]
const RAID_DURATION: float = 60.0

## Teleport time in each direction.
const RAID_TELEPORT_COOLDOWN: float = 15.0

## How far a hit varies either side of its nominal damage.
##
## Every blow landing for exactly the same number reads as arithmetic rather than
## as combat: two identical towers shooting the same enemy produce a metronome.
## A spread makes each shot feel like an event without changing what a tower is
## worth, because the average is unchanged - which matters, since every balance
## number in this file is written as an average. [TUNE]
const DAMAGE_SPREAD: float = 0.18

# ==============================================================================
# TOWERS & FUSION — GDD §4
# ==============================================================================

## Two adjacent towers of the same element grant this damage bonus instead of a
## fusion, so mono-element is a real strategy rather than a mistake. [TUNE]
const SAME_ELEMENT_DAMAGE_BONUS: float = 0.25

## Four slots in a ring means four adjacencies per loadout.
const TOWER_SLOT_COUNT: int = 4

# ==============================================================================
# CROSSROADS — GDD §5
# ==============================================================================

const CROSSROADS_PER_ACT: int = 3
const CROSSROADS_PER_RUN: int = 9

## Two cards are compared, drawn from five authored road archetypes. [TUNE]
const CROSSROAD_OPTIONS_SHOWN: int = 2
## A completed Relic Hunt offers a concise choice, not a random silent drop.
const ROAD_RELIC_CHOICES: int = 3

# ==============================================================================
# META-PROGRESSION — GDD §7
# ==============================================================================

## The single sanctioned concession to persistence: clearing Act 3 grants one
## extra starting Town Hall relic slot, capped at +1. Nothing else carries over.
const ACT3_CLEAR_BONUS_RELIC_SLOTS: int = 1

# ==============================================================================
# COMBAT FEEL — NOT SPECIFIED BY THE GDD
# ==============================================================================
#
# The GDD fixes the distances and the dash, but gives no HP, damage or attack
# timing numbers. Everything below was picked to make combat playable rather
# than to balance it. Treat all of it as provisional.

# ------------------------------------------------------------------------------
# Arena
# ------------------------------------------------------------------------------

## The hero is clamped to the spawn ring, so the playable floor and the arena
## edge are the same circle and there is nowhere enemies do not come from.
const ARENA_RADIUS: float = ENEMY_SPAWN_RADIUS

## Camera zoom, per scope. Godot zooms IN above 1.0 and OUT below it.
##
## The battlefield is ~1800px across against a 1080px-tall viewport, and the
## player has to be able to see which lane is collapsing — that is the entire
## decision loop — so it is pulled back far enough to hold the whole ring.
## The raid is an open arena with no lanes to read, so it sits closer and the
## swing stays legible. [TUNE]
const CAMERA_ZOOM: float = 0.72
## Framed for the authored 45x45 field.
##
## 0.77 framed the old 30x30 arena, where the whole map was two screens across.
## The authored map is 2880 units on a side, and at that zoom a player standing
## at the gate could not see the junction the road forks at - so the choice the
## map is built around happened entirely off screen. Pulled out to show about
## two thirds of the field's width at 1080p, which puts a fork and the ground
## either side of it in view together. [TUNE]
const CAMERA_ZOOM_BATTLEFIELD: float = 0.52
const CAMERA_ZOOM_RAID: float = 0.95

## Mouse-wheel battlefield range. Reaching the minimum and continuing outward
## moves through Town and Beast rather than shrinking the tactical map into an
## unreadable postage stamp.
const CAMERA_ZOOM_BATTLEFIELD_MIN: float = 0.38
const CAMERA_ZOOM_BATTLEFIELD_MAX: float = 1.00
const CAMERA_ZOOM_STEP: float = 0.10
const CAMERA_ZOOM_LERP_SPEED: float = 12.0

## Camera lag. Lower is snappier, higher is floatier.
const CAMERA_SMOOTHING_SPEED: float = 8.0

## How far the camera leans toward the mouse, as a fraction of the hero-to-mouse
## offset. Gives a little lookahead without taking control away.
const CAMERA_MOUSE_LEAN: float = 0.19
const CAMERA_MOUSE_LEAN_MAX: float = 300.0

## The battlefield is carried on a walking colossus. A very small elliptical
## camera drift sells that motion without moving collision geometry or making
## tower placement wobble under the cursor. It is a separate accessibility
## setting from impact shake and is enabled only on the battlefield camera.
## One full left/right support transfer per second. Two footfalls happen in a
## cycle; the short plant pause keeps the body over a stable pair of feet rather
## than floating through a sinusoid like a boat. [TUNE]
## Fewer steps, each one heavier.
##
## A Worldstrider the size of a town does not walk at a person's cadence. The
## step rate is what sells the scale: at 0.18 it read as a large animal, at 0.11
## it reads as something that has to gather itself to move at all - and the
## longer gap between footfalls is what gives each impact room to land. [TUNE]
const BEAST_GAIT_FREQUENCY: float = 0.11
## Held at the ceiling the balance gate enforces, not above it.
##
## More lateral sway was asked for, and this is as far as it goes without an
## owner decision: this value moves the *camera*, so it moves the frame the
## player aims and reads lanes in. balance_test caps it at 9.0 for that reason.
##
## The weight is carried by the things that have no such cost instead - a much
## slower step rate, a longer pause on impact, a deeper sink and a harder shake.
## Those make a footfall land without moving the player's reference frame, which
## is the part that has to stay still. [TUNE]
const BEAST_GAIT_HORIZONTAL: float = 9.0
const BEAST_GAIT_VERTICAL: float = 4.1
const BEAST_GAIT_ROTATION_DEGREES: float = 0.18
const BEAST_GAIT_SMOOTHING: float = 1.65
const BEAST_GAIT_HORN_SCALE: float = 0.12
## Exponentially slow support transfer followed by a faster final plant. [TUNE]
const BEAST_GAIT_WINDUP_POWER: float = 2.15
const BEAST_STEP_PAUSE: float = 0.38
const BEAST_STEP_SINK: float = 9.0
const BEAST_STEP_SHAKE: float = 12.5
const BEAST_STEP_SHAKE_TIME: float = 0.42
const BEAST_STEP_MASS: float = 4.8
const BEAST_PROFILE_BASE_X: float = -20.0
const BEAST_PROFILE_HORIZONTAL: float = 18.0
const BEAST_PROFILE_VERTICAL: float = 7.5

## A planted support transfers a tiny physical shove through the city shell.
## These remain deliberately below combat-stagger values: they sell unstable
## footing without changing the outcome of an attack wind-up. [TUNE]
const BEAST_STEP_WORLD_IMPULSE: float = 27.0
# --- Chill: slows stack, freezes are a moment ---------------------------------
#
# Slow used to be "strongest wins, refresh the timer" and freeze used to be
# "refresh the timer". Two frost towers covering the same tile therefore held an
# enemy still indefinitely: the lane stopped being a lane, and the fix a player
# reaches for - build another frost tower - made it worse.
#
# The model now: every slow feeds one chill meter, the meter sets how slowly the
# enemy walks down to a floor it never passes, and only a *full* meter buys a
# single short lock. After that the enemy walks away still slowed and cannot be
# locked again until its refractory expires.

## Slowest an enemy ever walks, however much chill is on it. Never zero - a tower
## line that stops enemies outright stops the game with them.
const CHILL_SLOW_FLOOR: float = 0.34

## Chill from a slow that would have stopped an enemy dead (factor 0). An
## authored slow_factor of 0.6 therefore contributes 0.4 of this. [TUNE]
const CHILL_PER_SLOW: float = 0.42

## Chill from a dedicated freeze proc. A freeze tower is a chill engine now, and
## reaches the lock sooner than a plain slow rather than by a different rule.
const CHILL_PER_FREEZE_PROC: float = 0.55

## Chill lost per second once nothing is refreshing it. [TUNE]
const CHILL_DECAY: float = 0.5

## The lock at a full meter. Long enough to read as a freeze, far too short to
## chain into a stunlock.
const CHILL_SHATTER_SECONDS: float = 0.45

## Hard ceiling on any single freeze, wherever it comes from. Nothing in the game
## may exceed this, which is what makes "enemies never stop for long" a property
## rather than a hope.
const FREEZE_MAX_SECONDS: float = 0.6

## How long before the same enemy can be locked again. The constant that turns a
## freeze into a moment instead of a state. [TUNE]
const FREEZE_REFRACTORY: float = 3.2

## Chill left after a lock breaks. Not zero: the enemy walks out of it slowed, so
## the towers that froze it keep their grip and the meter refills honestly.
const CHILL_AFTER_SHATTER: float = 0.55

## Bosses take chill at this rate. They still slow and still shatter - a boss
## immune to the utility half of the roster would invalidate those towers exactly
## when they matter - but they do it about twice as slowly. [TUNE]
const CHILL_BOSS_RESIST: float = 0.45


const BEAST_STEP_STUN: float = 0.055
const BEAST_STEP_WOBBLE_DEGREES: float = 3.2

## Shake, as a struck mass rather than as noise.
##
## The old shake was a fresh random offset every frame for the length of the
## effect. That is white noise: it has no direction, so a footfall on the left
## and a tower exploding on the right felt identical, and it has no frequency of
## its own - it vibrates at whatever the frame rate happens to be, so the same
## impact reads differently on two machines.
##
## A real impact does two things at once. It shoves, hard, in one direction and
## rings down; and it leaves behind a finer vibration that climbs in pitch as
## the energy drains and is the last thing to stop. Those are separate here, and
## both are driven by an accumulated phase rather than by the frame, so the shake
## is identical at 30 and at 144 fps.

## The opening blow: low, heavy, directional, and quickly over. Starts at full
## displacement on the frame of impact - the snap is the hit. [TUNE]
const SHAKE_THUNDER_HZ: float = 5.6
## Higher powers end the thunder sooner and hand over to the rumble faster. [TUNE]
const SHAKE_THUNDER_DECAY: float = 2.6

## The rumble that follows, climbing from a growl to a fine tremble as it
## settles. Two axes at slightly different rates so it buzzes rather than
## sliding back and forth along one line. [TUNE]
const SHAKE_RUMBLE_HZ_START: float = 17.0
const SHAKE_RUMBLE_HZ_END: float = 43.0
## Quieter than the blow that caused it, and slower to die, which is what makes
## it read as settling rather than as a second hit. [TUNE]
const SHAKE_RUMBLE_SCALE: float = 0.34
const SHAKE_RUMBLE_DECAY: float = 0.85

## Per-target animation hold on a registered hit. This is not global hitstop;
## a large formation therefore remains responsive when an AoE lands. [TUNE]
const IMPACT_FRAME_TIME: float = 0.032

# ------------------------------------------------------------------------------
# Hero — health and movement
# ------------------------------------------------------------------------------

const HERO_MAX_HP: float = 100.0

## Movement multiplier while an attack is in its windup/active frames. Not fully
## rooted: being able to drift keeps the chain from feeling like a commitment
## trap, but the cost has to be legible.
const HERO_ATTACK_MOVE_SCALE: float = 0.38

## A lethal hit downs the hero before they return with an act-long Wound. [TUNE]
const HERO_RESPAWN_DELAY: float = 8.0

const HERO_WOUND_HP_PENALTY: float = 0.10
const HERO_MAX_WOUNDS: int = 3
const HERO_WOUND_REVIVE_HP: float = 0.50
const HERO_DRAUGHT_REVIVE_HP: float = 0.40

## Tending the hero during Preparation. The only healing that is not somebody
## else's decision - Hearthmend arrives three times a run, a heal spell is a
## build choice, and a wound revive costs a Wound.
##
## A third of the bar for 45 Food: enough that one purchase matters, priced so a
## full bar costs three and competes with the towers that would have stopped the
## damage in the first place. Healing should be the more expensive answer. [TUNE]
const HERO_TEND_FRACTION: float = 0.34
const HERO_TEND_COST: int = 45

## The guaranteed Hearthmend repairs this fraction of the Town Hall before the
## enhanced service choice. [TUNE]
const HEARTHMEND_TOWN_REPAIR_FRACTION: float = 0.12

## Grace period after respawning, so you are not instantly re-killed.
const HERO_RESPAWN_INVULN: float = 1.5

## Opening Preparation has no forced timer: the road starts only when the player
## deliberately chooses Ride On. [TUNE]
const PREPARATION_MIN_SECONDS: float = 0.0

## A breather opens only after every enemy in a wave is defeated, and it is a
## countdown: at the end of it the next formation rolls in by itself.
##
## It used to wait indefinitely for Ride On. That made the start of every wave a
## decision with nothing pressing it, so a run stopped dead between formations
## and the pacing of the whole road came apart. Fifteen seconds is long enough to
## build, upgrade and reposition, and short enough to feel like a breath. [TUNE]
const PREPARATION_BETWEEN_WAVES: float = 15.0

## Gold for riding on the instant a between-wave breather opens. [TUNE]
const PREPARATION_EARLY_GOLD_MAX: int = 10

## The award stops falling here, and holds. [TUNE]
const PREPARATION_EARLY_GOLD_FLOOR: int = 5

## The award falls a gold a second across this window, MAX down to FLOOR. [TUNE]
const PREPARATION_EARLY_GOLD_DECAY: float = 5.0

## After this the award is gone entirely, though the breather still has time left
## on it. [TUNE]
const PREPARATION_EARLY_GOLD_DEADLINE: float = 10.0


## The early-departure award for riding on with `seconds_left` on the clock.
##
## Falls a gold a second to a floor, holds there, then vanishes at a deadline -
## three steps rather than one ramp, and deliberately. A linear fade to zero
## gives a number that is never quite worth hurrying for and never quite worth
## waiting out. Two cliffs give two real decisions: go now for the most, or go
## before the bonus disappears at all.
static func preparation_early_gold(seconds_left: float) -> int:
	var elapsed: float = maxf(PREPARATION_BETWEEN_WAVES - seconds_left, 0.0)
	if elapsed >= PREPARATION_EARLY_GOLD_DEADLINE:
		return 0
	if elapsed >= PREPARATION_EARLY_GOLD_DECAY:
		return PREPARATION_EARLY_GOLD_FLOOR
	return maxi(PREPARATION_EARLY_GOLD_MAX - int(floor(elapsed)),
		PREPARATION_EARLY_GOLD_FLOOR)


## Seconds left before the early-departure award disappears entirely.
static func preparation_bonus_seconds_left(seconds_left: float) -> float:
	return maxf(seconds_left 		- (PREPARATION_BETWEEN_WAVES - PREPARATION_EARLY_GOLD_DEADLINE), 0.0)

## How long a formation may fail to clear before the run moves on anyway.
##
## Waves wait for every enemy, which is right - but with no ceiling that wait is
## a softlock: one enemy that cannot die or cannot be reached stops the wave, the
## next Preparation, and the run, with nothing spawning and nothing to fight.
## Generous, because it must never fire during an ordinary slow wave; it exists
## only so a stall becomes a hiccup. [TUNE]
const WAVE_STALL_TIMEOUT: float = 75.0

## How much closer an enemy must get for the wave to count as progressing.
##
## Small, but not zero: an enemy circling a bend edges nearer and further by a
## few units a frame, and a zero threshold would call that progress forever and
## disarm the watchdog entirely. [TUNE]
const WAVE_PROGRESS_EPSILON: float = 24.0

## Aggregate HP change that proves combat is still resolving even when a ranged
## attacker has stopped walking. Position alone called a caster firing at the
## town "stuck" and opened Preparation on top of it. [TUNE]
const WAVE_ACTIVITY_EPSILON: float = 0.25

## How soon the next wave may arrive once a breather ends. [TUNE]
const WAVE_BREATHER_RESUME_SECONDS: float = 1.5

const ROAD_START_WARNING_SECONDS: float = 2.5

## Radius of the hero's body for contact and hurt checks.
const HERO_BODY_RADIUS: float = 26.0

# ------------------------------------------------------------------------------
# Hero — dash
# ------------------------------------------------------------------------------

## Ground covered by one dash.
const HERO_DASH_DISTANCE: float = 190.0

## How long the movement itself lasts. Shorter than HERO_DASH_IFRAMES, so the
## i-frames outlast the travel and the dash reads as generous.
const HERO_DASH_DURATION: float = 0.16

# ------------------------------------------------------------------------------
# Hero — 3-hit attack chain
# ------------------------------------------------------------------------------
#
# Each hit is windup -> active -> recovery. The next click is accepted from the
# start of the active window until CHAIN_WINDOW seconds after recovery ends;
# miss it and the chain resets to hit 1.
#
# Arrays are indexed by chain step (0, 1, 2). The third hit is the finisher:
# slower, wider, and worth roughly two light hits.

const HERO_CHAIN_LENGTH: int = 3

const HERO_ATTACK_WINDUP: Array[float] = [0.07, 0.06, 0.13]
const HERO_ATTACK_ACTIVE: Array[float] = [0.10, 0.10, 0.14]
const HERO_ATTACK_RECOVERY: Array[float] = [0.15, 0.15, 0.30]
const HERO_ATTACK_DAMAGE: Array[float] = [10.0, 12.0, 24.0]

## Reach measured from the hero's centre.
const HERO_ATTACK_RANGE: Array[float] = [95.0, 95.0, 115.0]

## Total width of the swing arc in degrees, centred on the aim direction.
const HERO_ATTACK_ARC_DEGREES: Array[float] = [110.0, 110.0, 170.0]

## Impulse applied to everything the swing connects with.
const HERO_ATTACK_KNOCKBACK: Array[float] = [170.0, 190.0, 420.0]

## Hero self-movement on the finisher, so the third hit steps into the swing.
const HERO_ATTACK_LUNGE: Array[float] = [40.0, 45.0, 110.0]

## How long a lunge takes to bleed off. The impulse is sized from the distance
## above and this duration, so tuning the distance is enough.
const HERO_ATTACK_LUNGE_TIME: float = 0.12

## How long after recovery ends the chain stays open for the next click.
const HERO_CHAIN_WINDOW: float = 0.35

## A click this long before the chain window opens is remembered and fires as
## soon as it does. Without this the chain feels like it drops inputs.
const HERO_ATTACK_BUFFER: float = 0.20

## Screen shake magnitude per chain step, in pixels.
const HERO_ATTACK_SHAKE: Array[float] = [2.0, 2.5, 7.0]

## Time the whole game is frozen on a connecting hit, per chain step. This is
## the single biggest contributor to whether a swing feels like it landed.
const HERO_ATTACK_HITSTOP: Array[float] = [0.035, 0.04, 0.09]

# ------------------------------------------------------------------------------
# Enemy — Stage 1 uses one breed
# ------------------------------------------------------------------------------

## Three light hits, or one light hit plus a finisher.
const ENEMY_MAX_HP: float = 28

const ENEMY_CONTACT_DAMAGE: float = 8.5

## Minimum time between two contact hits from the same enemy.
const ENEMY_CONTACT_INTERVAL: float = 0.8

## Radius of the enemy's body for contact and hurt checks.
const ENEMY_BODY_RADIUS: float = 22.0

## Enemies push each other apart at this speed so a crowd does not collapse into
## a single stacked point. Purely cosmetic separation, not physics.
const ENEMY_SEPARATION_SPEED: float = 45.0

## Seconds of stagger applied on being hit, during which the enemy does not walk.
const ENEMY_HITSTUN: float = 0.18

## Minimum moving time between two hitstuns on the same enemy.
##
## Hitstun used to be applied on every single hit with nothing stopping it from
## being refreshed. Any tower firing faster than once per ENEMY_HITSTUN - or two
## towers between them, or one splash landing on the same enemy every volley -
## therefore pinned it in place indefinitely. That is what "frozen solid by a
## Glacial Mortar" actually was: not the freeze, which is capped and has its own
## refractory, but the flinch, which had neither.
##
## With this, an enemy spends at most ENEMY_HITSTUN of every
## ENEMY_HITSTUN + ENEMY_HITSTUN_GAP seconds locked - about 30% - however much
## fire is landing on it. [TUNE]
const ENEMY_HITSTUN_GAP: float = 0.42

## Sideways speed below which a sprite keeps the facing it already has.
##
## Anything moving mostly along the y axis has a tiny, sign-flipping x component,
## and a bare `x < 0` test turns that into a sprite that shudders between facings
## every frame. [TUNE]
const FACING_DEADZONE: float = 6.0

## How long an attack holds the hero's facing after it lands.
##
## Long enough that a swing thrown behind you reads as a swing behind you, rather
## than snapping back to the walk direction before the animation is done. [TUNE]
const HERO_ATTACK_FACING_HOLD: float = 0.35

## How fast knockback velocity bleeds off, in px/s per second.
const ENEMY_KNOCKBACK_DECAY: float = 900.0

## Time from death to the corpse disappearing.
const ENEMY_DEATH_FADE: float = 0.35

# ------------------------------------------------------------------------------
# Stage 1 spawning
# ------------------------------------------------------------------------------
#
# Stage 1 has no waves — GDD §10 puts those in Stage 2. This is a continuous
# trickle that thickens over five minutes so the session has a shape.

const SPAWN_INTERVAL_START: float = 1.70
const SPAWN_INTERVAL_END: float = 0.45

## Time over which the interval ramps from start to end. Matches the five
## minutes of survivable combat Stage 1 asks for.
const SPAWN_RAMP_SECONDS: float = 300.0

## Hard cap on live enemies, so a bad stretch cannot become unrecoverable.
const SPAWN_MAX_ALIVE: int = 72

## Enemies never appear closer to the hero than this, even if the hero is
## standing on the spawn ring.
const SPAWN_MIN_DISTANCE_FROM_HERO: float = 420.0

## Enemies spawned at once when the timer fires, at the start and end of the ramp.
const SPAWN_BURST_START: int = 1
const SPAWN_BURST_END: int = 3

# ------------------------------------------------------------------------------
# Feedback
# ------------------------------------------------------------------------------

## Engine time scale during hitstop. 0.0 is a true freeze; raise it toward 0.1
## for a slow-motion feel instead.
const HITSTOP_TIME_SCALE: float = 0.0

## Seconds a unit stays tinted after being hit.
const HIT_FLASH_TIME: float = 0.09

## Colour a unit flashes when damaged.
const HIT_FLASH_COLOUR: Color = Color(2.4, 1.6, 1.6)

## Unit health bars. These sit above the unit in world space — Stage 1 has no
## screen-space HUD, but a swing you cannot see landing tells you nothing.
const HEALTH_BAR_WIDTH: float = 54.0
const HEALTH_BAR_HEIGHT: float = 7.0

## How fast the blink cycles while the hero is invulnerable, in cycles/sec.
const INVULN_BLINK_RATE: float = 12.0

# ==============================================================================
# GDD v3 — LANES, TOWERS, TOWN, RAID
# ==============================================================================

# ------------------------------------------------------------------------------
# Lanes and the battlefield ring — GDD §3
# ------------------------------------------------------------------------------

## Four cardinal lanes: N, E, S, W.
const LANE_COUNT: int = 4

## How many distinct routes a lane may offer.
##
## The authored map yields eight per lane. The cap is a guard on the search, not
## a design number: simple-path enumeration is exponential in the worst case, and
## a future map with more forks should slow the level down rather than hang it.
const ROUTES_PER_LANE_MAX: int = 24

## How hard route choice leans toward the shorter way in.
##
## Weight is length raised to minus this. At 0 every route is equally likely and
## a third of each wave takes the long way, which arrives as a second clump and
## reads as a bug. At 1.5 the short ways carry the wave and a real minority still
## goes round, which is the behaviour that makes the forks worth having. [TUNE]
const ROUTE_LENGTH_BIAS: float = 1.5

## The longest route a lane may offer, as a multiple of its shortest.
##
## The authored map's longest way in is three and a half times its shortest. An
## enemy taking it walks for around two and a half minutes, which is not variety
## - the wave has been over for a minute by the time it arrives, and it reads as
## a stuck enemy rather than as a flanker. Capped at twice the direct route,
## which still leaves several genuinely different ways in. [TUNE]
const ROUTE_LENGTH_MAX_RATIO: float = 2.0

## The battlefield's build grid, in tiles per side (GDD §13, LOCKED at 30x30).
## `BattleGrid` reads this rather than owning it: it is a tuning number, and every
## tuning number lives here. [TUNE]
const GRID_TILES: int = 30

## A tower covers this many tiles on a side (GDD §13, LOCKED at 2x2). [TUNE]
const TOWER_FOOTPRINT_TILES: int = 2

## Radius at which a lane's enemies spawn. [TUNE]
const LANE_SPAWN_RADIUS: float = 900.0

## Radius of the town core. Enemies that reach it deal damage. [TUNE]
const TOWN_RADIUS: float = 160.0

## Build spots along each lane, town-outward, for both flanks of the road.
##
## Six per road rather than three: the same inner/middle/outer trio, mirrored to
## the other side of the path. 6 x 4 lanes = 24 spots. Owner decision, 2026-08-14,
## superseding the three-spot layout in GDD v4 §3-§4; the design docs and
## V4_CONFORMANCE were updated with it rather than left disagreeing.
##
## The array's size is what the rest of the game reads as "spots per lane" -
## RunState indexes saves with it, Battlefield builds the field from it - so this
## is the one place the number lives.
##
## Index 0-2 are the left flank, 3-5 the right, each running inner to outer.
## Left and right are taken standing at the town looking outward along the road,
## which is well defined because the orthogonal is a consistent rotation.
const TOWER_SLOT_RADII: Array[float] = [
	320.0, 520.0, 720.0,
	320.0, 520.0, 720.0,
]

## Spots on one flank. Each flank is a self-contained trio with its own
## combination, so a road can run two different fusions at once.
const TOWER_SLOTS_PER_SIDE: int = 3

## The combination slot is the middle of its flank, and only unlocks once both of
## its neighbours on that flank are built (GDD §4.1).
const COMBO_SLOT_INDEX: int = 1


## Which flank a spot is on: 0 for the left trio, 1 for the right.
static func slot_side(slot: int) -> int:
	return 0 if slot < TOWER_SLOTS_PER_SIDE else 1


## The sign to push a spot away from the lane centre line with.
static func slot_side_sign(slot: int) -> float:
	return 1.0 if slot_side(slot) == 0 else -1.0


## Position within its flank: 0 inner, 1 middle, 2 outer.
static func slot_local(slot: int) -> int:
	return slot % TOWER_SLOTS_PER_SIDE


## First slot index of the flank this spot belongs to.
static func slot_side_base(slot: int) -> int:
	return slot_side(slot) * TOWER_SLOTS_PER_SIDE


static func slot_is_combo(slot: int) -> bool:
	return slot_local(slot) == COMBO_SLOT_INDEX


static func slots_per_lane() -> int:
	return TOWER_SLOT_RADII.size()

## How far a build spot sits to the side of the lane centre line, so towers
## flank the path instead of standing in it.
## How far to the side of the lane centre a build spot stands.
##
## This is a *click* problem before it is a layout one. The spot's hit target is
## TowerSlot.HIT_SIZE square and centred here, so the geometry that matters is:
##
##     road half-width          88   (LANE_WIDTH 110 * LANE_ROAD_SCALE 1.6 / 2)
##     enemies walk within     +-55  (LANE_WIDTH * 0.5)
##     hit target near edge     offset - HIT_SIZE/2
##
## At the old 96 with a 120px target the near edge sat 36px from the centre line
## — inside the corridor enemies walk down. Swinging at something on the near
## side of the road hit the build spot instead and threw the build panel open
## mid-wave.
##
## 158 with a 96px target puts the near edge at 110: clear of the road by 22px
## and of the enemy corridor by 55px. [TUNE]
const TOWER_SLOT_OFFSET: float = 158.0

## How close a living enemy has to be before a build spot stops taking clicks.
##
## Moving the spot to 158 above got the hit target out of the corridor enemies
## *walk* down. It could do nothing about the ones that stop and attack the
## tower, which come right up to it and stand on the target - so swinging at a
## besieger still threw the build panel open.
##
## Geometry rather than taste: the target is 96 square, so its corner is 68 from
## the centre. 130 covers the whole target with enough margin that a click aimed
## at an enemy just outside it is genuinely aimed at empty ground. [TUNE]
const TOWER_CLICK_BLOCK_RADIUS: float = 130.0

## Enemies drift up to this far from the lane centre line, so a wave reads as a
## column rather than a single-file queue.
const LANE_WIDTH: float = 125

# ------------------------------------------------------------------------------
# Towers — GDD §4
# ------------------------------------------------------------------------------

## Five levels keep resources relevant through Acts 2 and 3. The Forge gates
## access above the early-game cap, so this is a progression track rather than
## five buttons available on the opening screen.
const TOWER_MAX_LEVEL: int = 5

## Every emplacement is a structure now, not only Bulwarks. Specialist blockers
## override this in their TowerData; ordinary towers inherit it. [TUNE]
const TOWER_BASE_MAX_HP: float = 520.0
const TOWER_REPAIR_FRACTION: float = 0.34
const TOWER_REPAIR_WOOD_COST: int = 32
const TOWER_BASE_LEVEL_CAP: int = 2

## Resource cost to build a base tower at level 1. [TUNE]
## Tower price, as two independent decisions (GDD §20).
##
## Role sets the Gold. Reach is the premium stat: it decides how many enemies a
## tower ever gets to shoot, so it compounds with everything else a level buys.
## Indexed by TowerData.Role. [TUNE]
const TOWER_ROLE_GOLD: Array[int] = [50, 95, 120, 70]

## Element sets a Gold modifier and a secondary currency, so a build competes
## with the town rather than only with itself. Indexed by TowerData.Element:
## Fire, Water, Earth, Air. [TUNE]
const TOWER_ELEMENT_GOLD_SCALE: Array[float] = [1.15, 0.85, 0.85, 1.10]

## Secondary currency per element, and how much. Fire is pure Gold - the damage
## you simply buy. Water is fed, Earth is quarried, Air is timber-framed, and
## each draws on a different town producer. [TUNE]
const TOWER_ELEMENT_SECONDARY: Array[String] = ["", "food", "stone", "wood"]
const TOWER_ELEMENT_SECONDARY_COST: Array[int] = [0, 6, 10, 8]

## Fallback for anything without a role, and the figure the opening-economy
## checks are written against.
const TOWER_BUILD_COST: int = 70

## Combination towers cost more than either parent. [TUNE]
const TOWER_COMBO_BUILD_COST: int = 160

## Cost of upgrading to level N, indexed by the level being bought (1 -> 2 is
## index 0). [TUNE]
const TOWER_UPGRADE_COSTS: Array[int] = [90, 190, 340, 560]

## Damage and rate multipliers per level, indexed by level - 1. [TUNE]
const TOWER_LEVEL_DAMAGE: Array[float] = [1.0, 1.38, 1.88, 2.48, 3.20]
const TOWER_LEVEL_RATE: Array[float] = [1.0, 1.10, 1.22, 1.36, 1.52]

## Status, reach, area and durability also improve. Utility towers used to gain
## almost nothing from an upgrade because only raw damage and rate scaled.
const TOWER_LEVEL_UTILITY: Array[float] = [1.0, 1.10, 1.22, 1.37, 1.55]
## Reach per level. Was [1.0, 1.02, 1.05, 1.08, 1.12] - twelve percent across
## four upgrades, which is under nine pixels a level on a 270-unit tower and so
## is not a thing a player can see happening. An upgrade the player cannot see is
## an upgrade they do not believe in.
##
## Held below the damage curve on purpose: reach decides *how many* enemies a
## tower ever gets to shoot, so it compounds with everything else a level buys.
## 42% at level 5 is clearly visible on the range ring without letting one corner
## tower cover two roads. [TUNE]
const TOWER_LEVEL_RANGE: Array[float] = [1.0, 1.09, 1.19, 1.30, 1.42]

# ------------------------------------------------------------------------------
# Command — GDD v4 §15
# ------------------------------------------------------------------------------

const COMMAND_MAX: float = 100.0
const COMMAND_CAUTION_PRESSURE: float = 0.35
const COMMAND_HERO_HIT_GAIN: float = 2.5
const COMMAND_PRIORITY_HIT_GAIN: float = 2.0
const COMMAND_INTERRUPT_GAIN: float = 8.0
const COMMAND_PERFECT_DODGE_GAIN: float = 12.0
const COMMAND_PERFECT_DODGE_RADIUS: float = 150.0

## How far from the cursor Overdrive will reach for a tower.
##
## Orders are aimed with the mouse rather than by pre-selecting a slot. Rally
## always has an answer - every point is nearest to some road - but Overdrive
## names one specific tower, and aiming at the far side of the field should miss
## rather than quietly boost whatever happened to be closest. Slightly over the
## 270 slot radius, so pointing anywhere near a lane finds its towers. [TUNE]
const COMMAND_AIM_RADIUS: float = 320.0

const COMMAND_OVERDRIVE_COST: float = 30.0
const COMMAND_OVERDRIVE_DURATION: float = 5.0
const COMMAND_OVERDRIVE_RATE: float = 1.60
const COMMAND_OVERDRIVE_UTILITY: float = 0.25

const COMMAND_RALLY_COST: float = 45.0
const COMMAND_RALLY_STAGGER: float = 1.10
const COMMAND_RALLY_SHIELD: float = 4.0

const COMMAND_LAST_STAND_COST: float = 100.0
const COMMAND_LAST_STAND_DURATION: float = 3.0
const COMMAND_ORDER_COUNT: int = 3

## Refund fraction when a tower is sold. [TUNE]
const TOWER_SELL_REFUND: float = 0.6
const TOWER_COMBO_STONE_COST: int = 55
const TOWER_STONE_SELL_REFUND: float = 0.4

## Both non-combo slots in a lane sharing an element grants this bonus. [TUNE]
const SAME_ELEMENT_LANE_BONUS: float = 0.25

## Default projectile speed for towers that fire one. [TUNE]
## How large the painted projectile head is drawn, against its 64px source.
##
## The art is a skin over the same flight: the trail, filament, light, tumble and
## per-level scaling all still run underneath it. A sprite that replaced them
## would read as a decal sliding across the field rather than as a shot. [TUNE]
## Drawn against a 96x48 source. The art is a long horizontal bolt now rather
## than a square blob: the first set was drawn diagonally, so rotating it to its
## heading left every shot pointing about 45 degrees off its own travel. [TUNE]
const PROJECTILE_ART_SCALE: float = 0.40

## How wide a painted impact burst is drawn for a shot with no blast radius. An
## area shot uses its own radius instead, so the picture matches the damage. [TUNE]
const PROJECTILE_IMPACT_ART_SIZE: float = 86.0

## How fast a ground pool turns while it burns, in radians per second at full
## jitter. Slow: this is meant to keep a long pool alive to the eye, not to spin
## like a fan. [TUNE]
const GROUND_ZONE_DRIFT: float = 0.22

# --- Structure idle ----------------------------------------------------------
#
# Towers and buildings prefer authored PixelLab frame loops by id convention.
# The transform remains the missing-art fallback, so a partial install still
# reads as alive instead of freezing or dropping the sprite entirely.
#
# Deliberately small. This is meant to be felt and not watched - a structure that
# visibly pulses pulls the eye away from the road, which is where the game is.

## Cycles per second of the breathe. Slow: a building is not panting. [TUNE]
const STRUCTURE_IDLE_RATE: float = 0.42

## Authored structure-idle playback speed in frames per second. Four poses at
## this cadence make a one-second closed loop without pulling focus from combat.
## [TUNE]
const STRUCTURE_IDLE_FRAME_RATE: float = 4.0

## How much a structure swells and settles, as a fraction of its size. [TUNE]
const STRUCTURE_IDLE_SCALE: float = 0.012

## How far it leans, in degrees, at the ends of its cycle. [TUNE]
const STRUCTURE_IDLE_SWAY: float = 0.55

## The beast standing still: how far it rises and falls, and how often.
##
## Much slower and larger than a structure's breathe - this is an animal the size
## of a town, and a fast shallow bob on it reads as a shiver. [TUNE]
const BEAST_IDLE_BREATH: float = 5.0
const BEAST_IDLE_BREATH_RATE: float = 0.16

## How often a foliage clump is a painted plant rather than only blades.
##
## Low on purpose. The polygons are what make the ground look covered and they
## cost almost nothing; the sprites are the few plants the eye stops on. Raising
## this multiplies the field's draw cost for a difference nobody sees. [TUNE]
const FOLIAGE_PAINTED_CHANCE: float = 0.16

## How far a painted plant is tinted toward its region's sampled palette, so it
## sits in the same light as the blades instead of looking pasted on. [TUNE]
const FOLIAGE_PAINTED_TINT: float = 0.45

## Raised with the field.
##
## 620 was tuned when a tower's whole range fitted comfortably on screen. On the
## authored map the camera sits further out, so the same shot covers less of the
## view per second and reads as slow — and a slow shot against a moving enemy is
## also a shot that misses more, because the lead grows with flight time. [TUNE]
const TOWER_PROJECTILE_SPEED: float = 880.0

# ------------------------------------------------------------------------------
# Waves — GDD §3
# ------------------------------------------------------------------------------

## Seconds between waves at the start of a segment. [TUNE]
const WAVE_INTERVAL: float = 20

## Eight-wave onboarding envelope. The previous curve snapped from one lane to
## three at wave five while every protection multiplier simultaneously became
## neutral. This opens one road at a time and hands control to the unchanged
## late curve at wave eight. [TUNE]
const WAVE_FIRST_PREPARATION: float = 18.0
const WAVE_OPENING_COUNT_SCALE: Array[float] = [0.84, 0.86, 0.58, 0.66, 0.74, 0.82, 0.72, 0.80, 0.88, 0.68, 0.84, 1.0]
const WAVE_OPENING_HP_SCALE: Array[float] = [0.70, 0.75, 0.80, 0.85, 0.90, 0.94, 0.97, 1.0]
const WAVE_OPENING_DAMAGE_SCALE: Array[float] = [0.62, 0.68, 0.74, 0.80, 0.86, 0.91, 0.96, 1.0]
const WAVE_OPENING_SPEED_SCALE: Array[float] = [0.86, 0.89, 0.92, 0.94, 0.96, 0.98, 0.99, 1.0]
const WAVE_OPENING_INTERVAL_BONUS: Array[float] = [6.0, 5.0, 4.0, 3.0, 2.0, 1.0]
const WAVE_OPENING_SUPPLIES: Array[int] = [0, 25, 35, 40, 30, 25]
const WAVE_OPENING_SINGLE_LANE_WAVES: int = 2

## Seconds between spawns inside one wave. [TUNE]
const WAVE_SPAWN_SPACING: float = 0.65

## Enemies in wave 1, and how many are added per wave. [TUNE]
const WAVE_BASE_COUNT: int = 4
## Rebalanced 2026-08-18 for the grid battlefield.
##
## Two changes landed together and I described them as pulling in opposite
## directions. They do not - both make the game easier for the defender:
##
##   * Tower count is uncapped. The curve report's capability roughly doubled.
##   * Roads are 2.1x longer, so a formation is under fire 2.1x as long. A bend
##     costs the attacker time; it does not cost the defender anything.
##
## Measured, pressure across Acts 2-3 had halved - 0.09-0.12 where the old
## three-slot game reached 0.25. Threat has to rise to meet it, so pack growth
## and HP growth both go up, and enemies move faster to claw back some of the
## time the bend hands the player. Speed is the honest lever for the road
## length; HP and count answer the tower count. [TUNE]
## Endless escalation, applied per Endless wave on top of the ordinary per-wave
## growth. Without these, Endless settles at whatever pressure Act 3 ended on and
## becomes a treadmill the player can never lose - which is the one thing an
## endless mode must not be. [TUNE]
const ENDLESS_HP_GROWTH: float = 0.055
const ENDLESS_DAMAGE_GROWTH: float = 0.032
const ENDLESS_COUNT_GROWTH: float = 0.11

const WAVE_COUNT_GROWTH: float = 0.285
const WAVE_ACT_COUNT_SCALE: Array[float] = [1.0, 1.14, 1.30]
const WAVE_NIGHT_COUNT_BONUS: float = 0.16

## Enemy HP and damage multiplier added per wave. [TUNE]
## Rebalanced for the authored map and hero levelling (2026-08-20).
##
## Three changes made the game easier at once and none of them looked like a
## balance change: the map gained far more buildable ground (568 places take two
## towers abreast, where the old pockets took one), free placement removed the
## slot ceiling, and the hero can now reach +105% damage over a run. Measured
## peak pressure sat at 0.26 - towers alone were covering roughly four times the
## threat, which is exactly the passive game that gets played from the base.
##
## Threat is raised rather than tower damage cut, on purpose. Cutting towers
## makes the early game worse for a new player who has not learned to fight yet;
## raising the curve leaves Road 1 where it was and bites where a player has
## levels, skills and a defence to fight alongside. [TUNE]
## Solved for a target rather than nudged. `curve_report` models tower
## capability and *no hero at all*, so peak pressure is precisely the fraction of
## late threat the player has to cover themselves. At 0.26 that was a quarter,
## which a good defence absorbs without anyone leaving the base. Around 0.6 the
## towers hold most of a wave and the rest is the player's job - which is the
## stated goal, and what the levelling exists to make possible.
const WAVE_HP_GROWTH: float = 0.122
const WAVE_DAMAGE_GROWTH: float = 0.019
const WAVE_SPEED_GROWTH: float = 0.19
const WAVE_DARK_DAMAGE_WEIGHT: float = 0.58
const WAVE_DARK_SPEED_WEIGHT: float = 0.10
## Act boundaries introduce new enemy roles and lane patterns, so they should
## not also be stat cliffs. The continuous global-wave curve still takes Act 3
## well into mastery-level pressure; these modest regional multipliers make the
## first Saltglass formation readable after the Ashfen boss.
## Act multipliers stay close to where they were tuned.
##
## Raising these was the first attempt at the 2026-08-20 rebalance and the
## balance gate refused it: an act multiplier applies in full on the first
## formation of an act, so 1.26 -> 1.68 is a 33% wall at Act 2's door, which is
## precisely the "erase the player's progress on the very first formation" the
## gate exists to catch. The per-wave rate carries the increase instead - growth
## is linear, so a higher rate lifts wave 51 far more than wave 5 and arrives as
## a ramp rather than a step. [TUNE]
const WAVE_ACT_HP_SCALE: Array[float] = [1.0, 1.28, 1.60]
const WAVE_ACT_DAMAGE_SCALE: Array[float] = [1.0, 1.12, 1.28]

## The final stretch of an act becomes a visible pressure peak instead of only
## changing the label above the boss track.
## Measured, the last wave of every act was the sharpest step inside that act -
## +30%, +26%, +25% - because the ramp raises pack size and stats at once and
## lands on top of the wave where pack size was going to increment anyway. The
## peak is wanted; three multipliers arriving together is not. Count carries less
## of it now, since bodies are what the ramp was already adding through its own
## growth curve. [TUNE]
const ACT_BOSS_RAMP_COUNT: float = 0.16
const ACT_BOSS_RAMP_STATS: float = 0.18

## Later regions remain dominated by their own breed while veterans from
## earlier terrain occasionally break up a predictable procession.
const WAVE_INVADER_CHANCE: Array[float] = [0.0, 0.12, 0.22]

## Elites arrive as an increasing number of squad leaders, not one lottery roll
## per wave for the entire 45-minute run.
const WAVE_ELITE_BASE_CHANCE: float = 0.13
const WAVE_ELITE_PROGRESS_BONUS: float = 0.75
const WAVE_ELITE_ACT_BONUS: float = 0.20
const WAVE_MAX_QUEUED: int = 180

## How many lanes a wave uses, at wave 1 and at the end of an act. [TUNE]
const WAVE_LANES_START: int = 1

## How much wider each new act opens than the last.
##
## Was effectively 1, which restarted Act 2 at two roads after Act 1 had ended at
## four: measured as a 77% drop in pressure across the boundary, so the game went
## quiet for four waves exactly when the player arrived somewhere new.
##
## Raising it to 2 halved the drop and then produced an 81% jump two waves later,
## which is the same problem wearing a different hat. Lane count is a coarse
## lever - a road is a quarter of the battlefield, so it cannot express "slightly
## easier" - and using it to shape an act boundary can only ever see-saw.
##
## At 3 every act after the first opens at full width and the boundary is shaped
## by WAVE_ACT_OPENING_COUNT_SCALE instead, which is continuous. Act 1 keeps its
## own authored lane introduction; that one is teaching, not pacing. [TUNE]
const WAVE_LANES_PER_ACT: int = 3

## Pack size over the first waves of Acts 2 and 3, as a fraction of the curve.
##
## The continuous half of the act-boundary shape. A new region arrives a little
## thinner and is back to full within four waves, so it reads as a breath rather
## than as the difficulty falling over. Act 1 has its own, longer envelope in
## WAVE_OPENING_COUNT_SCALE, because a first act is teaching the game rather than
## pacing a transition. [TUNE]
const WAVE_ACT_OPENING_COUNT_SCALE: Array[float] = [0.66, 0.78, 0.89, 1.0]
const WAVE_LANES_MAX: int = 4

## Authored wave formations multiply the continuous curve; these clamps keep a
## malformed content file from producing an empty wave or an instant spawn wall.
const WAVE_ARCHETYPE_MIN_COUNT_SCALE: float = 0.50
const WAVE_ARCHETYPE_MIN_SPACING_SCALE: float = 0.72

## Live enemy cap across the whole battlefield. [TUNE]
const BATTLEFIELD_MAX_ENEMIES: int = 120

# ------------------------------------------------------------------------------
# Enemy attacks — GDD §3
# ------------------------------------------------------------------------------
#
# Enemies stop and telegraph. Touching the hero does nothing: the damage comes
# from a wind-up you can see and dash out of.

## How close an enemy gets before it stops to attack. [TUNE]
const ENEMY_ATTACK_RANGE: float = 62.0

## Visible tell before the blow lands. [TUNE]
const ENEMY_ATTACK_WINDUP: float = 0.45

## How long the damaging moment lasts. [TUNE]
const ENEMY_ATTACK_STRIKE: float = 0.12

## Recovery before the enemy can act again. [TUNE]
const ENEMY_ATTACK_RECOVERY: float = 0.75

## An enemy will break off to hit the hero if the hero is this close. [TUNE]
const ENEMY_HERO_AGGRO_RANGE: float = 210.0

## Howlers and the Drowned Choir fire slow committed shots. Their target can
## leave the marked destination before impact; this is pressure, not hitscan.
const ENEMY_RANGED_RANGE: float = 330.0
## Raised alongside the tower shot, but by less: an enemy's shot has to stay
## dodgeable, and the hero has more ground to dodge into now. [TUNE]
const ENEMY_PROJECTILE_SPEED: float = 400.0
const ENEMY_PROJECTILE_WIDTH: float = 7.0
const ENEMY_PROJECTILE_HIT_RADIUS: float = 18.0
const ENEMY_PROJECTILE_BLAST_RADIUS: float = 54.0
const ENEMY_PROJECTILE_MAX_LIFE: float = 2.0
const ENEMY_PROJECTILE_TRAIL_POINTS: int = 12
const ENEMY_PROJECTILE_GLOW_SCALE: float = 0.22
const ENEMY_PROJECTILE_LIGHT_RADIUS: float = 105.0
const ENEMY_PROJECTILE_LIGHT_ENERGY: float = 0.75
const ENEMY_PROJECTILE_COLOUR: Color = Color(0.95, 0.25, 0.12)
const HOWLER_SEARCH_RADIUS: float = 240.0

# ------------------------------------------------------------------------------
# Town — GDD §5
# ------------------------------------------------------------------------------

const TOWN_MAX_HP: float = 1250.0

## Damage an enemy deals to the town when it arrives, per point of its own
## contact damage. [TUNE]
const TOWN_DAMAGE_SCALE: float = 1.75
const TOWER_ARMOUR_EFFECT_SCALE: float = 0.45

## Resources produced per distance unit travelled, before Granary tiers. [TUNE]
const RESOURCE_PER_DISTANCE: float = 0.25

## Normal enemies still pop resource drops, but not every body is a full unit
## of currency. A fractional carry preserves the dopamine beat without making
## a large wave finance every remaining upgrade by itself.
const KILL_RESOURCE_SCALE: float = 0.5

## Extra resource rate per Granary tier. [TUNE]
const GRANARY_TIER_BONUS: float = 0.30

## Extra resource rate per captive assigned to the Scavenging Post. [TUNE]
const CAPTIVE_WORK_BONUS: float = 0.22

## Captives assignable to one building. [TUNE]
const CAPTIVES_PER_BUILDING: int = 2

## Resources granted at the start of a run. [TUNE]
## Covers one tower on every lane plus one deliberate flex purchase. The old
## 220-resource start could protect only three of four roads before combat.
const STARTING_RESOURCES: int = 350

## Four-wallet v4 opening cache. Gold covers four base towers plus one level-2
## choice; Stone permits one Fusion; Wood supports an opening town project; Food
## is held for hero recovery/training. [TUNE]
const STARTING_WOOD: int = 180
const STARTING_FOOD: int = 70
const STARTING_GOLD: int = 390
const STARTING_STONE: int = 90
## Machine-readable v4 contract; RunState owns the runtime typed aliases.
const CURRENCY_IDS: Array[String] = ["wood", "food", "gold", "stone"]

const BUILD_WOOD_COSTS: Array[int] = [80, 145, 230, 340]
const MARKET_TRADES_PER_PREPARATION: int = 2
const MARKET_MAX_EXCHANGE: int = MARKET_TRADES_PER_PREPARATION
const MARKET_TRADE_LOT: int = 30
const MARKET_TRADE_RETURN: int = 18
const TREASURY_CACHE_PER_TIER: Array[int] = [20, 35, 50]
const TREASURY_CACHE_MAX: int = 50

# ==============================================================================
# TOOLS AND SIGILS (GDD v4 SS35, SS36)
# ==============================================================================
#
# The two account-level systems v4 sanctions. Both are horizontal: Tools widen
# what a run *can* contain and Sigils widen how a run *starts*. Neither makes a
# tower hit harder, which is the line CLAUDE.md SS7 draws around the save.

## Tools earned for reaching an act, cumulative. Getting deeper is the whole
## earning curve - there is no per-kill trickle, because a trickle rewards
## farming a wave rather than surviving a road. [TUNE]
const TOOLS_PER_ACT: int = 2

## On top of that, for a run that reached the summit. [TUNE]
const TOOLS_VICTORY_BONUS: int = 3

## What one roster tower costs. Eight towers at four each is thirty-two Tools,
## which is roughly four full runs - the roster widens over a campaign rather
## than over an evening. [TUNE]
const TOOLS_PER_ROSTER_TOWER: int = 4

## Ceiling on the stored balance. Tools are spent automatically at the end of a
## run, so a balance only builds up once the roster is complete; the cap stops it
## growing into a meaningless number on the debrief. [TUNE]
const TOOLS_MAX: int = 40

## Legacy ranks, and the cap v4 SS36 fixes at four. "Four clears expose the
## complete bounded legacy" - the point of the cap is that the ceiling is
## reachable and then done, not a ladder without a top.
const SIGIL_MAX_RANK: int = 4

## Rank 1: a modest starting bundle, per currency. [TUNE]
const SIGIL_RANK1_SUPPLY: int = 25

## Rank 3: what the Treasury may carry when the rank is held. [TUNE]
## Sigil rank 2: crossroad pairs a run may redraw (v4 SS36).
##
## One, and per run rather than per crossroad. A reroll at every fork would make
## the route a shopping list instead of a decision - the point of a crossroad is
## that you take one of the two in front of you. One redraw across a whole run is
## a rescue from a pair that fights your build, which is the case rank 2 is for.
const SIGIL_RANK2_REROLLS: int = 1

const SIGIL_RANK3_TREASURY_CAP: int = 120

## Accessibility contract mirrored by Palette's authored live tables.
const COLOURBLIND_MODES: Array[String] = ["off", "protanopia", "deuteranopia", "tritanopia"]
## Stone from an elite kill.
##
## Doubling the build spots doubled the fusions a run can reach - eight rather
## than four, two per road - and Stone is the only thing that buys them. Left at
## 4 the second fusion on a road was arithmetic rather than a decision: the
## currency simply never arrived.
##
## 6 rather than 8, deliberately. Stone is meant to be the scarce, event-driven
## wallet: it comes from elites, raids and the quarry, never from walking. A
## second fusion should be a run's late goal, not something every road gets by
## default - otherwise the extra flank stops being a choice about where to spend
## and becomes a checklist. [TUNE]
const ELITE_STONE_REWARD: int = 6
const BOSS_STONE_REWARD: int = 24

## A costly emergency action: restores the run after a partial breach while
## competing directly with the next tower mastery purchase.
const TOWN_REPAIR_COST: int = 110
const TOWN_REPAIR_AMOUNT: float = 120.0

# ------------------------------------------------------------------------------
# War horn, raid meter and the raid — GDD §6
# ------------------------------------------------------------------------------

## Raid meter gained per kill, and the multiplier while the horn is blowing.
const RAID_CHARGE_PER_KILL: float = 0.02
const RAID_CHARGE_HORN_MULTIPLIER: float = 3.0

## How long enemies stay weakened after the meter fills. [TUNE]
const WEAKENED_DURATION: float = 10

## Stat multiplier applied to weakened enemies. [TUNE]
const WEAKENED_STAT_SCALE: float = 0.60

## Enemy speed and strength multipliers while the horn is blowing. [TUNE]
const HORN_ENEMY_SPEED_SCALE: float = 1.45
const HORN_SPAWN_RATE_SCALE: float = 1.8

## Two authored extraction windows at 25 and 50 seconds, followed by the
## chieftain climax. [TUNE]
const RAID_EXTRACTION_WINDOWS: Array[float] = [25.0, 50.0]
const RAID_WINDOW_DURATION: float = 3.0

## Refusing a window makes the camp harder by this much, compounding. [TUNE]
const RAID_REFUSAL_ESCALATION: float = 0.35

const RAID_CHIEFTAIN_TIME: float = 70.0
const RAID_HARD_LIMIT: float = 90.0

## Player-facing outcomes after a full clear. The current reward defaults to
## Accept Oath until the choice overlay lands; the vocabulary is authoritative.
const LEADER_RESOLUTIONS: Array[String] = ["accept_oath", "ransom", "take_standard"]

## Raid horde pacing. [TUNE]
const RAID_SPAWN_INTERVAL: float = 0.55
const RAID_MAX_ENEMIES: int = 72
## The old circular arena. Kept only as the fallback bound for a raid whose
## layout failed to build; the camp is a 40x40 tile field now (RaidLayout).
const RAID_ARENA_RADIUS: float = 700.0

# --- Raid camp terrain --------------------------------------------------------
#
# The camp was a flat circle 700 units across, which made every part of it the
# same as every other part - so a raid was a minute of backing away from whatever
# spawned. Raised islands give it corners to break contact behind, high ground
# worth climbing for, and ramps narrow enough to hold.

## How many raised blobs a camp gets. [TUNE]
const RAID_ISLANDS_MIN: int = 4
const RAID_ISLANDS_MAX: int = 7

## Tiles between island seeds, so they read as separate hills.
const RAID_ISLAND_SPACING: float = 9.0

## Blob size in tiles, before the edge wobble.
const RAID_ISLAND_RADIUS_MIN: float = 3.4
const RAID_ISLAND_RADIUS_MAX: float = 6.2

## How often an island gets a second tier on top of its first.
const RAID_SECOND_TIER_CHANCE: float = 0.45

## Tiles clear around the arrival point, so nobody lands inside a cliff.
const RAID_ARRIVAL_CLEARANCE: float = 5.0

## Above this many tiles, an island may get a second ramp. One ramp on a large
## island is a siege; one on a small island is a choke.
const RAID_BIG_ISLAND_TILES: int = 40

## Chests per camp, and how many of those are locked.
const RAID_CHESTS_MIN: int = 3
const RAID_CHESTS_MAX: int = 5
const RAID_LOCKED_CHESTS: int = 2

## Tiles between anything placed, so two chests never share a corner.
const RAID_CHEST_SPACING: float = 6.0

## What a chest pays, before the tier multiplier.
## The region's sixteen-tile corner set, shared by the battlefield floor and the
## raid camp's raised ground - an island is different ground, so the region's own
## upper material is exactly the right texture for it.
const GROUND_TILE_FORMAT: String = "res://art/terrain/ground_%s_%02d.png"

## Fallback tint when a region has no corner set, so a camp is still readable
## rather than invisible.
const RAID_LEVEL_TINT: Array[Color] = [
	Color(0, 0, 0, 0),
	Color(0.62, 0.60, 0.54, 0.28),
	Color(0.78, 0.76, 0.70, 0.36),
]
const RAID_RAMP_TINT: Color = Color(0.88, 0.68, 0.32, 0.40)

## Lightening applied per tier above the first, so two stacked plates of the
## same material still read as two.
const RAID_TIER_LIFT: Color = Color(1.0, 0.98, 0.92, 0.16)
## The cliff outline, drawn over the textured surface.
##
## Softer than it was. With flat plates the line *was* the boundary; now the
## material transition carries most of that reading, and a hard black outline
## fights it — the art transition is organic while collision follows the tile
## grid, so a heavy line advertises the mismatch. It stays because the line is
## the *true* boundary and the art is decoration over it, but it reads as a
## shadow under the edge rather than as a drawn border. [TUNE]
const RAID_CLIFF_EDGE: Color = Color(0.04, 0.03, 0.04, 0.5)
const RAID_CLIFF_EDGE_WIDTH: float = 2.0

## Chest and key presentation.
## Terrain sits above the ground sprite and below everything that walks on it.
## The camp floor, under the elevation plates.
## Beast walk and idle frames, by convention. Absent falls back to the single
## profile sprite.
## The sidescroller ground the beast walks over, by region.
const BEAST_GROUND_TILE_FORMAT: String = "res://art/bg/side_%s_%02d.png"

## Strip size in tiles. Wide enough that two of them leapfrog without a seam
## crossing the screen; deep enough that the bottom is never visible.
const BEAST_GROUND_TILES_ACROSS: int = 32
const BEAST_GROUND_TILES_DOWN: int = 6

## World units one ground tile covers. Sets the sidescroller's pixel grain, and
## is the reason the ground is not drawn at its native 32px beside a beast four
## times that size.
const BEAST_GROUND_TILE_WORLD: float = 64.0

## How far the surface rolls, in tiles, either side of level.
##
## Zero, and deliberately. A sidescroller tileset has no slope tiles, so any
## roll at all is built from vertical cliff faces - which drew the scope as a
## platformer stage with ledges to jump between, under a beast that is plainly
## walking on level ground. Flat is the honest read.
const BEAST_GROUND_ROLL: float = 0.0

## The ground is lit by the sky it stands under.
##
## The tilesets are generated at full daylight saturation. Dropped unlit into
## Act I's dusk, the grass read as a bright green platform pasted over a sunset;
## a fixed dark tint fixed that and then drew Act II's desert as a slab of grey
## slate under a blazing white sky. One constant cannot serve three acts, because
## the three are not lit alike.
##
## So the tint is **sampled from the backdrop's own horizon** instead: the ground
## takes the hue of the light falling on it and a brightness scaled from that
## light's own. Nothing to retune when an act's sky is regenerated.
##
## How much of the backdrop, measured up from its bottom edge, counts as the
## light falling on the near ground.
const BEAST_GROUND_LIGHT_BAND: float = 0.14

## How much darker the near ground sits than the distance behind it. Foreground
## reads darker at any hour - it is nearer the viewer than the light is.
const BEAST_GROUND_SHADE: float = 0.86

## The horizon brightness that means "no tinting at all". Sampled light above
## this is clamped, so a white desert sky cannot bleach the ground past its art.
const BEAST_GROUND_LIGHT_NEUTRAL: float = 0.52

## The dimmest the ground is allowed to get, as a fraction of neutral light.
##
## Act I's dusk horizon is genuinely almost black, and lighting the ground
## faithfully from it drew a featureless void along the bottom of the screen -
## physically right and unreadable. The floor is the concession: the beast has to
## be seen standing on something.
const BEAST_GROUND_LIGHT_FLOOR: float = 0.52

## How far the ground's tint carries the sky's hue, against staying neutral.
##
## Not all the way. A tint normalised to the horizon's brightest channel is a
## *coloured* multiplier, and multiplying already-coloured art by it compounds:
## the snow act's blue sky pushed blue tiles to electric cyan. Pulled back toward
## white, the light still reads warm in the desert and cold in the snow without
## driving the art's own colour past where it was drawn.
const BEAST_GROUND_LIGHT_HUE: float = 0.35

## Where the strip sits, and how fast it passes. Faster than the sky, which is
## what sells the distance.
## How tall the beast scope draws its backdrop, whatever the art's native size.
const BEAST_BACKDROP_HEIGHT: float = 1080.0

const BEAST_GROUND_Y: float = 452.0
## The sky sits behind everything, including the ground the beast walks on.
##
## It was left at the default 0 while the ground was at -5, which drew a
## full-screen opaque painting over the ground strip: the sidescroller terrain
## was baked, scrolled and never once visible.
const BEAST_BACKDROP_Z: int = -20

const BEAST_GROUND_Z: int = -5
const BEAST_GROUND_SCROLL: float = 0.55

const BEAST_WALK_FRAME_FORMAT: String = "res://art/beast/beast_walk_%02d.png"
const BEAST_IDLE_FRAME_FORMAT: String = "res://art/beast/beast_idle_%02d.png"

## How many frames a series may hold. Loading stops at the first gap.
const BEAST_FRAME_MAX: int = 16

## How much the 256px frames are enlarged. The profile sprite they replace is
## 1024, so four keeps the beast the size it has always been on screen.
const BEAST_FRAME_SCALE: float = 4.0

## Where the framed beast sits, so its feet meet the ground strip.
const BEAST_FRAME_BASE_Y: float = -40.0

## Idle frames per second. Slow: a resting animal breathes, it does not fidget.
const BEAST_IDLE_FRAME_RATE: float = 5.0

## How often a painted clump uses the region's own plant rather than one of the
## extra kinds. High: the region's plant is what makes a field read as *this*
## act, and the extra kinds are punctuation rather than the sentence. [TUNE]
const FOLIAGE_REGION_PLANT_SHARE: float = 0.58

const RAID_GROUND_Z: int = -40

## Terrain sits above the ground sprite and below everything that walks on it.
const RAID_TERRAIN_Z: int = -20

const RAID_CHEST_GLOW: float = 96.0
const RAID_LOCKED_TINT: Color = Color(0.66, 0.74, 0.95)
const RAID_LOCKED_GLOW: Color = Color(0.55, 0.68, 1.0, 0.45)
const RAID_KEY_GLOW: Color = Color(1.0, 0.85, 0.42, 0.6)

## How many drops a chest scatters. Paid on the ground rather than into the
## purse, so opening one happens in front of the player.
const RAID_CHEST_PIECES: int = 6

## How near the hero must be to open a chest or take a key.
const RAID_REACH: float = 74.0

## What a chest pays, before the tier multiplier.
const RAID_CHEST_REWARD: int = 40
const RAID_LOCKED_CHEST_REWARD: int = 110

## Reward fraction for leaving early, scaled by kills against this target. [TUNE]
const RAID_PARTIAL_REWARD_KILLS: int = 60

# ------------------------------------------------------------------------------
# Run flow — GDD §7, §8, §9
# ------------------------------------------------------------------------------

## Seconds the studio splash holds before the menu. [TUNE]
const SPLASH_DURATION: float = 1.25

## Crossfade between scopes. [TUNE]
const SCOPE_FADE_TIME: float = 0.22

## Beast speed lost per point of town damage taken, and regained per second of
## a clean segment. [TUNE]
const BEAST_SPEED_LOSS_PER_DAMAGE: float = 0.0006
const BEAST_SPEED_RECOVERY_PER_SEC: float = 0.010

# ------------------------------------------------------------------------------
# Spells and ascension — GDD §9, §11
# ------------------------------------------------------------------------------

## Grace granted by a Rift Step, so blinking through a wind-up works. [TUNE]
const BLINK_IFRAMES: float = 0.25

## Stat multiplier added per boss ascension. Acts 1 and 2 also grant a spell
## slot; act 3's boss ends the run. [TUNE]
const ASCENSION_STAT_BONUS: float = 0.18

## Spells the hero starts a run with, drawn from the unlocked pool.
const STARTING_SPELLS: int = 2

## Damage a warded lane absorbs before the ward pops. [TUNE]
const WARD_ABSORB: float = 260.0

## Resources paid out by an act boss, on top of the reward package. [TUNE]
const BOSS_RESOURCE_REWARD: int = 180
const BOSS_ACT_SCALE: Array[float] = [1.25, 2.10, 3.20]

## Boss-phase reinforcements use the current wave curve, softened so the boss
## remains the centre of the encounter while the other lanes demand attention.
const BOSS_PHASE_REINFORCEMENT_HP_SCALE: float = 0.72
const BOSS_PHASE_REINFORCEMENT_DAMAGE_SCALE: float = 0.82
const BOSS_PHASE_MAX_REINFORCEMENTS: int = 6

## Source pixel size of a tower sprite. Towers are square like every other
## generated asset; the illusion of height comes from the art, not the file.
const TOWER_SPRITE_SIZE: float = 192.0

## How far up a tower is drawn from its build spot, so the base sits on the
## ground instead of the sprite being centred on it.
const TOWER_SPRITE_LIFT: float = 42.0

## How far below its plot's centre a tower's node sits, so it y-sorts on the
## ground it stands on rather than on its own middle.
##
## A y-sorted parent sorts children by their own y and Godot has no per-node sort
## origin, so the only way to sort a structure by its base is to put the node
## there. One tile - half a 2x2 footprint - lands it on the plot's front edge,
## which is exactly where the tower meets the ground.
##
## The visual does not move: the sprite, range ring and health bar are lifted by
## the same amount, and `Tower.origin()` hands the plot centre back to everything
## that measures range or spawns an effect, so nothing about the gameplay shifts.
const TOWER_SORT_LIFT: float = 64.0

## Layer health bars draw on. Above the sorted world layer and below the cloud
## shadows, so a readout is never occluded by the thing it is reporting on or by
## a plant standing in front of it. Absolute, not relative.
const HEALTH_BAR_Z: int = 20

# ==============================================================================
# PROCEDURAL ANIMATION
# ==============================================================================
#
# Every sprite in the game is one static PNG, so all motion is transform work.
# These drive SpriteAnimator. Values are for a mass of 1.0 (a human); the
# animator scales them by each unit's mass.

# ------------------------------------------------------------------------------
# Walk cycle
# ------------------------------------------------------------------------------

## Radians of stride advanced per pixel travelled. Phase is driven by distance
## rather than time so a slowed unit takes slower steps instead of skating. [TUNE]
const ANIM_STRIDE_PER_PIXEL: float = 0.011

## Peak height of the walk bounce, in pixels. [TUNE]
const ANIM_BOUNCE_HEIGHT: float = 5.0

## Sway speed as a fraction of the stride rate. 0.5 is one lean per two steps,
## 1.0 is one per step. Just under 1 keeps it lively without twitching. [TUNE]
const ANIM_TILT_RATE: float = 1

## Degrees of body sway at full speed. Runs at half stride rate, so the lean
## alternates once per two steps. [TUNE]
const ANIM_WALK_TILT: float = 3.5

## Horizontal drift accompanying the sway, in pixels. [TUNE]
const ANIM_WALK_SWAY: float = 2.2

## How fast the cycle settles back to neutral on stopping. [TUNE]
const ANIM_SETTLE_SPEED: float = 12.0

## Vertical compress applied when a foot lands. [TUNE]
const ANIM_STEP_SQUASH: float = 0.055

# ------------------------------------------------------------------------------
# Weight
# ------------------------------------------------------------------------------

## Units at or above this mass shake the screen when they walk. A human is 1.0,
## so only elites and bosses qualify. [TUNE]
const ANIM_SHAKE_MASS_THRESHOLD: float = 2.5

## Shake magnitude per point of mass above the threshold. [TUNE]
const ANIM_STEP_SHAKE: float = 1.1
const ANIM_STEP_SHAKE_TIME: float = 0.12

# ------------------------------------------------------------------------------
# Squash and stretch
# ------------------------------------------------------------------------------

## How much width is gained per unit of height lost. Roughly volume-preserving,
## which is what makes a squash read as physical. [TUNE]
const ANIM_SQUASH_WIDEN: float = 0.62

const ANIM_SQUASH_DECAY: float = 3.4
const ANIM_STRETCH_DECAY: float = 4.0

# ------------------------------------------------------------------------------
# Impacts
# ------------------------------------------------------------------------------

## How far the sprite is knocked from the source of a hit, in pixels. [TUNE]
const ANIM_RECOIL_DISTANCE: float = 9.0
const ANIM_RECOIL_DECAY: float = 90.0

## Compress applied on taking a hit. [TUNE]
const ANIM_HURT_SQUASH: float = 0.14

## How far the sprite throws itself into its own swing, in pixels. [TUNE]
const ANIM_PUNCH_DISTANCE: float = 13.0
const ANIM_PUNCH_DECAY: float = 130.0

## Degrees of roll into a swing. [TUNE]
const ANIM_PUNCH_LEAN: float = 9.0
const ANIM_PUNCH_SQUASH: float = 0.09
const ANIM_LEAN_DECAY: float = 70.0

# ------------------------------------------------------------------------------
# Dash and death
# ------------------------------------------------------------------------------

## Stretch along the dash axis. Held for the dash, then released. [TUNE]
const ANIM_DASH_STRETCH: float = 0.34

## Ghost images left behind by a dash, and how long each lingers. [TUNE]
const ANIM_DASH_GHOSTS: int = 4
const ANIM_DASH_GHOST_LIFE: float = 0.22

## Degrees a corpse rolls as it falls. [TUNE]
const ANIM_DEATH_SPIN: float = 74.0
const ANIM_DEATH_SQUASH: float = 0.3
const ANIM_SPIN_DECAY: float = 60.0

# ------------------------------------------------------------------------------
# Mass by unit kind
# ------------------------------------------------------------------------------
#
# EnemyData carries no mass field, so it is derived from category and body size.
# A field could be added later; this keeps the data files unchanged.

const ANIM_MASS_HERO: float = 1.0
const ANIM_MASS_BREED: float = 1.0
const ANIM_MASS_ELITE: float = 3.2
const ANIM_MASS_BOSS: float = 9.0

# ==============================================================================
# WORLD SCALE
# ==============================================================================

## World units behind one terrain texel.
##
## This was twelve, matched to the road: a road piece is a 32px tile drawn across
## PIECE (384) world units, and twelve put exactly the same number of world units
## behind a ground texel as behind a road texel. The reasoning was sound and the
## number was not. Twelve gives the *entire* 2880-unit battlefield a 256x256
## floor texture — one texel every eight screen pixels with the camera pulled all
## the way out, and far coarser than that in play. That is the flat green and tan
## patchwork with hard stepped edges the environment audit called the largest
## visual gap in the game.
##
## Four is three times the texel density for a 928px bake, and it costs the
## grain-match with the road, which stays at twelve because its scale is not a
## choice: half of a road tile has to cover a three-tile carriageway, so 32px art
## *must* span 384 units. Raising the road needs higher-resolution road art, not
## a different constant.
##
## Losing the match is the right trade and not only the cheap one. A road is a
## smoother thing than the undergrowth beside it, so a finer verge against a
## flatter carriageway reads as two materials; equal coarseness read as one
## blurry photograph of both.
##
## Expressed per texel rather than per tile so the floor art can change size -
## one tile, or a mosaic of four - without the scale needing to be retuned. [TUNE]
const GROUND_UNITS_PER_TEXEL: float = 4.0

## How quickly the floor's two materials trade places, in patches per ground
## cell. Low enough that moss and earth arrive in broad drifts a player reads as
## terrain; high enough that a screen holds several of them.
##
## Divided by three when the texel scale was, so the drifts stay exactly the size
## they were tuned to be. The unit is patches per *cell*, and cells got three
## times smaller — left alone, the same number would have shrunk every patch on
## the field to a third of its width. [TUNE]
const GROUND_PATCH_FREQUENCY: float = 0.0733

## Noise above this is the region's *upper* material. Slightly above zero, so the
## floor is mostly its base material with the second one laid over it in patches
## rather than the two splitting the field evenly. [TUNE]
const GROUND_PATCH_THRESHOLD: float = 0.06

## Sprite scale for units. The battlefield camera has to hold the whole lane
## ring, which leaves the hero about 79 screen pixels at source size - too small
## to read the art or the animation on it. [TUNE]
const HERO_SPRITE_SCALE: float = 1.75
const ENEMY_SPRITE_SCALE: float = 1.55
const ELITE_SPRITE_SCALE: float = 1.9
const BOSS_SPRITE_SCALE: float = 2.2

# ==============================================================================
# FEEDBACK VFX
# ==============================================================================
#
# Drives the Vfx autoload. All of it is cosmetic: turning every value here to
# zero should leave a game that plays identically and feels dead.

## Draw order for transient effects - above units, below the HUD.
const VFX_Z: int = 40

## Hard cap on live effect nodes. A wave of forty enemies dying at once would
## otherwise spawn hundreds of tweens in a frame.
const VFX_MAX_LIVE: int = 350

## Shards thrown by an impact. [TUNE]
const VFX_SPARK_LIFE: float = 0.32
const VFX_SPARK_SPREAD: float = 0.9

## Floating damage numbers. [TUNE]
const VFX_NUMBER_SIZE: int = 22
const VFX_NUMBER_SIZE_BIG: int = 32
const VFX_NUMBER_RISE: float = 64.0
const VFX_NUMBER_LIFE: float = 0.85

## Tower muzzle flash. [TUNE]
const VFX_MUZZLE_LENGTH: float = 44.0
const VFX_MUZZLE_WIDTH: float = 13.0
const VFX_MUZZLE_LIFE: float = 0.13

## Secondary impact language: radial rays and ground dust give large events a
## readable silhouette without needing large opaque screen flashes. [TUNE]
const VFX_RAY_LIFE: float = 0.24
const VFX_DUST_LIFE: float = 0.48
const VFX_BUILD_SHAKE: float = 4.0
const VFX_BOSS_PHASE_SHAKE: float = 11.0

## The wedge that sweeps through the hero's swing arc. [TUNE]
const VFX_SLASH_LIFE: float = 0.16

## Screen wash intensities, 0..1. [TUNE]
const VFX_HURT_FLASH: float = 0.26
const VFX_TOWN_FLASH: float = 0.34
const VFX_TOWN_SHAKE: float = 13.0

## Shortest gap between two town-damage flashes. Hits arriving inside the window
## are added up and reported as one burst when it ends, so a broken lane reads as
## a hard repeated pulse instead of holding the screen solid red. Must stay above
## the flash's own 0.4s life or the flashes overlap again. [TUNE]
const VFX_TOWN_FLASH_COOLDOWN: float = 0.85

## Town health fraction below which its damage flash doubles up. [TUNE]
const VFX_TOWN_CRITICAL: float = 0.35

## Hero health fraction at which the red edge starts, and how dark the edge gets
## at zero health. This is edge opacity, not screen opacity - the centre of the
## screen always stays clear. [TUNE]
const VFX_VIGNETTE_THRESHOLD: float = 0.5
const VFX_VIGNETTE_MAX: float = 0.85

## Level the ambience bed settles at, in decibels. It is meant to be noticed
## only when it stops. [TUNE]
const AMBIENCE_DB: float = -14.0

## Level the music settles at on its own bus, in decibels. The bus carries the
## player's volume slider, so this is purely how loud music sits against the
## sound effects. [TUNE]
const MUSIC_DB: float = -8.0

# ==============================================================================
# DAY / NIGHT AND LIGHTING
# ==============================================================================

## Phase a run begins at. 0.18 is mid-morning: bright, so the first minutes are
## readable before the game starts taking the light away. [TUNE]
const DAY_START_PHASE: float = 0.19

## Darkness above which night rules apply.
const NIGHT_THRESHOLD: float = 0.55

## Extra enemy count and stats at full darkness. Night is a difficulty state,
## not just a colour grade. [TUNE]
const NIGHT_DIFFICULTY_BONUS: float = 0.28

## Fraction of a light's energy that survives midday. Not zero, so a brazier
## still glows a little in daylight. [TUNE]
const LIGHT_DAY_ENERGY: float = 0.12

## Hero's carried light. [TUNE]
const HERO_LIGHT_RADIUS: float = 330.0
const HERO_LIGHT_ENERGY: float = 1.20
const HERO_LIGHT_COLOUR: Color = Color(1.0, 0.86, 0.62)
const HERO_LIGHT_FLICKER: float = 0.10

## Tower braziers, tinted by element. [TUNE]
const TOWER_LIGHT_RADIUS: float = 210.0
const TOWER_LIGHT_ENERGY: float = 1.00
const TOWER_LIGHT_FLICKER: float = 0.16

## The town is the brightest thing on the field - it is what you are defending.
## Pulled in from 620 because at that reach it was a floodlight over the whole
## middle of the map, and nothing near the town could be in shadow. [TUNE]
const TOWN_LIGHT_RADIUS: float = 430.0
const TOWN_LIGHT_ENERGY: float = 1.30
const TOWN_LIGHT_COLOUR: Color = Color(1.0, 0.82, 0.55)

## Enemy eyes, so a wave is visible in the dark before it is in tower range.
const ENEMY_LIGHT_RADIUS: float = 110.0
const ENEMY_LIGHT_ENERGY: float = 0.5

# ------------------------------------------------------------------------------
# Projectiles
# ------------------------------------------------------------------------------

const PROJECTILE_LENGTH: float = 26.0
const PROJECTILE_WIDTH: float = 5.0

## How fast a shot turns to follow its target, per second. [TUNE]
const PROJECTILE_TURN_RATE: float = 9.0

## Extra slack on the hit test, so a fast shot cannot tunnel through.
const PROJECTILE_HIT_RADIUS: float = 16.0

## A shot that has not connected by now fizzles.
const PROJECTILE_MAX_LIFE: float = 2.5

## Points held in a shot's trail. More is a longer ribbon. [TUNE]
const PROJECTILE_TRAIL_POINTS: int = 14

## Size of the soft glow behind the head, as a multiple of the core. [TUNE]
const PROJECTILE_GLOW_SCALE: float = 2.4

## How fast an Earth shot tumbles, in radians per second. [TUNE]
const PROJECTILE_SPIN_RATE: float = 9.0

## Impact burst. [TUNE]
const PROJECTILE_IMPACT_SPARKS: int = 7
const PROJECTILE_IMPACT_RING: float = 46.0
const PROJECTILE_IMPACT_FLASH: float = 17.0

const PROJECTILE_LIGHT_RADIUS: float = 120.0
const PROJECTILE_LIGHT_ENERGY: float = 0.7

## Hot filament inside the elemental ribbon and occasional shedding motes.
const PROJECTILE_FILAMENT_WIDTH: float = 1.65
const PROJECTILE_MOTE_INTERVAL: float = 0.055
const PROJECTILE_MOTE_LIFE: float = 0.22

# ------------------------------------------------------------------------------
# See-through structures
# ------------------------------------------------------------------------------

## How transparent a tower or building becomes when the hero is behind it. [TUNE]
const OCCLUDER_ALPHA: float = 0.38

## Tolerance added to a sprite's half-width when deciding whether the hero is
## actually behind it. The trigger area otherwise comes from the sprite size.
const OCCLUDER_SIDE_MARGIN: float = 26.0

## How fast the fade moves, in alpha per second.
const OCCLUDER_FADE_SPEED: float = 6.0

# ------------------------------------------------------------------------------
# Cloud shadows
# ------------------------------------------------------------------------------

## Cloud shadows drift across the field, darkening ground and units alike. Speed
## is in pixels per second; the two layers move at different rates so the sky has
## depth rather than sliding as one sheet. [TUNE]
## Drift. Slightly quicker than it was: on a field half again as large, the old
## speed crossed the screen so slowly the motion read as a static gradient.
const CLOUD_SPEED: Vector2 = Vector2(38.0, 14.0)
const CLOUD_SPEED_FAR: Vector2 = Vector2(17.0, 6.0)

## How dark a shadow gets at full daylight, 0..1. Clouds cast nothing at night,
## because there is no sun to block. [TUNE]
## How dark a cloud shadow gets at full daylight.
##
## Raised with the fade curve in `CloudShadows._on_phase`. At 0.42 against a
## deepened night grade they were a few percent of themselves for most of a run -
## reported, correctly, as "not really noticeable if they're even there". [TUNE]
const CLOUD_DARKNESS: float = 0.60

## Size of the noise features, in pixels. Larger is fewer, bigger clouds. [TUNE]
const CLOUD_SCALE: float = 900.0
const CLOUD_SCALE_FAR: float = 1500.0

## Fraction of the noise range that becomes shadow. Higher is more overcast. [TUNE]
const CLOUD_COVERAGE: float = 0.46

# ------------------------------------------------------------------------------
# Visible tower tiers
# ------------------------------------------------------------------------------
#
# An upgrade the player paid for has to be visible from across the map without
# clicking anything.

## Sprite growth per level above the first. [TUNE]
const TOWER_LEVEL_SCALE_STEP: float = 0.10

## How far the sprite tints toward its element colour per level, 0..1. [TUNE]
const TOWER_LEVEL_TINT_STEP: float = 0.18

## Extra brazier energy per level. [TUNE]
const TOWER_LEVEL_LIGHT_STEP: float = 0.30

## How much bigger a projectile is per level of the tower that fired it. [TUNE]
const PROJECTILE_TIER_SCALE: float = 0.16

# ==============================================================================
# TORCHES, FOLIAGE AND PATH BLENDING
# ==============================================================================

# ------------------------------------------------------------------------------
# Torches
# ------------------------------------------------------------------------------
#
# Lighting that is also a mechanic. Enemies snuff torches as they pass; the hero
# relights them by standing close. A dark lane sends stronger, more frequent
# enemies, so keeping the road lit competes for attention with everything else.

## Where along a road the torches stand, measured out from the town centre.
##
## Three stops each side of every road: 3 x 2 sides x 4 lanes = 24 torches.
## Deliberately *between* the build spots in TOWER_SLOT_RADII rather than level
## with them - a torch standing beside a tower competes with it for attention and
## covers the thing the player is trying to click. [TUNE]
## Torch stops per side of each road, spread evenly by arc length.
##
## Replaces TORCH_ALONG_STOPS, which measured distance out from the town. That
## was the same thing when roads were straight; on a bent road it puts torches on
## the carriageway. 3 per side x 2 sides x 4 roads = 24, the count the manifest
## and the asset budget already assume. [TUNE]
## Five per side, forty in all. Three left long unlit stretches on the outside
## of a U-bend, where the arc is longest and the light is needed most. Torches
## are built in code rather than authored, so the count costs art nothing. [TUNE]
## Distance a torch keeps from either end of the straight it stands on.
##
## Torches used to be placed by distance along the whole polyline, which meant
## one landing near a bend took its heading from whichever segment contained it
## and stood the post in the middle of the perpendicular leg. They are placed per
## straight now, and this keeps them out of the corners entirely. [TUNE]
## U-bends per road (GDD v4 SS13). One: the road runs in, turns across, doubles
## back away from the town, turns across again, then resumes. That single detour
## is what encloses the buildable pocket - a second would halve the pocket and
## double the walk without adding a decision.
const ROAD_BEND_COUNT: int = 1

## How far out a corner torch stands from the vertex it lights.
##
## A multiple of the straight offset rather than the same number: at a right
## angle a post has to clear two roads at once, and sqrt(2) is exactly the extra
## reach that keeps its margin equal to a torch on a straight.
const TORCH_CORNER_OFFSET_SCALE: float = 1.42

const TORCH_CORNER_CLEARANCE: float = 150.0

## Target gap between torches along a straight. The real gap is this rounded to
## fit the segment, so spacing is even within a run and no two end up shoulder to
## shoulder across a bend. [TUNE]
const TORCH_SPACING: float = 300.0

## No two torches may stand closer than this.
##
## Spacing is even *within* a straight by construction, but a straight's end stop
## and the corner post of the bend past it are placed by different rules and land
## on top of each other. Each is correct locally; only the set knows they crowd.
## Applied as a filter over the whole lane after every position is proposed.
## [TUNE]
const TORCH_MIN_GAP: float = 190.0

## One in this many torches casts a real shadow at High. The rest are promoted at
## Ultra without rebuilding the field.
const TORCH_FEATURED_SHADOW_EVERY: int = 4

## One torch in this many carries a real PointLight2D. The rest keep their flame,
## their glow and their smoke, and are lit by their neighbours' pools.
##
## Measured, not guessed. Every 2D light re-draws every item it covers, so cost
## is lights x items-under-them - and widening the pools to 360 while raising the
## count to about sixty took a quiet field to 107 lights and 6,000 draw calls at
## 21 FPS. The pools overlap heavily at that radius, so lighting every second
## post looks the same and costs half. [TUNE]
const TORCH_LIGHT_EVERY: int = 2

## How far to the side of the lane centre they stand.
##
## Moved out with the build spots. When TOWER_SLOT_OFFSET went from 96 to 158 to
## get the click targets off the road, the towers arrived where the torches were
## standing - 215 was chosen to clear a tower at 96 and clears nothing at 158.
##
## A tower sprite is ~192 wide, so its edge reaches 158 + 96 = 254. 300 keeps the
## flames outside that with room to spare. [TUNE]
## How far to the side of the road's centre line a torch stands.
##
## 70 puts it on the road shoulder: the carriageway runs to +-96, and enemies
## walk within +-55, so a torch here is off the walking corridor and still on
## unbuildable ground - which is what stops it ever standing where a tower was
## wanted. It was 300, chosen when the buildable field was open ground beside a
## straight road and there was no grid to conflict with. [TUNE]
## Just off the carriageway, not on it.
##
## The road runs to +-96. 70 stood the posts *on* the road surface - chosen so a
## torch could never occupy ground the player wanted to build on, which it does
## solve, and which is not worth standing a burning post in the middle of the
## lane the enemies walk down. 116 clears the road edge by twenty units, so the
## flame reads as lining the road rather than blocking it, and still throws its
## light across the carriageway.
##
## 116 was the first attempt and cleared the road by only twenty units, which at
## this zoom is a dozen pixels - close enough that torches on the outside of a
## bend still read as standing in the lane. 138 clears it by forty and reads as
## lining the road from every angle.
##
## Towers do not conflict: placement is by tile and a torch occupies none, so the
## worst case is a tower sprite overlapping a flame - and towers y-sort above the
## ground now, so the tower simply occludes it, which is what should happen.
const TORCH_LANE_OFFSET: float = 138.0

## Height of the post and of the fire on top of it. Sized against the camera, not
## against realism: at battlefield zoom a 34px torch was a lit matchstick, and a
## thing the player is meant to notice going out has to be legible from across
## the lane. [TUNE]
const TORCH_HEIGHT: float = 58.0
const TORCH_FLAME_SIZE: float = 26.0

## Tight and bright, not wide and soft.
##
## At 340 the twenty-four pools overlapped so heavily that the whole field was
## lit at once: the night stopped being dark, and every cast shadow was filled in
## by three other torches, so the shadows may as well not have been there. A
## smaller radius at higher energy gives each torch a patch of ground it owns —
## which is what makes the dark between them read as dark, and what lets a shadow
## survive long enough to be seen. [TUNE]
const TORCH_LIGHT_COLOUR: Color = Color(1.0, 0.70, 0.34)
## A torch's pool of light.
##
## Widened with the darker night grade below. The two are one change: a deeper
## night is only atmospheric if the lit ground is genuinely lit, and a 225 pool
## against a darker field left the road legible only directly under the flame.
## At 360 the pools overlap along a straight, so a road reads as a lit ribbon
## through darkness rather than as a row of separate glows. [TUNE]
const TORCH_LIGHT_RADIUS: float = 360.0

## Per-torch energy, deliberately low for the radius.
##
## Light adds. At 360 the pools overlap along a straight, so two torches sum
## where they meet and a torch standing alone looks dim beside them - which is
## what "some glow more than others" was, rather than any torch being faulty.
## Energy came down as the radius went up so the *sum* lands where a single
## bright torch used to, and the road is lit evenly instead of in bright knots.
const TORCH_LIGHT_ENERGY: float = 1.15

## High features one full cast-shadow pool per road; every other brazier still
## lights, dims and flickers, while Ultra promotes all twenty-four to shadow
## casters. The featured stop is central so the effect crosses the most-played
## part of each lane. [TUNE]


## The light's own flicker. Low on purpose: the flame *shape* now carries the
## unsteadiness, and a light that strobes as hard as the silhouette does reads as
## a fault in the renderer rather than as fire. [TUNE]
const TORCH_FLICKER: float = 0.16

## How close an enemy must draw level with a torch to snuff it, measured **along
## the road** rather than as a straight line.
##
## This is not a proximity radius and must not be read as one. Torches stand 300px
## off the lane and enemies walk within 55px of its centre, so no straight-line
## radius small enough to be meaningful could ever have matched - which is why the
## mechanic silently never fired. See Enemy._tick_torch_snuff. [TUNE]
const TORCH_SNUFF_RANGE: float = 120

## Pressure is accumulated while enemies remain level with a torch, not rolled
## as an instant binary snuff. One walker takes time; a crowd can overwhelm it.
## Elite and boss bodies count as more than one ordinary walker. [TUNE]
const TORCH_PRESSURE_SAMPLE: float = 0.18
const TORCH_DIM_PER_ENEMY_SECOND: float = 0.082
const TORCH_PRESSURE_MAX_WEIGHT: float = 6.0
const TORCH_ELITE_PRESSURE: float = 1.55
const TORCH_BOSS_PRESSURE: float = 2.4
const TORCH_RECOVERY_PER_SECOND: float = 0.13
const TORCH_HERO_RECOVERY_PER_SECOND: float = 0.16
const TORCH_HERO_MIN_STRENGTH: float = 0.18

## How close the hero stands, and for how long, to relight one. [TUNE]
const TORCH_RELIGHT_RANGE: float = 150
const TORCH_RELIGHT_TIME: float = 1.1

## Extra enemy strength and spawn weight at a fully dark lane, applied on top of
## the night multiplier. A dark lane at night is genuinely dangerous. [TUNE]
const TORCH_DARK_DIFFICULTY: float = 0.34

## How strongly a dark lane pulls the wave director toward choosing it. [TUNE]
const TORCH_DARK_LANE_BIAS: float = 2.2

# ------------------------------------------------------------------------------
# Fire
# ------------------------------------------------------------------------------
#
# Shared by the lane torches and the burning city. There is no fire art in the
# project and none is wanted at these sizes - a static sprite reads as a decal.
# See scripts/systems/flame.gd for what each of these does to the silhouette.

## Horizontal slices per flame layer. More is smoother and costs draw calls; the
## additive glow behind hides a surprising amount of blockiness. [TUNE]
const FLAME_SEGMENTS: int = 9

## How fast the tongues travel up the flame. [TUNE]
const FLAME_DANCE_SPEED: float = 3.4

## How far the tip wanders sideways, as a fraction of flame height. The base
## never moves - the displacement grows with height, which is the whole
## difference between a flame and a leaning triangle. [TUNE]
const FLAME_LICK: float = 0.34

## How much the height itself breathes, 0..1. A flame of constant height is a
## lamp. [TUNE]
const FLAME_BREATH: float = 0.26

## Colours, hottest first. Drawn additively and nested, so the overlap blooms.
const FLAME_CORE: Color = Color(1.00, 0.96, 0.80)
const FLAME_MID: Color = Color(1.00, 0.62, 0.18)
const FLAME_BODY: Color = Color(0.90, 0.24, 0.06)

## Soft glow behind the flame: radius as a multiple of flame size, and strength.
## This replaces the old halo polygon, whose fourteen straight sides were plainly
## visible as a disc. [TUNE]
const FLAME_GLOW_SCALE: float = 4.2
const FLAME_GLOW_ALPHA: float = 0.34

## Embers. A real particle system, so they inherit spread, damping and a colour
## ramp rather than being hand-tweened one at a time. [TUNE]
const FLAME_EMBER_AMOUNT: int = 16
const FLAME_EMBER_LIFETIME: float = 1.7
const FLAME_EMBER_SPEED: float = 42.0
const FLAME_EMBER_SPREAD: float = 26.0
const FLAME_EMBER_RISE: float = 34.0

## Smoke, drawn behind the flame and mixed rather than added. [TUNE]
const FLAME_SMOKE_AMOUNT: int = 11
const FLAME_SMOKE_LIFETIME: float = 3.1
const FLAME_SMOKE_SPEED: float = 20.0
const FLAME_SMOKE_ALPHA: float = 0.26
const FLAME_SMOKE_COLOUR: Color = Color(0.20, 0.19, 0.18)

# ------------------------------------------------------------------------------
# Shadows
# ------------------------------------------------------------------------------
#
# Two kinds, because they answer different questions.
#
# A *contact* shadow is the soft pool directly under a thing. It is what stops
# units looking pasted onto the floor, and everything that stands on the ground
# gets one. It tracks the sun: long and raking at dawn and dusk, tight at noon.
#
# A *cast* shadow is real: a LightOccluder2D blocking a torch, throwing a hard
# streak away from the flame. That is the one that makes a lit road at night look
# like a lit road.

## Contact shadow strength at noon and at midnight. Darker by day because by
## night the torches are doing the work. [TUNE]
const SHADOW_ALPHA_DAY: float = 0.52
const SHADOW_ALPHA_NIGHT: float = 0.22

## How far the pool slides from under its owner, in quad half-widths, when the
## sun is on the horizon versus overhead. [TUNE]
const SHADOW_OFFSET_LOW: float = 0.46
const SHADOW_OFFSET_NOON: float = 0.10

## How flat the pool is. 1.0 is a circle; higher reads as ground seen at an
## angle, which is the projection the rest of the art assumes. [TUNE]
const SHADOW_SQUASH: float = 2.30

## Pool width as a fraction of the owner's sprite width. [TUNE]
const SHADOW_WIDTH: float = 0.66

## Real cast shadows from torch and town light. Turn off if the field ever gets
## dense enough for the shadow passes to cost more than they are worth. [TUNE]
const SHADOW_CAST_ENABLED: bool = true

## Softening on cast shadow edges. Zero is a hard stencil edge. [TUNE]
const SHADOW_FILTER_SMOOTH: float = 2.1

## Occluder layers, so a light can be told what it may throw a shadow of. Bit 1
## is scenery, bit 2 is units - the town light uses this to shadow the people
## walking past it without shadowing itself.
const SHADOW_LAYER_SCENERY: int = 1
const SHADOW_LAYER_UNITS: int = 2

# ------------------------------------------------------------------------------
# Foliage
# ------------------------------------------------------------------------------

## Clumps scattered per terrain. [TUNE]
const FOLIAGE_COUNT: int = 420

## Multiples of LANE_WIDTH kept clear either side of a road. [TUNE]
const FOLIAGE_LANE_CLEARANCE: float = 1.15

## Clear radius around a build spot and around the town. [TUNE]
const FOLIAGE_SLOT_MARGIN: float = 130.0
const FOLIAGE_TOWN_MARGIN: float = 180.0

## Fraction of clumps that are low ground cover rather than tall growth. Two
## layers at different heights read as undergrowth; one layer reads as a field
## of identical weeds. [TUNE]
const FOLIAGE_GROUND_RATIO: float = 0.55

## Ground cover is smaller and sways less than the tall layer.
const FOLIAGE_GROUND_SCALE: float = 0.64
const FOLIAGE_GROUND_SWAY: float = 0.45

const FOLIAGE_MIN_SCALE: float = 0.7
const FOLIAGE_MAX_SCALE: float = 1.5

## Sway. Degrees of lean, and how fast the wind moves. [TUNE]
const FOLIAGE_SWAY_DEGREES: float = 5.5
const FOLIAGE_SWAY_SPEED: float = 1.15

## How far a blade's tip travels at full lean, in world units.
const FOLIAGE_SWAY_REACH: float = 34.0

## The same, for painted plants. Much less: a shrub, a rock or a flowering
## succulent is a stiff thing with a woody base, and giving it a blade of grass's
## whip is what makes scattered sprites read as cardboard flapping in a breeze.
const FOLIAGE_SWAY_REACH_PAINTED: float = 9.0

## Foliage moves slowly enough that 30 transform updates per second are visually
## continuous, while updating hundreds of off-road clumps at the render rate
## spends CPU on sub-pixel changes the player cannot see. [TUNE]
const FOLIAGE_UPDATE_INTERVAL: float = 1.0 / 30.0

# ------------------------------------------------------------------------------
# Path blending
# ------------------------------------------------------------------------------

## Half-width of the road's solid interior, in pixels, measured out from the
## centre line. Inside this radius the road is untouched: no fade, no noise.
##
## This is the value that went wrong. It used to be implied rather than stated -
## the fringe was 46px of an 88px half-width, so the fade began barely off the
## centre line and, at 55% tint on top, the roads all but vanished. Stating the
## solid core explicitly means widening the fringe can never eat the road. [TUNE]
const PATH_CORE_RADIUS: float = 70.0

## Width of the soft, noisy fringe *outside* the core, in pixels. Core plus
## fringe should land near the road's half-width (LANE_WIDTH * 1.6 / 2 = 88);
## more than that and the fringe is simply clipped. [TUNE]
const PATH_EDGE_FADE: float = 39.0

## How hard the fringe is broken up, 0..1. Only ever moves where the fade
## *starts*, never how opaque the interior is. [TUNE]
const PATH_EDGE_NOISE: float = 0.68

## Fraction of each end of a road given over to fading out, so the road
## dissolves into the distance instead of stopping at a line. [TUNE]
const PATH_END_FADE: float = 0.10

## Scale of the fringe noise, in pixels. [TUNE]
const PATH_NOISE_SCALE: float = 74.0

## Opacity of the road over the terrain. A road you cannot see is not a road.
## [TUNE]
const PATH_TINT_ALPHA: float = 0.84

## Multiplied into the road art so trodden ground sits darker than the country
## either side of it.
##
## This is doing more work than it looks like. The road texture and the jungle
## terrain are close in both hue and value, so at full opacity the lane was still
## only a faintly different rectangle. Contrast, not opacity, is what makes a
## road read as a road — and a road the player cannot pick out at a glance is a
## tower-defense map with no lanes on it. [TUNE]
const PATH_DARKEN: float = 0.76

## Warmth pushed into the road, so trodden earth reads brown against grey rock.
## Two channels of separation do more than another 10% of darkening. [TUNE]
const PATH_WARMTH: Color = Color(1.06, 0.94, 0.78)

# ------------------------------------------------------------------------------
# Lane pressure rosette
# ------------------------------------------------------------------------------
#
# The directional threat readout (GDD SS3). It replaced four labelled progress
# bars floating around the middle of the screen, which were as loud at rest as
# under attack and put the letters N/E/S/W over the battlefield for no reason -
# the player can already see which way is up.
#
# An arc sitting just outside the town, on the side the threat is coming from,
# says the same thing without naming it, and says nothing at all when calm.

## Distance from screen centre to the arc, in pixels. Just outside the town. [TUNE]
const LANE_RING_RADIUS: float = 208.0

## Thickness of the arc, and how much thicker it grows at full pressure. [TUNE]
const LANE_RING_THICKNESS: float = 5.0
const LANE_RING_GROWTH: float = 7.0

## How much of the circle each lane's arc spans, in degrees. [TUNE]
const LANE_RING_ARC_DEGREES: float = 58.0

## Opacity of the empty track, and of a full arc. The track has to be faint
## enough to ignore and present enough to give the fill somewhere to go. [TUNE]
const LANE_RING_TRACK_ALPHA: float = 0.13
const LANE_RING_FULL_ALPHA: float = 0.92

## Calm to critical. The fill runs between these. [TUNE]
const LANE_RING_CALM: Color = Color(0.85, 0.66, 0.28)
const LANE_RING_HOT: Color = Color(0.86, 0.24, 0.14)

## Size of the arrow that appears outside an alarmed arc, in pixels. [TUNE]
const LANE_RING_ARROW_SIZE: float = 38.0

## Pressure above which the arc pulses. Below it the readout is still. [TUNE]
const LANE_RING_ALARM_AT: float = 0.62
const LANE_RING_PULSE_SPEED: float = 5.4

# ------------------------------------------------------------------------------
# The burning city
# ------------------------------------------------------------------------------
#
# The city already swapped to a more broken sprite at each damage stage, which
# reads on a still frame and not at all in motion. Fire does: it moves, it lights
# the ground around it, and it is the difference between damaged art and a place
# that is actually losing.

## Fires alight at each damage stage, in order (untouched first). [TUNE]
const CITY_FIRES_PER_STAGE: Array[int] = [0, 2, 4, 7]

## Flame size at the smallest and largest, so a burning city is not a row of
## identical fires. [TUNE]
const CITY_FIRE_SIZE_MIN: float = 15.0
const CITY_FIRE_SIZE_MAX: float = 30.0

## Half-extents of the area fires are scattered over, as a fraction of the city
## sprite. Kept inside the silhouette so nothing burns off the edge of it. [TUNE]
const CITY_FIRE_SPREAD: Vector2 = Vector2(0.30, 0.16)

## Smoke column above the city, thickening with each stage. [TUNE]
const CITY_SMOKE_AMOUNT: int = 20
const CITY_SMOKE_LIFETIME: float = 4.4
const CITY_SMOKE_SPEED: float = 30.0
const CITY_SMOKE_ALPHA: float = 0.30

# ---------------------------------------------------------------------------
# Leaderboard score
#
# One number per finished run. Every coefficient here is a statement about what
# playing well means, which is why they are all in one place and none of them
# live inside `Score` - a formula whose weights are scattered is a formula
# nobody can retune without re-reading it.
#
# Calibration, on Normal: a clean Act I loss lands near 900, a full clear near
# 5,800, and a perfect fast clear near 8,000. Hell multiplies that sixfold, so a
# combined board sorts by difficulty first without needing a second key.
# ---------------------------------------------------------------------------

## Progress, which is most of a score. A run is a road, and the first thing a
## board should answer is how far down it you got.
const SCORE_PER_WAVE: float = 120.0
const SCORE_PER_ACT: float = 450.0

## Reaching the summit. Large enough that no amount of endless grinding on a lost
## run out-scores finishing the game.
const SCORE_VICTORY: float = 1800.0

## Awarded on a win, scaled by how far under par the run came in.
const SCORE_SPEED: float = 900.0

## The clear that speed is measured against, in seconds. Fifty minutes: about
## what an unhurried full run takes, so the bonus rewards a defence that holds
## without nursing rather than one that rushes.
const SCORE_PAR_SECONDS: float = 3000.0

## An untouched town, at full value. Measured from damage taken rather than
## health remaining, because Hearthmend repairs it and a town rebuilt three times
## was patched, not defended.
const SCORE_TOWN_INTACT: float = 1200.0

## Per wave of the victory lap. Worth more than a campaign wave because by then
## nothing is being unlocked and the only thing left to spend is skill.
const SCORE_PER_ENDLESS_WAVE: float = 260.0

## What a hero death costs, and the share of a score deaths can never eat.
##
## The floor is the important half. A penalty that can reach zero invites a
## player to stop playing rather than risk one more death, which is the opposite
## of what a board is for.
const SCORE_DEATH_COST: float = 220.0
const SCORE_DEATH_FLOOR: float = 0.45

# ---------------------------------------------------------------------------
# Main menu
#
# The menu art stays painterly and is deliberately *not* being redrawn as pixel
# art. The style-clash argument that moved the act backdrops does not reach it:
# a backdrop shares a frame with a pixel-art beast standing in front of it, and
# key art shares a frame with nothing. Redrawing it would trade a strong image
# for a consistent one nobody is in a position to compare.
#
# What it did lack is motion. A completely still first screen reads as a
# screenshot of a game rather than as a game waiting.
# ---------------------------------------------------------------------------

## How far the key art drifts from centre, as a fraction of its own size.
##
## Small enough that nobody catches it moving, which is the point: a menu that
## visibly pans is a menu doing a trick. Paired with the overscan below, so the
## art never drifts far enough to show an edge.
const MENU_DRIFT: float = 0.012

## How long one full drift cycle takes, in seconds. Slow — a minute and a half,
## so a player reading the buttons never sees it repeat.
const MENU_DRIFT_PERIOD: float = 92.0

## How much larger than the screen the art is drawn, so drifting cannot uncover
## an edge. Derived from the drift rather than guessed: twice the travel, plus a
## little, is exactly enough.
const MENU_OVERSCAN: float = 1.0 + MENU_DRIFT * 2.4

## Seconds a beast idle frame is held on the menu.
##
## Slower than the scope's, deliberately. In the scope the beast is walking and
## the gait drives the frame; here it is standing still and breathing, and a
## breath that keeps time with a walk reads as impatience.
const MENU_BEAST_FRAME_TIME: float = 0.22

## How fast the menu's mist bands cross, in pixels a second at 1080p. Slow
## enough to be weather rather than a scrolling texture.
const MENU_MIST_SPEED: float = 7.5


# ---------------------------------------------------------------------------
# Milestone cinematics
# ---------------------------------------------------------------------------

## One milestone remains below five seconds when left untouched, far inside the
## GDD's ten-second interruption ceiling. All four values are real-time seconds.
## [TUNE]
const MILESTONE_CINEMATIC_FADE_IN_SECONDS: float = 0.55
const MILESTONE_CINEMATIC_HOLD_SECONDS: float = 3.4
const MILESTONE_CINEMATIC_FADE_OUT_SECONDS: float = 0.4
const MILESTONE_CINEMATIC_SKIP_HOLD_SECONDS: float = 0.9


# ---------------------------------------------------------------------------
# Touch controls
# ---------------------------------------------------------------------------

## How far from where a thumb landed counts as a full push, in screen pixels at
## the 1080p design resolution.
##
## A thumb rolls rather than slides, so this is much shorter than it looks: past
## about this far the thumb has to lift and the stick sticks at full tilt.
const TOUCH_STICK_REACH: float = 130.0

## How far a thumb may wander before it means anything. Larger than a mouse
## deadzone would be, because a resting thumb on glass is never still.
const TOUCH_STICK_DEADZONE: float = 14.0

## How far the right stick must be pushed before it is asking for an attack
## rather than only turning the hero.
##
## Not zero, deliberately: aiming without swinging has to be possible, or a
## player cannot line a shot up without committing to it.
const TOUCH_ATTACK_THRESHOLD: float = 0.45

## How visible the on-screen controls are.
##
## Low on purpose. They sit over the battlefield, and the thing a player needs to
## see is the battlefield - a thumb already knows where it is.
const TOUCH_OPACITY: float = 0.34

## How much bigger every interactive element is when the game is being played
## with a thumb.
##
## Fingertips are about 9mm across and a mouse cursor is one pixel. Apple and
## Google both put the minimum comfortable target near 44-48 density-independent
## pixels; the desktop buttons here are 54 tall, which is fine under a cursor and
## marginal under a thumb once a phone's scaling is applied.
##
## Applied as a scale rather than as a second set of sizes, so there is one
## layout with one set of proportions and no chance of the two drifting apart.
const UI_TOUCH_SCALE: float = 1.28


## How visible a persistent touch *button* is.
##
## Higher than a stick's, because the two are seen under opposite conditions. A
## stick is drawn only once a thumb is already on it, so it never has to be
## found; a button is on screen the whole time and has to be found exactly once.
const TOUCH_BUTTON_OPACITY: float = 0.58


## The one field a stranger chooses, so the one field that needs a rule.
const SCORE_NAME_MAX: int = 20
const SCORE_NAME_FALLBACK: String = "Oathless"

## Bounds shared by the client, save reader and Supabase table policy.
const LEADERBOARD_SCORE_MAX: int = 999999999
const LEADERBOARD_ACT_MAX: int = 3
const LEADERBOARD_WAVE_MAX: int = 100000
const LEADERBOARD_DURATION_MAX: int = 86400

## Network presentation. Reads are deliberately short and bounded because a
## public board must never stall the menu or make an unbounded response.
const LEADERBOARD_PAGE_SIZE: int = 50
## How long one request may take before it is abandoned.
##
## Was eight seconds, which is fine on a desk and too short on a phone. Godot's
## web build implements `HTTPRequest` with `fetch()` and an `AbortController`, so
## this is a hard abort — and the first request of a session pays for a cold DNS
## lookup and TLS handshake on mobile data while the game is still busy. An
## abandoned request then reports as a transport failure, which is
## indistinguishable from having no connection at all and was reported as such.
const LEADERBOARD_REQUEST_TIMEOUT: float = 25.0

## How many of this save's own runs the local board keeps.
##
## Bounded because it is written into the save on every run end, and an unbounded
## list of finished runs is a save file that grows forever.
const LEADERBOARD_LOCAL_MAX: int = 60

## How many unsent runs the outbox holds before it stops accepting more. Small:
## a player this far offline is not going to care about the fortieth queued row,
## and the cap is what stops a broken table from filling a save.
const LEADERBOARD_PENDING_MAX: int = 12
