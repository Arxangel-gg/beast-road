# Twelve VFX and polish videos, triaged (2026-09-24)

The owner forwarded twelve YouTube videos - Godot 2D lighting, shaders, VFX and
"juice" tutorials - and asked for the best of them to be implemented, adapted or
rejected.

**How they were studied, stated plainly.** YouTube refuses transcripts to a
signed-out browser (`get_transcript` answers `FAILED_PRECONDITION`, the
timed-text track answers empty), so each video was read from its title, its
description, its auto-generated chapter list and its length, and the techniques
named there were checked against the code rather than against memory. Where a
row says *built*, the file that builds it is named.

## The short of it

Nearly everything these videos teach is already in Wilderhold - this is the
sixth forwarded batch in a row to be mostly a description of what ships. Two
things were genuinely missing and both are built:

1. **A screen bloom.** Four of the twelve lean on glow (the 48-second lighting
   short, MrEliptik's "World Environment" tip, Nuto Fx's electric effect, Single-
   Minded Ryan's 2D glow). The game had halos on flowers, pools on the ground and
   glowing seams, but nothing made a bright thing *bleed* light into the dark
   around it. See `color_grade.gdshader`.
2. **A branded boot splash.** MrEliptik's first tip, "no Godot icon". The icon
   was the game's own; the boot splash - the first thing a player sees - was
   Godot's default. See `project.godot`, `application/boot_splash`.

## Video by video

| # | Video | What it teaches | Here |
|---|---|---|---|
| 1 | *Give me 48 seconds ... 2D light & shadow* (Single-Minded Ryan, 0:48) | PointLight2D, LightOccluder2D, shadow filtering | **Built.** `LightKit.enable_shadows`, `ShadowKit.add_caster` - torches and the town throw tower shadows across the road |
| 2 | *Foliage Wind Effect with Visual Shader* (Single-Minded Ryan, 3:44) | Vertex sway anchored at the root | **Built, and further.** `Foliage` sway material driven by the replicated wind vector (`RunState.wind`), trample, per-kind stiffness |
| 3 | *How Games Make VFX* (PlayWithFurcifer, 5:45) | Water from scrolling noise, distortion, foam | **Built.** `pond_water.gdshader` - glints, rings, caustics, shore foam; `flood_sheen.gdshader` refracts the frame beneath |
| 4 | *2D Electric Lightning Shader* (Le Lu, 24:02) | Bolt texture, scrolling shader, sparks, flare | **Built**, and now glows: the chain shot's jagged ribbon and motes (`projectile.gd`, `Shot.CHAIN`), the earth's lightning, forge sheets. The bloom is what the flare stage of the tutorial adds |
| 5 | *Godot 2d Fx-Electric* (Nuto Fx, 0:14) | Shader + particles + **glow** | Glow was the gap → **the bloom** |
| 6 | *Projectiles VFX (FIRE BALL)* (Le Lu, 40:32) | Head, inner ball, static and dynamic trails, sparks | **Built.** `projectile.gd` trail and filament `Line2D`s, shot styles, per-breed enemy shot heads (`EnemyShotData.head`) |
| 7 | *How to make VFX in Godot* (Brackeys, 41:49) | Layers, flipbooks, shockwave, debris, blend modes, premultiplied alpha, audio with VFX | **Built.** The forge's flipbook sheets (`Vfx.forge_play`), layered element hits (`Vfx.impact`), tower rubble, quake slabs, positional audio (`Sfx.play_at`) |
| 8 | *6 Essential Godot 2D Effects* (Single-Minded Ryan, 35:44) | Blink, camera shake, hit particles, dissolve, scanline, outline | **All built.** Impact rim (`actor_polish`), `camera_impact`, `Vfx.impact`, `state_dissolve` / `stone_dissolve`, `ui_hologram` scanlines, the four-sample outline |
| 9 | *BETTER 2D visuals in 7 EASY TIPS* (MrEliptik, 10:38) | No Godot icon, colour palette, world environment, good camera, lights, particles, animate everything | Icon **built**; boot splash was the gap → **built**. Palette → `tools/palette_sheet.py` (2026-09-23). World environment: grade built, glow was the gap → **the bloom**. Camera: follow, lean at the mouse, distance-weighted shake - built. Lights, particles, idle breathing, tweens everywhere - built |
| 10 | *3 Essential Godot 4.5 Effects* (Single-Minded Ryan, 14:52) | Y-sort, foliage wind, 2D glow shader | Y-sort and wind **built**; glow → **the bloom** |
| 11 | *Hits and Impacts Effect* (Gabriel Aguiar, 14:42) | Flash, flare, shockwave, sparks as layers | **Built.** `Vfx.impact` per element: flash, forge hit sheet, sparks, ring |
| 12 | *Common VFX Shader Techniques* (onetupthree, 7:07) | Tiling/offset, masking, distortion, erosion, polar coordinates, depth fade, lifetime | **Built** as authoring: the forge (`tools/vfx_forge/forge_kit.py`) is polar coordinates, erosion by age and masks. **Depth fade rejected** - it is a 3D soft-particle technique and a 2D canvas has no depth buffer to fade against |

## The bloom, and its bounds

A bloom is the classic way to make a game look expensive, and the classic way to
make it look like 2009. What keeps this one on the right side:

- **It is the night's, mostly.** The threshold falls as the dark rises
  (`BLOOM_THRESHOLD_DAY` → `_NIGHT`), so by day only what is genuinely brighter
  than a sunlit field blooms and the field does not haze; at night every torch,
  flame, spell, spark, glowing seam and lit tower bleeds into the dark around it,
  which is the Core Keeper look from the previous triage arriving from a second
  direction.
- **One pass, no new copy.** It lives inside the colour grade's existing full-
  screen pass and reads the screen's own mip chain - measured working on the
  Compatibility renderer this game ships on (`tools/bloom_probe.gd`) - so it
  costs a mip generation and three taps rather than a second screen read.
- **A look, never a fact.** Nothing reads it; `Graphics.KEY_BLOOM` turns it off
  with no number moving, and it is off by default on the Low preset.
- **The interface is not bloomed**: the grade sits under the HUD.

## Rejected

- **Depth fade** (#12): 3D only.
- **A WorldEnvironment glow** (the route in #1, #5, #9): the Compatibility
  renderer's 2D glow is not the path this game's post-processing already takes,
  and a second full-screen pass beside the grade would be two reads of one frame.
  The same result inside the pass that exists.
- **Visual-shader authoring** (#2, #4, #10): the videos build in the visual shader
  editor; this project writes shaders as text so they can be grepped, gated and
  reviewed. Same maths, different editor.
