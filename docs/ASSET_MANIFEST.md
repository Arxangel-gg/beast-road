# BEAST ROAD — Asset Manifest & Generation Prompts

Every image the v1 build needs: exact path, exact size, which tool makes it,
and the prompt to make it with.

**This file is machine-read.** `game/tools/generate_placeholders.gd` parses the
tables in §5 to generate placeholders. Keep the table format intact. Adding an
asset requirement to code without adding a row here is a bug.

---

## 1. House style

One style block, used on every prompt, so ninety assets look like one game.

**Style:** dark painterly grim-fantasy game art. Hand-painted texture, visible
brushwork, no black outlines. Strong warm amber rim light from the upper right
against deep teal-black shadow. Muted desaturated base palette with a single
saturated accent per asset. High silhouette clarity — the shape must read at
64px.

**Palette:**

| Role | Hex |
|------|-----|
| Shadow / void | `#0B1416` |
| Slate mid | `#1E2E33` |
| Amber key light | `#E8A33D` |
| Bone highlight | `#D9CDB8` |
| Rust accent | `#8C3A2B` |

**Perspective:** all units, towers and buildings are drawn from a **three-
quarter top-down view**, as seen in a 2D action game where the camera looks
down at roughly 60°. Consistency here matters more than any individual asset
looking good.

---

## 2. Tool split

| Tool | Use for | Why |
|------|---------|-----|
| **ChatGPT** (GPT Image) | Everything needing a transparent background: units, towers, buildings, icons, VFX | Produces genuine alpha channels |
| **Midjourney** | Everything opaque: terrain tiles, backdrops, splash art, menu art | Better painterly quality and `--tile` for seamless terrain |

### ChatGPT rules

- Generate at **1024×1024** and downscale to the target size in the table. Do
  not ask it for odd sizes.
- Always end the prompt with the transparency clause in §3.
- If it returns a checkerboard *pattern* instead of real alpha, say
  "regenerate with a true transparent alpha channel, not a checkerboard
  pattern drawn in the image."
- Verify alpha before saving: open in an editor and confirm the background is
  actually empty.

### Midjourney rules

- Terrain tiles need `--tile` and must be tested by tiling 2×2 before use.
- Once you have one hero image you love, grab its `--sref` code and append it
  to every subsequent Midjourney prompt. That is what locks the style.
- No `--style raw` — the painterly default is what you want here.
- `--s 250` for backdrops, `--s 150` for anything that needs to stay readable.

---

## 3. Prompt stems

Prepend to every prompt of that type.

**ChatGPT stem (transparent):**

> Game asset sprite on a fully transparent background. No background elements,
> no ground shadow, no frame, no text. Single subject, centered, full body,
> even margin on all sides. Dark painterly grim-fantasy game art, hand-painted
> texture, visible brushwork, no black outlines. Strong warm amber rim light
> from the upper right against deep teal-black shadow. Muted desaturated
> palette (#0B1416, #1E2E33, #E8A33D, #D9CDB8, #8C3A2B) with one saturated
> accent. High silhouette clarity — the shape must read clearly at small size.
> Three-quarter top-down view, camera looking down at roughly 60 degrees.
> Square 1:1. Export as PNG with a true alpha channel.
>
> SUBJECT: `[subject]`

**Midjourney stem (opaque):**

> `[subject]`, dark painterly grim-fantasy game art, hand-painted digital
> matte painting, visible brushwork, warm amber light against deep teal-black
> shadow, muted desaturated palette, heavy atmosphere, volumetric haze, no
> characters, no text, no UI `--ar 16:9 --s 250`

**Midjourney stem (seamless terrain):**

> seamless tileable top-down ground texture, `[subject]`, dark painterly
> grim-fantasy game art, hand-painted, muted desaturated palette, even
> lighting with no directional shadow, no objects casting shadow, no text
> `--tile --ar 1:1 --s 150`

---

## 4. Naming and placement

**The path is derived from the resource `id`. Nothing else.** A `TowerData`
with `id = "ember_spire"` loads `res://art/towers/tower_ember_spire.png`.

To install real art: **overwrite the placeholder file at the same path with
the same dimensions.** Godot re-imports on focus. No code change.

Rules:

- `snake_case` only. No spaces, no capitals, no version suffixes.
- PNG only.
- Exact dimensions from the table. Not "close enough" — the collision and
  layout code assumes them.
- Never rename a file to fix a problem. Fix the `id` in the `.tres`.

**Placeholder detection:** pixel `(0,0)` of every generated placeholder is pure
magenta `#FF00FF`. Run `asset_report.gd` to list what is still fake.

Most placeholders also carry a 4px magenta border. **Terrain tiles and
backdrops do not** — they are tiled or stretched, and four magenta edges turn a
tiled floor into graph paper. They get a small corner pip instead. Pixel `(0,0)`
is the contract; the border is only a convenience.

---

## 5. Asset tables

`T` = transparent (ChatGPT). `O` = opaque (Midjourney).

### 5.1 Hero — `res://art/hero/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `hero_base.png` | 128×128 | T | `#E8A33D` |
| `hero_ascended_1.png` | 128×128 | T | `#E8A33D` |
| `hero_ascended_2.png` | 128×128 | T | `#E8A33D` |

### 5.2 Enemies — `res://art/enemies/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `enemy_bogkin.png` | 96×96 | T | `#4A6B4F` |
| `enemy_glassborn.png` | 96×96 | T | `#6B8A9E` |
| `enemy_steppehorde.png` | 96×96 | T | `#8C3A2B` |
| `elite_warden.png` | 128×128 | T | `#5A5A6B` |
| `elite_howler.png` | 128×128 | T | `#7A5A3D` |
| `elite_burrower.png` | 128×128 | T | `#4A3D33` |

### 5.3 Bosses — `res://art/bosses/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `boss_drowned_choir.png` | 384×384 | T | `#2E4A52` |
| `boss_mirrorfang.png` | 384×384 | T | `#8FA8B8` |
| `boss_rust_crown.png` | 384×384 | T | `#8C3A2B` |

### 5.4 Towers — `res://art/towers/`

All 128×192, type T. Placeholder colour by element.

| File | Element | Colour |
|------|---------|--------|
| `tower_ember_spire.png` | Fire | `#C4552E` |
| `tower_pyre_cannon.png` | Fire | `#C4552E` |
| `tower_rime_lance.png` | Frost | `#7FA6BF` |
| `tower_hoarfrost_bell.png` | Frost | `#7FA6BF` |
| `tower_bulwark.png` | Stone | `#7A6E5C` |
| `tower_shard_thrower.png` | Stone | `#7A6E5C` |
| `tower_arc_coil.png` | Storm | `#9B8FC4` |
| `tower_gale_turret.png` | Storm | `#9B8FC4` |

### 5.5 City — `res://art/city/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `city_base.png` | 512×512 | T | `#8A7A5E` |
| `city_damage_1.png` | 512×512 | T | `#7A6A4E` |
| `city_damage_2.png` | 512×512 | T | `#6A5A3E` |
| `city_damage_3.png` | 512×512 | T | `#5A4A2E` |
| `building_town_hall.png` | 192×192 | T | `#8A7A5E` |
| `building_forge.png` | 192×192 | T | `#C4552E` |
| `building_sanctum.png` | 192×192 | T | `#9B8FC4` |
| `building_granary.png` | 192×192 | T | `#7A8A4E` |
| `building_scavenging_post.png` | 192×192 | T | `#6B5A4A` |
| `building_watchtower.png` | 192×192 | T | `#5E6B7A` |
| `plot_empty.png` | 192×192 | T | `#4A4438` |
| `plot_locked.png` | 192×192 | T | `#33302A` |

### 5.6 Beast — `res://art/beast/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `beast_profile.png` | 1024×512 | T | `#2E3A33` |

### 5.7 Terrain tiles — `res://art/terrain/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `terrain_ashfen.png` | 512×512 | O | `#2E3A33` |
| `terrain_saltglass.png` | 512×512 | O | `#8FA8B8` |
| `terrain_steppe.png` | 512×512 | O | `#6B4A3A` |

### 5.8 Backdrops — `res://art/bg/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `macro_act1.png` | 1920×1080 | O | `#1E2E33` |
| `macro_act2.png` | 1920×1080 | O | `#2E3A42` |
| `macro_act3.png` | 1920×1080 | O | `#3A2E2E` |
| `crossroad_bg.png` | 1920×1080 | O | `#1E2E33` |
| `raid_arena_bg.png` | 1920×1080 | O | `#160E12` |
| `menu_key_art.png` | 1920×1080 | O | `#0B1416` |

### 5.9 Relic icons — `res://art/icons/relics/`

All 128×128, type T, placeholder colour `#E8A33D`.

Files: `relic_01.png` … `relic_20.png`, plus `relic_core_drowned_choir.png`,
`relic_core_mirrorfang.png`, `relic_core_rust_crown.png`.

> Rename these to match final relic `id`s once relics are designed in Stage 5.
> Until then the numbered placeholders are correct.

### 5.10 Spell icons — `res://art/icons/spells/`

All 96×96, type T, placeholder colour `#9B8FC4`.

`spell_rift_step.png` · `spell_cinder_nova.png` · `spell_bulwark_ward.png` ·
`spell_marrow_drain.png` · `spell_chain_hook.png` · `spell_ash_veil.png` ·
`spell_tremor.png` · `spell_beasts_breath.png`

### 5.11 UI icons — `res://art/icons/ui/`

All 64×64, type T, placeholder colour `#D9CDB8`.

`ui_element_fire.png` · `ui_element_water.png` · `ui_element_earth.png` ·
`ui_element_air.png` · `ui_resource.png` · `ui_blueprint.png` ·
`ui_relic.png` · `ui_war_horn.png` · `ui_raid_charge.png` ·
`ui_distance.png` · `ui_city_health.png` · `ui_pressure_arrow.png` ·
`ui_captive.png` · `ui_wave.png` · `ui_upgrade.png` · `ui_build.png` ·
`ui_pause.png` · `ui_settings.png` · `ui_lock.png` · `ui_close.png`

> The four element icons were renamed in GDD v3 (Frost→Water, Stone→Earth,
> Storm→Air). The old `ui_element_frost/stone/storm.png` files were deleted, not
> left as orphans.

### 5.12 Combination towers — `res://art/towers/`

All 128×192, type T. Built in the middle slot of a lane from the two elements
flanking it (GDD §4.1). Placeholder colour blends the two parent elements.

| File | Parents | Colour |
|------|---------|--------|
| `tower_firestorm.png` | Fire + Air | `#B0729B` |
| `tower_magma.png` | Fire + Earth | `#9E6244` |
| `tower_steam_burst.png` | Fire + Water | `#A17E77` |
| `tower_blizzard.png` | Water + Air | `#8B9BC2` |
| `tower_glacier.png` | Water + Earth | `#7C8A8E` |
| `tower_quake.png` | Earth + Air | `#8A7F90` |
| `tower_conflagration.png` | Fire + Fire | `#D14A22` |
| `tower_deep_freeze.png` | Water + Water | `#6FA8CF` |
| `tower_bastion.png` | Earth + Earth | `#6E6350` |
| `tower_tempest.png` | Air + Air | `#A79BD8` |

### 5.13 Battlefield — `res://art/battlefield/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `lane_path.png` | 256×256 | O | `#3A3630` |
| `build_spot.png` | 128×128 | T | `#7A7057` |
| `build_spot_combo.png` | 128×128 | T | `#9B8FC4` |
| `town_core.png` | 384×384 | T | `#8A7A5E` |

### 5.14 Raid — `res://art/raid/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `chieftain_ashfen.png` | 256×256 | T | `#3E5A52` |
| `chieftain_saltglass.png` | 256×256 | T | `#9FB4C4` |
| `chieftain_steppe.png` | 256×256 | T | `#9C4A3B` |
| `captive_bogkin.png` | 128×128 | T | `#4A6B4F` |
| `captive_glassborn.png` | 128×128 | T | `#6B8A9E` |
| `captive_steppehorde.png` | 128×128 | T | `#8C3A2B` |

### 5.15 UI frames — `res://art/ui/`

Nine-slice frames and bars. Stretched in code, so the placeholder size is the
source size, not the on-screen size.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `ui_panel.png` | 256×256 | T | `#1A2428` |
| `ui_panel_dark.png` | 256×256 | T | `#0E1518` |
| `ui_button.png` | 256×64 | T | `#2E4048` |
| `ui_button_hover.png` | 256×64 | T | `#3E5660` |
| `ui_slot.png` | 96×96 | T | `#232F33` |
| `ui_bar_fill.png` | 64×16 | T | `#C4552E` |
| `ui_bar_back.png` | 64×16 | T | `#141C1F` |
| `ui_logo.png` | 1024×256 | T | `#E8A33D` |
| `splash_studio.png` | 1920×1080 | O | `#0B1416` |

---

## 6. Subject prompts

Drop each `SUBJECT` into the matching stem from §3.

### Hero

| Asset | Subject |
|-------|---------|
| `hero_base` | a lone armored scavenger-warrior in a mid-stride combat stance, curved single-edged blade held low, tattered dark cloak, bone-white featureless mask, lean wiry silhouette, scavenged plate over wrapped cloth |
| `hero_ascended_1` | the same armored scavenger-warrior, now transformed — the mask cracked open with amber light bleeding through, the cloak longer and torn, one arm sheathed in fused bone plating, the blade glowing faintly at its edge |
| `hero_ascended_2` | the same warrior in final transformation — towering and monstrous, the mask fully shattered into a crown of bone shards, amber light pouring from every seam, cloak become a mass of trailing ribbons, the blade elongated and burning |

### Enemies

| Asset | Subject |
|-------|---------|
| `enemy_bogkin` | a hunched swamp-dweller creature, waterlogged and bloated, moss and dead reeds hanging from its limbs, dim pale eyes, slow lumbering posture, dripping black water |
| `enemy_glassborn` | a jagged crystalline humanoid made of fractured salt glass, thin sharp limbs, semi-translucent body catching light, agile forward-leaning stance, hairline fractures across its chest |
| `enemy_steppehorde` | a scrappy nomad raider in scavenged rusted iron plates, crude iron spear, wiry underfed frame, cloth-wrapped face, aggressive charging pose |
| `elite_warden` | a heavily armored bulwark warrior hunched behind an enormous riveted iron shield taller than itself, dense immovable silhouette, minimal visible body |
| `elite_howler` | a gaunt ritual-caller with an oversized curved bone horn raised to its mouth, ragged banner strapped to its back, arms flung outward, throat distended |
| `elite_burrower` | a segmented armored digging creature erupting from broken ground, heavy clawed forelimbs, eyeless armored head plate, chitinous body half-emerged |

### Bosses

| Asset | Subject |
|-------|---------|
| `boss_drowned_choir` | a towering mass of fused drowned bodies forming a single cathedral-like figure, dozens of open singing mouths across its surface, black water pouring continuously from its frame, tattered ceremonial cloth, immense and vertical |
| `boss_mirrorfang` | an enormous predatory quadruped beast built from mirrored salt glass, overlapping reflective shard plating, long fanged skull, refracted amber light scattering off its flanks |
| `boss_rust_crown` | a colossal armored warlord fused to a throne of corroded iron, a crown of jagged rusted spires grown into its skull, chains and torn banners hanging from its shoulders, monumental scale |

### Towers

| Asset | Subject |
|-------|---------|
| `tower_ember_spire` | a slender tall stone spire capped with an open burning brazier, narrow iron banding, embers rising from the top |
| `tower_pyre_cannon` | a squat heavy siege cannon of blackened iron with a glowing fire-chamber, wide short barrel, mounted on a stone base |
| `tower_rime_lance` | a tall narrow tower of pale stone ending in a single frost-encrusted spear point, sheets of blue-white ice down one side |
| `tower_hoarfrost_bell` | a heavy stone frame holding a large frost-covered bronze bell, long icicles hanging from its rim |
| `tower_bulwark` | a squat fortified stone bunker with layered overlapping shield plating, heavy and wide, almost no ornament, built to absorb |
| `tower_shard_thrower` | a mechanical ballista of stone and iron loaded with a single long jagged rock shard, tensioned cables |
| `tower_arc_coil` | a metal tower wrapped in tiered copper coils, arcs of pale violet lightning crackling between the rings |
| `tower_gale_turret` | a slim tower with spinning bladed vanes and open wind funnels at its crown, motion blur on the blades |

### City and beast

| Asset | Subject |
|-------|---------|
| `city_base` | a small fortified settlement built on a curved platform of vast bone and lashed timber, tiered stone buildings, banners, chimney smoke, defensive palisade around the rim, viewed from three-quarter above |
| `city_damage_1/2/3` | the same settlement, progressively ruined — *(1)* scorch marks, a collapsed roof, torn banners; *(2)* several buildings burned to frames, palisade breached, fires burning; *(3)* mostly rubble, only the town hall standing, everything blackened |
| `building_town_hall` | a tiered stone hall with a heavy timber roof and a relic-socket frame above its door, banners on both sides |
| `building_forge` | a squat stone forge with a glowing open furnace mouth, anvil outside, smoke stack |
| `building_sanctum` | a narrow stone shrine with a burning bowl on a pedestal and hanging chains, ritual markings on the walls |
| `building_granary` | a rounded timber and stone storehouse with sacks and barrels stacked outside, thatched roof |
| `beast_profile` | an immense ancient six-legged beast walking across a wasteland, shaggy and armored, a small fortified city strapped to its back with vast chains, seen in full side profile, colossal scale, one figure-sized detail for scale |

### Terrain (Midjourney, seamless stem)

| Asset | Subject |
|-------|---------|
| `terrain_ashfen` | dark marsh ground, pools of black standing water, pale dead reeds, ash-grey mud, sunken twisted roots |
| `terrain_saltglass` | cracked salt flat, pale white-blue crystalline crust, thin fracture lines, scattered glassy shards |
| `terrain_steppe` | dry steppe hardpan, red-brown cracked earth, scattered rusted iron debris, sparse dead grass tufts |

### Backdrops (Midjourney, opaque stem)

| Asset | Subject |
|-------|---------|
| `macro_act1` | a vast fog-drowned marsh valley stretching to the horizon, drowned trees, low grey mist, distant water |
| `macro_act2` | an endless cracked white salt desert under a bruised sky, distant glass formations catching light, heat shimmer |
| `macro_act3` | a red-brown iron steppe under a heavy dust sky, the ruined silhouette of an immense fortress on the far horizon |
| `crossroad_bg` | a fork in an ancient road at dusk, two paths diverging into different distant landscapes, weathered stone waymarker in the foreground |
| `raid_arena_bg` | a hostile enemy warcamp seen from directly above, ringed by bone totems and burning braziers, packed dirt floor, tents at the edges `--ar 1:1` |
| `menu_key_art` | an immense ancient beast walking away across a wasteland at dusk with a small lit fortified city on its back, seen from behind and below, dramatic scale, cinematic key art |

### Icons

**Relics** — ChatGPT stem, subject: *a single ancient ritual object isolated on
transparent background, `[object]`, worn and weathered, amber light catching
one edge.* Objects: a cracked bone crown · a rusted iron heart · a sealed clay
jar · a knotted cord of teeth · a shattered mirror shard · a blackened iron
key · a wax-sealed scroll · a horn ring · a burnt feather · a river stone
bound in wire.

**Spells** — ChatGPT stem, subject: *a single glowing arcane sigil on
transparent background representing `[concept]`, painted in amber and violet
light, rough hand-drawn ritual mark, no border.* Concepts: a blink through
space · a bursting star · a protective barrier · a draining hook · a chain and
hook · a veil of ash · a shockwave ring · a beast's exhaled breath.

**UI icons** — ChatGPT stem, subject: *a simple bold game UI icon on
transparent background, `[thing]`, flat two-tone amber and bone on nothing,
thick readable shapes, no gradient, no frame, no text.*

---

## 7. Priority order

Do not make ninety images before the game is playable. Placeholders are fine
for a long time.

| When | Make |
|------|------|
| **After Stage 2** (triage confirmed fun) | `hero_base`, `enemy_bogkin`, all 8 towers, `city_base`, `terrain_ashfen` |
| **After Stage 3** | `elite_*`, `raid_arena_bg` |
| **After Stage 4** | `building_*`, `beast_profile`, `ui_*` |
| **Stage 5–6** | everything else |
| **Last** | `menu_key_art` — make it when you know what the game looks like, because it becomes your Steam capsule |

If a stage's kill question fails, every asset made for it is wasted. That is
the whole reason for this order.
