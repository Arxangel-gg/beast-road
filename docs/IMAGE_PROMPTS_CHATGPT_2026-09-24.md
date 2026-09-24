# Image prompts for ChatGPT (GPT Image) - everything PixelLab should not make

**For the owner, 2026-09-24.** PixelLab makes the *sprites*: every unit, tower,
building, animal, mount, plant, tile and icon that stands on the field at
128-192px. Everything below is the other kind of picture - **full-screen
paintings the player never sees beside a sprite, the interface's own textures,
and the store** - and those are what a general image model does better.

Nothing below fills a placeholder; `asset_report` is clean. Every item is an
*elevation*: today's version is a sprite held up full-screen, a coloured plate,
or a pixel painting at 688x384 scaled 2.8x.

## How to generate and deliver

- **Sizes.** GPT Image renders 1024x1024, 1536x1024 (landscape) and 1024x1536
  (portrait). Ask for the one named on each prompt; I crop and downscale to
  the exact size the game needs. Never ask for an odd size.
- **Transparency.** Prompts marked **[alpha]** end with the transparency
  clause. If it comes back with a checkerboard *drawn in the image*, reply:
  *"regenerate with a true transparent alpha channel, not a checkerboard
  pattern drawn in the image."* Check it in an editor before saving.
- **Naming.** Save each file under the name given, as PNG, into
  `art_inbox/chatgpt/<section>/`. I do the rest (crop, scale, install, gate).
- **No text in the image, ever** - the game sets its own type. If a prompt
  needs a mark or a sigil it says so; letters are never wanted.
- **Variants.** Where a prompt says *x N*, generate N and keep them all;
  I pick, and the rejects are still useful as style references.

## The style block - paste at the top of every prompt

> Dark painterly grim-fantasy game art, hand-painted with visible brushwork,
> no black outlines. Strong warm amber rim light from the upper right against
> deep teal-black shadow. Muted, desaturated base palette with one saturated
> accent. Palette: shadow #0B1416, slate #1E2E33, amber #E8A33D, bone #D9CDB8,
> rust #8C3A2B. Cinematic, atmospheric, weighty; nothing cute, nothing glossy,
> no lens flare, no chromatic aberration, no watermark, no text, no letters,
> no signature, no border, no frame unless asked.

**The world, so every picture agrees.** *Wilderhold* is a fortified town
carried on the back of **Yuri**, a colossal walking beast - a mossy, plated,
stone-hided Worldstrider with vines and old chains hanging from his flanks,
bigger than a hill, walking a road that crosses eleven regions to a beacon at
the top of the world. The **Warden** is the player: a hooded figure with a
bone-white skull face, dark blue-grey hooded cloak, steel plate pauldrons, a
red sash, a red banner on a pole at the back, a glowing lantern in the left
hand and a curved sword in the right. The enemy is **the Host**, a compelled
army of many peoples, driven by **Kharok the Chainmaker** - once a Warden, now
the one who chained the Worldstriders - and his kept companion **the
Gatekeeper**. The road's own elemental music is the **Roadsong**.

The transparency clause: *"Isolated on a fully transparent background with a
real alpha channel; no ground plane, no shadow on the ground, no backdrop."*

---

## A. Store, platform and identity (`art_inbox/chatgpt/store/`)

1. **`key_art_master.png`** - 1536x1024, x3. *Wilderhold key art: the colossal
   beast Yuri seen from three-quarter front and slightly below, a walled town
   with lantern-lit rooftops and a forge chimney on his back, four roads
   falling away from the town down his flanks into a jungle of huge gate-like
   trees, warm amber evening light from the upper right, the small hooded
   Warden standing at the town's edge with a lantern, tiny against the beast so
   the beast reads as a mountain; dark teal-black jungle depth, a beacon far
   away at the top of a mountain in the last light.* No text.
2. **`capsule_vertical.png`** - 1024x1536, x2. *The same scene composed tall:
   the beast's head and shoulder filling the lower two thirds, the town on his
   back at the middle, the Warden on the wall, the beacon mountain above in the
   sky, room at the top for a title.* No text.
3. **`capsule_square.png`** - 1024x1024, x2. *Close on the Warden's hooded
   skull face lit from below by the lantern, the beast's mossy plated hide as
   the whole background, one chain link the size of a door hanging behind.*
4. **`app_icon.png`** - 1024x1024, x3 **[alpha]**. *A single readable emblem for
   a game icon: the Warden's hooded skull mask over a glowing lantern flame,
   bold simplified shapes that read at 48px, painted not vector, amber flame
   the one accent.* Then the transparency clause.
5. **`sigil_chain_lantern.png`** - 1024x1024, x3 **[alpha]**. *An emblem for a
   studio-style logo mark: a broken chain link forming a ring around a lantern
   flame, worn iron and amber, flat front-on, symmetrical, no text.*
6. **`social_banner.png`** - 1536x1024, x2. *A wide banner crop: the beast's
   silhouette walking left to right across a horizon at dusk, the town's
   lanterns the only warm light, the road below, vast empty sky above for
   text.* No text.
7. **`launcher_backdrop.png`** - 1536x1024, x2. *The key art scene at night,
   the town's lanterns and the forge glow the light source, the beast asleep
   with his head down, mist at his feet, the sky full of stars and one beacon;
   calm, for a window a player waits at.*
8. **`store_background.png`** - 1536x1024. *A very dark, low-contrast wide
   painting of the beast's hide - moss, plates, chain - to sit behind a store
   page at 30% brightness; no focal point, no horizon.*

## B. Act cards and loading screens (`art_inbox/chatgpt/acts/`)

One landscape painting per region, **1536x1024**, x2 each. Every one is
*"seen from the town on the beast's back: the road ahead falling away below,
the region's ground and its landmark, the horizon in the upper third, the
beast's plated shoulder or a chain in the lower corner for scale"*. Nothing
that lives on the field is drawn in detail - no enemies, no towers.

9. **`act01_verdant_maw.png`** - *The Verdant Maw: a jungle of gate-sized
   trees, roots like bridges, green-gold light through canopy, a river.*
10. **`act02_sunglass_waste.png`** - *The Sunglass Waste: a desert of dunes and
    dark glass ridges, heat shimmer, a half-buried ruin, white sun.*
11. **`act03_white_teeth.png`** - *The White Teeth: a snowfield below jagged
    white peaks, a frozen pass, blue shadow, a cold amber dawn.*
12. **`act04_hollow_marches.png`** - *The Hollow Marches: fog over a bog of
    black water and reeds, dead trees, cranes standing in the shallows, will-o'
    lights.*
13. **`act05_rustwood.png`** - *The Rustwood: a red autumn forest with rusted
    iron machines half swallowed by the trees, orange leaf-fall, copper light.*
14. **`act06_saltpan_mire.png`** - *The Saltpan Mire: a white salt flat cracked
    into plates, brine pools mirroring the sky, distant salt stacks.*
15. **`act07_iron_steppe.png`** - *The Iron Steppe: grass to the horizon and no
    cover, a huge sky, wind in the grass, one iron watch-post, riders as dust.*
16. **`act08_glass_fields.png`** - *The Glass Fields: a glacier ground over a
    city, towers sheared off under blue ice, prisms of light, cold and clear.*
17. **`act09_ashen_reach.png`** - *The Ashen Reach: a burnt forest of stumps,
    ash drifts like snow, and a glow of embers under all of it, red sky.*
18. **`act10_last_terrace.png`** - *The Last Terrace: cut stone steps of a giant
    stair climbing into cloud, old statues, wind, the beacon's light above.*
19. **`act11_crown.png`** - *The Crown of the World: the summit - a beacon
    tower wrapped in colossal chains driven into the rock, the world below
    under cloud, the chains' anchor spike, cold gold light.*
20. **`hold_home.png`** - *The Hold: the last human hold cut into a hillside,
    three shelves of stone and turf, a forge, pens, a stable, banners, an
    unfinished wall, warm windows at dusk, the beast's shadow across it.*

## C. The Guide's lore paintings (`art_inbox/chatgpt/lore/`)

**1536x1024**, x2 each; I crop to 960x540. These illustrate the codex entries.

21. **`lore_roadsong.png`** - *Four elements as weather over one road: fire,
    water, earth and air braided into a storm along a valley, the road lit
    beneath it.*
22. **`lore_the_chain.png`** - *A single chain link the size of a house driven
    into the earth, moss on the iron, a road worn around it, the beast's
    shadow falling over it.*
23. **`lore_kharok.png`** - *Kharok the Chainmaker: an immense armoured figure
    seen from below, a Warden's ruined cloak over black iron, a hammer, chains
    running from his gauntlets into the ground, no face visible, amber embers.*
24. **`lore_gatekeeper.png`** - *The Gatekeeper: a tall gaunt sentinel in old
    plate standing in a mountain gate, a chain through its own chest bolted to
    the gate posts, waiting, snow on its shoulders.*
25. **`lore_worldstriders.png`** - *Several colossal beasts walking a plain at
    dawn, each with something grown on its back - a forest, a ruin, a town -
    seen from very far away.*
26. **`lore_yuri.png`** - *Yuri's portrait: the beast's head close, ancient
    eyes, moss and plates, a lantern hung from one horn, the Warden's hand on
    the hide.*
27. **`lore_warden.png`** - *The Warden alone at a campfire on the beast's
    back, hood down but the skull face still in shadow, the lantern beside
    them, the banner planted.*
28. **`lore_host.png`** - *The Host: a column of many peoples marching under
    chain-banners, faces blank, driven forward, seen from above on a road.*
29. **`lore_the_hold.png`** - *The Hold at night from the road below, a warm
    gate in a dark hill.*
30. **`lore_first_cut.png`** - *The first cut: a Warden's sword striking a
    chain, sparks, the link half-parted, close and violent.*
31. **`lore_ascension.png`** - *A gate of light at the top of a stair, a lone
    figure passing through it, the world small behind.*
32. **`lore_road_cards.png`** - *Three tarot-like cards fanned on a stone,
    each a painted omen - a storm, a flame, a wolf - lit by a lantern.*
33. **`lore_summit.png`** - *The beacon lit: the summit tower burning white at
    the top of the world, the chains falling away from a beast far below.*

## D. Act-end and boss cards (`art_inbox/chatgpt/bosses/`)

When an act boss falls, the game holds the thing that was killed up
full-screen. Today that is its sprite. **1024x1024 each, x2 [alpha]** - a
painted three-quarter portrait, chest up, lit by amber from the upper right,
with the transparency clause; I set it on the game's own inked plate.

34. **`boss_mistwarden.png`** - *Hollow Ard, the Mistwarden: a bog-lantern
    warden of the Hollow Marches, a hollow reed mask, fog pouring from the
    ribs, a crane-skull staff.*
35. **`boss_mirrorfang.png`** - *Veyr of the Sunglass, Dune Seer: a desert
    prophet wrapped in glass-sewn robes, a mirrored fang mask, sand running
    from the sleeves.*
36. **`boss_rust_crown.png`** - *Mogrun White-Maw, Avalanche King: a huge
    snow-bear king in a crown of rusted iron, ice in the fur.*
37. **`boss_drowned_choir.png`** - *Rakka Coal-Eye, Wolf Marshal: a scarred
    wolf-marshal in mail with one ember eye, a war-horn of bone.*
38. **`boss_rustmother.png`** - *The Rustmother: a machine-mother of the
    Rustwood, iron and autumn leaf, a cradle of gears at the chest.*
39. **`boss_brinefather.png`** - *The Brinefather: a salt-crusted giant of the
    Saltpan Mire, crab-plate armour, brine dripping.*
40. **`boss_horde_warlord.png`** - *Khatun Var, Who Rides Last: a steppe
    warlord on a horse skull standard, wind-burned, a lance of black iron.*
41. **`boss_glass_colossus.png`** - *The Shatterfather: a colossus of blue
    glacier ice with a city's towers frozen in its chest.*
42. **`boss_cinder_titan.png`** - *Ashgild the Unquenched: a titan of ash
    with a furnace heart, embers falling like snow.*
43. **`boss_last_anchor.png`** - *The Last Anchor: a chain-spike the size of a
    tower driven into stone, a face forming in the iron, chains radiating.*
44. **`boss_gatekeeper.png`** - the Gatekeeper as in 24, chest up.
45. **`boss_chainmaker.png`** - Kharok as in 23, chest up, the one face left
    unseen.

## E. Portraits for cards and screens (`art_inbox/chatgpt/portraits/`)

**1024x1024, x2 [alpha]**, chest-up, front three-quarter, amber key light.

46. **`portrait_warden.png`** - *The Warden, hood up, skull face, lantern
    light from below, red sash - for the Warden's card and the creation
    screen.*
47. **`portrait_yuri.png`** - *Yuri's head, for the beast card.*
48. **`portrait_halric.png`** - *Halric the stable-master: a weathered horse
    handler in a felt coat, rope over the shoulder, kind and tired.*
49. **`portrait_blacksmith.png`** - *The Hold's smith: broad, scarred forearms,
    a leather apron, hammer over the shoulder, forge-lit.*
50. **`portrait_vendor.png`** - *The Long Ledger's keeper: a thin clerk in a
    travelling coat with a ledger chained to the wrist, a lantern.*
51-54. **`mount_ash_courser.png`, `mount_marsh_pony.png`,
    `mount_steppe_horse.png`, `mount_terrace_stag.png`** - *head-and-neck
    portraits: a smoke-grey and charcoal courser with ember eyes; a shaggy
    dun marsh pony; a tall bay steppe horse; a pale stag with mossy antlers.*

## F. The interface kit (`art_inbox/chatgpt/ui/`)

All **[alpha]**, flat, front-on, symmetrical, painted texture not vector.
Generate at 1024x1024 unless said. **Leave the centre empty** where the game
draws its own contents.

55. **`frame_carved_stone.png`** - x3. *A rectangular frame of carved dark
    stone with moss in the joints and a worn amber-bronze inlay line, corners
    heavier than edges, the whole centre empty and transparent; a 9-slice
    border for panels.*
56. **`frame_iron_banded.png`** - x2. *The same, in black iron bands with
    rivets, for the pause and settings panels.*
57. **`plate_parchment.png`** - 1536x1024, x2. *A sheet of aged parchment,
    stained, edges torn and slightly curled, no writing, for tooltips and
    the codex.*
58. **`button_stone.png`** - x3. *A wide low button plate of carved stone with
    a bronze edge, three rows stacked: rest, lit (amber glow in the edge),
    pressed (darker, sunk).*
59. **`tab_stone.png`** - *A tab plate: a stone tongue with a bronze pin,
    two states side by side, rest and chosen (amber lit).*
60. **`bar_frame_vitals.png`** - 1536x1024. *Three empty horizontal bar
    frames stacked: heavy iron for health, a silver-blue filigree for mana, a
    leather-strap for stamina; hollow inside.*
61. **`bar_frame_town.png`** - *A wide empty bar frame of stone crenellations
    for the town's health.*
62. **`bar_frame_boss.png`** - *A wide empty bar frame of black iron and
    chain for a boss's health, a skull boss at each end.*
63. **`card_frame_rarity.png`** - 1536x1024, x2. *Seven card frames in a row,
    empty centres, each a step up: rough wood; sound oak; brass; silver with
    a blue stone; gold with a red stone (Oathbound); black iron broken chain
    (Chainbroken); antler and moss with a green flame (Beastcalled).*
64. **`slot_frame_rarity.png`** - 1536x1024. *The same seven as square
    inventory slots.*
65. **`frame_minimap_round.png`** - *A round frame of carved stone and bronze
    with a compass rose worked into the top, empty centre.*
66. **`compass_rose.png`** - *A worn bronze compass rose, eight points.*
67. **`ribbon_wave.png`** - 1536x1024. *A red banner ribbon on a bronze rod
    for announcements, empty centre, ends torn.*
68. **`frame_wardens_glass.png`** - 1024x1536. *An ornate tall mirror frame of
    black iron and antler, a lantern hung at the top, empty centre - the
    character creation screen.*
69. **`plate_ledger.png`** - *A heavy ledger book lying open, blank pages, a
    chain at the spine, for the market.*
70. **`plate_anvil_forge.png`** - *An anvil on a stump with tongs and a
    glowing coal bed, for the Smithy's plate.*
71. **`medal_achievement.png`** - 1536x1024. *Three round medals side by
    side, empty centres: bronze, silver, gold, each hung on a short red
    ribbon.*
72. **`knob_slider_and_toggles.png`** - *A small kit on one sheet: a bronze
    slider knob, a stone slider track, a toggle in two states, a checkbox in
    two states, a dropdown arrow, a scroll grip.*
73. **`cursor_set.png`** - *Six cursors in a row, each 128px in feel: an
    arrow of bone, a pointing gauntlet, a crossed-swords attack, a hammer for
    build, a wrench for repair, an hourglass for busy.*

## G. Icon sets the game has none of (`art_inbox/chatgpt/icons/`)

**1024x1024 each [alpha]**, one object, bold silhouette that reads at 64px,
front-on, painted. I downscale to 128.

74-78. **Professions** - `prof_angler.png` (a rod and a leaping fish),
    `prof_woodcutter.png` (an axe in a stump), `prof_miner.png` (a pick and a
    raw gem), `prof_smith.png` (a hammer on an anvil), `prof_farmer.png` (a
    sickle and a sheaf).
79-82. **Doctrines**, for the act-start choice - `doctrine_bulwark.png` (a
    stone tower shield), `doctrine_measured.png` (a balanced scale on a
    sword), `doctrine_spire.png` (one tall tower with a beacon),
    `doctrine_warband.png` (three banners crossed).
83-85. **Difficulties** - `tier_normal.png` (a plain iron crest),
    `tier_nightmare.png` (the crest with a horned skull), `tier_hell.png` (the
    crest burning, chains).
86-92. **Map modes**, small landscape thumbnails, opaque, 1536x1024 each -
    *a stylised overhead map painted on parchment*: `map_classic.png` (four
    winding roads to a walled town), `map_keep.png` (two walls, roads doubling
    back), `map_citadel.png` (one wall, gates east and west), `map_beast_axis.png`
    (a spine with ribs), `map_confluence.png` (two braided trunks),
    `map_four_rings.png` (a braided ring on each road), `map_wild_roads.png` (a
    tangle), and `map_random.png` (dice on the parchment).
93-104. **Ascension ranks**, twelve badges - `ascension_01.png` ...
    `ascension_12.png` - *one badge shape, an iron ring, growing: a single
    notch; two; three; a gate; a gate with light; two flames; three; a cut
    chain; a broken chain; a road; a horn; the beast's silhouette in the
    ring.* Titles for your reference: Warden, Tested, Twice-Tested,
    Thrice-Tested, Gate-Passed, Ascended, Twice-Ascended, Thrice-Ascended,
    Chain-Cutter, Unbound, Roadsworn, Worldstrider's Own.
105-128. **Achievements**, twenty-four, each one object: `ach_first_road.png`
    (a milestone stone), `ach_first_boss.png` (a fallen crown), `ach_first_camp.png`
    (a burning tent), `ach_first_fork.png` (a forked road sign), `ach_first_fish.png`
    (one fish on a line), `ach_fifty_fish.png` (a full creel), `ach_first_spirit.png`
    (a paw print glowing), `ach_first_coop.png` (two lanterns), `ach_first_rift.png`
    (a torn portal), `ach_first_dungeon.png` (a stair into dark), `ach_first_war_camp.png`
    (a broken totem), `ach_first_win.png` (the beacon lit), `ach_hundred_kills.png`
    (a notched blade), `ach_thousand_kills.png` (a skull pile), `ach_level_twenty.png`
    (a bronze laurel), `ach_level_forty.png` (a silver laurel), `ach_ten_bosses.png`
    (ten small crowns in a ring), `ach_ten_roads.png` (a worn boot), `ach_swimmer.png`
    (a wet boot dripping), `ach_twenty_camps.png` (a sacked banner), `ach_act_five.png`
    (a stair half climbed), `ach_act_ten.png` (the terrace stair), `ach_ascended.png`
    (the gate of light), `ach_codex_half.png` (an open book, half the pages lit).

## H. Cinematic and ending frames (`art_inbox/chatgpt/story/`)

**1536x1024, x2 each.** The four opening panels exist as pixel paintings;
these are the endings and the between-act punctuation, which are shown alone.

129. **`ending_beacon_lit.png`** - *Victory: the beacon burning at the summit,
     the last chain falling from Yuri's neck into cloud, the Warden small on
     his back, dawn.*
130. **`ending_home_again.png`** - *A return: the beast walking home along a
     quiet road at evening, the town lit, the Warden sitting on the wall.*
131. **`ending_fall.png`** - *A fall: the lantern lying on the road in the
     rain, still lit, the beast's shape walking on into fog without its
     Warden.*
132. **`act_end_plate.png`** - 1536x1024, x2 **[alpha]**. *An inked, torn
     plate with a chain motif and an empty centre, to sit behind a boss
     portrait when an act ends.*

## I. Not on this list, on purpose

- **Anything that stands on the field** - units, towers, buildings, plants,
  animals, tiles, projectiles: PixelLab, so it matches the roster.
- **The wordmark**: it exists (gold and stone) and is the identity; a second
  one is a second identity.
- **The Guide's how-to pictures**: those are photographs of the real game
  (`guide_shots`), and must stay so.
- **Sky, weather, water, fog, blood, light**: shaders and forged sheets; a
  painting cannot move.
