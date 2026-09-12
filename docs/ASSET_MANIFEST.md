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
| `hero_shoot.png` | 1512×1280 | T | `#E8A33D` |

**`hero_shoot` is the tenth sheet, added 2026-09-08.** Ranged combat shipped on
2026-08-31 with no firing animation at all — `hero_ranged.gd` made no animator
call and `hero_animator.STATES` had no entry, so the Warden loosed arrows while
standing in its idle pose. Nothing caught it: the sheets are named by state and
a state nobody asks for is not a missing file, so `report` was right that every
declared asset existed.

Generated as a **state of the existing PixelLab hero**
(`create_character_state`, group `7913682d-163d-4440-82cd-acc3f6f416cb`) rather
than as new art, with the source palette snapped, so the skull, hood, red
banner, armour and colours carry from idle unchanged. The lantern is stowed in
this state and that is correct — both hands are on the bow.

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
| `enemy_loam_lurker.png` | 192×192 | T | `#4A6B4F` |
| `enemy_mire_shambler.png` | 192×192 | T | `#4F6350` |
| `enemy_fog_lantern.png` | 192×192 | T | `#4F6350` |
| `enemy_reed_stalker.png` | 192×192 | T | `#4F6350` |
| `enemy_rust_hulk.png` | 192×192 | T | `#7A4A3A` |
| `enemy_bell_priest.png` | 192×192 | T | `#7A4A3A` |
| `enemy_flake_runner.png` | 192×192 | T | `#7A4A3A` |
| `enemy_brine_drowned.png` | 192×192 | T | `#B9B3A5` |
| `enemy_salt_crawler.png` | 192×192 | T | `#B9B3A5` |
| `enemy_choir_cantor.png` | 192×192 | T | `#B9B3A5` |
| `enemy_horde_lancer.png` | 192×192 | T | `#8A7B55` |
| `enemy_horde_shieldman.png` | 192×192 | T | `#8A7B55` |
| `enemy_horde_drummer.png` | 192×192 | T | `#8A7B55` |
| `enemy_shard_wight.png` | 192×192 | T | `#7FA6C4` |
| `enemy_prism_warden.png` | 192×192 | T | `#7FA6C4` |
| `enemy_glass_singer.png` | 192×192 | T | `#7FA6C4` |
| `enemy_ember_husk.png` | 192×192 | T | `#5A4A48` |
| `enemy_cinder_hound.png` | 192×192 | T | `#5A4A48` |
| `enemy_ash_caller.png` | 192×192 | T | `#5A4A48` |
| `enemy_gate_sentinel.png` | 192×192 | T | `#7A7C80` |
| `enemy_stair_runner.png` | 192×192 | T | `#7A7C80` |
| `enemy_crown_herald.png` | 192×192 | T | `#7A7C80` |
| `enemy_cinder_runner.png` | 192×192 | T | `#4A6B4F` |
| `enemy_glass_chanter.png` | 192×192 | T | `#6B8A9E` |
| `enemy_salt_marcher.png` | 192×192 | T | `#6B8A9E` |
| `enemy_crevasse_stalker.png` | 192×192 | T | `#9CB9D8` |
| `enemy_frost_herald.png` | 192×192 | T | `#9CB9D8` |

### 5.2c Enemy idle frames — `res://art/enemies/`

All 192×192, type T, placeholder colour `#8E8A86`.

Base plus three PixelLab continuation poses. Idle fills stationary movement
and recovery; attack tells, freeze, stun and death take priority. Generation
provenance is in `ASSET_BATCH_2026-09-07.json`.

Files: `elite_avalanche_warden_idle_01.png` · `elite_avalanche_warden_idle_02.png` · `elite_avalanche_warden_idle_03.png`
Files: `elite_mirage_seer_idle_01.png` · `elite_mirage_seer_idle_02.png` · `elite_mirage_seer_idle_03.png`
Files: `elite_pack_howler_idle_01.png` · `elite_pack_howler_idle_02.png` · `elite_pack_howler_idle_03.png`
Files: `elite_siege_lizard_idle_01.png` · `elite_siege_lizard_idle_02.png` · `elite_siege_lizard_idle_03.png`
Files: `elite_white_maw_giant_idle_01.png` · `elite_white_maw_giant_idle_02.png` · `elite_white_maw_giant_idle_03.png`
Files: `elite_wolf_standard_bearer_idle_01.png` · `elite_wolf_standard_bearer_idle_02.png` · `elite_wolf_standard_bearer_idle_03.png`
Files: `enemy_cinder_runner_idle_01.png` · `enemy_cinder_runner_idle_02.png` · `enemy_cinder_runner_idle_03.png`
Files: `enemy_coalpaint_raider_idle_01.png` · `enemy_coalpaint_raider_idle_02.png` · `enemy_coalpaint_raider_idle_03.png`
Files: `enemy_crevasse_stalker_idle_01.png` · `enemy_crevasse_stalker_idle_02.png` · `enemy_crevasse_stalker_idle_03.png`
Files: `enemy_dune_burrower_idle_01.png` · `enemy_dune_burrower_idle_02.png` · `enemy_dune_burrower_idle_03.png`
Files: `enemy_ember_shaman_idle_01.png` · `enemy_ember_shaman_idle_02.png` · `enemy_ember_shaman_idle_03.png`
Files: `enemy_frost_herald_idle_01.png` · `enemy_frost_herald_idle_02.png` · `enemy_frost_herald_idle_03.png`
Files: `enemy_glass_chanter_idle_01.png` · `enemy_glass_chanter_idle_02.png` · `enemy_glass_chanter_idle_03.png`
Files: `enemy_glassguard_idle_01.png` · `enemy_glassguard_idle_02.png` · `enemy_glassguard_idle_03.png`
Files: `enemy_ice_hauler_idle_01.png` · `enemy_ice_hauler_idle_02.png` · `enemy_ice_hauler_idle_03.png`
Files: `enemy_loam_lurker_idle_01.png` · `enemy_loam_lurker_idle_02.png` · `enemy_loam_lurker_idle_03.png`
Files: `enemy_rime_marauder_idle_01.png` · `enemy_rime_marauder_idle_02.png` · `enemy_rime_marauder_idle_03.png`
Files: `enemy_rootshield_idle_01.png` · `enemy_rootshield_idle_02.png` · `enemy_rootshield_idle_03.png`
Files: `enemy_salt_marcher_idle_01.png` · `enemy_salt_marcher_idle_02.png` · `enemy_salt_marcher_idle_03.png`
Files: `enemy_scale_rider_idle_01.png` · `enemy_scale_rider_idle_02.png` · `enemy_scale_rider_idle_03.png`
Files: `enemy_snowhide_brute_idle_01.png` · `enemy_snowhide_brute_idle_02.png` · `enemy_snowhide_brute_idle_03.png`
Files: `enemy_storm_caller_idle_01.png` · `enemy_storm_caller_idle_02.png` · `enemy_storm_caller_idle_03.png`
Files: `enemy_veiled_skirmisher_idle_01.png` · `enemy_veiled_skirmisher_idle_02.png` · `enemy_veiled_skirmisher_idle_03.png`
Files: `enemy_wolf_rider_idle_01.png` · `enemy_wolf_rider_idle_02.png` · `enemy_wolf_rider_idle_03.png`

The seven regions of 2026-09-11 (acts IV to X) were fed back through
PixelLab's animator by job URL rather than posed, and ship the same base
plus three every other breed does - the walk gate holds that contract.

Files: `enemy_mire_shambler_idle_01.png` · `enemy_mire_shambler_idle_02.png` · `enemy_mire_shambler_idle_03.png`
Files: `enemy_fog_lantern_idle_01.png` · `enemy_fog_lantern_idle_02.png` · `enemy_fog_lantern_idle_03.png`
Files: `enemy_reed_stalker_idle_01.png` · `enemy_reed_stalker_idle_02.png` · `enemy_reed_stalker_idle_03.png`
Files: `enemy_rust_hulk_idle_01.png` · `enemy_rust_hulk_idle_02.png` · `enemy_rust_hulk_idle_03.png`
Files: `enemy_bell_priest_idle_01.png` · `enemy_bell_priest_idle_02.png` · `enemy_bell_priest_idle_03.png`
Files: `enemy_flake_runner_idle_01.png` · `enemy_flake_runner_idle_02.png` · `enemy_flake_runner_idle_03.png`
Files: `enemy_brine_drowned_idle_01.png` · `enemy_brine_drowned_idle_02.png` · `enemy_brine_drowned_idle_03.png`
Files: `enemy_salt_crawler_idle_01.png` · `enemy_salt_crawler_idle_02.png` · `enemy_salt_crawler_idle_03.png`
Files: `enemy_choir_cantor_idle_01.png` · `enemy_choir_cantor_idle_02.png` · `enemy_choir_cantor_idle_03.png`
Files: `enemy_horde_lancer_idle_01.png` · `enemy_horde_lancer_idle_02.png` · `enemy_horde_lancer_idle_03.png`
Files: `enemy_horde_shieldman_idle_01.png` · `enemy_horde_shieldman_idle_02.png` · `enemy_horde_shieldman_idle_03.png`
Files: `enemy_horde_drummer_idle_01.png` · `enemy_horde_drummer_idle_02.png` · `enemy_horde_drummer_idle_03.png`
Files: `enemy_shard_wight_idle_01.png` · `enemy_shard_wight_idle_02.png` · `enemy_shard_wight_idle_03.png`
Files: `enemy_prism_warden_idle_01.png` · `enemy_prism_warden_idle_02.png` · `enemy_prism_warden_idle_03.png`
Files: `enemy_glass_singer_idle_01.png` · `enemy_glass_singer_idle_02.png` · `enemy_glass_singer_idle_03.png`
Files: `enemy_ember_husk_idle_01.png` · `enemy_ember_husk_idle_02.png` · `enemy_ember_husk_idle_03.png`
Files: `enemy_cinder_hound_idle_01.png` · `enemy_cinder_hound_idle_02.png` · `enemy_cinder_hound_idle_03.png`
Files: `enemy_ash_caller_idle_01.png` · `enemy_ash_caller_idle_02.png` · `enemy_ash_caller_idle_03.png`
Files: `enemy_gate_sentinel_idle_01.png` · `enemy_gate_sentinel_idle_02.png` · `enemy_gate_sentinel_idle_03.png`
Files: `enemy_stair_runner_idle_01.png` · `enemy_stair_runner_idle_02.png` · `enemy_stair_runner_idle_03.png`
Files: `enemy_crown_herald_idle_01.png` · `enemy_crown_herald_idle_02.png` · `enemy_crown_herald_idle_03.png`

### 5.2b Enemy attack frames — `res://art/enemies/`

Owner request, 2026-09-01: any animation every enemy should have and does not.
This was the one, and it had been promised in code for months — `enemy.gd` said
"the windup animation is drawn from the rest pose" beside a state machine with
no windup animation at all. An enemy about to hit you stood perfectly still in
its standing pose for the whole 0.45s tell, which is the moment in a fight the
player reads a body hardest.

**Four frames, mapped onto the three attack states rather than played at a rate
of their own.** `Enemy._advance_attack_frames` puts the first half across the
wind-up, holds the impact pose for the whole strike, and settles through the
rest during recovery. A sequence with its own frame rate would drift out of step
the first time any of those three durations was tuned, and the failure would be
a blow that lands before the weapon does — which reads as the enemy cheating.

Frame zero is absent for the same reason it is absent from the walk lists: the
base sprite is the standing pose the swing starts from, not part of the swing.

All 192×192, type T, placeholder colour `#8E8A86`. Twenty-four sprites; the
enemies that borrow another's art inherit its swing by the same path convention.

Files: `elite_avalanche_warden_attack_01.png` · `elite_avalanche_warden_attack_02.png` · `elite_avalanche_warden_attack_03.png` · `elite_avalanche_warden_attack_04.png`
Files: `elite_mirage_seer_attack_01.png` · `elite_mirage_seer_attack_02.png` · `elite_mirage_seer_attack_03.png` · `elite_mirage_seer_attack_04.png`
Files: `elite_pack_howler_attack_01.png` · `elite_pack_howler_attack_02.png` · `elite_pack_howler_attack_03.png` · `elite_pack_howler_attack_04.png`
Files: `elite_siege_lizard_attack_01.png` · `elite_siege_lizard_attack_02.png` · `elite_siege_lizard_attack_03.png` · `elite_siege_lizard_attack_04.png`
Files: `elite_white_maw_giant_attack_01.png` · `elite_white_maw_giant_attack_02.png` · `elite_white_maw_giant_attack_03.png` · `elite_white_maw_giant_attack_04.png`
Files: `elite_wolf_standard_bearer_attack_01.png` · `elite_wolf_standard_bearer_attack_02.png` · `elite_wolf_standard_bearer_attack_03.png` · `elite_wolf_standard_bearer_attack_04.png`
Files: `enemy_cinder_runner_attack_01.png` · `enemy_cinder_runner_attack_02.png` · `enemy_cinder_runner_attack_03.png` · `enemy_cinder_runner_attack_04.png`
Files: `enemy_coalpaint_raider_attack_01.png` · `enemy_coalpaint_raider_attack_02.png` · `enemy_coalpaint_raider_attack_03.png` · `enemy_coalpaint_raider_attack_04.png`
Files: `enemy_crevasse_stalker_attack_01.png` · `enemy_crevasse_stalker_attack_02.png` · `enemy_crevasse_stalker_attack_03.png` · `enemy_crevasse_stalker_attack_04.png`
Files: `enemy_dune_burrower_attack_01.png` · `enemy_dune_burrower_attack_02.png` · `enemy_dune_burrower_attack_03.png` · `enemy_dune_burrower_attack_04.png`
Files: `enemy_ember_shaman_attack_01.png` · `enemy_ember_shaman_attack_02.png` · `enemy_ember_shaman_attack_03.png` · `enemy_ember_shaman_attack_04.png`
Files: `enemy_frost_herald_attack_01.png` · `enemy_frost_herald_attack_02.png` · `enemy_frost_herald_attack_03.png` · `enemy_frost_herald_attack_04.png`
Files: `enemy_glass_chanter_attack_01.png` · `enemy_glass_chanter_attack_02.png` · `enemy_glass_chanter_attack_03.png` · `enemy_glass_chanter_attack_04.png`
Files: `enemy_glassguard_attack_01.png` · `enemy_glassguard_attack_02.png` · `enemy_glassguard_attack_03.png` · `enemy_glassguard_attack_04.png`
Files: `enemy_ice_hauler_attack_01.png` · `enemy_ice_hauler_attack_02.png` · `enemy_ice_hauler_attack_03.png` · `enemy_ice_hauler_attack_04.png`
Files: `enemy_loam_lurker_attack_01.png` · `enemy_loam_lurker_attack_02.png` · `enemy_loam_lurker_attack_03.png` · `enemy_loam_lurker_attack_04.png`
Files: `enemy_rime_marauder_attack_01.png` · `enemy_rime_marauder_attack_02.png` · `enemy_rime_marauder_attack_03.png` · `enemy_rime_marauder_attack_04.png`
Files: `enemy_rootshield_attack_01.png` · `enemy_rootshield_attack_02.png` · `enemy_rootshield_attack_03.png` · `enemy_rootshield_attack_04.png`
Files: `enemy_salt_marcher_attack_01.png` · `enemy_salt_marcher_attack_02.png` · `enemy_salt_marcher_attack_03.png` · `enemy_salt_marcher_attack_04.png`
Files: `enemy_scale_rider_attack_01.png` · `enemy_scale_rider_attack_02.png` · `enemy_scale_rider_attack_03.png` · `enemy_scale_rider_attack_04.png`
Files: `enemy_snowhide_brute_attack_01.png` · `enemy_snowhide_brute_attack_02.png` · `enemy_snowhide_brute_attack_03.png` · `enemy_snowhide_brute_attack_04.png`
Files: `enemy_storm_caller_attack_01.png` · `enemy_storm_caller_attack_02.png` · `enemy_storm_caller_attack_03.png` · `enemy_storm_caller_attack_04.png`
Files: `enemy_veiled_skirmisher_attack_01.png` · `enemy_veiled_skirmisher_attack_02.png` · `enemy_veiled_skirmisher_attack_03.png` · `enemy_veiled_skirmisher_attack_04.png`
Files: `enemy_mire_shambler_attack_01.png` · `enemy_mire_shambler_attack_02.png` · `enemy_mire_shambler_attack_03.png` · `enemy_mire_shambler_attack_04.png`
Files: `enemy_fog_lantern_attack_01.png` · `enemy_fog_lantern_attack_02.png` · `enemy_fog_lantern_attack_03.png` · `enemy_fog_lantern_attack_04.png`
Files: `enemy_reed_stalker_attack_01.png` · `enemy_reed_stalker_attack_02.png` · `enemy_reed_stalker_attack_03.png` · `enemy_reed_stalker_attack_04.png`
Files: `enemy_rust_hulk_attack_01.png` · `enemy_rust_hulk_attack_02.png` · `enemy_rust_hulk_attack_03.png` · `enemy_rust_hulk_attack_04.png`
Files: `enemy_bell_priest_attack_01.png` · `enemy_bell_priest_attack_02.png` · `enemy_bell_priest_attack_03.png` · `enemy_bell_priest_attack_04.png`
Files: `enemy_flake_runner_attack_01.png` · `enemy_flake_runner_attack_02.png` · `enemy_flake_runner_attack_03.png` · `enemy_flake_runner_attack_04.png`
Files: `enemy_brine_drowned_attack_01.png` · `enemy_brine_drowned_attack_02.png` · `enemy_brine_drowned_attack_03.png` · `enemy_brine_drowned_attack_04.png`
Files: `enemy_salt_crawler_attack_01.png` · `enemy_salt_crawler_attack_02.png` · `enemy_salt_crawler_attack_03.png` · `enemy_salt_crawler_attack_04.png`
Files: `enemy_choir_cantor_attack_01.png` · `enemy_choir_cantor_attack_02.png` · `enemy_choir_cantor_attack_03.png` · `enemy_choir_cantor_attack_04.png`
Files: `enemy_horde_lancer_attack_01.png` · `enemy_horde_lancer_attack_02.png` · `enemy_horde_lancer_attack_03.png` · `enemy_horde_lancer_attack_04.png`
Files: `enemy_horde_shieldman_attack_01.png` · `enemy_horde_shieldman_attack_02.png` · `enemy_horde_shieldman_attack_03.png` · `enemy_horde_shieldman_attack_04.png`
Files: `enemy_horde_drummer_attack_01.png` · `enemy_horde_drummer_attack_02.png` · `enemy_horde_drummer_attack_03.png` · `enemy_horde_drummer_attack_04.png`
Files: `enemy_shard_wight_attack_01.png` · `enemy_shard_wight_attack_02.png` · `enemy_shard_wight_attack_03.png` · `enemy_shard_wight_attack_04.png`
Files: `enemy_prism_warden_attack_01.png` · `enemy_prism_warden_attack_02.png` · `enemy_prism_warden_attack_03.png` · `enemy_prism_warden_attack_04.png`
Files: `enemy_glass_singer_attack_01.png` · `enemy_glass_singer_attack_02.png` · `enemy_glass_singer_attack_03.png` · `enemy_glass_singer_attack_04.png`
Files: `enemy_ember_husk_attack_01.png` · `enemy_ember_husk_attack_02.png` · `enemy_ember_husk_attack_03.png` · `enemy_ember_husk_attack_04.png`
Files: `enemy_cinder_hound_attack_01.png` · `enemy_cinder_hound_attack_02.png` · `enemy_cinder_hound_attack_03.png` · `enemy_cinder_hound_attack_04.png`
Files: `enemy_ash_caller_attack_01.png` · `enemy_ash_caller_attack_02.png` · `enemy_ash_caller_attack_03.png` · `enemy_ash_caller_attack_04.png`
Files: `enemy_gate_sentinel_attack_01.png` · `enemy_gate_sentinel_attack_02.png` · `enemy_gate_sentinel_attack_03.png` · `enemy_gate_sentinel_attack_04.png`
Files: `enemy_stair_runner_attack_01.png` · `enemy_stair_runner_attack_02.png` · `enemy_stair_runner_attack_03.png` · `enemy_stair_runner_attack_04.png`
Files: `enemy_crown_herald_attack_01.png` · `enemy_crown_herald_attack_02.png` · `enemy_crown_herald_attack_03.png` · `enemy_crown_herald_attack_04.png`
Files: `enemy_wolf_rider_attack_01.png` · `enemy_wolf_rider_attack_02.png` · `enemy_wolf_rider_attack_03.png` · `enemy_wolf_rider_attack_04.png`


### 5.2a Enemy walk frames — `res://art/enemies/`

Owner request, 2026-09-01: "give all enemies walking pixellab animations too".
Every enemy in the game was a single static PNG slid along the road, with all of
its apparent motion coming from `SpriteAnimator`'s bounce and lean. That is a
good fallback — it carried the game for months — and it is not legs.

**Frame zero is deliberately absent from these lists.** The convention
`GameData.load_move_frames` implements excludes the base sprite from the walk
loop, because the base is a standing pose: a cycle alternating between standing
and mid-stride reads as the sprite being *replaced* rather than animated. That
was learned on the wildlife and the same rule applies here.

Eighteen sprites cover twenty-two enemies. Six enemies carry a `sprite_id`
pointing at another's art, so they inherit its walk for free — the frames are
found by deriving the path from the sprite, exactly as the resting pose is.

Split by region so each group can state its own placeholder colour, matching how
the enemy table above is grouped.


#### Jungle walk frames

All 192×192, type T, placeholder colour `#4A6B4F`.

Files: `elite_pack_howler_move_01.png` · `elite_pack_howler_move_02.png` · `elite_pack_howler_move_03.png` · `elite_pack_howler_move_04.png`
Files: `elite_wolf_standard_bearer_move_01.png` · `elite_wolf_standard_bearer_move_02.png` · `elite_wolf_standard_bearer_move_03.png` · `elite_wolf_standard_bearer_move_04.png`
Files: `enemy_coalpaint_raider_move_01.png` · `enemy_coalpaint_raider_move_02.png` · `enemy_coalpaint_raider_move_03.png` · `enemy_coalpaint_raider_move_04.png`
Files: `enemy_ember_shaman_move_01.png` · `enemy_ember_shaman_move_02.png` · `enemy_ember_shaman_move_03.png` · `enemy_ember_shaman_move_04.png`
Files: `enemy_rootshield_move_01.png` · `enemy_rootshield_move_02.png` · `enemy_rootshield_move_03.png` · `enemy_rootshield_move_04.png`
Files: `enemy_wolf_rider_move_01.png` · `enemy_wolf_rider_move_02.png` · `enemy_wolf_rider_move_03.png` · `enemy_wolf_rider_move_04.png`
Files: `enemy_loam_lurker_move_01.png` · `enemy_loam_lurker_move_02.png` · `enemy_loam_lurker_move_03.png` · `enemy_loam_lurker_move_04.png`
Files: `enemy_cinder_runner_move_01.png` · `enemy_cinder_runner_move_02.png` · `enemy_cinder_runner_move_03.png` · `enemy_cinder_runner_move_04.png`


#### Desert walk frames

All 192×192, type T, placeholder colour `#6B8A9E`.

Files: `elite_mirage_seer_move_01.png` · `elite_mirage_seer_move_02.png` · `elite_mirage_seer_move_03.png` · `elite_mirage_seer_move_04.png`
Files: `elite_siege_lizard_move_01.png` · `elite_siege_lizard_move_02.png` · `elite_siege_lizard_move_03.png` · `elite_siege_lizard_move_04.png`
Files: `enemy_dune_burrower_move_01.png` · `enemy_dune_burrower_move_02.png` · `enemy_dune_burrower_move_03.png` · `enemy_dune_burrower_move_04.png`
Files: `enemy_glassguard_move_01.png` · `enemy_glassguard_move_02.png` · `enemy_glassguard_move_03.png` · `enemy_glassguard_move_04.png`
Files: `enemy_scale_rider_move_01.png` · `enemy_scale_rider_move_02.png` · `enemy_scale_rider_move_03.png` · `enemy_scale_rider_move_04.png`
Files: `enemy_veiled_skirmisher_move_01.png` · `enemy_veiled_skirmisher_move_02.png` · `enemy_veiled_skirmisher_move_03.png` · `enemy_veiled_skirmisher_move_04.png`
Files: `enemy_glass_chanter_move_01.png` · `enemy_glass_chanter_move_02.png` · `enemy_glass_chanter_move_03.png` · `enemy_glass_chanter_move_04.png`
Files: `enemy_salt_marcher_move_01.png` · `enemy_salt_marcher_move_02.png` · `enemy_salt_marcher_move_03.png` · `enemy_salt_marcher_move_04.png`


#### Snow walk frames

All 192×192, type T, placeholder colour `#9CB9D8`.

Files: `elite_avalanche_warden_move_01.png` · `elite_avalanche_warden_move_02.png` · `elite_avalanche_warden_move_03.png` · `elite_avalanche_warden_move_04.png`
Files: `elite_white_maw_giant_move_01.png` · `elite_white_maw_giant_move_02.png` · `elite_white_maw_giant_move_03.png` · `elite_white_maw_giant_move_04.png`
Files: `enemy_ice_hauler_move_01.png` · `enemy_ice_hauler_move_02.png` · `enemy_ice_hauler_move_03.png` · `enemy_ice_hauler_move_04.png`
Files: `enemy_rime_marauder_move_01.png` · `enemy_rime_marauder_move_02.png` · `enemy_rime_marauder_move_03.png` · `enemy_rime_marauder_move_04.png`
Files: `enemy_snowhide_brute_move_01.png` · `enemy_snowhide_brute_move_02.png` · `enemy_snowhide_brute_move_03.png` · `enemy_snowhide_brute_move_04.png`
Files: `enemy_storm_caller_move_01.png` · `enemy_storm_caller_move_02.png` · `enemy_storm_caller_move_03.png` · `enemy_storm_caller_move_04.png`
Files: `enemy_crevasse_stalker_move_01.png` · `enemy_crevasse_stalker_move_02.png` · `enemy_crevasse_stalker_move_03.png` · `enemy_crevasse_stalker_move_04.png`
Files: `enemy_frost_herald_move_01.png` · `enemy_frost_herald_move_02.png` · `enemy_frost_herald_move_03.png` · `enemy_frost_herald_move_04.png`


#### Hollow Marches walk frames

All 192×192, type T, placeholder colour `#4F6350`.

Files: `enemy_mire_shambler_move_01.png` · `enemy_mire_shambler_move_02.png` · `enemy_mire_shambler_move_03.png` · `enemy_mire_shambler_move_04.png`
Files: `enemy_fog_lantern_move_01.png` · `enemy_fog_lantern_move_02.png` · `enemy_fog_lantern_move_03.png` · `enemy_fog_lantern_move_04.png`
Files: `enemy_reed_stalker_move_01.png` · `enemy_reed_stalker_move_02.png` · `enemy_reed_stalker_move_03.png` · `enemy_reed_stalker_move_04.png`

#### Rustwood walk frames

All 192×192, type T, placeholder colour `#7A4A3A`.

Files: `enemy_rust_hulk_move_01.png` · `enemy_rust_hulk_move_02.png` · `enemy_rust_hulk_move_03.png` · `enemy_rust_hulk_move_04.png`
Files: `enemy_bell_priest_move_01.png` · `enemy_bell_priest_move_02.png` · `enemy_bell_priest_move_03.png` · `enemy_bell_priest_move_04.png`
Files: `enemy_flake_runner_move_01.png` · `enemy_flake_runner_move_02.png` · `enemy_flake_runner_move_03.png` · `enemy_flake_runner_move_04.png`

#### Saltpan walk frames

All 192×192, type T, placeholder colour `#B9B3A5`.

Files: `enemy_brine_drowned_move_01.png` · `enemy_brine_drowned_move_02.png` · `enemy_brine_drowned_move_03.png` · `enemy_brine_drowned_move_04.png`
Files: `enemy_salt_crawler_move_01.png` · `enemy_salt_crawler_move_02.png` · `enemy_salt_crawler_move_03.png` · `enemy_salt_crawler_move_04.png`
Files: `enemy_choir_cantor_move_01.png` · `enemy_choir_cantor_move_02.png` · `enemy_choir_cantor_move_03.png` · `enemy_choir_cantor_move_04.png`

#### Iron Steppe walk frames

All 192×192, type T, placeholder colour `#8A7B55`.

Files: `enemy_horde_lancer_move_01.png` · `enemy_horde_lancer_move_02.png` · `enemy_horde_lancer_move_03.png` · `enemy_horde_lancer_move_04.png`
Files: `enemy_horde_shieldman_move_01.png` · `enemy_horde_shieldman_move_02.png` · `enemy_horde_shieldman_move_03.png` · `enemy_horde_shieldman_move_04.png`
Files: `enemy_horde_drummer_move_01.png` · `enemy_horde_drummer_move_02.png` · `enemy_horde_drummer_move_03.png` · `enemy_horde_drummer_move_04.png`

#### Glass Fields walk frames

All 192×192, type T, placeholder colour `#7FA6C4`.

Files: `enemy_shard_wight_move_01.png` · `enemy_shard_wight_move_02.png` · `enemy_shard_wight_move_03.png` · `enemy_shard_wight_move_04.png`
Files: `enemy_prism_warden_move_01.png` · `enemy_prism_warden_move_02.png` · `enemy_prism_warden_move_03.png` · `enemy_prism_warden_move_04.png`
Files: `enemy_glass_singer_move_01.png` · `enemy_glass_singer_move_02.png` · `enemy_glass_singer_move_03.png` · `enemy_glass_singer_move_04.png`

#### Ashen Reach walk frames

All 192×192, type T, placeholder colour `#5A4A48`.

Files: `enemy_ember_husk_move_01.png` · `enemy_ember_husk_move_02.png` · `enemy_ember_husk_move_03.png` · `enemy_ember_husk_move_04.png`
Files: `enemy_cinder_hound_move_01.png` · `enemy_cinder_hound_move_02.png` · `enemy_cinder_hound_move_03.png` · `enemy_cinder_hound_move_04.png`
Files: `enemy_ash_caller_move_01.png` · `enemy_ash_caller_move_02.png` · `enemy_ash_caller_move_03.png` · `enemy_ash_caller_move_04.png`

#### Last Terrace walk frames

All 192×192, type T, placeholder colour `#7A7C80`.

Files: `enemy_gate_sentinel_move_01.png` · `enemy_gate_sentinel_move_02.png` · `enemy_gate_sentinel_move_03.png` · `enemy_gate_sentinel_move_04.png`
Files: `enemy_stair_runner_move_01.png` · `enemy_stair_runner_move_02.png` · `enemy_stair_runner_move_03.png` · `enemy_stair_runner_move_04.png`
Files: `enemy_crown_herald_move_01.png` · `enemy_crown_herald_move_02.png` · `enemy_crown_herald_move_03.png` · `enemy_crown_herald_move_04.png`

### 5.3 Bosses — `res://art/bosses/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `boss_drowned_choir.png` | 384×384 | T | `#2E4A52` |
| `boss_mirrorfang.png` | 384×384 | T | `#8FA8B8` |
| `boss_rust_crown.png` | 384×384 | T | `#8C3A2B` |
| `boss_chainmaker.png` | 384×384 | T | `#2A3140` |
| `boss_mistwarden.png` | 384×384 | T | `#5A6A5E` |
| `boss_rustmother.png` | 384×384 | T | `#7A4326` |
| `boss_brinefather.png` | 384×384 | T | `#7E9691` |
| `boss_horde_warlord.png` | 384×384 | T | `#6B5A34` |
| `boss_glass_colossus.png` | 384×384 | T | `#6FA4C8` |
| `boss_cinder_titan.png` | 384×384 | T | `#6B3320` |
| `boss_gatekeeper.png` | 384×384 | T | `#78797B` |

> The seven added on 2026-09-11 are base sprites only. The four that shipped
> before them also carry idle, move and attack sequences; a boss with no
> authored sequence holds its pose, which the frame loader already handles.
> Declaring frames that have not been drawn would fail the art report, so they
> are not declared until they exist.

#### 5.3b Boss idle frames

All 384×384, type T, placeholder colour `#8E8A86`.

Generated on the shipped 192-native lattice, restored with nearest-neighbour
scaling; base plus three poses. See `BOSS_IDLE_BATCH_2026-09-07.json`.

Files: `boss_drowned_choir_idle_01.png` · `boss_drowned_choir_idle_02.png` · `boss_drowned_choir_idle_03.png`
Files: `boss_mirrorfang_idle_01.png` · `boss_mirrorfang_idle_02.png` · `boss_mirrorfang_idle_03.png`
Files: `boss_rust_crown_idle_01.png` · `boss_rust_crown_idle_02.png` · `boss_rust_crown_idle_03.png`
Files: `boss_chainmaker_idle_01.png` · `boss_chainmaker_idle_02.png` · `boss_chainmaker_idle_03.png`
Files: `boss_mistwarden_idle_01.png` · `boss_mistwarden_idle_02.png` · `boss_mistwarden_idle_03.png`
Files: `boss_rustmother_idle_01.png` · `boss_rustmother_idle_02.png` · `boss_rustmother_idle_03.png`
Files: `boss_brinefather_idle_01.png` · `boss_brinefather_idle_02.png` · `boss_brinefather_idle_03.png`
Files: `boss_horde_warlord_idle_01.png` · `boss_horde_warlord_idle_02.png` · `boss_horde_warlord_idle_03.png`
Files: `boss_glass_colossus_idle_01.png` · `boss_glass_colossus_idle_02.png` · `boss_glass_colossus_idle_03.png`
Files: `boss_cinder_titan_idle_01.png` · `boss_cinder_titan_idle_02.png` · `boss_cinder_titan_idle_03.png`
Files: `boss_gatekeeper_idle_01.png` · `boss_gatekeeper_idle_02.png` · `boss_gatekeeper_idle_03.png`

#### 5.3a Boss walk and attack frames

The bosses were the last things in the game with no legs. Every walker got a
walk cycle on 2026-09-01 and a swing on 2026-09-02; the four bosses got neither,
because the generator caps a frame at 256 and these are 384. Seven more bosses
arrived with the ten-act campaign on 2026-09-11 and needed the same treatment;
see the note below them for why theirs came out differently.

**They are 192-native art upscaled**, which is what makes this work: halving to
192, animating, and doubling back with nearest-neighbour lands on exactly the
lattice the base sprites already sit on. That was checked by eye against the
originals rather than by a difference count — the count says 7-9% of texels move
and every one of them is edge antialiasing, which is why the first look at this
concluded, wrongly, that it could not be done.

No code changed. A boss's frames are found by the same convention as everything
else, so putting the files at the derived paths was the whole integration.

All 384×384, type T, placeholder colour `#2E4A52`.

Files: `boss_chainmaker_move_01.png` … `boss_chainmaker_move_04.png` ·
`boss_chainmaker_attack_01.png` … `boss_chainmaker_attack_04.png`
Files: `boss_drowned_choir_move_01.png` … `boss_drowned_choir_move_04.png` ·
`boss_drowned_choir_attack_01.png` … `boss_drowned_choir_attack_04.png`
Files: `boss_mirrorfang_move_01.png` … `boss_mirrorfang_move_04.png` ·
`boss_mirrorfang_attack_01.png` … `boss_mirrorfang_attack_04.png`
Files: `boss_rust_crown_move_01.png` … `boss_rust_crown_move_04.png` ·
`boss_rust_crown_attack_01.png` … `boss_rust_crown_attack_04.png`

**The seven Act IV-X bosses are posed, not generated**, and that is worth
knowing before anyone compares them. `animate_image` wants the source frame as
base64 or as a public URL, and these sprites were not published when their
frames were needed; asked for the same boss by description instead,
`create_1_direction_object` returned a stone archway rather than a figure.

So each frame is the boss's own art deformed by height: the horizontal offset
and the vertical lift are functions of how far up the sprite a row sits, which
shears the legs against the torso, sways the head further than the hips, and
leaves the foot row exactly where it was. That is articulation rather than the
whole-sprite bob `Enemy` already applies every frame, which is the bar a frame
has to clear to be worth having at all.

They are replaceable in place, by convention, the moment the art is fetchable by
URL - which it is as soon as this lands on the public repository.

Files: `boss_mistwarden_move_01.png` … `boss_mistwarden_move_04.png` ·
`boss_mistwarden_attack_01.png` … `boss_mistwarden_attack_04.png`
Files: `boss_rustmother_move_01.png` … `boss_rustmother_move_04.png` ·
`boss_rustmother_attack_01.png` … `boss_rustmother_attack_04.png`
Files: `boss_brinefather_move_01.png` … `boss_brinefather_move_04.png` ·
`boss_brinefather_attack_01.png` … `boss_brinefather_attack_04.png`
Files: `boss_horde_warlord_move_01.png` … `boss_horde_warlord_move_04.png` ·
`boss_horde_warlord_attack_01.png` … `boss_horde_warlord_attack_04.png`
Files: `boss_glass_colossus_move_01.png` … `boss_glass_colossus_move_04.png` ·
`boss_glass_colossus_attack_01.png` … `boss_glass_colossus_attack_04.png`
Files: `boss_cinder_titan_move_01.png` … `boss_cinder_titan_move_04.png` ·
`boss_cinder_titan_attack_01.png` … `boss_cinder_titan_attack_04.png`
Files: `boss_gatekeeper_move_01.png` … `boss_gatekeeper_move_04.png` ·
`boss_gatekeeper_attack_01.png` … `boss_gatekeeper_attack_04.png`

### 5.4 Towers — `res://art/towers/`

All 192×192, type T. Placeholder colour by element.

| File | Element | Colour |
|------|---------|--------|
| `tower_ember_spire.png` | Fire | `#C4552E` |
| `tower_pyre_cannon.png` | Fire | `#C4552E` |
| `tower_rime_lance.png` | Frost | `#7FA6BF` |
| `tower_hoarfrost_bell.png` | Frost | `#7FA6BF` |
| `tower_healing_well.png` | Frost | `#7FA6BF` |
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
| `tower_cinder_moat.png` | Fire | `#C4552E` |
| `tower_ash_thrower.png` | Fire | `#C4552E` |
| `tower_rime_ward.png` | Frost | `#7FA6BF` |
| `tower_hailcaster.png` | Frost | `#7FA6BF` |
| `tower_scree_gun.png` | Stone | `#7A6E5C` |
| `tower_barrow_stake.png` | Stone | `#7A6E5C` |
| `tower_squall_vane.png` | Storm | `#9B8FC4` |
| `tower_gale_lance.png` | Storm | `#9B8FC4` |

### 5.4b Tower idle frames — `res://art/towers/`

All 192×192, type T, placeholder colour `#6E667A`.

The conventional base sprite is runtime pose zero. PixelLab generates four
interior/interpolation poses with that same source pinned as both endpoints;
poses 01–03 ship, while the exact terminal duplicate is only the loop target.

Files: `tower_arc_coil_idle_01.png` … `tower_arc_coil_idle_03.png`
Files: `tower_ashen_censer_idle_01.png` … `tower_ashen_censer_idle_03.png`
Files: `tower_bastion_idle_01.png` … `tower_bastion_idle_03.png`
Files: `tower_blizzard_idle_01.png` … `tower_blizzard_idle_03.png`
Files: `tower_bulwark_idle_01.png` … `tower_bulwark_idle_03.png`
Files: `tower_cinder_lance_idle_01.png` … `tower_cinder_lance_idle_03.png`
Files: `tower_conflagration_idle_01.png` … `tower_conflagration_idle_03.png`
Files: `tower_deep_freeze_idle_01.png` … `tower_deep_freeze_idle_03.png`
Files: `tower_ember_spire_idle_01.png` … `tower_ember_spire_idle_03.png`
Files: `tower_firestorm_idle_01.png` … `tower_firestorm_idle_03.png`
Files: `tower_gale_turret_idle_01.png` … `tower_gale_turret_idle_03.png`
Files: `tower_glacial_mortar_idle_01.png` … `tower_glacial_mortar_idle_03.png`
Files: `tower_glacier_idle_01.png` … `tower_glacier_idle_03.png`
Files: `tower_grit_sling_idle_01.png` … `tower_grit_sling_idle_03.png`
Files: `tower_healing_well_idle_01.png` … `tower_healing_well_idle_03.png`
Files: `tower_hoarfrost_bell_idle_01.png` … `tower_hoarfrost_bell_idle_03.png`
Files: `tower_magma_idle_01.png` … `tower_magma_idle_03.png`
Files: `tower_pyre_cannon_idle_01.png` … `tower_pyre_cannon_idle_03.png`
Files: `tower_quake_idle_01.png` … `tower_quake_idle_03.png`
Files: `tower_rime_lance_idle_01.png` … `tower_rime_lance_idle_03.png`
Files: `tower_shard_thrower_idle_01.png` … `tower_shard_thrower_idle_03.png`
Files: `tower_steam_burst_idle_01.png` … `tower_steam_burst_idle_03.png`
Files: `tower_stonewatch_idle_01.png` … `tower_stonewatch_idle_03.png`
Files: `tower_stormvane_idle_01.png` … `tower_stormvane_idle_03.png`
Files: `tower_tempest_idle_01.png` … `tower_tempest_idle_03.png`
Files: `tower_tide_caller_idle_01.png` … `tower_tide_caller_idle_03.png`
Files: `tower_zephyr_needle_idle_01.png` … `tower_zephyr_needle_idle_03.png`
Files: `tower_cinder_moat_idle_01.png` … `tower_cinder_moat_idle_03.png`
Files: `tower_ash_thrower_idle_01.png` … `tower_ash_thrower_idle_03.png`
Files: `tower_rime_ward_idle_01.png` … `tower_rime_ward_idle_03.png`
Files: `tower_hailcaster_idle_01.png` … `tower_hailcaster_idle_03.png`
Files: `tower_scree_gun_idle_01.png` … `tower_scree_gun_idle_03.png`
Files: `tower_barrow_stake_idle_01.png` … `tower_barrow_stake_idle_03.png`
Files: `tower_squall_vane_idle_01.png` … `tower_squall_vane_idle_03.png`
Files: `tower_gale_lance_idle_01.png` … `tower_gale_lance_idle_03.png`

### 5.4c Tower firing frames — `res://art/towers/`

All 192×192, type T, placeholder colour `#6E667A`.

**Every tower fires.** Three authored discharge/recovery poses each,
played once on the existing host/guest firing event before the ordinary
idle resumes. `structure_art_check` requires all three for every tower, so
this section and `data/towers/` cannot drift apart without a red gate.

Provenance is split across three ledgers because the set was built in three
passes: `TOWER_FIRE_BATCH_2026-09-08.json` (the four-tower pilot),
`TOWER_FIRE_COMPLETION_2026-09-08.json` (the next twenty) and
`TOWER_FIRE_REMEDIAL_2026-09-08.json` (two never generated, plus the
packages regenerated after contact-sheet review rejected them).

Files: `tower_pyre_cannon_attack_01.png` … `tower_pyre_cannon_attack_03.png`
Files: `tower_arc_coil_attack_01.png` … `tower_arc_coil_attack_03.png`
Files: `tower_glacial_mortar_attack_01.png` … `tower_glacial_mortar_attack_03.png`
Files: `tower_grit_sling_attack_01.png` … `tower_grit_sling_attack_03.png`
Files: `tower_ashen_censer_attack_01.png` … `tower_ashen_censer_attack_03.png`
Files: `tower_bastion_attack_01.png` … `tower_bastion_attack_03.png`
Files: `tower_blizzard_attack_01.png` … `tower_blizzard_attack_03.png`
Files: `tower_bulwark_attack_01.png` … `tower_bulwark_attack_03.png`
Files: `tower_cinder_lance_attack_01.png` … `tower_cinder_lance_attack_03.png`
Files: `tower_conflagration_attack_01.png` … `tower_conflagration_attack_03.png`
Files: `tower_deep_freeze_attack_01.png` … `tower_deep_freeze_attack_03.png`
Files: `tower_ember_spire_attack_01.png` … `tower_ember_spire_attack_03.png`
Files: `tower_firestorm_attack_01.png` … `tower_firestorm_attack_03.png`
Files: `tower_gale_turret_attack_01.png` … `tower_gale_turret_attack_03.png`
Files: `tower_glacier_attack_01.png` … `tower_glacier_attack_03.png`
Files: `tower_healing_well_attack_01.png` … `tower_healing_well_attack_03.png`
Files: `tower_hoarfrost_bell_attack_01.png` … `tower_hoarfrost_bell_attack_03.png`
Files: `tower_magma_attack_01.png` … `tower_magma_attack_03.png`
Files: `tower_quake_attack_01.png` … `tower_quake_attack_03.png`
Files: `tower_cinder_moat_attack_01.png` … `tower_cinder_moat_attack_03.png`
Files: `tower_ash_thrower_attack_01.png` … `tower_ash_thrower_attack_03.png`
Files: `tower_rime_ward_attack_01.png` … `tower_rime_ward_attack_03.png`
Files: `tower_hailcaster_attack_01.png` … `tower_hailcaster_attack_03.png`
Files: `tower_scree_gun_attack_01.png` … `tower_scree_gun_attack_03.png`
Files: `tower_barrow_stake_attack_01.png` … `tower_barrow_stake_attack_03.png`
Files: `tower_squall_vane_attack_01.png` … `tower_squall_vane_attack_03.png`
Files: `tower_gale_lance_attack_01.png` … `tower_gale_lance_attack_03.png`
Files: `tower_rime_lance_attack_01.png` … `tower_rime_lance_attack_03.png`
Files: `tower_shard_thrower_attack_01.png` … `tower_shard_thrower_attack_03.png`
Files: `tower_steam_burst_attack_01.png` … `tower_steam_burst_attack_03.png`
Files: `tower_stonewatch_attack_01.png` … `tower_stonewatch_attack_03.png`
Files: `tower_stormvane_attack_01.png` … `tower_stormvane_attack_03.png`
Files: `tower_tempest_attack_01.png` … `tower_tempest_attack_03.png`
Files: `tower_tide_caller_attack_01.png` … `tower_tide_caller_attack_03.png`
Files: `tower_zephyr_needle_attack_01.png` … `tower_zephyr_needle_attack_03.png`

### 5.5 City — `res://art/city/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `city_base.png` | 512×512 | T | `#8A7A5E` |
| `city_damage_1.png` | 512×512 | T | `#7A6A4E` |
| `city_damage_2.png` | 512×512 | T | `#6A5A3E` |
| `city_damage_3.png` | 512×512 | T | `#5A4A2E` |
| `city_base_idle_01.png` | 512×512 | T | `#8A7A5E` |
| `city_base_idle_02.png` | 512×512 | T | `#8A7A5E` |
| `city_base_idle_03.png` | 512×512 | T | `#8A7A5E` |
| `city_base_idle_04.png` | 512×512 | T | `#8A7A5E` |
| `city_damage_1_idle_01.png` | 512×512 | T | `#7A6A4E` |
| `city_damage_1_idle_02.png` | 512×512 | T | `#7A6A4E` |
| `city_damage_1_idle_03.png` | 512×512 | T | `#7A6A4E` |
| `city_damage_1_idle_04.png` | 512×512 | T | `#7A6A4E` |
| `city_damage_2_idle_01.png` | 512×512 | T | `#6A5A3E` |
| `city_damage_2_idle_02.png` | 512×512 | T | `#6A5A3E` |
| `city_damage_2_idle_03.png` | 512×512 | T | `#6A5A3E` |
| `city_damage_2_idle_04.png` | 512×512 | T | `#6A5A3E` |
| `city_damage_3_idle_01.png` | 512×512 | T | `#5A4A2E` |
| `city_damage_3_idle_02.png` | 512×512 | T | `#5A4A2E` |
| `city_damage_3_idle_03.png` | 512×512 | T | `#5A4A2E` |
| `city_damage_3_idle_04.png` | 512×512 | T | `#5A4A2E` |
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

### 5.5a Merchants — `res://art/city/`

Whoever is in town selling things. Travellers until enough business settles
them, at which point the same sprite simply stops leaving; there is no second
"resident" drawing, because the person is the same person and the shop is the
same shop.

128x128 rather than the buildings' 192x192: a merchant is a figure standing
inside the plot ring, not a structure on it, and drawing them the same size
would make a man with a handcart the equal of the Forge.

They stand on a small cobblestone plinth, which is the town's own convention -
every building sits on one. The first generation put each of them on a patch of
sand and grass instead, which is precisely the artefact reported from play on
towers and enemies, so all three were regenerated rather than trimmed. Colour
alone cannot separate grass from a green hood or a green potion bottle, and this
merchant has both.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `merchant_alchemist.png` | 128×128 | T | `#4C6B45` |
| `merchant_relic_peddler.png` | 128×128 | T | `#48557A` |
| `merchant_quartermaster.png` | 128×128 | T | `#6B6258` |

### 5.5b Building tiers and idle frames — `res://art/city/`

All 192×192, type T, placeholder colour `#62584B`.

Tier one keeps the conventional base path. Every tier has its own four-pose
package: the base/tier sprite is pose zero and poses 01–03 are the shipped
PixelLab continuation frames.

Files: `building_forge_idle_01.png` … `building_forge_idle_03.png`
Files: `building_forge_tier_02.png`
Files: `building_forge_tier_02_idle_01.png` … `building_forge_tier_02_idle_03.png`
Files: `building_forge_tier_03.png`
Files: `building_forge_tier_03_idle_01.png` … `building_forge_tier_03_idle_03.png`

Files: `building_granary_idle_01.png` … `building_granary_idle_03.png`
Files: `building_granary_tier_02.png`
Files: `building_granary_tier_02_idle_01.png` … `building_granary_tier_02_idle_03.png`
Files: `building_granary_tier_03.png`
Files: `building_granary_tier_03_idle_01.png` … `building_granary_tier_03_idle_03.png`

Files: `building_market_idle_01.png` … `building_market_idle_03.png`
Files: `building_market_tier_02.png`
Files: `building_market_tier_02_idle_01.png` … `building_market_tier_02_idle_03.png`
Files: `building_market_tier_03.png`
Files: `building_market_tier_03_idle_01.png` … `building_market_tier_03_idle_03.png`

Files: `building_sanctum_idle_01.png` … `building_sanctum_idle_03.png`
Files: `building_sanctum_tier_02.png`
Files: `building_sanctum_tier_02_idle_01.png` … `building_sanctum_tier_02_idle_03.png`
Files: `building_sanctum_tier_03.png`
Files: `building_sanctum_tier_03_idle_01.png` … `building_sanctum_tier_03_idle_03.png`

Files: `building_scavenging_post_idle_01.png` … `building_scavenging_post_idle_03.png`
Files: `building_scavenging_post_tier_02.png`
Files: `building_scavenging_post_tier_02_idle_01.png` … `building_scavenging_post_tier_02_idle_03.png`
Files: `building_scavenging_post_tier_03.png`
Files: `building_scavenging_post_tier_03_idle_01.png` … `building_scavenging_post_tier_03_idle_03.png`

Files: `building_town_hall_idle_01.png` … `building_town_hall_idle_03.png`
Files: `building_town_hall_tier_02.png`
Files: `building_town_hall_tier_02_idle_01.png` … `building_town_hall_tier_02_idle_03.png`
Files: `building_town_hall_tier_03.png`
Files: `building_town_hall_tier_03_idle_01.png` … `building_town_hall_tier_03_idle_03.png`

Files: `building_treasury_idle_01.png` … `building_treasury_idle_03.png`
Files: `building_treasury_tier_02.png`
Files: `building_treasury_tier_02_idle_01.png` … `building_treasury_tier_02_idle_03.png`
Files: `building_treasury_tier_03.png`
Files: `building_treasury_tier_03_idle_01.png` … `building_treasury_tier_03_idle_03.png`

Files: `building_watchtower_idle_01.png` … `building_watchtower_idle_03.png`
Files: `building_watchtower_tier_02.png`
Files: `building_watchtower_tier_02_idle_01.png` … `building_watchtower_tier_02_idle_03.png`
Files: `building_watchtower_tier_03.png`
Files: `building_watchtower_tier_03_idle_01.png` … `building_watchtower_tier_03_idle_03.png`

Files: `building_woodcutter_idle_01.png` … `building_woodcutter_idle_03.png`
Files: `building_woodcutter_tier_02.png`
Files: `building_woodcutter_tier_02_idle_01.png` … `building_woodcutter_tier_02_idle_03.png`
Files: `building_woodcutter_tier_03.png`
Files: `building_woodcutter_tier_03_idle_01.png` … `building_woodcutter_tier_03_idle_03.png`

### 5.6 Beast — `res://art/beast/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `beast_profile.png` | 1024×1024 | T | `#2E3A33` |

### 5.6b Beast frames — `res://art/beast/`

Walk and idle cycles for the beast scope, layered **over** the procedural gait
rather than replacing it: the bob, step sink, settle and footfall impulses stay,
and the frames give the legs somewhere to be while all of that happens. Swapping
the procedural motion out for a spritesheet would trade a gait that responds to
speed, pauses and terrain for one that plays at a fixed rate.

Loading stops at the first gap, and an empty series falls back to the single
profile sprite in section 5.6 — so a partial set costs the animation, not the
screen.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `beast_walk_00.png` | 256×256 | T | `#4A5A4A` |
| `beast_walk_01.png` | 256×256 | T | `#4A5A4A` |
| `beast_walk_02.png` | 256×256 | T | `#4A5A4A` |
| `beast_walk_03.png` | 256×256 | T | `#4A5A4A` |
| `beast_walk_04.png` | 256×256 | T | `#4A5A4A` |
| `beast_walk_05.png` | 256×256 | T | `#4A5A4A` |
| `beast_walk_06.png` | 256×256 | T | `#4A5A4A` |
| `beast_walk_07.png` | 256×256 | T | `#4A5A4A` |
| `beast_walk_08.png` | 256×256 | T | `#4A5A4A` |
| `beast_idle_00.png` | 256×256 | T | `#4A5A4A` |
| `beast_idle_01.png` | 256×256 | T | `#4A5A4A` |
| `beast_idle_02.png` | 256×256 | T | `#4A5A4A` |
| `beast_idle_03.png` | 256×256 | T | `#4A5A4A` |
| `beast_idle_04.png` | 256×256 | T | `#4A5A4A` |
| `beast_idle_05.png` | 256×256 | T | `#4A5A4A` |
| `beast_idle_06.png` | 256×256 | T | `#4A5A4A` |

### 5.7 Terrain tiles — `res://art/terrain/`

Each region's floor is the plain-ground tile of its own road set, mirrored into
a seamless 64×64 tile by `tools/build_road_tiles.py`. Ground and road therefore
come from one generation, share a palette, and are drawn at the same pixel
density (`Balance.GROUND_UNITS_PER_TEXEL`).

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `terrain_jungle.png` | 512×512 | O | `#342F25` |
| `terrain_desert.png` | 512×512 | O | `#6B4F36` |
| `terrain_snow.png` | 512×512 | O | `#4D5B68` |
| `terrain_hollow_marches.png` | 512×512 | O | `#44503F` |
| `terrain_rustwood.png` | 512×512 | O | `#54301C` |
| `terrain_saltpan.png` | 512×512 | O | `#7E8A84` |
| `terrain_iron_steppe.png` | 512×512 | O | `#6E5C34` |
| `terrain_glass_fields.png` | 512×512 | O | `#486E94` |
| `terrain_ashen_reach.png` | 512×512 | O | `#3E3836` |
| `terrain_last_terrace.png` | 512×512 | O | `#606264` |

### 5.7b Foliage — `res://art/foliage/`

One painted plant per region, scattered among the procedural blades rather than
replacing them: the polygons are what make the ground look covered and cost
almost nothing, and the sprite is the plant the eye actually stops on. Tinted
toward the region's sampled ground palette so it sits in the same light.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `tree_jungle.png` | 96×128 | T | `#24401F` |
| `tree_desert.png` | 96×128 | T | `#8A7B4E` |
| `tree_snow.png` | 96×128 | T | `#5A6E78` |
| `tree_jungle_01.png` | 128×128 | T | `#24401F` |
| `tree_jungle_02.png` | 128×128 | T | `#24401F` |
| `tree_jungle_03.png` | 128×128 | T | `#24401F` |
| `tree_jungle_04.png` | 128×128 | T | `#24401F` |
| `tree_desert_01.png` | 128×128 | T | `#8A7B4E` |
| `tree_desert_02.png` | 128×128 | T | `#8A7B4E` |
| `tree_desert_03.png` | 128×128 | T | `#8A7B4E` |
| `tree_desert_04.png` | 128×128 | T | `#8A7B4E` |
| `tree_snow_01.png` | 128×128 | T | `#5A6E78` |
| `tree_snow_02.png` | 128×128 | T | `#5A6E78` |
| `tree_snow_03.png` | 128×128 | T | `#5A6E78` |
| `tree_snow_04.png` | 128×128 | T | `#5A6E78` |
| `butterfly_fly_01.png` | 32×32 | T | `#8155B8` |
| `butterfly_fly_02.png` | 32×32 | T | `#8155B8` |
| `butterfly_fly_03.png` | 32×32 | T | `#8155B8` |
| `butterfly_fly_04.png` | 32×32 | T | `#8155B8` |
| `butterfly_fly_05.png` | 32×32 | T | `#8155B8` |
| `butterfly_side_01.png` | 32×32 | T | `#8155B8` |
| `butterfly_side_02.png` | 32×32 | T | `#8155B8` |
| `butterfly_side_03.png` | 32×32 | T | `#8155B8` |
| `butterfly_side_04.png` | 32×32 | T | `#8155B8` |
| `butterfly_side_05.png` | 32×32 | T | `#8155B8` |
| `butterfly_side_06.png` | 32×32 | T | `#8155B8` |
| `butterfly_side_07.png` | 32×32 | T | `#8155B8` |
| `butterfly_side_08.png` | 32×32 | T | `#8155B8` |
| `butterfly_idle_01.png` | 32×32 | T | `#8155B8` |
| `plant_jungle.png` | 48×64 | T | `#2E4A33` |
| `plant_desert.png` | 48×64 | T | `#C0AC7E` |
| `plant_snow.png` | 48×64 | T | `#A8BCCC` |

### 5.7c Foliage kinds — `res://art/foliage/`

Extra painted kinds scattered alongside each region's own plant. Two families:
**regional** kinds carry the act's identity and are named per region
(`plant_<region>_<kind>.png`); **shared** kinds look the same everywhere — a rock
is a rock in a jungle or a snowfield — and are named once (`prop_<kind>.png`).

The region's own plant stays the common draw. These are punctuation: a field of
nothing but boulders is as monotonous as a field of nothing but reeds, and the
point is that a clump is occasionally *not* what you expected.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `plant_jungle_shrub.png` | 56×64 | T | `#2E3A33` |
| `plant_jungle_flower.png` | 32×40 | T | `#2E3A33` |
| `plant_jungle_fern.png` | 64×40 | T | `#2E3A33` |
| `plant_desert_shrub.png` | 56×64 | T | `#6E5B3C` |
| `plant_desert_flower.png` | 32×40 | T | `#6E5B3C` |
| `plant_jungle_tallgrass.png` | 40×64 | T | `#24401F` |
| `plant_desert_tallgrass.png` | 40×64 | T | `#8A7B4E` |
| `plant_snow_tallgrass.png` | 40×64 | T | `#7C8A96` |
| `plant_jungle_creeper.png` | 64×40 | T | `#24401F` |
| `plant_desert_creeper.png` | 64×40 | T | `#8A7B4E` |
| `plant_snow_creeper.png` | 64×40 | T | `#7C8A96` |
| `prop_cairn.png` | 40×56 | T | `#6E6A62` |
| `prop_signpost.png` | 40×64 | T | `#6B5344` |
| `prop_driftwood.png` | 72×40 | T | `#8A7B57` |
| `prop_burrow.png` | 48×40 | T | `#6B5344` |
| `plant_desert_fern.png` | 64×40 | T | `#6E5B3C` |
| `plant_snow_shrub.png` | 56×64 | T | `#7C8A96` |
| `plant_snow_flower.png` | 32×40 | T | `#7C8A96` |
| `plant_snow_fern.png` | 64×40 | T | `#7C8A96` |
| `plant_jungle_bush.png` | 64×56 | T | `#2E3A33` |
| `plant_jungle_blossom.png` | 32×40 | T | `#2E3A33` |
| `plant_desert_blossom.png` | 32×40 | T | `#6E5B3C` |
| `plant_snow_blossom.png` | 32×40 | T | `#7C8A96` |
| `prop_mushrooms.png` | 48×40 | T | `#6B5344` |
| `prop_bones.png` | 56×32 | T | `#B4AC97` |
| `prop_reeds.png` | 40×56 | T | `#6E7A4C` |
| `prop_wreckage.png` | 64×40 | T | `#8A8073` |
| `prop_wildflower_01.png` | 64×64 | T | `#596B3C` |
| `prop_wildflower_02.png` | 64×64 | T | `#596B3C` |
| `prop_wildflower_03.png` | 64×64 | T | `#596B3C` |
| `prop_wildflower_04.png` | 64×64 | T | `#596B3C` |
| `plant_desert_bush.png` | 64×56 | T | `#6E5B3C` |
| `plant_snow_bush.png` | 64×56 | T | `#7C8A96` |
| `prop_rock.png` | 48×40 | T | `#4A4A46` |
| `prop_boulder.png` | 64×56 | T | `#4A4A46` |
| `prop_log.png` | 72×40 | T | `#4A4A46` |
| `prop_stump.png` | 40×40 | T | `#4A4A46` |

#### Idle sequences

Painted plants carry the same `_idle_NN` convention as everything else: frame
zero is the ordinary sprite and continuations sit beside it, so a plant animates
by having files dropped in and stops animating by having them removed. Foliage
reads them through `GameData.load_idle_frames` and falls back to the shader sway
alone when a sequence is absent, which is a supported state rather than a gap.

**Every kind except the flowers has one, and that exception is a finding rather
than a shortfall.** All of them were generated and looked at on a contact sheet.
At 48×64 and above the generator moves what is already drawn — fronds ripple,
branches shift, snow settles, and the silhouette holds. At 32×40 it does not move
a flower, it *invents* one: the desert blossom sprouted cream-coloured growths
that are not part of the plant, and the desert flower grew extra petals and lost
them again. Those were discarded rather than shipped — twice, the second time
with the loop pinned. A flower's motion comes from the wind shader, which bends
what is drawn and cannot add to it, and the shader leans a flower harder than a
bush precisely because it is the flower's only motion.

Generated with the source pinned as **both** endpoints, exactly as the tower idle
frames are, and for the same reason: left open-ended the sequence drifts and the
loop snaps back — the snow fern's last frame sat four times further from the base
pose than one step of its own animation. Poses 01–03 ship; the terminal duplicate
is only the loop target.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `plant_jungle_fern_idle_01.png` | 64×40 | T | `#2E3A33` |
| `plant_jungle_fern_idle_02.png` | 64×40 | T | `#2E3A33` |
| `plant_jungle_fern_idle_03.png` | 64×40 | T | `#2E3A33` |
| `plant_snow_fern_idle_01.png` | 64×40 | T | `#7C8A96` |
| `plant_snow_fern_idle_02.png` | 64×40 | T | `#7C8A96` |
| `plant_snow_fern_idle_03.png` | 64×40 | T | `#7C8A96` |
| `plant_desert_fern_idle_01.png` | 64×40 | T | `#6E5B3C` |
| `plant_desert_fern_idle_02.png` | 64×40 | T | `#6E5B3C` |
| `plant_desert_fern_idle_03.png` | 64×40 | T | `#6E5B3C` |
| `plant_jungle_shrub_idle_01.png` | 56×64 | T | `#2E3A33` |
| `plant_jungle_shrub_idle_02.png` | 56×64 | T | `#2E3A33` |
| `plant_jungle_shrub_idle_03.png` | 56×64 | T | `#2E3A33` |
| `plant_jungle_bush_idle_01.png` | 64×56 | T | `#2E3A33` |
| `plant_jungle_bush_idle_02.png` | 64×56 | T | `#2E3A33` |
| `plant_jungle_bush_idle_03.png` | 64×56 | T | `#2E3A33` |
| `plant_jungle_idle_01.png` | 48×64 | T | `#2E3A33` |
| `plant_jungle_idle_02.png` | 48×64 | T | `#2E3A33` |
| `plant_jungle_idle_03.png` | 48×64 | T | `#2E3A33` |
| `plant_snow_shrub_idle_01.png` | 56×64 | T | `#7C8A96` |
| `plant_snow_shrub_idle_02.png` | 56×64 | T | `#7C8A96` |
| `plant_snow_shrub_idle_03.png` | 56×64 | T | `#7C8A96` |
| `plant_snow_bush_idle_01.png` | 64×56 | T | `#7C8A96` |
| `plant_snow_bush_idle_02.png` | 64×56 | T | `#7C8A96` |
| `plant_snow_bush_idle_03.png` | 64×56 | T | `#7C8A96` |
| `plant_snow_idle_01.png` | 48×64 | T | `#7C8A96` |
| `plant_snow_idle_02.png` | 48×64 | T | `#7C8A96` |
| `plant_snow_idle_03.png` | 48×64 | T | `#7C8A96` |
| `plant_desert_shrub_idle_01.png` | 56×64 | T | `#6E5B3C` |
| `plant_desert_shrub_idle_02.png` | 56×64 | T | `#6E5B3C` |
| `plant_desert_shrub_idle_03.png` | 56×64 | T | `#6E5B3C` |
| `plant_desert_bush_idle_01.png` | 64×56 | T | `#6E5B3C` |
| `plant_desert_bush_idle_02.png` | 64×56 | T | `#6E5B3C` |
| `plant_desert_bush_idle_03.png` | 64×56 | T | `#6E5B3C` |
| `plant_desert_idle_01.png` | 48×64 | T | `#6E5B3C` |
| `plant_desert_idle_02.png` | 48×64 | T | `#6E5B3C` |
| `plant_desert_idle_03.png` | 48×64 | T | `#6E5B3C` |

**Generated with the loop pinned to its own first frame.** Left open-ended, the
generator does not produce an idle at all — it produces *growth*: the first pass
turned the snow and desert blossoms into taller, differently-shaped plants by
frame four, which is a new plant rather than a breathing one. Passing the source
sprite as the last frame as well forces the cycle to return to where it started.
Anything added here should be checked on a contact sheet against its own base
before it ships, for exactly that reason.

**The second pass, 2026-09-01.** Owner direction: "not all foliage has idle
animations + wind shader combo active but should unless they're a static foliage
asset like a rock or something that does not get animated. Flowers should be
animated both ways, same for trees but each asset's wind shader should be tuned
for what it is."

Everything that should move now does, and the wind materials are split per kind
and per region so a snow conifer, a jungle broadleaf and a bed of reeds no longer
lean by the same angle (`Balance.FOLIAGE_KIND_SWAY`, `Balance.FOLIAGE_TREE_SWAY`).

Deliberately still: `prop_rock`, `prop_boulder`, `prop_log`, `prop_stump`,
`prop_bones` and `prop_wreckage`. A rock that breathes is a bug.

**One flower was rejected again, and the reason is the one written above.** At
32×40 the generator invents rather than moves: the desert flower grew a second
bloom beside the first, twice - once on the ordinary prompt and once with the
bloom count and silhouette named explicitly in it. Both attempts were looked at
on a contact sheet and discarded. It keeps the wind shader as its only motion,
which is what every flower had before this pass.

The snow flower failed the same way on the first attempt - its rounded head
flattened into a fan and back - and passed on the second, once the prompt said
the bloom must not open, split or flatten. The jungle flower passed immediately;
the difference is that it is three blooms on three stems, so leaning them is a
motion the generator can find without inventing geometry.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `plant_jungle_flower_idle_01.png` | 32×40 | T | `#2E3A33` |
| `plant_jungle_flower_idle_02.png` | 32×40 | T | `#2E3A33` |
| `plant_jungle_flower_idle_03.png` | 32×40 | T | `#2E3A33` |
| `plant_desert_flower_idle_01.png` | 32×40 | T | `#6E5B3C` |
| `plant_jungle_tallgrass_idle_01.png` | 40×64 | T | `#24401F` |
| `plant_jungle_tallgrass_idle_02.png` | 40×64 | T | `#24401F` |
| `plant_jungle_tallgrass_idle_03.png` | 40×64 | T | `#24401F` |
| `plant_desert_tallgrass_idle_01.png` | 40×64 | T | `#8A7B4E` |
| `plant_desert_tallgrass_idle_02.png` | 40×64 | T | `#8A7B4E` |
| `plant_desert_tallgrass_idle_03.png` | 40×64 | T | `#8A7B4E` |
| `plant_snow_tallgrass_idle_01.png` | 40×64 | T | `#7C8A96` |
| `plant_snow_tallgrass_idle_02.png` | 40×64 | T | `#7C8A96` |
| `plant_snow_tallgrass_idle_03.png` | 40×64 | T | `#7C8A96` |
| `plant_jungle_creeper_idle_01.png` | 64×40 | T | `#24401F` |
| `plant_jungle_creeper_idle_02.png` | 64×40 | T | `#24401F` |
| `plant_jungle_creeper_idle_03.png` | 64×40 | T | `#24401F` |
| `plant_desert_creeper_idle_01.png` | 64×40 | T | `#8A7B4E` |
| `plant_desert_creeper_idle_02.png` | 64×40 | T | `#8A7B4E` |
| `plant_desert_creeper_idle_03.png` | 64×40 | T | `#8A7B4E` |
| `plant_snow_creeper_idle_01.png` | 64×40 | T | `#7C8A96` |
| `plant_snow_creeper_idle_02.png` | 64×40 | T | `#7C8A96` |
| `plant_snow_creeper_idle_03.png` | 64×40 | T | `#7C8A96` |
| `plant_desert_flower_idle_02.png` | 32×40 | T | `#6E5B3C` |
| `plant_desert_flower_idle_03.png` | 32×40 | T | `#6E5B3C` |
| `plant_snow_flower_idle_01.png` | 32×40 | T | `#7C8A96` |
| `plant_snow_flower_idle_02.png` | 32×40 | T | `#7C8A96` |
| `plant_snow_flower_idle_03.png` | 32×40 | T | `#7C8A96` |
| `plant_jungle_blossom_idle_01.png` | 32×40 | T | `#2E3A33` |
| `plant_jungle_blossom_idle_02.png` | 32×40 | T | `#2E3A33` |
| `plant_jungle_blossom_idle_03.png` | 32×40 | T | `#2E3A33` |
| `plant_desert_blossom_idle_01.png` | 32×40 | T | `#6E5B3C` |
| `plant_desert_blossom_idle_02.png` | 32×40 | T | `#6E5B3C` |
| `plant_desert_blossom_idle_03.png` | 32×40 | T | `#6E5B3C` |
| `plant_snow_blossom_idle_01.png` | 32×40 | T | `#7C8A96` |
| `plant_snow_blossom_idle_02.png` | 32×40 | T | `#7C8A96` |
| `plant_snow_blossom_idle_03.png` | 32×40 | T | `#7C8A96` |
| `prop_wildflower_01_idle_01.png` | 64×64 | T | `#596B3C` |
| `prop_wildflower_01_idle_02.png` | 64×64 | T | `#596B3C` |
| `prop_wildflower_01_idle_03.png` | 64×64 | T | `#596B3C` |
| `prop_wildflower_02_idle_01.png` | 64×64 | T | `#596B3C` |
| `prop_wildflower_02_idle_02.png` | 64×64 | T | `#596B3C` |
| `prop_wildflower_02_idle_03.png` | 64×64 | T | `#596B3C` |
| `prop_wildflower_03_idle_01.png` | 64×64 | T | `#596B3C` |
| `prop_wildflower_03_idle_02.png` | 64×64 | T | `#596B3C` |
| `prop_wildflower_03_idle_03.png` | 64×64 | T | `#596B3C` |
| `prop_wildflower_04_idle_01.png` | 64×64 | T | `#596B3C` |
| `prop_wildflower_04_idle_02.png` | 64×64 | T | `#596B3C` |
| `prop_wildflower_04_idle_03.png` | 64×64 | T | `#596B3C` |
| `prop_reeds_idle_01.png` | 40×56 | T | `#6E7A4C` |
| `prop_reeds_idle_02.png` | 40×56 | T | `#6E7A4C` |
| `prop_reeds_idle_03.png` | 40×56 | T | `#6E7A4C` |
| `prop_mushrooms_idle_01.png` | 48×40 | T | `#6B5344` |
| `prop_mushrooms_idle_02.png` | 48×40 | T | `#6B5344` |
| `prop_mushrooms_idle_03.png` | 48×40 | T | `#6B5344` |
| `tree_jungle_idle_01.png` | 96×128 | T | `#24401F` |
| `tree_jungle_idle_02.png` | 96×128 | T | `#24401F` |
| `tree_jungle_idle_03.png` | 96×128 | T | `#24401F` |
| `tree_desert_idle_01.png` | 96×128 | T | `#8A7B4E` |
| `tree_desert_idle_02.png` | 96×128 | T | `#8A7B4E` |
| `tree_desert_idle_03.png` | 96×128 | T | `#8A7B4E` |
| `tree_snow_idle_01.png` | 96×128 | T | `#5A6E78` |
| `tree_snow_idle_02.png` | 96×128 | T | `#5A6E78` |
| `tree_snow_idle_03.png` | 96×128 | T | `#5A6E78` |
| `tree_jungle_01_idle_01.png` | 128×128 | T | `#24401F` |
| `tree_jungle_01_idle_02.png` | 128×128 | T | `#24401F` |
| `tree_jungle_01_idle_03.png` | 128×128 | T | `#24401F` |
| `tree_jungle_02_idle_01.png` | 128×128 | T | `#24401F` |
| `tree_jungle_02_idle_02.png` | 128×128 | T | `#24401F` |
| `tree_jungle_02_idle_03.png` | 128×128 | T | `#24401F` |
| `tree_jungle_03_idle_01.png` | 128×128 | T | `#24401F` |
| `tree_jungle_03_idle_02.png` | 128×128 | T | `#24401F` |
| `tree_jungle_03_idle_03.png` | 128×128 | T | `#24401F` |
| `tree_jungle_04_idle_01.png` | 128×128 | T | `#24401F` |
| `tree_jungle_04_idle_02.png` | 128×128 | T | `#24401F` |
| `tree_jungle_04_idle_03.png` | 128×128 | T | `#24401F` |
| `tree_desert_01_idle_01.png` | 128×128 | T | `#8A7B4E` |
| `tree_desert_01_idle_02.png` | 128×128 | T | `#8A7B4E` |
| `tree_desert_01_idle_03.png` | 128×128 | T | `#8A7B4E` |
| `tree_desert_02_idle_01.png` | 128×128 | T | `#8A7B4E` |
| `tree_desert_02_idle_02.png` | 128×128 | T | `#8A7B4E` |
| `tree_desert_02_idle_03.png` | 128×128 | T | `#8A7B4E` |
| `tree_desert_03_idle_01.png` | 128×128 | T | `#8A7B4E` |
| `tree_desert_03_idle_02.png` | 128×128 | T | `#8A7B4E` |
| `tree_desert_03_idle_03.png` | 128×128 | T | `#8A7B4E` |
| `tree_desert_04_idle_01.png` | 128×128 | T | `#8A7B4E` |
| `tree_desert_04_idle_02.png` | 128×128 | T | `#8A7B4E` |
| `tree_desert_04_idle_03.png` | 128×128 | T | `#8A7B4E` |
| `tree_snow_01_idle_01.png` | 128×128 | T | `#5A6E78` |
| `tree_snow_01_idle_02.png` | 128×128 | T | `#5A6E78` |
| `tree_snow_01_idle_03.png` | 128×128 | T | `#5A6E78` |
| `tree_snow_02_idle_01.png` | 128×128 | T | `#5A6E78` |
| `tree_snow_02_idle_02.png` | 128×128 | T | `#5A6E78` |
| `tree_snow_02_idle_03.png` | 128×128 | T | `#5A6E78` |
| `tree_snow_03_idle_01.png` | 128×128 | T | `#5A6E78` |
| `tree_snow_03_idle_02.png` | 128×128 | T | `#5A6E78` |
| `tree_snow_03_idle_03.png` | 128×128 | T | `#5A6E78` |
| `tree_snow_04_idle_01.png` | 128×128 | T | `#5A6E78` |
| `tree_snow_04_idle_02.png` | 128×128 | T | `#5A6E78` |
| `tree_snow_04_idle_03.png` | 128×128 | T | `#5A6E78` |

### 5.8 Backdrops — `res://art/bg/`

> The three `macro_act*` backdrops are **688×384 pixel art**, scaled to fill the
> view height at draw time. They were 1920×1080 paintings, which read as a
> different game once the beast standing in front of them became pixel art — the
> rest of the project is pixel art and the backdrops were the outlier. The
> remaining 1920×1080 entries here are UI key art, which is never seen beside a
> sprite.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `macro_act1.png` | 688×384 | O | `#1E2E33` |
| `macro_act2.png` | 688×384 | O | `#2E3A42` |
| `macro_act3.png` | 688×384 | O | `#3A2E2E` |
| `macro_act4.png` | 688×384 | O | `#2B3430` |
| `macro_act5.png` | 688×384 | O | `#33201A` |
| `macro_act6.png` | 688×384 | O | `#3C4744` |
| `macro_act7.png` | 688×384 | O | `#3E3524` |
| `macro_act8.png` | 688×384 | O | `#26384A` |
| `macro_act9.png` | 688×384 | O | `#241F1E` |
| `macro_act10.png` | 688×384 | O | `#32353A` |
| `crossroad_bg.png` | 1920×1080 | O | `#1E2E33` |
| `raid_arena_bg.png` | 1920×1080 | O | `#160E12` |
| `menu_key_art.png` | 688×384 | O | `#0B1416` |
| `summit.png` | 1920×1080 | O | `#1B2436` |

### 5.8b Story panels — `res://art/story/`

Four 16:9 panels for the opening cinematic (GDD §6). Native 688×384, drawn
nearest-neighbour and letterboxed rather than stretched: pixel art scaled to an
arbitrary window is the fastest way to make careful art look cheap.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `story_worldstrider.png` | 688×384 | O | `#2E3A42` |
| `story_host.png` | 688×384 | O | `#16223A` |
| `story_warden.png` | 688×384 | O | `#1E2E33` |
| `story_summit.png` | 688×384 | O | `#101A2E` |

### 5.8c Loot drops — `res://art/loot/`

World art for dropped rewards, named `loot_<reward>.png` by convention. Every
run currency has a dedicated road-scale silhouette. The supplies silhouette is
the ordinary raid provision cache; the relic silhouette is reserved for the
locked premium cache, so the detour's value reads before the player reaches it.

The healing orb is crimson against the Mender's Spark's green, because two
recoveries that glowed alike would teach the player that one of them is the
other, and they are deliberately opposite halves of one idea. Both of those
generations arrived with the artefact reported from play: the orb standing on a
cast shadow and the crate on a patch of grass. The shadow was a *detached* blob
and came off by connected component; the grass was attached and came off by
colour, which was only safe because the crate had first been shown to contain no
green at all.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `loot_wood.png` | 48×48 | T | `#8D5A32` |
| `loot_food.png` | 48×48 | T | `#D8A33A` |
| `loot_gold.png` | 48×48 | T | `#C8A44A` |
| `loot_stone.png` | 48×48 | T | `#697386` |
| `loot_supplies.png` | 48×48 | T | `#8B7250` |
| `loot_relic.png` | 48×48 | T | `#7A5BA8` |
| `loot_mender_spark.png` | 48×48 | T | `#79D9A0` |
| `loot_healing_orb.png` | 48×48 | T | `#E64857` |
| `loot_supply_crate.png` | 48×48 | T | `#7A5B3C` |

### 5.8d Sidescroller ground — `res://art/bg/`

A sixteen-tile side-view platform set for the beast scope: the ground Yuri walks
over, baked into one wide strip and scrolled as a leapfrogging pair.

**It is a corner-mask set, not sixteen interchangeable slabs.** Exactly one tile
is solid, one is empty, and the other fourteen are the transitions between. The
numbering carries no meaning — the bake *measures* each tile's four corners from
its own alpha and files it under the mask it answers to, so a regenerated set
cannot silently invert the convention and put sky underground.

Named `side_<region>_NN.png`, one set per act region. A region without a set
falls back to `jungle` rather than to a placeholder: a missing set should cost
an act its own material, not its ground, and a magenta strip across the bottom
of the screen would be a downgrade on both.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `side_jungle_00.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_01.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_02.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_03.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_04.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_05.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_06.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_07.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_08.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_09.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_10.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_11.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_12.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_13.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_14.png` | 32×32 | T | `#2E3A33` |
| `side_jungle_15.png` | 32×32 | T | `#2E3A33` |
| `side_desert_00.png` | 32×32 | T | `#B08A52` |
| `side_desert_01.png` | 32×32 | T | `#B08A52` |
| `side_desert_02.png` | 32×32 | T | `#B08A52` |
| `side_desert_03.png` | 32×32 | T | `#B08A52` |
| `side_desert_04.png` | 32×32 | T | `#B08A52` |
| `side_desert_05.png` | 32×32 | T | `#B08A52` |
| `side_desert_06.png` | 32×32 | T | `#B08A52` |
| `side_desert_07.png` | 32×32 | T | `#B08A52` |
| `side_desert_08.png` | 32×32 | T | `#B08A52` |
| `side_desert_09.png` | 32×32 | T | `#B08A52` |
| `side_desert_10.png` | 32×32 | T | `#B08A52` |
| `side_desert_11.png` | 32×32 | T | `#B08A52` |
| `side_desert_12.png` | 32×32 | T | `#B08A52` |
| `side_desert_13.png` | 32×32 | T | `#B08A52` |
| `side_desert_14.png` | 32×32 | T | `#B08A52` |
| `side_desert_15.png` | 32×32 | T | `#B08A52` |
| `side_snow_00.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_01.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_02.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_03.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_04.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_05.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_06.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_07.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_08.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_09.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_10.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_11.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_12.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_13.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_14.png` | 32×32 | T | `#8FA4B8` |
| `side_snow_15.png` | 32×32 | T | `#8FA4B8` |

### 5.9 Relic icons — `res://art/icons/relics/`

All 128×128, type T, placeholder colour `#E8A33D`.

Files: `relic_01.png` … `relic_80.png`, plus `relic_core_drowned_choir.png`,
`relic_core_mirrorfang.png`, `relic_core_rust_crown.png`.

> Rename these to match final relic `id`s once relics are designed in Stage 5.
> Until then the numbered placeholders are correct.

> Eight per region, and there are ten regions since 2026-09-11. The count is not
> decorative: `balance_test` requires every region to ship exactly eight, so that
> no act's relic pool is poorer than another's, and adding an act means adding
> eight relics with it.

### 5.10 Spell icons — `res://art/icons/spells/`

All 96×96, type T, placeholder colour `#9B8FC4`.

`spell_rift_step.png` · `spell_cinder_nova.png` · `spell_bulwark_ward.png` ·
`spell_marrow_drain.png` · `spell_chain_hook.png` · `spell_ash_veil.png` ·
`spell_tremor.png` · `spell_beasts_breath.png`

Five more since 2026-09-11, the first spells that strike a place the hero only
pointed at rather than the ground they are standing on:

`spell_ember_fall.png` · `spell_stonefall.png` · `spell_thorn_volley.png` ·
`spell_frost_lance.png` · `spell_sky_lance.png`

The six summoning calls. **These were missing entirely** — the spells shipped, the
sockets showed them, and each drew nothing because the icon its id derives to did
not exist. Found by walking every content resource's derived path against the
disk rather than by looking at the manifest, which only ever knows about assets
somebody remembered to declare.

Drawn as spirit heads rather than as animals: they are a *call*, not a creature,
and the companion sprites already carry the animal itself.

`spell_call_wolf.png` · `spell_call_bear.png` · `spell_call_crow.png` ·
`spell_call_hart.png` · `spell_call_ram.png` · `spell_call_serpent.png`

### 5.9d Barricades — `res://art/barricades/`

All 96×96, type T, placeholder colour `#B89A70`.

Larger than the traps because they stand up rather than lie flat, and are looked
at from the side like every other structure. Sized to read as a thing an enemy
has to break rather than a thing it steps over — which is the whole mechanic.

`barricade_stake_line.png` · `barricade_iron_hoarding.png`

### 5.9e Barricade orientations — `res://art/barricades/`

All 96×96, type T, placeholder colour `#B89A70`.

A wall drawn lying *along* a road is a fence, not a barricade — the image has to
cross the lane. So the piece is chosen from the road under it, and the road is
what the grid knows: a straight north-south run takes the main sprite, an
east-west run takes `_along`, and a corner takes `_diagonal`, mirrored to follow
which way the bend turns.

Three pieces rather than four, because the fourth is the third flipped. A
barricade that ships only its main sprite still stands everywhere — turned the
wrong way rather than invisible.

Files: `barricade_stake_line_along.png` · `barricade_stake_line_diagonal.png`
Files: `barricade_iron_hoarding_along.png` · `barricade_iron_hoarding_diagonal.png`

### 5.10 Traps — `res://art/traps/`

All 64×64, type T, placeholder colour `#DBB96B`.

Drawn top-down rather than in profile, unlike everything else this size: a trap
lies flat on the road and is looked at from above, where a wolf or a deer stands
on it and is looked at from the side.

`trap_spike_pit.png` · `trap_tar_snare.png` · `trap_firebloom.png`

### 5.10a Companions — `res://art/companions/`

All 64×64, type T, placeholder colour `#9EC8FF`.

The three summonable spirits. Sized and lit to match the wildlife rather than the
enemies, because they read at the same distance and against the same ground — and
tinted toward the summon's pale blue so a Spirit Wolf is not mistaken for
something that turned up on its own.

`companion_wolf.png` · `companion_crow.png` · `companion_bear.png` ·
`companion_serpent.png` · `companion_hart.png` · `companion_ram.png`

No attack pose. One authored strike frame per companion is three more sprites for
something on screen ten seconds at a time; the lunge toward the target is a
transform and reads at any zoom.

### 5.10b Wildlife — `res://art/wildlife/`

All 64×64, type T, placeholder colour `#7A8B6E`.

Seven more since 2026-09-11, one for each region the road gained, each carrying
the same package the others do - a base pose, three idle poses, a seven-frame
forward cycle, and four attack poses for the three that will start a fight. The
moth's forward cycle is `_fly_` rather than `_move_`, because a flier has no
walk and the gate asks for the one it has.

`wildlife_bog_crane.png` · `wildlife_iron_beetle.png` ·
`wildlife_salt_crab.png` · `wildlife_steppe_horse.png` ·
`wildlife_glass_moth.png` · `wildlife_ash_hound.png` ·
`wildlife_cliff_goat.png`

**Two of the seven face right and five face left**, and that was decided by
looking at them rather than by what the prompt asked for - `art_faces_right` is
set per species, and this project has already shipped a manifest that had four
of six backwards.

Files: `wildlife_bog_crane_idle_01.png` · `wildlife_bog_crane_idle_02.png` · `wildlife_bog_crane_idle_03.png`
Files: `wildlife_bog_crane_move_01.png` · `wildlife_bog_crane_move_02.png` · `wildlife_bog_crane_move_03.png` · `wildlife_bog_crane_move_04.png` · `wildlife_bog_crane_move_05.png` · `wildlife_bog_crane_move_06.png` · `wildlife_bog_crane_move_07.png`
Files: `wildlife_iron_beetle_idle_01.png` · `wildlife_iron_beetle_idle_02.png` · `wildlife_iron_beetle_idle_03.png`
Files: `wildlife_iron_beetle_move_01.png` · `wildlife_iron_beetle_move_02.png` · `wildlife_iron_beetle_move_03.png` · `wildlife_iron_beetle_move_04.png` · `wildlife_iron_beetle_move_05.png` · `wildlife_iron_beetle_move_06.png` · `wildlife_iron_beetle_move_07.png`
Files: `wildlife_salt_crab_idle_01.png` · `wildlife_salt_crab_idle_02.png` · `wildlife_salt_crab_idle_03.png`
Files: `wildlife_salt_crab_move_01.png` · `wildlife_salt_crab_move_02.png` · `wildlife_salt_crab_move_03.png` · `wildlife_salt_crab_move_04.png` · `wildlife_salt_crab_move_05.png` · `wildlife_salt_crab_move_06.png` · `wildlife_salt_crab_move_07.png`
Files: `wildlife_salt_crab_attack_01.png` · `wildlife_salt_crab_attack_02.png` · `wildlife_salt_crab_attack_03.png` · `wildlife_salt_crab_attack_04.png` · `wildlife_salt_crab_attack_05.png`
Files: `wildlife_steppe_horse_idle_01.png` · `wildlife_steppe_horse_idle_02.png` · `wildlife_steppe_horse_idle_03.png`
Files: `wildlife_steppe_horse_move_01.png` · `wildlife_steppe_horse_move_02.png` · `wildlife_steppe_horse_move_03.png` · `wildlife_steppe_horse_move_04.png` · `wildlife_steppe_horse_move_05.png` · `wildlife_steppe_horse_move_06.png` · `wildlife_steppe_horse_move_07.png`
Files: `wildlife_glass_moth_idle_01.png` · `wildlife_glass_moth_idle_02.png` · `wildlife_glass_moth_idle_03.png` · `wildlife_glass_moth_idle_04.png`
Files: `wildlife_glass_moth_fly_01.png` · `wildlife_glass_moth_fly_02.png` · `wildlife_glass_moth_fly_03.png` · `wildlife_glass_moth_fly_04.png` · `wildlife_glass_moth_fly_05.png` · `wildlife_glass_moth_fly_06.png` · `wildlife_glass_moth_fly_07.png`
Files: `wildlife_ash_hound_idle_01.png` · `wildlife_ash_hound_idle_02.png` · `wildlife_ash_hound_idle_03.png`
Files: `wildlife_ash_hound_move_01.png` · `wildlife_ash_hound_move_02.png` · `wildlife_ash_hound_move_03.png` · `wildlife_ash_hound_move_04.png` · `wildlife_ash_hound_move_05.png` · `wildlife_ash_hound_move_06.png` · `wildlife_ash_hound_move_07.png`
Files: `wildlife_ash_hound_attack_01.png` · `wildlife_ash_hound_attack_02.png` · `wildlife_ash_hound_attack_03.png` · `wildlife_ash_hound_attack_04.png` · `wildlife_ash_hound_attack_05.png`
Files: `wildlife_cliff_goat_idle_01.png` · `wildlife_cliff_goat_idle_02.png` · `wildlife_cliff_goat_idle_03.png`
Files: `wildlife_cliff_goat_move_01.png` · `wildlife_cliff_goat_move_02.png` · `wildlife_cliff_goat_move_03.png` · `wildlife_cliff_goat_move_04.png` · `wildlife_cliff_goat_move_05.png` · `wildlife_cliff_goat_move_06.png` · `wildlife_cliff_goat_move_07.png`
Files: `wildlife_cliff_goat_attack_01.png` · `wildlife_cliff_goat_attack_02.png` · `wildlife_cliff_goat_attack_03.png` · `wildlife_cliff_goat_attack_04.png` · `wildlife_cliff_goat_attack_05.png`


Deliberately small and few. These are ambient animals seen at combat zoom across
a field: what has to survive is the silhouette and the colour, and detail spent
past that is detail nobody will ever be close enough to see. Adding a creature is
a `.tres` in `data/wildlife/` and a sprite named for its id — no code.

`wildlife_raven.png` · `wildlife_fox.png` · `wildlife_rabbit.png` ·
`wildlife_deer.png` · `wildlife_squirrel.png` · `wildlife_raccoon.png` ·
`wildlife_wolf.png` · `wildlife_boar.png` · `wildlife_bear.png` ·
`wildlife_viper.png` · `wildlife_badger.png` · `wildlife_hawk.png` ·
`wildlife_stag.png` ·
`wildlife_heron.png` · `wildlife_hedgehog.png` · `wildlife_lynx.png` ·
`wildlife_tortoise.png` · `wildlife_jackal.png` · `wildlife_scorpion.png` ·
`wildlife_snow_hare.png` · `wildlife_ptarmigan.png` ·
`wildlife_snow_lynx.png` · `wildlife_frost_elk.png`

The ten added on 2026-09-01 answer "more wildlife variety for all rarities of
both harmless and predators for all regions". The gap was not rarity — that
was already even — it was **Act III**, which had five species against nine and
ten in the other two, so a snowfield read as emptier than a jungle for reasons
nobody chose. Four of the ten are Act III alone.

**Eight of the ten face right; the hedgehog and the snow lynx face left.**
`art_faces_right` is per-sprite for exactly this reason, and getting it wrong
makes a creature moonwalk.

Read off individual sprites at full size, not off a contact sheet. The first
pass used a 3x sheet, called the snow lynx right-facing, and shipped it
backwards - the owner spotted it. A pixel-mass heuristic was then tried as a
cross-check and was worse: it scored that sprite 389 against 397, a coin toss on
an animal whose face is plainly on the left. **There is no substitute for
looking at each one**, and no gate can do it.

Six of these are the **hostile** roster — wolf, boar, bear, viper, badger, hawk —
and they read as such: heavier silhouettes, teeth and tusks where the ambient
seven have ears and tails. That contrast is doing real work — a player has to be
able to tell at a glance whether the thing beside the road is a question or an
answer.

Each species also carries a **rarity** in its `.tres`, and the rarity is the
thing the eye should be able to check. The Pale Stag is the harmless Legendary
and the bear the hostile one, so both are drawn larger and stranger than their
tier-mates: a player who sees one should know before being told that this is not
a rabbit. Name them in prose rather than by filename here — the report parser
reads every backticked path in this document as a listing, and a file mentioned
twice fails the production-art gate.

Facing here: the wolf, viper and hawk face left; the boar, bear and badger face
right. Read off a 5x sheet *before* any dependent frame was generated, which is
the order that stops a whole set having to be redone.

**Facing is declared per creature (`art_faces_right`) and must be verified per
*frame*.** Five face right; the deer and the raccoon face left.

This has been got wrong three times, each time by reading the art too small or
not at all, so the rule is now explicit: **the generator assigns facing at
random, per frame, regardless of the prompt.** Frames within one creature's own
set routinely disagree with each other — the squirrel's base and walk frames
faced opposite ways, and so did the raven's base and flight frames. Any new frame
must be composited into a contact sheet at 6× and looked at before it is
declared. A 3× sheet was read wrong; 6× was not.

### 5.10c Wildlife idle frames — `res://art/wildlife/`

All 64×64, type T, placeholder colour `#7A8B6E`.

One continuation pose each, following the same `_idle_01` convention the
structures use — so the animator is the same code, and a creature shipped with
no continuation frame is a supported state rather than a broken one. Generated
img2img from the base pose so the palette cannot drift between frames.

Files: `wildlife_raven_idle_01.png` … `wildlife_raven_idle_05.png`
Files: `wildlife_fox_idle_01.png` · `wildlife_fox_idle_02.png` · `wildlife_fox_idle_03.png`
Files: `wildlife_rabbit_idle_01.png` · `wildlife_rabbit_idle_02.png` · `wildlife_rabbit_idle_03.png`
Files: `wildlife_deer_idle_01.png` · `wildlife_deer_idle_02.png` · `wildlife_deer_idle_03.png`
Files: `wildlife_stag_idle_01.png` · `wildlife_stag_idle_02.png` · `wildlife_stag_idle_03.png`
Files: `wildlife_heron_idle_01.png` · `wildlife_heron_idle_02.png` · `wildlife_heron_idle_03.png` · `wildlife_heron_idle_04.png`
Files: `wildlife_hedgehog_idle_01.png` · `wildlife_hedgehog_idle_02.png` · `wildlife_hedgehog_idle_03.png` · `wildlife_hedgehog_idle_04.png`
Files: `wildlife_lynx_idle_01.png` · `wildlife_lynx_idle_02.png` · `wildlife_lynx_idle_03.png` · `wildlife_lynx_idle_04.png`
Files: `wildlife_tortoise_idle_01.png` · `wildlife_tortoise_idle_02.png` · `wildlife_tortoise_idle_03.png` · `wildlife_tortoise_idle_04.png`
Files: `wildlife_jackal_idle_01.png` · `wildlife_jackal_idle_02.png` · `wildlife_jackal_idle_03.png` · `wildlife_jackal_idle_04.png`
Files: `wildlife_scorpion_idle_01.png` · `wildlife_scorpion_idle_02.png` · `wildlife_scorpion_idle_03.png` · `wildlife_scorpion_idle_04.png`
Files: `wildlife_snow_hare_idle_01.png` · `wildlife_snow_hare_idle_02.png` · `wildlife_snow_hare_idle_03.png` · `wildlife_snow_hare_idle_04.png`
Files: `wildlife_ptarmigan_idle_01.png` · `wildlife_ptarmigan_idle_02.png` · `wildlife_ptarmigan_idle_03.png` · `wildlife_ptarmigan_idle_04.png`
Files: `wildlife_snow_lynx_idle_01.png` · `wildlife_snow_lynx_idle_02.png` · `wildlife_snow_lynx_idle_03.png` · `wildlife_snow_lynx_idle_04.png`
Files: `wildlife_frost_elk_idle_01.png` · `wildlife_frost_elk_idle_02.png` · `wildlife_frost_elk_idle_03.png` · `wildlife_frost_elk_idle_04.png`
Files: `wildlife_badger_idle_01.png` … `wildlife_badger_idle_04.png`
Files: `wildlife_bear_idle_01.png` … `wildlife_bear_idle_04.png`
Files: `wildlife_boar_idle_01.png` … `wildlife_boar_idle_04.png`
Files: `wildlife_viper_idle_01.png` … `wildlife_viper_idle_04.png`
Files: `wildlife_wolf_idle_01.png` … `wildlife_wolf_idle_04.png`

The five predators had **no** idle sequence until 2026-08-31, so a wolf waiting
by the road stood as a single frozen frame while every harmless animal breathed —
which read as the predators being decoration rather than the thing you have to
watch. `animate_image` produced all five from their own base sprites, so palette
and facing carry rather than being described. `wildlife_spawn_check` now asserts
the whole matrix, because this gap was invisible: a missing sequence is a
supported state that falls back to the static pose without a warning.
Files: `wildlife_squirrel_idle_01.png` · `wildlife_squirrel_idle_02.png` · `wildlife_squirrel_idle_03.png`
Files: `wildlife_raccoon_idle_01.png` · `wildlife_raccoon_idle_02.png` · `wildlife_raccoon_idle_03.png`

### 5.10d Wildlife move frames — `res://art/wildlife/`

All 64×64, type T, placeholder colour `#7A8B6E`.

The walking half of each pair, on the `_move_01` convention that mirrors the idle
one. Standing still and walking are two sequences over one source sprite, so a
creature can ship with either, both or neither — the animator falls back to a
transform where a sequence is missing.

**Twenty-one now carry a full seven-frame gait**, upgraded 2026-09-08 from the
two-frame pairs below. Two frames is a shuffle: it alternates between two leg
positions and reads as a sprite being swapped. Seven is a stride. The raven is
the exception and stays on two, because it flies and its flight cycle is the
sequence that matters. Provenance in `WILDLIFE_MOVE_BATCH_2026-09-07.json`.

Ground anchor was measured across all 147 frames rather than assumed: drift is
0-3px against each base, and the largest is the rabbit, which hops. Move frames
are deliberately *not* passed through `lock_animation_region.py` the way idle
frames are — vertical travel is the gait, and flattening it would remove the
thing being animated.

The way to get a frame was neither hand-editing nor the character rig.
Text-to-image genuinely will not produce "the same animal, a different pose, the
*same size and shade*" — three attempts came back darker, lighter or larger every
time, which is why seven of these shipped with one frame and a procedural hop.

`animate_image` does. It takes the existing frame as its *first* frame and asks
only for the motion, so palette, scale and facing come from the sprite rather
than from a description of it — and facing in particular has been wrong here
three separate times when it was described rather than carried.

Every pair was checked side by side on a contact sheet before it shipped, which
is the only way this has ever been established. See
`build-a-contact-sheet-before-claiming-art-facts`.

The procedural hop stays for anything that ships with one frame: a creature can
still have either, both or neither.

Files: `wildlife_raven_move_01.png` · `wildlife_raven_move_02.png`
Files: `wildlife_fox_move_01.png` · `wildlife_fox_move_02.png` · `wildlife_fox_move_03.png` · `wildlife_fox_move_04.png` · `wildlife_fox_move_05.png` · `wildlife_fox_move_06.png` · `wildlife_fox_move_07.png`
Files: `wildlife_raccoon_move_01.png` · `wildlife_raccoon_move_02.png` · `wildlife_raccoon_move_03.png` · `wildlife_raccoon_move_04.png` · `wildlife_raccoon_move_05.png` · `wildlife_raccoon_move_06.png` · `wildlife_raccoon_move_07.png`
Files: `wildlife_deer_move_01.png` · `wildlife_deer_move_02.png` · `wildlife_deer_move_03.png` · `wildlife_deer_move_04.png` · `wildlife_deer_move_05.png` · `wildlife_deer_move_06.png` · `wildlife_deer_move_07.png`
Files: `wildlife_wolf_move_01.png` · `wildlife_wolf_move_02.png` · `wildlife_wolf_move_03.png` · `wildlife_wolf_move_04.png` · `wildlife_wolf_move_05.png` · `wildlife_wolf_move_06.png` · `wildlife_wolf_move_07.png`
Files: `wildlife_boar_move_01.png` · `wildlife_boar_move_02.png` · `wildlife_boar_move_03.png` · `wildlife_boar_move_04.png` · `wildlife_boar_move_05.png` · `wildlife_boar_move_06.png` · `wildlife_boar_move_07.png`
Files: `wildlife_bear_move_01.png` · `wildlife_bear_move_02.png` · `wildlife_bear_move_03.png` · `wildlife_bear_move_04.png` · `wildlife_bear_move_05.png` · `wildlife_bear_move_06.png` · `wildlife_bear_move_07.png`
Files: `wildlife_viper_move_01.png` · `wildlife_viper_move_02.png` · `wildlife_viper_move_03.png` · `wildlife_viper_move_04.png` · `wildlife_viper_move_05.png` · `wildlife_viper_move_06.png` · `wildlife_viper_move_07.png`
Files: `wildlife_badger_move_01.png` · `wildlife_badger_move_02.png` · `wildlife_badger_move_03.png` · `wildlife_badger_move_04.png` · `wildlife_badger_move_05.png` · `wildlife_badger_move_06.png` · `wildlife_badger_move_07.png`
Files: `wildlife_rabbit_move_01.png` · `wildlife_rabbit_move_02.png` · `wildlife_rabbit_move_03.png` · `wildlife_rabbit_move_04.png` · `wildlife_rabbit_move_05.png` · `wildlife_rabbit_move_06.png` · `wildlife_rabbit_move_07.png`
Files: `wildlife_squirrel_move_01.png` · `wildlife_squirrel_move_02.png` · `wildlife_squirrel_move_03.png` · `wildlife_squirrel_move_04.png` · `wildlife_squirrel_move_05.png` · `wildlife_squirrel_move_06.png` · `wildlife_squirrel_move_07.png`
Files: `wildlife_stag_move_01.png` · `wildlife_stag_move_02.png` · `wildlife_stag_move_03.png` · `wildlife_stag_move_04.png` · `wildlife_stag_move_05.png` · `wildlife_stag_move_06.png` · `wildlife_stag_move_07.png`
Files: `wildlife_heron_move_01.png` · `wildlife_heron_move_02.png` · `wildlife_heron_move_03.png` · `wildlife_heron_move_04.png` · `wildlife_heron_move_05.png` · `wildlife_heron_move_06.png` · `wildlife_heron_move_07.png`
Files: `wildlife_hedgehog_move_01.png` · `wildlife_hedgehog_move_02.png` · `wildlife_hedgehog_move_03.png` · `wildlife_hedgehog_move_04.png` · `wildlife_hedgehog_move_05.png` · `wildlife_hedgehog_move_06.png` · `wildlife_hedgehog_move_07.png`
Files: `wildlife_lynx_move_01.png` · `wildlife_lynx_move_02.png` · `wildlife_lynx_move_03.png` · `wildlife_lynx_move_04.png` · `wildlife_lynx_move_05.png` · `wildlife_lynx_move_06.png` · `wildlife_lynx_move_07.png`
Files: `wildlife_tortoise_move_01.png` · `wildlife_tortoise_move_02.png` · `wildlife_tortoise_move_03.png` · `wildlife_tortoise_move_04.png` · `wildlife_tortoise_move_05.png` · `wildlife_tortoise_move_06.png` · `wildlife_tortoise_move_07.png`
Files: `wildlife_jackal_move_01.png` · `wildlife_jackal_move_02.png` · `wildlife_jackal_move_03.png` · `wildlife_jackal_move_04.png` · `wildlife_jackal_move_05.png` · `wildlife_jackal_move_06.png` · `wildlife_jackal_move_07.png`
Files: `wildlife_scorpion_move_01.png` · `wildlife_scorpion_move_02.png` · `wildlife_scorpion_move_03.png` · `wildlife_scorpion_move_04.png` · `wildlife_scorpion_move_05.png` · `wildlife_scorpion_move_06.png` · `wildlife_scorpion_move_07.png`
Files: `wildlife_snow_hare_move_01.png` · `wildlife_snow_hare_move_02.png` · `wildlife_snow_hare_move_03.png` · `wildlife_snow_hare_move_04.png` · `wildlife_snow_hare_move_05.png` · `wildlife_snow_hare_move_06.png` · `wildlife_snow_hare_move_07.png`
Files: `wildlife_ptarmigan_move_01.png` · `wildlife_ptarmigan_move_02.png` · `wildlife_ptarmigan_move_03.png` · `wildlife_ptarmigan_move_04.png` · `wildlife_ptarmigan_move_05.png` · `wildlife_ptarmigan_move_06.png` · `wildlife_ptarmigan_move_07.png`
Files: `wildlife_snow_lynx_move_01.png` · `wildlife_snow_lynx_move_02.png` · `wildlife_snow_lynx_move_03.png` · `wildlife_snow_lynx_move_04.png` · `wildlife_snow_lynx_move_05.png` · `wildlife_snow_lynx_move_06.png` · `wildlife_snow_lynx_move_07.png`
Files: `wildlife_frost_elk_move_01.png` · `wildlife_frost_elk_move_02.png` · `wildlife_frost_elk_move_03.png` · `wildlife_frost_elk_move_04.png` · `wildlife_frost_elk_move_05.png` · `wildlife_frost_elk_move_06.png` · `wildlife_frost_elk_move_07.png`

### 5.10f Wildlife attack frames — `res://art/wildlife/`

All 64×64, type T, placeholder colour `#7A8B6E`.

The strike pose, for the six that fight. Its own sequence rather than a reuse of
the walk, because **the wind-up is what the player reads to decide whether to
move** — an animal that swung with its walking pose would be a hit with no tell
in front of it.

Each is the same animal committing: the wolf's jaws open, the boar's head down
and tusks forward, the bear reared with a paw up, the viper uncoiled, the badger
snarling, the hawk with its wings swept back and talons out.

Five frames per fighter, generated from the existing strike pose so palette,
scale and silhouette stay species-consistent through wind-up, contact and
recovery.

Files: `wildlife_wolf_attack_01.png` … `wildlife_wolf_attack_05.png`
Files: `wildlife_boar_attack_01.png` … `wildlife_boar_attack_05.png`
Files: `wildlife_bear_attack_01.png` … `wildlife_bear_attack_05.png`
Files: `wildlife_viper_attack_01.png` … `wildlife_viper_attack_05.png`
Files: `wildlife_lynx_attack_01.png` … `wildlife_lynx_attack_05.png`
Files: `wildlife_jackal_attack_01.png` … `wildlife_jackal_attack_05.png`
Files: `wildlife_scorpion_attack_01.png` … `wildlife_scorpion_attack_05.png`
Files: `wildlife_snow_lynx_attack_01.png` … `wildlife_snow_lynx_attack_05.png`
Files: `wildlife_frost_elk_attack_01.png` … `wildlife_frost_elk_attack_05.png`
Files: `wildlife_badger_attack_01.png` … `wildlife_badger_attack_05.png`
Files: `wildlife_hawk_attack_01.png` … `wildlife_hawk_attack_05.png`

**No death frames, and that is the better answer rather than the cheaper one.**
Dying is procedural — the body topples, settles and fades. One routine covers six
creatures with nothing anatomically in common, and it cannot disagree with the
sprite it started from, which authored frames from this generator repeatedly
have.

### 5.10e Wildlife flight frames — `res://art/wildlife/`

All 64×64, type T, placeholder colour `#7A8B6E`.

A third sequence, for anything that leaves the ground. Not a reuse of the move
frames: a bird walking and a bird flying are not the same animal at two speeds,
and a crow that hopped across the sky was exactly what shipping only one moving
sequence looked like.

Eight frames carry the wing all the way from high through level to a sustained,
clearly low downstroke, then recover to the raised pose. The added temporal room
keeps the lowest part of the beat visible at gameplay frame rates.

Files: `wildlife_raven_fly_01.png` … `wildlife_raven_fly_08.png`
Files: `wildlife_hawk_fly_01.png` … `wildlife_hawk_fly_08.png`

Both birds also land between flights. Their grounded loops are perched
silhouettes with planted feet and restrained breathing/head motion, not frozen
in-flight frames.

Files: `wildlife_hawk_idle_01.png` … `wildlife_hawk_idle_05.png`

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
`ui_stone.png` · `ui_hero_health.png` · `ui_wounds.png` · `ui_last_scar.png` ·
`ui_resurrection_draught.png` · `ui_hearthroot_tonic.png` ·
`ui_rimeglass_ward.png` · `ui_scope_battlefield.png` ·
`ui_scope_town.png` · `ui_scope_beast.png`

Persistent gear uses the same world-object language. Every `GearData.id`
resolves by convention to `ui_<id>.png`; these are used both in the stash and
as the readable silhouette inside a rarity-lit battlefield pickup.

`ui_coalpaint_edge.png` · `ui_sunglass_saber.png` ·
`ui_shieldbearers_vow.png` · `ui_gutterfang.png` ·
`ui_reckoners_rod.png` · `ui_warmarked_jack.png` ·
`ui_reaver_plate.png` · `ui_driftrunners_wrap.png` ·
`ui_reliquary_harness.png` · `ui_hearthiron_torc.png` ·
`ui_deepwell_charm.png` · `ui_oathiron_ring.png` ·
`ui_coursers_feather.png` · `ui_ledgerkeepers_seal.png` ·
`ui_bulwark_pike.png` · `ui_stonewarden_hammer.png` ·
`ui_whisper_fang.png` · `ui_windcut_saber.png` ·
`ui_sigil_brand.png` · `ui_tally_knife.png` ·
`ui_tollgate_barbute.png` · `ui_kettle_of_the_ninth.png` ·
`ui_hollow_crown_cap.png` · `ui_riverwake_hood.png` ·
`ui_lantern_mask.png` · `ui_nailed_mitts.png` ·
`ui_ropeburn_wraps.png` · `ui_drovers_gloves.png` ·
`ui_counting_gloves.png` · `ui_forgescarred_grips.png` ·
`ui_ditchwalker_boots.png` · `ui_nailsole_clogs.png` ·
`ui_marchwarden_greaves.png` · `ui_quietstep_slippers.png` ·
`ui_frostbound_treads.png` · `ui_tally_ring.png` ·
`ui_harelip_band.png` · `ui_splitknuckle_ring.png` ·
`ui_widows_iron.png` · `ui_oathbreakers_loop.png` ·
`ui_road_token.png` · `ui_tooth_on_a_cord.png` ·
`ui_waystation_bell.png` · `ui_cartographers_pendant.png` ·
`ui_chainlink_reliquary.png` ·
`ui_berserkers_harness.png` · `ui_scholars_mantle.png` ·
`ui_warpriests_plate.png` · `ui_skirmishers_leathers.png` ·
`ui_hearthstone_pendant.png` · `ui_bloodoath_band.png` ·
`ui_rimebound_maul.png` · `ui_rootweave_guard.png` ·
`ui_mirrorscale_plate.png` · `ui_avalanche_harness.png` ·
`ui_emberwind_charm.png` · `ui_hearthkeeper_sigil.png` ·
`ui_chainbreaker_seal.png` · `ui_wardens_step.png` ·
`ui_tanners_cleaver.png` · `ui_pilgrims_spear.png` ·
`ui_twinfang_dirks.png` · `ui_lanternhook.png` ·
`ui_ashfall_glaive.png` · `ui_oathbreakers_axe.png` ·
`ui_roadmenders_coat.png` · `ui_kilnforged_hauberk.png` ·
`ui_stormwake_mantle.png` · `ui_pelt_of_long_watch.png` ·
`ui_tollkeepers_bell.png` · `ui_feathercut_talisman.png` ·
`ui_quiet_ledger.png` · `ui_bloodroot_knot.png`

Five more slots were opened on 2026-09-01 — head, hands, feet, and two
jewellery sockets. Their icons follow the same rule: a worn object drawn as an
object, so that a piece is recognisable in a stash row without reading its name.
The jewellery is drawn small and lit, because at 40px a band and a pendant are
otherwise the same grey ring.

`ui_roadwardens_helm.png` · `ui_ashplate_greathelm.png` ·
`ui_seers_circlet.png` · `ui_quarry_gauntlets.png` ·
`ui_surehand_wraps.png` · `ui_lodestone_grips.png` ·
`ui_marchers_boots.png` · `ui_windstep_sandals.png` ·
`ui_ironshod_treads.png` · `ui_band_of_the_watch.png` ·
`ui_emberloop.png` · `ui_tidewrack_ring.png` ·
`ui_pilgrims_amulet.png` · `ui_nightglass_pendant.png` ·
`ui_harriers_token.png`

Each of the five went to five kinds rather than three, so that every slot can
raise any of the four attributes and the question a slot poses is which
attribute this loadout wants rather than which piece scores highest.

`ui_watchers_coif.png` · `ui_kilnglass_visor.png` ·
`ui_tanners_mitts.png` · `ui_sootcloth_gloves.png` ·
`ui_stillstep_boots.png` · `ui_ashwalk_greaves.png` ·
`ui_harebone_band.png` · `ui_quarryman_signet.png` ·
`ui_boarstooth_amulet.png` · `ui_deepglass_torc.png`

Four of these were drawn twice. Hand armour generates as leg armour unless the
prompt insists on fingers, and a ring generates as a slab unless it insists on
the hole; the first pass put boots in the Gloves slot and a paving stone in the
Rings slot, and both were only visible on a contact sheet. Look at gear icons
side by side before believing the filenames.

The three `ui_scope_*` icons are final production art, added when the scope bar
became a column of icons: text that named function keys could not survive on a
phone. Crossed blades on a shield, a gate keep, and the walking beast in profile
- three silhouettes that stay apart at 30px, which is the only size that matters
for them.

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
`discipline_beasts_breath.png` · `discipline_break_the_host.png` ·
`discipline_call_wolf.png` · `discipline_call_crow.png` ·
`discipline_call_serpent.png` · `discipline_call_hart.png` ·
`discipline_call_ram.png` ·
`discipline_call_bear.png`

The three families share blackened iron and aged brass; Blood uses controlled
crimson, Holy uses ivory-gold, and Berserk uses ember-orange so discipline
identity survives without relying on text alone.

The three summons break that scheme on purpose: they are ghost-blue in all three
families, because what they have in common is being a *spirit* rather than
belonging to a school. One is offered per discipline, so any hero can reach a
companion and no hero can hold all three.

### 5.13e Road Card icons — `res://art/icons/road_cards/`

All 128×128, type T, placeholder colour `#B8863A`.

`card_whetstone_hour.png` · `card_cleared_sightlines.png` · `card_banked_earth.png` ·
`card_the_forager.png` · `card_picked_clean.png` · `card_loose_boots.png` ·
`card_short_rations.png` · `card_propped_gate.png` · `card_dry_powder.png` ·
`card_cold_iron_stakes.png` · `card_the_long_lever.png` · `card_set_stance.png` ·
`card_the_good_road.png` · `card_the_standing_order.png` · `card_counted_the_fires.png` ·
`card_the_quartermaster.png` · `card_the_master_founder.png` · `card_the_watchtower_eye.png` ·
`card_riveted_plate.png` · `card_the_conductor.png` · `card_the_open_hand.png` ·
`card_second_wind.png` · `card_the_deep_cellar.png` · `card_the_quiet_approach.png`

One per card, drawn on the face that offers it, and the same rule as the omen
icons: a **single object the road left behind** rather than a symbol. A card is
one of three read in a few seconds, and three silhouettes separate faster than
three sentences do - which is the argument that bought the omens their art and
applies here with twenty crossroads' worth of repetition behind it.

Warm bone, rust and amber, like the relics and the portents. Two came back
wrong on the first pass and were regenerated: the ranging glass arrived as a
chalice and the tally stick as a plank, neither of which any gate can see.

### 5.13b Omen icons — `res://art/icons/omens/`

All 128×128, type T, placeholder colour `#B8863A`.

`omen_glassfall.png` · `omen_lean_season.png` · `omen_open_country.png` ·
`omen_the_gathering.png` · `omen_the_heavy_load.png` · `omen_the_iron_price.png` ·
`omen_the_last_watch.png` · `omen_the_long_night.png` · `omen_the_red_ford.png` ·
`omen_the_wake.png`

Ten more since 2026-09-11, because ten acts read ten portents and a pool of ten
runs out at the ninth:

`omen_ashfall.png` · `omen_iron_rain.png` · `omen_salt_in_the_wounds.png` ·
`omen_the_far_horn.png` · `omen_the_hollowing.png` · `omen_the_last_gate.png` ·
`omen_the_long_thaw.png` · `omen_the_quiet_road.png` · `omen_the_shatter.png` ·
`omen_the_stone_tithe.png`

One per portent, drawn on the card that offers it. Each is a **single object the
road left behind** rather than a symbol or a scene: an emptied cooking pot, a
lantern still lit in an abandoned waystation, a snapped trunk shoved aside. The
portent line is written as something a traveller noticed, and the icon is the
thing they noticed.

Warm bone, rust and amber like the relic icons, with two deliberate exceptions —
Glassfall is cold silver and The Long Night is black against pale corona, because
both portents are about the light changing and a warm version of either would
read as one more piece of luggage.

### 5.13c Fish — `res://art/fish/`

All 64×64, type T, placeholder colour `#7FA9C4`.

`fish_chainmaker_koi.png` · `fish_deepwinter_pike.png` · `fish_frostgill_char.png` ·
`fish_glasshead_dace.png` · `fish_greenback_perch.png` · `fish_mirebell_eel.png` ·
`fish_roadkeeper_carp.png` · `fish_saltglass_bream.png` · `fish_silt_minnow.png` ·
`fish_sunglass_ray.png` · `fish_white_teeth_trout.png`

One per kind pulled out of the ponds, drawn as a single fish on transparency and
seen from the side — the shape a thing makes lying on a bank, which is where the
player meets it. They are icons rather than creatures: nothing here animates, and
the only place one is drawn at size is the stash's Consumables list.

Three per region and two that swim in every water. The regional nine are ordinary
animals, coloured to their act — the Maw's are green and fat, the Waste's are pale
and glassy, the White Teeth's are dark-flanked and spotted. The two that go
everywhere are not ordinary: the Roadkeeper is an enormous scarred bronze carp and
the Chainmaker's Koi is scaled in iron links edged with gold, because a Legendary
that merely had better numbers would be a rarity nobody could see.

### 5.13d Ponds — `res://art/battlefield/`

All 128×128, type T, placeholder colour `#3E6C74`.

`pond_tiles_jungle.png` · `pond_tiles_desert.png` · `pond_tiles_snow.png` ·
`pond_tiles_hollow_marches.png` · `pond_tiles_rustwood.png` · `pond_tiles_saltpan.png` ·
`pond_tiles_iron_steppe.png` · `pond_tiles_glass_fields.png` · `pond_tiles_ashen_reach.png` ·
`pond_tiles_last_terrace.png`

**The water is a tilemap now (2026-09-11), not a picture.** One sixteen-tile
Wang sheet per region, 32px tiles drawn at twice size, in canonical corner
order - tile index NW·8 + NE·4 + SW·2 + SE, four across, a set bit meaning
water in that corner. `tools/install_pond_tiles.py` repacks PixelLab's sheet
into that order, so `PondTiles` reads a texture and no per-region metadata. A
pond is a blob of water nodes on a lattice, so every pond is its own shape and
size, and `pond_water.gdshader` puts the light on it.

#### The float

The float on the line, cast from the hand to the water.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `fishing_float.png` | 32×32 | T | `#C4552E` |

### 5.13f Rift gates — `res://art/battlefield/`

The gates into the rifts and dungeons (2026-09-11), dug in the outer band
beside the ponds by `RiftGates`. The rift is a tear of violet light on a
plinth; the dungeon mouth is a broken stair down under a carved arch.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `rift_gate.png` | 160×160 | T | `#7A5FC4` |
| `dungeon_mouth.png` | 192×160 | T | `#7A5FC4` |

#### Rift gate frames

All 160×160, type T, placeholder colour `#7A5FC4`. The light pulses and the
shards drift; a spent gate stops on its base frame.

Files: `rift_gate_idle_01.png` … `rift_gate_idle_06.png`

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

The sixteen sets below own road **shape only**. Their alpha masks define every
bend, junction, collar and shoulder. One seamless 512×512 regional material is
mapped continuously across the baked mask, so fine travel wear never restarts at
a junction and can never appear on open terrain.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `road_surface_jungle.png` | 512×512 | O | `#4A3E31` |
| `road_surface_desert.png` | 512×512 | O | `#8B6338` |
| `road_surface_snow.png` | 512×512 | O | `#657087` |

**Act I — The Verdant Maw**

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `path_jungle_00.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_01.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_02.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_03.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_04.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_05.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_06.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_07.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_08.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_09.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_10.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_11.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_12.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_13.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_14.png` | 64×64 | T | `#6B5A44` |
| `path_jungle_15.png` | 64×64 | T | `#6B5A44` |

**Act II — The Sunglass Waste**

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `path_desert_00.png` | 64×64 | T | `#D8C08A` |
| `path_desert_01.png` | 64×64 | T | `#D8C08A` |
| `path_desert_02.png` | 64×64 | T | `#D8C08A` |
| `path_desert_03.png` | 64×64 | T | `#D8C08A` |
| `path_desert_04.png` | 64×64 | T | `#D8C08A` |
| `path_desert_05.png` | 64×64 | T | `#D8C08A` |
| `path_desert_06.png` | 64×64 | T | `#D8C08A` |
| `path_desert_07.png` | 64×64 | T | `#D8C08A` |
| `path_desert_08.png` | 64×64 | T | `#D8C08A` |
| `path_desert_09.png` | 64×64 | T | `#D8C08A` |
| `path_desert_10.png` | 64×64 | T | `#D8C08A` |
| `path_desert_11.png` | 64×64 | T | `#D8C08A` |
| `path_desert_12.png` | 64×64 | T | `#D8C08A` |
| `path_desert_13.png` | 64×64 | T | `#D8C08A` |
| `path_desert_14.png` | 64×64 | T | `#D8C08A` |
| `path_desert_15.png` | 64×64 | T | `#D8C08A` |

**Act III — The White Teeth**

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `path_snow_00.png` | 64×64 | T | `#8A8D95` |
| `path_snow_01.png` | 64×64 | T | `#8A8D95` |
| `path_snow_02.png` | 64×64 | T | `#8A8D95` |
| `path_snow_03.png` | 64×64 | T | `#8A8D95` |
| `path_snow_04.png` | 64×64 | T | `#8A8D95` |
| `path_snow_05.png` | 64×64 | T | `#8A8D95` |
| `path_snow_06.png` | 64×64 | T | `#8A8D95` |
| `path_snow_07.png` | 64×64 | T | `#8A8D95` |
| `path_snow_08.png` | 64×64 | T | `#8A8D95` |
| `path_snow_09.png` | 64×64 | T | `#8A8D95` |
| `path_snow_10.png` | 64×64 | T | `#8A8D95` |
| `path_snow_11.png` | 64×64 | T | `#8A8D95` |
| `path_snow_12.png` | 64×64 | T | `#8A8D95` |
| `path_snow_13.png` | 64×64 | T | `#8A8D95` |
| `path_snow_14.png` | 64×64 | T | `#8A8D95` |
| `path_snow_15.png` | 64×64 | T | `#8A8D95` |

### 5.17b Fallen marker — `res://art/vfx/`

The stone that stands where a player went down, and disappears the moment they
are helped up. A collapsed hero hides its own sprite — it has to, or a corpse
lies on the field looking alive — and a revive bar alone is a few pixels of
outline at a distance, so a partner crossing the map had nothing to walk
*towards*. Never drawn in a solo run: nobody is coming.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `fallen_marker.png` | 40×48 | T | `#8A9099` |

### 5.18 Projectiles — `res://art/vfx/`

One head per element, drawn as a horizontal bolt pointing east with its wake
trailing west. Horizontal on purpose: the sprite is rotated to its heading in
flight, and a diagonal drawing reads as permanently mis-aimed. The
sprite is a skin over the existing flight: the trail, filament, light, tumble and
per-level scaling all still run underneath, so a missing file costs nothing and
the shot still reads.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `projectile_fire.png` | 96×48 | T | `#E8752B` |
| `projectile_water.png` | 96×48 | T | `#54B8C8` |
| `projectile_earth.png` | 96×48 | T | `#B07A3E` |
| `projectile_air.png` | 96×48 | T | `#BFE6F0` |

Impact bursts, one per element, layered over the sparks and the blast ring at
the moment of a hit. The sparks carry direction and the ring carries radius, so
the art only has to carry the element - which is why one frame is enough.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `impact_fire.png` | 96×96 | T | `#E8752B` |
| `impact_water.png` | 96×96 | T | `#54B8C8` |
| `impact_earth.png` | 96×96 | T | `#B07A3E` |
| `impact_air.png` | 96×96 | T | `#BFE6F0` |

### 5.18a Drawn bursts — `res://art/vfx/`

Frame zero is the ordinary drawing and the `_idle_NN` frames play through
once, on the same convention the impacts use; `Vfx.sheet_burst` plays any of
them at a point. The ripple is rings out from a cast, a bite and a landed
fish; the splash is the float going in and the fish coming out; the sparks are
a blow landing on steel; the slash is the crescent of a finisher; the burst is
a radial impact, white-hot to gone; the cut is the chain's fast steps; the
embers are an ember spray for fire and for deaths in a burning region.

Made the way PixelLab's own VFX workflow suggests (2026-09-11): a Pro sprite
sheet of nine concepts per family, the winners cropped and centred, then
animated with the constraint that the effect stays inside its own frame. The
ripple is the one that had to be redone for exactly that reason - an
open-ended "rings expanding" animation walks straight off the canvas.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `ripple.png` | 96×96 | T | `#BFE6F0` |
| `splash.png` | 96×96 | T | `#BFE6F0` |
| `sparks.png` | 96×96 | T | `#E8752B` |
| `slash.png` | 160×160 | T | `#BFE6F0` |
| `burst.png` | 96×96 | T | `#E8752B` |
| `cut.png` | 96×96 | T | `#BFE6F0` |
| `embers.png` | 96×96 | T | `#E8752B` |

#### Drawn burst frames

All 96×96, type T, placeholder colour `#BFE6F0`.

Files: `ripple_idle_01.png` … `ripple_idle_06.png`
Files: `splash_idle_01.png` … `splash_idle_06.png`
Files: `sparks_idle_01.png` … `sparks_idle_06.png`
Files: `burst_idle_01.png` … `burst_idle_06.png`
Files: `cut_idle_01.png` … `cut_idle_06.png`
Files: `embers_idle_01.png` … `embers_idle_06.png`

#### Slash frames

All 160×160, type T, placeholder colour `#BFE6F0`.

Files: `slash_idle_01.png` … `slash_idle_06.png`

The optional, teen-rated character-hit layer is procedural: short ballistic
droplets land into the shared ground field. It has no bitmap requirement, and
the Blood effects setting can remove it without removing danger telegraphs, hit
confirmation, or damage numbers.

Ground pools, one per element. Rotated to any angle, scaled and hue-jittered per
cast, so four files never read as four stamps — the variety lives in the
placement, the same way it does in the ground tiles.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `pool_fire.png` | 128×128 | T | `#E8752B` |
| `pool_water.png` | 128×128 | T | `#54B8C8` |
| `pool_earth.png` | 128×128 | T | `#B07A3E` |
| `pool_air.png` | 128×128 | T | `#BFE6F0` |

### 5.18b Shared particle art — `res://art/vfx/`

The two shapes the whole game is built out of. A caller count across the effects
autoload put the expanding ring at 38 sites and the outward spark burst at 35 -
between them roughly three quarters of every effect a player ever sees - and
both were drawing bare geometry: a polyline circle and coloured line segments.
Every element-specific asset above sits on top of those two, so this is the
cheapest square inch of art in the project.

Both are drawn white and tinted at runtime by the caller's colour, which is why
there is one of each rather than one per element. A coloured source multiplies
into mud the moment somebody asks for blue, and the callers ask for blue, green,
red, gold and the four elements.

They add to the procedural motion rather than replacing it. The polyline still
draws the crisp leading edge of the wave and the sprite gives it a body; the
line segment still carries the streak of a shard and the sprite gives it a hot
head. A missing file costs the softness and nothing else - both effects still
run, exactly as they did before this art existed.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `vfx_ring.png` | 128×128 | T | `#FFFFFF` |
| `vfx_spark.png` | 32×32 | T | `#FFFFFF` |

### 5.18c Muzzle flashes — `res://art/vfx/`

All 80×80, type T, placeholder colour `#D8B47A`.

The third beat of a shot, and the one that had no art: a tower firing read as
nothing at the origin, a painted bolt in flight, and a painted burst on arrival.
The procedural cone is still drawn on top — it is the instantaneous white-hot
stab that sells the timing — and these carry the material underneath it.

Each is a decay sequence rather than a loop: frame zero is the peak and the
continuation frames collapse to almost nothing, because a muzzle flash happens
once. They are rotated to the shot and randomly flipped, so a lane of one tower
firing does not stamp the same picture over and over.

Files: `muzzle_fire.png` `muzzle_water.png` `muzzle_earth.png` `muzzle_air.png`
Files: `muzzle_fire_idle_01.png` … `muzzle_fire_idle_08.png`
Files: `muzzle_water_idle_01.png` … `muzzle_water_idle_08.png`
Files: `muzzle_earth_idle_01.png` … `muzzle_earth_idle_08.png`
Files: `muzzle_air_idle_01.png` … `muzzle_air_idle_08.png`

### 5.18d Projectile flight loops — `res://art/vfx/`

All 96×48, type T, placeholder colour `#D8B47A`.

Continuation frames for the projectile heads above, on the same `_idle_NN`
convention every animated structure uses. Frame zero is the ordinary drawing in
5.18 and is not repeated here.

**The bolt animates in place and the scene does the travelling.** That split is
what keeps one drawing reusable — the sprite carries flicker, heat and trailing
embers while the game carries speed, homing and position — and it is the thing
most easily got wrong, because a generated animation will happily fly the
subject across its own canvas unless told not to.

Frame counts differ on purpose. Fire, water and earth run the full eight. Air
ships five, and they are frames 1, 2, 3, 2, 1 of its generated run: that run
faded 32% from end to end, so looping it straight strobed at the seam, while the
bright half ping-ponged holds to within 7%.

Files: `projectile_fire_idle_01.png` … `projectile_fire_idle_08.png`
Files: `projectile_water_idle_01.png` … `projectile_water_idle_08.png`
Files: `projectile_earth_idle_01.png` … `projectile_earth_idle_08.png`
Files: `projectile_air_idle_01.png` … `projectile_air_idle_05.png`

### 5.16 Raid — `res://art/raid/`

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `chieftain_jungle.png` | 256×256 | T | `#3E5A52` |
| `chieftain_desert.png` | 256×256 | T | `#9FB4C4` |
| `chieftain_snow.png` | 256×256 | T | `#9C4A3B` |
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
| `ui_app_icon.png` | 512×512 | T | `#181A1C` |
| `ui_app_icon_192.png` | 192×192 | T | `#181A1C` |
| `ui_app_icon_fore.png` | 432×432 | T | `#181A1C` |
| `ui_app_icon_back.png` | 432×432 | T | `#181A1C` |

The four icons are the **application** icon, not artwork in the game. Android
refuses to export without one, and modern launchers show the adaptive pair - a
foreground the launcher masks to its own shape over a flat background - rather
than the square. All four are derived from the beast's first idle frame, because Yuri
carrying the city is the game's identity and that sprite is already square; the
wordmark is 1024×512 and would have sat in empty bands. The foreground is inset
further than the square, since a launcher crops up to a third of the edge away.

Replacing them is overwriting the files, like any other art. They are opaque on
purpose: a transparent icon becomes a silhouette on some launchers.
| `splash_studio.png` | 1920×1080 | O | `#0B1416` |

---


### 5.7e Ranged weapons — `res://art/ranged/`

Owner decision, 2026-08-31. One icon per weapon. A blueprint needs no art of its
own: it wears the icon of whatever it teaches, so adding a plan costs nothing
here.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `ranged_shortbow.png` | 128×128 | T | `#7A5A32` |
| `ranged_longbow.png` | 128×128 | T | `#7A5A32` |
| `ranged_windcarver.png` | 128×128 | T | `#8FA07A` |
| `ranged_hand_ballista.png` | 128×128 | T | `#6E6A62` |
| `ranged_heavy_crossbow.png` | 128×128 | T | `#5A5A5E` |

### 5.7f Ammunition — `res://art/ammo/`

Silhouette first. An Ember Arrow and a Rime Arrow are told apart at a glance in
the quiver readout, which is the whole reason they carry marks rather than
labels.

| File | Size | Type | Placeholder colour |
|------|------|------|--------------------|
| `ammo_plain_arrow.png` | 128×128 | T | `#8A7B57` |
| `ammo_ember_arrow.png` | 128×128 | T | `#B4471F` |
| `ammo_rime_arrow.png` | 128×128 | T | `#6FA8C4` |
| `ammo_barbed_arrow.png` | 128×128 | T | `#8A7B57` |
| `ammo_thunder_bolt.png` | 128×128 | T | `#6FA8C4` |
| `ammo_plain_bolt.png` | 128×128 | T | `#6E6A60` |
| `ammo_blast_bolt.png` | 128×128 | T | `#9C6A34` |

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
| `terrain_jungle` | dark marsh ground, pools of black standing water, pale dead reeds, ash-grey mud, sunken twisted roots |
| `terrain_desert` | cracked salt flat, pale white-blue crystalline crust, thin fracture lines, scattered glassy shards |
| `terrain_snow` | dry snow hardpan, red-brown cracked earth, scattered rusted iron debris, sparse dead grass tufts |

### Backdrops (Midjourney, opaque stem)

| Asset | Subject |
|-------|---------|
| `macro_act1` | a vast fog-drowned marsh valley stretching to the horizon, drowned trees, low grey mist, distant water |
| `macro_act2` | an endless cracked white salt desert under a bruised sky, distant glass formations catching light, heat shimmer |
| `macro_act3` | a red-brown iron snow under a heavy dust sky, the ruined silhouette of an immense fortress on the far horizon |
| `crossroad_bg` | a fork in an ancient road at dusk, two paths diverging into different distant landscapes, weathered stone waymarker in the foreground |
| `raid_arena_bg` | a hostile enemy warcamp seen from directly above, ringed by bone totems and burning braziers, packed dirt floor, tents at the edges `--ar 1:1` |
| `menu_key_art` | an original colossal, root-bound road gate at twilight: deep indigo jungle and stone framing a restrained amber road into layered peaks — **left side quiet for navigation, upper centre quiet for the logo, centre-right staged and no creature in it**, because the game's own beast, firelight, mist and embers are drawn onto it at runtime |

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
| **After Stage 2** (triage confirmed fun) | `hero_base`, `enemy_bogkin`, all 8 towers, `city_base`, `terrain_jungle` |
| **After Stage 3** | `elite_*`, `raid_arena_bg` |
| **After Stage 4** | `building_*`, `beast_profile`, `ui_*` |
| **Stage 5–6** | everything else |
| **Last** | `menu_key_art` — make it when you know what the game looks like, because it becomes your Steam capsule. It is a *stage*, not a finished picture: `MenuStage` composes the beast, mist, embers, star shimmer and horizon glow over it at runtime, so the art must leave its middle empty |

If a stage's kill question fails, every asset made for it is wasted. That is
the whole reason for this order.
