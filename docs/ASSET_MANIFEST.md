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

**The prompts live in `ASSET_PROMPTS.md`, generated from this file.** Do not
write them by hand here.

There are four stems, not one, because a single stem produced eye-level concept
art for a top-down game:

| Stem | Used for | Camera |
|------|----------|--------|
| Character | hero, enemies, bosses, chieftains, captives | looking down ~45 deg |
| Structure | towers, buildings, plots, town core, beast | looking down ~60 deg |
| Icon | relic, spell and UI icons | flat, front-on, no perspective |
| UI frame | panels, buttons, bars | flat, symmetrical, empty centre |

Characters are drawn flatter than buildings on purpose. A human at 60 degrees
is a head and two shoulders with no silhouette worth looking at, which is why
almost every top-down action game draws its environments steeply and its
characters much closer to side-on.

Each stem leads with the medium, the camera and the display size, in that
order, because image models weight early tokens most heavily. The first version
buried the camera at the end and got a portrait back every time.

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

**Animation sheets.** Rows are the 8 facings in engine index order (clockwise
from east), columns are frames, each cell 168×160. Built from Pixellab's
per-frame export by `tools/pack_hero_frames.py` — do not hand-edit them, and do
not change the cell size without changing `hero_animator.gd` to match.

The cell is 168×160 rather than a round 192 because it was measured: content
reaches at most 157px above the canvas bottom and 83px either side of centre.
Nine sheets of 192-square cells cost the entire frame-hitch budget on a 3070 Ti.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `hero_idle.png` | 1512×1280 | T | `#E8A33D` |
| `hero_walk.png` | 1512×1280 | T | `#E8A33D` |
| `hero_attack_1a.png` | 1512×1280 | T | `#E8A33D` |
| `hero_attack_1b.png` | 1512×1280 | T | `#E8A33D` |
| `hero_attack_2.png` | 1512×1280 | T | `#E8A33D` |
| `hero_attack_3.png` | 1512×1280 | T | `#E8A33D` |
| `hero_hurt.png` | 1512×1280 | T | `#E8A33D` |
| `hero_dash.png` | 1512×1280 | T | `#E8A33D` |
| `hero_death.png` | 1512×1280 | T | `#E8A33D` |

### 5.2 Enemies — `res://art/enemies/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `enemy_coalpaint_raider.png` | 192×192 | T | `#4A6B4F` |
| `enemy_wolf_rider.png` | 192×192 | T | `#4A6B4F` |
| `enemy_rootshield.png` | 192×192 | T | `#4A6B4F` |
| `enemy_ember_shaman.png` | 192×192 | T | `#4A6B4F` |
| `elite_pack_howler.png` | 192×192 | T | `#4A6B4F` |
| `elite_wolf_standard_bearer.png` | 192×192 | T | `#4A6B4F` |
| `enemy_veiled_skirmisher.png` | 192×192 | T | `#6B8A9E` |
| `enemy_scale_rider.png` | 192×192 | T | `#6B8A9E` |
| `enemy_glassguard.png` | 192×192 | T | `#6B8A9E` |
| `enemy_dune_burrower.png` | 192×192 | T | `#6B8A9E` |
| `elite_mirage_seer.png` | 192×192 | T | `#6B8A9E` |
| `elite_siege_lizard.png` | 192×192 | T | `#6B8A9E` |
| `enemy_rime_marauder.png` | 192×192 | T | `#9CB9D8` |
| `enemy_ice_hauler.png` | 192×192 | T | `#9CB9D8` |
| `enemy_snowhide_brute.png` | 192×192 | T | `#9CB9D8` |
| `enemy_storm_caller.png` | 192×192 | T | `#9CB9D8` |
| `elite_avalanche_warden.png` | 192×192 | T | `#9CB9D8` |
| `elite_white_maw_giant.png` | 192×192 | T | `#9CB9D8` |

### 5.3 Bosses — `res://art/bosses/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `boss_drowned_choir.png` | 384×384 | T | `#2E4A52` |
| `boss_mirrorfang.png` | 384×384 | T | `#8FA8B8` |
| `boss_rust_crown.png` | 384×384 | T | `#8C3A2B` |

### 5.4 Towers — `res://art/towers/`

All 192×192, type T. Placeholder colour by element.

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
| `tower_cinder_lance.png` | Fire | `#C4552E` |
| `tower_ashen_censer.png` | Fire | `#C4552E` |
| `tower_tide_caller.png` | Frost | `#7FA6BF` |
| `tower_glacial_mortar.png` | Frost | `#7FA6BF` |
| `tower_grit_sling.png` | Stone | `#7A6E5C` |
| `tower_stonewatch.png` | Stone | `#7A6E5C` |
| `tower_zephyr_needle.png` | Storm | `#9B8FC4` |
| `tower_stormvane.png` | Storm | `#9B8FC4` |

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
| `building_woodcutter.png` | 192×192 | T | `#5B4933` |
| `building_treasury.png` | 192×192 | T | `#4A5158` |
| `building_market.png` | 192×192 | T | `#7A4936` |
| `plot_empty.png` | 192×192 | T | `#4A4438` |
| `plot_locked.png` | 192×192 | T | `#33302A` |

### 5.6 Beast — `res://art/beast/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `beast_profile.png` | 1024×1024 | T | `#2E3A33` |

### 5.7 Terrain tiles — `res://art/terrain/`

Each region's floor is the plain-ground tile of its own road set, mirrored into
a seamless 40×40 tile by `tools/build_road_tiles.py`. Ground and road therefore
come from one generation, share a palette, and are drawn at the same pixel
density (`Balance.GROUND_UNITS_PER_TEXEL`).

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `terrain_ashfen.png` | 40×40 | O | `#2E3A33` |
| `terrain_saltglass.png` | 40×40 | O | `#8FA8B8` |
| `terrain_steppe.png` | 40×40 | O | `#6B4A3A` |

**Region floors — corner (Wang) sets.**

Each region's floor is sixteen tiles covering every way four corners can be one
of two materials, indexed by a corner mask (bit0=NW, bit1=NE, bit2=SE, bit3=SW;
a set bit is the *upper* material). `Battlefield` bakes the floor by sampling a
seeded noise field at the cell corners, so the two materials interlock in
organic drifts and the floor never shows a repeat — the periodicity lives in the
pattern, not in the image.

Sliced from a PixelLab tileset by `tools/build_ground_tiles.py`, which documents
the two traps: slice by each tile's `bounding_box`, never by its name or grid
position, and read the corners by name rather than positionally.

`terrain_<id>.png` above remains the fallback for a region with no corner set.

**Act I — The Verdant Maw** (dark jungle earth → deep-green moss)

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `ground_ashfen_00.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_01.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_02.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_03.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_04.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_05.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_06.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_07.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_08.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_09.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_10.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_11.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_12.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_13.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_14.png` | 32×32 | O | `#2E3A33` |
| `ground_ashfen_15.png` | 32×32 | O | `#2E3A33` |

**Act II — The Sunglass Waste** (pale salt hardpan → golden sand drifts)

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `ground_saltglass_00.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_01.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_02.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_03.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_04.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_05.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_06.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_07.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_08.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_09.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_10.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_11.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_12.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_13.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_14.png` | 32×32 | O | `#C9A968` |
| `ground_saltglass_15.png` | 32×32 | O | `#C9A968` |

**Act III — The White Teeth** (frozen rock → wind-packed snow)

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `ground_steppe_00.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_01.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_02.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_03.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_04.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_05.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_06.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_07.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_08.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_09.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_10.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_11.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_12.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_13.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_14.png` | 32×32 | O | `#8FA8B8` |
| `ground_steppe_15.png` | 32×32 | O | `#8FA8B8` |

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

Files: `relic_01.png` … `relic_24.png`, plus `relic_core_drowned_choir.png`,
`relic_core_mirrorfang.png`, `relic_core_rust_crown.png`.

> Rename these to match final relic `id`s once relics are designed in Stage 5.
> Until then the numbered placeholders are correct.

### 5.10 Spell icons — `res://art/icons/spells/`

All 96×96, type T, placeholder colour `#9B8FC4`.

`spell_rift_step.png` · `spell_cinder_nova.png` · `spell_bulwark_ward.png` ·
`spell_marrow_drain.png` · `spell_chain_hook.png` · `spell_ash_veil.png` ·
`spell_tremor.png` · `spell_beasts_breath.png`

### 5.11 UI icons — `res://art/icons/ui/`

All 128×128, type T, placeholder colour `#D9CDB8`.

> Raised from 64×64. The game runs fullscreen, and a 64px icon drawn into a
> 40–48px HUD slot on a 1440p display has almost no headroom — any UI scaling at
> all and it is visibly soft. 128 costs a few KB each and leaves room to grow.

`ui_element_fire.png` · `ui_element_water.png` · `ui_element_earth.png` ·
`ui_element_air.png` · `ui_resource.png` · `ui_blueprint.png` ·
`ui_relic.png` · `ui_war_horn.png` · `ui_raid_charge.png` ·
`ui_distance.png` · `ui_city_health.png` · `ui_pressure_arrow.png` ·
`ui_captive.png` · `ui_wave.png` · `ui_upgrade.png` · `ui_build.png` ·
`ui_pause.png` · `ui_settings.png` · `ui_lock.png` · `ui_close.png` ·
`ui_command.png` · `ui_command_overdrive.png` · `ui_command_rally.png` ·
`ui_command_last_stand.png` · `ui_wood.png` · `ui_food.png` · `ui_gold.png` ·
`ui_stone.png` · `ui_hero_health.png` · `ui_wounds.png`

The four Command icons are final production art. They share the bone/amber
field-command language and remain distinct at 32px: crest, surging tower,
rally shield, and protected gate.

**Two languages, on purpose.** The set is not stylistically uniform and should
not be made so:

- **World objects are painted** in the Command icons' bone/amber language —
  resources, elements, relic, war horn, gatehouse, blueprint, torch, wave,
  captive, distance, build. These name a thing that exists in the fiction, and a
  painted thing sits beside a painted game.
- **Chrome stays a flat amber glyph** — `ui_close`, `ui_pause`, `ui_settings`,
  `ui_lock`, `ui_upgrade`, `ui_pressure_arrow`. These name an *action on the
  interface*, they sit on top of the battlefield, and a painted miniature there
  competes with the thing the player is trying to look at.

The four element icons carry their own hue and are the one place colour does the
work: fire is ember red, water teal, earth ochre, air pale cyan. They were amber
like everything else once, which left fire and water distinguishable only by
outline — the whole point of an element marker, lost.

Every icon here must still read at 32px. That rules out thin, vertical or
diagonal subjects however good they look at 128: a sword and a rank of spears
were both tried and both came back as slivers.

> The four element icons were renamed in GDD v3 (Frost→Water, Stone→Earth,
> Storm→Air). The old `ui_element_frost/stone/storm.png` files were deleted, not
> left as orphans.

### 5.12 Cursor states — `res://art/cursors/`

All 64×64, type T, placeholder colour `#D9CDB8`.

`cursor_default.png` · `cursor_point.png` · `cursor_build.png` ·
`cursor_attack.png` · `cursor_repair.png` · `cursor_busy.png`

Cursor artwork is registered once by `CursorKit`; standard Control hover states
inherit it while world interactions can explicitly request build, attack, or
repair.

### 5.13 Discipline icons — `res://art/icons/disciplines/`

All 192×192, type T, placeholder colour `#8C3A2B`.

`discipline_hemorrhage_edge.png` · `discipline_red_pursuit.png` ·
`discipline_sanguine_guard.png` · `discipline_marrow_drain.png` ·
`discipline_hunters_pulse.png` · `discipline_open_vein.png` ·
`discipline_crimson_tempest.png` · `discipline_blood_remembers.png` ·
`discipline_consecrated_chain.png` · `discipline_judgment_brand.png` ·
`discipline_aegis_step.png` · `discipline_bulwark_ward.png` ·
`discipline_vigil.png` · `discipline_mercy_under_fire.png` ·
`discipline_dawn_bell.png` · `discipline_unbroken_oath.png` ·
`discipline_cleaving_road.png` · `discipline_chain_hook.png` ·
`discipline_iron_roar.png` · `discipline_tremor.png` ·
`discipline_rising_fury.png` · `discipline_no_ground_given.png` ·
`discipline_beasts_breath.png` · `discipline_break_the_host.png`

The three families share blackened iron and aged brass; Blood uses controlled
crimson, Holy uses ivory-gold, and Berserk uses ember-orange so discipline
identity survives without relying on text alone.

### 5.14 Combination towers — `res://art/towers/`

All 192×192, type T. Built in the middle slot of a lane from the two elements
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

### 5.15 Battlefield — `res://art/battlefield/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `lane_path.png` | 256×256 | O | `#3A3630` |
| `build_spot.png` | 128×128 | T | `#7A7057` |
| `build_spot_combo.png` | 128×128 | T | `#9B8FC4` |
| `town_core.png` | 384×384 | T | `#8A7A5E` |


**Road tiles.** A 16-piece connectable set — straights, corners, T-junctions, a
crossroads, dead-ends and plain ground — sharing one look, so the U-bends in
GDD §13 join properly instead of being stretched strips with a notch at every
corner. 32×32 native, drawn at ×2 to land exactly on the 64-unit grid.

Edge rules are a 4-bit neighbour mask: bit0=N, bit1=E, bit2=S, bit3=W, a set bit
meaning the road continues across that edge. `path_tile_NN` is the tile for mask
NN, so an autotiler indexes them directly.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `path_tile_00.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_01.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_02.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_03.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_04.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_05.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_06.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_07.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_08.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_09.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_10.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_11.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_12.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_13.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_14.png` | 32×32 | T | `#8A6B3F` |
| `path_tile_15.png` | 32×32 | T | `#8A6B3F` |
**Regional road tiles.** The same sixteen-piece set per region, picked by the
terrain id (`path_<terrain>_NN.png`), falling back to `path_tile_NN` for any
region without one. Built from a generated set by `tools/build_road_tiles.py`,
which is where the tile-order, missing-mask and seam problems are documented.

`path_tile_NN` remains the fallback for any region without a set.

**Act I — The Verdant Maw**

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `path_ashfen_00.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_01.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_02.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_03.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_04.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_05.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_06.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_07.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_08.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_09.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_10.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_11.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_12.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_13.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_14.png` | 32×32 | T | `#6B5A44` |
| `path_ashfen_15.png` | 32×32 | T | `#6B5A44` |

**Act II — The Sunglass Waste**

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `path_saltglass_00.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_01.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_02.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_03.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_04.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_05.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_06.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_07.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_08.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_09.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_10.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_11.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_12.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_13.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_14.png` | 32×32 | T | `#D8C08A` |
| `path_saltglass_15.png` | 32×32 | T | `#D8C08A` |

**Act III — The White Teeth**

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `path_steppe_00.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_01.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_02.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_03.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_04.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_05.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_06.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_07.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_08.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_09.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_10.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_11.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_12.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_13.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_14.png` | 32×32 | T | `#8A8D95` |
| `path_steppe_15.png` | 32×32 | T | `#8A8D95` |

### 5.18 Projectiles — `res://art/vfx/`

One head per element, drawn pointing east with its wake trailing behind. The
sprite is a skin over the existing flight: the trail, filament, light, tumble and
per-level scaling all still run underneath, so a missing file costs nothing and
the shot still reads.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `projectile_fire.png` | 64×64 | T | `#E8752B` |
| `projectile_water.png` | 64×64 | T | `#54B8C8` |
| `projectile_earth.png` | 64×64 | T | `#B07A3E` |
| `projectile_air.png` | 64×64 | T | `#BFE6F0` |

Impact bursts, one per element, layered over the sparks and the blast ring at
the moment of a hit. The sparks carry direction and the ring carries radius, so
the art only has to carry the element - which is why one frame is enough.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `impact_fire.png` | 96×96 | T | `#E8752B` |
| `impact_water.png` | 96×96 | T | `#54B8C8` |
| `impact_earth.png` | 96×96 | T | `#B07A3E` |
| `impact_air.png` | 96×96 | T | `#BFE6F0` |

### 5.16 Raid — `res://art/raid/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `chieftain_ashfen.png` | 256×256 | T | `#3E5A52` |
| `chieftain_saltglass.png` | 256×256 | T | `#9FB4C4` |
| `chieftain_steppe.png` | 256×256 | T | `#9C4A3B` |
| `captive_bogkin.png` | 128×128 | T | `#4A6B4F` |
| `captive_glassborn.png` | 128×128 | T | `#6B8A9E` |
| `captive_steppehorde.png` | 128×128 | T | `#8C3A2B` |

### 5.17 UI frames — `res://art/ui/`

Nine-slice frames and bars. **Square on purpose.** These are stretched in code,
so the source only has to carry a border and a plain centre — the aspect on
screen comes from the nine-slice, not from the file. Every transparent asset in
this project is square, because every tool that makes them returns squares, and
a non-square target just letterboxes the art and shrinks it.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `ui_panel.png` | 256×256 | T | `#1A2428` |
| `ui_panel_dark.png` | 256×256 | T | `#0E1518` |
| `ui_button.png` | 256×88 | T | `#2E4048` |
| `ui_button_hover.png` | 256×88 | T | `#3E5660` |
| `ui_slot.png` | 128×128 | T | `#232F33` |
| `ui_bar_fill.png` | 128×16 | T | `#C4552E` |
| `ui_bar_back.png` | 128×16 | T | `#141C1F` |
| `ui_logo.png` | 1024×512 | T | `#E8A33D` |
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
bound in wire. Rimebound additions: a frost-split bone carapace · a coal sealed
inside an ice-and-black-iron reliquary · a broken black-iron glacier spur · an
ice-crazed whiteout lens in a weathered surveyor housing.

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
