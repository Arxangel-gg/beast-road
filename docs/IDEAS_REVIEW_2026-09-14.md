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

## Two principles adopted from the lists

- **Skills change how the player treats the land, not only their numbers.**
  A master woodcutter cuts without devastating the forest; a master farmer
  makes life grow where the ground says it should not.
- **See it now, earn it later.** A thing in the world may name the level it
  wants - a black seam, a strange tree, an unstable ruin - so aspiration is
  visible without quest gates.
