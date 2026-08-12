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
const CAMERA_ZOOM: float = 0.62
const CAMERA_ZOOM_BATTLEFIELD: float = 0.62
const CAMERA_ZOOM_RAID: float = 0.95

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
const TOWER_SLOT_OFFSET: float = 96.0

## Enemies drift up to this far from the lane centre line, so a wave reads as a
## column rather than a single-file queue.
const LANE_WIDTH: float = 110.0

# ------------------------------------------------------------------------------
# Towers — GDD §4
# ------------------------------------------------------------------------------

const TOWER_MAX_LEVEL: int = 3

## Resource cost to build a base tower at level 1. [TUNE]
const TOWER_BUILD_COST: int = 60

## Combination towers cost more than either parent. [TUNE]
const TOWER_COMBO_BUILD_COST: int = 140

## Cost of upgrading to level N, indexed by the level being bought (1 -> 2 is
## index 0). [TUNE]
const TOWER_UPGRADE_COSTS: Array[int] = [80, 160]

## Damage and rate multipliers per level, indexed by level - 1. [TUNE]
const TOWER_LEVEL_DAMAGE: Array[float] = [1.0, 1.55, 2.3]
const TOWER_LEVEL_RATE: Array[float] = [1.0, 1.15, 1.35]

## Refund fraction when a tower is sold. [TUNE]
const TOWER_SELL_REFUND: float = 0.6

## Both non-combo slots in a lane sharing an element grants this bonus. [TUNE]
const SAME_ELEMENT_LANE_BONUS: float = 0.25

## Default projectile speed for towers that fire one. [TUNE]
const TOWER_PROJECTILE_SPEED: float = 620.0

# ------------------------------------------------------------------------------
# Waves — GDD §3
# ------------------------------------------------------------------------------

## Seconds between waves at the start of a segment. [TUNE]
const WAVE_INTERVAL: float = 30.0

## Seconds between spawns inside one wave. [TUNE]
const WAVE_SPAWN_SPACING: float = 0.75

## Enemies in wave 1, and how many are added per wave. [TUNE]
const WAVE_BASE_COUNT: int = 5
const WAVE_COUNT_GROWTH: float = 1.15

## Enemy HP and damage multiplier added per wave. [TUNE]
const WAVE_STAT_GROWTH: float = 0.065

## How many lanes a wave uses, at wave 1 and at the end of an act. [TUNE]
const WAVE_LANES_START: int = 1
const WAVE_LANES_MAX: int = 4

## Chance a given wave includes an elite, once elites are unlocked. [TUNE]
const WAVE_ELITE_CHANCE: float = 0.25

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

# ------------------------------------------------------------------------------
# Town — GDD §5
# ------------------------------------------------------------------------------

const TOWN_MAX_HP: float = 1400.0

## Damage an enemy deals to the town when it arrives, per point of its own
## contact damage. [TUNE]
const TOWN_DAMAGE_SCALE: float = 1.5

## Resources produced per distance unit travelled, before Granary tiers. [TUNE]
const RESOURCE_PER_DISTANCE: float = 0.55

## Extra resource rate per Granary tier. [TUNE]
const GRANARY_TIER_BONUS: float = 0.30

## Extra resource rate per captive assigned to the Scavenging Post. [TUNE]
const CAPTIVE_WORK_BONUS: float = 0.22

## Captives assignable to one building. [TUNE]
const CAPTIVES_PER_BUILDING: int = 2

## Resources granted at the start of a run. [TUNE]
const STARTING_RESOURCES: int = 300

# ------------------------------------------------------------------------------
# War horn, raid meter and the raid — GDD §6
# ------------------------------------------------------------------------------

## Raid meter gained per kill, and the multiplier while the horn is blowing.
const RAID_CHARGE_PER_KILL: float = 0.02
const RAID_CHARGE_HORN_MULTIPLIER: float = 3.0

## How long enemies stay weakened after the meter fills. [TUNE]
const WEAKENED_DURATION: float = 20.0

## Stat multiplier applied to weakened enemies. [TUNE]
const WEAKENED_STAT_SCALE: float = 0.55

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
const RAID_MAX_ENEMIES: int = 90
const RAID_ARENA_RADIUS: float = 700.0

## Reward fraction for leaving early, scaled by kills against this target. [TUNE]
const RAID_PARTIAL_REWARD_KILLS: int = 60

# ------------------------------------------------------------------------------
# Run flow — GDD §7, §8, §9
# ------------------------------------------------------------------------------

## Seconds the studio splash holds before the menu. [TUNE]
const SPLASH_DURATION: float = 1.8

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
const BOSS_RESOURCE_REWARD: int = 400

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

## Degrees of body sway at full speed. Runs at half stride rate, so the lean
## alternates once per two steps. [TUNE]
const ANIM_WALK_TILT: float = 3.6

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
const GROUND_TILE_WORLD_SIZE: float = 1400.0

## Sprite scale for units. The battlefield camera has to hold the whole lane
## ring, which leaves the hero about 79 screen pixels at source size - too small
## to read the art or the animation on it. [TUNE]
const HERO_SPRITE_SCALE: float = 1.75
const ENEMY_SPRITE_SCALE: float = 1.55
const ELITE_SPRITE_SCALE: float = 1.9
const BOSS_SPRITE_SCALE: float = 2.2
