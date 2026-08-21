# BEAST ROAD — Pixellab AI prompt book

Everything needed to generate this game's art in Pixellab: the decision to make
first, exact sizes and paths, the style block that makes 187 images look like one
game, and the prompts.

Companion to `ASSET_MANIFEST.md` (the machine-read source of truth for paths and
sizes) and `ASSET_PROMPTS.md` (the existing ChatGPT/Midjourney book).

---

## 0. Read this before spending a single generation

**Production update, 2026-08-20:** the structure animation and building-tier
batch described by the later owner ruling is complete. The live source of truth
for its four-pose package, prompt templates, paths and correction process is
`STRUCTURE_ART_PIPELINE.md`. This larger prompt book remains useful for source
art direction and any future full-style pass, but its old priority list is
historical.

The asset report currently says:

```
All 590 manifest assets exist. 590 have real art.
```

There is no unfilled manifest gap. New or replacement art is an art-direction
task and still lands only with an exact manifest path.

**Pixellab makes pixel art. Beast Road's 187 assets are painterly.** The house
style in `ASSET_MANIFEST.md` §1 is "dark painterly grim-fantasy game art,
hand-painted texture, visible brushwork, **no black outlines**", and the shipped
sprites match it: soft gradients, baked amber rim light, smooth alpha edges.

These two facts mean there is no partial path. Every asset shares the screen with
every other one, so a pixel-art tower standing beside a painterly one reads as a
bug, not as a style. **Using Pixellab for shipped art is a decision to restyle the
whole game.** That is an owner call, not a technical one.

### The honest trade

**For the pivot:**

- **Real animation.** This is the big one. `sprite_animator.gd` opens with: *"Every
  asset in this game is one static PNG. There are no frames, no rigs and no
  spritesheets — so all motion has to come from what can be done to a transform."*
  Every walk, hit, death and idle in the game is currently a procedural squash,
  lean or spin. Pixellab generates actual animation frames. That is the single
  largest visual upgrade available to this project, and no other tool here offers
  it.
- 192x192 is a *large* pixel canvas. This would be chunky, detailed pixel art, not
  8-bit minimalism.
- One tool plus a style reference locks cohesion far better than three tools did.
- Cheap iteration, and it is paid for either way.

**Against:**

- 187 assets to redo, and the current set is finished and cohesive.
- **The lighting system was tuned for painterly sprites.** The game runs real
  `PointLight2D` lights with shadow casters, plus baked amber rim light *inside*
  each sprite. Pixel art normally bakes all its lighting and can look wrong under
  dynamic lights — flat where the paint expects form. This is the technical risk,
  and it is not hypothetical: torches, tower lights, damage flames and the
  see-through occluder fade all push light across these sprites at runtime.
- A friend is dev-testing the current build. A half-restyled game is worse to test
  than either finished style.

### What to do instead of deciding blind

**Run the pilot in §4.** Three assets, exact sizes, dropped into the real game
under the real lighting. Half an hour answers a 187-asset question, and it answers
the lighting risk specifically — which no amount of looking at generated images on
their own will.

If the pilot looks good, the rest of this document is the production run. If it
does not, three generations is a cheap way to find out.

---

## 1. Universal specs

**Dimensions are contractual.** `ASSET_MANIFEST.md` §4: *"Exact dimensions from the
table. Not 'close enough' — the collision and layout code assumes them."*

| Group | Path | Size | Count | Transparent |
|-------|------|------|-------|-------------|
| Hero | `res://art/hero/` | 128x128 | 3 | yes |
| Enemies + elites | `res://art/enemies/` | 192x192 | 24 | yes |
| Bosses | `res://art/bosses/` | 384x384 | 3 | yes |
| Towers | `res://art/towers/` | 192x192 | 26 | yes |
| Buildings + plots | `res://art/city/` | 192x192 | 11 | yes |
| City shell | `res://art/city/` | 512x512 | 4 | yes |
| Beast | `res://art/beast/` | 1024x1024 | 1 | yes |
| Grid tile overlay | `res://art/battlefield/` | 128x128 | 2 | yes |
| Lane path | `res://art/battlefield/` | 256x256 | 1 | yes |
| Town core | `res://art/battlefield/` | 384x384 | 1 | yes |
| Captives | `res://art/raid/` | 128x128 | 3 | yes |
| Chieftains | `res://art/raid/` | 256x256 | 3 | yes |
| Relic icons | `res://art/icons/relics/` | 128x128 | 27 | yes |
| Spell icons | `res://art/icons/spells/` | 96x96 | 8 | yes |
| UI icons | `res://art/icons/ui/` | 128x128 | 30 | yes |
| Discipline icons | `res://art/icons/disciplines/` | 192x192 | 24 | yes |
| Cursors | `res://art/cursors/` | 64x64 | 6 | yes |
| Terrain tiles | `res://art/terrain/` | 512x512 | 3 | **no — must tile** |
| Backdrops | `res://art/bg/` | 1920x1080 | 6 | no |
| UI panels | `res://art/ui/` | 256x256 | 2 | yes |
| UI buttons | `res://art/ui/` | 256x88 | 2 | yes |
| UI bars | `res://art/ui/` | 128x16 | 2 | yes |
| UI slot | `res://art/ui/` | 128x128 | 1 | yes |
| Logo | `res://art/ui/` | 1024x512 | 1 | yes |
| Splash | `res://art/ui/` | 1920x1080 | 1 | no |

### Generate at native size

This is the one place Pixellab differs sharply from the ChatGPT workflow in
`ASSET_PROMPTS.md`. That book says *"generate at 1024x1024 and downscale"*, which
is right for painterly art and **wrong for pixel art** — downscaling destroys the
pixel grid and produces mush.

**Generate pixel art at the exact target size.** 192x192 for a tower, 128x128 for
an icon. If a smaller native canvas plus an upscale gives a better result, scale by
a whole-number factor (2x, 3x, 4x) with nearest-neighbour — never a fractional
scale.

### Filenames and the importer

Save with **exactly** the filename the game expects; the folder does not matter.
Drop everything into `art_inbox/` at the repo root and run:

```
tools\import_art.ps1
```

It resizes to the exact target, verifies transparent assets really carry an alpha
channel, files each one at its `res://art/...` path, and reports anything it could
not match. Nothing is filed by hand.

`snake_case`, PNG only, no version suffixes. Never rename a file to fix a
problem — fix the `id` in the `.tres`.

---

## 2. The style block

Paste this into every prompt, or set it once as the project style. This is the
existing house palette, unchanged, so a restyle stays the same *game*.

```
STYLE: dark grim-fantasy pixel art, chunky detailed pixels, limited palette,
strong readable silhouette, subtle dithering for gradients, no anti-aliasing on
outer edges, transparent background.

LIGHT: warm amber key light from the upper right, deep teal-black shadow on the
lower left, one bright rim highlight along the top-right contour.

PALETTE: shadow #0B1416, slate #1E2E33, amber #E8A33D, bone #D9CDB8,
rust #8C3A2B. Muted and desaturated overall with a single saturated accent.
```

### Per-act accents

The block above is the house style and applies to everything. On top of it, v4
§175-197 gives each region its own identity, and enemies, terrain and backdrops
should carry their region's:

| Act | Region | Accent palette |
|-----|--------|----------------|
| I | The Verdant Maw | saturated wet greens, charcoal black, ember orange |
| II | The Sunglass Waste | pale sand, red cloth, turquoise glass, long black shadows |
| III | The White Teeth | blue snow, black stone, pale aurora, red warning cloth |

The amber key light stays constant across all three — it is the town's light, and
v4 names it in every act ("warm town light against cool rain", "warm windows on
Yuri"). Shift the *shadow* and the *accent*, never the key.

Hero, towers, buildings and UI stay on the house palette only. They travel through
all three regions and must not belong to any one of them.

### Camera — the rule that matters most

`ASSET_MANIFEST.md` §3 learned this the hard way: a single stem produced eye-level
concept art for a top-down game. There are two cameras, not one.

| Subject | Camera |
|---------|--------|
| Hero, enemies, bosses, chieftains, captives | **~45 degrees above**, closer to side-on |
| Towers, buildings, plots, town core, beast | **~60 degrees above**, steeply top-down |
| Icons, cursors, UI | **flat, front-on, no perspective** |

Characters are drawn flatter than buildings on purpose. A human at 60 degrees is a
head and two shoulders with no silhouette worth looking at.

### Locking the style

Generate one asset worth keeping — **`tower_ember_spire` is the right choice**; it
is the signature tower and carries fire, stone and metal in one image. Then use it
as the style reference for everything else. This is the pixel-art equivalent of the
`--sref` trick the Midjourney half of the old book relies on, and it is what makes
187 images look like one game instead of 187 pictures.

---

## 3. Completed item-icon source

`ui_resurrection_draught.png` — 128x128 — `res://art/icons/ui/`

Completed 2026-08-20 with PixelLab Pixflux job
`63a0379a-87c4-4639-af1e-cbf2cb44d496` (seed `81061`). The HUD now resolves the
item's convention path directly and the manifest/production-art gate covers it.
Keep the prompt below as the exact reroll brief.

```
[STYLE BLOCK]

A single game UI icon, flat front-on with no perspective, 128x128 pixel art.

SUBJECT: a small sealed glass vial of dark red liquid, a cracked wax seal over its
stopper, a single amber highlight catching the glass, bone-coloured cord wrapped
at the neck.

Flat two-tone amber and bone. Thick readable shapes. No gradient, no frame, no
text, no border. Transparent background.
```

---

## 4. The pilot — do these three first

Three assets, three cameras, one lighting test. Generate them, drop them in
`art_inbox/`, run `tools\import_art.ps1`, launch the game.

**What matters is not whether the sprites are nice.** It is whether they survive
the lighting: stand a tower next to a lit torch and watch what the `PointLight2D`
does to it. Painterly sprites absorb that light. Pixel art with baked shading can
fight it and go flat or muddy.

### 4.1 `tower_ember_spire.png` — 192x192

```
[STYLE BLOCK]

A game structure sprite seen from about 60 degrees above, steeply top-down as in a
tower-defense game. 192x192 pixel art, transparent background.

SUBJECT: a slender tall stone spire capped with an open burning brazier, narrow
iron banding around the shaft, embers rising from the top.

The whole shape must read clearly at 64 pixels. Standing on nothing — no ground,
no base plate, no shadow, no scenery.
```

### 4.2 `enemy_coalpaint_raider.png` — 192x192

The first enemy the player ever meets. **Not `enemy_bogkin.png`** — that file
exists and nothing loads it; see §5.2.

```
[STYLE BLOCK]

A game character sprite seen from about 45 degrees above, closer to side-on than
top-down. 192x192 pixel art, transparent background.

SUBJECT: a jungle raider of the Cinderpaint Host in layered leather and bark
armour smeared with black coal paste in broad handprint marks, short heavy blade,
wet green cloth, aggressive close stance.

Full body, facing three-quarter left, standing on nothing — no ground, no shadow.
The silhouette must read clearly at 64 pixels.
```

### 4.3 `hero_base.png` — 128x128

```
[STYLE BLOCK]

A game character sprite seen from about 45 degrees above, closer to side-on than
top-down. 128x128 pixel art, transparent background.

SUBJECT: a lone armored scavenger-warrior in a mid-stride combat stance, curved
single-edged blade held low, tattered dark cloak, bone-white featureless mask,
lean wiry silhouette, scavenged plate over wrapped cloth.

Full body, facing three-quarter left, standing on nothing — no ground, no shadow.
```

---

## 5. Production run — subjects by group

Every subject below is the one the existing art was made from, so a restyle depicts
the same world. Wrap each in the matching camera line from §2 and the style block.

### 5.1 Hero — 128x128

**See §11, the Warden character bible.** The hero is the only asset generated once and
then multiplied into eight directions and eight animation states, so it has a section of
its own with the full prompt, the silhouette contract and the exclusions that stop the
model drifting into a skeleton king.

Generate **`hero_base` only**. `hero_ascended_1` and `hero_ascended_2` are v3 leftovers
that no shipped code references, and v4's ascension is a single Keystone (§24) that has no
visual design yet.

### 5.2 Enemies and elites — 192x192

**These are the v4 roster and they replaced a v3 one.** `ASSET_MANIFEST.md` still
describes Bogkin, Glassborn, Steppehorde, Warden, Howler and Burrower — v3
creatures the game no longer renders. `EnemyData` carries a `sprite_id` override,
so the id `bogkin` loads `enemy_coalpaint_raider.png`. Six art files in
`art/enemies/` are dead: `enemy_bogkin`, `enemy_glassborn`, `enemy_steppehorde`,
`elite_warden`, `elite_howler`, `elite_burrower`. **Generating any of those six is
wasted work — nothing loads them.**

The eighteen below are the live set, matching v4 §397-399 exactly: four regulars
and two elites per region. Subjects are drawn from each act's visual identity in
v4 §175-197 and each enemy's `description` in `game/data/enemies/*.tres`, so the
art states the enemy's job — which is v4 §375's requirement: *"Every enemy must
have a readable job."*

**Act I — The Verdant Maw.** The Cinderpaint Host: rain-heavy jungle, coal paste
marking armour, smoke, roots, wolf cavalry. Palette: saturated wet greens,
charcoal black, ember orange.

| File | Subject |
|------|---------|
| `enemy_coalpaint_raider` | a jungle raider in layered leather and bark armour smeared with black coal paste in broad handprint marks, short heavy blade, wet green cloth, aggressive close stance |
| `enemy_wolf_rider` | a light raider mounted on a lean grey jungle wolf, low forward charge, coal-marked shoulder plate, short spear couched |
| `enemy_rootshield` | a broad slow figure carrying a living barricade of woven roots and bark taller than its body, moss and creeper hanging from the frame, almost no body visible |
| `enemy_ember_shaman` | a robed ranged supporter swinging a smoking iron censer on a chain, ember orange glow lighting the face from below, charms of bone and coal at the belt |
| `elite_pack_howler` | a tall coal-marked caller with an oversized curved bone horn raised to its mouth, ragged banner strapped to its back, throat distended, arms flung wide |
| `elite_wolf_standard_bearer` | an elite rider on a heavy black wolf, a tall ragged war standard of bone and green cloth planted upright at its shoulder, commanding posture |

**Act II — The Sunglass Waste.** The Veiled Scale-Riders: fused sand, buried
roads, mirage storms, lizard mounts, reflective armour, javelins, tunnelling
scouts. Palette: pale sand, red cloth, turquoise glass, long black shadows.

| File | Subject |
|------|---------|
| `enemy_veiled_skirmisher` | a fast lightly built desert fighter wrapped head to foot in pale sand cloth with a red sash, thin javelin, forward-leaning sprint, brittle unarmoured frame |
| `enemy_scale_rider` | a rider low on the back of a running desert lizard, turquoise glass scale barding, javelin levelled, built entirely for the charge |
| `enemy_glassguard` | a shield-wall soldier behind a tall mirrored slab of turquoise fused glass, reflective and featureless, planted immovably |
| `enemy_dune_burrower` | a segmented armoured digging creature erupting upward through fused sand, heavy clawed forelimbs, eyeless armoured head plate, sand sheeting off its back |
| `elite_mirage_seer` | a veiled ranged elite with a ring of floating mirrored glass shards orbiting its head like a halo, red robes, one hand raised, heat shimmer distorting the air around it |
| `elite_siege_lizard` | an enormous armoured desert lizard carrying a stone bombard strapped across its back, turquoise glass plating, heavy and low to the ground |

**Act III — The White Teeth.** The Rimebound Clans: frozen mountain approach,
massive orcs, ice-clad siege carriers, storm callers. Palette: blue snow, black
stone, pale aurora, red warning cloth.

| File | Subject |
|------|---------|
| `enemy_rime_marauder` | a hard-running orcish axe fighter in frost-rimed black iron plate, red warning cloth wrapped at the arm, breath steaming, two-handed axe carried mid-run |
| `enemy_ice_hauler` | a heavy figure dragging a chained iron sled loaded with ice blocks, thick chains over the shoulder, leaning hard into the pull, enormous mass |
| `enemy_snowhide_brute` | a horned slab of white fur and black iron, hunched and enormously wide, small eyes, built to stand in a road and not move |
| `enemy_storm_caller` | a ranged supporter in pale furs holding a black stone staff crowned with hanging ice, snow spiralling around its raised arm, aurora light on its shoulders |
| `elite_avalanche_warden` | a colossal elite behind a wall-sized shield of blue glacier ice bound in black iron, dense immovable silhouette, almost no body visible |
| `elite_white_maw_giant` | a towering white-furred giant with a vast frost-crusted club raised overhead, tusked lower jaw, red cloth bound around one arm, monumental scale |

### 5.3 Bosses — 384x384

| File | Subject |
|------|---------|
| `boss_drowned_choir` | a towering mass of fused drowned bodies forming a single cathedral-like figure, dozens of open singing mouths across its surface, black water pouring continuously from its frame, tattered ceremonial cloth, immense and vertical |
| `boss_mirrorfang` | an enormous predatory quadruped beast built from mirrored salt glass, overlapping reflective shard plating, long fanged skull, refracted amber light scattering off its flanks |
| `boss_rust_crown` | a colossal armored warlord fused to a throne of corroded iron, a crown of jagged rusted spires grown into its skull, chains and torn banners hanging from its shoulders, monumental scale |

### 5.4 Towers — 192x192

**Sixteen base towers, four per element, one per role** (GDD §21, revised
2026-08-18). Eight exist; **eight are new and marked**. Fusions are keyed by
element pair, not tower pair, so the ten combination towers are unchanged and no
new fusion art is needed.

The four roles read the same across all four elements, and the silhouette should
say which role a tower is before the player reads anything:

| Role | Silhouette rule |
|------|-----------------|
| **Skirmisher** | small and low, wide base, no tall mast |
| **Siege** | squat and heavy, thick barrel or arm, visibly massive |
| **Sniper** | tall and thin, one long straight line pointing up and out |
| **Warden** | no barrel at all — a frame, a bell, a censer, a vane |

**Fire — escalation.** Amber and rust, blackened iron, visible flame.

| File | Role | Subject |
|------|------|---------|
| `tower_ember_spire` | Skirmisher | a slender tall stone spire capped with an open burning brazier, narrow iron banding, embers rising from the top |
| `tower_pyre_cannon` | Siege | a squat heavy siege cannon of blackened iron with a glowing fire-chamber, wide short barrel, mounted on a stone base |
| **`tower_cinder_lance`** | Sniper | **NEW** — a very tall narrow tower of black iron ending in one long straight lance-barrel angled upward, a small white-hot furnace glowing at its base, heat haze along the barrel |
| **`tower_ashen_censer`** | Warden | **NEW** — a heavy stone frame holding a huge perforated iron censer on chains, thick grey smoke and orange embers pouring from its vents, no barrel of any kind |

**Water — control.** Pale blue-white, frost, bronze and wet stone.

| File | Role | Subject |
|------|------|---------|
| **`tower_tide_caller`** | Skirmisher | **NEW** — a low wide basin of dark wet stone on a squat plinth, ringed with small carved spouts, pale blue water arcing continuously from its rim |
| **`tower_glacial_mortar`** | Siege | **NEW** — a fat short-barrelled mortar of frost-caked bronze angled steeply upward, packed ice shells stacked at its base, cold vapour spilling over the rim |
| `tower_rime_lance` | Sniper | a tall narrow tower of pale stone ending in a single frost-encrusted spear point, sheets of blue-white ice down one side |
| `tower_hoarfrost_bell` | Warden | a heavy stone frame holding a large frost-covered bronze bell, long icicles hanging from its rim |

**Earth — denial.** Grey and ochre stone, raw rock, iron banding.

| File | Role | Subject |
|------|------|---------|
| **`tower_grit_sling`** | Skirmisher | **NEW** — a small squat timber-and-rope sling frame on a low stone pad, a basket of loose grey stones beside it, the simplest and cheapest structure on the field |
| `tower_shard_thrower` | Siege | a mechanical ballista of stone and iron loaded with a single long jagged rock shard, tensioned cables |
| **`tower_stonewatch`** | Sniper | **NEW** — a tall narrow watch-spire of stacked grey blocks with a hinged release arm at its crown holding one enormous boulder, iron counterweight hanging behind |
| `tower_bulwark` | Warden | a squat fortified stone bunker with layered overlapping shield plating, heavy and wide, almost no ornament, built to absorb |

**Air — reach.** Pale violet, copper, thin metal, visible motion.

| File | Role | Subject |
|------|------|---------|
| `tower_gale_turret` | Skirmisher | a slim tower with spinning bladed vanes and open wind funnels at its crown |
| `tower_arc_coil` | Siege | a metal tower wrapped in tiered copper coils, arcs of pale violet lightning crackling between the rings |
| **`tower_zephyr_needle`** | Sniper | **NEW** — an extremely tall and impossibly thin copper needle on a narrow tripod, guy-wires running to the ground, a single point of violet light at the very tip |
| **`tower_stormvane`** | Warden | **NEW** — a tall open frame carrying four large spinning brass weather-vanes at different heights, torn streamers snapping outward, no weapon of any kind |

Ten combination towers complete the set of 26 — ids and elements are in
`game/data/towers/*.tres`. Each should read as its two parents fused, not as a
third unrelated object.

### 5.5 City — buildings 192x192, shell 512x512

| File | Subject |
|------|---------|
| `city_base` | a small fortified settlement built on a curved platform of vast bone and lashed timber, tiered stone buildings, banners, chimney smoke, defensive palisade around the rim |
| `city_damage_1/2/3` | the same settlement progressively ruined — (1) scorch marks, a collapsed roof, torn banners; (2) several buildings burned to frames, palisade breached, fires burning; (3) mostly rubble, only the town hall standing, everything blackened |
| `building_town_hall` | a tiered stone hall with a heavy timber roof and a relic-socket frame above its door, banners on both sides |
| `building_forge` | a squat stone forge with a glowing open furnace mouth, anvil outside, smoke stack |
| `building_sanctum` | a narrow stone shrine with a burning bowl on a pedestal and hanging chains, ritual markings on the walls |
| `building_granary` | a rounded timber and stone storehouse with sacks and barrels stacked outside, thatched roof |

**The damage stages must align pixel-for-pixel with `city_base`.** Generate the base
first, then inpaint on a copy of it for each stage rather than generating three
separate settlements — the game crossfades between them.

### 5.6 Beast — 1024x1024

`beast_profile` — an immense ancient six-legged beast walking across a wasteland,
shaggy and armored, a small fortified city strapped to its back with vast chains,
**seen in full side profile**, colossal scale, one figure-sized detail for scale.

### 5.7 Terrain — production Wang sets

**Production override, 2026-08-20.** The runtime no longer uses one 512px repeat.
Each act ships a 16-piece 64×64 Wang floor plus a 16-mask 64×64 connected road.
The final PixelLab sources are recorded here because their deliberately darker
brief supersedes the brighter v4 concept wording below:

| Act | Wang ground source | Connected-road source |
|-----|--------------------|-----------------------|
| Verdant Maw | `e4e4aea3-4419-4236-a58e-afbf27f0893b` | `c790502f-d1b4-4083-bfcb-087722c9ef97` |
| Sunglass Waste | `ba47b7ff-94be-47b4-9329-9108124f0cc9` | `975f6f07-2d46-4343-b763-8d892fdf8d5b` |
| White Teeth | `a71e043a-8492-4a65-94f5-4a3e30e4d329` | `b13cd460-1930-49aa-a968-1f156d9ce40b` |

Ground prompt rule: `FLAT COPLANAR`, directly overhead, two dark surfaces at the
same ground height, restrained low saturation, no props, no repeating motif,
and explicitly no cliff, wall, bank, ledge, rim, bevel or bright highlight.
Act I is wet umber loam/blue-green standing water; Act II is near-black smoky
umber hardpan/medium-dark blue-grey saltglass; Act III is nearly-black oxblood
basalt/dirty steel-blue snow film. `tools/conform_ground.py` clamps palette and
exposure outliers without changing topology.

Road prompt rule: directly overhead flat traversable surface, preserve the
N/E/S/W edge contract, dark ruts and sparse material-specific grit, no slab or
elevation. Jungle and snow sources were whole-number nearest-neighbour enlarged
to 64px after a semantic upscale changed their topology; desert used the accepted
64px edit job `bc3e0ae7-802b-4abf-a8bc-fee01d74c616`. The road builder owns the
final canonical silhouette and seam collar.

**The file ids are v3 and the subjects below are v4.** The three terrain resources
are still named `ashfen`, `saltglass` and `steppe`, with display names "Ashfen
Marsh", "Saltglass Flats" and "Iron Steppe" — the v3 regions. v4 §175-197 renamed
them and, for two of the three, changed what they *look like*. See §10; the ids
stay, the art follows v4.

| File | v4 region | Subject |
|------|-----------|---------|
| `terrain_jungle` | The Verdant Maw | wet jungle floor, saturated green moss and broad leaves, black mud, thick exposed roots, standing rainwater catching light |
| `terrain_desert` | The Sunglass Waste | cracked flat of fused pale sand, turquoise glass shards embedded in the crust, thin fracture lines, long hard shadows |
| `terrain_snow` | The White Teeth | packed blue-white snow over black stone, wind-scoured drifts, exposed dark rock edges, faint aurora light on the surface |

Use a **tileset / seamless** mode, not plain generation. Test by tiling 2x2 before
saving — a visible seam becomes a grid across the whole battlefield. No
transparency; these are opaque ground.

### 5.8 Backdrops — 1920x1080, opaque

| File | Subject |
|------|---------|
| `macro_act1` | a vast rain-heavy jungle basin stretching to the horizon, saturated wet greens, broken shrines swallowed by roots, low smoke drifting between the trees |
| `macro_act2` | an endless waste of fused pale sand under a bleached sky, distant turquoise glass formations catching light, violent heat shimmer, long black shadows |
| `macro_act3` | a frozen mountain approach of blue snow and black stone, narrowing passes, pale aurora across the sky, the silhouette of an immense peak on the horizon |
| `crossroad_bg` | a fork in an ancient road at dusk, two paths diverging into different distant landscapes, weathered stone waymarker in the foreground |
| `raid_arena_bg` | a hostile enemy warcamp seen from directly above, ringed by bone totems and burning braziers, packed dirt floor, tents at the edges |
| `menu_key_art` | an immense ancient beast walking away across a wasteland at dusk with a small lit fortified city on its back, seen from behind and below, dramatic scale, cinematic key art |

1920x1080 is far above a comfortable pixel-art canvas. Generate these at 480x270 and
scale 4x with nearest-neighbour, or 640x360 and scale 3x. Never generate at full
size and never scale by a fraction.

**`menu_key_art` last.** It becomes the Steam capsule; make it once the game's look
is settled.

### 5.9 Icons

| Group | Size | Stem |
|-------|------|------|
| Relics | 128x128 | *a single ancient ritual object, [object], worn and weathered, amber light catching one edge* |
| Spells | 96x96 | *a single glowing arcane sigil representing [concept], amber and violet light, rough hand-drawn ritual mark, no border* |
| UI | 128x128 | *a simple bold game UI icon, [thing], flat two-tone amber and bone, thick readable shapes, no gradient, no frame, no text* |
| Disciplines | 192x192 | as UI, but one clear emblem per node |

Relic objects: a cracked bone crown · a rusted iron heart · a sealed clay jar · a
knotted cord of teeth · a shattered mirror shard · a blackened iron key · a
wax-sealed scroll · a horn ring · a burnt feather · a river stone bound in wire · a
frost-split bone carapace · a coal sealed in an ice-and-black-iron reliquary · a
broken black-iron glacier spur · an ice-crazed whiteout lens.

Spell concepts: a blink through space · a bursting star · a protective barrier · a
draining hook · a chain and hook · a veil of ash · a shockwave ring · a beast's
exhaled breath.

**Icons are where pixel art wins hardest.** At 96–128px, flat two-tone shapes with
hard edges read better than painted ones. If the pilot is marginal, icons are still
worth doing.

### 5.10 UI frames — flat, symmetrical, empty centre

| File | Size | Subject |
|------|------|---------|
| `ui_panel` / `ui_panel_dark` | 256x256 | an ornate riveted dark iron panel frame, empty centre, symmetrical border |
| `ui_button` / `ui_button_hover` | 256x88 | a horizontal iron plate button, bevelled edge, empty centre; hover version lit warmer |
| `ui_bar_back` / `ui_bar_fill` | 128x16 | a narrow horizontal bar segment, plain and seamless left to right |
| `ui_slot` | 128x128 | a square recessed socket frame, empty centre |
| `ui_logo` | 1024x512 | the words BEAST ROAD in heavy weathered iron letterforms |

These are **nine-slice stretched by the theme**. The centre must be genuinely empty
and the border must survive stretching, so keep ornament in the corners and away
from the middle of each edge.

### 5.11 Battlefield — the grid and the roads

The 30x30 grid and the U-bend roads (GDD §13, revised 2026-08-18) change what
three existing files have to be, and add one requirement that does not exist yet.

**Repurposed — same paths, new job:**

| File | Size | Was | Now |
|------|------|-----|-----|
| `build_spot` | 128x128 | a fixed slot marker | the **buildable-tile ghost**: a 2x2 footprint outline shown under the cursor while placing. Four faint corner brackets on a barely-tinted fill, nothing in the middle — a real tower sprite sits inside it. |
| `build_spot_combo` | 128x128 | the combination slot | the **fusion-tile marker**: the same footprint in warm gold with a small linking mark on the two flanked edges, showing which pair it would fuse. |
| `lane_path` | 256x256 | a straight road piece | the **straight road tile**, seamless left-to-right so it repeats along a leg. |

**New requirement — road corners.** A U-bend needs corner pieces, and there is no
corner art. At minimum one 256x256 tile that turns the road 90 degrees, mirrored
and rotated in engine for the other three orientations; two (inner and outer
corner) if the road has a visible bank or kerb.

> Do **not** generate this until the manifest row exists. `ASSET_MANIFEST.md` §5
> is machine-read, and a row with only a placeholder behind it fails the
> production-art gate and blocks every release — which is exactly how the
> Resurrection Draught icon broke publishing on 2026-08-14. The row and the real
> art go in together, in one change. Say when the art exists and the row goes in
> with it.

```
[STYLE BLOCK]

A seamless top-down road corner tile for a game battlefield, seen from directly
above. 256x256 pixel art, opaque, no transparency.

SUBJECT: a packed dirt road turning ninety degrees, worn wheel ruts following the
curve, loose stones and scuffed edges where the verge meets the road.

The road must meet the tile edge at exactly the same width and position on both
open sides so it lines up with the straight tile. Tileable — no lighting gradient
across the tile, no vignette, no shadow.
```

**What the grid does not need.** No per-tile ground art: terrain tiles (§5.7)
already cover the field and the grid is drawn as an overlay, not painted. No
separate art for occupied versus empty tiles — the tower sprite is the occupancy
cue.

---

## 6. Pixellab techniques worth using

**Animation.** The reason to do this at all. The game has no animation frames and
fakes everything with transforms. **See §9** for the state list, the frame
contract, and the prompts.

**Rotation / 8-direction.** Enemies walk inward along four cardinal roads and the
hero moves freely. Directional sprites would remove the current sprite-flipping
compromise entirely. Worth doing for the hero first.

**Inpainting.** The right tool for `city_damage_1/2/3` — edit a copy of the base so
the silhouette stays put.

**Style reference.** Set `tower_ember_spire` once and leave it on. Single
highest-leverage setting in the whole run.

**Transparency.** Verify before saving. `import_art.ps1` refuses a transparent-type
asset that arrives fully opaque, so a bad export is caught, but catching it first is
faster.

---

## 7. What not to generate

- **Nothing outside `ASSET_MANIFEST.md` §5.** An asset in code but not in the
  manifest is a bug; a manifest row with no real art behind it blocks every release.
  Add the row and the art in the same change.
- **No VFX sprites.** Flames, embers, rings, sparks, torch fire and shadows are all
  drawn procedurally by `Vfx`, `Flame`, `ShadowKit` and `LightKit`. Generating them
  leaves files nothing loads.
- **No ground shadows baked into sprites.** Every unit and structure gets a real
  contact shadow at runtime. A painted-on shadow doubles up and reads as dirt.
- **No level tiers for towers.** Levels are a runtime scale, tint and light change
  on the one sprite.
- **No fixed build-spot markers.** Placement is a free 30x30 grid as of
  2026-08-18; the old slot art is repurposed in §5.11, not reproduced.
- **No road corner tile until its manifest row exists.** See the warning in
  §5.11 — a row with a placeholder behind it blocks every release.

---

## 8. Priority order

`ASSET_MANIFEST.md` §7 orders by kill question because a stage that fails wastes
every asset made for it. For a restyle the ordering differs — the game is already
proven — but the principle holds: **do not make 187 images before knowing the style
survives the lighting.**

1. The three pilot assets (§4). Stop and look at them in-game.
2. **The eight new towers** (§5.4) — they are the only genuinely missing gameplay
   art, and they are needed whether or not the restyle happens.
3. The other 18 towers and the three act-opening regulars — the most-seen sprites.
4. Hero, elites, city shell, terrain.
5. Icons, buildings, bosses, chieftains.
6. Backdrops and UI frames.
7. `menu_key_art`.

---

## 9. Animation states

### 9.1 The rule that decides how these frames should look

**The procedural motion stays on.** Owner decision: when frame animation replaces
the single images, the existing transform juice keeps running *on top of it* —
squash on footfall, recoil away from a hit, lean into movement, the beast-step
wobble, the dash stretch, the death topple.

That is a design choice with a direct consequence for what you generate:

> **Generate frames that are neutral in the channels the engine already drives.**

`sprite_animator.gd` owns bounce, lean, squash/stretch, recoil, spin and the
impact hold. If a walk cycle also bakes in a heavy vertical bob, the two multiply
and the character pogos. If a death animation bakes in a full topple, it spins
twice.

Concretely, per channel:

| Channel | Owned by | What to bake into frames |
|---------|----------|--------------------------|
| Vertical bounce | engine (`set_motion`) | a *little* — keep the body's rise under ~4px |
| Lean into movement | engine | none; keep the body upright |
| Squash on impact | engine (`squash`, `punch`) | none |
| Recoil away from a hit | engine (`recoil`) | none; the hurt frames are a flinch in place |
| Death spin and shrink | engine (`topple`) | the *collapse*, not the rotation |
| Dash stretch | engine (`dash`) | none |
| Limbs, weapon, cloth, effects | **frames** | everything |

The frames carry what a transform cannot: limbs moving independently, a weapon
arcing, cloth trailing, a mouth opening, a horn raised. The engine keeps carrying
weight and impact. Together that is far more than either alone, which is the whole
point of keeping both.

### 9.2 The frame contract

Nothing in the engine consumes frames yet, so this is the contract to generate
against. Say when a set exists and `sprite_animator.gd` will be wired to it, with
a fallback to the current procedural motion for any character that has no frames —
so a half-finished set never breaks the game.

- **One file per state.** `enemy_coalpaint_raider_walk.png`,
  `enemy_coalpaint_raider_windup.png`, and so on. Same `snake_case` id as the base sprite, then the state.
- **Horizontal strip, left to right.** No grids, no padding, no gaps.
- **Every frame is exactly the base size.** A 6-frame Coalpaint Raider walk is a
  1152x192 PNG. A 6-frame hero walk is 768x128.
- **The pivot must not move.** The engine positions the character; if the body
  drifts across the strip the character slides. Feet stay on the same pixel row,
  centre of mass on the same column.
- **Transparent background, no ground shadow.** Runtime contact shadows are drawn
  for every unit already; a painted one doubles up and reads as dirt.
- **Lighting stays fixed across frames.** Amber key from the upper right in every
  frame. A light that swings between frames strobes.

### 9.3 Hero — 128x128 per frame

Read §11 first — the base sprite, the eight-direction order and the pivot rule all live
there, and every state below is generated from that base.

The hero's attack is a **three-step chain**, and step 3 is the finisher — the
engine already gives it a 1.6x heavier squash, so the frames should read as a
bigger commitment too.

| State | Frames | Loop | Notes |
|-------|--------|------|-------|
| `idle` | 4 | loop | breathing, cloak settling |
| `walk` | 8 | loop | full stride cycle |
| `attack_1` | 5 | once | fast horizontal slash |
| `attack_2` | 5 | once | return slash, opposite direction |
| `attack_3` | 7 | once | the finisher — winds up further, lands harder |
| `dash` | 4 | once | low forward lunge |
| `hurt` | 3 | once | flinch in place |
| `death` | 8 | once | collapse; ends lying still |

```
[STYLE BLOCK]

An 8-frame walk cycle sprite animation for a game character, seen from about 45
degrees above, closer to side-on than top-down. Each frame exactly 128x128 pixel
art on a transparent background, laid out as a single horizontal strip.

SUBJECT: a lone armored scavenger-warrior — curved single-edged blade held low,
tattered dark cloak, bone-white featureless mask, lean wiry silhouette, scavenged
plate over wrapped cloth.

MOTION: a full walking cycle facing three-quarter left. Legs carry the stride, the
cloak trails and settles, the blade stays low. Keep the body upright and the
vertical bob very small — under four pixels. The feet stay on the same pixel row
in every frame and the body does not drift across the strip.

Fixed amber key light from the upper right in every frame. No ground shadow, no
scenery.
```

Swap the MOTION block for the other states:

- **idle** — *a 4-frame idle. Weight settles, chest rises and falls, the cloak
  drifts. Almost no movement — this plays under the engine's own idle bounce.*
- **attack_1** — *a 5-frame horizontal slash from the character's right to left.
  Frames 1-2 wind up, frame 3 is the contact, frames 4-5 follow through. The blade
  traces a clear arc. The body stays in place.*
- **attack_2** — *a 5-frame return slash, left to right, mirroring the first.*
- **attack_3** — *a 7-frame finishing blow. A longer wind-up, an overhead committed
  strike, a heavy follow-through. This is the biggest attack in the chain and must
  read as the heaviest.*
- **dash** — *a 4-frame forward lunge, body low and extended, cloak snapping out
  behind. No stretch baked in — the engine adds that.*
- **hurt** — *a 3-frame flinch: head snaps back, arms tighten, recovers. In place,
  no knockback — the engine moves the body.*
- **death** — *an 8-frame collapse. Knees fold, the blade drops, the body settles
  to the ground and stops. No rotation — the engine adds the topple.*

### 9.4 Enemies and elites — 192x192 per frame

The engine's enemy state machine is **WALKING → WINDUP → STRIKE → RECOVER**, plus
**DYING**. Those are the five, and the mapping is exact.

**`windup` is the most important animation in the game.** It is the telegraph the
player reads in order to dodge, and v4 §347 requires telegraphs to be visually
distinct. Make it loud: a raised limb, a drawn-back weapon, a widened stance, a
glow — something that reads at a glance with four roads on screen at once.

| State | Frames | Loop | Engine state |
|-------|--------|------|--------------|
| `walk` | 6 | loop | `WALKING` |
| `windup` | 4 | hold last | `WINDUP` — the telegraph |
| `strike` | 3 | once | `STRIKE` |
| `recover` | 3 | once | `RECOVER` |
| `death` | 6 | once | `DYING` |

```
[STYLE BLOCK]

A 4-frame attack wind-up sprite animation for a game enemy, seen from about 45
degrees above, closer to side-on than top-down. Each frame exactly 192x192 pixel
art on a transparent background, laid out as a single horizontal strip.

SUBJECT: a jungle raider of the Cinderpaint Host in layered leather and bark armour
smeared with black coal paste, short heavy blade, wet green cloth.

MOTION: the creature draws back to strike. Frame 1 begins the pull-back, frames
2-3 rear further, frame 4 holds at full extension ready to release. This is a
telegraph the player must read from across the screen — make the silhouette change
dramatically and obviously between the first frame and the last.

The feet stay on the same pixel row and the body does not drift across the strip.
Fixed amber key light from the upper right. No ground shadow, no scenery.
```

Swap the MOTION block for the other states:

- **walk** — *a 6-frame walking cycle, slow and lumbering, facing three-quarter
  left. Keep the vertical bob under four pixels.*
- **strike** — *a 3-frame release from the wind-up pose: the blow lands, fast and
  committed. Frame 1 is still drawn back, frame 2 is contact, frame 3 is full
  extension.*
- **recover** — *a 3-frame return from full extension back to the neutral walking
  pose, slower than the strike.*
- **death** — *a 6-frame collapse. The body gives way and settles to the ground. No
  rotation — the engine adds the topple.*

Each base enemy and elite uses the same five states with its own subject line from
§5.2. The elites deserve a longer, louder `windup` — they are the ones the player
is meant to notice: 6 frames rather than 4.

### 9.5 Bosses — 384x384 per frame

Bosses cross **two health thresholds**, so they get one extra state.

| State | Frames | Loop | Notes |
|-------|--------|------|-------|
| `idle` | 4 | loop | bosses are stationary threats; this is the default read |
| `windup` | 6 | hold last | longer telegraph — the fight is about reading it |
| `strike` | 4 | once | |
| `recover` | 4 | once | |
| `phase` | 8 | once | the transition at a health threshold |
| `death` | 10 | once | the run's payoff; make it long |

`phase` is the one worth spending real time on. It fires when the boss crosses a
health threshold and is currently a particle burst and a screen shake with no
sprite change at all.

```
[STYLE BLOCK]

An 8-frame phase-transition sprite animation for a game boss, seen from about 45
degrees above. Each frame exactly 384x384 pixel art on a transparent background,
laid out as a single horizontal strip.

SUBJECT: a towering mass of fused drowned bodies forming a single cathedral-like
figure, dozens of open singing mouths across its surface, black water pouring
continuously from its frame, tattered ceremonial cloth.

MOTION: the figure convulses and changes. Frames 1-3 rear back as the mouths open
wider in unison, frames 4-5 are the peak — amber light bursting from every seam,
water thrown outward — frames 6-8 settle into a new, more aggressive stance that is
visibly different from the one it started in.

The base stays on the same pixel row and the body does not drift across the strip.
Fixed amber key light from the upper right. No ground shadow, no scenery.
```

### 9.6 What to generate first

Animation is expensive; the frames the player looks at most are worth doing first.

1. **`enemy_coalpaint_raider` — all five states.** The first enemy the player ever
   meets. One complete enemy proves the pipeline end to end and is what gets wired
   into `sprite_animator.gd` first.
2. **`hero` — idle, walk, attack_1/2/3, death.** On screen every second of the game.
3. The other two act-opening regulars, `enemy_veiled_skirmisher` and
   `enemy_rime_marauder`.
4. The three elites — especially their `windup`.
5. Bosses: `phase` and `death` before the rest.

Towers, buildings and the city do not need animation. They are static by design and
the engine already gives them idle light flicker, damage flames, the beast-step
wobble and an upgrade burst.

---

## 10. v4 conformance of the art

Checked against `Game_Design_v4.md` on 2026-08-14, by reading the shipped `.tres`
data rather than the older docs. `ASSET_MANIFEST.md` predates v4 and describes the
v3 world in several places; where the two disagree, this section is the one that
matches the running game.

### Conformant

**The enemy roster is exactly v4.** Twelve regulars and six elites, four and two
per region, matching the table in v4 §397-399 name for name: Coalpaint Raider,
Wolf Rider, Rootshield, Ember Shaman, Pack Howler, Wolf Standard-Bearer / Veiled
Skirmisher, Scale Rider, Glassguard, Dune Burrower, Mirage Seer, Siege Lizard /
Rime Marauder, Ice Hauler, Snowhide Brute, Storm Caller, Avalanche Warden, White
Maw Giant. Each `description` states the enemy's job, which is v4 §375's
requirement.

**The Oathbound framing is correct.** v4 §57 makes "no unreviewed enslavement
language ships" a release requirement. Every player-facing string is Oathbound —
`role_noun = "Oathbound"`, `acquire_verb = "Assign"`, display names "Coal-Eye
Oathbound", "Sunglass Oathbound", "Rimebound Oathbound". Only internal ids and
filenames still read `captive_*`, which CLAUDE.md explicitly sanctions for save
compatibility. **Do not put chains, cages, collars or bindings in the Oathbound or
chieftain art.** These leaders are sworn, ransomed or memorialised — never owned.

**Tower count and elements.** 18 towers, four elements, ten combinations. v4 §54
cuts light and dark elements and level-3 specialisation branches; neither exists
in the data.

### Drifted — still v3 in the shipped game

These are game-data issues, not art issues. Flagged rather than changed, because
renaming shipped content is an owner call.

| Thing | Shipped | v4 says |
|-------|---------|---------|
| Act I region | "Ashfen Marsh" | **The Verdant Maw** — a rain-heavy jungle |
| Act II region | "Saltglass Flats" | **The Sunglass Waste** |
| Act III region | "Iron Steppe" | **The White Teeth** — a frozen mountain approach |
| Act I boss | "The Drowned Choir" | **Rakka Coal-Eye, Wolf Marshal** |
| Act II boss | "Mirrorfang" | **Veyr of the Sunglass, Dune Seer** |
| Act III boss | "The Rust Crown" | **Mogrun White-Maw, Avalanche King** |

**The Act III mismatch is the one that shows.** Its enemies are entirely frozen —
Rime Marauder, Ice Hauler, Snowhide Brute, Storm Caller, Avalanche Warden, White
Maw Giant — and they currently walk across a red-brown dusty iron steppe. The
terrain and backdrop prompts in §5.7 and §5.8 are written to v4 (blue snow, black
stone, aurora), so generating them fixes the picture even if the display names are
left alone. Act I has the same problem more mildly: grey ash marsh under a roster
that v4 describes as jungle.

The three boss names are pure text. The v4 names carry `[TUNE name]` markers, so
they are not final either — worth deciding before the boss art is drawn, since
"The Drowned Choir" and "Rakka Coal-Eye, Wolf Marshal" are not the same creature.
The boss subjects in §5.3 are still written to the v3 names and should be redone
once that is settled.

### Dead art — do not generate

Six files in `art/enemies/` are loaded by nothing, because `EnemyData.sprite_id`
redirects their ids to the v4 sprites:

`enemy_bogkin` · `enemy_glassborn` · `enemy_steppehorde` · `elite_warden` ·
`elite_howler` · `elite_burrower`

They pass the asset report because they have manifest rows, so nothing complains
about them. They are v3 leftovers and generating replacements would be wasted
work. Worth deleting from both the manifest and `art/` in a future pass — that is
a code change, not an art one.

### `ASSET_MANIFEST.md` is stale

Its §6 subject tables still describe Bogkin, Glassborn, Steppehorde, Warden,
Howler and Burrower, and its terrain and backdrop subjects still describe the
marsh and the iron steppe. It remains correct for **paths and sizes**, which is
what the tooling parses it for. For *subjects*, this document supersedes it.

---

## 11. The Warden — hero character bible

The hero is on screen every second of the game and every animation state is generated
from one base sprite. It is the only asset worth over-specifying, so this section is the
authority: **§5.1 and §9.3 defer to it.**

### 11.1 Who the Warden is

v4 §149: *"The player is the town's **Warden**, a singular defender bound to Yuri."*

Not a knight, not a king, not a wanderer who happens to be here. One person responsible
for a refuge town riding on the back of a walking beast, holding four roads alone. v4
§112 adds that the hero is *"attached to Yuri and the town because both visibly carry the
history of the run"* — so the Warden should look like they belong **to that town**, not
like a mercenary who arrived from somewhere else.

`hero_ascended_1` and `hero_ascended_2` are v3 leftovers and are referenced by no shipped
code. **Generate `hero_base` only.** v4's ascension is a single Ascension Keystone chosen
after the Act III boss (§24), so if an ascended sprite is ever wanted it is one, not two,
and it does not exist yet as a design.

### 11.2 The three silhouette hooks

The Warden is 128x128 on a battlefield that also holds towers at 192x192 and enemies at
192x192, viewed at a zoom that shows all four roads. **The player has to find their own
character instantly in a crowded, dark frame.** That is a silhouette problem, and it is
solved by three asymmetric hooks that never change across any state or direction:

| Hook | Side | Why |
|---|---|---|
| **A long curved single-edged blade, carried low** | one hand | Reads as offense at a glance and gives a hard diagonal no enemy silhouette has |
| **A torn banner-cloak in the town's rust red** | opposite side | Motion, asymmetry, and the only saturated colour on the sprite |
| **A hooded ember-lamp at the hip** | centre-low | The warm point of light — see below |

**The lamp is not decoration.** `torch.gd` gives the Warden a real mechanic: *"the hero
standing near a dead one relights it."* The Warden is the only thing on the battlefield
that can bring a road's light back. Carrying the flame that does it is the sprite stating
its own verb, and it supplies the one warm accent the house style asks for.

### 11.3 What the current attempt gets right, and the four fixes

The generated attempt is close and worth iterating rather than restarting. It already has
the blade held low, a torn dark cloak, a lean layered build, and a palette in the right
family.

**Fix 1 — the face reads as a skull. It must be a featureless mask.**
A skull says undead, necromancer, or lich. That is the most common creature in dark-fantasy
training data, and it is why every prompt drifts toward it. The Warden's face is a
**smooth bone-pale plate with no eye sockets, no nose, no teeth, no jaw seam** — a blank.
Say so explicitly and negatively, or the model will put a skull there every time.

**Fix 2 — there is no amber anywhere.**
The house style is *"strong warm amber rim light from the upper right against deep
teal-black shadow"* with *"a single saturated accent per asset."* The attempt is almost
monochrome dark, which will vanish against a dark battlefield and go muddy under the
game's real `PointLight2D` torchlight. The sprite needs the amber rim baked along its
upper-right contour and one warm accent — the lamp.

**Fix 3 — nothing says which town this is.**
Add the rust-red banner-cloak. It is the town's colour, it is the asymmetry hook, and it
is what makes this a *Warden* rather than a generic hooded swordsman.

**Fix 4 — value contrast is too low to survive the battlefield.**
Dark cloth on a dark field at 128px reads as a blob. The rule below is not stylistic.

> **The 64-pixel test.** Shrink the sprite to 64x64 and squint. The blade, the cloak
> direction and the lamp must still be three separate things. If it collapses into one
> mass, the values are too close — lighten the upper-right armour plates and darken the
> lower-left cloth until it separates.

### 11.4 Base sprite prompt — `hero_base.png`, 128x128

Generate this **facing south (toward the camera)**. Pixellab rotates from a south base, and
every other direction and every animation state descends from this one image, so it is the
only generation that is worth spending several attempts on.

Pose is **neutral and weight-centred** — a ready stance, not a dramatic one. A base sprite
with a dynamic pose baked in fights every animation generated from it and rotates badly.

```
A game character sprite for a top-down action game. 128x128 pixel art, transparent
background. Full body, standing, facing the camera (south).

CHARACTER: the Warden — the lone defender of a small refuge town. Lean, athletic and
built to run, not a heavy knight. Layered scavenged plate over wrapped dark cloth, worn
and repaired. Hood up.

FACE: a smooth bone-pale mask, completely featureless — no eye sockets, no nose, no
mouth, no teeth, no jaw line. A blank plate, not a skull.

SILHOUETTE (must read at 64 pixels):
- a long curved single-edged blade carried low in the right hand, angled down and out
- a torn banner-cloak in deep rust red hanging from the left shoulder
- a small hooded lamp burning amber at the hip

POSE: neutral ready stance, weight centred over both feet, arms clear of the body so the
silhouette is open. Not mid-swing, not crouched, not dramatic.

STYLE: dark grim-fantasy pixel art, chunky detailed pixels, limited palette, subtle
dithering, no anti-aliasing on outer edges, strong readable silhouette.

LIGHT: warm amber key light from the upper right putting a bright rim along the top-right
contour of the head, shoulder and blade. Deep teal-black shadow on the lower left. The
lamp casts a second small warm glow at the hip.

PALETTE: teal-black #0B1416, slate #1E2E33, bone #D9CDB8 for the mask, rust #8C3A2B for
the banner-cloak, amber #E8A33D for the lamp flame and the rim light only.

FRAMING: the whole figure inside the frame with a two-pixel margin, feet on the bottom
edge, centred horizontally.

NOT: no crown, no throne, not seated, no skull face, no gold metal, no shield, no cape of
office, no full plate armour, no horns, no glowing eyes, no ground, no shadow, no scenery.
```

**The NOT line is doing real work.** An earlier attempt at "grim-fantasy armored figure
with a bone mask" returned a crowned skeleton king seated on a throne — the genre's
strongest attractor. Gold and crowns pull toward royalty; "bone" pulls toward skulls.
Naming them as exclusions is cheaper than re-rolling.

### 11.5 Eight directions

Once the south base is right, rotate it before generating a single animation. Every state
is then generated per direction from a sprite that already agrees with itself.

Order of work, and do not skip ahead:

1. **`hero_base` south.** Iterate until the 64-pixel test passes. This is the expensive step.
2. **8-direction rotation** from that base. Check the blade stays in the same hand and the
   banner stays on the same shoulder in all eight — a rotation that swaps them is a reroll.
3. **`idle`**, 4 frames, south only. Confirm the animation pipeline and the pivot.
4. The remaining states in §9.3, per direction.

The engine positions the character, so **the pivot must not move** — feet on the same pixel
row and the body on the same column in every frame and every direction. A drifting pivot
makes the Warden slide as they turn.

### 11.6 What the engine adds, so the frames should not

Repeating §9.1 because it matters most here: the Warden's frames run **underneath** the
procedural motion. `sprite_animator.gd` already supplies bounce, lean, squash, recoil, the
dash stretch and the death topple. Frames that bake those in multiply against them.

Generate the limbs, the blade arc, the cloak and the lamp. Leave the weight to the engine.
