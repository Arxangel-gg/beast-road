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
const ENEMY_WALK_SPEED: float = 38.5

## Tower firing range. Slight overlap between adjacent slots so the diagonals
## have no dead zones. [TUNE]
const TOWER_RANGE: float = 325

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

const CROSSROADS_PER_ACT: int = 3
const CROSSROADS_PER_RUN: int = 9

## Three option types exist; two are shown at each crossroad.
const CROSSROAD_OPTIONS_SHOWN: int = 3

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
const CAMERA_ZOOM_BATTLEFIELD: float = 0.77
const CAMERA_ZOOM_RAID: float = 0.95

## Mouse-wheel battlefield range. Reaching the minimum and continuing outward
## moves through Town and Beast rather than shrinking the tactical map into an
## unreadable postage stamp.
const CAMERA_ZOOM_BATTLEFIELD_MIN: float = 0.62
const CAMERA_ZOOM_BATTLEFIELD_MAX: float = 1.18
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
const BEAST_GAIT_FREQUENCY: float = 0.82
const BEAST_GAIT_HORIZONTAL: float = 5.0
const BEAST_GAIT_VERTICAL: float = 4.0
const BEAST_GAIT_ROTATION_DEGREES: float = 0.16
const BEAST_GAIT_SMOOTHING: float = 3.5
const BEAST_GAIT_HORN_SCALE: float = 0.12
const BEAST_STEP_PAUSE: float = 0.085
const BEAST_STEP_SINK: float = 3.6
const BEAST_STEP_SHAKE: float = 4.8
const BEAST_STEP_SHAKE_TIME: float = 0.18
const BEAST_STEP_MASS: float = 2.4

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

## The guaranteed Hearthmend repairs this fraction of the Town Hall before the
## enhanced service choice. [TUNE]
const HEARTHMEND_TOWN_REPAIR_FRACTION: float = 0.12

## Grace period after respawning, so you are not instantly re-killed.
const HERO_RESPAWN_INVULN: float = 1.5

## Minimum time the initial and between-road Preparation state remains open.
## The player must still confirm Ride On after this reaches zero. [TUNE]
const PREPARATION_MIN_SECONDS: float = 18.0

## A breather opens after every wave is fully defeated. Building and upgrading
## are open for this long, and the next formation waits.
##
## Unlike the long Preparation above, this one ends by itself: a player is not
## asked to confirm Ride On thirty times a run. Ride On still skips it, so the
## impatient lose nothing. [TUNE]
const PREPARATION_BETWEEN_WAVES: float = 10.0

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
const ENEMY_MAX_HP: float = 38

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
const SPAWN_MAX_ALIVE: int = 120

## Enemies never appear closer to the hero than this, even if the hero is
## standing on the spawn ring.
const SPAWN_MIN_DISTANCE_FROM_HERO: float = 420.0

## Enemies spawned at once when the timer fires, at the start and end of the ramp.
const SPAWN_BURST_START: int = 1
const SPAWN_BURST_END: int = 4

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

## Radius at which a lane's enemies spawn. [TUNE]
const LANE_SPAWN_RADIUS: float = 900.0

## Radius of the town core. Enemies that reach it deal damage. [TUNE]
const TOWN_RADIUS: float = 160.0

## Radii of the three build spots along each lane, town-outward.
## Index 0 = inner, 1 = middle (the combination slot), 2 = outer.
const TOWER_SLOT_RADII: Array[float] = [320.0, 520.0, 720.0]

## The combination slot is the middle one and only unlocks once both of its
## neighbours are built (GDD §4.1).
const COMBO_SLOT_INDEX: int = 1

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

## Enemies drift up to this far from the lane centre line, so a wave reads as a
## column rather than a single-file queue.
const LANE_WIDTH: float = 120

# ------------------------------------------------------------------------------
# Towers — GDD §4
# ------------------------------------------------------------------------------

## Five levels keep resources relevant through Acts 2 and 3. The Forge gates
## access above the early-game cap, so this is a progression track rather than
## five buttons available on the opening screen.
const TOWER_MAX_LEVEL: int = 5
const TOWER_BASE_LEVEL_CAP: int = 2

## Resource cost to build a base tower at level 1. [TUNE]
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
const TOWER_LEVEL_RANGE: Array[float] = [1.0, 1.02, 1.05, 1.08, 1.12]

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
const TOWER_PROJECTILE_SPEED: float = 620.0

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
const WAVE_OPENING_COUNT_SCALE: Array[float] = [0.84, 0.86, 0.88, 0.90, 0.92, 0.95, 0.98, 1.0]
const WAVE_OPENING_HP_SCALE: Array[float] = [0.70, 0.75, 0.80, 0.85, 0.90, 0.94, 0.97, 1.0]
const WAVE_OPENING_DAMAGE_SCALE: Array[float] = [0.62, 0.68, 0.74, 0.80, 0.86, 0.91, 0.96, 1.0]
const WAVE_OPENING_SPEED_SCALE: Array[float] = [0.86, 0.89, 0.92, 0.94, 0.96, 0.98, 0.99, 1.0]
const WAVE_OPENING_INTERVAL_BONUS: Array[float] = [6.0, 5.0, 4.0, 3.0, 2.0, 1.0]
const WAVE_OPENING_SUPPLIES: Array[int] = [0, 25, 35, 40, 30, 25]
const WAVE_OPENING_SINGLE_LANE_WAVES: int = 2

## Seconds between spawns inside one wave. [TUNE]
const WAVE_SPAWN_SPACING: float = 0.35

## Enemies in wave 1, and how many are added per wave. [TUNE]
const WAVE_BASE_COUNT: int = 3
const WAVE_COUNT_GROWTH: float = 0.33
const WAVE_ACT_COUNT_SCALE: Array[float] = [1.0, 1.18, 1.38]
const WAVE_NIGHT_COUNT_BONUS: float = 0.28

## Enemy HP and damage multiplier added per wave. [TUNE]
const WAVE_HP_GROWTH: float = 0.045
const WAVE_DAMAGE_GROWTH: float = 0.022
const WAVE_SPEED_GROWTH: float = 0.19
const WAVE_DARK_DAMAGE_WEIGHT: float = 0.72
const WAVE_DARK_SPEED_WEIGHT: float = 0.16
const WAVE_ACT_HP_SCALE: Array[float] = [1.0, 1.70, 2.60]
const WAVE_ACT_DAMAGE_SCALE: Array[float] = [1.0, 1.30, 1.65]

## The final stretch of an act becomes a visible pressure peak instead of only
## changing the label above the boss track.
const ACT_BOSS_RAMP_COUNT: float = 0.55
const ACT_BOSS_RAMP_STATS: float = 0.28

## Later regions remain dominated by their own breed while veterans from
## earlier terrain occasionally break up a predictable procession.
const WAVE_INVADER_CHANCE: Array[float] = [0.0, 0.12, 0.22]

## Elites arrive as an increasing number of squad leaders, not one lottery roll
## per wave for the entire 45-minute run.
const WAVE_ELITE_BASE_CHANCE: float = 0.19
const WAVE_ELITE_PROGRESS_BONUS: float = 1.60
const WAVE_ELITE_ACT_BONUS: float = 0.45
const WAVE_MAX_QUEUED: int = 420

## How many lanes a wave uses, at wave 1 and at the end of an act. [TUNE]
const WAVE_LANES_START: int = 1
const WAVE_LANES_MAX: int = 4

## Authored wave formations multiply the continuous curve; these clamps keep a
## malformed content file from producing an empty wave or an instant spawn wall.
const WAVE_ARCHETYPE_MIN_COUNT_SCALE: float = 0.50
const WAVE_ARCHETYPE_MIN_SPACING_SCALE: float = 0.42

## Live enemy cap across the whole battlefield. [TUNE]
const BATTLEFIELD_MAX_ENEMIES: int = 180

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
const ENEMY_PROJECTILE_SPEED: float = 310.0
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
const RESOURCE_PER_DISTANCE: float = 0.24

## Normal enemies still pop resource drops, but not every body is a full unit
## of currency. A fractional carry preserves the dopamine beat without making
## a large wave finance every remaining upgrade by itself.
const KILL_RESOURCE_SCALE: float = 0.45

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

## Accessibility contract mirrored by Palette's authored live tables.
const COLOURBLIND_MODES: Array[String] = ["off", "protanopia", "deuteranopia", "tritanopia"]
const ELITE_STONE_REWARD: int = 4
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

## Seconds between raid extraction windows, and how long one stays open. [TUNE]
const RAID_WINDOW_INTERVAL: float = 30.0
const RAID_WINDOW_DURATION: float = 3.0

## Refusing a window makes the camp harder by this much, compounding. [TUNE]
const RAID_REFUSAL_ESCALATION: float = 0.35

## Windows the player must refuse before the chieftain comes out. [TUNE]
const RAID_WINDOWS_BEFORE_CHIEFTAIN: int = 3

## Raid horde pacing. [TUNE]
const RAID_SPAWN_INTERVAL: float = 0.55
const RAID_MAX_ENEMIES: int = 72
const RAID_ARENA_RADIUS: float = 700.0

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

## How much world area one terrain tile covers, in pixels. The source art is
## 512px; drawing it 1:1 repeats it eight times across the screen and the result
## reads as wallpaper rather than as ground. Stretching each tile over a much
## larger area hides the repeat at the cost of some sharpness, which is the
## right trade for a floor nobody is meant to look at. [TUNE]
const GROUND_TILE_WORLD_SIZE: float = 900.0

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
const NIGHT_DIFFICULTY_BONUS: float = 0.45

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
const CLOUD_SPEED: Vector2 = Vector2(26.0, 9.0)
const CLOUD_SPEED_FAR: Vector2 = Vector2(11.0, 4.0)

## How dark a shadow gets at full daylight, 0..1. Clouds cast nothing at night,
## because there is no sun to block. [TUNE]
const CLOUD_DARKNESS: float = 0.42

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
const TORCH_ALONG_STOPS: Array[float] = [250.0, 430.0, 630.0]

## How far to the side of the lane centre they stand.
##
## Moved out with the build spots. When TOWER_SLOT_OFFSET went from 96 to 158 to
## get the click targets off the road, the towers arrived where the torches were
## standing - 215 was chosen to clear a tower at 96 and clears nothing at 158.
##
## A tower sprite is ~192 wide, so its edge reaches 158 + 96 = 254. 300 keeps the
## flames outside that with room to spare. [TUNE]
const TORCH_LANE_OFFSET: float = 300.0

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
const TORCH_LIGHT_RADIUS: float = 225.0
const TORCH_LIGHT_ENERGY: float = 1.55

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
const TORCH_DARK_DIFFICULTY: float = 0.5

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
const PATH_CORE_RADIUS: float = 58.0

## Width of the soft, noisy fringe *outside* the core, in pixels. Core plus
## fringe should land near the road's half-width (LANE_WIDTH * 1.6 / 2 = 88);
## more than that and the fringe is simply clipped. [TUNE]
const PATH_EDGE_FADE: float = 30.0

## How hard the fringe is broken up, 0..1. Only ever moves where the fade
## *starts*, never how opaque the interior is. [TUNE]
const PATH_EDGE_NOISE: float = 0.75

## Fraction of each end of a road given over to fading out, so the road
## dissolves into the distance instead of stopping at a line. [TUNE]
const PATH_END_FADE: float = 0.10

## Scale of the fringe noise, in pixels. [TUNE]
const PATH_NOISE_SCALE: float = 62.0

## Opacity of the road over the terrain. A road you cannot see is not a road.
## [TUNE]
const PATH_TINT_ALPHA: float = 0.95

## Multiplied into the road art so trodden ground sits darker than the country
## either side of it.
##
## This is doing more work than it looks like. The road texture and the ashfen
## terrain are close in both hue and value, so at full opacity the lane was still
## only a faintly different rectangle. Contrast, not opacity, is what makes a
## road read as a road — and a road the player cannot pick out at a glance is a
## tower-defense map with no lanes on it. [TUNE]
const PATH_DARKEN: float = 0.62

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
