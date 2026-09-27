# The Arsenal — augments that are ways of killing

**Design and build record · 27 September 2026 · owner request, built**

> *"These augment cards you're showing me are too similar to the relics and stuff
> players would get at crossroads. These augments are supposed to be more like
> Megabonk and Tower of Babel game providing new little ways of dealing damage to
> enemies, etc. The augs still scale in game and are also affected by the player's
> gear and persistent player level etc. And even so with it all it still needs to
> be perfectly balanced. Players should have fun eliminating way more hoards of
> enemies, and needing to in order to earn the resources needed for their
> towers..."* — owner, 2026-09-27

## 1. What was wrong

The live deck was 29 cards: **24 moved one number** in `Modifiers` (+8% tower
damage, +10% Gold, −6% build cost…) and 5 keystones re-routed a rule. A relic
socketed at a crossroad also moves one number in `Modifiers`. So a draft of
augments and a relic offer were the same decision wearing two frames, and neither
changed *how the player fights*.

Megabonk and Tower of Babel get their pull from the opposite: every pick is a new
**thing on the screen that kills** — an orbiting blade, a homing bolt, a pulse, a
trail of fire — and the fun is watching one pathetic fireball become a machine.

## 2. The decision

**The deck becomes an Arsenal.** An augment is now one of three kinds:

| Kind | What it is | Levels | Example |
|---|---|---|---|
| **Weapon** | An autonomous way of dealing damage, anchored to the Warden, the towers or the town | I–V, each level changes a visible number (count, size, rate or damage) | *Ember Wisps* — fire orbs circle the Warden and burn what they touch |
| **Catalyst** | Moves a number *only the Arsenal reads* — cadence, count, area, duration, power | I–V | *Quickening Oil* — every weapon fires sooner |
| **Keystone** | Re-routes an existing rule (unchanged: Cold Snap, Tinderstrike, Timberwright, Sapper's Due, Hunter's Mark) | I | — |

**Evolutions** close the loop that makes the genre addictive: a weapon at level V
with its paired catalyst in the hand is offered its evolved form, which replaces
it and keeps the slot.

**The 24 scalar cards are retired, not deleted.** Their resources stay on disk and
resolve by id — a banked expedition holding one still reads it, and its number
still reaches `Modifiers` for that road — but no draft deals them again. That is
the relic overlap the owner named, removed at the one place a card is chosen.

## 3. The bounds

Each is gated (`arsenal_check`), because every one of them has a precedent in
this project of a system that was fair on its own and broke something else.

1. **Every blow goes through `Enemy.take_damage`, named in the ledger.** A ward
   turns it, a planted shield takes it, Ironhide resists it, a puppet on a guest
   refuses it, and the debrief says which weapon did it (`arsenal:<id>`).
2. **One formula, and gear and level are in it.** A hit is
   `damage × level × act × the owner's multiplier × (1 + Arsenal power)`. The
   owner's multiplier is `Hero.damage_multiplier()` — Might (a point a level, and
   gear), the chain's form, the hand — so a levelled, geared Warden's Arsenal hits
   harder by exactly the amount their swing does. **Focus shortens a weapon's
   cadence** as it shortens a spell's, capped at the same `HERO_FOCUS_COOLDOWN_CAP`.
   A weapon anchored on the board or the town uses the party's mean multiplier.
3. **No weapon fires a weapon.** Generated damage never triggers a kill-weapon of
   the same card, and every kill-triggered payload is capped a second. The chain
   reaction is real and it ends.
4. **It freezes with its scope.** A weapon lives under the hero or the battlefield,
   so a raid's freeze holds every orb and bolt in the air (working rule 8).
5. **It is measured.** `curve_report` models each weapon's damage a second at its
   level and act, times its authored *crowd factor* (how many bodies a hit
   typically lands on), and `arsenal_check` measures that crowd factor against a
   real crowd — so the curve cannot be tuned against a model the fight disagrees
   with.
6. **It is budgeted.** A weapon's projectiles, orbitals and strikes are records on
   one canvas, never nodes; a hero holds at most `ARSENAL_RECORDS_MAX` of them and
   the oldest give way.
7. **Nothing persists.** The Arsenal is the run's hand, run-scoped as a relic is
   (working rule 7).

## 4. The roster

Chosen from the ~200 ideas the owner forwarded (`AUGMENT_CATALOGUE_2026-09-26.md`,
second half) by one test: **does it create a new *shape* of killing that this game
does not already have, readable at a glance on a crowded road?** Eight patterns
cover them — orbit, seeker, chain, nova, trail, strike, on-kill, arc — and each is
code once; every weapon is a data file (working rule 3).

### Warden — the Arsenal at your shoulder (per Warden in co-op)

| Weapon | Pattern | Element | Plays like |
|---|---|---|---|
| Ember Wisps | Orbit | Fire | Fire orbs circle you and burn what they touch; more orbs a level |
| Frost Shards | Orbit | Water | A wider, slower ring that chills what it cuts |
| Seeking Flames | Seeker | Fire | Homing firebolts at the nearest body; more a volley a level |
| Chain Spark | Chain | Air | Lightning leaps from you through the crowd, one more jump a level |
| Thunderclap | Nova | Air | A pulse around you every few seconds that throws bodies back |
| Thorn Wake | Trail | Earth | Walking leaves thorns that bite whatever stands in them |
| Stone Rain | Strike | Earth | Rocks fall on the thickest knot of bodies near you, telegraphed |
| Marrow Seekers | On kill | Spirit | A body that dies lets a spirit go to hunt the next |

### Rampart — the towers near the Warden fight (the party's)

| Weapon | Pattern | Plays like |
|---|---|---|
| Sentry Wisps | Orbit on towers | Every tower near you keeps a wisp that zaps what comes near |
| Arc Lattice | Arc | Lightning hangs between the towers near you and bites what crosses it |
| Fortress Barrage | Strike from towers | Every twelve kills, the towers near you each lob a stone |

**Near the Warden, not every tower** (`ARSENAL_TOWER_REACH`). The first measure
armed every tower on the board: with forty of them Sentry Wisps alone modelled at
more than the whole board by Act X and the Arsenal was nine tenths of the
defence. Arming the towers within reach of a Warden bounds it by a handful and
makes where the Warden stands decide which stretch of wall fights harder.

### Hearth — the town and the road (the party's)

| Weapon | Pattern | Plays like |
|---|---|---|
| Falling Stars | Strike on the road | Small stars fall on bodies near the town |
| Bell of the Hold | Nova on the town | The town rings; a pulse hits every body at the wall |
| Soulfire | On kill | A body that dies burning bursts into the bodies around it |

### Catalysts

Quickening Oil (cadence), Twin Casting (count), Wider Wake (area),
Long Burn (duration), Kindled Heart (Arsenal power).

### Evolutions

| Base at V | + Catalyst | Becomes |
|---|---|---|
| Ember Wisps | Twin Casting | **Sunwheel** — suns circle you and hurl fire outward |
| Chain Spark | Quickening Oil | **Stormcrown** — the chain fires on its own clock and never stops jumping |
| Stone Rain | Wider Wake | **Worldbreaker** — boulders crater the ground in a ring |
| Thorn Wake | Long Burn | **Briar Sea** — the thorns stay, and spread |

### Refused, and why

- **Every universal multiplier** ("Kindled Heart for the whole game", Echo Cast on
  everything, Multicast): a number that multiplies every source is the third power
  scale this project has refused a dozen times. Kindled Heart moves the Arsenal
  only.
- **Resource-burning weapons** (Coin Cannon, Blood Engine, Wrath Engine): a weapon
  that eats Gold competes with the wall, and one that eats health or raises wrath
  is a self-damage economy — the failure Megabonk's own patch notes record.
- **Summons that are bodies** (Ghost Knight, Stone Golem, Phantom Archer): a second
  body that walks and is targeted is the party roster §54 cuts; the spirit
  companion is that body already. Weapons here are effects, never actors.
- **Black Hole, Gravity Well, Repulsion Field**: moving bodies off their route is
  the one thing morale's own bound forbids (it may change the shape of a fight,
  never where a body goes).
- **Disaster-linked and wrath-linked weapons**: the earth's wrath is hidden by
  design and must never be a readout; a weapon that grew with it would be one.
- **The Mythic tier** (Tempest Crown, World Engine, Living Fortress): an evolution
  is already the top of a weapon; a tier above it is the next thing to build when
  the first twelve have been played.

## 5. Economy and hordes

The second half of the owner's request is that the road sends **far more bodies**,
that killing them is **how the towers are paid for**, and that the whole road is
tuned to it. Measured on `curve_report`, new account, after the Arsenal landed:

| | Before | After |
|---|---|---|
| Bodies an act (`WAVE_ACT_COUNT_SCALE`) | 1.13 … 3.21 | **1.41, 2.30 … 4.82** (+25% Act I, +50% after) |
| What a body pays (`KILL_RESOURCE_SCALE`, `KILL_ACT_VALUE_SCALE`) | 0.33; 1.0 … 2.20 | **0.264; 1.0, 0.83 … 1.83** - the purse stays where it was, so the extra towers are *earned by killing the extra bodies* |
| Health an act, II on (`WAVE_ACT_HP_SCALE`) | 1.40 … 2.55 | **1.48, 2.31 … 3.05** - Act II held to a 1.36 step from Act I, the rest bought as bodies |
| Co-op bodies a player (`COOP_BODY_SCALE_PER_PLAYER`) | 0.5 | **1.0** - each Warden brings their own Arsenal |
| Co-op income a body (`COOP_KILL_INCOME_SCALE`) | 1.0 (unmodelled) | **0.85**, now modelled |
| Mean pressure, 1 to 4 players | 0.453 … 0.526 | **0.437, 0.458, 0.432, 0.404** (band 0.40–0.64, spread 13%) |
| Act by act | 0.23 … 0.61 | **0.25, 0.22, 0.38 … 0.66** - Act II a little under Act I, where the board arrives; no holiday |
| Arsenal share of the defence | — | **20% in Act I, 43–60% after** |

A campaign is 544 waves rather than 657: the road is the same length, and each
wave is bigger. The act-start purse, ranks and drafts were re-read off the same
report.

## 6. Art

PixelLab's allowance is spent until 2026-10-11, and the production-art gate
refuses a placeholder. So a weapon's card icon is **composed from the game's own
painted spell art** (three meteors in an orbit, lances in a chain), which is new
arrangement of shipped art rather than art drawn in code, and its in-play effects
are the forged VFX sheets, the painted projectile heads and the ink canvases the
towers and spells already use. Bespoke icons are a PixelLab job for October.
