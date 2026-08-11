# BEAST ROAD — Game Design Document v3

> **Status: authoritative.** This supersedes `Game_Design_v2.md`.
>
> v2 is kept for its *reasoning* — it argues well for why several systems were
> cut, and those arguments are still worth reading before re-cutting anything.
> But where v2 and v3 disagree, **v3 wins**. `Game Design.md` (v1) remains
> archived history and is not a build source.
>
> **What changed and why.** v2 was scoped for two people building evenings. The
> project owner has since specified a larger game: four fully realised scopes, a
> complete run loop, menus, and the capture system v2 cut. §14 is the full
> changelog. Everything marked `[TUNE]` is a starting value, not a balance claim.

---

## 1. Core Concept

A 2D action tower-defense roguelite. The last remnants of an exiled
civilisation ride a colossal ancient beast across hostile lands, searching for a
sanctuary. The player is the one hero defending a town that rides on the
beast's back.

**Genre fusion:** Travian (town) + classic lane tower-defense (battlefield) +
Musou / Vampire Survivors (raid) + Slay the Spire (run structure).

### The one-line design

> **One hero, four lanes, can't be everywhere.**
> Towers hold the line; the hero decides where to add weight.

The moment-to-moment loop is **triage under pressure**. Every system feeds it,
escalates it, or paces it.

### The pitch image

An immense ancient beast — serpent, turtle and dinosaur fused — walking across a
wasteland with a walled town on the plateau of its back. It reads in one
screenshot. Protect it in every art decision. (Reference:
`References/Scope3(Beast).png`.)

### Story premise *(provisional — see §13)*

We are the descendants of a banished people. There is said to be a sanctuary at
the end of the road. Until we reach it we live on the back of the beast, and
everything between here and there wants us dead.

---

## 2. The Four Scopes

The player moves freely between scopes. **The battlefield never pauses except
where explicitly stated.**

| Scope | Reference | What the player does |
|-------|-----------|----------------------|
| Town | `Scope1(Town).png` | Manage buildings, socket relics in the Town Hall |
| Battlefield | `Scope2(Battlefield).png` | Fight waves, place and upgrade towers |
| Beast | `Scope3(Beast).png` | Watch the walk, read distance to the next crossroad |
| Raid | `Scope4(Raid).png` | Musou-style horde combat in the enemy camp |

---

## 3. Battlefield

**Layout.** Top-down. Town at centre. **Four cardinal lanes** (N/E/S/W). Enemies
spawn at each lane's mouth and walk a **fixed path** to the town. They do not
free-roam — this is a lane tower-defense, not a survivors arena.

**Tower slots: three per lane, twelve total.** Along each lane path, ordered
from the town outward:

```
   TOWN ── [inner] ── [middle] ── [outer] ── spawn
              A          C           B
```

- **Slot A (inner)** and **slot B (outer)** take a normal elemental tower.
- **Slot C (middle)** is the **combination slot**. It only becomes buildable
  once both A and B are built, and what it can become is determined by the two
  elements flanking it.

This is the loadout puzzle. Picking A and B is picking what C can be.

**Key distances** — tune as a set:

| Value | Start | Consequence |
|-------|-------|-------------|
| Hero move speed | 200 px/s `[TUNE]` | Lane to opposite lane ≈ 5s |
| Lane length (spawn → town) | 900 px `[TUNE]` | ~15s walk for a basic enemy |
| Enemy walk speed | 60 px/s `[TUNE]` | The player's reaction window |
| Tower range | 220 px `[TUNE]` | Slight overlap between adjacent slots |
| Town radius | 160 px `[TUNE]` | The thing being defended |

**Towers auto-fire.** They may be **built and upgraded at any time**, including
mid-wave, paid for with resources. *(This reverses v2 §9. See §14.)*

**Hero** is the only mid-combat interactivity: melee 3-hit chain, dash with
0.3s i-frames / 4s cooldown `[TUNE]`, up to 4 spells.

**Enemies telegraph.** An enemy that reaches its target **stops, winds up, and
strikes** on a visible tell. Enemies never deal damage merely by touching the
hero. *(Fixes the v2 build, where walking into you was the entire attack and
melee therefore felt self-harming.)*

**Directional pressure indicator.** Core UI, not optional. A ring around the
town showing per-lane load. Without it there is no triage and therefore no game.

**War horn.** See §6.

---

## 4. Elements, Towers and Combinations

**Four elements: Earth, Water, Air, Fire.** *(v2 used Fire/Frost/Stone/Storm;
these are the same four archetypes renamed. Existing tower identities and art
paths are preserved — see §14.)*

**Eight base towers, two per element:**

| Element | Tower | Behaviour |
|---------|-------|-----------|
| Fire | Ember Spire | Fast, low damage, single target |
| Fire | Pyre Cannon | Slow, heavy AoE |
| Water | Rime Lance | Single target + slow |
| Water | Hoarfrost Bell | Aura slow, no damage |
| Earth | Bulwark | Taunts and blocks; high HP, minimal damage |
| Earth | Shard Thrower | Piercing line shot |
| Air | Arc Coil | Chain lightning |
| Air | Gale Turret | Fast, knockback |

### 4.1 Combination towers

The middle slot builds a tower derived from its two neighbours' elements.
**Ten combinations** — six mixed pairs and four same-element pairs.

| A + B | Combination | Effect |
|-------|-------------|--------|
| Fire + Air | Firestorm | Burn spreads to nearby enemies |
| Fire + Earth | Magma | Leaves a damaging ground zone |
| Fire + Water | Steam Burst | Periodic AoE knockback |
| Water + Air | Blizzard | Chain effects also slow |
| Water + Earth | Glacier | Chance to freeze; +armour to lane towers |
| Earth + Air | Quake | Knockback ring on kill |
| Fire + Fire | Conflagration | Large burn aura, heavy single-target |
| Water + Water | Deep Freeze | Long freeze, low damage |
| Earth + Earth | Bastion | Very high HP taunt, lane damage reduction |
| Air + Air | Tempest | Fast chain lightning, many targets |

**Upgrades.** Every tower has **3 levels** `[TUNE]`. Cost scales; stats scale.
Upgrading is the resource sink that competes with building.

### 4.2 Lane synergy

If both A and B in a lane share an element, that lane gains
**+25% element damage** `[TUNE]` on top of the same-element combination. Mono
lanes are a real strategy, not a mistake.

---

## 5. Town

Circular plan, plots radiating around a central hall (reference:
`Scope1(Town).png`).

| Building | Function |
|----------|----------|
| Town Hall | Relic sockets. Upgrading adds slots (1 / 2 / 3 / 4). |
| Forge | Unlocks and upgrades tower blueprints for this run |
| Sanctum | Hero upgrades: max HP, move speed, spell cooldown |
| Granary | Resource generation rate |
| Scavenging Post | Assign captives; generates resources over distance |
| Watchtower | Reveals incoming wave composition one wave ahead |

**Construction is gated by distance travelled, not real time.** Surviving *is*
building. Tier 1 costs **150 distance units** `[TUNE]`; tier 2 **300**; tier 3
**500**.

**One build slot at a time.** Queueing turns a decision into a checklist.

**Relics** only act while socketed in the Town Hall. Boss cores are the
exception — permanent, always-active, unsocketed.

**Visual scarring.** Town art degrades across the run. Cosmetic. Do it late.

---

## 6. War Horn, Raid Charge and the Raid

### 6.1 The horn

Blowing the war horn:

- makes enemies **arrive faster and stronger** for the duration
- **freezes distance** — the beast plants its feet, construction stalls
- **fills the raid meter** much faster
- permanently escalates enemy strength by **+8% HP and damage per use** `[TUNE]`

### 6.2 The meter and the weakened window

When the raid meter fills:

1. Enemies on the battlefield enter a **weakened state** for
   **20 seconds** `[TUNE]` — reduced HP and damage.
2. The player **may** enter a raid during this window.

### 6.3 The raid

**The battlefield pauses, frozen exactly as it was.** *(This reverses v2, which
had the battlefield continue. The pause is what makes the raid a place you go
rather than a penalty you pay.)*

The hero teleports to the enemy camp and fights a Musou-style horde
(reference: `Scope4(Raid).png`).

**Extraction windows.** Every **30 seconds** `[TUNE]` a return window opens for
**3 seconds** `[TUNE]`. Take it and you leave with a partial reward scaled to
raid performance. Refuse it and:

- enemies grow stronger each window refused
- after **3 refused windows** `[TUNE]` the **chieftain** emerges

**Defeating the chieftain** ends the raid with the full reward:

1. A **relic**
2. The **chieftain as a captive**, assignable to the Scavenging Post or another
   building

**Dying in the raid** ejects you with nothing and costs the run's raid charge.

> **Framing note.** The captive system's player-facing language lives entirely
> in `CaptiveData` string fields, never in logic. Changing the framing — from
> enslavement to conscription, oath-binding, or v2's trophy-standard — is a data
> edit, not a refactor. v2 §3.4 argues at length against the enslavement
> framing on positioning grounds; that argument is worth reading before ship.

---

## 7. Beast Scope

A view of the beast walking (reference: `Scope3(Beast).png`), showing:

- distance remaining to the next crossroad
- act boundary and total journey progress
- a **zoom-out** toggle showing the whole route

**The beast's state is one number: walking speed.** Town damage taken and
enemies reaching the centre slow it. Slower beast = less distance = slower
construction. Speed floor **0.5** `[TUNE]` so a bad stretch is punishing without
being a death spiral.

**Total journey: 2700 distance units.** 3 acts × 900. Base speed
**1.0 units/sec** `[TUNE]` → ~15 min/act.

---

## 8. Crossroads

At every 300-unit segment boundary — **two per act, six per run.** Combat
pauses. The player may rearrange towers, socket relics, start a construction,
assign captives, then choose a road.

**Three option types**, two shown each time:

1. **Terrain choice** — which breed and modifiers you'll face
2. **Risk/reward** — harder segment, guaranteed relic or blueprint
3. **Resource road** — safer segment, weighted toward resources

---

## 9. Acts, Bosses and the Run Loop

Difficulty scales continuously with distance. Enemy count spikes over the final
100 units of each act as the ramp into the boss.

**Boss reward package** (all three, every act):

1. **Hero ascension** — permanent for the run: +1 spell slot (acts 1–2), stat
   tier jump, visual change
2. **Boss core** — permanent always-active town-wide relic
3. **Next act's terrain and breed unlock**

| Act | Terrain | Boss |
|-----|---------|------|
| 1 | Ashfen Marsh | The Drowned Choir |
| 2 | Saltglass Flats | Mirrorfang |
| 3 | Iron Steppe | The Rust Crown |

Act 3's boss ends the run: win screen, unlock payout, back to menu.

### The full loop

```
Splash → Main Menu → New Run
   ↓
[Segment] Battlefield waves ⇄ Town ⇄ Beast     (horn → raid meter → Raid)
   ↓ 300 distance units
Crossroad → choose road
   ↓ ×3 segments
Act Boss → reward package
   ↓ ×3 acts
Win screen → unlock payout → Main Menu
```

Losing the town at any point ends the run and pays out unlocks earned so far.

---

## 10. Meta-Progression

**Between runs, the only thing that persists is the unlock pool.** Clearing
content adds towers, relics, spells, terrains and captive types to the pool of
things that *can appear*. You start every run at zero power.

Clearing Act 3 grants a permanent **+1 Town Hall starting relic slot**, capped
at +1. Nothing else carries over.

**Save file contents:** unlocked ids, run statistics, settings. That is the
entire schema.

---

## 11. Content Budget

| Content | Count |
|---------|-------|
| Terrains | 3 |
| Enemy breeds | 3 |
| Shared elites | 3 — Warden (shielded), Howler (buffs nearby), Burrower (emerges past the towers) |
| Bosses | 3 |
| Base towers | 8 |
| Combination towers | 10 |
| Tower levels | 3 |
| Hero spells | 8 (pick 4) |
| Relics | 20 + 3 boss cores |
| Buildings | 6 |
| Captive types | 3 |
| Crossroad types | 3 |
| Currencies | 3 — resource, relics, blueprints |

### Terrain modifiers

| Terrain | Breed | Effect |
|---------|-------|--------|
| Ashfen Marsh | Bog-kin — slow, high HP | Enemies regenerate; Fire +damage |
| Saltglass Flats | Glass-born — fast, fragile | Projectiles reflect; Air chains +1 target |
| Iron Steppe | Steppe Horde — weak, in packs | Larger waves, shorter intervals; Earth +armour |

### Hero spells (pick 4 of 8)

Rift Step · Cinder Nova · Bulwark Ward · Marrow Drain · Chain Hook · Ash Veil ·
Tremor · Beast's Breath

---

## 12. Still Out of Scope

- Multiple heroes, hero roster, hero swapping
- Endless mode *(revisit post-launch as a toggle)*
- Light/dark elements
- Relic set bonuses / synergy altar
- Building specialisation forks
- Detours, wildcard crossroads
- PvP, multiplayer, leaderboards

---

## 13. Genuinely Open

1. **Story and tone.** Premise in §1 is provisional. Needs a pass.
2. **Captive framing.** See §6.3.
3. **Is 45 minutes right?** Might want to be 30.
4. **Are four lanes correct?** Three may sharpen triage.
5. **Do combination towers need their own art**, or are they recoloured
   composites of their parents?
6. **Naming.** *Beast Road* is a placeholder and is likely taken on Steam.

---

## 14. Changelog vs. v2

| Change | Type | Rationale |
|--------|------|-----------|
| Elements renamed to Earth/Water/Air/Fire | Renamed | Owner's spec. Frost→Water, Stone→Earth, Storm→Air. Tower identities and all art paths preserved, so no assets churn. |
| 4 tower slots → 12 (3 per lane) | Expanded | The middle combination slot is the loadout puzzle |
| Fusion adjacency → combination slot | Restructured | Combos are now a built tower, not a passive pair effect |
| 6 fusions → 10 combinations | Expanded | Same-element pairs now produce a tower too |
| Tower upgrades (3 levels) | Added | Resource sink competing with building |
| Enemies free-roam → fixed lane paths | Changed | Classic TD readability |
| Mid-combat tower placement | **Un-cut** | Was v2 §9. Owner's spec. |
| Enemies telegraph attacks | Added | v2's contact damage made attacking feel self-harming |
| Battlefield continues during raid → **pauses** | **Reversed** | Makes the raid a destination, not a penalty |
| Fixed 60s raid → extraction windows | Restructured | Push-your-luck replaces a timer |
| Partial raid extraction | **Un-cut** | Was v2 §9. Owner's spec. |
| Chieftain capture → captive labour | **Un-cut** | Was v2 §9. Owner's spec. Framing kept in data — see §6.3 |
| Scavenging Post + Watchtower | Added | 4 buildings → 6 |
| Raid meter → weakened-enemy window | Added | Gives the horn an upside, not only a cost |
| Full menus, splash, settings, save UI | Added | Owner's spec: a complete game, not a prototype |
| Story premise | Added | Provisional |
