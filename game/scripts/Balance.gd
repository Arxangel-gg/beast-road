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
# Persistent and capped by owner amendment (2026-08-20). The road still owns the
# current values through RunState; MetaState only checkpoints them so a crash or
# a new run does not discard earned progression.

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
## Raised with `LOOT_ICON_SIZE`, and it has to be. At 34.0 against a drop drawn
## 58 units wide, the hero could stand visually on top of a coin without picking
## it up - the collect radius was smaller than the sprite, so the art and the
## rule disagreed about where the thing was.
const LOOT_COLLECT_RANGE: float = 48.0
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
const LOOT_GLOW_SIZE: float = 132.0
const LOOT_GLOW_SPEED: float = 3.1

## Two small lights orbit each reward and a narrow beacon breathes above it.
## Both are world-space sprites rather than extra full-screen shader passes, so
## the readability survives Low quality and the cost stays bounded by the
## handful of live drops. [TUNE]
const LOOT_ORBIT_COUNT: int = 2
const LOOT_ORBIT_RADIUS: Vector2 = Vector2(30.0, 12.0)
const LOOT_ORBIT_SPEED: float = 2.8
const LOOT_ORBIT_SIZE: float = 13.0
const LOOT_BEACON_WIDTH: float = 30.0
const LOOT_BEACON_HEIGHT: float = 150.0
const LOOT_BEACON_ALPHA: float = 0.17

## How big a drop is drawn, in world units.
##
## This was 26.0, which was measured against nothing. The arithmetic that says
## why it is now 58.0:
##
##   hero sprite      128 px art x HERO_SPRITE_SCALE 1.75 = 224 world units tall
##   drop at 26.0     11.6% of the hero's height
##   at battlefield zoom CAMERA_ZOOM_BATTLEFIELD 0.52 ->  13.5 screen px at 1080p
##   zoomed fully out CAMERA_ZOOM_BATTLEFIELD_MIN 0.38 ->   9.9 screen px
##
## Ten pixels, on a field carrying corpses, foliage, torchlight and blast rings -
## and fewer than ten on a phone. A reward the player never notices is a reward
## that did not happen, which is the whole complaint.
##
## 58.0 is picked from the far end instead: about 30 screen px at the default
## battlefield zoom and still 22 when fully zoomed out, which is roughly a
## quarter of the hero's height. Large enough to be a thing lying on the road,
## small enough not to read as a crate.
const LOOT_ICON_SIZE: float = 58.0
const LOOT_BOB_SPEED: float = 5.0
const LOOT_BOB_HEIGHT: float = 3.0
const LOOT_Z_INDEX: int = -2

## How much gear the stash holds.
##
## Finite on purpose. An unlimited stash means a player never chooses what to
## keep, and "which of these do I break for shards" is the decision the
## blacksmith exists to pose. [TUNE]
##
## **Raised from 40 to 96 with the drop rates below** (owner direction,
## 2026-09-01: "the game needs way more loot... players should be mostly playing
## to farm better gear"). Capacity is inventory, not power - three pieces are
## worn and the rest are shard stock - so this does not touch the bound working
## rule 7 actually cares about, which is that gear grants capped attribute
## points. What it does is stop a farming run from spending its second half
## auto-breaking drops the player never got to look at.
const STASH_CAPACITY: int = 96

## Chance a raid chest also yields a piece of gear.
const GEAR_CHEST_CHANCE: float = 0.55

## Battlefield gear odds, by what died.
##
## **Retuned upward, 2026-09-01.** At 0.6% a breed kill the battlefield hunt was
## a rumour: a whole act could pass without a single piece, so the loop the owner
## wants - fight, find, compare, break, upgrade, go further - never got to start.
## The economics that argued for rarity were about a forty-slot stash, and the
## stash is 96 now.
##
## The ordering is the part that must not move: a breed is a surprise, an elite
## is a prospect worth chasing across the field, and a boss always pays.
## `balance_test` holds the ordering and the floor. [TUNE]
const GEAR_BATTLEFIELD_DROP_CHANCE: float = 0.024
const GEAR_BATTLEFIELD_ELITE_CHANCE: float = 0.45
const GEAR_BATTLEFIELD_BOSS_CHANCE: float = 1.0

## Extra pieces a boss leaves beyond the guaranteed one.
##
## A boss is the end of an act and the reason to have survived it; one piece was
## the same reward an elite could roll. Rolled separately, so the two can be
## different kinds and different rarities - a handful of loot is a moment, and
## one item is a line of text. [TUNE]
const GEAR_BOSS_EXTRA_PIECES: int = 2

## How much a campaign tier multiplies the gear odds, on top of its `loot_scale`
## for currency.
##
## This is what makes Nightmare and Hell worth farming rather than merely worth
## beating: the tiers already scale enemy health and damage, and without a
## matching reward the correct play is to farm the easiest tier forever. Bounded
## so a Hell run cannot fill the stash in one act. [TUNE]
const GEAR_TIER_ODDS_CEILING: float = 2.2

## Gear is a more important silhouette than a coin and earns a larger pickup.
## Scaled up alongside `LOOT_ICON_SIZE` and by slightly more, so the rarer drop
## stays the one that catches the eye first - see that constant for the
## screen-pixel arithmetic these come from.
const GEAR_DROP_ICON_SIZE: float = 76.0
const GEAR_DROP_GLOW_SIZE: float = 168.0
const GEAR_RARITY_COLOURS: Array[Color] = [
	Color("aeb4ad"), Color("82b68a"), Color("6fa8d8"),
	Color("b486d9"), Color("e8b85c")]

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

## The same three numbers, for a screen held in one hand.
##
## **Closer, not further.** These constants frame the field against a 1080p
## monitor a desk away; a phone is a quarter of the size and twice as close, and
## at 0.52 a hero on it is about nine millimetres tall. Every reason the desktop
## default is wide - read which lane is collapsing, see the fork the road takes -
## depends on being able to make out what is there at all, and on a phone that
## stops being true well before the field stops fitting.
##
## So the default sits nearer, and the range moves with it: the far end still
## pulls back far enough to read the ring of lanes, and the near end goes closer
## than a desktop ever needs for the moments a thumb is fighting something. [TUNE]
const CAMERA_ZOOM_BATTLEFIELD_TOUCH_MIN: float = 0.52
const CAMERA_ZOOM_BATTLEFIELD_TOUCH_MAX: float = 1.55


## How much closer every scene starts when a thumb is driving.
##
## A gain rather than a fixed number, because each scene authors its own framing
## - the battlefield opens at 0.62 and the raid arena at 0.95 - and replacing
## both with one value would throw that away. This moves them together and keeps
## the difference between them, which is the part that was designed. [TUNE]
## **Nothing in this file may reach for an autoload.** It is loaded by tools run
## with `--script`, which start no autoloads at all - so one call to `TouchInput`
## here stopped `Balance` compiling for every one of them, and the release gate
## failed with "Identifier not found: TouchInput" from a tool that has nothing to
## do with zoom. Constants live here; the choice between them belongs where the
## answer is already known.
const CAMERA_TOUCH_ZOOM_GAIN: float = 1.55






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

## Production baseline. Large values belong in local test harness setup, never in
## the shipped balance contract. [TUNE]
const HERO_MAX_HP: float = 100.0

## Movement multiplier while an attack is in its windup/active frames. Not fully
## rooted: being able to drift keeps the chain from feeling like a commitment
## trap, but the cost has to be legible.
const HERO_ATTACK_MOVE_SCALE: float = 0.38

## A held right stick on touch chains attacks, but leaves a deliberate travel
## beat during recovery so the player can kite rather than root in place. [TUNE]
const TOUCH_AUTOATTACK_MOVE_SCALE: float = 0.84

## A lethal hit downs the hero before they return with an act-long Wound. [TUNE]
const HERO_RESPAWN_DELAY: float = 8.0

const HERO_WOUND_HP_PENALTY: float = 0.10
const HERO_MAX_WOUNDS: int = 3
const HERO_WOUND_REVIVE_HP: float = 0.50
const HERO_DRAUGHT_REVIVE_HP: float = 0.40

# ------------------------------------------------------------------------------
# Oath of the Last Scar — run challenge
# ------------------------------------------------------------------------------

## Offered once, at an Act II crossroad, after the run has suffered a Wound.
## The reward widens this run's Wound ceiling only; it never enters MetaState.
const LAST_SCAR_OFFER_ACT: int = 2
const LAST_SCAR_MAX_WOUND_BONUS: int = 1
## The protected floor is measured continuously through the sworn road. [TUNE]
const LAST_SCAR_TOWN_MIN_RATIO: float = 0.60
## The marked pursuer is an ordinary regional elite with an oath-sized edge.
## [TUNE]
const LAST_SCAR_PURSUER_HP_SCALE: float = 1.55
const LAST_SCAR_PURSUER_DAMAGE_SCALE: float = 1.30

## Tending the hero during Preparation. The only healing that is not somebody
## else's decision - Hearthmend arrives three times a run, a heal spell is a
## build choice, and a wound revive costs a Wound.
##
## A third of the bar for 45 Food: enough that one purchase matters, priced so a
## full bar costs three and competes with the towers that would have stopped the
## damage in the first place. Healing should be the more expensive answer. [TUNE]
const HERO_TEND_FRACTION: float = 0.34
const HERO_TEND_COST: int = 45

## Tending under fire: field rations.
##
## **This is where the Food surplus goes.** Wildlife pays well and the only
## sinks were Preparation tending and a couple of town trades, so a player who
## hunted at all arrived at Act III with Food they could not spend and a wallet
## that had stopped meaning anything. Rations turn that surplus into the answer
## to a specific question - "can I survive the next thirty seconds" - which is
## the moment a resource is worth having.
##
## Deliberately worse than tending in every respect except availability. It costs
## more, heals less, and cannot be repeated quickly; Preparation is still the
## sensible time to be whole. What this buys is the *option* to be wrong about
## that and still live, which is the difference between a mistake and a loss.
## [TUNE]
const RATION_COST: int = 60
const RATION_FRACTION: float = 0.18
const RATION_COOLDOWN: float = 22.0

## What each ration in the same fight adds to the price of the next.
##
## Escalating rather than flat, so leaning on rations is a decision with a bill
## rather than a rotation. The counter resets when the wave does. [TUNE]
const RATION_ESCALATION: int = 25

# ------------------------------------------------------------------------------
# Mender's Spark — rare battlefield recovery
# ------------------------------------------------------------------------------

const MENDER_SPARK_ID: String = "mender_spark"
## Only an elite kill while somebody is below this health can roll a Spark.
## [TUNE]
const MENDER_SPARK_HEALTH_THRESHOLD: float = 0.45
const MENDER_SPARK_DROP_CHANCE: float = 0.34
## The third eligible elite guarantees the act's Spark. [TUNE]
const MENDER_SPARK_PITY_ELITES: int = 3
const MENDER_SPARK_MAX_PER_ACT: int = 1
## Small rescue up front, then meaningful recovery that still asks for safety.
## [TUNE]
const MENDER_SPARK_IMMEDIATE_FRACTION: float = 0.06
const MENDER_SPARK_REGEN_PER_SECOND: float = 0.015
const MENDER_SPARK_DURATION: float = 6.0
const MENDER_SPARK_BREAK_GRACE: float = 0.75

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
## and the pacing of the whole road came apart. The countdown fixed that.
##
## **Thirty seconds, raised from fifteen on 2026-09-01.** Reported from play:
## it "feels too short and doesn't give enough time to do everything necessary".
## That is a fair report and the reason is measurable rather than a matter of
## taste - fifteen seconds is less than one town interaction takes. Opening the
## Hero Mansion, reading a page, and training a node is twenty to thirty seconds
## on a phone by itself, before any tower is placed. The breather was sized
## against "place a tower", and the sheets it competes with have since grown.
##
## The ceiling is what stops this becoming sixty. A breather is a *breath*: it
## has to end while the player still feels the road waiting for them. Past about
## forty seconds the pressure that the countdown exists to create is gone and
## the pacing complaint the fifteen was solving comes back wearing the opposite
## coat. Thirty covers a full town interaction and still ends too soon to relax
## into, which is the property worth holding.
##
## **Lengthening this is close to free in world terms, and that is not luck.**
## `Journey.stop()` runs when a breather opens, so the beast does not walk: no
## distance accrues, which means no walking resources, no construction progress
## and no movement of an act boundary. What a longer breather actually costs is
## real-world minutes - see `SCORE_PAR_SECONDS`, which is adjusted with it - and
## nothing else. Spell cooldowns are unaffected in practice: the longest is 34
## seconds and the shortest wave cycle is over forty, so every cooldown already
## recovered inside a cycle without help from the breather.
##
## `balance_test._test_preparation_envelope` holds both ends of this. [TUNE]
const PREPARATION_BETWEEN_WAVES: float = 30.0

## Gold for riding on the instant a between-wave breather opens. [TUNE]
const PREPARATION_EARLY_GOLD_MAX: int = 10

## The award stops falling here, and holds. [TUNE]
const PREPARATION_EARLY_GOLD_FLOOR: int = 5

## When the award stops falling, and when it disappears, as **fractions of the
## breather** rather than as absolute seconds.
##
## Shares, so the shape of the decision survives a change to the breather's
## length. At the old fifteen seconds these resolve to exactly the five and ten
## that were written there literally, so this is a refactor at the old value and
## a scaling at the new one.
##
## They also fix a latent trap. The slope used to be hardcoded at one gold per
## second while the decay length was a separate constant that happened to equal
## `MAX - FLOOR`; the two branches agreed by coincidence, and anyone changing the
## decay window would have found the slope ignoring them entirely. The slope is
## derived from the window now, so the two cannot disagree. [TUNE]
const PREPARATION_EARLY_GOLD_DECAY_SHARE: float = 1.0 / 3.0
const PREPARATION_EARLY_GOLD_DEADLINE_SHARE: float = 2.0 / 3.0


## The early-departure award for riding on with `seconds_left` on the clock.
##
## Falls to a floor, holds there, then vanishes at a deadline - three steps
## rather than one ramp, and deliberately. A linear fade to zero gives a number
## that is never quite worth hurrying for and never quite worth waiting out. Two
## cliffs give two real decisions: go now for the most, or go before the bonus
## disappears at all.
##
## **The amounts did not rise with the breather**, which is a decision rather
## than an omission. Ten Gold across roughly forty wave breathers is already a
## fifth of a run's Gold income if it is always taken; paying more for giving up
## thirty seconds instead of fifteen would make the tempo reward a primary income
## source. A longer breather also means the bonus is *taken* less often, because
## the time is now worth using - so if anything this drifts income down, well
## inside noise.
static func preparation_early_gold(seconds_left: float) -> int:
	var elapsed: float = maxf(PREPARATION_BETWEEN_WAVES - seconds_left, 0.0)
	var decay: float = preparation_early_gold_decay_seconds()
	if elapsed >= preparation_early_gold_deadline_seconds():
		return 0
	if elapsed >= decay:
		return PREPARATION_EARLY_GOLD_FLOOR
	var fall: float = float(PREPARATION_EARLY_GOLD_MAX - PREPARATION_EARLY_GOLD_FLOOR)
	return maxi(
		PREPARATION_EARLY_GOLD_MAX - int(floor(elapsed * fall / maxf(decay, 0.01))),
		PREPARATION_EARLY_GOLD_FLOOR)


static func preparation_early_gold_decay_seconds() -> float:
	return PREPARATION_BETWEEN_WAVES * PREPARATION_EARLY_GOLD_DECAY_SHARE


static func preparation_early_gold_deadline_seconds() -> float:
	return PREPARATION_BETWEEN_WAVES * PREPARATION_EARLY_GOLD_DEADLINE_SHARE


## Seconds left before the early-departure award disappears entirely.
static func preparation_bonus_seconds_left(seconds_left: float) -> float:
	return maxf(seconds_left
		- (PREPARATION_BETWEEN_WAVES - preparation_early_gold_deadline_seconds()), 0.0)

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

## A lunge stops with room for both silhouettes instead of carrying the hero
## through a target. A connecting hit then gives a short counter-step without
## cancelling the chain or its input buffer. [TUNE]
const HERO_ATTACK_BODY_CLEARANCE: float = 34.0
const HERO_ATTACK_LUNGE_CORRIDOR: float = 30.0
const HERO_ATTACK_RECOIL: Array[float] = [16.0, 19.0, 27.0]
const HERO_ATTACK_RECOIL_TIME: float = 0.10

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
## Crowd separation: how bodies keep out of each other.
##
## The cell is the broadphase bucket, comfortably wider than any two bodies that
## could touch, so a body only ever consults its own cell and the eight around
## it. Strength is how much of a frame's overlap is resolved at once - all of it
## at once makes a crowd twitch, a fraction of it reads as bodies settling. The
## cap is the safety rail: whatever the maths says, nothing is displaced faster
## than a walk, so separation can never fling anything. [TUNE]
## How much overlap is acceptable once a crowd has settled.
##
## Not zero: bodies are pushed apart a fraction of the overlap per frame, so
## they approach contact rather than snapping to it, and demanding zero would be
## demanding a stiffness that reads as jitter. A couple of units is touching
## shoulders. [TUNE]
const CROWD_RESIDUAL: float = 3.0

const CROWD_CELL: float = 96.0
const CROWD_STRENGTH: float = 7.0
const CROWD_MAX_SHOVE: float = 150.0


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

# ------------------------------------------------------------------------------
# Readability shaders — actors, loot and impacts
# ------------------------------------------------------------------------------

## Four neighbouring alpha samples produce one crisp pixel-art silhouette.
## Medium and above use it; Low avoids the extra texture reads. [TUNE]
const ACTOR_OUTLINE_STRENGTH: float = 0.82
const ACTOR_OUTLINE_COLOUR: Color = Color(0.035, 0.045, 0.05, 0.94)
## Directional rim on the side opposite the incoming blow. [TUNE]
const IMPACT_RIM_STRENGTH: float = 1.0
const IMPACT_RIM_COLOUR: Color = Color(1.0, 0.82, 0.62, 1.0)
const LOOT_SHIMMER_STRENGTH: float = 0.34
const LOOT_PICKUP_DISSOLVE_TIME: float = 0.18

# ------------------------------------------------------------------------------
# Treeline and wilderness frame
# ------------------------------------------------------------------------------

## Treeline silhouette variation. Region ranges are intentionally larger than
## play-space foliage: these trees begin beyond build reach and frame the map.
## Non-uniform scale, tiny lean and colour spread make one authored tree read as
## a stand rather than repeated wallpaper. [TUNE]
const TREELINE_JUNGLE_SCALE: Vector2 = Vector2(1.35, 2.15)
const TREELINE_DESERT_SCALE: Vector2 = Vector2(1.08, 1.70)
const TREELINE_SNOW_SCALE: Vector2 = Vector2(1.22, 1.94)
const TREELINE_WIDTH_VARIATION: Vector2 = Vector2(0.82, 1.18)
const TREELINE_HEIGHT_VARIATION: Vector2 = Vector2(0.94, 1.12)
const TREELINE_LEAN_DEGREES: float = 2.2
const TREELINE_SHADE: Vector2 = Vector2(0.80, 1.08)

## A few old trees are much larger than the surrounding stand. The ordinary
## scale still carries most of the silhouette; this sparse multiplier supplies
## landmarks without turning the whole perimeter into one solid wall. [TUNE]
const TREELINE_GIANT_CHANCE: float = 0.14
const TREELINE_GIANT_SCALE: Vector2 = Vector2(1.35, 1.72)
## Keeps independently scattered trunks from occupying effectively one pixel.
## Canopies may overlap naturally; the ground contacts may not. [TUNE]
const TREELINE_TRUNK_SPACING: float = 92.0
const TREELINE_REACH: float = 2800.0
const TREELINE_ATTEMPTS: int = 720
const TREELINE_LANE_CLEARANCE: float = 320.0

# ------------------------------------------------------------------------------
# Unit readability feedback
# ------------------------------------------------------------------------------

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

## The shove a tower gives itself when it looses a shot.
##
## Procedural rather than an authored attack pose, and that is an order of work
## rather than a substitute for one: twenty-six towers would be some seventy
## frames to draw, while a transform kick reads at every zoom, arrives free for
## any tower added later, and still composes with authored frames when they
## come - the idle loop already proves that, since it replaces the texture while
## the same code keeps driving scale and rotation.
##
## Short, because it has to finish before the next shot on a fast tower: an
## Arc Coil at tier three fires inside a quarter second. [TUNE]
## How far weather pushes the foliage past its resting sway.
##
## The gain is on top of the authored calm, not a replacement for it: at wind 0
## the grass moves exactly as it always did, so a clear day is unchanged and only
## the weathers that should be felt are. The bias is a *steady lean* rather than
## more waving, because that is the difference between a breeze and a gale -
## a gale holds the grass over. [TUNE]
## Ambient animals: how many, how often, and how they move.
##
## The cap is a ceiling on cost rather than a target population - arrivals are a
## coin flip against the chance below, so the field is genuinely sometimes empty
## and sometimes busy. A fixed count reads as decoration however good the sprites
## are, because the eye works out inside a minute that there are always six.
## [TUNE]
## The city's own motion: how it rides the beast, and how it takes a hit.
##
## The city does *not* breathe the way a tower does, and that is a judgement
## about the subject rather than a tuning value: a 512px city gently scaling
## reads as wobbling masonry. What a city on a walking beast should do is rock
## with the gait, so the idle is the beast's step and nothing else.
##
## The jolt is separate and much sharper. Being struck already flashed the
## sprite and shook the camera - shaking the camera says "you were hit" while
## shaking the *city* says "the city was hit", and those are different
## sentences. [TUNE]
const TOWN_GAIT_DEGREES: float = 0.55
const TOWN_GAIT_LIFT: float = 5.0
const TOWN_JOLT_SECONDS: float = 0.28
const TOWN_JOLT_SCALE: float = 0.022
const TOWN_JOLT_SHOVE: float = 7.0
const TOWN_JOLT_VARIANTS: int = 3
const TOWN_JOLT_TWIST_DEGREES: float = 1.7
const CITY_FEET_ANCHOR: float = 0.44
const CITY_IDLE_FRAME_RATE: float = 2.4

## How close an enemy has to be to a barricade to be held by it, and for how
## long the hold is refreshed. [TUNE]
## How far ahead an enemy notices a barricade, and how directly in front of it
## the wall must be to count as in the way.
##
## The dot is generous on purpose: a road bends, and a wall a little off the
## current heading is still one the enemy is about to reach. Too strict and they
## walk past anything on a curve - which is where walls are most worth building.
## [TUNE]
## How high the barricade's health bar rides, and how it looks as it is worn
## down: greyed and settling rather than swapped for a broken sprite. Three
## authored damage states per orientation per barricade is twelve images for
## something the player mostly reads off the bar. [TUNE]
## How far a corner piece is turned. Mirrored for the other diagonal.
##
## Not 45: the art is drawn in elevation like every other structure here, and a
## full 45 degrees reads as a wall that has fallen over. Enough lean to say
## "this follows the bend" without pretending the sprite is a plan view. [TUNE]
const BARRICADE_DIAGONAL_DEGREES: float = 26.0

const BARRICADE_BAR_LIFT: float = 62.0
const BARRICADE_BROKEN_TINT: Color = Color(0.55, 0.5, 0.46, 1.0)
const BARRICADE_SAG: float = 0.22

const BARRICADE_NOTICE_RANGE: float = 520.0
const BARRICADE_AHEAD_DOT: float = 0.45

const BARRICADE_GRIP_RADIUS: float = 90.0
const BARRICADE_GRIP_SECONDS: float = 0.6

# ------------------------------------------------------------------------------
# Wildlife behavior and spacing
# ------------------------------------------------------------------------------

## The floor and the ceiling on how many animals are about.
##
## Below the floor something always arrives; above it arrival is a coin flip. The
## floor is what stops a field being empty for minutes at a time, and the flip
## above it is what stops the population reading as a quota. [TUNE]
const WILDLIFE_MIN: int = 6
const WILDLIFE_MAX: int = 22

## How far a hero's swing reaches an animal, how much of the field an animal may
## wander off before it stops existing, and how high a flier is drawn above the
## ground it sorts against. [TUNE]
## How much further than the swing's own reach a hunt connects.
##
## A little generous: an ambient animal is not a combat target and should not
## demand combat precision, but the arc test in front of the hero keeps it from
## being a radius kill.
const WILDLIFE_KILL_REACH_BONUS: float = 40.0
const WILDLIFE_FORGET_DISTANCE: float = 2600.0
const WILDLIFE_FLIER_LIFT: float = 54.0
const WILDLIFE_ARRIVAL_CHANCE: float = 0.55
## How far out from the town animals are placed.
##
## Widened from 1150: the ground being scattered across was barely larger than
## the road network, so animals only ever appeared among the lanes. Reported as
## wanting more life *beyond* the paths - the placement rule already keeps them
## off the roads, it simply was not being offered much ground that is not one.
## [TUNE]
const WILDLIFE_FIELD_SPAN: float = 2000.0
const WILDLIFE_ENTRY_DISTANCE: float = 1500.0
const WILDLIFE_PAUSE_MIN: float = 1.6
const WILDLIFE_PAUSE_MAX: float = 7.0
const WILDLIFE_IDLE_FRAME_RATE: float = 2.6
const WILDLIFE_MOVE_FRAME_RATE: float = 7.5

## Formation steering. The first number is a hard spawn clearance; the latter
## two are a soft in-motion repulsion, capped below ordinary walking speed so a
## crowded pack separates instead of exploding apart. [TUNE]
const WILDLIFE_GROUP_SPAWN_SPACING: float = 96.0
const WILDLIFE_SEPARATION_RADIUS: float = 104.0
const WILDLIFE_SEPARATION_STRENGTH: float = 74.0
const WILDLIFE_COHESION_STRENGTH: float = 0.34

## Small deterministic wander curves keep travel from being ruler-straight.
## They steer; they never change the destination or combat outcome. [TUNE]
const WILDLIFE_WANDER_CURVE: float = 0.22
const WILDLIFE_SOAR_CURVE: float = 0.46
const WILDLIFE_SKITTER_BURST: float = 1.22

## Sprite origins are ground contacts. Art is lifted above that contact so the
## Y-sort key stays at the feet regardless of frame dimensions. [TUNE]
const WILDLIFE_FEET_ANCHOR: float = 0.43
## A short visual commitment makes authored attack frames read without moving
## the actual body into or through its target. [TUNE]
const WILDLIFE_ATTACK_LUNGE: float = 11.0

# ------------------------------------------------------------------------------
# Local ambient life — cosmetic and intentionally not replicated
# ------------------------------------------------------------------------------

## Butterflies animate by day; fireflies replace them at night. They are local,
## cosmetic and quality-scaled, so these values tune atmosphere without changing
## a seeded run or adding replication traffic. [TUNE]
const AMBIENT_BUTTERFLY_COUNT: int = 10
const AMBIENT_BUTTERFLY_SPEED: Vector2 = Vector2(20.0, 52.0)
const AMBIENT_BUTTERFLY_TURN: float = 3.2
const AMBIENT_BUTTERFLY_ROAM: float = 280.0
const AMBIENT_BUTTERFLY_FRAME_RATE: float = 8.0
const AMBIENT_BUTTERFLY_LIFT: float = 28.0
const AMBIENT_BUTTERFLY_LAND_CHANCE: float = 0.42
const AMBIENT_BUTTERFLY_REST: Vector2 = Vector2(1.4, 4.2)
const AMBIENT_BUTTERFLY_SWERVE_TIME: Vector2 = Vector2(0.24, 0.82)
const AMBIENT_BUTTERFLY_SWERVE: float = 0.88
const AMBIENT_FIREFLY_AMOUNT: int = 84
const AMBIENT_FIREFLY_FIELD_EXTENT: Vector2 = Vector2(1700.0, 1120.0)
const AMBIENT_FIREFLY_CLUSTER_COUNT: int = 10
const AMBIENT_FIREFLY_CLUSTER_EXTENT: Vector2 = Vector2(145.0, 96.0)
const AMBIENT_FIREFLY_TREE_BIAS: float = 0.8
const AMBIENT_FIREFLY_LIFETIME: float = 4.8
const AMBIENT_FIREFLY_SPEED: float = 9.0
const AMBIENT_FIREFLY_SIZE: float = 0.82

## The hop given to walkers that have only one authored frame. Rise, fall, and a
## squash at the bottom - which is the right gait for a rabbit anyway. [TUNE]
## Elite wildlife: the same animal grown and scarred.
##
## One number drives the size, and the rest scale from it, so an elite cannot end
## up bigger without being tougher or worth more. The tint is what makes it
## readable before it arrives - a name in a tooltip is no use to somebody
## deciding whether to walk past it. [TUNE]
## The bar over a wounded animal. Hidden until it is hurt, except on an elite,
## which shows it from the moment it arrives - that is half of what makes an
## elite readable before it reaches you. [TUNE]
const WILDLIFE_BAR_WIDTH: float = 34.0
const WILDLIFE_BAR_HEIGHT: float = 4.0
const WILDLIFE_BAR_LIFT: float = 42.0

## How long a predator presses a hunt, and how long it stays off you after.
##
## Without these a hunt never ended: aggro is measured from where the animal has
## got to, so anything that closed the gap stayed inside its own radius forever.
## The rest window is deliberately longer than the hunt - the player has to get
## an actual gap out of surviving one, or breaking off is a pause rather than an
## escape. [TUNE]
## How long an enemy remembers being bitten by something out of the wilderness.
##
## Short on purpose. Retaliation is a reaction, not a second allegiance: a column
## that abandoned the road to hunt wolves would be a different game, and the
## `_in_reach` condition already stops it walking anywhere. This is only how long
## the animal stays worth swinging at when it is standing on top of you. [TUNE]
## How far to the side of a brazier an enemy may be and still smother it.
##
## The longitudinal range answers "is it level with the torch"; this answers "is
## it on the same piece of road". Without it a bent lane snuffs torches from its
## other leg, because both project onto the same point along the lane vector.
## Comfortably wider than the road so a walker on the far verge still counts.
## [TUNE]
## How often a painted plant that is not the region's own is a flower.
##
## Applied after `FOLIAGE_REGION_PLANT_SHARE` has already had its say, so this is
## a share of the *remainder* rather than of everything. Flowers are the only
## foliage carrying a colour that is not green, brown or white, and at a uniform
## one-in-eleven they effectively were not there. [TUNE]
const FOLIAGE_FLOWER_SHARE: float = 0.55

## How many *extra* flowers stand beside one that was placed, and how far they
## scatter.
##
## A single flower in a field reads as a mistake; a patch reads as a place where
## something grows. Only flowers cluster - four boulders in a heap would read as
## a different mistake. [TUNE]
const FOLIAGE_FLOWER_CLUSTER_MIN: int = 2
const FOLIAGE_FLOWER_CLUSTER_MAX: int = 5
const FOLIAGE_FLOWER_CLUSTER_SPREAD: float = 34.0

const TORCH_SNUFF_LATERAL: float = 300.0

const ENEMY_PROVOKED_SECONDS: float = 4.0

## How much of its bite a predator lands, per act.
##
## The wilderness is a third party that happens to you, not a second enemy
## faction - and in Act I it was reading as the boss fight. A wolf costs 8 a bite
## against a hero with 100, and they arrive in threes. Softer early, whole later:
## the ramp is by act rather than by wave so a player who notices it can say what
## it is, and so nothing about the late game moves. [TUNE]
## Below this share of health, healing lights up in the action bar.
##
## A third: high enough that the option is offered while there is still time to
## take it, low enough that it is not lit for most of a normal fight - a
## highlight that is always on is decoration. [TUNE]
const HUD_HEAL_URGENT_FRACTION: float = 0.34
const HUD_HEAL_PULSE_RATE: float = 3.1
const HUD_HEAL_URGENT_TINT: Color = Color(1.0, 0.72, 0.55)


const WILDLIFE_BITE_BY_ACT: Array[float] = [0.6, 0.85, 1.0]

## How much room a settled animal leaves around the town during Preparation.
##
## Only animals already inside this walk anywhere - one halfway across the field
## has no business moving on account of a phase, and re-goaling every predator
## every Preparation would read as the wilderness politely clearing the room.
## [TUNE]
## How far from the city a wild animal may first appear.
##
## **Not the foliage margin.** Wildlife inherited the rule that keeps plants off
## the town - 340 units, which is a reed's distance and nothing like an animal's.
## Deer and wolves arrived close enough to the base to read as attacking it, and
## a predator that noticed the hero standing there was on them immediately.
##
## Out past the build grid's inner half instead, which puts arrivals among the
## treeline rather than on the doorstep - the forest is where animals come from,
## and it is off the edge of what the player is watching. They may still walk in
## afterwards; that is a journey the player can see, not a spawn on top of them.
## [TUNE]
## How much the quiver holds, counted in ammunition bulk.
##
## One number rather than a capacity per family, because the player carries one
## quiver and the interesting decision is *what* fills it - forty plain arrows,
## or twelve blast bolts and room for nothing else. [TUNE]
## How close an arrow has to pass to count as a hit.
##
## Generous, and deliberately so. A bow aimed with a thumb on a phone cannot be
## pixel-accurate, and a shot that visibly passes through a body without
## registering reads as the game cheating rather than as the player missing.
## [TUNE]
## How far in front of the hero a shot appears.
##
## Clear of their own body, so an arrow never looks like it spawned inside the
## person firing it. [TUNE]
## Arrows handed over with a first bow.
##
## Enough to form an opinion with and not enough to live on. A bow and no
## ammunition is a bow the player cannot evaluate; a bow and forty arrows is a
## bow that never has to be fed. [TUNE]
## How often something worth killing leaves a plan behind.
##
## Elites are a prospect and bosses are close to a promise. Ordinary breeds drop
## none at all: a recipe that falls out of a Bogkin is not a discovery, it is a
## grind with a certificate. [TUNE]
const BLUEPRINT_ELITE_CHANCE: float = 0.18
const BLUEPRINT_BOSS_CHANCE: float = 0.85

const RANGED_STARTING_SHOTS: int = 12

const HERO_ARROW_MUZZLE: float = 38.0

## The line a drawn bow puts on the ground in front of the hero. [TUNE]
##
## Not decoration. A thumb stick states a *direction* and nothing else, so
## without this a phone player is aiming at a number they cannot see - and on a
## desktop it confirms that the shot really does leave along the cursor, which
## is the thing that was wrong. Short on purpose: a full-range laser reads as a
## targeting weapon rather than as a bow being drawn.
const HERO_AIM_GUIDE_LENGTH: float = 230.0
const HERO_AIM_GUIDE_START: float = 46.0
const HERO_AIM_GUIDE_WIDTH: float = 5.0
const HERO_AIM_GUIDE_ALPHA: float = 0.34
## Brighter while the draw is still running, so the line also says "not ready".
const HERO_AIM_GUIDE_DRAWING_ALPHA: float = 0.62

const HERO_ARROW_HIT_RADIUS: float = 34.0

const AMMO_CAPACITY: int = 48

## Promoted enemies (owner decision, 2026-08-31).
##
## **A champion is a pack and an elite is an encounter.** The champion's own
## numbers are modest because there are four of them wearing the same affix; the
## elite's are large because there is one, and it is meant to be the thing the
## wave is about. Size is the tell before the outline is: a body half again as
## wide reads as different from across the field. [TUNE]
## How much of the affix colour is laid over a promoted sprite.
##
## Restrained: the breed has to stay recognisable. A Bogkin that is entirely
## purple is a new enemy the player has to learn, when the useful information is
## "a Bogkin, and something else as well". [TUNE]
const RANK_TINT_STRENGTH: float = 0.38

const CHAMPION_HEALTH_SCALE: float = 2.2
const CHAMPION_DAMAGE_SCALE: float = 1.25
const CHAMPION_SIZE_SCALE: float = 1.18
const CHAMPION_PACK_MIN: int = 3
const CHAMPION_PACK_MAX: int = 4

const ELITE_HEALTH_SCALE: float = 6.5
const ELITE_DAMAGE_SCALE: float = 1.6
const ELITE_SIZE_SCALE: float = 1.42
const ELITE_AFFIX_MIN: int = 2
const ELITE_AFFIX_MAX: int = 3

## How often a wave produces one, per spawn.
##
## Rare on purpose. A champion pack every wave is not a champion pack, it is the
## wave - and the whole value of a promotion is that the player notices it and
## changes what they were doing. [TUNE]
const CHAMPION_SPAWN_CHANCE: float = 0.085
const ELITE_SPAWN_CHANCE: float = 0.03

## What a promoted enemy pays out, against an ordinary one.
const CHAMPION_REWARD_SCALE: float = 2.5
const ELITE_REWARD_SCALE: float = 6.0

const WILDLIFE_SPAWN_CLEARANCE: float = 1000.0

const WILDLIFE_TOWN_SPACE: float = 520.0


## A predator's damage multiplier in a given act.
static func wildlife_bite(act: int) -> float:
	if WILDLIFE_BITE_BY_ACT.is_empty():
		return 1.0
	return WILDLIFE_BITE_BY_ACT[clampi(act - 1, 0, WILDLIFE_BITE_BY_ACT.size() - 1)]


const WILDLIFE_HUNT_MIN: float = 7.0
const WILDLIFE_HUNT_MAX: float = 12.0
const WILDLIFE_HUNT_REST_MIN: float = 13.0
const WILDLIFE_HUNT_REST_MAX: float = 22.0

## The most hostile animals that may share the field at once.
##
## Kinds are weighted for *variety*, and by weight the six hostile species are
## 42% of arrivals - so a cap is what keeps a run of unlucky rolls from turning
## an ambient system into a second enemy faction. Bounded worst case, one number,
## and the roster stays as varied as it was authored to be. [TUNE]
const WILDLIFE_HOSTILE_MAX: int = 7

const WILDLIFE_ELITE_SCALE: float = 1.45
const WILDLIFE_ELITE_HEALTH: float = 2.6
const WILDLIFE_ELITE_REWARD: float = 2.4
const WILDLIFE_ELITE_TINT: Color = Color(1.0, 0.72, 0.62, 1.0)

## How long a killed animal takes to fall over, and how far it rolls doing it.
const WILDLIFE_DEATH_SECONDS: float = 0.85
const WILDLIFE_DEATH_ROLL: float = 78.0

## How far a single-frame walker rises through its stride. Much smaller than
## a hop: this is a gait, not a bound. [TUNE]
const WILDLIFE_STRIDE_LIFT: float = 3.0

const WILDLIFE_HOP_RATE: float = 9.0
const WILDLIFE_HOP_HEIGHT: float = 9.0
const WILDLIFE_HOP_SQUASH: float = 0.16
const WILDLIFE_FLIGHT_FRAME_RATE: float = 9.5
const WILDLIFE_ATTACK_FRAME_RATE: float = 8.0
const WILDLIFE_BOB_RATE: float = 11.0
const WILDLIFE_BOB_SCALE: float = 0.09

const FOLIAGE_WIND_SWAY_GAIN: float = 1.35
const FOLIAGE_WIND_SPEED_GAIN: float = 0.85
const FOLIAGE_WIND_BIAS_DEGREES: float = 7.0

const TOWER_FIRE_KICK_SECONDS: float = 0.17
const TOWER_FIRE_KICK_SCALE: float = 0.08
const TOWER_FIRE_KICK_PUSH: float = 5.0

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
## Layered hostile ribbon and head. The dark shell identifies enemy fire before
## the hot filament is bright enough to compete with tower projectiles. [TUNE]
const ENEMY_PROJECTILE_WIDTH: float = 11.0
const ENEMY_PROJECTILE_FILAMENT_WIDTH: float = 3.0
const ENEMY_PROJECTILE_HEAD_RADIUS: float = 8.0
const ENEMY_PROJECTILE_RUNE_RADIUS: float = 15.0
const ENEMY_PROJECTILE_RUNE_WIDTH: float = 2.0
const ENEMY_PROJECTILE_PULSE_SPEED: float = 9.0
const ENEMY_PROJECTILE_HIT_RADIUS: float = 18.0
const ENEMY_PROJECTILE_BLAST_RADIUS: float = 54.0
const ENEMY_PROJECTILE_MAX_LIFE: float = 2.0
const ENEMY_PROJECTILE_TRAIL_POINTS: int = 16
const ENEMY_PROJECTILE_GLOW_SCALE: float = 0.30
const ENEMY_PROJECTILE_MOTE_INTERVAL: float = 0.11
const ENEMY_PROJECTILE_MOTE_SPEED: float = 58.0
const ENEMY_PROJECTILE_IMPACT_SPARKS: int = 15
const ENEMY_PROJECTILE_LIGHT_RADIUS: float = 105.0
const ENEMY_PROJECTILE_LIGHT_ENERGY: float = 0.75
const ENEMY_PROJECTILE_COLOUR: Color = Color(0.95, 0.25, 0.12)
const ENEMY_PROJECTILE_CORE_COLOUR: Color = Color(1.0, 0.82, 0.46)
const ENEMY_PROJECTILE_SHELL_COLOUR: Color = Color(0.22, 0.025, 0.035)
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

## Four-wallet v4 opening cache, amended 2026-08-24 (owner).
##
## **Gold starts at zero.** The run begins with no build capital at all, and the
## player buys their first tower with money taken off the enemies they killed.
## The point is that the hero has to fight: with four towers already up, an act
## could be subcontracted to them and watched.
##
## This reverses GDD §448's opening protection envelope, which read "Starting
## Gold and Stone can build one level-1 base tower on each road plus one
## meaningful upgrade or town choice". The re-cut is recorded there and in
## CLAUDE.md, both dated.
##
## **Wood, Food and Stone are deliberately not zeroed**, and that is an
## interpretation worth stating rather than burying. No tower can be built
## without Gold - every entry in `build_cost_table` carries a Gold price - so
## zero Gold already means zero towers, which is the whole of the owner's
## intent. What the secondary wallets decide is *which element* the first
## affordable tower may be, since Fire is the only pure-Gold line. Emptying them
## too would not make the opening more demanding; it would silently force every
## player onto Fire for the first act. The run still starts unable to build
## anything.
##
## Wood and Food also pay for town repair and hero tending, which have nothing
## to do with tower capital and would be collateral damage.
const STARTING_WOOD: int = 180
## **Below the price of one tending**, deliberately.
##
## Food was the currency nobody had to think about: it started above its only
## urgent price, accrued while the beast walked, and then twelve species of
## huntable wildlife arrived - a bear alone paid for a whole tend and change.
## Players reported stockpiling it long before there was anything to spend it on,
## which is a currency that has stopped being a decision.
##
## Starting below one tend means the first wounded hero is a choice: hunt for it,
## walk for it, or fight on hurt. [TUNE]
const STARTING_FOOD: int = 38
## The Warden earns the first tower by fighting; see GDD v4 §18. [TUNE]
const STARTING_GOLD: int = 0
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
## What a recipe costs, against a tower's four. Cheaper because a blueprint is a
## smaller thing than a tower line - and because this shelf exists to keep Tools
## meaningful in the late account, not to become a second grind.
const TOOLS_PER_BLUEPRINT: int = 3

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
## Fallback tint when a region has no terrain painting, so a camp is still
## readable rather than invisible.
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

# ------------------------------------------------------------------------------
# Beast and menu environment lighting
# ------------------------------------------------------------------------------

## The beast belongs to the painted light around it instead of retaining the
## neutral source exposure over a dusk, snow or desert backdrop. [TUNE]
const BEAST_ENVIRONMENT_TINT: float = 0.58
const BEAST_TOWN_LIGHT_COLOUR: Color = Color(1.0, 0.58, 0.25)
const BEAST_TOWN_LIGHT_RADIUS: float = 520.0
const BEAST_TOWN_LIGHT_ENERGY: float = 1.05
const BEAST_TOWN_LIGHT_FLICKER: float = 0.08
const BEAST_TOWN_LIGHT_LIFT: float = 182.0

## Menu art uses its backdrop's sampled hue/exposure, with a readability floor
## so the hero object never disappears into the gate. [TUNE]
const MENU_BEAST_TINT_STRENGTH: float = 0.62
const MENU_BEAST_LIGHT_FLOOR: float = 0.58

# ------------------------------------------------------------------------------
# Beast parallax
# ------------------------------------------------------------------------------

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
## The cohesive regional terrain texture repeats at this scale. The rejected
## Wang-floor pass is deliberately gone: alternating materials at this scale
## became giant rectangular islands and obscured the hand-authored road layout.
## Two world units per texel keeps the established terrain grain readable. [TUNE]
const GROUND_UNITS_PER_TEXEL: float = 2.0

## Sprite scale for units. The battlefield camera has to hold the whole lane
## ring, which leaves the hero about 79 screen pixels at source size - too small
## to read the art or the animation on it. [TUNE]
const HERO_SPRITE_SCALE: float = 1.75
const ENEMY_SPRITE_SCALE: float = 1.55
## Actor nodes are positioned at their ground contact. Their art and body are
## lifted above it, so foliage, torches, wildlife and combatants all compare the
## same physical point when the shared Y sorter orders them. [TUNE]
const HERO_FEET_ANCHOR: float = 0.43
const ENEMY_FEET_ANCHOR: float = 0.43
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
## How long a fork waits, after the first vote, before settling on what it has.
##
## **Measured from the first vote, not from the fork opening**, which is what
## makes a short number the right one: by the time anybody has voted, everyone
## has already had the whole approach to the junction to read three road cards.
## The clock is not reading time, it is the grace a decided party gives an
## undecided one.
##
## Twenty-five seconds was the first figure and it was too long by far. With two
## players and one of them hesitating, the other watched a dead screen for the
## better part of half a minute - and the two-process harness failed roughly one
## run in two because the fork had not settled inside its window, taking every
## later assertion with it, since a run cannot advance past an open fork.
const CROSSROAD_VOTE_SECONDS: float = 12.0
## How far off its route a body must be before it re-enters at the nearest leg
## rather than walking back to the waypoint it was heading for.
##
## Comfortably wider than a lane's own lateral spread: a column holds an offset
## of up to half a lane width on purpose, and re-anchoring on that would fight
## the formation's shape every frame. This is the distance that means *thrown*.
const ENEMY_REANCHOR_DISTANCE: float = 260.0
## How brightly a promoted body burns, and how fast the band moves over it.
##
## A champion is not merely a brighter elite: it is slower and wider, because at
## equal speed the two read as the same thing at different volumes. The eye
## separates them on rhythm long before it reads a colour.
const RANK_AURA_STRENGTH_ELITE: float = 1.35
const RANK_AURA_STRENGTH_CHAMPION: float = 1.9
const RANK_AURA_SPEED_ELITE: float = 1.35
const RANK_AURA_SPEED_CHAMPION: float = 0.85
const RANK_AURA_WIDTH_ELITE: float = 5.5
const RANK_AURA_WIDTH_CHAMPION: float = 8.0
## Noise cells across the sprite. Fewer, larger cells read as flame; many small
## ones read as static crawling on the silhouette.
const RANK_AURA_SCALE: float = 6.5
const VFX_SLASH_LIFE: float = 0.16
## The blade rides a little inside the wedge's outer edge, so the arc still
## reads as the reach and the weapon reads as being held rather than thrown.
const VFX_BLADE_RADIUS: float = 0.72
## Longer than the wedge: the wedge is a flash, the blade is a movement, and a
## movement the eye cannot follow is not worth drawing.
##
## **Cut from 1.9 to 0.85** (owner report, 2026-09-01): "melee weapon attack
## sweeps feel a little clunky and slow in comparison to the original quick trail
## only that would happen before". At 1.9 the blade was still travelling long
## after the swing had already resolved its damage, so the picture lagged the
## fight - and a strike whose feedback arrives late reads as heavy input, not as
## a heavy weapon. Below the wedge's own life now, so the edge outruns the flash.
const VFX_BLADE_LIFE_SCALE: float = 0.85
## Blade length as a fraction of the swing's reach.
const VFX_BLADE_SIZE: float = 0.62

## The ribbon the edge lays down, measured from the hilt to the point.
##
## Two radii rather than one width. The trail used to be a `Line2D` drawn along a
## single radius - the arc the middle of the blade happened to ride - which reads
## as a rope being swung rather than as a blade cutting: a real sword trail is
## the *area* the edge swept, wide at the point and pinched at the hand.
##
## Fractions of the swing's reach, so a maul with a longer reach lays down a
## proportionally longer ribbon without a second table of numbers. [TUNE]
const VFX_BLADE_TRAIL_HILT: float = 0.30
const VFX_BLADE_TRAIL_TIP: float = 0.95
## How much of the ribbon is still visible at its tail. Zero would taper to
## nothing, which is correct for the shape and reads as a smear; a little floor
## keeps the start of the arc legible.
const VFX_BLADE_TRAIL_TAIL_ALPHA: float = 0.0
const VFX_BLADE_TRAIL_HEAD_ALPHA: float = 0.66
## Segments along the arc. Ten was enough for a line; a filled ribbon shows its
## own facets, and under twenty the leading edge is visibly polygonal.
const VFX_BLADE_TRAIL_STEPS: int = 22
## How long the ribbon lingers after the edge has passed, as a multiple of the
## sweep. Short: this is the part that must not feel slow.
const VFX_BLADE_TRAIL_FADE: float = 0.75
## How much of the ribbon nearest the edge burns toward white, and how hot.
##
## A trail in one flat colour reads as a painted crescent. What sells a cut is
## that the metal is *ahead* of its own smear - so the last fifth heats up and
## everything behind it stays the weapon's colour. [TUNE]
const VFX_BLADE_TRAIL_HOT: float = 0.22
const VFX_BLADE_TRAIL_HEAT: float = 0.72
## Which way the gear icons are actually drawn. Every melee icon in `art/icons/ui`
## is painted on the up-right diagonal - hilt low-left, point high-right - so a
## blade meant to lead along the swing has to be turned back by this much first.
## Measured off the sprites; if new weapon art breaks the convention, this is
## the one number that has to move.
const VFX_BLADE_ART_DEGREES: float = -45.0
## How far the bow kicks back on release, and how long the recoil reads for.
const VFX_BOW_RECOIL: float = 26.0
const VFX_BOW_LIFE: float = 0.26
const VFX_BOW_SIZE: float = 150.0
const VFX_BOW_OFFSET: float = 34.0

## Procedural blood impact sizing. The setting can suppress this entire layer;
## the ordinary hit spark and number remain so combat never becomes less
## readable for a player who disables gore. [TUNE]
const VFX_BLOOD_HIT_SIZE: float = 54.0
const VFX_BLOOD_DEATH_SIZE: float = 82.0
const VFX_BLOOD_LIFE: float = 0.52
const VFX_BLOOD_DROPS_MIN: int = 5
const VFX_BLOOD_DROPS_MAX: int = 9
const VFX_BLOOD_ARC: Vector2 = Vector2(18.0, 46.0)
const VFX_BLOOD_LAND_SPREAD: float = 0.68

## Blood on the ground.
##
## Below anything that walks, above the road it stains: loot sits at -2 and the
## field itself lower still, so -3 puts a stain on the dirt and under the boots
## of whoever made it. [TUNE]
## How a drop announces itself, and how it announces being taken.
##
## The scatter already threw drops clear of the corpse, but they arrived at full
## size with no event - so a wave's worth of loot appeared as inventory rather
## than as spoils. The pop is short and overshoots: the eye catches the change in
## size, not the size. [TUNE]
const LOOT_POP_TIME: float = 0.22
const LOOT_POP_FROM: float = 0.35
const LOOT_POP_OVERSHOOT: float = 1.18

## The burst when a drop is taken. Coloured by the drop itself, so a rare piece
## reads as rare at the moment it matters rather than only while it lies there.
const LOOT_TAKE_SPARKS: int = 9
const LOOT_TAKE_SPEED: float = 190.0

const BLOOD_GROUND_Z: int = -3

## How long a stain lasts, and how much of that it spends at full strength.
##
## The hold matters more than the total. A mark that starts fading the instant it
## lands never reads as a stain at all - it reads as another transient effect,
## which is the thing blood on the ground exists not to be. It sits, then it
## goes. [TUNE]
const BLOOD_GROUND_LIFE: float = 600.0
## Sustained rain ages a stain this many times faster. Ten minutes of dry-field
## history becomes roughly two minutes under a downpour: visibly washed, never
## erased in one frame. [TUNE]
const BLOOD_RAIN_WASH_MULTIPLIER: float = 5.0
const BLOOD_HOLD: float = 0.45
const BLOOD_GROUND_ALPHA: float = 0.5

## Blobs per mark, and how far a blow throws them.
##
## Enough for an irregular shape and no more: the silhouette does the work at
## this zoom, not the detail inside it. [TUNE]
const BLOOD_BLOBS_MIN: int = 4
const BLOOD_BLOBS_MAX: int = 9
const BLOOD_THROW: float = 0.85

## Fresh, and dried. The second is where a stain ends up, which is what makes an
## old mark read as old rather than merely faint.
const BLOOD_FRESH: Color = Color(0.48, 0.06, 0.07)
const BLOOD_DRY: Color = Color(0.24, 0.07, 0.08)

## How much of a character's sprite is stained at nothing-left health.
##
## Not 1.0. A hero about to go down should look badly used, not repainted - the
## silhouette has to stay readable, and the party tint under it has to stay
## legible enough to tell four Wardens apart in a crowd. [TUNE]
const BLOOD_STAIN_MAX: float = 0.34
## Cluster scale and fine scatter for the actor stain shader. Larger clusters
## read as blood at gameplay zoom; fine noise keeps their edges organic. [TUNE]
const BLOOD_STAIN_CLUSTER_PIXELS: float = 3.4
const BLOOD_STAIN_FINE_SCATTER: float = 0.24

## How quickly the stain follows the health that drives it.
##
## Slower on the way off than on: taking a wound should show at once, and healing
## should wash it away over a few seconds rather than snapping clean, because an
## instant change reads as a bug in the sprite. [TUNE]
const BLOOD_STAIN_ON: float = 7.0
const BLOOD_STAIN_OFF: float = 0.6

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
const AMBIENCE_DB: float = -20.0

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

## Where a shot stops being bigger and starts being *hotter*.
##
## Scale alone was already carrying the upgrade - a level 5 shot is 1.64 times a
## level 1 - and a bigger shot still reads as the same shot. From this tier the
## head gains a white core turning against its own shell, which changes what the
## projectile *is* rather than how much of it there is. That is the difference
## between an upgrade the player can measure and one they can see. [TUNE]
const PROJECTILE_HOT_TIER: int = 3
const PROJECTILE_HOT_SCALE: float = 0.46

## How much faster the head turns per level, and how much harder the glow burns.
##
## Both small per step and cumulative across five: a max-level shot spins at
## twice the rate of a fresh one and blooms half again as bright, which is
## legible in a lane full of traffic without any of it being loud. [TUNE]
const PROJECTILE_SPIN_TIER_STEP: float = 0.25
const PROJECTILE_GLOW_TIER_STEP: float = 0.12

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
## **Retuned upward when the lateral bound landed**, and the reason is worth
## keeping. Torches were going out because enemies on *other legs of the same
## bent road* counted as pressure - three bands of them, measured at 185, 505 and
## 730 units to the side. Excluding the two that were never near the torch cut
## real pressure to a third, and 0 of 48 torches went out in a 45-second soak
## that had always passed.
##
## So the mechanic had been working for the wrong reason. This is what it costs
## to have it work for the right one: roughly a pair of enemies level with a
## brazier for four seconds. [TUNE]
const TORCH_DIM_PER_ENEMY_SECOND: float = 0.26
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
## How far out plants are scattered, in world units.
##
## Comfortably past the lane network at 900. The scatter used to stop at 1.15x
## that, so everything grew among the roads and the ground beyond them was empty
## - which reads as a map that stops rather than a place that continues. [TUNE]
const FOLIAGE_REACH: float = 2100.0

## Set by what the field should look like, because the cost turned out to be
## nothing at all.
##
## This was thinned twice on the strength of a measurement that did not survive
## checking. A single run said 1700 clumps cost 2.3 ms a frame; three interleaved
## passes say foliage off and foliage on are **16.8 ms and 16.8 ms** - identical
## to one decimal. The earlier number was noise on a machine whose frame time
## drifts by more than any effect being measured.
##
## Chosen on look, with one honest caveat: interleaved measurement puts 2100
## clumps at +0.7 ms and 1350 at +0.2 ms, so the cost is small but not quite
## zero and it scales with the count. 1500 buys most of the density back for
## about a fifth of a millisecond. Reported as too thin inside the roads on
## 2026-08-25. [TUNE]
const FOLIAGE_COUNT: int = 1500

## How strongly the scatter crowds inward. 0.5 is uniform by area; lower packs
## more of it near the roads and leaves the outer ground sparse.
##
## Nearer to uniform than it was, now that outer plants are not being rationed:
## some thinning away from the lanes is still truer to ground nobody walks on.
const FOLIAGE_INNER_BIAS: float = 0.42

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

## How large a clump is drawn, as a range so no two match.
##
## Raised on 2026-08-25: plants read as too small beside a 224-unit hero, which
## made the ground look like a texture rather than somewhere with things growing
## in it. Judge these against the hero, not against each other. [TUNE]
const FOLIAGE_MIN_SCALE: float = 1.15
const FOLIAGE_MAX_SCALE: float = 2.35

## Sway. Degrees of lean, and how fast the wind moves. [TUNE]
const FOLIAGE_SWAY_DEGREES: float = 5.5
const FOLIAGE_SWAY_SPEED: float = 1.15
## How much of its own phase each blade keeps, in turns. At 0 the field moves as
## one travelling wave, which is what it did; at 1 every blade is independent and
## the meadow stops reading as wind at all. A little under half keeps the gust
## legible while breaking up the lockstep.
const FOLIAGE_PHASE_JITTER: float = 0.42

## How far a blade's tip travels at full lean, in world units.
const FOLIAGE_SWAY_REACH: float = 34.0

## The same, for painted plants. Much less: a shrub, a rock or a flowering
## succulent is a stiff thing with a woody base, and giving it a blade of grass's
## whip is what makes scattered sprites read as cardboard flapping in a breeze.
const FOLIAGE_SWAY_REACH_PAINTED: float = 9.0
## How far a tree's crown travels. Smaller than a plant's despite the tree being
## far larger: the sway is applied in the sprite's own space and scales with it,
## so matching the plants' figure threw whole canopies across the road.
const FOLIAGE_SWAY_REACH_CANOPY: float = 3.4
## How fast a plant's idle sequence runs, in frames per second. Slow on purpose:
## this is a plant breathing under the shader's bend, not a creature moving, and
## it is also the rate at which any texture is reassigned at all.
const FOLIAGE_IDLE_FRAME_RATE: float = 4.5
## How fast a Codex entry's idle plays. Slower than the field, because a page is
## looked at rather than glanced at, and a creature flickering in a book reads as
## a broken image rather than a living one.
const CODEX_ART_FRAME_RATE: float = 3.5
## How far each painted kind bends, as a multiplier on the painted reach.
##
## **Tuned per foliage type rather than per material.** One number for every
## painted plant meant a fern and a boulder-sized bush leaned by the same amount,
## which reads as wrong in opposite directions: the fern looked stiff and the
## bush looked like it was about to fall over. Thin things with long leaves move
## most; dense masses barely move at all; props do not move, which is what a zero
## here means and why rocks are listed.
##
## Keyed by the kind suffix in the sprite name - `plant_<region>_<kind>.png` -
## so a new kind is a row here and a file on disk, never a branch in Foliage.
const FOLIAGE_KIND_SWAY: Dictionary = {
	"fern": 1.35,      # long fronds, the most mobile thing on the ground
	"flower": 1.15,    # a light head on a thin stem
	"blossom": 1.10,
	"shrub": 0.75,     # woody, and only the tips move
	"bush": 0.55,      # a dense mass; it breathes rather than sways
	"": 1.0,           # the region's own plant, the baseline
	"rock": 0.0,       # props do not move at all
	"boulder": 0.0,
	"log": 0.0,
	"stump": 0.0,
	"bones": 0.0,
	"wreckage": 0.0,
	"mushrooms": 0.35,
	"reeds": 1.5,      # the most mobile thing in the set
	"wildflower_01": 1.2,
	"wildflower_02": 1.2,
	"wildflower_03": 1.2,
	"wildflower_04": 1.2,
}

## Foliage moves slowly enough that 30 transform updates per second are visually
## continuous, while updating hundreds of off-road clumps at the render rate
## spends CPU on sub-pixel changes the player cannot see. [TUNE]
const FOLIAGE_UPDATE_INTERVAL: float = 1.0 / 30.0

## Foliage that deliberately has no authored idle sequence.
##
## Everything with a sway above zero should also carry frames (owner direction,
## 2026-09-01) - the wind shader bends what is drawn, and the frames are what
## makes a plant *breathe* rather than merely lean. One asset is not going to
## get them.
##
## `plant_desert_flower` is 32x40 and a single bloom on a single stem. Asked to
## move it, the generator invents a second bloom instead - twice, once on the
## ordinary prompt and once with the bloom count named explicitly in it. Both
## attempts were looked at on a contact sheet and discarded. The manifest carries
## the full account; this is the machine-readable half, so `foliage_art_check`
## can hold every other kind to the rule without failing on the one exception.
const FOLIAGE_IDLE_EXEMPT: Array[String] = ["plant_desert_flower"]

# ------------------------------------------------------------------------------
# Falling leaves
# ------------------------------------------------------------------------------
#
# Owner request, 2026-09-01: "would be nice if sometimes trees had leaf falling
# particle system effects that procedurally randomly have leaves occasionally
# falling and blowing with the wind a bit and landing on the ground somewhere
# naturally and randomly and aesthetically, and fading out after an appropriate
# amount of time without being distracting."
#
# "Without being distracting" is the constraint that shapes every number below.
# A leaf every second from every tree is weather; the intent is that the eye
# catches one occasionally and the field reads as alive rather than as a
# particle demo. So: a handful of leaves alive at once across the whole
# treeline, long gaps between falls, and a slow enough drift that nothing in
# the air competes with an enemy for attention.

## Seconds between one fall and the next, across the whole treeline. [TUNE]
const LEAFFALL_INTERVAL: Vector2 = Vector2(1.6, 5.4)

## How many leaves one fall releases. Usually one; sometimes a small flurry,
## which is what stops the effect reading as a metronome. [TUNE]
const LEAFFALL_BURST: Vector2i = Vector2i(1, 3)

## Live leaves, hard ceiling. Above about thirty the field starts to read as
## autumn rather than as a tree shedding. [TUNE]
const LEAFFALL_MAX: int = 30

## Downward speed, and how far a leaf swings either side of its fall line.
## Leaves do not drop; they hesitate. [TUNE]
const LEAFFALL_FALL_SPEED: Vector2 = Vector2(26.0, 54.0)
const LEAFFALL_SWAY_PIXELS: float = 24.0
const LEAFFALL_SWAY_SPEED: Vector2 = Vector2(0.8, 1.9)
const LEAFFALL_SPIN: Vector2 = Vector2(-2.4, 2.4)
const LEAFFALL_SIZE: Vector2 = Vector2(5.0, 9.5)

## How far down the canopy a leaf starts, and how far it falls before it lands,
## as fractions of the tree's drawn height. Landing short of the trunk's own
## base is what makes it look like it settled on the ground beside the tree
## rather than sinking into it. [TUNE]
const LEAFFALL_START_HEIGHT: Vector2 = Vector2(0.45, 0.85)
const LEAFFALL_DROP: Vector2 = Vector2(0.55, 1.0)

## Sideways drift per unit of the weather's own wind, in pixels per second. The
## same `WeatherData.wind` the grass leans to, so a duststorm carries leaves the
## way it bends reeds. [TUNE]
const LEAFFALL_WIND_DRIFT: float = 46.0

## How long a landed leaf lies there, and how long it takes to go. Long enough
## that the player sees it land; short enough that the ground never accumulates.
## [TUNE]
const LEAFFALL_REST: float = 3.2
const LEAFFALL_FADE: float = 1.8

## Per-region shedding, because a conifer under snow is not a jungle canopy.
##
## The snowfield's "leaves" are pale and rare - what comes off a laden branch
## there is snow, not foliage - and the desert sheds least of all. Tuned per
## region for the same reason the wind is: an asset should move like the thing
## it is a picture of. [TUNE]
const LEAFFALL_REGION_RATE: Dictionary = {
	"jungle": 1.0,
	"desert": 0.45,
	"snow": 0.30,
}

## The two colours a region's leaves are drawn between.
const LEAFFALL_REGION_COLOURS: Dictionary = {
	"jungle": [Color("6f8f42"), Color("c2a33e")],
	"desert": [Color("b9954e"), Color("8a6a38")],
	"snow": [Color("d7e2ea"), Color("9fb3bf")],
}

## How opaque a leaf is in the air. Below the foliage it falls from, so it
## reads as something small rather than as a UI marker. [TUNE]
const LEAFFALL_ALPHA: float = 0.82

## Drawn just above the ground stains and far below anything readable. [TUNE]
const LEAFFALL_Z: int = -2

## How far beyond the camera a tree may be and still shed, as a share of the view
## height. A tree just off the edge drops leaves that drift into frame, which is
## what stops the effect from starting exactly at the screen border. [TUNE]
const LEAFFALL_VIEW_MARGIN: float = 0.12

## Per-region tree sway, multiplying `FOLIAGE_SWAY_REACH_CANOPY`.
##
## Owner request, 2026-09-01: "each asset's wind shader should be tuned for what
## it is". One canopy material for every tree in the game meant a snow-laden
## conifer and a jungle broadleaf leaned by exactly the same angle, which is the
## foliage equivalent of giving every enemy the same walk. [TUNE]
const FOLIAGE_TREE_SWAY: Dictionary = {
	"jungle": 1.30,   # broad leaves on long boughs, the most mobile canopy
	"desert": 0.85,   # sparse and stiff, little sail area
	"snow": 0.50,     # conifer, and weighted down by what is sitting on it
}

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

## Sub-pixel shoulder blend between the baked lane mask and regional ground.
## Kept near one source texel so it softens the cut-paper edge without turning
## the pixel-art road itself blurry or widening build geometry. [TUNE]
const PATH_EDGE_FEATHER_TEXELS: float = 1.15
const PATH_EDGE_FEATHER_STRENGTH: float = 0.82

## Rain catches only the road's brighter texels and moves in long, faint bands.
## It is part of the existing road pass rather than another full-field layer.
## [TUNE]
const PATH_WET_SHEEN: float = 0.24

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

## Reaching the summit. Large enough that no amount of wave grinding on a lost
## run out-scores finishing the game.
const SCORE_VICTORY: float = 1800.0

## Awarded on a win, scaled by how far under par the run came in.
const SCORE_SPEED: float = 900.0

## The clear that speed is measured against, in seconds.
##
## **Sixty minutes, raised from fifty on 2026-09-01** alongside
## `PREPARATION_BETWEEN_WAVES`. A full run is 51 waves (`curve_report`), and
## roughly forty of those clear into a between-wave breather rather than into a
## crossroad or a boss - so doubling the breather from fifteen seconds to thirty
## adds about ten minutes of wall clock to an unhurried run that plays exactly
## the same.
##
## Without moving par with it, every player's speed bonus would have quietly
## fallen for a change that has nothing to do with how well they played, and
## runs recorded before the change would have become permanently unbeatable.
## Par means "about what an unhurried full run takes"; when that number moves,
## this one has to move with it or it means something else.
##
## The speed term is 900 of roughly 8,000 on a perfect fast clear, so the board
## is not sensitive to this - but "not very wrong" is not a reason to leave a
## number wrong. [TUNE]
const SCORE_PAR_SECONDS: float = 3600.0

## An untouched town, at full value. Measured from damage taken rather than
## health remaining, because Hearthmend repairs it and a town rebuilt three times
## was patched, not defended.
const SCORE_TOWN_INTACT: float = 1200.0

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

## How much taller interactive elements are when the game is being played with
## a thumb.
##
## Fingertips are about 9mm across and a mouse cursor is one pixel. Apple and
## Google both put the minimum comfortable target near 44-48 density-independent
## pixels; the desktop buttons here are 54 tall, which is fine under a cursor and
## marginal under a thumb once a phone's scaling is applied.
##
## Width is intentionally not multiplied: a nine-control combat row cannot grow
## sideways on a phone. UiMetrics applies this to each control's Y target,
## padding, label size and panel contents independently. [TUNE]
const UI_TOUCH_SCALE: float = 2.0

## Absolute floors keep small desktop-only utility controls from remaining tiny
## merely because 1.68 times tiny is still tiny. [TUNE]
const UI_TOUCH_MIN_TARGET_HEIGHT: float = 120.0
const UI_TOUCH_MIN_TARGET_WIDTH: float = 76.0
const UI_TOUCH_FONT_SCALE: float = 1.40
const UI_TOUCH_MIN_FONT_SIZE: int = 26
const UI_TOUCH_PANEL_SCALE: float = 1.10
const UI_TOUCH_GAP_SCALE: float = 1.28
const UI_TOUCH_SPELL_SLOT_HEIGHT: float = 132.0
const UI_TOUCH_SPELL_SLOT_WIDTH: float = 122.0

## Dense sheets need compact, still-thumb-safe rows. The generic 120-unit floor
## is for isolated controls; applying it to eight tower choices leaves only two
## visible on a landscape phone. [TUNE]
const UI_TOUCH_BUILD_TARGET_HEIGHT: float = 84.0
## Every scrolling surface exposes a draggable rail, including desktop users
## without a wheel. The touch width is deliberately a larger thumb target. [TUNE]
const UI_SCROLLBAR_WIDTH: float = 20.0
const UI_TOUCH_SCROLLBAR_WIDTH: float = 30.0
const UI_SCROLL_STEP: float = 54.0
const UI_SCROLL_DRAG_DEADZONE: int = 8
const UI_TOUCH_PREPARATION_BUTTON_HEIGHT: float = 72.0

## Floating panels - the town sheet, the pause menu, the leaderboard.
##
## Every one of these was authored as a fixed rectangle and every one of them
## overflowed a phone. The screen is the bound, not the number the panel was
## drawn at: a panel asks for a share of the viewport and never exceeds what is
## actually there.
##
## `UI_PANEL_MARGIN` is the clear space kept between a panel and the screen edge
## on every side. Below about 16 the frame's corner ironwork touches the bezel
## and the panel reads as clipped even when it is not. [TUNE]
const UI_PANEL_MARGIN: float = 22.0

## The widest a side-docked building sheet may be, as a share of the screen, and
## the narrowest it is allowed to become. The share matters more than the pixels:
## on a phone 0.42 leaves the battlefield readable beside it, and on a desktop it
## stops the sheet from becoming a billboard. [TUNE]
const UI_SIDE_PANEL_SHARE: float = 0.42
const UI_SIDE_PANEL_MIN_WIDTH: float = 360.0
const UI_SIDE_PANEL_MAX_WIDTH: float = 680.0

## The narrowest a wrapped action row inside a side sheet may ask to be. Rows
## wrap rather than widen, so this is what stops a long cost line from pushing
## the whole sheet off the screen. [TUNE]
const UI_PANEL_ROW_MIN_WIDTH: float = 240.0

## Centre-floating panels (pause, leaderboard) as a share of the screen. [TUNE]
const UI_CENTRE_PANEL_WIDTH_SHARE: float = 0.86
const UI_CENTRE_PANEL_HEIGHT_SHARE: float = 0.92

## The thin hero-progression strip across battlefield and raid views. [TUNE]
const UI_XP_BAR_HEIGHT: float = 18.0
const UI_XP_BAR_TOUCH_HEIGHT: float = 32.0


## How visible a persistent touch *button* is.
##
## Higher than a stick's, because the two are seen under opposite conditions. A
## stick is drawn only once a thumb is already on it, so it never has to be
## found; a button is on screen the whole time and has to be found exactly once.
const TOUCH_BUTTON_OPACITY: float = 0.58


## The one field a stranger chooses, so the one field that needs a rule.
const SCORE_NAME_MAX: int = 20
const SCORE_NAME_FALLBACK: String = "Oathless"

## What a run is filed under when it carries no build version.
##
## The board's table checks `char_length(version) between 1 and 32`, so an empty
## string is not a harmless blank - it is a rejected insert. Runs queued by an
## older build carry one, and retried forever against a constraint they could
## never satisfy.
const SCORE_VERSION_FALLBACK: String = "unknown"

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

# ------------------------------------------------------------------------------
# Co-op — GDD §54, amended 2026-08-24. See docs/COOP_DESIGN.md
# ------------------------------------------------------------------------------

## The default port a host listens on.
##
## High and unregistered on purpose. The obvious choices — 7777, 27015 — are the
## ones already occupied on a machine that plays other games, and "someone else's
## server is already on that port" reads to a player as "co-op is broken".
const COOP_PORT: int = 45870
## LAN discovery uses its own UDP port so a listener can coexist with the game
## socket on the same machine. [TUNE]
const COOP_DISCOVERY_PORT: int = 45871

## Four, and the transport is told so.
##
## Not a soft convention: ENet is given this as its peer limit, so a fifth
## connection is refused by the transport rather than by a rule somewhere in
## GDScript that could be missed.
##
## Two until 2026-08-26, when the owner asked for parties. The number is used
## rather than assumed everywhere it matters - wave size, the party roster, the
## spawn ring and the colours below all derive from it - so it is a number to
## change rather than a rewrite, which is the only reason two became four
## cheaply.
const COOP_MAX_PLAYERS: int = 4
const COOP_MAX_GUESTS: int = COOP_MAX_PLAYERS - 1

## Who is who, at a glance.
##
## **Colour is how a player finds themselves in a crowd of four**, so these are
## picked for distance and for colour blindness rather than for prettiness: red,
## blue, yellow and green are the four the owner asked for and are also the four
## that stay distinguishable under the most common deficiencies, because they
## differ in lightness as well as in hue.
##
## Slot 1 is always the host. Nothing reads a colour from anywhere else, so a
## player is the same colour on every screen in the party.
## Who is who, at a glance, in a lane full of enemies.
##
## Brighter and further apart than the first set, which was chosen to sit
## politely inside the game's palette and did exactly that - four muted mid-tones
## that were hard to tell apart in a crowd, and nearly impossible once a torch
## was throwing orange over everything.
##
## Separated by **value as well as hue**, so they still read when the colour
## itself is unreliable: the yellow is the brightest, the blue the darkest, and
## red and green sit between them. That ordering is what carries a colour-blind
## player, and it is why the yellow is not simply a lighter orange. [TUNE]
const PARTY_COLOURS: Array[Color] = [
	Color("ff4436"),
	Color("2f8ff5"),
	Color("ffd426"),
	Color("46d95e"),
]
const PARTY_COLOUR_NAMES: Array[String] = ["Red", "Blue", "Yellow", "Green"]

## The mark under a player's feet that says which of the four they are.
##
## Under the feet rather than on the body: four heroes tinted red, blue, yellow
## and green would fight the art, the lighting and the damage flash - and the
## flash is a readout that matters more than the colour. Faint enough to read as
## ground rather than as an effect. [TUNE]
## The mark under a player's feet, and how far the body is leaned toward the
## seat colour.
##
## Both, because neither alone was enough. A ground mark on its own could not be
## picked out of a crowded lane, and a body painted flat would fight the art, the
## lighting and the hurt flash. The tint is a *lean* - the character still looks
## like itself, and a white flash still reads as a flash. [TUNE]
const PARTY_MARK_SCALE: float = 0.86
const PARTY_MARK_LIFT: float = 16.0
const PARTY_MARK_ALPHA: float = 0.78
## How far the body leans toward the seat colour.
##
## Raised from 0.30, which was a lean nobody could see. The character still has
## to look like itself and a white hurt flash still has to read as a flash, so
## this is not a repaint - but at 0.30 four heroes in a scrum were four
## identical silhouettes, which is the one thing the colour exists to prevent.
const PARTY_TINT_STRENGTH: float = 0.46

## How far the light a player carries leans toward their seat colour.
##
## The strongest of the three cues and the one that was missing entirely. A
## hero's light reaches much further than their body, so at night it says who is
## where before anyone is close enough to make out a silhouette - and in a game
## played largely after dark that is most of the time.
##
## Stronger than the body tint because a light has no art to fight. It keeps
## enough of the warm base that the ground still looks lit rather than gelled.
const PARTY_LIGHT_STRENGTH: float = 0.62

## The lobby uses the hero's authored south-facing idle rather than a static
## thumbnail. It deliberately runs at the same rate as the in-world idle so a
## player who joins the row looks like the Warden who will step onto the road.
## [TUNE]
const COOP_LOBBY_IDLE_FPS: float = 8.0
const COOP_LOBBY_CARD_SIZE: Vector2 = Vector2(132.0, 178.0)
const COOP_LOBBY_HERO_SIZE: Vector2 = Vector2(116.0, 112.0)
## Maximum co-op panel height. Runtime clamps this to the visible viewport so a
## shorter window creates overflow inside the scroll surface instead of placing
## the panel's top and bottom beyond the screen. [TUNE]
const COOP_PANEL_VIEW_HEIGHT: float = 920.0
const COOP_PANEL_EDGE_MARGIN: float = 24.0
const COOP_PANEL_MIN_VIEW_HEIGHT: float = 320.0

## How wide a line in the party feed may run before it wraps. [TUNE]
const PARTY_LOG_WIDTH: float = 420.0

## The longest thing a player may say at once.
##
## Bounded because it arrives from the network and is drawn: a line long enough
## to fill the screen is a line long enough to hide a wave behind. [TUNE]
const CHAT_MAX_LENGTH: int = 140

## How many friends may be kept, and how often the list is refreshed.
##
## Bounded because the list is drawn and because every refresh asks about every
## code at once - a thousand friends would be a thousand codes in one query. [TUNE]
const FRIENDS_MAX: int = 60
const FRIENDS_REFRESH: float = 12.0
const PRESENCE_INTERVAL: float = 30.0

## How long a join attempt may sit before it is called a failure. [TUNE]
##
## A timer is needed rather than only ENet's `connection_failed`, because that
## signal answers "the host refused" and not "there is nothing at this address".
## A wrong IP produces silence, and silence with no clock is a player staring at
## a spinner deciding the game has hung.
const COOP_CONNECT_TIMEOUT: float = 10.0

## How long a *room* may take to connect, against ten seconds for a direct dial.
##
## Much longer on purpose, because it is a different kind of wait: ENet either
## reaches an address or it does not, while a WebRTC handshake asks two routers
## about themselves through a third party and then tries several routes. On a
## slow link the first attempt legitimately takes half a minute, and giving up
## on a connection that would have worked is the worse failure. `CoopWebRTC` has
## its own deadline just under this one, so the transport reports the reason
## before the session times out with nothing to say. [TUNE]
const COOP_CONNECT_TIMEOUT_ROOM: float = 50.0

## How much bigger a wave gets per extra player. [TUNE]
##
## **Body count, and nothing else.** GDD §54's co-op re-cut scales the director
## to the player count, and `docs/COOP_DESIGN.md` §5 is explicit about which knob
## that must be: more enemies, never tougher ones.
##
## Scaling individual health and damage instead is the classic mistake. It does
## not add pressure, it adds *duration* — the same fight, slower — and it
## invalidates every dodge window the combat design is built on, because a
## wind-up tuned to be dodgeable is tuned against a specific time-to-kill.
##
## **0.5, and the naive answer was wrong.** Two players face 1.5x the bodies, not
## 2x. Measured with `curve_report -- --players=2` rather than reasoned about:
##
##   per extra player   1.00   0.70   0.60   0.50   0.30   0.00
##   peak pressure      0.90   0.77   0.74   0.71   0.70   0.60
##   (one player peaks at 0.63)
##
## Doubling the bodies made co-op 43% harder at the peak, not equal. The reason
## is worth knowing before anyone retunes this: the late game is **tower**
## dominated, so a second hero barely moves late capability - at zero extra
## bodies, two players still measure 0.60 against a solo 0.63. The offset that
## does exist comes from income, and income buys sublinear damage because the
## tower count is capped and upgrades escalate. So bodies scale threat linearly
## while a second player scales capability much less than linearly.
##
## 0.5 sits above the solo curve on purpose. The model is blind to the single
## biggest thing a second player brings - two lanes covered *at once*, where solo
## play must choose - and it is equally blind to the costs, latency and
## coordination. Those partly cancel and the balance of them is not something a
## headless model can settle.
##
## **This number is provisional until co-op is played on two machines**, which is
## a row on the road list. It is one constant with a recorded measurement behind
## it, which is what makes it cheap to move.
const COOP_BODY_SCALE_PER_PLAYER: float = 0.5

## Trim on what a body pays when there are two players. [TUNE]
##
## Twice the bodies into one shared pool is twice the income, and the tower
## curve was tuned against one player's earnings. This exists so the fix for
## "co-op is too rich" is a number rather than a redesign; 1.0 means no trim,
## which is where it starts because the measured curve did not need one.
const COOP_KILL_INCOME_SCALE: float = 1.0

# ------------------------------------------------------------------------------
# Torch shadow
# ------------------------------------------------------------------------------

## The pool of shadow at the foot of a torch post, in world units. [TUNE]
##
## Given rather than measured: the ironwork is drawn from polygons and has no
## texture to size a shadow from. Narrow, because a torch is a post - a wide pool
## reads as a barrel.
const TORCH_SHADOW_WIDTH: float = 26.0

# ------------------------------------------------------------------------------
# Beast parallax — GDD §7
# ------------------------------------------------------------------------------

## The beast scope's procedural parallax bands (GDD §7).
##
## The scope had two depths — a painted sky and the ground underfoot — so
## distance read as a texture sliding rather than as land being crossed. These
## are drawn silhouettes rather than painted art, because a distant ridge is one
## flat colour under a skyline once haze has taken the detail out of it, and new
## painted art is an art-direction task this toolchain cannot do.
##
## Rates are the whole illusion and they must stay ordered: sky slowest, then
## ridge, then ground, then the near band that passes in front of the beast.
## Anything out of order reads as the world turning inside out.
const BEAST_RIDGE_Z: int = -12
const BEAST_RIDGE_SCROLL: float = 0.34
const BEAST_RIDGE_HEIGHT: float = 130.0

## Just above where the ground meets the sky. The scope camera is centred on the
## world origin, so this is measured down from the middle of the view - the first
## attempt put it at 210 and drew a wall across half the sky.
const BEAST_RIDGE_BASELINE: float = 366.0

## How much darker the hazed ridge is than the sky it stands against. Without it
## the band reads as fog rather than as land. [TUNE]
const BEAST_RIDGE_SHADE: float = 0.34

## How far the ridge is pulled toward the sky's own colour. High, because the
## point of a distant band is that the air between has taken most of it. [TUNE]
const BEAST_RIDGE_HAZE: float = 0.62

## The band that passes in front of everything, including the beast.
##
## Fast and nearly black: it is close enough that the eye cannot resolve it, and
## it is what turns "a beast on a treadmill" into "a beast being overtaken by
## the ground". Kept short so it frames the bottom of the view rather than
## eating it.
const BEAST_FOREGROUND_Z: int = 40

## Tall enough that its peaks rise *above* the ground line and cross the beast's
## feet. The first attempt kept it entirely below that line, where it was a dark
## shape on an already-dark ground and read as nothing at all - a foreground that
## never occludes the subject is not a foreground, it is a texture.
const BEAST_FOREGROUND_HEIGHT: float = 190.0
const BEAST_FOREGROUND_BASELINE: float = 560.0

## How much of the horizon's colour the near band keeps. [TUNE]
##
## Not near-black, which was the first attempt and is a trap: keeping 14% of a
## pale desert sky is effectively black, and a black mass against near-white sand
## reads as a hole punched in the screen rather than as ground close to the
## camera. Keeping a third leaves a deep version of the region's own colour, so
## the band still silhouettes but belongs to the place it is in.
const BEAST_FOREGROUND_DARKEN: float = 0.32

# ------------------------------------------------------------------------------
# Weather — GDD §177, §193
# ------------------------------------------------------------------------------

## See scripts/systems/weather_veil.gd.
##
## How long precipitation takes to arrive or clear, in seconds. Weather that
## switches on between two frames reads as a bug in the renderer rather than as
## a change in the sky. [TUNE]
## How far the weather veil reaches, and how finely it is divided.
##
## The reach has to cover everywhere a player can walk, not the road grid: the
## foliage scatter goes to 2100 and wildlife roams to 2000, so a veil sized to
## the lanes left a visible edge where the rain stopped. The cell count scales
## with the reach so a raindrop stays the same size in the world. [TUNE]
const WEATHER_VEIL_REACH: float = 2600.0
const WEATHER_VEIL_CELLS: float = 34.0

const WEATHER_FADE_SECONDS: float = 3.5

## How long snow takes to cover the ground from bare, and to melt back, in
## seconds of continuous snowfall. [TUNE]
##
## Melting is deliberately far slower than settling. Snow arrives with the storm
## and outlives it by a long way, which is what makes it feel like a thing that
## happened rather than an overlay tied to a switch.
const SNOW_SETTLE_SECONDS: float = 90.0
const SNOW_MELT_SECONDS: float = 240.0

## How white the ground goes at full cover, 0..1. Not 1.0: the region's own
## floor art has to stay legible under it, and a pure white field is a field
## where nothing can be read. [TUNE]
const SNOW_COVER_STRENGTH: float = 0.62

# ------------------------------------------------------------------------------
# Snow on the ground — see scripts/systems/snow_cover.gd
# ------------------------------------------------------------------------------

## How white the *paths* go under snow, 0..1. [TUNE]
##
## Much lighter than `SNOW_COVER_STRENGTH`. A road is walked on, so it holds a
## dusting rather than a drift - and the faint layer that produces it is drawn
## above the roads, which is also what feathers the edge where a deep verge meets
## a cleared path. The two layers share one noise field, so a drift continues
## across the road as a dusting rather than stopping at the kerb.
const SNOW_PATH_STRENGTH: float = 0.22
## Sparse points of settled snow catch the light on Medium and above. [TUNE]
const SNOW_SPARKLE_STRENGTH: float = 0.24

# ------------------------------------------------------------------------------
# Regional post-processing — high quality only
# ------------------------------------------------------------------------------

## One optional screen pass combines grading, edge atmosphere and desert heat.
## High uses the authored grade; Ultra gets the full values. [TUNE]
const REGION_GRADE_HIGH_SCALE: float = 0.72
const REGION_GRADE_STRENGTH: float = 0.13
const REGION_GRADE_VIGNETTE: float = 0.20
const REGION_EDGE_ATMOSPHERE: float = 0.16
const DESERT_HEAT_DISTORTION: float = 0.0018
const DESERT_HEAT_SPEED: float = 0.42

## Boss phase breaks are a transient local shader, never a screen-sized pass.
const BOSS_PHASE_CRACK_DURATION: float = 0.72
const BOSS_PHASE_EDGE_PULSES: int = 3

## Chance per step that an enemy walking on snow slips sideways, at full cover.
##
## Scaled by how much snow is actually lying, so a dusting barely does it and a
## covered field does it often. Deliberately small: a slip is a moment of
## character, and one that fires constantly is a movement bug with a story
## attached. [TUNE]
const SNOW_SLIP_CHANCE: float = 0.055

## How far a slip carries, in world units, and how long it lasts.
const SNOW_SLIP_DISTANCE: float = 46.0
const SNOW_SLIP_SECONDS: float = 0.34

# ------------------------------------------------------------------------------
# Co-op smoothing
# ------------------------------------------------------------------------------

## How hard a hero is pulled onto the position the host reports, 0..1 per packet.
##
## Not 1.0, which is the obvious value and the wrong one. Both heroes are already
## walking - the partner from relayed input, the local one from its own player -
## so assigning the authoritative position outright fights that motion twenty
## times a second. It reads as a stutter, and it flattens the velocity the walk
## cycle is chosen from, so a moving hero plays its idle animation.
##
## Low enough to be invisible, high enough that a real disagreement is gone
## within a few packets. [TUNE]
## How often a partner's cursor position is sent while a fork is open, and the
## colour it is drawn in.
##
## Only while the crossroad is up: this is the one screen where two people are
## deciding one thing together and the only other signal is the screen closing.
## Everywhere else a partner's cursor is noise. [TUNE]
const COOP_POINTER_INTERVAL: float = 0.06
const COOP_PARTNER_TINT: Color = Color(0.62, 0.86, 1.0, 1.0)

## How hard a mirrored body is pulled toward where the host's copy should be.
##
## Applied per frame as `delta / window * this`, so it is a rate rather than a
## per-packet step and behaves the same at any frame rate. Around 1.0 erases the
## error over roughly one packet window; higher is tighter and more likely to
## show the correction, lower is smoother and further behind. [TUNE]
const COOP_MIRROR_CATCHUP: float = 1.35

## How much of a fresh velocity estimate to believe.
##
## One late or early packet makes a single estimate wildly wrong, and a puppet
## that lurched for each of them would be jittery in exactly the way the
## interpolation exists to prevent. [TUNE]
const COOP_MIRROR_VELOCITY_BLEND: float = 0.45

## How far out of place a mirrored body may be before it is teleported instead
## of walked. Multiplies the distance the thing could actually have covered in
## one packet window, so a fast enemy gets more slack than a slow one. [TUNE]
const COOP_MIRROR_SNAP_FACTOR: float = 6.0

const COOP_POSITION_CORRECTION: float = 0.25

## How close a partner must stand to help a downed hero back up, in world units.
##
## About two body widths: close enough that it is a deliberate act rather than
## something that happens because you were nearby, and close enough to be
## dangerous during a wave. [TUNE]
const COOP_REVIVE_RADIUS: float = 150.0

## How long a partner must hold the revive key to get somebody back up.
##
## Long enough to be a commitment - three seconds standing still beside a downed
## friend, in the open, during a wave - and short enough that it is worth trying
## rather than writing them off. This replaced an earlier design in which dying
## in co-op still cost a wound and a partner merely made the respawn faster; the
## owner re-cut it on 2026-08-25 so that a rescued player costs the run nothing
## and only a *team wipe* is paid for. [TUNE]
const COOP_REVIVE_SECONDS: float = 3.0

## Health a revived hero comes back with, as a fraction of their maximum.
##
## Lower than the Wound respawn, and that asymmetry is the balance: a revive is
## fast and costs the run nothing, so it returns somebody fragile and standing
## where they fell rather than safe at the spawn. [TUNE]
const COOP_DOWNED_REVIVE_HP: float = 0.35

## How far from the reported impact point a guest will look for the enemy a
## relayed tower shot was aimed at, in world units.
##
## Wide enough to survive a batch of movement between the host firing and the
## packet landing, narrow enough that it cannot pick a different enemy in a
## crowd. Roughly one and a half tiles. [TUNE]
const COOP_SHOT_MATCH_RANGE: float = 96.0

## How long a mirrored body keeps walking on its last known speed before giving
## up and standing still.
##
## Long enough to ride out a late packet or two, short enough that a dropped
## connection does not march the whole field off the map. [TUNE]
const COOP_MIRROR_COAST_LIMIT: float = 0.75
