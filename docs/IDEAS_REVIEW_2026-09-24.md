# Twelve VFX and polish videos, studied from their transcripts (2026-09-24)

The owner forwarded twelve YouTube videos - Godot 2D lighting, shaders, VFX and
"juice" tutorials - and asked for the best of them to be implemented, adapted or
rejected, then asked for the transcripts to be obtained properly rather than
inferred.

## How the transcripts were obtained

An earlier pass read only titles, descriptions and chapter lists, because
YouTube refuses transcripts to a signed-out browser. This pass has the words:

- **Nine** from YouTube's own caption tracks via `yt-dlp` - four written by the
  creator (Furcifer, onetupthree, and Single-Minded Ryan's two longer top-down
  videos), five auto-generated.
- **Two** transcribed locally with Whisper (`medium.en` on the GPU, under two
  minutes): *6 Essential Godot 2D Effects*, which has no captions at all, and
  the 48-second lighting short, whose auto-captions YouTube had misdetected as
  Arabic.
- **One**, the 14-second electric clip, has no speech (Whisper: 0 segments) and
  was studied from a contact sheet of its frames.

About 30,000 words. Every technique below was then checked against the code by
reading it, with the file and line named, because this project has twice
triaged something as missing that already existed under another name.

## The short of it

Nearly everything these twelve videos teach already ships in Wilderhold, and in
several places the shipped version is the stronger one - the camera shake is a
modelled thunder-and-rumble rather than sampled noise, the impacts are layered
per element, the hits are felt by what they land on. Three things were genuinely
missing and all three are built:

1. **Bloom** (`color_grade.gdshader`): four of the twelve lean on glow and the
   game had none. Inside the grade's existing pass, off the screen's mip chain,
   weighted toward night.
2. **A branded boot splash** (`project.godot`): the first thing a player saw was
   Godot's logo. It is the studio splash's own dark now.
3. **A real light at a big blow** (`Vfx.light_burst`): Brackeys animates a
   light with every explosion and Le Lu puts one at the lightning strike; the
   game's `flash_at` is an additive polygon that lights nothing. A meteor, a
   strike, a boss slam and a dragon's breath now throw a capped, decaying
   `PointLight2D` - which, with the towers shading by light direction since
   this morning, lights the towers round a meteor from the side it fell on.

One thing was refused on purpose and is recorded below: acceleration and friction
on the Warden's walk.

## Video by video

### 1. *Give me 48 seconds ... 2D light & shadow* (Single-Minded Ryan, 0:48)

Whisper transcript. Add a `PointLight2D` to the player with a radial gradient
texture, make it big, raise the energy, colour it, enable shadows; add an
occlusion layer to the tileset and paint occlusion polygons; darken the
background and the player sprite so the light reads; PCF13 filter and smooth 1
for soft shadows.

| technique | here | verdict |
|---|---|---|
| point light with a generated radial texture | `LightKit.falloff_texture`, five-stop inverse-square falloff | built |
| shadows off occluders | `LightKit.enable_shadows`, `ShadowKit.add_caster` on towers, the shadow filter from `Graphics.shadow_filter` | built |
| darken the scene so lights read | `DayNight` tint to 0.15 at deep night, torches widened to match (CLAUDE.md, 2026-09-12) | built |
| painted tileset occlusion | not applicable - the road's occluders are per structure, not per tile | n/a |

### 2. *Foliage Wind Effect with Visual Shader* (Single-Minded Ryan, 3:44)

Vertex sway: mask by the UV's green channel remapped so the stump stays still,
multiply the vertex x by the mask and a swing value, drive the swing by
`sin(TIME * rate)`, and make the rate a **per-instance** shader parameter set to
a random float in `_ready` so no two trees are in step.

| technique | here | verdict |
|---|---|---|
| vertex sway masked at the root | the foliage sway material (`Foliage`, `ParallaxScatter.sway_material`) | built |
| per-instance random phase | every plant has its own clock (CLAUDE.md, 2026-09-12) | built |
| wind as the driver | `RunState.wind`, replicated, leaning every plant (2026-09-15) | built, further |

### 3. *How Games Make VFX* (PlayWithFurcifer, 5:45)

Creator captions. Water is "all just noise": a noise texture scrolled by
`TIME * scroll` on the UV; read the screen behind through `screen_texture` at
`SCREEN_UV` and offset it by the noise for refraction; a second noise scrolled
differently and multiplied for overlapping waves; a tint colour and a separate
top-light colour on the crests; "fiddle until it looks good"; fire, poison and
lasers are the same trick mapped to a gradient on particles.

| technique | here | verdict |
|---|---|---|
| scrolling noise water with crests | `pond_water.gdshader` - glints, rings, caustics, shore foam | built |
| refraction of what is beneath | `flood_sheen.gdshader` (`hint_screen_texture`), `quake_ripple.gdshader` | built |
| scrolled noise through a gradient for fire | the forge's sheets (`tools/vfx_forge`) are that, rendered once | built |

### 4. *2D Electric Lightning Shader* (Le Lu, 24:02)

Draw a seamless bolt texture, blur a copy for glow, erode it with a
morphological filter. A `Line2D` in stretch mode wearing a canvas shader: UV
panning by `TIME * speed`, one channel only, a `smoothstep` "vanishing value"
that erodes the bolt in and out, a colour multiplied in HDR (1.8, 1.2, 0.22),
additive blend. Sparks: 15 particles from a ring of radius 50, stretched along
velocity (align Y), radial velocity 500-700, additive, HDR colour. A flare: one
particle scaling small-big-small over 0.15 s. A `PointLight2D` at the impact
with the glow texture, energy 3, tweened to 0. An `AnimationPlayer` for start and
end.

| technique | here | verdict |
|---|---|---|
| jagged bolt ribbon | `projectile.gd` chain shot (`Shot.CHAIN`, `PROJECTILE_CHAIN_JITTER`), the earth's strike in `sky.gd` | built |
| sparks stretched along their flight | `Vfx.spark` - `Line2D` shards with a spark head (383-460) | built |
| flare at the strike | `Vfx.flash_at` at 62 and 70 units, twice (`sky.gd` 392-394, 421) | built |
| **a light at the impact** | was missing → `Vfx.light_burst` at the strike (`sky.gd`) | **built** |
| erosion-style appear/vanish on the bolt | the bolt fades by alpha | deferred - a look; the bloom does more for it |

### 5. *Godot 2d Fx-Electric* (Nuto Fx, 0:14, no speech)

From the frames: a soft glowing halo that swells and shrinks every frame, with
short bright jagged arcs snapping off it at random angles, one or two at a
time.

| technique | here | verdict |
|---|---|---|
| pulsing halo with random arcs | `TowerData.Ambient.SPARKS` (`tower_aura.gd` 54), the chain shot's crackle; the bloom now gives the halo its bleed | built |

### 6. *Projectiles VFX (FIRE BALL)* (Le Lu, 40:32)

A half-sphere head with scrolling noise masked by a vertical gradient (clamped
so the subtraction cannot go negative), UV panning by `TIME * speed`; an inner
ball with an inverted Fresnel; a ribbon trail with a scrolling seamless texture
and an HDR gradient yellow→red→transparent, alpha multiplied in; small sparks
emitted backward, aligned to velocity; a dynamic trail plugin for curved
flight.

| technique | here | verdict |
|---|---|---|
| a hot head with a core | the shot body plus `_light` on every projectile (`projectile.gd` 57, 165), `EnemyShotData.head` | built |
| a gradient ribbon trail that tapers and fades | `_trail` with `width_curve` and `Gradient` (`projectile.gd` 104-132) | built |
| sparks shed backward | the motes (`_mote_left`, `_spark_mote`) | built |
| a trail that bends with the flight | the trail is the path the node flew | built |
| a 3D mesh head | not applicable in 2D | n/a |

### 7. *How to make VFX in Godot* (Brackeys, 41:49)

Layers: fire, smoke, sparks, debris, shockwave, a light, sound, an animation
player to time them. The process material's three categories (spawn, display,
animated velocity/accelerations); curves and colour ramps over lifetime;
explosiveness and one-shot; `make unique (recursive)` pitfalls; sparks as
spikes aligned to velocity; a shockwave as one particle expanding and fading;
debris that collides and lingers; a wind-up before the blast; an omni light
that flares and fades "to tie the effect into the world"; billboards, random
start rotation, add vs mix blend, flipbooks, z-fighting offsets, premultiplied
alpha to blend fire into smoke in one system; restart/emitting from script;
spawning and freeing effect scenes; audio on the effect; pre-process for
ambient systems; local coords; rain at terminal velocity with impact
sub-emitters.

| technique | here | verdict |
|---|---|---|
| layered impacts (flash, shock, sparks, debris) | `Vfx.impact` per element, `forge_hit`, `Vfx.ring`, `Vfx.spark` | built |
| flipbook sheets | the forge catalogue, 24 effects, played by `Vfx.forge_play` | built |
| random start rotation and flips | `forge_play` turns, flips and wanders each play | built |
| add for fire, mix for smoke | additive materials on flames and forge sheets | built |
| a wind-up before a blast | every telegraph (`Vfx.ring` at the blow's own radius) | built |
| **a light that flares with the explosion** | was missing → `Vfx.light_burst` at the meteor and the boss slam | **built** |
| debris that lingers | `Tower._leave_rubble`, quake slabs, `FallingRock` | built |
| audio on the effect | positional `Sfx.play_at` on every blow | built |
| pre-process for ambient emitters | `ambient_life.gd` 311, `camp_fire.gd` 131 | built |
| rain at terminal velocity, impacts on the ground | `weather_veil.gdshader` - drops and impact rings (46, 128) | built |
| premultiplied alpha fire→smoke | not needed: fire and smoke are separate sheets | rejected |
| GPU particle collision, sub-emitters, billboards, z-fighting | 3D or not applicable | n/a |

### 8. *6 Essential Godot 2D Effects* (Single-Minded Ryan, 35:44)

Whisper transcript. Blink: `mix(colour, blink_colour, intensity * alpha)`,
tweened 1→0 over 0.5 s, material `local_to_scene` so two enemies do not blink
together. Camera shake: `FastNoiseLite.get_noise_1d(time) * intensity` on the
camera offset, intensity tweened 5→1 over 0.5 s. Hit particles: 20, one-shot,
explosive, sphere spawn, directional velocity away from the bullet, damping and
gravity, scale randomness, alpha ramp to zero. Dissolve: a noise mask against a
threshold, `SCREEN_UV` for the noise so animated frames do not flicker, a
bright lining just outside the threshold. Scanline: `sin(UV.y * 300 + TIME *
20)` mixed by alpha, with a slow fade. Outline: the alpha shifted in four
directions by `width * TEXTURE_PIXEL_SIZE`, summed with the original.

| technique | here | verdict |
|---|---|---|
| blink on hit | `HIT_FLASH_TIME`/`HIT_FLASH_COLOUR` (`enemy.gd` 2522, 3526) - per body, not per material | built |
| camera shake | `camera_rig.gd` `_tick_shake` - a thunder shove and a rumble whose pitch climbs, frame-rate independent | built, stronger |
| hit particles | `Vfx.impact`, `Vfx.spark` | built |
| dissolve with a lit edge | `state_dissolve` and `dissolve_colour` (`actor_state.gdshaderinc` 195-208) | built |
| scanline | `ui_hologram.gdshader`, `title_hologram.gdshader` - the interface's; a sci-fi scanline on a body is the wrong game | built where it belongs |
| outline | `actor_polish.gdshader`'s four-sample outline | built |

### 9. *BETTER 2D visuals in 7 EASY TIPS* (MrEliptik, 10:38)

No Godot icon (use `Polygon2D` for prototypes); a colour palette from Lospec;
a `WorldEnvironment` in canvas mode with tone mapping and glow, "sparingly - if
everything glows nothing does"; a good camera - lean toward the mouse by the
mouse's offset over half the screen, smoothing, screen shake scaled by how often
the action happens (none for walking, small for shooting, big for dying); lights
with shadows off occlusion polygons; particles everywhere, even in the UI;
animate everything - lerp velocity with separate acceleration and friction,
tween button scale on hover, curves.

| technique | here | verdict |
|---|---|---|
| no Godot icon | `config/icon` is the game's; the boot splash was Godot's → fixed | built |
| a palette | `tools/palette_sheet.py` (2026-09-23) | built |
| glow | the bloom, gated to the dark so the day does not haze | built |
| camera lean and smoothing | `camera_rig.gd` 7-9 (its own exponential smoothing so lean and shake compose) | built |
| shake by how often the action happens | `camera_impact` weighted by what the blow removed and its distance | built |
| lights, particles, tweens everywhere | throughout | built |
| **acceleration and friction on the walk** | `hero.gd` 592 sets velocity from input directly | **refused** - see below |
| button scale on hover | `ui_juice.gd` 417 - pivoted and offset rather than scaled, on purpose | built, differently |

**Why the walk stays instant.** Every telegraph in this game is answered by
stepping out of a circle, and the Warden is clamped, shoved, dashed and
knocked; a walk that takes a tenth of a second to start is a tenth of a second
less to leave a slam's ring, and a hundred gates measure travel. The weight the
tip is after is already on the feet (`Footfalls`) and in the gait. If this is
ever wanted it is one `move_toward` in `hero.gd` and a pass over every gate that
walks the Warden.

### 10. *3 Essential Godot 4.5 Effects* (Single-Minded Ryan, 14:52)

Creator captions. Y-sort on the parent, with the sprite offset upward so the
node's origin sits at the feet; the wind shader (as video 2); glow via HDR 2D and
a `WorldEnvironment` on Forward+, masking one colour (the sword's highlight) by
colour difference within a tolerance and multiplying it past 1 so only that
glows.

| technique | here | verdict |
|---|---|---|
| Y-sort by the feet | the `Sorted` layer; `Hero._ready` shifts the body onto its feet; `TOWER_SORT_LIFT` | built |
| wind | as video 2 | built |
| selective glow | the bloom's threshold does the selecting; Forward+ and HDR 2D are not available on the Compatibility renderer this game ships on | built, adapted |

### 11. *Hits and Impacts Effect Tutorial* (Gabriel Aguiar, 14:42)

Four layered one-shot particle systems: a flash (one particle, 0.1-0.2 s,
shrinking, HDR orange, alpha ramp), a flare (a cross of two flattened circles
with a glow, held then faded), a shockwave (a ring, expanding, alpha 0.1), sparks
(20, explosive, spread 180, stretched along velocity by a scale curve, HDR).
Textures made procedurally in Material Maker.

| technique | here | verdict |
|---|---|---|
| flash, flare, shockwave, sparks as layers | `Vfx.impact` - the element's flash, `forge_hit` sheet (the steel hit is a hard star), `Vfx.ring`, `Vfx.spark` | built |
| procedural effect textures | the forge (Blender headless) | built |

### 12. *Common VFX Shader Techniques* (onetupthree, 7:07)

Creator captions. Tiling and offset (`UV * tiling + offset`, offset by time);
masking by a greyscale texture on alpha, `UV.r`/`UV.g` as gradients; distortion
by adding a noise sample to the UV; erosion by `smoothstep(min, min + offset,
noise)`; polar coordinates (`atan(uv.y, uv.x) / TAU` and `length`) to unwrap
radially; depth fade; particle lifetime from `INSTANCE_CUSTOM.y` driving curves.

| technique | here | verdict |
|---|---|---|
| tiling/offset, masking, distortion, erosion, polar coordinates | `tools/vfx_forge/forge_kit.py` - `phase`, `band`, `grain`, radial coordinates, erosion by age | built as authoring |
| lifetime-driven curves | a forge frame's age | built |
| depth fade | a 3D soft-particle technique; a 2D canvas has no depth buffer | rejected |

## Rejected, with reasons

- **Depth fade** (#12): 3D only.
- **A `WorldEnvironment` glow with HDR 2D** (#9, #10): needs Forward+; this
  game ships on the Compatibility renderer for the web build. The bloom lives in
  the pass that exists instead.
- **Premultiplied-alpha fire-to-smoke** (#7): the forge's sheets are separate
  fire and smoke; nothing here blends them in one emitter.
- **Scanlines on bodies** (#8): a sci-fi read on a painted world. The interface
  keeps its holograms.
- **Acceleration and friction on the walk** (#9): control precision, above.
- **Visual-shader authoring** (#2, #4, #8, #10): the videos build in the node
  editor; this project writes shaders as text so they can be grepped and gated.
  Same maths.
- **Polygon2D placeholders** (#9): every sprite here is painted.

## Deferred

- **Erosion-style appear and vanish on the lightning bolt** (#4): a look on a
  ribbon that already crackles and now blooms. Worth a photograph before it is
  worth a shader.
- **Particles on the interface's buttons** (#9, Franz Fury): the holograms
  answer a hover already; motes on a focused button are a taste question for the
  owner.
