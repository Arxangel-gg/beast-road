# Untitled Tower-Defense Roguelite — Game Design Document

## Core Concept

A 2D roguelite tower-defense hybrid. A city is built on the back of a giant,
mysterious walking monster crossing dangerous, branching terrain across three
acts. Genre fusion: **Travian** (city building) + **Darkest Dungeon**
(single-hero identity, wounds) + **Slay the Spire** (branching runs,
deckbuilding-style choices).

---

## The Four Scopes

### 1. City (inner scope)

- **Buildings:**
  - Town Hall — houses relics
  - Resource building — wood, stone, food
  - Scavenging building — slaved war chiefs work here between runs
  - Hero building — spells and hero upgrades
  - Tower blueprint building
  - Relic synergy altar — combine relics into sets for bonus effects
- Town Hall relic slots expand via Town Hall upgrades; only socketed relics
  grant buffs.
- Upgrades cost resources; the progress bar fills based on **distance
  traveled**, not real time — survival is the only way to finish a build.
- City visually scars/grows permanently across playthrough history
  (cosmetic memory of the run).
- **Backlog ideas:** building specialization forks, idle slave flavor
  events, building damage from bad raids/waves.

### 2. Battlefield (outer scope)

- City fixed at center; 4 tower slots (N/S/E/W). Tower *type* swappable at
  those slots pre-battle only; towers auto-fire once battle starts.
- 4 enemy spawn directions, converging inward.
- One permanent hero (no roster, no swap) — fully player-controlled: roam,
  fight, cast spells. This is the sole mid-battle interactivity — no
  telegraphs, no other anti-idle systems needed.
- **War horn:** 30-second window, pulls/weakens enemies faster; each use
  escalates future enemy strength.
- Enemies are terrain-locked by breed — one breed per terrain, each terrain
  giving that breed unique buffs/debuffs.
- **Backlog ideas:**
  - Tower blueprint trade-offs (heavy/slow vs fast/light vs crowd-control)
  - Directional pressure/reinforcement indicator (shows which lane is under
    heaviest load)
  - Tower fusion/combo slots (adjacent compatible towers synergize; four
    elemental types plus unlockable light/dark elements)
  - Hero ultimate charged by city investment (relic synergy/building tier)

### 3. Macro scope (journey)

- Zoomed-out view of the monster's walk and distance remaining to the safe
  zone/crossroad — pacing display and tension builder.
- Monster has a wound/mood state separate from city and hero health; poor
  performance raises wound level, which can slow progress or open new
  burrow spawn points.
- **Backlog ideas:** optional detours (extra distance cost for a guaranteed
  small reward), boss silhouette foreshadowing near act-end, monster
  bond/trust meter for passive perks.

### 4. Raid scope (enemy base)

- Unlocked only after weakening enemies enough via kills (war horn is the
  primary lever for this).
- Teleport in/out, 15-second cooldown each way; enemies spawn from
  everywhere (surround-arena feel).
- Kill threshold spawns an elite **war chief**; defeating them lets you
  **capture and enslave** them (permanent, loyal, no escape) to work the
  scavenging building, and can be assigned to other buildings too — they
  level up via scavenging XP, yielding better loot over time, with
  surprise/random events layered in for flavor.
- **Backlog ideas:**
  - Chief-specific arena modifiers per terrain
  - Partial extraction (bail early with partial rewards, lower risk)
  - Escalating raid difficulty per run (base "remembers" being raided)
  - Raid streak bonus (reward multiplier for consecutive successful raids,
    feeding the same escalation risk)

---

## Crossroads

Occur when the monster reaches a fork. Combat pauses; the player checks the
city for upgrades, then picks a road. **6 possible option types** (2–3
shown per crossroad, not all at once):

1. **Terrain choice** — breed + buffs/debuffs
2. **Risk/length tradeoff** — shorter/safer vs longer/more distance banked
3. **Resource-weighted bias** — favors wood/stone, relics, or scavenging
   targets
4. **Blueprint/reward road** — guaranteed rare tower blueprint or relic, at
   the cost of harder terrain
5. **Captive-specific road** — preview of that terrain's war chief and
   their unique scavenging bonus if captured
6. **Wildcard/event road** — rare, one-time unusual modifiers

---

## Three Acts & Final Bosses

- Difficulty scales with distance traveled; enemy count spikes just before
  each new act begins as the ramp signal.
- Each act ends in a boss fight. Reward package per boss:
  1. **Hero evolution/ascension** — permanent transformation (new spell
     slot, stat tier jump) — keeps the one-hero rule intact instead of
     adding a new hero
  2. **Permanent, always-active city-wide relic** — not socketed, the
     boss's "core"
  3. **Next act's terrain/enemy unlock**
- Open question: do all three rewards drop every act, or does Act 3 (true
  final boss) get something extra so the last fight feels biggest?

---

## Hero

- Single permanent hero, no roster.
- 4 spell slots max, unlocked via leveling, flavored as "scavenging
  incantations."
- Wounded (not permadeath) at the mechanic level, but **hero death or city
  fall = full run restart**.
- Death wipes: city upgrades persist; everything else undecided.

---

## Meta-Progression

**Confirmed to persist between runs:**
- Permanent city upgrade tiers

**Still open — needs a decision:**
- Do unlocked terrains/acts persist?
- Does the relic vault persist?
- Do captured/slaved war chiefs persist?

---

## Open Gaps To Resolve

1. **Win condition** — is there a true end (reaching a final safe zone), or
   is it an endless survive-as-long-as-you-can loop?
2. **Full death-wipe scope** — exactly what resets vs. persists beyond city
   upgrades.
3. **Spell acquisition detail** — are all 4 spells guaranteed by level, or
   is there choice/RNG involved?
4. **Crossroad UI/iconography** — with 6 option types, a clear at-a-glance
   icon system is needed so choices read in seconds, not paragraphs.

---

## Design Priorities (Recommended)

The four scopes already form a closed, self-reinforcing loop: kills feed
raids → raids feed captures and relics → relics feed city power → city
power feeds the hero and towers → the macro scope paces all of it.

**Before writing any code, lock down:**
- The death-wipe scope (what survives a restart)
- The win condition

Both decisions shape how "roguelite" the game feels, and several existing
systems (hero evolution, relic vault, terrain unlocks) only make full sense
once "what a run resets to" is defined.

**Suggested build order:**
1. MVP loop — one hero, city, 4 towers, 3 terrains, basic crossroads,
   war horn → raid → capture loop
2. Act 2 content pass — backlog ideas per scope, second/third terrain
   rosters, boss rewards
3. Polish — wildcard crossroads, blueprint-specific roads, visual scarring,
   flavor events
