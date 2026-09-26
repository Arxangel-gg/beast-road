# The Warden's disciplines, reworked (proposal, 2026-09-26)

The owner asked for "the perfect skill tree system to do as a full rework that is
perfect for our game", taking inspiration from *Tower of Babel: Survivors of
Chaos* and a thumbs-down Steam review of it. This is the proposal. **Nothing here
is built**, and several parts re-cut decisions this project recorded as LOCKED or
bounded, so they are listed as rulings in section 6.

Sources read for it: the game's 96 Steam announcements from the demo to today
(through Steam's public news API), 917 English Steam reviews (317 negative, 600
positive, through the public review API), the demo video the owner linked, three
build guides, and our own discipline code, data and Mansion screen.

---

## 1. What is wrong with ours now, measured

Seven findings, each from the code or the owner's save rather than from
impression.

1. **Skill points leak.** Points are an account currency (`MetaState.hero_skill_points`)
   and the nodes they buy are run state (`RunState.trained_discipline_nodes`,
   cleared by `reset`). Training decrements the run's copy; the next level-up or
   attribute point calls `_store_hero`, which writes the decremented count to the
   account; the node is then wiped when the run ends. The owner's level-100 account
   has earned 20 points and holds 16.
2. **Seven gates stand in front of one node**: the Mansion built to the node's
   tier this run, the act that opens its slot, the act that opens its discipline,
   a skill point, its Food, depth in its tree, and a cap that grows with level.
   `_training_blocker` exists because the player cannot work out which one is
   stopping them.
3. **A level-100 Warden starts every road as a novice.** The tree is rebuilt from
   scratch each run with Food, beside a hero whose level, attributes, gear and
   ascension all persist. The one layer the owner asked to be "Diablo-like" is the
   one layer that does not carry over.
4. **Many skills are the same skill.** Twenty-three nodes cast a spell, and
   they share nineteen spells between them. Sanguine Guard, Iron Roar and
   Siphoning Veil all cast `ash_veil`; Red Pursuit and Aegis Step both cast
   `rift_step`; Dawn Bell casts Tremor. The three Attack nodes also carry +8%,
   +5% and +4% damage written into `hero.gd` as a `match` on the effect id,
   outside the data. "The skills were all boring" (owner, 2026-09-13) has a
   measurable cause: several are one cast with a different sentence under it.
5. **It is a list, not a tree.** The Mansion shows text rows under three tabs.
   Its discipline filter builds from `Balance.DISCIPLINE_IDS`, which still holds
   three ids, so there is no Arcane filter.
6. **Co-op shares one loadout.** Every discipline effect and every equipped spell
   is read from `RunState`, which is one copy per machine. On the host, a
   partner's spell buttons cast the host's spells (`SpellCaster.spell_in_slot`),
   and the partner's discipline effects are the host's.
7. **Nothing shows what a build does.** There is no damage-by-source readout
   anywhere. The debrief names the blow that killed the Warden and says nothing
   about how the Warden's own damage was split.

And one overlap: the Mansion's three-a-road offers are a second draft beside Road
Cards (three at each crossroad), portents (three at each act end), relics and
tower paths. Two drafts of the same kind of choice, and the one the build
depends on is the random one.

---

## 2. What Tower of Babel teaches

**What it is.** A survivors-like (auto-attack, waves, a timer) with Diablo-style
loot, five heroes, Early Access May 2025, 1.0 in May 2026, 200,000 copies sold,
78% positive overall. Levelling up in a run offers **three random choices** from
a shared pool of skills and stat boosts; Reroll, Bless (a skill appears more
often and stronger) and Ban give some control, three uses of each since 1.8.
Between runs, gold buys small permanent bonuses at the **Altar of Blessings**.

**Hearth of Souls** (update 1.11.0, January 2026) is its skill tree, and the part
the owner pointed at:

- a **different tree per hero**, 80 to 100 nodes each;
- nodes that **change how the basic and special attacks work**, including whole
  alternate forms of them (named in the Skullcrusher reveal), plus stat nodes,
  special effects and new abilities;
- bought with **Souls of the Dead**: 2 for the first clear of each floor, 3 for a
  boss floor, more from sparing a beggar;
- **reset in part or in full, free** up to a point and for gold after it;
- reworked for 1.0 because it leaned on the basic and special attacks and left
  skill-based builds with little to take - nodes that enhance individual skills
  were added.

**What players say**, from 917 reviews. The complaints cluster tightly:

- *the build's core is drawn, not chosen.* Players restart a floor when their
  main skill is not offered in the first few level-ups, and report going ten
  levels without seeing a blessed skill. Items built around a skill are dead
  weight when the skill never appears. The owner's quoted review calls this
  "Blackjack against a cheating AI".
- *meta upgrades are microscopic and expensive*: fractions of a percent of
  crit, one or two percent more chance to be offered a better card, tens of
  thousands of gold a step.
- *progression walled per character* (fixed in 1.5 by making it account-wide).
- *heroes identical beyond two attacks* (the reason Hearth of Souls exists).
- *no information*: dozens of stats with no explanation, passives that raise
  "area" without saying which skills they touch, and no damage report - the
  reviewer the owner quoted wants "a literal spreadsheet of damage done/damage
  taken by source".

The praise clusters too: **legendary affixes that change how a skill behaves**
(doubling a skill's projectiles and scattering where they fall, for one), seeing
gear on the character, and
stacking effects once a build comes together. Hearth of Souls is credited with
giving the heroes identity.

### Adopt, adapt, reject

| From Tower of Babel | Verdict | Why |
|---|---|---|
| A tree that reshapes the basic attack into alternate forms | **Adopt** | The Warden's three-hit chain is the most-used thing in the game; a form that changes it is felt every second. |
| Nodes that enhance one skill (their 1.0 fix) | **Adopt** | Each skill gets its own upgrades, so a skill is a build decision rather than a slot filler. |
| Free reset between runs | **Adopt** | Experimenting is the fun; a tree you are afraid to touch is a tree you never learn. |
| Account-wide growth (their 1.5 fix) | **Already ours** | One Warden per save slot; nothing is per character. |
| Skill-altering legendaries | **Adapt, later** | Their best-loved system. Ours move a `Modifiers` number only; letting one name a skill upgrade is a ruling (section 6, R7). |
| Souls from first floor clears | **Adapt** | Skill points from the first clear of each act on each difficulty, so Nightmare and Hell feed the tree. |
| Bless, Ban, Reroll | **Adapt** | Not needed for the build core, which moves to the tree. Road Cards keep the draft, and could show what is left in the deck. |
| A random level-up pool as the build engine | **Reject** | The single most-cited complaint. Randomness may add to a build, never withhold it. |
| Gold-bought micro stats, "chance for a better card" | **Reject** | Our Quartermaster already refuses gold that buys power, on purpose. |
| Enhancement casinos with "dangerous outcomes" | **Reject** | Our Forge draws its odds before anything is spent. |
| No damage report | **Reject the gap** | Build a ledger (section 3.8). |

---

## 3. The proposal

### 3.1 Principles

1. **The build is chosen, never drawn.** Everything a build rests on is bought in
   the tree. Road Cards, portents and loot add to a build; none of them can
   withhold it.
2. **One currency, one tree, kept.** Skill points are earned by the account and
   spent in a tree that persists. Points are derived, never stored, so they cannot
   leak.
3. **Every node changes what the Warden does, or states exactly what it adds.**
   No two skills cast the same spell, and no rider hides in code.
4. **Depth opens nodes; it grants nothing itself.** Numbers live on nodes, on
   the levelling scale, and `curve_report` models them.
5. **Show the work.** A ledger of damage dealt and taken, by source.
6. **One tree per Warden in co-op.**

### 3.2 Where it lives

The tree belongs to the account (per save slot) and is edited **in the Hold**,
between runs, where the stash, the pen and the stable already live. Reset is
free there, in part or in full.

On the road the tree is fixed. What changes in Preparation, at the Mansion, is
the **loadout**: which learned skill sits in each of the four slots, and which
chain form the Attack slot uses. Moving points in a run is a **retraining** at
the Mansion for Food, at a price that rises each time, which keeps the v4 rule
that respeccing is a Preparation cost and never happens in combat.

### 3.3 Skill points

Available points are always `earned - spent`, computed on demand:

- **From levels**: one on each of levels 2 to 10, then one every two levels -
  54 at level 100;
- **From first clears**: one the first time each act's boss falls on each
  difficulty - 11 acts times 3 tiers, 33;
- **87 at most.** [TUNE]

Front-loading the first ten levels matters because the new XP curve puts level 10
in the middle of Act II; the first hour needs choices in it.

### 3.4 The shape

Four arms around the Warden - Blood, Holy, Berserk, Arcane, the four disciplines
the game already has, with the same names and identities. Each arm has three
rings and a tip, gated by **points spent in that arm**, counted rather than
graphed (a count cannot strand a node, which a drawn graph once did):

| Ring | Opens at | Holds |
|---|---|---|
| I | 0 in this arm | a chain form, a Defense skill, one passive |
| II | 6 in this arm | two Power skills, one passive |
| III | 14 in this arm | the Ultimate, one passive |
| Tip | 22 in this arm | the arm's Oath |

**Every skill is three nodes**: the skill (1 point), its enhancement (1), and one
of two upgrades (1). The two upgrades are exclusive; switching is free in the
Hold. This is the pattern Diablo IV's tree uses, and it is what makes a skill a
decision rather than a line on a card.

**Passives** have up to three ranks, each a stated number.

An arm costs about 30 points to fill and the whole tree about 120, so a Warden at
the cap owns roughly seven tenths of it, and the exclusive upgrades and the single
Oath mean nobody owns every option. [TUNE]

### 3.5 Chain forms

The Attack slot stops being a rider and becomes a **form of the basic combo** -
Tower of Babel's alternate attacks, applied to the three-hit chain:

- **Hemorrhage Edge** (Blood): the finisher opens a bleed. Upgrades: the bleed
  spreads to the next body hit, or the finisher heals by the bleed's size.
- **Consecrated Chain** (Holy): the third hit splashes radiance near defences.
  Upgrades: the splash shields the nearest tower, or it brands what it hits.
- **Cleaving Road** (Berserk): the wide third hit gains force per body struck.
  Upgrades: the finisher shoves, or each body struck shortens the next dash.
- **Spellblade** (Arcane, new): the finisher throws a short bolt and refunds a
  share of mana. Upgrades: the bolt pierces, or a cast right after it costs less.

Their numbers move out of `hero.gd` into data.

### 3.6 Skills: one spell each

The six duplicates get skills of their own (data and effects; each needs an
icon):

| Node | Casts today | Becomes |
|---|---|---|
| Sanguine Guard | `ash_veil` | a blood shell that turns damage into a slow-healing wound |
| Iron Roar | `ash_veil` | a roar that staggers and hardens |
| Siphoning Veil | `ash_veil` | keeps the veil, as the only veil |
| Red Pursuit | `rift_step` | a lunge that strikes through marked prey |
| Aegis Step | `rift_step` | keeps the step, leaving a shield field |
| Dawn Bell | Tremor | a bell toll: stagger ring, then tower haste |

The Augment nodes (Blood Remembers, Unbroken Oath, Break the Host, Quickening)
become upgrades of the skill they already modify.

### 3.7 Oaths

One per arm, at its tip, and **only one sworn at a time** across the tree. An
Oath re-routes a rule, and pays for its boon with a bane, the way portents do. Examples, all [TUNE]:

- **The Red Road** (Blood): health does not regenerate; every Blood hit heals.
- **The Kept Gate** (Holy): wards also shield the nearest tower; damage falls
  away from the roads.
- **No Retreat** (Berserk): the dash becomes a striking charge; no perfect evade.
- **The Deep Well** (Arcane): twice the mana; it refills only on kills.

### 3.8 Tags, synergies and the ledger

**Tags.** Every skill carries tags: Fire, Frost, Earth, Storm, Blood, Radiant,
Mark, Ward, Summon, Road, Finisher, Movement. A passive names the tags it
touches, and the map shows them, which answers the Tower of Babel complaint about
passives that say "area" without saying where. Synergies grow from three pairs
into tag synergies and keep their rule: they change when an effect fires or what
it fires on, never its size.

**The ledger.** Damage dealt by source - each skill, the chain and its finisher,
each tower kind, traps, companions, spirits, the earth - and damage taken by
source, live on the pause menu and per act on the debrief. It is built by
marking the source where a blow is dealt, the way `Enemy.mark_element` already
marks an element, rather than threading a source through the 41 callers of
`take_damage`. Whatever is not attributed shows as "other", and a gate holds
"other" to a small share so the ledger cannot quietly go blind.

### 3.9 The road

- **The Mansion's offers are removed.** The build is chosen in the tree; the
  run's draft is Road Cards.
- **The Mansion's tiers change meaning.** Tier 1 lets the loadout be changed;
  tier 2 opens the Power slot an act early; tier 3 opens the Ultimate an act
  early. That keeps the building a Preparation decision against the towers, and
  gives Food and Stone a reason to go there, without fencing the tree.
- Road Cards stay the run's draft, hand of five. Later they can name tags.

### 3.10 Co-op

Each Warden fights with their own tree. The loadout crosses the wire by node id,
as worn gear kinds already do: validated against this build's content, attributed
by the peer it arrived on, and read per hero rather than from `RunState`.

### 3.11 What does not change

The four disciplines and their names. The four slots, and the acts that open
them. The Arcane opening at Act II. Five attributes, one point a level. Gear on
attribute points. The synergy rule. Road Cards, portents, relics and tower
paths.

---

## 4. Bounds

- **Working rule 7.** The tree is a new save key. Its points come from levels and
  first clears, so it sits on the levelling scale; `curve_report` models the tree
  a Warden is expected to own at each difficulty, the way it now models ascension,
  and a node number it does not model is forbidden.
- **The ceiling.** A full tree's passive numbers together may not exceed a share
  of the levelling scale to be set with the owner. [TUNE]
- **Oaths.** Each trades: a boon paid for by a bane, gated by `curve_report`
  reading the same band sworn and unsworn.

---

## 5. Build plan

**Phase 1, foundation (code, no new art).**

1. Derived points and the `tree` save key; the leak closed by construction.
2. The node model: skill, enhancement, exclusive upgrade, passive rank, chain
   form, Oath; tags; appended enums.
3. The tree screen in the Hold (a node map, four arms around the Warden), and the
   Mansion's loadout and retraining.
4. One tree per Warden in co-op.
5. The ledger.
6. The forty nodes moved into the new shape; the hard-coded multipliers into
   data.

Gates: a tree check (no leak across any sequence of levels, runs and resets;
upgrades exclusive; every node reachable by a walk; every node's effect read by
code), a ledger check, the co-op heroes check, and `curve_report` modelling the
tree.

**Phase 2, content.** The six distinct skills, two upgrades for every skill, four
Oaths, the Spellblade form, about ten tag synergies. Upgrades reuse their skill's
icon with a mark, so the art is roughly seven new icons.

**Phase 3, loot and draft.** Tag-aware Road Cards, and skill-altering legendary
affixes if R7 is approved.

---

## 6. Rulings needed from the owner

| | Decision | Re-cuts |
|---|---|---|
| R1 | The tree persists on the account and is edited in the Hold | v4 §24 and §26 (run-scoped, LOCKED); a new save key under working rule 7 |
| R2 | Skill points also come from first act clears per difficulty | new |
| R3 | Nodes may carry numbers, modelled on the levelling scale | the 2026-09-09 bound "depth buys access, never power" |
| R4 | Oaths re-route a rule with a bane and a boon, one at a time | new |
| R5 | The Mansion's three offers are removed | v4 §26 per-road offers |
| R6 | The Mansion's tiers open slots an act early instead of tree depth | v4 §24 "Mansion tiers reveal deeper rows" |
| R7 | (Phase 3) A legendary affix may grant a skill upgrade | the 2026-09-12 legendary-affix bound |

**Fixed now, without waiting**: the point leak under the current model (points
are recomputed from level each run rather than stored), and the missing Arcane
filter.
