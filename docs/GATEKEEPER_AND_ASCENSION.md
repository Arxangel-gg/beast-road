# Wilderhold - the Gatekeeper ladder and ascension

> Drafted 2026-09-17 against every shipped player-facing string, then
> reviewed adversarially against GDD section 57, act integrity and the
> shipped lore. **Nothing here is built yet and several points need an
> owner ruling - they are listed at the end.**

---

# The Gatekeeper Ladder and the Ascension Scale

Design document. Wilderhold, 2026-09-17. **Second pass — corrected after review.**

Numbers marked **measured** were read off `curve_report` on an empty profile.
Numbers marked **predicted** are arithmetic on those measurements. Numbers
marked **unmodelled** are things `curve_report` does not compute at all, and
saying which is which is most of the value of §10.

---

## 0. The measurements this rests on, and what they do not say

Run on a scratch profile (`APPDATA` pointed at an empty directory, per the
recorded lesson that `curve_report` reads the account):

```
[curve] measured on a NEW account - hero level 1, 2 gear points, 8 towers unlocked
[curve] mean pressure by party size   1:0.479  2:0.518  3:0.544  4:0.563
[curve] mean pressure by act  1:0.23 2:0.21 3:0.29 4:0.30 5:0.40
                              6:0.46 7:0.60 8:0.56 9:0.66 10:0.70
        wave 622: threat 5015, capability 5574, pressure 0.90
```

The same profile with `hero.last_tier` set to `"nightmare"`: mean pressure
1:1.389. 1.389 / 0.479 = 2.900, which is `nightmare.tres`'s `hp_scale` to three
significant figures.

**The first draft read that clean ratio as evidence of linearity and predicted
Hell at 0.479 × 7.4 = 3.545. That is the wrong conclusion and it is the most
dangerous sentence in the first draft.** The ratio is clean because the model
has exactly one input from the tier. `curve_report._row()`:

```gdscript
var hp: float = director._hp_scale(0)
var damage: float = director._damage_scale(0)
var speed: float = director._speed_scale(0)

var threat: float = float(bodies) * hp
```

`damage` and `speed` are computed, carried into the row, printed in the table —
and **never enter `threat`**. Of the three things a campaign tier changes, the
model sees one. Nightmare is 2.9× health, **1.7× incoming damage and 1.08×
speed**, and the pressure column is blind to two of them. 3.545 is not a
prediction about Hell. It is `7.4` with a decimal point moved.

### The four blind spots, stated once

| What | Status | Effect on the reading |
|---|---|---|
| `hp_scale` | modelled | the only tier input the curve sees |
| `damage_scale`, `speed_scale` | **unmodelled** | threat is understated on hard tiers |
| Hero level, gear attribute points | **unmodelled** | capability understated on played accounts |
| Tier `loot_scale` on the purse | **unmodelled** | capability understated on hard tiers |

`MetaState.hero_level` appears in `curve_report.gd` in exactly one place: the
line that prints which account it measured. `_gold_per_body()` reads
`Balance.KILL_RESOURCE_SCALE` and the enemy roster and **does not read
`Modifiers.KILL_RESOURCES`**; `_affordable_dps()` reads `Balance` costs and
does not read `Modifiers.BUILD_COST`. Capability reaches the `Modifiers` table
through exactly two keys, `HERO_DAMAGE` and `TOWER_DAMAGE`.

Two of those errors overstate the gap and two understate it. **The net is
unknown, and no statement of the form "ascension closes N% of Nightmare" is
falsifiable until §10's prerequisites land.** The first draft made that
statement anyway, in bold, as a headline. It is withdrawn.

### What the measurement does say, and it is enough to design against

At wave 622 capability is 5574 and hero DPS is 38.3. **Towers are 99.3% of late
capability in the model.** That number does not depend on any of the four blind
spots. It gives the one structural fact this design is built on:

> **The two scales the game already has are nearly invisible to the one model
> that judges it, and the arenas where they are the whole of the player's power
> are the one place the model refuses to look.** `curve_report` measures waves
> against towers. An arena has no towers in it, so inside one, level and gear
> are 100% of capability.

---

# PART ONE — THE LADDER

## 1. Entry: the Standing Gates

**Mechanism: the rift gate, unchanged.** `RiftGates` digs interactable gates in
the outskirts band on open ground from a stream seeded by the run and the
region, so both machines dig the same ones; `interact` emits
`EventBus.rift_requested`; `Run._on_rift_requested` runs the co-op party vote
through `PartyEvents` and then suspends the battlefield (working rule 8,
untouched) and opens an arena. `RiftGates.dig_at(kind, at)` already exists for a
gate placed by an event rather than scattered.

A trial is that machinery with one more `Kind`:

- `RiftArena.Kind` is `{ RIFT, DUNGEON }` and gains `TRIAL` — **appended, never
  inserted**. It is mapped by number into `PartyEvents.Kind`, which is
  `{ RAID, RIFT, DUNGEON }` and gains `TRIAL` the same way. Content pointing at
  the wrong enum member has shipped twice here (`Role`, `Trigger`).
- `CoopRelay` gains its fact/request numbers **at the end of their enums**, then
  `coop_check._test_every_wire_number_is_its_own` is run.
- `TrialArena extends RiftArena`, the way `RiftArena extends RaidArena`. It
  inherits the freeze, the arena lighting and `CanvasModulate`, the fog, the
  death markers, the hero handling, the cliffs, `can_step` and the co-op vote.
  It overrides the objective, the clock, the ending and the reward.

**Placement is not scattered.** A rift may be missed; a trial is a decision, and
a decision the player never finds is not a decision. The gate is dug in
`Battlefield.refresh_terrain` — the one function everything regional goes
through, and the one that has already silently omitted the gather nodes and the
treeline once — at act start, on the near side of the field, **marked on the
minimap from the first frame and not fogged**, with a banner when the act opens.
It stands for the whole act.

**Exactly one trial gate can exist**, and only if all of:

- `RunState.act` is 3, 5, 7 or 9, and
- that act is the act of **the next rung the account owes on the tier being
  played** — so Act 5's gate does not exist until Act 3's trial is cleared, and
  "each unlocked by clearing the one before" needs no separate check, and
- the act's boss is not on the field. **Correction: the first draft asserted
  `RunState.act_boss_is_out()`. No such method exists.** The reader is
  `BossDirector.boss_is_out()`, on a system node, reached the way
  `hud.gd:2623` reaches it. A trial is refused while the boss is out; the boss
  is the act ending and the trial belongs to the act. Otherwise allowed in
  Preparation and between waves, exactly as a rift is.

**Spent on use.** Win or lose, the gate closes for that run. Losing costs what
losing in any arena costs — a Wound — and the rung stays where it was. A failed
trial never ends a run and never touches the frontier.

### Why this mechanism and not the crossroad card

The crossroad already carries the road choice, the portent and the homecoming
pass. A fourth card there is a trial entered with no travel and no commitment.
The gate on the field costs a walk into the outskirts — the same walk the camps,
the seams and the ponds charge — and it is refusable by ignoring it, which is
the shape of an optional detour this game has three examples of.

---

## 2. The scaling rule, which is the correction that matters most

The first draft scaled the Act 9 fight as `TRIAL_GATEKEEPER_SCALE` × the act's
`BOSS_ACT_SCALE`, and set the rest against the wave tables. **That builds a
difficulty cliff directly into the one door the whole system hangs off, and the
draft's own §10 admits the model cannot see it.**

The arithmetic. Ascension moves towers, the town and the purse. A trial arena
has no towers, no town and no purse. Of the eighteen nodes in §7, exactly one —
`ENEMY_DAMAGE`, worth −5% — does anything inside a trial. So:

> **The ladder is the only content in this game that ascension cannot help
> with, and the ladder is the only source of ascension.**

Scale the trials off the tier's wave tables and a Nightmare Warden must beat
four 2.9×-health, 1.7×-damage arena fights **on level and gear alone** before
earning the first point of the scale that is supposed to make Nightmare
tractable. That is the opposite of the brief.

**So no trial reads the tier's `hp_scale`, `damage_scale` or `BOSS_ACT_SCALE`.
Every trial is measured against the hero who walks in.** Health and damage are
derived from the hero's own sustained output and effective pool at the moment
the gate opens. A level-70 Nightmare Warden in full gear meets a proportionally
harder trial; a level-30 Normal Warden meets a proportionally easier one.

Three things fall out of that and all three are wanted:

- **The cliff cannot form**, because the trial has no term in it that a tier
  multiplies.
- **A gear grind cannot trivialise a rung**, which is the Weighing's whole point
  and is now true of all four.
- **It is tunable without `curve_report`**, which has nothing to say about a
  fight with no waves in it. The trial constants are set by *driving* the arena
  at each tier's `boss_levels`, which is a gate, not a report.

**Consequence: `ENEMY_DAMAGE` is left alone inside trials, and the first draft's
"ascension is set aside too" clause is deleted.** Its stated justification —
"without that clause a rank makes the next rung easier and the ladder is a
snowball that tunes itself" — was false. Seventeen of eighteen nodes are inert
in an arena; the snowball was worth 5%. A special case that protects against
nothing is a special case a gate has to know about for ever. The Weighing still
sets `Modifiers` aside, because that is the trial's name and its subject.

---

## 3. What each trial tests

The Gatekeeper was set at the last step and told to wait. It is not testing
whether the Warden can kill something; every act boss does that.

**Where it stands, corrected.** Shipped fiction: *"The Gatekeeper stands at the
last step, set there and told to wait, and it has waited a very long time."* The
first draft said in §1 that it "cannot leave the summit, so it does not come"
and then in rung 4 that it "is the arena's guardian and is present from the
first second." Those cannot both be true, and the second falsifies a shipped
string.

The resolution costs nothing: **a Standing Gate is one of its doors, and a door
is a door at both ends.** Rungs 1–3, the Gatekeeper answers *through* the gate —
its voice, its terms, and bodies it can send. Rung 4, the Warden steps through,
and the far side of that door is the last step. The Gatekeeper never moved. It
has been there the whole time and the Warden came to it.

| Rung | Act | Name | What it tests | Shape |
|---|---|---|---|---|
| 1 | 3 | **The Watch** | Can you hold ground that is not you? | Defend a static objective, no towers, no exit |
| 2 | 5 | **The Weighing** | Can you fight, without what you were given? | A duel with the whole `Modifiers` table set aside |
| 3 | 7 | **The Breaking** | Can you get through? | A throughput problem against a mending door and a clock |
| 4 | 9 | **The Gatekeeper** | All three, at once, against it | Three phases, one per trial |

The first has no boss, the second has no build, the third has no attacker.

### Rung 1 — Act 3 — THE WATCH

The raid's camp layout, no maze. On the highest plate stands **the mark** — a
stone with its own `Health` and no attacks. Bodies walk in from the rim at eight
points and go for the mark, ignoring the Warden unless the Warden is between
them and it.

- `TRIAL_WATCH_SECONDS = 150`, in three announced steps of rising flow.
- Win: the mark stands when the clock runs out. Lose: the mark falls, or you do.
- The Warden cannot leave. There is no extraction window; that is the point.

**New work, named.** The first draft said "enemies already know how to route at
a town." They know how to route at a town *on the battlefield*, along authored
routes. Inside an arena the steering is `RiftArena.route_hint`, a flow field
from the **hero's** tile. Routing a body at a static objective in an arena is a
second flow field and it is new code, not reuse. The mark's `Health` must also
**not** read `Modifiers.TOWN_MAX_HP` — `town_core.gd:205` does, and a mark that
inherited it would quietly make WARD nodes buy trial health.

**Why it is not a boss fight.** Nothing to kill ends it, the objective is
stationary and is not you, and no amount of damage shortens it. This is the one
fight in the game where the correct play is sometimes to stand still and let a
body walk past you.

### Rung 2 — Act 5 — THE WEIGHING

On entry the trial **sets aside everything the road gave**, for its duration:
socketed relics, boss cores, portents, road cards, legendary affixes, matched-set
tiers, momentum. All of it already passes through one table; this is one flag on
that table. The spell bar is empty. The companion waits outside. No fish, no
Tonic, no draught.

What is kept is the Warden's body: hero level, placed attributes, gear's
*attribute points*, the blade, the dash, the disciplines they trained.

The opponent is a **Gate Sentinel** grown to the Warden's own measure.
`gate_sentinel.tres` ships and needs no edit — `brace_chance = 0.45`, an
authored wind-up (`behaviour_warning 0.75`, `behaviour_seconds 3.0`,
`behaviour_recovery 1.3`), `max_hp = 250`, `knockback_resistance = 0.5`. Its
health and damage are derived per §2 from the hero's own output.

- `TRIAL_WEIGHING_SECONDS = 120`. Win: it falls inside the clock.
- It braces rather than shoves, and its recovery is long. A duel about reading.

**Why it is not a boss fight.** It is the only fight in the game measured
against the hero's floor instead of their build, and the only one a gear grind
cannot shorten.

### Rung 3 — Act 7 — THE BREAKING

`DungeonLayout` cuts the floor — it already does exactly this for a rift, and a
wall is a `Cell.WALL` at the top level, so the terrain, the cliffs and the
stepping rule draw and enforce it unchanged. At the far end of the longest walk,
where the vault would be, stands **a sealed door**: very large health, no
attacks, no movement.

The door is **mended**. Bodies stand in alcoves along the corridors and heal it
on a clock — the mending exists as `_mend_the_company` and as the
`death_mends_allies` mark. Killing a mender slows the mending; menders return.

- `TRIAL_BREAKING_SECONDS = 180`, with the place groaning first
  (`DUNGEON_TREMOR_WARNING` is shipped and is the telegraph rule).
- Win: the door is down inside the clock.

One decision taken repeatedly: burn the door and lose to the mending, or clear
menders and lose to the clock. There is a correct split and it moves as the
clock runs.

**Why it is not a boss fight.** The target never touches you. What kills you is
arithmetic, and the fight is about target priority and route.

### Rung 4 — Act 9 — THE GATEKEEPER

The Warden steps through the Standing Gate and comes out at the last step.
`cinder_titan` stays Act 9's boss; this is a detour off it.

`gatekeeper.tres` needs almost nothing: `phase_thresholds = [0.68, 0.34]` and
the phase names **"It Raises the Chain"** and **"It Sets Down the Chain"**
already ship and already fit. One more name is added.

- **Phase 0 → 0.68 · It Raises the Chain.** The mark from the Watch stands
  behind it, and bodies come for the mark while the Gatekeeper fights you.
- **Phase 1 → 0.34 · It Sets Down the Chain.** The Weighing, mid-fight:
  `Modifiers` goes quiet for the rest of the encounter. Everything you were
  leaning on stops, at the moment you had started leaning on it.
- **Phase 2 · It Closes the Door.** `Health.floor_hp` holds the Gatekeeper at
  34% — it cannot be finished — while a sealed stone behind it feeds it. Break
  the stone. The Breaking, with the thing you were breaking now hitting back.

**Scale, per §2.** Not `BOSS_ACT_SCALE`. The authored `max_hp` is 14,000 and
`BOSS_ACT_SCALE` reaches 12.30; a straight product is a 150,000-HP fight in an
arena with no towers in it. `TRIAL_GATEKEEPER_HP_SHARE` is a multiple of the
hero's measured sustained output over the clock, set by driving the fight at
each tier's `boss_levels`.

**Failure costs a Wound and nothing else.** The rung is not lost, the run
continues, the gate is spent for that run.

---

## 4. What a trial pays

Each of the four rungs pays, once ever per campaign tier:

- **One ascension point** (Part Two). This is the only source of them.
- **The rung**, which opens the next gate on that tier.
- Run-scoped spoils on the same tables a rift already pays from — currency, gear
  at the tier's rarity, Shards. `rift_check` names every key a reward may carry;
  the trial reward is held to that list, so "and a permanent +1" cannot arrive
  without failing a gate.

**No fish, no material, no profession XP, no attribute, no level.**

**Correction: rung 4 does not hand over `core_gatekeeper`.** The first draft
proposed it. `core_gatekeeper.tres` has `source_act = 10`, and
`ContentDB.boss_core_for_act()` matches on `source_act`, and
`boss_director._grant_rewards()` guards with `if not RunState.boss_cores.has(core.id)`.
So a player who took the Act 9 trial would reach the Act 10 boss and **be paid
no boss core at all, silently** — the exact failure that file's own comment
records having already shipped once ("an act whose core had never been authored
paid nothing and said nothing"). If rung 4 is ever to pay a core it needs a core
of its own with its own `source_act`, and that is a content decision, not a
reuse.

---

## 5. Co-op

The party votes exactly as it does for a raid or a rift: the proposer proposes,
the host counts, the field runs on for anybody who stayed, and an absent seat
counts as a pack on the field so a fork waits for the party to be whole.

**The gate that appears is the host's next rung.** A guest standing at the same
rung who enters and is alive at the win takes the rung and the point. A guest at
a different rung takes the spoils and nothing else, **and the gate says so
before anybody presses anything** — "this door is not yours" — rather than
silently paying nothing.

That prevents a rung being carried by a friend, which matters because the rungs
gate a power scale. It is an owner ruling and it is in the risks.

Nothing about a trial's outcome is computed twice: as with a fish and a crop, a
guest asks the host by rung id and the host reads its own tables. Ascension
points are account state, written locally on each machine from the host's word.

---

## 6. The consequence of skipping

**A campaign tier whose Gatekeeper is unbeaten fights it alongside Kharok at the
summit.** Beating it there closes that tier's rung 4 permanently — it does not
come back — but it does **not** pay the three trials' points. Skipping the ladder
is allowed and it is expensive.

**Why it is there at all, corrected for §57 and for shipped fiction.** The first
draft's string was *"we will do this here, with him watching"*, which frames the
Gatekeeper as Kharok's henchman. The Gatekeeper is not part of the Chainbound
Host, is not compelled by the chain, and does not belong to anybody. It is doing
its job: **it refuses passage to someone who came past its doors without
knocking.** It happens to be standing between the Warden and Kharok because
that is where a doorkeeper stands. Kharok's presence is incidental to it, and
the string must say so.

### Why it is harder than two health bars

**1. It imposes an order on a fight that had none.** While the Gatekeeper
stands, `Health.floor_hp` holds Kharok at `SUMMIT_KHAROK_FLOOR = 0.15` — he
cannot be finished. `floor_hp` is `health.gd:55` and is already how the town is
held through a withdrawal, so this is one assignment. The summit stops being
"kill the man" and becomes "break the door, under the man's full pressure,
before the wall goes". A player saving a burst for the last 15% finds it does
nothing.

**2. It owns the ground you have to stand on.** `Enemy.make_camp_mob(home, leash)`
gives a body a home, a leash and no route, so it holds a ring at the gate. Kharok
roams four lanes; the Gatekeeper owns the centre, and the centre is where its
slam lands (`boss_slam_radius = 400`). Fight the mobile one in the open while
breaking the stationary one from inside its own blast.

**3. It spends the resource the summit is short of.** Kharok phases with
`phase_reinforcements_per_lane = 1` across `phase_reinforcement_lanes = 4`; the
Gatekeeper's shipped values are 1 across 2. Both phasing means **six
reinforcement bodies per crossing rather than four**, against a wall that is the
loss condition and that the player has spent ten acts repairing. This is where
the extra difficulty actually lives: not in a health bar, in the town's.

Scaled as an escort rather than a second boss —
`SUMMIT_GATEKEEPER_HP_SHARE = 0.45` of its own authored health at the summit's
scale — because the point is the order, the ground and the lanes, not duration.

**Per difficulty.** A player who ran Normal's ladder and then unlocks Nightmare
meets Nightmare's Gatekeeper at Nightmare's summit until they run Nightmare's
ladder. That is the brief's rule, and it gives Nightmare and Hell their own
reason to walk into the outskirts.

---

# PART TWO — ASCENSION

## 7. First: the name is already taken twice

**Correction, and it is not cosmetic.** This project already has two things
called ascension and the first draft added a third without noticing:

| Symbol | What it is | Where |
|---|---|---|
| `RunState.hero_ascension` | **run-scoped body stat tier**, +1 per act boss | `boss_director.gd:209`, read every frame at `hero.gd:918` |
| `Balance.ASCENSION_STAT_BONUS` | 0.18 — what one of those is worth | `Balance.gd:4650` |
| `MetaState.ascension` | prestige rank, 0–2 | `MetaState.gd:440` |

So §8's central claim in the first draft — *"nothing either scale has ever
touched: the towers, the town, and the purse"* — is argued against a landscape
that already contains a third scale, `hero_ascension`, which does nothing but
touch the Warden's body at 18% a tier. That does not sink the axis argument
(`hero_ascension` is run-scoped, like a relic, and resets), but a design that
did not know it existed has not surveyed the ground it is standing on.

**The tree is named THE GATE'S FAVOUR, and `favour` is its symbol prefix.**
`MetaState.ascension` keeps its name and its meaning as a rank, because it is on
disk, in `Score`, in an achievement and in two screens. A third meaning of
"ascension" in one codebase is a grep that returns three unrelated systems and
a `balance_reach_check` nobody can read.

## 8. The axis rule: why this is a capped scale and not more of the two

Every refusal of a third power scale in this project has been the same sentence:
*a scale nobody is tuning.* The answer has to satisfy that rather than argue
with it.

Hero level grants one attribute point; gear grants attribute points on the same
capped scale. Every one of the five attributes resolves into a number **about
the Warden's body**: damage per swing, health, movement, attack speed, spell
damage, cooldown, mitigation, ward size, the toughness of the spirit standing
where they stand.

Nothing either scale has ever touched: **the towers, the town, and the purse.**

> **The Gate's Favour is the Warden's standing with the road, not their body.**
> Level and gear make the Warden stronger. Favour makes the *defence* stronger —
> the emplacements, the wall, and what the road pays.

That is a different axis, and it is the one that answers Nightmare, because
Nightmare's problem is `hp_scale = 2.9` against a board the purse cannot upgrade
fast enough. It is also — and this is what makes it tunable — **the axis
`curve_report` can be made to measure**, because capability in that model is
99.3% towers.

### And it moves only numbers `Modifiers` already resolves

Every node is one entry in the flat table that relics, boss cores, portents,
road cards, legendary affixes and set tiers all feed. Nothing downstream learns
the Favour exists. Same bound as omens, Road Cards, tower paths, spirit traits
and set tiers.

**No new `Modifiers` key is needed.** All ten keys were verified present in
`Modifiers.gd` with live consumers this session.

---

## 9. Points, ranks and the tree

**Points.** Four per campaign tier — three trials and the Gatekeeper. Three
tiers. **Twelve, and that is the cap.**

**Rank.** `MetaState.ascension` becomes the number of points *earned*, 0 to 12.
`Balance.ASCENSION_MAX` moves from **2 to 12**.

**The tree.** Three branches of six, **eighteen nodes, twelve points**. More
nodes than points on purpose: the cap is on power, and what is left is a build.
One point buys one node outright.

**Depth, counted not graphed.** A node at depth *d* needs *d−1* nodes already
bought **in that branch**. A count cannot author an unreachable node the way a
hand-drawn graph can, and this project lost `call_wolf` to exactly that.

**Respec is free, at the Hold, between runs.** A twelve-point permanent
allocation with no way back is a wiki requirement.

### The eighteen nodes

**WARD — what the road cannot break.**

| # | Node | Effect | Magnitude |
|---|---|---|---|
| 1 | Stonefast | `TOWN_MAX_HP` | +0.06 |
| 2 | Deep Footing | `TOWER_ARMOUR` | +0.10 |
| 3 | Banked Earth | `TOWN_MAX_HP` | +0.06 |
| 4 | Set Against | `ENEMY_DAMAGE` | −0.05 |
| 5 | Hold the Gate | `TOWER_ARMOUR` | +0.10 |
| 6 | The Long Watch | `TOWN_MAX_HP` | +0.08 |

**ARMS — what the defence does.**

| # | Node | Effect | Magnitude |
|---|---|---|---|
| 1 | True Sighting | `TOWER_RANGE` | +0.06 |
| 2 | Weight of Stone | `TOWER_DAMAGE` | +0.08 |
| 3 | Told to Hold | `SLOW_STRENGTH` | +0.10 |
| 4 | Longer Reach | `TOWER_RANGE` | +0.06 |
| 5 | Set the Charge | `TOWER_DAMAGE` | +0.08 |
| 6 | The Door Opens | `TOWER_DAMAGE` | +0.10 |

**LEVY — what the road gives.**

| # | Node | Effect | Magnitude |
|---|---|---|---|
| 1 | Tithe | `KILL_RESOURCES` | +0.08 |
| 2 | Quarried | `BUILD_COST` | −0.06 |
| 3 | Standing Levy | `RESOURCE_RATE` | +0.08 |
| 4 | Cut Stone | `BUILD_COST` | −0.06 |
| 5 | The Road Pays | `KILL_RESOURCES` | +0.10 |
| 6 | Word Ahead | `WAVE_FORESIGHT` | +1.0 |

`WAVE_FORESIGHT` is a **counted key** — `RunState` rounds it and `Tower` reads
`chain_targets` with `int()`. `COUNTED_KEYS` applies: a whole number, or the
node charges a point and hands out nothing.

**Maximum reachable `TOWER_DAMAGE` is +26%**, costing all six ARMS nodes — half
the cap.

**Correction to the first draft's visibility claim.** It said "four of the six
ARMS nodes and five of the six WARD nodes are invisible to `curve_report`". The
true figure is worse and is worth stating exactly, because §11 depends on it:
capability reads the `Modifiers` table through **two keys only**, `HERO_DAMAGE`
and `TOWER_DAMAGE`. So **three of eighteen nodes are visible to the model as it
stands today** — the three `TOWER_DAMAGE` nodes. `TOWER_RANGE`, `TOWER_ARMOUR`,
`SLOW_STRENGTH`, `TOWN_MAX_HP`, `ENEMY_DAMAGE` and `WAVE_FORESIGHT` are all
survivability or information, and the whole LEVY branch reaches the purse
through `_gold_per_body()` and `_affordable_dps()`, **neither of which reads
`Modifiers` at all**.

---

## 10. What persists

Working rule 7, stated precisely. **`SAVE_VERSION` stays at 7**; all entries are
additive, and a save written before this reads back as a new account.

**Already persists, cap changes only:**

- `MetaState.ascension: int` — 0 to `Balance.ASCENSION_MAX`, now 12.

**Added:**

- `MetaState.gatekeeper: Dictionary` — `{tier_id: rung}`, rung 0–4. Only ids
  `ContentDB.tier(id)` answers are read or written; a malformed row is dropped
  rather than trusted, the way the pen's rows are. This is a run statistic in
  kind — which rungs are done — and rule 7 already sanctions run statistics.
- `MetaState.favour_spent: Dictionary` — `{node_id: 1}`. Only ids
  `ContentDB.favour_nodes` answers are read. The sum may never exceed
  `ascension`; a save claiming more is truncated deterministically by node id
  order rather than trusted.

**Both live in the `hero` block, and `balance_test`'s guard must name them.**
`balance_test.gd:1320` guards the hero block against exactly
`["level", "xp", "attributes", "attribute_points", "skill_points",
"tier_cleared", "last_tier", "story_seen", "ascension"]`, and its comment says
the list is *about power, not tidiness*. `favour_spent` **is** power and it
belongs there with that argument written beside it, not slipped in as
housekeeping.

**Grandfathering, which the first draft did not address at all.**
`MetaState.gd:1148` reads `ascension = clampi(int(hero.get("ascension", 0)), 0,
Balance.ASCENSION_MAX)`. Raising the cap to 12 means a player who is rank 2
today keeps 2 — and with `favour_spent` empty they hold **two free Favour points
having never touched a trial**, plus an empty `gatekeeper` dictionary saying
they owe rung 1 on every tier. That is a migration decision and it is in the
risks.

**Nothing else.** No currency, no XP, no level, no attribute, no gear, no relic,
no tower level.

**And any new `stat()` key must land in two places.** `MetaState.gd:596` lists
the stat keys and `guide_check.gd:23` keeps a **mirror** of them with the
comment "Keep the two together" — a gate that refuses an achievement naming a
key the reader does not answer. `stat("gatekeeper_rungs")` is derived from
`gatekeeper` rather than stored, and it must be added to both lists or the gate
refuses it. The first draft named neither.

---

## 11. How Nightmare and Hell extend it

**Points, not nodes.** Each tier's ladder grants four more points. The tree
stays at eighteen.

**This is a re-cut of the brief and it is flagged as one.** The brief says
Nightmare and Hell "extend the ascension tree". This proposes they extend how
far up it a player reaches. The argument: more *nodes* at higher tiers is a
power scale that exists only for players who have already cleared Hell, which is
precisely a scale nobody can tune against. But the brief said tree and this says
points, so it is an owner question, not a settled matter. It is in the risks.

At twelve points a player buys twelve of eighteen. **Nobody ever buys the whole
tree**, so the endpoint is a build rather than a fixed loadout.

Node magnitudes are **flat across tiers**. Weighting by difficulty was rejected:
it makes the model harder to read and the player's arithmetic opaque.

---

## 12. Tuning

### Five prerequisites, none of them the Favour's fault

These are pre-existing and must land **before** the Favour is tuned, or a third
scale will be blamed for a gap the first two were meant to close. The first
draft listed three and missed two.

1. **`--tier=<id>`.** The machinery is there — `WaveDirector._hp_scale` reads
   `RunState.tier()`, `RunState.reset()` takes it from
   `MetaState.last_tier_id` — and only the flag is missing. Today the only way
   to measure Nightmare is to hand-edit a save, which is what was done.
2. **`damage_scale` and `speed_scale` in `threat`.** *(new)* Both are already
   computed in `_row()` and neither enters the formula. Until they do, the model
   understates every hard tier by everything except its health.
3. **The tier's `loot_scale` on the purse.** `Enemy._drop_loot` and
   `crate_value()` both multiply by it; `_gold_per_body()` does not know.
4. **Hero level and gear attribute points in `_hero_dps()`.** The model prices
   the hero at a flat 38.3 DPS at level 1 and at level 100, so **neither capped
   scale the game has appears in the curve at all.**
5. **`Modifiers.KILL_RESOURCES` and `BUILD_COST` in the purse model.** *(new)*
   `_gold_per_body()` reads `Balance.KILL_RESOURCE_SCALE` and the roster;
   `_affordable_dps()` reads `Balance` costs. Neither touches `Modifiers`. So
   the entire LEVY branch is invisible to the model **and so is every relic,
   portent and road card that has ever moved those two keys.** This is a
   pre-existing hole in the curve, found while checking the first draft's ×1.15
   estimate, and it is worth its own commit regardless of this design.

### The flag

```
--favour=<n>         # allocate n points, best-first down one branch order
--favour=<id,id,…>   # or an explicit allocation
```

Same shape `--companion` already has.

### The bands

Measured today, model blind to four of the five things above:

| Tier | Rank | Mean pressure |
|---|---|---|
| Normal | 0 | **0.479** (measured), band 0.44–0.58, PASS |
| Nightmare | 0 | **1.389** (measured, health only) |
| Hell | 0 | **not measured, and not predicted** |

**Hell is left blank on purpose.** The first draft printed 3.545. That number is
`0.479 × hell.hp_scale` and it asserts a linearity the model cannot support,
since `hell.tres` also carries `damage_scale = 2.8` and `speed_scale = 1.15`,
neither of which the pressure column reads. Writing a number there that nobody
has run is how a band gets tuned against a game that does not exist.

Proposed bands once the five prerequisites land, held as constants in
`curve_report` beside `PARTY_PRESSURE_FLOOR`/`_CEILING` — **not as prose in
CLAUDE.md**, which is the mistake already recorded once, when the band moved in
that file and the two constants in the tool were left behind. **All six rows
below are placeholders to be re-derived after prerequisite 2 lands**, because
adding damage and speed to threat moves every one of them:

| Tier | Rank | Hero | Band |
|---|---|---|---|
| Normal | 0 | fresh | **0.44 – 0.58** (unchanged) |
| Normal | 12 | fresh | **floor 0.32, no ceiling** |
| Nightmare | 0 | tier-expected (lv 45–70) | re-derive |
| Nightmare | 8 | tier-expected | re-derive |
| Hell | 8 | tier-expected (lv 80–94) | re-derive |
| Hell | 12 | tier-expected | re-derive |

**The hard bound, and the one that makes this a capped scale:**

```
FAVOUR_NORMAL_FLOOR = 0.32
```

> No allocation of Favour points may take Normal's modelled mean pressure below
> 0.32.

Stated as a **floor on the measured outcome**, not as a ceiling on node
magnitudes, so the tree can be re-authored without re-deriving the bound and the
gate drives the real model rather than reading a constant.

**And the first draft's prediction of that outcome is withdrawn.** It computed
capability ×1.45 from "a full ARMS branch is ×1.26 and the LEVY spend is ×1.15",
and then read 0.479 / 1.42 ≈ 0.337 — comfortably above the floor. Per §9, the
LEVY branch reaches the model through nothing at all today, and it will only do
so once prerequisite 5 lands. **The ×1.15 was an estimate of a path that does
not exist.** The visible figure today is ×1.26 from ARMS alone, giving
0.479 / 1.26 ≈ **0.380**. The true number is somewhere below that and above the
floor, and *nobody knows where* until 5 lands. The tree's magnitudes are
provisional until then and the gate, not the arithmetic, decides them.

### "A player must be able to clear every act without ascending"

A mean cannot express that — a healthy mean hides a bad curve shape, which this
campaign paid for once when it peaked in Act 3 and coasted. The gate is **per
act**:

```
NIGHTMARE_ACT_CEILING = 0.95
HELL_ACT_CEILING      = 1.25
```

Measured today, Nightmare at rank 0 with a fresh hero breaks that in acts 5
through 10 — expected, because a fresh hero has no business on Nightmare and the
model cannot see the hero a Nightmare player actually brings. **This is the
number that says whether prerequisite 4 landed.** If a tier-expected Nightmare
hero still reads above 0.95 in six acts with level and gear modelled, then
Nightmare is not clearable without the Favour and either the tier table or the
two existing scales need work — not the Favour.

### The score interaction, which must move in the same change

`score.gd:77` reads `ASCENSION_SCORE_BONUS = 0.1` per rank off
`summary["ascension"]`, which `GameDirector.gd:470` fills from
`MetaState.ascension`. At the old cap of 2 that is +20%; at 12 it becomes
**+120%**, silently re-sorting every leaderboard. Set
`ASCENSION_SCORE_BONUS = 0.02` — a top bonus of +24%.

`MetaState.warden_title()` indexes `ASCENSION_TITLES` by `ascension` and clamps
to `size() - 1`. With rank 0–12 and three titles, **everyone at rank 2 and above
reads "Gatekeeper's Warden"**. Index by **ladders completed** (0–3) instead, and
author four titles.

---

## 13. Constants

```gdscript
# --- The Gatekeeper ladder -----------------------------------------------
const GATEKEEPER_TRIAL_ACTS: Array[int] = [3, 5, 7, 9]
const GATEKEEPER_RUNGS: int = 4

const TRIAL_WATCH_SECONDS: float = 150.0
const TRIAL_WATCH_SPAWN_INTERVAL: Array[float] = [2.4, 1.8, 1.2]  # three steps
# Every figure below is a multiple of what the HERO brings, never of a tier's
# wave table. See section 2: a trial scaled off `hp_scale` builds a cliff into
# the one door the Favour is earned through.
const TRIAL_MARK_HP_SHARE: float = 12.0       # x the hero's own effective pool
const TRIAL_BODY_HP_SHARE: float = 0.45       # x hero DPS x seconds-to-kill
const TRIAL_BODY_DAMAGE_SHARE: float = 0.06   # x the hero's own pool

const TRIAL_WEIGHING_SECONDS: float = 120.0
const TRIAL_SENTINEL_HP_SHARE: float = 9.0    # x measured hero DPS x seconds

const TRIAL_BREAKING_SECONDS: float = 180.0
const TRIAL_DOOR_HP_SHARE: float = 22.0       # x measured hero DPS x seconds
const TRIAL_DOOR_MEND_PER_SECOND: float = 0.018   # share of the door, per mender
const TRIAL_MENDERS: int = 4
const TRIAL_MENDER_RETURN: float = 14.0

const TRIAL_GATEKEEPER_HP_SHARE: float = 30.0 # x measured hero DPS x seconds

# --- The summit escort ---------------------------------------------------
const SUMMIT_KHAROK_FLOOR: float = 0.15
const SUMMIT_GATEKEEPER_HP_SHARE: float = 0.45
const SUMMIT_GATEKEEPER_LEASH: float = 420.0

# --- The Gate's Favour ---------------------------------------------------
# NOT to be confused with `RunState.hero_ascension` (a run-scoped body stat
# tier, +1 an act boss, worth ASCENSION_STAT_BONUS each) or with
# `MetaState.ascension` (the rank on disk). This is the between-run tree.
const ASCENSION_MAX: int = 12                     # was 2
const FAVOUR_POINTS_PER_TIER: int = 4
const ASCENSION_SCORE_BONUS: float = 0.02         # was 0.1 - or the board re-sorts
const ASCENSION_TITLES: Array[String] = [
    "Warden", "Ascended Warden", "Gatekeeper's Warden", "Keeper of the Last Step",
]                                                 # indexed by ladders completed
const FAVOUR_NORMAL_FLOOR: float = 0.32           # the cap, as an outcome

# --- Bands (in curve_report, beside PARTY_PRESSURE_FLOOR) ----------------
const NIGHTMARE_ACT_CEILING: float = 0.95
const HELL_ACT_CEILING: float = 1.25
```

---

## 14. Gates

`gatekeeper_check` and `favour_check`. Every one has a precedent in something
this project has already shipped wrong.

**The Favour:**

1. Every node names a key in `Modifiers.keys_in_use()` — the misspelt-effect-key
   failure, four times over.
2. No fraction on a counted key (`WAVE_FORESIGHT`).
3. **Every node is reachable** within 12 points under the branch-depth rule —
   *walked*, not counted. `call_wolf` was unreachable once.
4. Allocation ≤ `ascension`; a save claiming more truncates rather than grants.
5. A fresh account reads rank 0, empty allocation, and is offered only rung 1.
6. **A grandfathered save** — `{"ascension": 2}` with no `gatekeeper` and no
   `favour_spent` — loads to whatever §15.1's ruling decides, driven through the
   real load path. `attribute_check` proves a four-entry hero the same way.
7. **The Normal floor**: drive `curve_report`'s model with a full allocation and
   refuse a mean below `FAVOUR_NORMAL_FLOOR`. Drive the model, do not sum the
   constants — two models of one thing is the fault this project keeps paying
   for.
8. A fully-favoured hero's *attributes* are exactly what they were — the
   Angler's bound, in the shape `gathering_check` already uses.
9. Save keys: `balance_test`'s hero-block guard names `gatekeeper` and
   `favour_spent` and nothing else.
10. `stat("gatekeeper_rungs")` is answered by `MetaState.stat` **and** present in
    `guide_check.STATS`. The mirror's own comment says keep the two together.

**The ladder:**

11. Rung *N+1*'s gate never appears before rung *N* is cleared — **walked over 24
    fixed seeds**, not sampled from `RunState.reset()`. A guarantee is a property
    of every road or it is not a guarantee; this project has shipped four
    coin-toss gates.
12. A trial gate is refused while the act's boss is out, asked through
    `BossDirector.boss_is_out()`.
13. A lost trial costs a Wound and does not end the run, lose the frontier or
    move the rung. Driven through the real death path.
14. `Modifiers` reads **zero** inside the Weighing and inside phase 2 of the Act
    9 fight — measured by reading a number back off a hero, never by reading a
    flag.
15. **No trial's difficulty moves when the tier changes.** Build an identical
    hero, open the same trial on Normal and on Hell, and read the mark's health,
    the sentinel's health and the body damage back. They must be equal. This is
    §2's rule and it is the one that prevents the cliff; plant the fault by
    multiplying by `hp_scale` and the gate must name it.
16. **The mark does not read `Modifiers.TOWN_MAX_HP`.** Allocate the full WARD
    branch and confirm the mark's health is unchanged.
17. The Act 9 Gatekeeper is felled at each tier's expected level inside its clock
    — *driven*, with a hero built to `boss_levels`, not asserted.
18. Summit: rung < 4 spawns the escort and rung 4 does not; Kharok's floor holds
    while it stands and releases when it dies; the escort never leaves its leash;
    killing it sets that tier's rung to 4 and grants **no** points.
19. **The Act 10 boss still pays a boss core** after every rung has been cleared.
    This is the `core_gatekeeper` failure of §4 held shut.
20. Wire numbers: `coop_check._test_every_wire_number_is_its_own` after the enums
    grow.
21. Every trial's player-facing string passes `copy_check` — on **both** the
    guard and release bars, per §57.

**Validate each gate by planting the fault**, and a planted fault must *remove*
the correct behaviour rather than add a wrong one beside it.

---

## 15. Player-facing strings

In data, per working rule 9. The Gatekeeper is **"it"**, per shipped fiction.
Kharok is "he".

**§57 note, and it is the reason two lines below were rewritten.** Nothing here
describes anyone as owned, worked, serving or belonging to anyone. The Host is
compelled by the chain. The Gatekeeper is **not** part of the Host, is not
chain-bound, and is not Kharok's: it was *told to wait* by someone the strings
deliberately do not name, and it is still waiting because nobody came back. The
shipped `gatekeeper.tres` description already says exactly this — *"Set at the
last step and told to wait. Nobody has come back to relieve it."* — so "told to
wait" and "the only order I was ever given" are shipped vocabulary and safe.
What is **not** safe is any line implying it fights *for* Kharok, because an
unexplained "it fights for him" reads as "it belongs to him". The summit line
was rewritten for exactly that.

**The Standing Gate, on approach (Act 3):**
> A door stands in the grass with nothing on either side of it. It has been
> standing a long time.

**Rung 1 — The Watch.**
> I was set at a step and told to wait. I am still waiting. Wait with me, and I
> will know something about you.

> THE WATCH — the mark must be standing when the light goes.

Win: *"You did not move. Good. There is another door."*
Loss: *"You moved."*

**Rung 2 — The Weighing.**
> Everything on you was handed to you by the road. Put it down at the door. Come
> in as whatever is left.

Win: *"That was you. I wanted to see it."*
Loss: *"You were the things you were carrying."*

**Rung 3 — The Breaking.**
> There is a door at the top of the world that has never opened. If you cannot
> open mine, you will not open that one.

Win: *"It opened. Nothing has opened it before."*
Loss: *"It held. It was always going to hold. I wanted to see how you argued
with it."*

**Rung 4 — The Gatekeeper.** *(the Warden steps through, and the far side is
the last step)*
> You held. You came as yourself. You opened a door. There is one thing left and
> it is me. I was told to wait. Nobody said anything about what to do with
> someone worth letting through.

Win:
> Go on, then. I will keep waiting. It is the only order I was ever given, and
> the beacon was never mine to light.

Loss: *"Not yet. Come back up the road."*

**The summit escort (rung < 4).** *Rewritten: the first draft's "with him
watching" made it Kharok's second. It is not his and it is not the Host's. It is
doing its job.*
> You came past my doors without knocking. That is not how anyone gets through.
> What he is doing here is his business. This part is mine.

**The Hold, the Favour screen:**
> THE GATE'S FAVOUR
>
> What the Gatekeeper weighed was not your arm. It was whether the road should
> answer when you ask it to. It does now — a little, and only as far as a door
> can vouch for anyone.

---

## 16. What this touches that already ships

| Thing | Change |
|---|---|
| `Balance.ASCENSION_MAX` | 2 → 12 |
| `Balance.ASCENSION_SCORE_BONUS` | 0.1 → 0.02, or the board re-sorts |
| `Balance.ASCENSION_TITLES` | 4 entries, indexed by ladders completed |
| `MetaState.warden_title()` | index by ladders, not by rank |
| `MetaState.ascend()` | called by a trial, not by the summit |
| `MetaState.stat` + `guide_check.STATS` | **both** gain `gatekeeper_rungs` |
| `MetaState._read_hero` | grandfathering ruling (§15.1) |
| `balance_test` hero-block guard | `gatekeeper`, `favour_spent`, with the power argument |
| `results_screen._offer_ascension` | **removed.** Points come from trials |
| `achievements/ascended.tres` | **new work.** "Through the Gate / Ascend once", threshold 1.0, now fires on clearing Act 3's Watch. Numerically fine, **copy is wrong.** Re-author |
| `hub_screen.RANK_TINTS` | sized for 13, or indexed by ladders |
| `hub_screen.gd:241` | **player-facing.** "Ascended %d of %d times" is wrong under points. Re-author |
| **A Favour tree screen at the Hold** | **NEW SCREEN.** Does not exist. `HubScreen.adopt` gains a door |
| `RiftArena.Kind`, `PartyEvents.Kind`, `CoopRelay` enums | appended only |
| `Battlefield.refresh_terrain` | digs the trial gate — the one regional list |
| `curve_report` | five prerequisites in §12, plus `--tier=` and `--favour=` |
| `V4_CONFORMANCE` | the ascension row currently reads "prestige only" |

**New art, named rather than assumed.** The first draft implied none. Three
props do not exist: the **Standing Gate** (a door in open grass, a field prop
and a minimap icon), **the mark** (a standing stone with a health bar — the
vault or town core may be restyled), and **the sealed door** at the end of the
Breaking's corridor. All three are objects at the perspective rule — front-on,
slight top-down, flat base, never isometric. Manifest rows and placeholders in
the same change, per §4.

**New code, named rather than assumed.** A second flow field in `RiftArena` that
steers bodies at a static objective rather than at the hero. `route_hint` is
built from the hero's tile; the Watch needs one from the mark's.

---

## 17. Open rulings

See the risks list.


---

## Decisions taken in this draft

- Entry reuses RiftGates + RiftArena: TrialArena extends RiftArena, Kind.TRIAL appended to both RiftArena.Kind {RIFT, DUNGEON} and PartyEvents.Kind {RAID, RIFT, DUNGEON}, entered with `interact`, freezing the field through the existing path. Verified both enums; append only.
- CORRECTED: no trial reads the tier's hp_scale, damage_scale or BOSS_ACT_SCALE. Every trial is sized against the hero who walks in. The first draft scaled the Act 9 fight off BOSS_ACT_SCALE, which builds a difficulty cliff into the only door the scale is earned through — ascension moves towers/town/purse, an arena has none of the three, so 17 of 18 nodes are inert inside a trial and a Nightmare Warden would face 2.9x/1.7x arenas on level and gear alone.
- CORRECTED: the 'ascension is set aside too' clause is deleted. Its justification (a snowball that tunes itself) was false — only ENEMY_DAMAGE among the eighteen nodes does anything in an arena, worth -5%. The Weighing still sets Modifiers aside, because that is its subject.
- CORRECTED: the Gatekeeper never leaves the last step. The first draft said it 'cannot leave the summit' in one section and was 'the arena's guardian, present from the first second' in another — self-contradictory and falsifying a shipped string. Rungs 1-3 it answers through the door; rung 4 the Warden steps through and the far side is the last step.
- CORRECTED: rung 4 does NOT pay core_gatekeeper. Verified core_gatekeeper.tres has source_act = 10 and boss_director guards with `not RunState.boss_cores.has(core.id)` — so paying it at Act 9 makes the Act 10 boss pay no core at all, silently. That is the exact failure boss_director's own comment records having shipped once.
- CORRECTED: the tree is named THE GATE'S FAVOUR, prefix `favour`. Verified the codebase already has two ascensions — RunState.hero_ascension (run-scoped body stat tier, +1 an act boss, ASCENSION_STAT_BONUS 0.18, read at hero.gd:918) and MetaState.ascension (prestige rank). A third meaning is a grep that returns three unrelated systems.
- CORRECTED: Hell is left unmeasured and unpredicted. The first draft's 3.545 was 0.479 x hell.hp_scale, asserting a linearity the model cannot support — verified curve_report._row computes `damage` and `speed` and then sets `threat = bodies * hp`, so two of the three things a tier changes never enter the pressure column.
- CORRECTED: five tuning prerequisites, not three. Added (2) damage_scale and speed_scale into threat, and (5) Modifiers.KILL_RESOURCES and BUILD_COST into the purse model — verified _gold_per_body reads Balance.KILL_RESOURCE_SCALE and the roster, and _affordable_dps reads Balance costs; neither touches Modifiers, so the whole LEVY branch and every relic/portent/card on those keys is invisible to the curve.
- CORRECTED: the predicted x1.45 capability and the 0.337 outcome are withdrawn. The LEVY half rested on a model path that does not exist. Visible today is x1.26 from the three TOWER_DAMAGE nodes alone, giving ~0.380; the true figure is unknown until prerequisite 5 lands, and the gate rather than the arithmetic sets the magnitudes.
- Three trials test three competences: hold ground that is not you (Watch), fight with Modifiers set aside (Weighing), break a mended door against a clock (Breaking). None is a boss fight. Act 9 runs all three as phases, reusing the shipped phase_thresholds [0.68, 0.34] and both shipped phase names.
- The Favour is the Warden's standing with the road, not their body: towers, town and purse — the three things neither hero level nor gear has ever touched. Every node is one entry in the existing Modifiers table; all ten keys verified present with live consumers.
- Twelve points (4 per tier), eighteen nodes in three branches of six, one point per node, branch-depth gating counted rather than graphed, free respec at the Hold. Nobody buys the whole tree.
- The cap is a measured outcome, not a sum of magnitudes: FAVOUR_NORMAL_FLOOR = 0.32, driven through the real model.
- Persistence adds two additive keys in the hero block — MetaState.gatekeeper {tier_id: rung} and MetaState.favour_spent {node_id: 1} — plus the cap change. SAVE_VERSION stays at 7. balance_test's hero-block guard must name both, and favour_spent must be argued as power rather than slipped in as housekeeping.
- Any new stat key lands in BOTH MetaState.gd:596 and guide_check.STATS — verified the mirror exists with the comment 'Keep the two together'.
- The summit escort is harder than two health bars by three shipped mechanisms: Health.floor_hp (verified at health.gd:55) holds Kharok at 15% while it stands, make_camp_mob leashes it to the centre you must enter, and both bosses phasing sends 6 reinforcement bodies per crossing instead of 4.
- The escort's framing is corrected for §57: it is not Kharok's, not chain-bound and not part of the Host. It refuses passage to someone who came past its doors without knocking. The first draft's 'with him watching' made it his second and was rewritten.
- ASCENSION_SCORE_BONUS drops 0.1 -> 0.02 in the same change (verified score.gd:77 reads summary['ascension'] filled from GameDirector.gd:470), and warden_title() is indexed by ladders completed rather than rank — verified MetaState.gd:1368 clamps to size()-1, so at a 12 cap every rank above 2 reads the same title.
- New art and new code are named rather than assumed: three props (Standing Gate, the mark, the sealed door) with manifest rows and placeholders, and a second flow field in RiftArena to steer bodies at a static objective — route_hint is built from the hero's tile, not an objective's.
- RunState.act_boss_is_out() does not exist; the reader is BossDirector.boss_is_out().

## Open - these need the owner

1. GRANDFATHERING, and the first draft did not address it at all. MetaState.gd:1148 clamps `ascension` to ASCENSION_MAX on load, so raising the cap to 12 leaves a player who is rank 2 today holding two Favour points having never touched a trial, with an empty `gatekeeper` dictionary saying they owe rung 1 on every tier. Should an existing rank be converted to Favour points, zeroed with the rank kept as a title, or zeroed outright with a line explaining why? This needs an owner ruling before any code, and it is the one decision here that a player will notice on their first launch after the patch.
2. Does the brief's 'Nightmare and Hell each extend the ascension tree' mean more POINTS (this design) or more NODES (the words)? This design gives four more points per tier and keeps eighteen nodes, on the grounds that nodes existing only for players who have cleared Hell are a scale nobody can tune against. That is a re-cut of a written instruction and it is the owner's call, not mine.
3. The brief asks that ascension 'empower significantly' and make Nightmare tractable after a gear grind. This design cannot yet say whether it does. Verified: curve_report computes `damage` and `speed` in _row() and then sets `threat = bodies * hp`, so Nightmare's 1.7x damage and 1.08x speed are invisible; _hero_dps() is flat from level 1 to 100; _gold_per_body() and _affordable_dps() never read Modifiers, so the whole LEVY branch and every relic, portent and card on KILL_RESOURCES or BUILD_COST is invisible too. Two errors overstate the gap and two understate it. Until the five prerequisites in section 12 land, any percentage figure about Nightmare is unfalsifiable — the first draft printed one in bold and it is withdrawn.
4. Is the Act 10 boss becoming Kharok acceptable given banked expeditions? Verified last_terrace.tres has boss_id = 'gatekeeper' and FINAL_ASCENT_ACT = ACT_COUNT + 1 is where chainmaker is fought. Changing a shipped act's boss is not a renumbering and breaks no save schema, but a player with an Act 10 expedition banked today will resume it and meet a different boss than the one they walked away from. Whoever resolves it must also move balance_test._test_final_ascent, the milestone cinematics, results_screen's is_final_ascent() gate and core_gatekeeper.tres (source_act = 10). This design works either way but cannot land before that is settled.
5. Who set the Gatekeeper there, and is it chain-bound? Shipped fiction does not say, and the strings in section 15 deliberately keep both readings open. This matters for §57 more than anything else in the document: 'told to wait' is shipped vocabulary and safe, 'made to serve' or anything implying it is Kharok's is not. The forwarded story document proposed it was Kharok's closest companion chained into waiting — that is an owner canon decision and it changes the tone of every line in section 15, and it is the single sentence in this whole design most likely to fail a human §57 read.
6. Co-op rung attribution is an owner ruling, not mine. Proposed: the host's next rung gates which door appears, guests at the same rung advance, guests at a different rung take spoils only and are told so before they press anything. The alternative — everyone present advances — makes the ladder farmable by pairing with an advanced player and undermines the gate on a power scale.
7. Should killing the escort at the summit pay any Favour point? Proposed: no. It closes that tier's rung permanently and pays nothing, so the ladder stays the only route to the scale. If it paid even one point, skipping the ladder becomes a viable route to the scale and the trials become optional content that gates optional content.
8. Should Normal be re-held to a ceiling at rank > 0? Proposed: no ceiling, floor 0.32. A fully-favoured Warden replaying Normal is supposed to feel it. But that means Normal has no upper bound at all once a player has ascended, and the pressure band stops describing the game most players are in.
9. Every trial number in section 13 is a starting value that must be set by DRIVING the arena at each tier's boss_levels, never derived from a wave table. curve_report has nothing to say about a fight with no towers in it, so these are the least-evidenced numbers in the document and TRIAL_GATEKEEPER_HP_SHARE is the most speculative of them.
10. Three props do not exist and are new art, not reuse: the Standing Gate (a door in open grass, plus a minimap icon), the mark (a standing stone with a health bar), and the sealed door at the end of the Breaking. A second flow field in RiftArena is new code — route_hint steers from the hero's tile and the Watch needs one from the mark's. The first draft implied all of this was reuse.
11. A Favour tree screen at the Hold does not exist. The first draft wrote its copy and never named it as new work. HubScreen.adopt gains a door and the screen itself is real UI, on the phone-landscape shapes layout_check walks.
12. achievements/ascended.tres reads stat = 'ascension', threshold 1.0, display 'Through the Gate', description 'Ascend once'. The first draft said 'threshold 1.0 still reads correctly'. It reads correctly as a number and means something entirely different to a player: it now fires on clearing Act 3's Watch, which is not going through any gate. Re-author the copy. The same applies to hub_screen.gd:241, 'Ascended %d of %d times', which is a shipped player-facing string that is wrong under a points model and appeared in no table in the first draft.
13. RiftArena.Kind, PartyEvents.Kind and the CoopRelay enums all grow. Append only, and run coop_check._test_every_wire_number_is_its_own: eight wire numbers were shared by two names once and a guest saw no weather at all for weeks, with nothing erroring.
14. copy_check must run on both the guard and release bars for these strings. A human still has to read section 15, because the gate catches vocabulary and not framing — which is exactly how 'compelled workers to maintain the anchors' passed every vocabulary check in the refused story document.
