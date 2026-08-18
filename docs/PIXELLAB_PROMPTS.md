# BEAST ROAD — Pixellab AI prompt book

Everything needed to generate this game's art in Pixellab: the decision to make
first, exact sizes and paths, the style block that makes 187 images look like one
game, and the prompts.

Companion to `ASSET_MANIFEST.md` (the machine-read source of truth for paths and
sizes) and `ASSET_PROMPTS.md` (the existing ChatGPT/Midjourney book).

---

## 0. Read this before spending a single generation

**The game is not missing any art.** `run_tool.gd -- report` currently says:

```
All 187 manifest assets exist. 187 have real art.
```

There is no gap to fill. Exactly one asset is *pending by choice* — see §3.

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
| Towers | `res://art/towers/` | 192x192 | 18 | yes |
| Buildings + plots | `res://art/city/` | 192x192 | 11 | yes |
| City shell | `res://art/city/` | 512x512 | 4 | yes |
| Beast | `res://art/beast/` | 1024x1024 | 1 | yes |
| Battlefield spots | `res://art/battlefield/` | 128x128 | 2 | yes |
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

## 3. The one genuinely pending asset

`ui_resurrection_draught.png` — 128x128 — `res://art/icons/ui/`

The Resurrection Draught is implemented and earnable: a full raid clear can yield
one, carry limit one, prevents the next lethal down and restores 40% health. Its
HUD indicator currently **borrows the relic icon**, because a manifest row with a
placeholder behind it fails the production-art gate and blocks every release.

Generate this one and say so — the manifest row, the indicator and the gate re-run
are a five-minute change.

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

### 4.2 `enemy_bogkin.png` — 192x192

```
[STYLE BLOCK]

A game character sprite seen from about 45 degrees above, closer to side-on than
top-down. 192x192 pixel art, transparent background.

SUBJECT: a hunched swamp-dweller creature, waterlogged and bloated, moss and dead
reeds hanging from its limbs, dim pale eyes, slow lumbering posture, dripping
black water.

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

| File | Subject |
|------|---------|
| `hero_base` | a lone armored scavenger-warrior in a mid-stride combat stance, curved single-edged blade held low, tattered dark cloak, bone-white featureless mask, lean wiry silhouette, scavenged plate over wrapped cloth |
| `hero_ascended_1` | the same warrior transformed — the mask cracked open with amber light bleeding through, the cloak longer and torn, one arm sheathed in fused bone plating, the blade glowing faintly at its edge |
| `hero_ascended_2` | the same warrior in final transformation — towering and monstrous, the mask shattered into a crown of bone shards, amber light pouring from every seam, cloak become a mass of trailing ribbons, the blade elongated and burning |

### 5.2 Enemies and elites — 192x192

| File | Subject |
|------|---------|
| `enemy_bogkin` | a hunched swamp-dweller creature, waterlogged and bloated, moss and dead reeds hanging from its limbs, dim pale eyes, slow lumbering posture, dripping black water |
| `enemy_glassborn` | a jagged crystalline humanoid made of fractured salt glass, thin sharp limbs, semi-translucent body catching light, agile forward-leaning stance, hairline fractures across its chest |
| `enemy_steppehorde` | a scrappy nomad raider in scavenged rusted iron plates, crude iron spear, wiry underfed frame, cloth-wrapped face, aggressive charging pose |
| `elite_warden` | a heavily armored bulwark warrior hunched behind an enormous riveted iron shield taller than itself, dense immovable silhouette, minimal visible body |
| `elite_howler` | a gaunt ritual-caller with an oversized curved bone horn raised to its mouth, ragged banner strapped to its back, arms flung outward, throat distended |
| `elite_burrower` | a segmented armored digging creature erupting from broken ground, heavy clawed forelimbs, eyeless armored head plate, chitinous body half-emerged |

The remaining enemy files follow the same regional logic — `game/data/enemies/*.tres`
has the full list of ids, with `display_name` and `description` on each for its
intended read.

### 5.3 Bosses — 384x384

| File | Subject |
|------|---------|
| `boss_drowned_choir` | a towering mass of fused drowned bodies forming a single cathedral-like figure, dozens of open singing mouths across its surface, black water pouring continuously from its frame, tattered ceremonial cloth, immense and vertical |
| `boss_mirrorfang` | an enormous predatory quadruped beast built from mirrored salt glass, overlapping reflective shard plating, long fanged skull, refracted amber light scattering off its flanks |
| `boss_rust_crown` | a colossal armored warlord fused to a throne of corroded iron, a crown of jagged rusted spires grown into its skull, chains and torn banners hanging from its shoulders, monumental scale |

### 5.4 Towers — 192x192

| File | Subject |
|------|---------|
| `tower_ember_spire` | a slender tall stone spire capped with an open burning brazier, narrow iron banding, embers rising from the top |
| `tower_pyre_cannon` | a squat heavy siege cannon of blackened iron with a glowing fire-chamber, wide short barrel, mounted on a stone base |
| `tower_rime_lance` | a tall narrow tower of pale stone ending in a single frost-encrusted spear point, sheets of blue-white ice down one side |
| `tower_hoarfrost_bell` | a heavy stone frame holding a large frost-covered bronze bell, long icicles hanging from its rim |
| `tower_bulwark` | a squat fortified stone bunker with layered overlapping shield plating, heavy and wide, almost no ornament, built to absorb |
| `tower_shard_thrower` | a mechanical ballista of stone and iron loaded with a single long jagged rock shard, tensioned cables |
| `tower_arc_coil` | a metal tower wrapped in tiered copper coils, arcs of pale violet lightning crackling between the rings |
| `tower_gale_turret` | a slim tower with spinning bladed vanes and open wind funnels at its crown |

Ten combination towers complete the set of 18 — ids and elements are in
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

### 5.7 Terrain — 512x512, must tile

| File | Subject |
|------|---------|
| `terrain_ashfen` | dark marsh ground, pools of black standing water, pale dead reeds, ash-grey mud, sunken twisted roots |
| `terrain_saltglass` | cracked salt flat, pale white-blue crystalline crust, thin fracture lines, scattered glassy shards |
| `terrain_steppe` | dry steppe hardpan, red-brown cracked earth, scattered rusted iron debris, sparse dead grass tufts |

Use a **tileset / seamless** mode, not plain generation. Test by tiling 2x2 before
saving — a visible seam becomes a grid across the whole battlefield. No
transparency; these are opaque ground.

### 5.8 Backdrops — 1920x1080, opaque

| File | Subject |
|------|---------|
| `macro_act1` | a vast fog-drowned marsh valley stretching to the horizon, drowned trees, low grey mist, distant water |
| `macro_act2` | an endless cracked white salt desert under a bruised sky, distant glass formations catching light, heat shimmer |
| `macro_act3` | a red-brown iron steppe under a heavy dust sky, the ruined silhouette of an immense fortress on the far horizon |
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

---

## 6. Pixellab techniques worth using

**Animation.** The reason to do this at all. The game has no animation frames and
fakes everything with transforms. Start with the hero and the three base enemies:
idle, walk, attack, death. Nothing in the engine consumes frames yet — say when a
set exists and `sprite_animator.gd` can be wired to play real frames and fall back
to the procedural motion wherever frames do not exist.

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

---

## 8. Priority order

`ASSET_MANIFEST.md` §7 orders by kill question because a stage that fails wastes
every asset made for it. For a restyle the ordering differs — the game is already
proven — but the principle holds: **do not make 187 images before knowing the style
survives the lighting.**

1. The three pilot assets (§4). Stop and look at them in-game.
2. All 18 towers and the 3 base enemies — the most-seen sprites in the game.
3. Hero, elites, city shell, terrain.
4. Icons, buildings, bosses, chieftains.
5. Backdrops and UI frames.
6. `menu_key_art`.
