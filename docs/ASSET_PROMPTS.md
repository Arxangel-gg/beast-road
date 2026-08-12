# BEAST ROAD - Asset Generation Prompts

**Generated from `ASSET_MANIFEST.md`.** Do not hand-edit the sizes here - fix the manifest
and regenerate, or the two will disagree about what the game loads.

122 assets: **111 ChatGPT** (transparent background) and **11 Midjourney** (opaque).

---

## How to use this

1. Generate the image with the prompt given.
2. Save it with **exactly the filename in the heading**. That is the only thing you have
   to get right - not the folder, not the resolution.
3. Drop every finished file into `art_inbox/` at the repo root.
4. Run:

```
tools\import_art.ps1
```

That resizes each image to its exact target dimensions, verifies transparent assets really
have an alpha channel, files each one at its correct `res://art/...` path, and reports
anything it could not match.

You do not need to resize anything yourself. Generate ChatGPT assets at 1024x1024 and
Midjourney assets at whatever the aspect ratio gives you.

### Getting real transparency out of ChatGPT

If it returns a grey-and-white checkerboard *painted into the image* instead of genuinely
empty pixels, reply:

> regenerate with a true transparent alpha channel, not a checkerboard pattern drawn in the image

The importer refuses a transparent-type asset that arrives fully opaque, so a bad export
gets caught before it reaches the game.

### Locking the Midjourney style

Generate `menu_key_art.png` first. Once you have one you like, take its `--sref` code and
append it to every later Midjourney prompt. That is what makes the opaque set look like one
game instead of separate paintings.

---

# ChatGPT prompts - transparent background

Paste the whole block, including the SUBJECT line. Every one of these needs a real alpha channel.

## 5.1 Hero — `res://art/hero/`

### `hero_base.png`

`128 x 128`  ->  `res://art/hero/hero_base.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 128 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a lone armored scavenger-warrior, curved single-edged blade held low at one side, tattered dark cloak, bone-white featureless mask, lean wiry build, scavenged plate over wrapped cloth
```

### `hero_ascended_1.png`

`128 x 128`  ->  `res://art/hero/hero_ascended_1.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 128 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: the same armored scavenger-warrior, now transformed - the mask cracked open with amber light bleeding through, the cloak longer and torn, one arm sheathed in fused bone plating, the blade glowing faintly at its edge
```

### `hero_ascended_2.png`

`128 x 128`  ->  `res://art/hero/hero_ascended_2.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 128 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: the same warrior in final transformation - towering and monstrous, the mask fully shattered into a crown of bone shards, amber light pouring from every seam, cloak become a mass of trailing ribbons, the blade elongated and burning
```

## 5.2 Enemies — `res://art/enemies/`

### `enemy_bogkin.png`

`96 x 96`  ->  `res://art/enemies/enemy_bogkin.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 96 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a hunched swamp-dweller creature, waterlogged and bloated, moss and dead reeds hanging from its limbs, dim pale eyes, heavy rounded shoulders, dripping black water
```

### `enemy_glassborn.png`

`96 x 96`  ->  `res://art/enemies/enemy_glassborn.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 96 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a jagged crystalline humanoid made of fractured salt glass, thin sharp limbs, semi-translucent body catching light, hairline fractures across its shoulders
```

### `enemy_steppehorde.png`

`96 x 96`  ->  `res://art/enemies/enemy_steppehorde.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 96 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a scrappy nomad raider in scavenged rusted iron plates, crude iron spear held upright, wiry underfed frame, cloth-wrapped head
```

### `elite_warden.png`

`128 x 128`  ->  `res://art/enemies/elite_warden.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 128 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a heavily armored bulwark warrior hunched behind an enormous riveted iron shield taller than itself, dense immovable silhouette, minimal visible body
```

### `elite_howler.png`

`128 x 128`  ->  `res://art/enemies/elite_howler.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 128 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a gaunt ritual-caller with an oversized curved bone horn raised to its mouth, ragged banner strapped to its back, throat distended
```

### `elite_burrower.png`

`128 x 128`  ->  `res://art/enemies/elite_burrower.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 128 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a segmented armored digging creature erupting from broken ground, heavy clawed forelimbs, eyeless armored head plate, broad chitinous back
```

## 5.3 Bosses — `res://art/bosses/`

### `boss_drowned_choir.png`

`384 x 384`  ->  `res://art/bosses/boss_drowned_choir.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 384 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a towering mass of fused drowned bodies forming a single cathedral-like figure, dozens of open singing mouths across its surface, black water pouring continuously from its frame, tattered ceremonial cloth, immense and vertical
```

### `boss_mirrorfang.png`

`384 x 384`  ->  `res://art/bosses/boss_mirrorfang.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 384 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: an enormous predatory quadruped beast built from mirrored salt glass, overlapping reflective shard plating, long fanged skull, refracted amber light scattering off its flanks
```

### `boss_rust_crown.png`

`384 x 384`  ->  `res://art/bosses/boss_rust_crown.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 384 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a colossal armored warlord fused to a throne of corroded iron, a crown of jagged rusted spires grown into its skull, chains and torn banners hanging from its shoulders, monumental scale
```

## 5.4 Towers — `res://art/towers/`

### `tower_ember_spire.png`

`128 x 192`  ->  `res://art/towers/tower_ember_spire.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a slender tall stone spire capped with an open burning brazier, narrow iron banding, embers rising from the top
```

### `tower_pyre_cannon.png`

`128 x 192`  ->  `res://art/towers/tower_pyre_cannon.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a squat heavy siege cannon of blackened iron with a glowing fire-chamber, wide short barrel, mounted on a stone base
```

### `tower_rime_lance.png`

`128 x 192`  ->  `res://art/towers/tower_rime_lance.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a tall narrow tower of pale stone ending in a single frost-encrusted spear point, sheets of blue-white ice down one side
```

### `tower_hoarfrost_bell.png`

`128 x 192`  ->  `res://art/towers/tower_hoarfrost_bell.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a heavy stone frame holding a large frost-covered bronze bell, long icicles hanging from its rim
```

### `tower_bulwark.png`

`128 x 192`  ->  `res://art/towers/tower_bulwark.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a squat fortified stone bunker with layered overlapping shield plating, heavy and wide, almost no ornament, built to absorb
```

### `tower_shard_thrower.png`

`128 x 192`  ->  `res://art/towers/tower_shard_thrower.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a mechanical ballista of stone and iron loaded with a single long jagged rock shard, tensioned cables
```

### `tower_arc_coil.png`

`128 x 192`  ->  `res://art/towers/tower_arc_coil.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a metal tower wrapped in tiered copper coils, arcs of pale violet lightning crackling between the rings
```

### `tower_gale_turret.png`

`128 x 192`  ->  `res://art/towers/tower_gale_turret.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a slim tower with spinning bladed vanes and open wind funnels at its crown, motion blur on the blades
```

## 5.5 City — `res://art/city/`

### `city_base.png`

`512 x 512`  ->  `res://art/city/city_base.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 512px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a small fortified settlement built on a curved platform of vast bone and lashed timber, tiered stone buildings, banners, chimney smoke, defensive palisade around the rim, viewed from three-quarter above
```

### `city_damage_1.png`

`512 x 512`  ->  `res://art/city/city_damage_1.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 512px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: the same small fortified settlement, lightly ruined - scorch marks, one collapsed roof, torn banners, thin smoke, viewed from three-quarter above
```

### `city_damage_2.png`

`512 x 512`  ->  `res://art/city/city_damage_2.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 512px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: the same small fortified settlement, heavily ruined - several buildings burned down to their frames, the palisade breached, fires still burning, viewed from three-quarter above
```

### `city_damage_3.png`

`512 x 512`  ->  `res://art/city/city_damage_3.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 512px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: the same small fortified settlement, almost destroyed - mostly blackened rubble with only the town hall still standing, viewed from three-quarter above
```

### `building_town_hall.png`

`192 x 192`  ->  `res://art/city/building_town_hall.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a tiered stone hall with a heavy timber roof and a relic-socket frame above its door, banners on both sides
```

### `building_forge.png`

`192 x 192`  ->  `res://art/city/building_forge.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a squat stone forge with a glowing open furnace mouth, anvil outside, smoke stack
```

### `building_sanctum.png`

`192 x 192`  ->  `res://art/city/building_sanctum.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a narrow stone shrine with a burning bowl on a pedestal and hanging chains, ritual markings on the walls
```

### `building_granary.png`

`192 x 192`  ->  `res://art/city/building_granary.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a rounded timber and stone storehouse with sacks and barrels stacked outside, thatched roof
```

### `building_scavenging_post.png`

`192 x 192`  ->  `res://art/city/building_scavenging_post.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a low open-sided work yard of rough timber and hide awnings, sorting tables piled with salvaged scrap and bone, tool racks, a heavy chain post
```

### `building_watchtower.png`

`192 x 192`  ->  `res://art/city/building_watchtower.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a tall narrow timber and stone lookout tower with an open railed platform at the top, a hanging signal lantern and a mounted spyglass
```

### `plot_empty.png`

`192 x 192`  ->  `res://art/city/plot_empty.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: an empty flattened building plot of packed earth ringed by low foundation stones, a few survey stakes and coiled rope, nothing built on it
```

### `plot_locked.png`

`192 x 192`  ->  `res://art/city/plot_locked.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: an overgrown derelict building plot behind a barred timber palisade, chained gate, weeds and rubble, clearly sealed off
```

## 5.6 Beast — `res://art/beast/`

### `beast_profile.png`

`1024 x 512`  ->  `res://art/beast/beast_profile.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 1024px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: an immense ancient beast walking across a wasteland - part sea serpent, part armored turtle, part dinosaur - a long scaled neck and horned skull, a vast domed shell of stone and moss on its back carrying a small fortified city lashed down with chains, six heavy legs, seen in full side profile, colossal scale
```

## 5.9 Relic icons — `res://art/icons/relics/`

### `relic_01.png`

`128 x 128`  ->  `res://art/icons/relics/relic_01.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a cracked bone crown, an ancient ritual object, worn and weathered
```

### `relic_02.png`

`128 x 128`  ->  `res://art/icons/relics/relic_02.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a rusted iron heart, an ancient ritual object, worn and weathered
```

### `relic_03.png`

`128 x 128`  ->  `res://art/icons/relics/relic_03.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a sealed clay jar, an ancient ritual object, worn and weathered
```

### `relic_04.png`

`128 x 128`  ->  `res://art/icons/relics/relic_04.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a knotted cord of teeth, an ancient ritual object, worn and weathered
```

### `relic_05.png`

`128 x 128`  ->  `res://art/icons/relics/relic_05.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a shattered mirror shard, an ancient ritual object, worn and weathered
```

### `relic_06.png`

`128 x 128`  ->  `res://art/icons/relics/relic_06.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a blackened iron key, an ancient ritual object, worn and weathered
```

### `relic_07.png`

`128 x 128`  ->  `res://art/icons/relics/relic_07.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a wax-sealed scroll, an ancient ritual object, worn and weathered
```

### `relic_08.png`

`128 x 128`  ->  `res://art/icons/relics/relic_08.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a carved horn ring, an ancient ritual object, worn and weathered
```

### `relic_09.png`

`128 x 128`  ->  `res://art/icons/relics/relic_09.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a burnt feather, an ancient ritual object, worn and weathered
```

### `relic_10.png`

`128 x 128`  ->  `res://art/icons/relics/relic_10.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a river stone bound in wire, an ancient ritual object, worn and weathered
```

### `relic_11.png`

`128 x 128`  ->  `res://art/icons/relics/relic_11.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a tarnished silver bell, an ancient ritual object, worn and weathered
```

### `relic_12.png`

`128 x 128`  ->  `res://art/icons/relics/relic_12.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a bundle of splintered arrows, an ancient ritual object, worn and weathered
```

### `relic_13.png`

`128 x 128`  ->  `res://art/icons/relics/relic_13.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a cracked hourglass of black sand, an ancient ritual object, worn and weathered
```

### `relic_14.png`

`128 x 128`  ->  `res://art/icons/relics/relic_14.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a flensed animal skull, an ancient ritual object, worn and weathered
```

### `relic_15.png`

`128 x 128`  ->  `res://art/icons/relics/relic_15.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a coil of braided hair, an ancient ritual object, worn and weathered
```

### `relic_16.png`

`128 x 128`  ->  `res://art/icons/relics/relic_16.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a broken compass needle, an ancient ritual object, worn and weathered
```

### `relic_17.png`

`128 x 128`  ->  `res://art/icons/relics/relic_17.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a vial of dark oil, an ancient ritual object, worn and weathered
```

### `relic_18.png`

`128 x 128`  ->  `res://art/icons/relics/relic_18.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a chipped obsidian blade, an ancient ritual object, worn and weathered
```

### `relic_19.png`

`128 x 128`  ->  `res://art/icons/relics/relic_19.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a rusted shackle bolt, an ancient ritual object, worn and weathered
```

### `relic_20.png`

`128 x 128`  ->  `res://art/icons/relics/relic_20.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a folded leather map, an ancient ritual object, worn and weathered
```

### `relic_core_drowned_choir.png`

`128 x 128`  ->  `res://art/icons/relics/relic_core_drowned_choir.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a fused knot of singing bone mouths weeping black water, an ancient ritual object of great power, worn and weathered
```

### `relic_core_mirrorfang.png`

`128 x 128`  ->  `res://art/icons/relics/relic_core_mirrorfang.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a curved mirrored glass fang refracting amber light, an ancient ritual object of great power, worn and weathered
```

### `relic_core_rust_crown.png`

`128 x 128`  ->  `res://art/icons/relics/relic_core_rust_crown.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 128px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a jagged crown of corroded iron spires, an ancient ritual object of great power, worn and weathered
```

## 5.10 Spell icons — `res://art/icons/spells/`

### `spell_rift_step.png`

`96 x 96`  ->  `res://art/icons/spells/spell_rift_step.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 96px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a rough hand-drawn ritual sigil representing a torn slit in space with a figure stepping through it
```

### `spell_cinder_nova.png`

`96 x 96`  ->  `res://art/icons/spells/spell_cinder_nova.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 96px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a rough hand-drawn ritual sigil representing a bursting star of ember and ash radiating outward
```

### `spell_bulwark_ward.png`

`96 x 96`  ->  `res://art/icons/spells/spell_bulwark_ward.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 96px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a rough hand-drawn ritual sigil representing a domed protective barrier over a straight line
```

### `spell_marrow_drain.png`

`96 x 96`  ->  `res://art/icons/spells/spell_marrow_drain.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 96px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a rough hand-drawn ritual sigil representing a curved fang siphoning a spiral of light
```

### `spell_chain_hook.png`

`96 x 96`  ->  `res://art/icons/spells/spell_chain_hook.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 96px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a rough hand-drawn ritual sigil representing a barbed hook trailing a taut chain
```

### `spell_ash_veil.png`

`96 x 96`  ->  `res://art/icons/spells/spell_ash_veil.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 96px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a rough hand-drawn ritual sigil representing a drifting veil of ash concealing a silhouette
```

### `spell_tremor.png`

`96 x 96`  ->  `res://art/icons/spells/spell_tremor.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 96px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a rough hand-drawn ritual sigil representing concentric shockwave rings cracking outward from a point
```

### `spell_beasts_breath.png`

`96 x 96`  ->  `res://art/icons/spells/spell_beasts_breath.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 96px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a rough hand-drawn ritual sigil representing a cone of exhaled breath widening into a beam
```

## 5.11 UI icons — `res://art/icons/ui/`

### `ui_element_fire.png`

`64 x 64`  ->  `res://art/icons/ui/ui_element_fire.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a stylised flame
```

### `ui_element_water.png`

`64 x 64`  ->  `res://art/icons/ui/ui_element_water.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a stylised water droplet
```

### `ui_element_earth.png`

`64 x 64`  ->  `res://art/icons/ui/ui_element_earth.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a stylised faceted stone
```

### `ui_element_air.png`

`64 x 64`  ->  `res://art/icons/ui/ui_element_air.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a stylised swirling gust
```

### `ui_resource.png`

`64 x 64`  ->  `res://art/icons/ui/ui_resource.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a heap of salvaged scrap and bone
```

### `ui_blueprint.png`

`64 x 64`  ->  `res://art/icons/ui/ui_blueprint.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a rolled schematic scroll
```

### `ui_relic.png`

`64 x 64`  ->  `res://art/icons/ui/ui_relic.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a faceted ritual amulet
```

### `ui_war_horn.png`

`64 x 64`  ->  `res://art/icons/ui/ui_war_horn.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a curved war horn
```

### `ui_raid_charge.png`

`64 x 64`  ->  `res://art/icons/ui/ui_raid_charge.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a filling lightning-charged meter
```

### `ui_distance.png`

`64 x 64`  ->  `res://art/icons/ui/ui_distance.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a winding road vanishing to a point
```

### `ui_city_health.png`

`64 x 64`  ->  `res://art/icons/ui/ui_city_health.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a fortified gate tower
```

### `ui_pressure_arrow.png`

`64 x 64`  ->  `res://art/icons/ui/ui_pressure_arrow.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a bold directional arrow
```

### `ui_captive.png`

`64 x 64`  ->  `res://art/icons/ui/ui_captive.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a pair of iron shackles
```

### `ui_wave.png`

`64 x 64`  ->  `res://art/icons/ui/ui_wave.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: three advancing spear silhouettes
```

### `ui_upgrade.png`

`64 x 64`  ->  `res://art/icons/ui/ui_upgrade.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a chevron arrow pointing up
```

### `ui_build.png`

`64 x 64`  ->  `res://art/icons/ui/ui_build.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a mason's hammer and chisel
```

### `ui_pause.png`

`64 x 64`  ->  `res://art/icons/ui/ui_pause.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: two vertical pause bars
```

### `ui_settings.png`

`64 x 64`  ->  `res://art/icons/ui/ui_settings.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a toothed iron cog
```

### `ui_lock.png`

`64 x 64`  ->  `res://art/icons/ui/ui_lock.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a heavy closed padlock
```

### `ui_close.png`

`64 x 64`  ->  `res://art/icons/ui/ui_close.png`

```text
A 2D game UI icon.

VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One clear symbol, like a printed pictogram.

SIZE: this will be displayed about 64px. Thick bold shapes only - it has to read at thumbnail size. No thin lines, no small parts, no texture detail.

STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) for separation. Slight hand-painted texture is fine; gradients, gloss and realistic rendering are not.

FRAMING: the symbol centred and filling most of the frame. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a bold X cross
```

## 5.12 Combination towers — `res://art/towers/`

### `tower_firestorm.png`

`128 x 192`  ->  `res://art/towers/tower_firestorm.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a tower of blackened iron and stone with a cyclone of burning embers spiralling above its open crown, wind-torn flame, scorched banding
```

### `tower_magma.png`

`128 x 192`  ->  `res://art/towers/tower_magma.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a squat cracked-stone tower with molten rock glowing through its fissures, slow lava seeping down its base onto the ground
```

### `tower_steam_burst.png`

`128 x 192`  ->  `res://art/towers/tower_steam_burst.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a riveted copper and stone tower with pressure valves along its flanks venting thick white steam, condensation running down the metal
```

### `tower_blizzard.png`

`128 x 192`  ->  `res://art/towers/tower_blizzard.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a pale ice-sheathed tower with a swirling vortex of snow and violet lightning around its upper spire, frost spreading from its base
```

### `tower_glacier.png`

`128 x 192`  ->  `res://art/towers/tower_glacier.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a massive block of blue-white glacial ice fused around a stone core, thick frozen buttresses, deep internal cracks catching light
```

### `tower_quake.png`

`128 x 192`  ->  `res://art/towers/tower_quake.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a heavy megalith tower of stacked raw stone with shattered rock and dust erupting around its foundations, visible ground fracture rings
```

### `tower_conflagration.png`

`128 x 192`  ->  `res://art/towers/tower_conflagration.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a tall furnace-tower entirely engulfed in roaring fire, iron ribs glowing white-hot, a column of flame rising from its open top
```

### `tower_deep_freeze.png`

`128 x 192`  ->  `res://art/towers/tower_deep_freeze.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a jagged spire of solid black-blue ice, razor-sharp frozen shards radiating outward, air visibly frosting around it
```

### `tower_bastion.png`

`128 x 192`  ->  `res://art/towers/tower_bastion.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: an immense squat fortress block of layered granite and iron plating, utterly immovable, arrow slits and buttresses, no ornament
```

### `tower_tempest.png`

`128 x 192`  ->  `res://art/towers/tower_tempest.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 192px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a skeletal iron lattice tower crowned with a violent storm cloud, multiple violet lightning bolts branching outward simultaneously
```

## 5.13 Battlefield — `res://art/battlefield/`

### `build_spot.png`

`128 x 128`  ->  `res://art/battlefield/build_spot.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 128px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a circular stone foundation pad set into the ground, cut flagstones with an empty socket in the centre, faint carved markings around the rim, nothing built on it
```

### `build_spot_combo.png`

`128 x 128`  ->  `res://art/battlefield/build_spot_combo.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 128px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a circular stone foundation pad inscribed with a glowing violet binding sigil, two linked channels running to its edges, empty socket in the centre
```

### `town_core.png`

`384 x 384`  ->  `res://art/battlefield/town_core.png`

```text
A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.

CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper surfaces are the dominant part of the image; the walls are visible but foreshortened. This is NOT an eye-level architectural view and NOT concept art.

SIZE: this will be displayed about 384px tall in game. Bold readable masses, clear silhouette, no fine detail that would disappear at that size.

STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no photoreal rendering. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in the image. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a compact fortified keep of tiered stone with a banner mast, heavy gate and a low protective wall, seen from three-quarter above, the heart of a small settlement
```

## 5.14 Raid — `res://art/raid/`

### `chieftain_ashfen.png`

`256 x 256`  ->  `res://art/raid/chieftain_ashfen.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 256 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: an enormous bloated marsh warlord crowned with antlers and reeds, draped in waterlogged hides, carrying a heavy bone maul, black water streaming from its bulk
```

### `chieftain_saltglass.png`

`256 x 256`  ->  `res://art/raid/chieftain_saltglass.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 256 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a tall crystalline warlord of fused salt glass shards, a mirrored faceless head, jagged blade-limbs, refracting amber light
```

### `chieftain_steppe.png`

`256 x 256`  ->  `res://art/raid/chieftain_steppe.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 256 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a broad iron-plated nomad warlord in a horned rusted helm, layered scavenged armour, twin curved cleavers, torn clan banners on its back
```

### `captive_bogkin.png`

`128 x 128`  ->  `res://art/raid/captive_bogkin.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 128 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a defeated hunched swamp-dweller creature kneeling with its head bowed, heavy iron shackles on its wrists, moss and dead reeds hanging from its limbs
```

### `captive_glassborn.png`

`128 x 128`  ->  `res://art/raid/captive_glassborn.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 128 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a defeated crystalline salt-glass humanoid kneeling with its head bowed, heavy iron shackles on its cracked wrists, dulled fractured body
```

### `captive_steppehorde.png`

`128 x 128`  ->  `res://art/raid/captive_steppehorde.png`

```text
An isometric game character sprite, in the style of a top-down isometric action RPG.

VIEW - describe by what is visible, not by an angle. Degree instructions do not work on these models; a list of what the camera can and cannot see does:

  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, the tops of the feet.

  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles of the feet.

  - The head overlaps the chest because you are looking down onto it. The legs are short and foreshortened. The figure looks slightly squashed vertically, and that is correct.

POSE: standing upright and compact, weight settled, facing away from the viewer and slightly down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across the frame, NOT a dramatic action pose.

SIZE: displayed at about 128 pixels in game - roughly a thumbnail. Build it from large flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no rendered texture. If a detail would be under two pixels, leave it out.

STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic rendering, no gloss. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow.

FRAMING: one figure, centred, standing vertically and filling most of the square with a small even margin. Square 1:1. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a defeated nomad raider kneeling with its head bowed, heavy iron shackles on its wrists, stripped armour and torn cloth wrappings
```

## 5.15 UI frames — `res://art/ui/`

### `ui_panel.png`

`256 x 256`  ->  `res://art/ui/ui_panel.png`

```text
A 2D user-interface panel graphic for a game, built to be stretched.

VIEW: flat and front-on, no perspective, no camera angle.

CONSTRUCTION: symmetrical left-to-right and top-to-bottom, with a decorated border and a completely flat, empty, evenly-coloured centre. The centre must stay plain because it gets stretched - any pattern there will smear. Put nothing inside it.

STYLE: dark weathered stone and iron, muted and low contrast so text sits on top of it legibly. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow. Restrained - this is a frame, not a focal point.

FRAMING: the panel fills the whole image, edge to edge. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a rectangular dark stone and iron interface panel with a riveted border and worn corner brackets, flat empty centre, symmetrical, suitable for nine-slice stretching
```

### `ui_panel_dark.png`

`256 x 256`  ->  `res://art/ui/ui_panel_dark.png`

```text
A 2D user-interface panel graphic for a game, built to be stretched.

VIEW: flat and front-on, no perspective, no camera angle.

CONSTRUCTION: symmetrical left-to-right and top-to-bottom, with a decorated border and a completely flat, empty, evenly-coloured centre. The centre must stay plain because it gets stretched - any pattern there will smear. Put nothing inside it.

STYLE: dark weathered stone and iron, muted and low contrast so text sits on top of it legibly. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow. Restrained - this is a frame, not a focal point.

FRAMING: the panel fills the whole image, edge to edge. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a rectangular near-black stone interface panel with a thin recessed iron border, flat empty centre, symmetrical, suitable for nine-slice stretching
```

### `ui_button.png`

`256 x 64`  ->  `res://art/ui/ui_button.png`

```text
A 2D user-interface panel graphic for a game, built to be stretched.

VIEW: flat and front-on, no perspective, no camera angle.

CONSTRUCTION: symmetrical left-to-right and top-to-bottom, with a decorated border and a completely flat, empty, evenly-coloured centre. The centre must stay plain because it gets stretched - any pattern there will smear. Put nothing inside it.

STYLE: dark weathered stone and iron, muted and low contrast so text sits on top of it legibly. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow. Restrained - this is a frame, not a focal point.

FRAMING: the panel fills the whole image, edge to edge. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a wide horizontal dark iron button plate with bevelled edges and small corner rivets, flat empty centre, symmetrical, suitable for nine-slice stretching
```

### `ui_button_hover.png`

`256 x 64`  ->  `res://art/ui/ui_button_hover.png`

```text
A 2D user-interface panel graphic for a game, built to be stretched.

VIEW: flat and front-on, no perspective, no camera angle.

CONSTRUCTION: symmetrical left-to-right and top-to-bottom, with a decorated border and a completely flat, empty, evenly-coloured centre. The centre must stay plain because it gets stretched - any pattern there will smear. Put nothing inside it.

STYLE: dark weathered stone and iron, muted and low contrast so text sits on top of it legibly. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow. Restrained - this is a frame, not a focal point.

FRAMING: the panel fills the whole image, edge to edge. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: the same wide horizontal iron button plate lit with a warm amber inner glow along its bevelled edges, flat empty centre, symmetrical
```

### `ui_slot.png`

`96 x 96`  ->  `res://art/ui/ui_slot.png`

```text
A 2D user-interface panel graphic for a game, built to be stretched.

VIEW: flat and front-on, no perspective, no camera angle.

CONSTRUCTION: symmetrical left-to-right and top-to-bottom, with a decorated border and a completely flat, empty, evenly-coloured centre. The centre must stay plain because it gets stretched - any pattern there will smear. Put nothing inside it.

STYLE: dark weathered stone and iron, muted and low contrast so text sits on top of it legibly. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow. Restrained - this is a frame, not a focal point.

FRAMING: the panel fills the whole image, edge to edge. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a square recessed inventory socket of dark stone with a worn iron rim and an empty hollow centre, symmetrical
```

### `ui_bar_fill.png`

`64 x 16`  ->  `res://art/ui/ui_bar_fill.png`

```text
A 2D user-interface panel graphic for a game, built to be stretched.

VIEW: flat and front-on, no perspective, no camera angle.

CONSTRUCTION: symmetrical left-to-right and top-to-bottom, with a decorated border and a completely flat, empty, evenly-coloured centre. The centre must stay plain because it gets stretched - any pattern there will smear. Put nothing inside it.

STYLE: dark weathered stone and iron, muted and low contrast so text sits on top of it legibly. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow. Restrained - this is a frame, not a focal point.

FRAMING: the panel fills the whole image, edge to edge. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a small horizontal bar of solid warm amber-rust light with a soft inner glow, flat, seamless left to right, no border
```

### `ui_bar_back.png`

`64 x 16`  ->  `res://art/ui/ui_bar_back.png`

```text
A 2D user-interface panel graphic for a game, built to be stretched.

VIEW: flat and front-on, no perspective, no camera angle.

CONSTRUCTION: symmetrical left-to-right and top-to-bottom, with a decorated border and a completely flat, empty, evenly-coloured centre. The centre must stay plain because it gets stretched - any pattern there will smear. Put nothing inside it.

STYLE: dark weathered stone and iron, muted and low contrast so text sits on top of it legibly. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow. Restrained - this is a frame, not a focal point.

FRAMING: the panel fills the whole image, edge to edge. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: a small horizontal empty trough of dark recessed iron, flat, seamless left to right, no border
```

### `ui_logo.png`

`1024 x 256`  ->  `res://art/ui/ui_logo.png`

```text
A 2D user-interface panel graphic for a game, built to be stretched.

VIEW: flat and front-on, no perspective, no camera angle.

CONSTRUCTION: symmetrical left-to-right and top-to-bottom, with a decorated border and a completely flat, empty, evenly-coloured centre. The centre must stay plain because it gets stretched - any pattern there will smear. Put nothing inside it.

STYLE: dark weathered stone and iron, muted and low contrast so text sits on top of it legibly. Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, #D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper right against deep teal-black shadow. Restrained - this is a frame, not a focal point.

FRAMING: the panel fills the whole image, edge to edge. Fully transparent background - no ground, no cast shadow, no frame, no text, no border. Export as PNG with a true alpha channel.

SUBJECT: the words BEAST ROAD as a wide game logo wordmark in a heavy weathered carved-bone serif, amber and bone, a faint horned serpent silhouette behind the letters
```

---

# Midjourney prompts - opaque

Terrain tiles use `--tile` and should be checked by tiling them 2x2 before use.

## 5.7 Terrain tiles — `res://art/terrain/`

### `terrain_ashfen.png`

`512 x 512`  ->  `res://art/terrain/terrain_ashfen.png`

```text
seamless tileable top-down ground texture, dark marsh ground, pools of black standing water, pale dead reeds, ash-grey mud, sunken twisted roots, dark painterly grim-fantasy game art, hand-painted, muted desaturated palette, even lighting with no directional shadow, no objects casting shadow, no text --tile --ar 1:1 --s 150
```

### `terrain_saltglass.png`

`512 x 512`  ->  `res://art/terrain/terrain_saltglass.png`

```text
seamless tileable top-down ground texture, cracked salt flat, pale white-blue crystalline crust, thin fracture lines, scattered glassy shards, dark painterly grim-fantasy game art, hand-painted, muted desaturated palette, even lighting with no directional shadow, no objects casting shadow, no text --tile --ar 1:1 --s 150
```

### `terrain_steppe.png`

`512 x 512`  ->  `res://art/terrain/terrain_steppe.png`

```text
seamless tileable top-down ground texture, dry steppe hardpan, red-brown cracked earth, scattered rusted iron debris, sparse dead grass tufts, dark painterly grim-fantasy game art, hand-painted, muted desaturated palette, even lighting with no directional shadow, no objects casting shadow, no text --tile --ar 1:1 --s 150
```

## 5.8 Backdrops — `res://art/bg/`

### `macro_act1.png`

`1920 x 1080`  ->  `res://art/bg/macro_act1.png`

```text
a vast fog-drowned marsh valley stretching to the horizon, drowned trees, low grey mist, distant water, dark painterly grim-fantasy game art, hand-painted digital matte painting, visible brushwork, warm amber light against deep teal-black shadow, muted desaturated palette, heavy atmosphere, volumetric haze, no characters, no text, no UI --ar 16:9 --s 250
```

### `macro_act2.png`

`1920 x 1080`  ->  `res://art/bg/macro_act2.png`

```text
an endless cracked white salt desert under a bruised sky, distant glass formations catching light, heat shimmer, dark painterly grim-fantasy game art, hand-painted digital matte painting, visible brushwork, warm amber light against deep teal-black shadow, muted desaturated palette, heavy atmosphere, volumetric haze, no characters, no text, no UI --ar 16:9 --s 250
```

### `macro_act3.png`

`1920 x 1080`  ->  `res://art/bg/macro_act3.png`

```text
a red-brown iron steppe under a heavy dust sky, the ruined silhouette of an immense fortress on the far horizon, dark painterly grim-fantasy game art, hand-painted digital matte painting, visible brushwork, warm amber light against deep teal-black shadow, muted desaturated palette, heavy atmosphere, volumetric haze, no characters, no text, no UI --ar 16:9 --s 250
```

### `crossroad_bg.png`

`1920 x 1080`  ->  `res://art/bg/crossroad_bg.png`

```text
a fork in an ancient road at dusk, two paths diverging into different distant landscapes, weathered stone waymarker in the foreground, dark painterly grim-fantasy game art, hand-painted digital matte painting, visible brushwork, warm amber light against deep teal-black shadow, muted desaturated palette, heavy atmosphere, volumetric haze, no characters, no text, no UI --ar 16:9 --s 250
```

### `raid_arena_bg.png`

`1920 x 1080`  ->  `res://art/bg/raid_arena_bg.png`

```text
a hostile enemy warcamp seen from directly above, ringed by bone totems and burning braziers, packed dirt floor, tents at the edges, dark painterly grim-fantasy game art, hand-painted digital matte painting, visible brushwork, warm amber light against deep teal-black shadow, muted desaturated palette, heavy atmosphere, volumetric haze, no characters, no text, no UI --ar 16:9 --s 250
```

### `menu_key_art.png`

`1920 x 1080`  ->  `res://art/bg/menu_key_art.png`

```text
an immense ancient beast - part serpent, part turtle, part dinosaur - walking away across a wasteland at dusk with a small lit fortified city on its back, seen from behind and below, dramatic scale, cinematic key art, dark painterly grim-fantasy game art, hand-painted digital matte painting, visible brushwork, warm amber light against deep teal-black shadow, muted desaturated palette, heavy atmosphere, volumetric haze, no characters, no text, no UI --ar 16:9 --s 250
```

## 5.13 Battlefield — `res://art/battlefield/`

### `lane_path.png`

`256 x 256`  ->  `res://art/battlefield/lane_path.png`

```text
a trodden dirt road surface, packed earth rutted by cart wheels and footfall, scattered gravel, slightly darker than surrounding ground, dark painterly grim-fantasy game art, hand-painted digital matte painting, visible brushwork, warm amber light against deep teal-black shadow, muted desaturated palette, heavy atmosphere, volumetric haze, no characters, no text, no UI --ar 1:1 --s 250
```

## 5.15 UI frames — `res://art/ui/`

### `splash_studio.png`

`1920 x 1080`  ->  `res://art/ui/splash_studio.png`

```text
a plain dark textured background of deep teal-black with a faint warm amber glow in the centre, empty, no subject, minimal, for a studio logo to sit on top of, dark painterly grim-fantasy game art, hand-painted digital matte painting, visible brushwork, warm amber light against deep teal-black shadow, muted desaturated palette, heavy atmosphere, volumetric haze, no characters, no text, no UI --ar 16:9 --s 250
```

---

# Checklist

| # | File | Size | Tool |
|---|------|------|------|
| 1 | `build_spot.png` | 128 x 128 | ChatGPT |
| 2 | `build_spot_combo.png` | 128 x 128 | ChatGPT |
| 3 | `lane_path.png` | 256 x 256 | Midjourney |
| 4 | `town_core.png` | 384 x 384 | ChatGPT |
| 5 | `beast_profile.png` | 1024 x 512 | ChatGPT |
| 6 | `crossroad_bg.png` | 1920 x 1080 | Midjourney |
| 7 | `macro_act1.png` | 1920 x 1080 | Midjourney |
| 8 | `macro_act2.png` | 1920 x 1080 | Midjourney |
| 9 | `macro_act3.png` | 1920 x 1080 | Midjourney |
| 10 | `menu_key_art.png` | 1920 x 1080 | Midjourney |
| 11 | `raid_arena_bg.png` | 1920 x 1080 | Midjourney |
| 12 | `boss_drowned_choir.png` | 384 x 384 | ChatGPT |
| 13 | `boss_mirrorfang.png` | 384 x 384 | ChatGPT |
| 14 | `boss_rust_crown.png` | 384 x 384 | ChatGPT |
| 15 | `building_forge.png` | 192 x 192 | ChatGPT |
| 16 | `building_granary.png` | 192 x 192 | ChatGPT |
| 17 | `building_sanctum.png` | 192 x 192 | ChatGPT |
| 18 | `building_scavenging_post.png` | 192 x 192 | ChatGPT |
| 19 | `building_town_hall.png` | 192 x 192 | ChatGPT |
| 20 | `building_watchtower.png` | 192 x 192 | ChatGPT |
| 21 | `city_base.png` | 512 x 512 | ChatGPT |
| 22 | `city_damage_1.png` | 512 x 512 | ChatGPT |
| 23 | `city_damage_2.png` | 512 x 512 | ChatGPT |
| 24 | `city_damage_3.png` | 512 x 512 | ChatGPT |
| 25 | `plot_empty.png` | 192 x 192 | ChatGPT |
| 26 | `plot_locked.png` | 192 x 192 | ChatGPT |
| 27 | `elite_burrower.png` | 128 x 128 | ChatGPT |
| 28 | `elite_howler.png` | 128 x 128 | ChatGPT |
| 29 | `elite_warden.png` | 128 x 128 | ChatGPT |
| 30 | `enemy_bogkin.png` | 96 x 96 | ChatGPT |
| 31 | `enemy_glassborn.png` | 96 x 96 | ChatGPT |
| 32 | `enemy_steppehorde.png` | 96 x 96 | ChatGPT |
| 33 | `hero_ascended_1.png` | 128 x 128 | ChatGPT |
| 34 | `hero_ascended_2.png` | 128 x 128 | ChatGPT |
| 35 | `hero_base.png` | 128 x 128 | ChatGPT |
| 36 | `relic_01.png` | 128 x 128 | ChatGPT |
| 37 | `relic_02.png` | 128 x 128 | ChatGPT |
| 38 | `relic_03.png` | 128 x 128 | ChatGPT |
| 39 | `relic_04.png` | 128 x 128 | ChatGPT |
| 40 | `relic_05.png` | 128 x 128 | ChatGPT |
| 41 | `relic_06.png` | 128 x 128 | ChatGPT |
| 42 | `relic_07.png` | 128 x 128 | ChatGPT |
| 43 | `relic_08.png` | 128 x 128 | ChatGPT |
| 44 | `relic_09.png` | 128 x 128 | ChatGPT |
| 45 | `relic_10.png` | 128 x 128 | ChatGPT |
| 46 | `relic_11.png` | 128 x 128 | ChatGPT |
| 47 | `relic_12.png` | 128 x 128 | ChatGPT |
| 48 | `relic_13.png` | 128 x 128 | ChatGPT |
| 49 | `relic_14.png` | 128 x 128 | ChatGPT |
| 50 | `relic_15.png` | 128 x 128 | ChatGPT |
| 51 | `relic_16.png` | 128 x 128 | ChatGPT |
| 52 | `relic_17.png` | 128 x 128 | ChatGPT |
| 53 | `relic_18.png` | 128 x 128 | ChatGPT |
| 54 | `relic_19.png` | 128 x 128 | ChatGPT |
| 55 | `relic_20.png` | 128 x 128 | ChatGPT |
| 56 | `relic_core_drowned_choir.png` | 128 x 128 | ChatGPT |
| 57 | `relic_core_mirrorfang.png` | 128 x 128 | ChatGPT |
| 58 | `relic_core_rust_crown.png` | 128 x 128 | ChatGPT |
| 59 | `spell_ash_veil.png` | 96 x 96 | ChatGPT |
| 60 | `spell_beasts_breath.png` | 96 x 96 | ChatGPT |
| 61 | `spell_bulwark_ward.png` | 96 x 96 | ChatGPT |
| 62 | `spell_chain_hook.png` | 96 x 96 | ChatGPT |
| 63 | `spell_cinder_nova.png` | 96 x 96 | ChatGPT |
| 64 | `spell_marrow_drain.png` | 96 x 96 | ChatGPT |
| 65 | `spell_rift_step.png` | 96 x 96 | ChatGPT |
| 66 | `spell_tremor.png` | 96 x 96 | ChatGPT |
| 67 | `ui_blueprint.png` | 64 x 64 | ChatGPT |
| 68 | `ui_build.png` | 64 x 64 | ChatGPT |
| 69 | `ui_captive.png` | 64 x 64 | ChatGPT |
| 70 | `ui_city_health.png` | 64 x 64 | ChatGPT |
| 71 | `ui_close.png` | 64 x 64 | ChatGPT |
| 72 | `ui_distance.png` | 64 x 64 | ChatGPT |
| 73 | `ui_element_air.png` | 64 x 64 | ChatGPT |
| 74 | `ui_element_earth.png` | 64 x 64 | ChatGPT |
| 75 | `ui_element_fire.png` | 64 x 64 | ChatGPT |
| 76 | `ui_element_water.png` | 64 x 64 | ChatGPT |
| 77 | `ui_lock.png` | 64 x 64 | ChatGPT |
| 78 | `ui_pause.png` | 64 x 64 | ChatGPT |
| 79 | `ui_pressure_arrow.png` | 64 x 64 | ChatGPT |
| 80 | `ui_raid_charge.png` | 64 x 64 | ChatGPT |
| 81 | `ui_relic.png` | 64 x 64 | ChatGPT |
| 82 | `ui_resource.png` | 64 x 64 | ChatGPT |
| 83 | `ui_settings.png` | 64 x 64 | ChatGPT |
| 84 | `ui_upgrade.png` | 64 x 64 | ChatGPT |
| 85 | `ui_war_horn.png` | 64 x 64 | ChatGPT |
| 86 | `ui_wave.png` | 64 x 64 | ChatGPT |
| 87 | `captive_bogkin.png` | 128 x 128 | ChatGPT |
| 88 | `captive_glassborn.png` | 128 x 128 | ChatGPT |
| 89 | `captive_steppehorde.png` | 128 x 128 | ChatGPT |
| 90 | `chieftain_ashfen.png` | 256 x 256 | ChatGPT |
| 91 | `chieftain_saltglass.png` | 256 x 256 | ChatGPT |
| 92 | `chieftain_steppe.png` | 256 x 256 | ChatGPT |
| 93 | `terrain_ashfen.png` | 512 x 512 | Midjourney |
| 94 | `terrain_saltglass.png` | 512 x 512 | Midjourney |
| 95 | `terrain_steppe.png` | 512 x 512 | Midjourney |
| 96 | `tower_arc_coil.png` | 128 x 192 | ChatGPT |
| 97 | `tower_bastion.png` | 128 x 192 | ChatGPT |
| 98 | `tower_blizzard.png` | 128 x 192 | ChatGPT |
| 99 | `tower_bulwark.png` | 128 x 192 | ChatGPT |
| 100 | `tower_conflagration.png` | 128 x 192 | ChatGPT |
| 101 | `tower_deep_freeze.png` | 128 x 192 | ChatGPT |
| 102 | `tower_ember_spire.png` | 128 x 192 | ChatGPT |
| 103 | `tower_firestorm.png` | 128 x 192 | ChatGPT |
| 104 | `tower_gale_turret.png` | 128 x 192 | ChatGPT |
| 105 | `tower_glacier.png` | 128 x 192 | ChatGPT |
| 106 | `tower_hoarfrost_bell.png` | 128 x 192 | ChatGPT |
| 107 | `tower_magma.png` | 128 x 192 | ChatGPT |
| 108 | `tower_pyre_cannon.png` | 128 x 192 | ChatGPT |
| 109 | `tower_quake.png` | 128 x 192 | ChatGPT |
| 110 | `tower_rime_lance.png` | 128 x 192 | ChatGPT |
| 111 | `tower_shard_thrower.png` | 128 x 192 | ChatGPT |
| 112 | `tower_steam_burst.png` | 128 x 192 | ChatGPT |
| 113 | `tower_tempest.png` | 128 x 192 | ChatGPT |
| 114 | `splash_studio.png` | 1920 x 1080 | Midjourney |
| 115 | `ui_bar_back.png` | 64 x 16 | ChatGPT |
| 116 | `ui_bar_fill.png` | 64 x 16 | ChatGPT |
| 117 | `ui_button.png` | 256 x 64 | ChatGPT |
| 118 | `ui_button_hover.png` | 256 x 64 | ChatGPT |
| 119 | `ui_logo.png` | 1024 x 256 | ChatGPT |
| 120 | `ui_panel.png` | 256 x 256 | ChatGPT |
| 121 | `ui_panel_dark.png` | 256 x 256 | ChatGPT |
| 122 | `ui_slot.png` | 96 x 96 | ChatGPT |
