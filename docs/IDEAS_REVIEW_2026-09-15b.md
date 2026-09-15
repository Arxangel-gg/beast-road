# Ideas review — the fifth forwarded list, 2026-09-15

The owner forwarded `ChatGPT_More_Ideas_5.md`: three long brainstorms — a
wildlife wave, a general systems wave, and a hundred-item juice and VFX wave —
with the owner's own caveat attached, that these were produced without access to
the project and so may be "denied, rejected or adapted".

That caveat is the most important fact about the document and it is worth
stating as a finding rather than a disclaimer.

---

## 1. Roughly half of it is already built

Not "something like it" — the same idea, shipped, gated, and recorded in
`CLAUDE.md`. The document proposes as new:

| Proposed | Already here as |
|---|---|
| Creature territories with clues at the borders | the **mythic trail** — five signs leading to the animal |
| Tracking as an actual skill; footprints, feathers, nests | the same trail; `TrailSignData` stages, read by walking near them |
| Mythic omens — nature behaves strangely beforehand | the `data/wrath/unrest_N` signs, and the legendary-slain stillness |
| Predator–prey pressure; overhunting consequences | over-farming retaliation, and the wrath rarity ledger (1, 3, 8, 24) |
| Creature social bonds; juvenile learning; protection moments | `WildlifeFamilies` — courtship, inheritance, growth stages, `protection` |
| Creature diseases, used sparingly | the **Wildblight** |
| Nest theft with an enraged parent | the nesting pass — `Wildlife.rouse_species` |
| Natural disasters affect wildlife first | every telegraph in `wrath` sends the animals running |
| Disaster migration waves | the same |
| Living nests that accumulate | nests, clutches and incubation by road walked |
| Scent/alarm networks | skittish radius, prey bolting, predators noticing |
| Deep-extraction temptation | the **homecoming pass** |
| Dungeon instability / commitment | the collapse, with its tremor warning |
| Mid-run branching paths | crossroads, and Road Cards on top of them |
| Procedural expedition modifiers | portents (omens), twenty of them |
| Run history / expedition chronicle | the Chronicle, and the debrief's `kept` counters |
| Towers affect local wildlife / microhabitats | `Climate` — towers warm, cool and wet the ground they stand on |
| Lightning chains further through wet enemies | the Wet status, `WET_CHAIN_RANGE` |
| Tower-combination reactions | charged ground (`ZONE_TOWER_BUFF`), and the elements' own strains |
| Localized camera shake by distance | `EventBus.camera_impact`, weighted by distance |
| Material-aware impacts | `EnemyData.hide` — FLESH / ARMOUR / STONE / SPIRIT, with per-hide hitstop |
| Tower recoil | `TOWER_FIRE_KICK_PUSH × juice_scale`, authored per tower |
| Tower idle life | `STRUCTURE_IDLE_SWAY`, and per-tower `Ambient` air |
| Selective hit-stop | `HIDE_HITSTOP_SCALE` |
| Damage-number hierarchy | damage numbers pop, arc, hang and tilt |
| Shadows announcing giant threats | the meteor's shadow, and the dragon's |
| Wind system visible everywhere | the wind, which moves foliage, fire, funnels **and characters** |
| Responsive vegetation | the shared sway material, on the walk as well as the road |
| Ambient micro-life | fireflies, butterflies, dust in the corridors, embers in a rift |
| Water interaction polish | swimming, splashes, the flood sheen shader, rain rings |
| Loot pickup magnetism | the magnet |
| Persistent battlefield scars | scorch from the wildfire, fault cracks from the quake |
| Accessibility without removing mastery | remapping, shake slider, the `Graphics` keys |
| Deterministic procedural versioning | `Phenotype.VERSION`, and every system stream seeded from the run |

**The lesson is not that the document is bad.** It is that a brainstorm without
project access converges on the same good answers the project already reached —
which is mild evidence the project reached them correctly.

## 2. What it assumes Wilderhold is, and is not

**An extraction game.** "Body recovery at the death site", "secure pouch",
"contraband containers", "quick-drop backpack", "emergency cache burial",
"mystery containers opened only at extraction", "forward operating outposts",
"supply lines", "extraction under pressure", "moving extraction".

Wilderhold's extraction is a **decision**, not a place: the homecoming pass
after each act boss, where the run's Marks are banked whole or gambled on
another act. There is no site to walk back to, because the run has ended. Every
item in that group is refused — not adapted — for the same reason the 2026-09-15
review refused the egg-theft beat as written.

**A settlement game.** Districts, festivals, tavern rumours, NPC professions with
relationships, museums, player quarters, rival AI adventuring parties, faction
politics, negotiated encounters. The Hold is a *lobby* — that was the reading
that made the hub buildable at all without contradicting the walking town
(2026-09-11). Each of these is a content system beside the ten acts and is §54
territory.

**A game with vertical geometry.** Rooftops, parkour, vaulting, grappling,
terrain manipulation, dark-zone mapping. The hero is clamped to a grid on the
back of a walking beast.

**A game with item attrition.** Durability, modular weapon components,
reforging, weapon identity progression. Gear is already on the capped attribute
scale levelling shares (working rule 7); parts would be a second scale nobody is
tuning.

**A game measured in days.** Seasons, moon phases, celestial events. A run is
hours long.

## 3. What it genuinely found — six gaps, all small, all presentation

Verified in the code rather than assumed. **Owner ruling, 2026-09-15: build all
six.** Each is held to the bound every feel change here is held to — *nothing
about damage moves*.

1. **Directional hit reaction.** `Enemy.take_damage` already receives `from`.
   Bodies take knockback, but nothing *recoils*, so a blow on a boss or on a
   knockback-resistant breed reads as a colour flash and nothing else.
2. **Tower target acquisition.** A tower fires without turning to face what it
   is firing at; `sprite.rotation` carries the idle wobble and nothing else. For
   a tower-defence game this is a clarity win — the player reads which tower is
   about to answer which enemy.
3. **Build and upgrade transformation.** Towers appear instantly, and a level-up
   only changes their size.
4. **Structure destruction.** A tower that falls simply vanishes.
5. **Elemental kill states.** Chill already has `_shatter`; fire, lightning and
   earth have nothing, and the killing blow's element is already known.
6. **Distance-attenuated sound.** `Sfx.play(id, extra_db)` has no position, so a
   tower firing across the map is exactly as loud as one beside you — while the
   *camera* has scaled its shake by distance since 2026-09-13. Closing that
   inconsistency is the cheapest immersion in the document.

## 4. Second rank — good, and **held**, by owner ruling 2026-09-15

Not refused. Deferred until the six above have been played:

- **Persistent footprints** in snow, ash and mud. It earns its place because
  tracking is now a real mechanic and the fiction should be consistent.
- **Boss entrance behaviours**, one authored per boss — eleven data rows, the
  same shape `slam` and `volley` took on 2026-09-13.
- **Post-battle settling** — music drops, dust drifts, embers remain.
- **Anticipation audio** on the telegraphs, which are currently visual only.

## 5. Adapted rather than taken

- **"Wildlife memory and reputation."** The punishing half is built twice over
  (over-farming, robbed nests). What is missing is the *inverse*: a species the
  player has never harmed being less skittish around them. One number, no
  persistence. Worth doing when the second rank is.
- **"Impact Tier system"** — a single Light/Medium/Heavy/Massive table every
  attack references. It exists here as four systems rather than one table
  (`camera_impact`, `hide`, hitstop, `juice_scale`). A refactor before release
  buys nothing the player can see.
- **"Complexity budget: remove a shallow system for every deep one."** Good
  advice in general and wrong here — the shallow systems in this project are
  each gated and each cost a frame fraction. The real budget is the frame, and
  `perf_check` owns it.

## 6. Refused on a bound

- **Adaptive survivors / adaptive enemy factions** — enemies that learn to
  counter the player's build. That is a difficulty setting nobody chose, which
  is the exact objection that keeps the fog of war from feeding the AI.
- **Corruption temptation, run-specific mutation, mana overcharge with
  lingering strain** — each is a power scale entered by accepting a downside,
  and the bound since 2026-09-01 is that levelling and gear are the only two.
- **A Spellcasting tree beside the four disciplines** — refused on 2026-09-14
  already; the Arcane discipline *is* the caster's tree.
- **Weapon durability and repair** — "avoid constant durability babysitting" is
  the document's own caveat, and with the caveat honoured there is nothing left.

## 7. Needing an owner ruling, and **ruled: not for 1.0**

Both of these are the document's best long-range ideas and both are **new
persistence axes**, which working rule 7 governs:

- **Legendary named individuals** — a procedural creature becomes globally
  notable, with a generated name, a territory, scars and a history that outlive
  the run.
- **Notorious enemies** — an ordinary elite earns a name, modifiers and a
  history through repeated encounters and can return. (Deliberately *not*
  Nemesis: that system is patented, and what is described here is the
  recognisable part rather than the protected mechanics.)

**Owner ruling, 2026-09-15: neither is built for 1.0.** They are the strongest
1.1 candidates in the document and are recorded here so the decision is visible
if it is ever revisited. If either is taken up, it needs its own bound written
down first — what it may persist and what it may never grant — exactly as
spirits, the pantry, professions and materials each did.

## 8. The document's own two best lines

Worth keeping, because they are already this project's rules under other names:

> **The Story Test.** For every major feature, ask: can a player tell their
> friend what happened without talking about numbers?

> **Three connections.** Before adding a feature, require it to interact
> meaningfully with about three existing systems.

Compare the bound every addition in `CLAUDE.md` has been held to since the
omens: *a card may only move a number the game already has an opinion about*.
Same rule, arrived at from the other direction.
