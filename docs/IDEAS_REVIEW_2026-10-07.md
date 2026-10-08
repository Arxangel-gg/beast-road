# Ideas review — 2026-10-07

Two forwarded ChatGPT lists (about eighty items and a closing thesis) and the
owner's mercenaries brief, triaged against what Wilderhold already ships. The
owner asked for each idea to be implemented, adapted or rejected as best fits
the game. Nothing here is a ruling; the rulings already on record in
`CLAUDE.md` are the bounds every verdict is held to.

**Verdicts.** *Built* means the game already does it, often under another name
(the file or system is named so it is not built twice). *Adopt* means build it
as proposed. *Adapt* means the idea is right and the proposed shape is not.
*Defer* means worth having and not now. *Refuse* means it contradicts a bound
the project holds, and the bound is named.

## Status, 2026-10-08

Every *Adopt* row is built, and every *Adapt* row is either built or turned out
to be built already. Read against the code rather than this list, because the
list was wrong about three of them:

| Item | Where it stands |
|---|---|
| Mercenaries (2.1) | Built, five stages - `mercenary_check`, `mercenary_road_check` |
| The corpse and the Living Battlefield (2.2) | Built - `corpse_check` |
| Death recap, personal best, perfect guard, durability restoration, codex mastery, teaching achievements, near-death, tower damage states (2.3) | Built |
| Run history and the Hall (2.3) | Built as **the Cairn** - `cairn_check` |
| Co-op ping wheel (2.3) | Built - `ping_check` |
| More mutations (3) | Built: Leeching, Riven, and the death blast already was the hazard trail |
| Build-defining uniques (3) | Built - `docs/UNIQUES_DESIGN_2026-10-07.md`, `unique_check` |
| Boss phases that change the battlefield (3) | **Was already built** - `EnemyData.phase_events`, `boss_reach_check` |
| Weather fronts (3) | **Was already built** - `WEATHER_FRONT_SPEED`, the weather veil |
| Migrations (3) | Built - `migration_check` |
| Population memory (3) | **Was already built** - `Wildlife.cull_share` |
| Sabotage enemies (3) | Built as the Saboteur mark - `saboteur_check` |
| Companion commands (3) | Built - `spirit_order_check` |
| Between-wave decisions, Hold prosperity (3) | As written: the Quartermaster, the wayside and the pass; the Cairn first |

**The test the lists themselves end on is a good one and is adopted as a
working question:** *can this interact with at least three other Wilderhold
systems?* It is how the corpse system below was chosen over a dozen isolated
features, and it is the reason most of the *Defer* rows are deferred.

---

## 1. What the lists already describe

Roughly half of both lists ships. This is the fifth forwarded document in a row
of which that is true, and recording it is what stops it being built twice.

| Idea | Verdict | Where it lives |
|---|---|---|
| Enemy affix / elite mutation (1-4 properties) | **Built** | 36 marks in `data/affixes`; `EnemyMarks.roll`; tier `marks_max` and `boss_marks`. Frenzied, Armored (`damage_resistance`), Regenerating, Pack Leader (Packbound), Stormcharged (Stormbound, `death_chain`), Reflective (Mirrorhide), Shielded (`spawn_guard`), Explodes on death (`death_blast_*`) all exist. |
| Enemy roles + tactics | **Built**, mostly | Marcher, Vanguard, Warden, Howler, Burrower roles; siege orders; sighted bodies leave the road (`_may_chase`); morale; pounce, anchor, ward, store behaviours; VANGUARD/REARGUARD formations. |
| Wave director | **Built** | `WaveDirector`: archetype library, formations, calm waves, siege orders, Heralds. |
| Loot affix depth, unusual effects | **Built** | Affixes divided by rarity, legendary affixes, gem sockets, legendary *branch grants* (a skill upgrade on a piece - the "unusual effect" the list asks for), sets, makes, tempering. |
| Favorite / lock items | **Built** | Gear marked kept (`Stash.may_break`). |
| Persistent battlefield scars | **Built** | Ground scars, craters, scorch, Brutal blood and stains - permanent for the whole journey since 2026-10-01. |
| Microclimates | **Built** | `Climate` grid: heat, wetness, soil byte, read by fire, wells, crops, lightning. |
| Rare albino / ancient / mythic | **Built** | Shiny variants with dry-streak pity; five mythics and the trail. |
| Wildlife personality traits | **Built** | `data/spirit_traits`, rolled per animal. |
| Wildlife territory | **Built**, partly | Nests, eggs, robbed parents hunting the party, families protecting young. |
| Wildlife food chain | **Built**, partly | Predators hunt prey, birds come to a death, scavenging is §2 below. |
| Dynamic events during waves | **Built** | Heralds, dragon passes, the earth's events, the raccoon, wayside encounters, legendary shocks. |
| Crossroads consequences | **Built** | Ten road kinds with banes and boons; the pass home; portents. |
| Hidden events | **Built**, one | The mythic trail (Evidence -> Tracking -> Encounter). |
| Build summary / damage breakdown | **Built** | `DamageLedger` on the debrief and the pause screen. |
| Run modifiers / mutators | **Built**, as portents | Twenty omens, kept for the run and stacking. |
| Tower sandbox | **Built** | The sandbox road (2026-09-30). |
| Combat readability priority | **Built** | `JuiceDirector`: telegraph > hazard > boss > player > cosmetic, floors never zero. |
| Adaptive VFX density | **Built** | `JuiceDirector` load, ink caps, `VFX_CROWD_*`, the quality governor. |
| Adaptive audio | **Built**, partly | Distance falloff, occlusion, `SFX_WORLD_STARTS_PER_FRAME`, mix priorities. |
| Performance budgets | **Built** | `budget_check`, every cap a constant. |
| Save validation | **Built**, partly | Version backups per slot, unreadable backups, cleaned reads. |
| Accessibility suite | **Built**, mostly | Colourblind modes, shake, flash and number scales, blood levels, UI scale, rebinding, the comfort card. |
| Controller-first | **Built** | `pad_focus_check` walks every screen's focus ring. |
| Mobile density | **Built**, partly | Touch layouts and the UI scale; the thumb cluster is item 25 and still owed. |
| Tutorial as gameplay / per-slot memory | **Built** | The Walk; coach triggers; the save is the slot. |
| Titles by playstyle | **Built** | `data/run_titles` (element by blade, towers or companion). |
| Run reputation | **Built** | Karma (2026-10-01). |
| Creature morale | **Built** | Enemy nerve; wildlife fright and the herd running together. |
| Sound attraction | **Built** | `Wildlife.notice`. |
| Slow-motion moments / boss kill-cam | **Built** | Hitstop, the last kill's beat, the boss-fall card and shader. |

## 2. Adopted - built next, in this order

### 2.1 Mercenaries (the owner's brief)
The largest item and the owner's own. Its design is
`docs/MERCENARIES_2026-10-07.md`; it is built in stages, each gated.

### 2.2 The meaty corpse, and the Living Battlefield it connects
The lists' closing thesis is right and is the strongest idea in them: *connect
what exists rather than add beside it*. Every link of its example chain exists
except one: **there is nothing on the ground between a death and the bones.**
The owner asked for exactly that on 2026-10-07 (corpses that are eaten, carried,
fought over, that draw vultures and a large scavenger, that wear down to bones
which fade - and stay for good in Brutal), so the corpse is built as the spine:

- a death leaves a corpse that the blow throws and the ground bounces;
- **scent** (adopted from list two, *lite*): a corpse and a blood pool are smelt
  from further downwind, read off `RunState.wind` - the first time the wind
  decides where an animal goes;
- predators eat, scavengers carry, the territorial guard it, and a pile draws
  vultures and, rarely, a roaming scavenger apex that aggroes everything near;
- the corpse wears down through states to bones, and bones join the ground
  scars in Brutal.

That one system passes the three-systems test five times over: blood, wrath and
grief, wildlife, wind, the ground, Brutal mode.

### 2.3 Small, high value, each bounded
- **Death recap** (list item 40): the last seconds of blows a Warden *took*,
  by source, on the debrief - the `DamageLedger` already exists for blows dealt.
- **Run history and the Hall** (items 39, 77, 78): the last runs kept as run
  statistics (working rule 7 already sanctions those), read by a Hall in the
  Hold - fallen runs on one side, records on the other.
- **Personal-best callouts** (item 79): said once, with ceremony.
- **Co-op ping wheel** (item 63): eight pings, relayed as facts.
- **Perfect guard** (item 14): a raise inside a short window before a blow is a
  perfect guard - the whole blow, a stagger, a deflected shot - and it is the
  shield's answer to *No Ground Given*, which already makes a perfect evade the
  game's block.
- **Durability restoration** (item 12): a rare master-smith material restores a
  piece's original ceiling once. Without it a beloved piece is disposable, which
  is the list's point and a fair one.
- **Codex mastery** (item 73): Encountered -> Killed -> Studied -> Mastered, the
  entry growing as kills climb. Knowledge as progression, never power.
- **Teaching achievements** (item 74): data only.
- **Near-death feedback** (list two): a low-pass on the world's sound and a
  heartbeat under a fifth of health, on the existing vignette.
- **Tower damage states and directional collapse** (list two): a hurt tower
  smokes, sparks and leans by its share; a fallen one falls away from the blow.

## 3. Adapted

| Idea | Adaptation |
|---|---|
| More mutations | As *mark fields*, the 2026-09-25 bound: **Vampiric** (heals a share of what its blow takes), **Splits on death** (two lesser bodies of its breed, counted by the wave), **Hazard trail** (a short ground strike where it dies). Burrowing and Phasing are behaviours already, not marks. |
| Encounter director reading the player | **Refused as rubber-banding, kept as pacing.** A director that reads the player's dominant element and counters it punishes the build the player chose, which is the opposite of buildcraft. What stays is the road's own drama: calm waves, formations, Heralds and act surges. |
| Build-defining uniques | As **authored trophy pieces** that carry a keystone-style re-route (the Road Card bound: when or what, never how much). One per act boss, found only there. A design pass before any are authored. |
| Boss phases that change the battlefield | As data on the phase: a phase may call a weather, a quake, a flood or a summons through the doors those already use. Each boss's breaks are already authored; this adds an optional event to each. |
| Weather fronts | A front crosses the field from the wind's side over a few seconds - the rain veil, the dark and the wet arriving as a line - rather than switching on. The weather's facts do not change, only when each part of the field receives them. |
| Migrations | A herd crossing as one arrival through the existing arrival door, with the herd's flight and the predators' interest it already carries. |
| Population memory | The over-farming savage is already the consequence; the adapted half is a species' arrival weight falling for the act after it is culled. Bounded, run-scoped. |
| Between-wave decisions | Through the Quartermaster, the wayside and the pass, which already are these; a fourth would be a menu. |
| Sabotage enemies | As a mark that goes for a well or a trap rather than the wall, beside siege orders. |
| Companion commands | Built with the mercenaries: one command set for a spirit and a mercenary. |
| Hold prosperity, civilians, quarters | Adapted to the Hall in 2.3 first; a Hold that grows with the campaign is art-heavy and waits. |

## 4. Deferred

Training dummies at the Hold; codex filters beyond search; equipment presets;
challenge runs as a weekly seed (the leaderboard has no server time); prestige
cosmetics; photo mode; simulation LOD for distant wildlife (the frame does not
need it yet - measured); party scaling by composition; hold/toggle and
auto-aim accessibility options; environmental ice and mud states (the soil byte
is reserved for them); hidden-event secrets; companion loyalty as behaviour.

## 5. Refused, and the bound each would break

| Idea | Refused because |
|---|---|
| Companion aging to Ancient/Ascended | A companion that grows stronger the longer it is owned is a third power scale (2026-09-01: collection, not accumulation). Wildlife growth stages already exist for the young. |
| Companion loyalty as power | The same bound. |
| Host migration | Recorded out of scope since 2026-09-14: the run is the host's. |
| Personal / need-greed loot | Gear is already personal (each Warden's stash); the purse is the run's. A need-greed vote is a menu between waves. |
| A director that counters the player's build | Anti-buildcraft; see §3. |
| Steam Deck verification | Not refused - it needs the device, which is the owner's. |
