extends Node

## Every tuning constant in the game, in one place.
##
## Autoloaded as `Balance`. Gameplay scripts must never contain a magic number —
## if a value could ever be argued about, it belongs here with a GDD reference.
##
## Section markers (§) point at docs/Game_Design_v2.md. Values the GDD tags
## `[TUNE]` are starting values chosen to make the system buildable, not balance
## claims. Expect all of them to move.
##
## No `class_name` here: the autoload singleton is already named `Balance`, and
## declaring a global class of the same name is a hard error in Godot 4.

# ==============================================================================
# BATTLEFIELD — GDD §3.1
# ==============================================================================

## Radius from the city centre to each of the four N/S/E/W tower slots. [TUNE]
const TOWER_SLOT_RADIUS: float = 250.0

## Radius of the arena edge; enemies spawn on this ring. [TUNE]
const ENEMY_SPAWN_RADIUS: float = 800.0

## Hero base movement speed. The GDD calls this the hero's most valuable stat:
## N tower -> S tower is ~2.5s, long enough that the choice costs something. [TUNE]
const HERO_MOVE_SPEED: float = 200.0

## Enemy walk speed. Spawn ring -> tower ring is ~9s, the player's reaction
## window. Tune as a set with HERO_MOVE_SPEED and ENEMY_SPAWN_RADIUS. [TUNE]
const ENEMY_WALK_SPEED: float = 60.0

## Tower firing range. Slight overlap between adjacent slots so the diagonals
## have no dead zones. [TUNE]
const TOWER_RANGE: float = 220.0

## Duration of the dash's invulnerability window. [TUNE]
const HERO_DASH_IFRAMES: float = 0.3

## Dash cooldown. [TUNE]
const HERO_DASH_COOLDOWN: float = 4.0

## Maximum spells equipped at once (GDD §2, decision 4).
const HERO_MAX_SPELL_SLOTS: int = 4

## Spells offered to choose from on level-up; the player picks one (GDD §2).
const SPELLS_OFFERED_ON_LEVEL_UP: int = 3

# ------------------------------------------------------------------------------
# War horn — GDD §3.1
# ------------------------------------------------------------------------------

## How long the horn's pull window lasts.
const WAR_HORN_DURATION: float = 30.0

## Permanent enemy HP and damage increase applied per horn use, for the rest of
## the run. This is the horn's delayed cost. [TUNE]
const WAR_HORN_ESCALATION_PER_USE: float = 0.08

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

const CROSSROADS_PER_ACT: int = 2
const CROSSROADS_PER_RUN: int = 6

## Three option types exist; two are shown at each crossroad.
const CROSSROAD_OPTIONS_SHOWN: int = 2

# ==============================================================================
# META-PROGRESSION — GDD §7
# ==============================================================================

## The single sanctioned concession to persistence: clearing Act 3 grants one
## extra starting Town Hall relic slot, capped at +1. Nothing else carries over.
const ACT3_CLEAR_BONUS_RELIC_SLOTS: int = 1

# ==============================================================================
# STAGE 1 GREYBOX — NOT SPECIFIED BY THE GDD
# ==============================================================================
#
# The GDD fixes the distances and the dash, but gives no HP, damage, attack
# timing or spawn-rate numbers — those first appear in Stage 2's wave scaling.
# Everything below is a starting value picked to make Stage 1 playable and
# answer its kill question. Treat all of it as provisional.

# ------------------------------------------------------------------------------
# Arena
# ------------------------------------------------------------------------------

## The hero is clamped to the spawn ring, so the playable floor and the arena
## edge are the same circle and there is nowhere enemies do not come from.
const ARENA_RADIUS: float = ENEMY_SPAWN_RADIUS

## Camera lag. Lower is snappier, higher is floatier.
const CAMERA_SMOOTHING_SPEED: float = 8.0

## How far the camera leans toward the mouse, as a fraction of the hero-to-mouse
## offset. Gives a little lookahead without taking control away.
const CAMERA_MOUSE_LEAN: float = 0.18

# ------------------------------------------------------------------------------
# Hero — health and movement
# ------------------------------------------------------------------------------

const HERO_MAX_HP: float = 100.0

## Movement multiplier while an attack is in its windup/active frames. Not fully
## rooted: being able to drift keeps the chain from feeling like a commitment
## trap, but the cost has to be legible.
const HERO_ATTACK_MOVE_SCALE: float = 0.35

## Time from death to respawning at the arena centre.
const HERO_RESPAWN_DELAY: float = 1.5

## Grace period after respawning, so you are not instantly re-killed.
const HERO_RESPAWN_INVULN: float = 1.5

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
const ENEMY_MAX_HP: float = 30.0

const ENEMY_CONTACT_DAMAGE: float = 8.0

## Minimum time between two contact hits from the same enemy.
const ENEMY_CONTACT_INTERVAL: float = 0.85

## Radius of the enemy's body for contact and hurt checks.
const ENEMY_BODY_RADIUS: float = 22.0

## Enemies push each other apart at this speed so a crowd does not collapse into
## a single stacked point. Purely cosmetic separation, not physics.
const ENEMY_SEPARATION_SPEED: float = 45.0

## Seconds of stagger applied on being hit, during which the enemy does not walk.
const ENEMY_HITSTUN: float = 0.18

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
const SPAWN_MAX_ALIVE: int = 55

## Enemies never appear closer to the hero than this, even if the hero is
## standing on the spawn ring.
const SPAWN_MIN_DISTANCE_FROM_HERO: float = 420.0

## Enemies spawned at once when the timer fires, at the start and end of the ramp.
const SPAWN_BURST_START: int = 1
const SPAWN_BURST_END: int = 3
