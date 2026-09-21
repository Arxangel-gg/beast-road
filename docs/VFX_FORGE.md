# The VFX forge — stylised effect sheets out of Blender

A design note, not a built system. Blender **4.5** is installed. Written
2026-09-21 after the owner forwarded a technique (Good Good, TikTok) for
stylised effects in geometry and shader nodes.

---

## 1. What the technique actually is

Not a fluid simulation. **A small, fixed set of nodes, reused for everything**:

1. **Scene Time → Map Range → Float Curve.** Turns the frame number into a
   normalised 0–1 value with authored easing. This is the animation driver, and
   everything downstream reads it.
2. **Color Ramp** on that value to offset one layer's start and end within the
   same range, so several layers of one effect stagger without separate clocks.
3. **Noise or Voronoi → Map Range set to Greater Than / Less Than.** A hard
   threshold that turns a smooth texture into a **sharp-edged mask**. This is
   the whole stylisation: graphic shapes rather than soft gradients.
4. **Mix Color (Linear Light) into the texture mapping** to roughen the mask's
   edge so it reads as drawn rather than as a clean cut.
5. **Store the timing as an attribute (`age`)** in geometry nodes and read it in
   the material, so the mask animates over the effect's life.
6. **Swirls**: centre the texture mapping, then multiply a gradient into
   rotation so it increases toward the middle. The cheap round gradient comes
   from Generated coordinates through a Separate XYZ; Combine XYZ with the scene
   time gives an animated swirl.
7. **Shader**: emission, mask drives alpha, a contrasting colour mixed into the
   back faces. Then layer until it looks right.

---

## 2. Why this fits Wilderhold, where a fluid sim would not

- **It is emission plus an alpha mask.** That is precisely how this game already
  draws effects — additive, feathered, colour per vertex. `Vfx`, `BloodInk`, the
  ring telegraphs and the set aura are all that shape. A smoke or fire
  simulation would arrive photoreal and look like a different game, which is the
  failure the gear icons already paid for.
- **Hard-thresholded masks are the house style.** Shockwave rings, the vault's
  rune circle, the burst — all graphic shapes with a defined edge.
- **It is frame-count driven by construction.** Set the range to sixteen frames
  and sixteen frames is exactly what renders. A sheet falls out of it.
- **Every frame is coherent.** The whole class of repair this project keeps
  paying for — masonry drifting a pixel, foundation pebbles re-invented, feet
  wandering off the ground line, the animator inventing bright blobs,
  `tools/lock_tower_frames.py` existing at all — **does not occur**, because the
  frames are evaluations of one graph rather than independent generations.
- **The camera is set once.** Orthographic, at Wilderhold's own front-on
  slight-top-down angle, and every effect obeys it instead of an argument with a
  prompt about isometry.
- **Colour is one input.** One effect definition emits fire, water, earth and
  air variants from the same graph. Today `TowerData.shot_tint` recolours shared
  effects by hand.

**And the decisive property: it is a node graph, which means it is code.**
`bpy` can build node groups and links programmatically, so the forge is a Python
library rather than a folder of `.blend` files somebody has to open. That is the
same shape as `install_pond_tiles.py`, `lock_tower_frames.py` and the rest of
`tools/`.

---

## 3. The dividing line — which effects may become sheets

**This is the design decision in the whole document, and it is not negotiable.**

> **A sheet is allowed when the effect's size is fixed. An effect whose size is
> a gameplay number stays procedural.**

The game already learned this and wrote it down: *"The telegraph is built from
the damage's own numbers. `Vfx.ring` is drawn at exactly the radius the strike
will use, over exactly the delay before it lands, so the tell and the blow
cannot disagree about where or when."* A pre-rendered sprite cannot be drawn at
exactly the radius a particular blow will use; scaling it up is a lie about the
blast, and scaling it down is a lie about the reach.

**Eligible for sheets** (fixed size, pure decoration):
- Spell impact flourishes — nova, ward, beam terminus, meteor bloom
- Per-element tower shot impacts
- The five enemy shot signatures — bolt, spray, lob, lance, hex
- Rift and dungeon portals, the vault rune circle's flare
- Level-up, gear-drop rarity bursts, set-aura motes
- Boss slam *impact* (not its telegraph)
- Wrath dressing: quake dust, funnel debris, meteor trail

**Must stay procedural** (size is a fact):
- Every range ring and targeting tell — drawn at the tower's own reach
- Every ground telegraph — drawn at the strike's own radius over its own delay
- Blood, footfall scuffs, ground marks — laid at the body's own footprint
- The fog, the minimap, anything read off world geometry

---

## 4. The forge, as a tool

`tools/vfx_forge/` — a Python package driven headless:

    blender --background --python tools/vfx_forge/render.py -- <effect_id>

**Primitives** (the "five nodes", each a function returning a node group):
`timing(frames, easing)`, `sharp_mask(texture, threshold, roughness)`,
`swirl(rate, falloff)`, `emit(colour, back_colour)`, `age_attribute()`.

**An effect is a declarative file**, not a `.blend`: layers, each naming a
primitive, its parameters and its slice of the timeline. Adding an effect means
adding a file — working rule 3, applied to art.

**Render settings, fixed and shared:**
- Orthographic camera at the game's own angle
- `Film > Transparent`, RGBA PNG
- No anti-aliasing beyond one sample tier, so edges stay graphic
- Power-of-two frame cells, packed left to right, single row
- Output to the manifest path derived from the effect id, exactly as every other
  asset path in this project is

**Colour is a parameter**, so one definition yields the four elemental variants
from one graph and they cannot drift apart.

---

## 5. What has to be proven before it is built

**Style match, judged by photograph and by nothing else.** No gate can see a
palette. The test is the one that caught the gear icons: a contact sheet with
the new effect beside the shipped burst, ripple and splash, looked at by a
person. If it reads as the same game, build the tool; if not, an afternoon was
spent.

**Pilot exactly one effect.** One impact burst, four elemental colours, sixteen
frames. Not a pipeline.

**Budget discipline.** The game already carries a frame with no headroom
(16.6 ms on a 3070 Ti) and a large download. A sheet is texture memory that a
triangle array is not, so: **one sheet tinted per element, never four sheets**,
and every sheet declared in `docs/ASSET_MANIFEST.md` at its exact dimensions
like every other asset.

**The decoration bound is unchanged.** A sheet effect must still be scaled away
by `Graphics.particle_scale()`, damped by `JuiceDirector` as COSMETIC, read by
nothing, and leave the run byte-identical when it is off.

---

## 6. When to do it

**Not on the critical path.** Music, enemy variety and playtesting are what gate
1.0, and none of them is this.

**But it is the right thing to do while those are gated on the owner.** Music
generation, campaign play-throughs and outside testing are all owner time; the
forge is a self-contained tool that can be built in parallel without touching
the game's code. That is its slot.
