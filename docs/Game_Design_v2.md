# BEAST ROAD — Game Design Document v2

*(working title — see Naming, §12)*

> **What this document is.** A revision of GDD v1 with every open decision
> locked, scope cut to a two-person build, and concrete numbers attached so
> code has something to compile against.
>
> **How to read the annotations.**
> `>` **Changed:** blocks mark where this differs from v1 and why. Full
> changelog in §11. Every number marked `[TUNE]` is a starting value chosen
> to make the system buildable, not a balance claim — expect all of them to
> move.
>
> **Status:** Decisions locked. Ready for Stage 1 prototype (§10).

---

## 1. Core Concept

A 2D action tower-defense roguelite. A city rides on the back of a giant
walking beast crossing hostile terrain across three acts. The player
controls a single hero defending four lanes that they cannot all be in at
once.

**Genre fusion:** Travian (city building) + Darkest Dungeon (single-hero
identity, tone) + Slay the Spire (branching runs, unlock-pool meta).

### The one-line design

> **One hero, four lanes, can't be everywhere.**
> Towers hold the line; the hero decides where to add weight.

The moment-to-moment loop is **triage under pressure**. Every system in this
document exists to feed that loop, escalate it, or pace it. Anything that
doesn't is in §9 (Out of Scope).

### The pitch image

A city on the back of a walking beast. It reads in one screenshot. Protect
it in every art decision.

---

## 2. Locked Decisions

These were the open questions in v1. They are now closed. Each is arguable —
argue now, not in month four.

| # | Question | Decision | Why |
|---|----------|----------|-----|
| 1 | Win condition | **True end.** Reach the safe zone at the end of Act 3. | The macro distance bar only means something if it fills. Also decides genre: 45-min run-based roguelite, not an endless survivor. |
| 2 | Run length | **~45 minutes.** 3 acts × ~15 min. | This number caps everything else — crossroad count, city depth, raid length. Nothing else can be sized until it's fixed. |
| 3 | Death-wipe scope | **Everything resets.** Meta-progression is unlock-pool only. | See §7. |
| 4 | Spell acquisition | **Choice, not guaranteed.** Level-ups offer 3 spells from the unlocked pool; pick 1. Max 4 slots. | Makes leveling a decision. Costs nothing extra to build. |
| 5 | Boss reward structure | All three rewards every act. Act 3 boss additionally ends the run (win screen + unlock payout). | The "biggest fight" feeling comes from being the finale, not from a bigger loot table. |
| 6 | Crossroad UI | 3 option types, not 6. Icon + one line of text each. | See §5. |

> **Changed:** v1 listed persistent city upgrade tiers as "confirmed."
> Reversed — see §7 for the argument.

---

## 3. The Four Scopes

Still four scopes. Two of them got much thinner.

### 3.1 Battlefield (the game)

This is where ~85% of playtime happens. Build it first.

**Layout.** Top-down 2D arena. City fixed at centre. Four tower slots at
N/S/E/W, radius **250px** `[TUNE]` from centre. Enemies spawn at the arena
edge, radius **800px** `[TUNE]`, from all four directions, and walk inward
toward the city.

**Key distances** — these produce the triage feel and should be tuned as a
set:

| Value | Start | Consequence |
|-------|-------|-------------|
| Hero move speed | 200 px/s `[TUNE]` | N tower → S tower = ~2.5s. Long enough that the choice costs something. |
| Enemy walk speed | 60 px/s `[TUNE]` | Spawn → tower ring = ~9s. That's the player's reaction window. |
| Tower range | 220px `[TUNE]` | Slight overlap between adjacent towers; no dead zones on the diagonals. |

**Towers** auto-fire. Type is swappable at each slot **only between
segments** (at crossroads and after boss fights), never mid-combat. Towers
are a loadout puzzle, not a placement puzzle — see §4.

**Hero** is the only mid-combat interactivity. Melee-primary, one 3-hit
attack chain, a dash with **0.3s i-frames / 4s cooldown** `[TUNE]`, and up to
4 spells on cooldowns. **Movement speed is the hero's most valuable stat** —
the job is reaching the lane that's collapsing.

**Directional pressure indicator.** Promoted from v1's backlog to **core UI**.
A ring around the city showing per-lane load. The hero's entire decision loop
reads off this element; without it the player is guessing.

> **Changed:** v1 listed this as a backlog idea. It is not optional. If the
> player can't see which lane is failing, there is no triage and therefore no
> game.

**War horn.** 30-second window. Pulls enemies faster and harder, and builds
raid charge. **Cost: the beast plants its feet and distance stops for the
duration** — construction progress freezes. Each use also permanently
escalates enemy strength for the rest of the run (+8% HP and damage per use
`[TUNE]`).

> **Changed:** v1's horn had escalation as its only cost, which arrives later
> and vaguely. Freezing distance makes the cost immediate and legible, so the
> horn becomes a decision instead of a button you always press.

**Enemies.** One dominant breed per terrain (identity, readability) plus a
**shared elite pool** that can appear anywhere (variety). See §8.

### 3.2 City (inner scope)

**Buildings — 4 in v1 build:**

| Building | Function |
|----------|----------|
| Town Hall | Relic sockets. Upgrading adds slots (1 / 2 / 3 / 4). |
| Forge | Unlocks and upgrades tower blueprints for this run. |
| Sanctum | Hero upgrades: max HP, move speed, spell cooldown. |
| Granary | Resource generation rate. |

**Construction is gated by distance travelled, not real time.** This is the
best mechanic in the original document and everything else bends around it.
Surviving *is* building. A tier-1 build costs **150 distance units** `[TUNE]`
(~2.5 min of walking); tier-2 **300**; tier-3 **500**.

**One build slot at a time.** Queueing is the difference between a decision
and a checklist.

**Relics** only grant effects while socketed in the Town Hall. Boss relics
are the exception — permanent, always-active, unsocketed (§6).

**Visual scarring.** City art degrades and accumulates damage across the run.
Cosmetic only. Cheap, high-value, do it late.

> **Changed / CUT:** Scavenging building, Relic Synergy Altar, building
> specialization forks, idle flavour events. Six buildings and a synergy
> system is a second management game. Four buildings, one build slot.

### 3.3 Macro (the journey)

Zoomed-out view of the beast's walk. Shows distance remaining to the next
crossroad, act boundary, and the safe zone.

**Total journey: 2700 distance units.** 3 acts × 900. Beast base speed
**1.0 units/sec** `[TUNE]` → ~15 min/act at full speed.

Each act is **three 300-unit segments**, separated by two crossroads and
ending in a boss.

**The beast's state is one number: walking speed.** Poor performance (city
damage taken, enemies reaching the centre) slows it. Slower beast = less
distance = slower construction = the run tightens. Speed floor **0.5** `[TUNE]`
so a bad stretch is punishing but not a death spiral.

> **Changed / CUT:** The separate wound/mood bar. Three health bars (city,
> hero, beast) is too much to communicate on one screen. Folded into speed,
> which is already displayed. Also cut: detours, bond meter, boss silhouette
> foreshadowing.

### 3.4 Raid (enemy base)

**Unlocked** when raid charge fills (built by kills, accelerated heavily by
the war horn).

**The entire point of this scope: your city is undefended while you're gone.**
Combat does not pause. Towers keep firing, enemies keep walking, and nobody
is plugging the gap. State this prominently in any pitch or store copy — it's
the most interesting decision in the game.

> **Changed:** v1 never said whether the battlefield continues during a raid.
> It does. That ambiguity was hiding the best idea in the scope.

**Structure.** 60 seconds `[TUNE]`. Teleport into a small surround-arena, kill
the war chief, take one relic, teleport out. 15s cooldown each way. Timer
expiry or hero death ejects you with nothing.

**Reward:** the chief's **standard** — a trophy relic with a terrain-specific
effect. One per chief.

> **Changed / CUT:** The entire capture-and-enslave economy. Chief XP,
> scavenging levels, assigning chiefs to buildings, idle events — all cut.
>
> Two reasons. **Scope:** it's a full idle-management game bolted to a
> roguelite, and it's the single largest source of unbudgeted work in v1.
> **Positioning:** slavery as a background idle-worker system with comedy
> flavour events is the version most likely to become the only thing anyone
> writes about the game, and it's very cheap to change now versus after art,
> UI strings, and marketing exist. Taking a defeated warlord's standard as a
> trophy is just as dark, reads cleanly, and carries zero management overhead.
>
> If your friend wants the darkness back, the version that works is one that
> treats it with weight — Darkest Dungeon is grim *and knows it*. What doesn't
> work is grim-as-set-dressing on an idle loop.

---

## 4. Towers & Elemental Fusion

**Four elements:** Fire, Frost, Stone, Storm.
**Eight towers**, two per element.

| Element | Tower | Behaviour |
|---------|-------|-----------|
| Fire | Ember Spire | Fast, low damage, single target |
| Fire | Pyre Cannon | Slow, heavy AoE |
| Frost | Rime Lance | Single target + slow |
| Frost | Hoarfrost Bell | Aura slow, no damage |
| Stone | Bulwark | Taunts and blocks; high HP, minimal damage |
| Stone | Shard Thrower | Piercing line shot |
| Storm | Arc Coil | Chain lightning |
| Storm | Gale Turret | Fast, knockback |

**Fusion.** The four slots form a ring, so each tower has exactly two
neighbours. Every adjacent pair of *different* elements produces a fusion
effect on both towers. Four slots = four active adjacencies per loadout.

| Pair | Fusion | Effect |
|------|--------|--------|
| Fire + Storm | Firestorm | Burn spreads to nearby enemies |
| Fire + Stone | Magma | Leaves a damaging ground zone |
| Fire + Frost | Steam Burst | Periodic AoE knockback |
| Frost + Storm | Blizzard | Chain effects also slow |
| Frost + Stone | Glacier | Chance to freeze; +tower armour |
| Stone + Storm | Quake | Knockback ring on kill |

Same-element neighbours produce no fusion but grant **+25% element damage**
`[TUNE]` — mono-element is a real strategy, not a mistake.

This is a lookup table. It is nearly free to implement and it's what makes
loadout selection a puzzle rather than a stat check.

> **Changed:** Promoted from v1 backlog to core. **CUT:** light/dark elements
> — post-launch content, not v1.

---

## 5. Crossroads

Occur at every 300-unit segment boundary — **two per act, six per run.**
Combat pauses. The player may: swap tower types, socket/unsocket relics,
start a construction, then choose a road.

**Three option types** (2 shown per crossroad):

1. **Terrain choice** — which breed and which terrain modifiers you'll face
2. **Risk/reward** — harder segment, guaranteed relic or blueprint
3. **Resource road** — safer segment, weighted toward resources

> **Changed / CUT:** v1 had six option types. Six needs an icon language, six
> needs balancing against each other, and six means each type appears rarely
> enough that players never learn to read them. Three types × two shown = a
> real choice every time and a UI you can build in an afternoon. Cut:
> captive-specific roads (the capture system is gone), blueprint-specific
> roads (folded into risk/reward), wildcard roads (post-launch).

---

## 6. Acts & Bosses

Difficulty scales continuously with distance travelled. Enemy count spikes in
the final 100 units of each act as the ramp signal into the boss.

**Boss reward package** (all three, every act):

1. **Hero ascension** — permanent transformation for the remainder of the run:
   +1 spell slot (acts 1 and 2), stat tier jump, visual change
2. **Boss core** — permanent always-active city-wide relic, not socketed
3. **Next act's terrain and breed unlock**

| Act | Terrain | Boss | Core effect (starting idea) |
|-----|---------|------|------------------------------|
| 1 | Ashfen Marsh | The Drowned Choir | Towers gain +10% range |
| 2 | Saltglass Flats | Mirrorfang | Hero dash cooldown −1s |
| 3 | Iron Steppe | The Rust Crown | *(final — run ends on kill)* |

Act 3's boss ends the run: win screen, unlock payout, back to menu.

---

## 7. Meta-Progression

**Between runs, the only thing that persists is the unlock pool.**

Clearing content adds towers, relics, spells, and terrains to the pool of
things that *can appear* in future runs. **You start every run at zero power.**

**Nothing else carries over.** Not city tiers, not relics, not blueprints,
not hero levels.

> **Changed:** v1 listed persistent city upgrade tiers as confirmed. This is
> the biggest reversal in the document and the one most worth arguing about.
>
> The case: distance-gated construction only generates tension if you're
> building *now, under fire*. Persistent tiers turn the first ten minutes of
> every run into a formality where you collect buildings you already own —
> which defuses the single best mechanic in the design. It's also the Slay the
> Spire model already cited as an influence, and it's a smaller build (no
> upgrade-state save schema, no balancing power creep across the whole run
> curve).
>
> **The concession, if he wants one:** clearing Act 3 grants a permanent
> +1 Town Hall starting relic slot, capped at +1. Nothing else.

**Save file contents:** unlocked IDs, run statistics, settings. That's the
entire schema.

---

## 8. Content Budget (v1 build)

Hard caps. Everything beyond these is a content patch.

| Content | Count | Notes |
|---------|-------|-------|
| Terrains | 3 | One per act |
| Enemy breeds | 3 | One dominant per terrain |
| Shared elites | 3 | Warden (shielded), Howler (buffs nearby), Burrower (emerges inside the tower ring) |
| Bosses | 3 | One per act |
| Towers | 8 | Two per element |
| Fusions | 6 | Lookup table |
| Hero spells | 8 | Pick 4 per run |
| Relics | 20 | Plus 3 boss cores |
| Buildings | 4 | |
| Crossroad types | 3 | |
| **Currencies** | **3** | Resource (single pooled), relics, blueprints |

> **Changed:** v1 had eight parallel progression axes (socketed relics,
> synergy sets, boss relics, blueprints, spells, chief levels, city tiers,
> multi-resource). Two people cannot balance eight. Three.

### Terrain modifiers

| Terrain | Breed | Terrain effect |
|---------|-------|----------------|
| Ashfen Marsh | Bog-kin — slow, high HP | Enemies regenerate; Fire towers +damage |
| Saltglass Flats | Glass-born — fast, fragile | Enemy projectiles reflect; Storm chains +1 target |
| Iron Steppe | Steppe Horde — weak, arrives in packs | Larger waves, shorter intervals; Stone towers +armour |

### Hero spells (pick 4 of 8)

Flavoured as *scavenging incantations*.

Rift Step (blink) · Cinder Nova (AoE burst) · Bulwark Ward (shield one lane)
· Marrow Drain (lifesteal strike) · Chain Hook (pull enemies to you) ·
Ash Veil (brief invulnerability + speed) · Tremor (knockback ring) ·
Beast's Breath (channelled damage line)

---

## 9. Explicitly Out of Scope for v1

**Do not build these.** They are listed so nobody re-adds them by accident.

- Chief capture, enslavement, chief XP, chief building assignment, idle events
- Relic synergy altar and relic set bonuses
- Building specialization forks
- Light/dark elements
- Wildcard crossroads, detours, partial raid extraction, raid streak bonuses
- Escalating raid memory ("base remembers being raided")
- Beast bond/trust meter, separate wound bar
- Boss silhouette foreshadowing
- Endless mode *(revisit post-launch as a toggle)*
- Multiple heroes, hero roster, hero swapping
- Mid-combat tower placement or swapping

---

## 10. Build Order

Each stage has a **kill question**. If the answer is no, stop and fix it
before adding the next layer. Stages 1–3 are the ones that determine whether
this game is worth making.

### Stage 1 — Does swinging feel good?
Grey boxes. One hero, one enemy breed, one open arena, five minutes of
combat. No towers, no city, no UI, no lanes.
**Ship condition:** attack chain, dash with i-frames, enemy pathing, damage,
death.
**Kill question:** *Is the combat fun with nothing on top of it?* If no,
nothing above this fixes it.

### Stage 2 — Is triage fun?
Four lanes, four auto-firing towers, city HP, directional pressure indicator,
continuous waves scaling over 5 minutes.
**Kill question:** *Does deciding which lane to save create tension?* **This
is the real prototype.** If this stage doesn't sing, the game doesn't exist.

### Stage 3 — Does leaving hurt?
War horn (with distance freeze), raid charge, 60-second raid arena, one war
chief, standard reward. Battlefield continues while raiding.
**Kill question:** *Is choosing to leave your city genuinely tense?*

### Stage 4 — City and distance
Distance tracker, beast speed responding to performance, four buildings, one
build slot, construction gated by distance. Placeholder UI throughout.
**Kill question:** *Does "surviving is building" land, or is the city just a
menu?*

### Stage 5 — It's a run
Crossroads, macro view, 3 terrains, act structure, one boss, win/lose states,
unlock-pool save.
**Kill question:** *Does a 45-minute run hold?*

### Stage 6 — Content and polish
Remaining bosses, full tower/relic/spell sets, fusion VFX, city scarring,
audio, tutorial, menus.

> **Changed:** v1's build order started with the city and included the full
> feature set in the "MVP." The city is the layer you can fake with buttons
> and the least likely to tell you whether the game works. Stages 1–3 are
> roughly six weeks of evenings and they answer the only question that
> matters.

---

## 11. Technical Direction

**Engine:** Godot 4.x, GDScript. 2D renderer, `gl_compatibility` for wide
hardware support. No revenue share, fast iteration, strong 2D tooling.

**Data-driven from day one.** Every tower, enemy, relic, spell, and terrain is
a custom `Resource` (`.tres`), never a hardcoded branch. Adding content should
mean adding a file, not editing a script.

### Project structure

```
/scenes
  /battlefield   arena, lanes, spawners, city, towers
  /hero          hero controller, spells, VFX
  /raid          raid arena, war chief
  /city          building UI, construction
  /run           crossroads, macro view, act flow
  /ui            HUD, pressure indicator, menus
/scripts
  /systems       WaveDirector, DistanceTracker, FusionResolver,
                 PressureCalculator, RaidController
  /resources     TowerData, EnemyData, RelicData, SpellData, TerrainData
/data
  /towers /enemies /relics /spells /terrains    (.tres files)
/autoload
  RunState.gd    current run: distance, resources, relics, loadout, act
  MetaState.gd   persistent unlock pool + settings (JSON save)
  EventBus.gd    signal hub — systems talk through here, not directly
```

### Architectural rules

1. **`RunState` is the single source of truth for a run.** No system caches
   run data locally.
2. **Systems communicate via `EventBus` signals**, never direct node
   references across scopes.
3. **All tuning values live in `.tres` or a single `Balance.gd` constants
   file.** Every `[TUNE]` value in this document goes there.
4. **The battlefield simulation must run while the raid scene is active.**
   Architect for this in Stage 2 — retrofitting it later is painful.
5. **`MetaState` only ever writes unlocked IDs, stats, and settings.** If
   anything else appears in the save file, a design decision has been
   violated.

### Suggested split for two people

Split by scope, not discipline — otherwise you'll both be editing the same
balance file at 2am.

- **Person A — Combat:** hero, towers, enemies, waves, raid, fusion
- **Person B — Run layer:** city, crossroads, macro, meta, UI, save

`EventBus` is the contract between you. Agree on its signal list before
Stage 2.

---

## 12. Changelog vs. v1

| Change | Type | Rationale |
|--------|------|-----------|
| Win condition = true end, 45-min runs | Locked | Decides genre, sizes everything else |
| Death wipes everything; meta = unlock pool | **Reversed** | Protects distance-gated building; smaller build |
| Chief capture/enslavement economy | **Cut** | Largest unbudgeted scope item; positioning risk |
| Raid reduced to 60s combat + trophy relic | Reduced | Keeps the tension, drops the management game |
| Battlefield continues during raids | Clarified | Was ambiguous; it's the point of the scope |
| War horn freezes distance | Added cost | Makes the horn a decision, not a default |
| Beast wound bar → walking speed | Merged | Three health bars is too many |
| 6 crossroad types → 3 | Reduced | Solves v1's own "icon system" gap |
| Tower fusion | Promoted | The only thing making towers interesting |
| Pressure indicator | Promoted to core | The hero's decision loop reads off it |
| City: 6 buildings → 4, one build slot | Reduced | Second management game |
| 8 progression axes → 3 | Reduced | Unbalanceable at two people |
| Light/dark elements | Cut | Post-launch |
| Build order rewritten | Restructured | Prototype the risky layer first |

### Naming

*Beast Road* is a placeholder. It's fine, it's not distinctive, and it's
almost certainly taken on Steam. Check availability before any art or
wishlist page work — renaming after a store page exists costs real momentum.

---

## 13. What's Still Genuinely Open

Everything above is locked *for building purposes*. These are the things
worth revisiting after Stage 3, once you've played it:

1. **Is 45 minutes right?** It might want to be 30. You'll know after one
   full run exists.
2. **Does the raid earn its scope?** If leaving isn't tense in Stage 3, cut
   the raid entirely and put war chiefs on the battlefield as elites.
3. **Are four lanes correct?** Three might create sharper triage decisions
   than four. Cheap to test in Stage 2.
4. **Should towers be upgradeable within a run**, or is swapping the only
   axis? Currently swap-only. Adding upgrades adds a currency — see §8.
