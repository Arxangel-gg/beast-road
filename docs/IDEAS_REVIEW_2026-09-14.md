# Ideas review, 2026-09-14 — the earth's wrath, the climate, and the crafts

The owner forwarded three ChatGPT conversations on the same day: disasters
and the earth's wrath, the ecology and a climate grid, and a long list of
crafts in the manner of RuneScape. This is the triage - what was built, what
comes next and in what order, what is deferred, and what is refused with the
reason - so the next session starts from the same place rather than from the
lists.

The rule the triage was made under is the one every addition to this project
is held to: **a new thing may move a number the game already has an opinion
about, or it is a content system that needs its own bound written down
first.** And one more, from the owner: **wrath is hidden.** Nothing here may
become a meter.

## Built (v0.21.0, v0.22.0)

- The earth's wrath: a hidden floor and heat fed by wildlife killed by
  players and enemies; quakes, wildfires, tornadoes, meteors, chain lightning
  in floods; every tower can be damaged and enemies may turn on one; acts
  ease wrath and never reset it.
- Charged ground ("hotspots"): storm core, burning ground, flood basin,
  seismic fault; matching towers overcharged; bounded and renewing.
- Telegraphs through the world: the hum before a quake, the dust before a
  funnel, the shadow before a stone, the animals running; the signs of the
  earth's mood as data lines.
- Compound disasters that multiply what exists: fire whirls, dry lightning,
  conductive floods, the historic trace (scorch, fault cracks).
- The climate grid: coarse cells with additive falloff sources, diffusion,
  sleep, band-only replication, bilinear reads, a noise-broken overlay, a
  debug view, a reserved soil byte; wildfire, wells and lightning read it.
- Water drawn as water: refraction, depth, foam, glints, rain rings, puddles
  where the ground is wet.

## Next, in order

1. **Rarity-scaled wrath and the legendary shock.** Per-kill cost by rarity,
   sharply; a legendary is a moment the world notices (birds, silence, the
   sky) and a window of raised hazard. **Legendary wildlife as anchors**:
   alive, a legendary steadies its region; killed, that leaves for the run.
   The strongest idea in the lists and cheap once wrath is per kill.
2. **Ecological strain and recovery**: clear-cutting, burning, and hammering
   one element feed wrath; each element's strain decays on its own clock
   (fire calms in rain, earth slowly, air fast and volatile); the floor
   recovers slowly when the road is left alone.
3. **Wind as a vector** feeding fire spread and tornado drift, from the
   weather's own wind plus a slow wander.
4. **Farming**, first of the new crafts, because it reads the grid (soil,
   moisture, temperature) and is the skill that ties the simulation to the
   player. Needs a working-rule-7 decision: seeds and a planted plot persist?
   Write the bound before the code, as the Angler's was.
5. **Cooking**, because farming, fishing and wildlife all feed it, with
   situational meals (heat, cold, wet) rather than bigger healing.
6. **Forestry as a woodcutting layer**: selective cutting reduces the strain
   clear-cutting adds; replanting recovers it. A behaviour, not a skill.
7. **Regional memory** on the soil byte: ground repeatedly burnt reads
   SCORCHED, repeatedly flooded WATERLOGGED, and farming reads both.

## Deferred

- Volcanic fissures, sinkholes, landslides, hail, dust storms, mudslides,
  geysers, floods that freeze, supercells, lava, blizzards-as-state: each is
  a new terrain state or movement rule. The soil byte is where they plug in
  when one earns its place.
- Spatial weather (storm cells you walk into): the grid can carry it; the
  sky's rain, charge and flood would become per-cell fields. After farming.
- Structural stress on towers, erosion, lightning rods, soil quality, ash and
  smoke, water contamination, wildlife migration, predator-prey balance,
  disaster aftermath loot, biome-specific tendencies, disaster-resistant
  construction, resonance/overcharge states, recovery events, element
  opposition, NPC warnings, audio warning layers beyond the rumbles.
- The crafts beyond farming and cooking: campcraft, fletching, crafting,
  masonry, engineering, herbalism, foraging, tracking, trapping, beast lore,
  survival, salvaging, archaeology, surveying, weathercraft, attunement,
  gemcutting, leatherworking, brewing, husbandry, beekeeping, composting,
  seed breeding, prospecting, cartography, trade, stewardship. Fewer skills
  with more interaction between them is the rule; each arrives one at a
  time with its bound, as the Angler, the Woodcutter, the Miner and the
  Smith did.

## Refused as written, and why

- **Enemy pathfinding that avoids unsafe zones, and tower projectiles that
  behave differently under wrath.** Both change wave pressure, and the
  ten-act curve `curve_report` reads cannot be read against them. A hazard
  the enemies walk around is a difficulty setting nobody chose.
- **A wrath UI that pulses or cracks.** Wrath is hidden; the world tells.
- **Fifteen independent skills because RuneScape has them.** Each new craft
  is a persistence decision under working rule 7 and a bound to defend.

## The third document: `ChatGPT_More_Ideas_3.md`

A design bible rather than a list: nine official skills (Woodcutting, Mining,
Fishing, Smithing, Farming, Cooking, Engineering, Herbalism, Archaeology)
with a level-100 cap and a capability unlock every ten levels, universal XP
and quality rules, a co-op XP rule, cross-skill chains, a skill fantasy, a
progression and completion pacing table (~350 hours to a genuine 100%),
difficulty reward multipliers, renown after player level 100, an economy
and exchange section, and a 38-topic outline of documents still to write.

**Adopted as the spec for the next crafts.** Farming (soil states derived
from the climate grid, event-based growth stages, readable failure, the
yield sum, seed adaptation late) and Cooking (one meal buff plus one tonic
buff, situational rather than bigger healing) will be built to these pages,
each with its working-rule-7 bound written first. The Earth's Wrath
interaction page is what the ecology batch already builds toward.

**Adopted as rules.** Skill XP and player XP survive a failed run (already
true here: professions and the hero persist as they are earned); difficulty
multiplies XP and rare chances, never ordinary nodes; no collection target
may need astronomically low odds without a pity or a fragment path (the
shiny streak correction is the precedent); milestone unlocks say what you
can now *do*, not a percentage.

**Decided when Farming lands, not before:** the level-100 skill cap. Four
crafts are authored to `PROFESSION_MAX_LEVEL` today; raising it re-paces
all four and wants the unlock tables authored as data, which is the same
change as the fifth craft and should be made once.

**Recorded, not built.** Engineering and Archaeology are the two skills that
change the map (structures on tiles; sites the disasters create) and each
needs its own bound; renown after 100 folds into the Ascension, which is
already prestige and nothing else; the exchange notes describe the Long
Ledger's buy/sell orders and sinks and add nothing the account blocker does
not still block; the 38-topic outline is documentation, to be written as
each system is built rather than ahead of it.

## The fourth document: `ChatGPT_More_Ideas_4.md` (spellcasting)

A complete magic system: a tenth persistent skill (Spellcasting 1-100) with
its own discipline tree and points, six schools of five spells, elemental
status effects and ten reactions, environmental magic on the climate grid,
wrath from casting, spell acquisition by grimoire and archaeology, rituals
and co-op rituals, catalysts, affixes, criticals, resistances, run augments,
unique items, anti-magic enemies, telegraphing, networking, debug tools.

**Taken, because it multiplies what exists.** Spells already exist (`SpellData`
kinds, mana governed by Focus, the Arcane discipline). Two pieces make them
part of the world the way towers now are: **spells feed the climate and the
strain** (a fire spell warms its cells and adds ember, a water spell wets and
adds tide, and so on - the same `Climate.add_heat`/`add_wet` and
`RunState` strains the towers use, rate-limited per cast), and **Wet with its
reactions** (a Wet body conducts - lightning chains further and hits harder
on it; freezes sooner; and fire on it steams the Wet away rather than
burning). Status shapes a blow; the reaction magnitudes are one number each
in Balance and `reaction_check` measures them, so the curve stays readable.

**Refused: a second tree.** A Spellcasting skill with its own discipline
points beside the four disciplines is the third draft this project keeps
refusing (IDEAS_REVIEW §4, Road Cards). The Arcane discipline *is* the
caster's tree; it grows nodes and spells rather than gaining a rival.
"Run spell augments" are Road Cards with spell keys, when authored.

**Deferred.** Six schools of five spells (content, with icons and VFX, after
the reactions prove out), rituals and co-op rituals (a new interaction
grammar), catalysts and magic affixes (gear kinds and affix keys on the
existing tables), spell acquisition by grimoire and archaeology (after
Archaeology), anti-magic enemies (a breed with a resistance is a `.tres`
away once resistances exist), spell criticals and resistances.

## Two principles adopted from the lists

- **Skills change how the player treats the land, not only their numbers.**
  A master woodcutter cuts without devastating the forest; a master farmer
  makes life grow where the ground says it should not.
- **See it now, earn it later.** A thing in the world may name the level it
  wants - a black seam, a strange tree, an unstable ruin - so aspiration is
  visible without quest gates.
