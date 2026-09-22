# The VFX forge — stylised effect sheets out of Blender

Written 2026-09-21 after the owner forwarded a technique (Good Good, TikTok)
for stylised effects in geometry and shader nodes. **Built the same day, as
the pilot §5 asks for**: `tools/vfx_forge/forge.py` drives Blender 4.5
headless through `render.py`, renders one effect as a single-row sheet and
writes it to `game/art/vfx/forge_<effect>.png`; `Vfx.forge_burst` plays it
tinted; `forge_check` holds the sheet, the player and the decoration bound;
`forge_shot` photographs it beside the painted burst. One effect so far - the
burst - at the enemy shot impact, the boss slam and the tower shot impact.

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

**Built, and it is three things**: a Python package, a command line, and a
window.

    python tools/vfx_forge/forge.py list           # what exists
    python tools/vfx_forge/forge.py burst          # one effect
    python tools/vfx_forge/forge.py --all          # the catalogue
    python tools/vfx_forge/forge.py nova --frames 20 --size 128 --variants 4

Blender is found by the `BLENDER` variable, or at the usual install path. The
command line drives `blender --background --python tools/vfx_forge/render.py`;
nothing about the graph lives in Blender's own file format, so there is no
`.blend` in the repository and no binary to merge.

### 4a. An effect is a file

`tools/vfx_forge/effects/<id>.py`, declaring what it is and how to build it:

    SPEC = {"frames": 16, "size": 96, "variants": 3,
            "why": "one line on what this is for"}

    def build(f):
        ring = f.band(f.grow(1.25), 0.24, 0.07)
        return f.Look(mask=ring, tone=f.lit(ring, 0.5))

Working rule 3 applied to art: **adding an effect means adding a file.** The
pilot wrote its one effect as a branch inside `render.py`, which was right for
one and wrong for thirty — two people cannot author two effects in one
`if/elif`, and a thirty-branch chain is the hardcoded stat table that rule
exists to refuse.

`build` is handed a `Forge` and returns a `Look`: a mask socket that becomes
the alpha and a tone socket that becomes the grey. Everything else — the
camera, the film, the keyframed clock, the radial coordinate, the angle, the
swirl, the noise, the emission — is `forge_kit.py` and is identical for every
effect, so no two can disagree about what a frame or a radius means.

**The toolbox is shapes, not maths nodes**: `grow`, `shrink`, `band`, `disc`,
`ring_gap`, `spokes`, `lobes`, `wedge`, `grain`, `hole`, `rise`, `squashed`,
`before`, `after`, `both`, `either`, `lit`, `phase`. What belongs in the kit is
anything two effects would otherwise write twice; a helper one effect wants
belongs in that effect's file.

Two things about it that cost a render pass each to learn:

- **`grain`'s usable range is about 0.30 to 0.62.** The noise field sits near
  0.5 with little spread, so a bar under about 0.2 passes everything — the
  first flame rendered as a solid sunburst — and a bar over about 0.64 passes
  nothing at all, which is a part of an effect that is simply *absent* with no
  number anywhere going wrong.
- **`phase()` is where a take's variety comes from when there is no noise.**
  The seed reaches an effect only through the noise lookup, so anything built
  out of clean geometry renders byte-identical takes. Spend `phase()` on
  *where things are* — a rotation, a scatter, a count — never on how bright
  they are.

### 4b. The window

`forge_app/` is a standalone Godot project: a dark-mode GUI that lists the
catalogue, renders an effect or all of them without freezing, and **plays the
result back the way the game will** — tinted, additive, at
`Balance.VFX_FORGE_FRAME_RATE`, over a plate the colour of the road, with a
contact strip of every cell underneath.

That last part is the whole reason it exists. A lit-pixel count says nothing
about what an effect looks like moving, and two of the catalogue passed every
numeric rule while rendering as a cog and a sunburst. A tool that renders a
sheet and cannot show it playing is a slower command line.

It is its own project, beside the launcher and for the launcher's reason: it
ships to nobody and must not be able to break the game by existing. What it
shares with the game is the Python half, which is the part doing the work.

### 4c. How a sheet reaches the game

`Vfx.FORGE_CATALOGUE` names every effect and how it may be turned;
`Vfx.forge_play(effect, at, size, tint, aim)` is the one door. Every sheet is
white on transparent and tinted once per use, so **one sheet serves every
element** and a colour is never rendered twice.

A play picks a take at random, turns the sheet by what it is a picture of,
flips it along whichever axis carries no meaning, and wanders its size:

| Turn | What it is | Turned | Flipped |
|---|---|---|---|
| `FREE` | anything radial — a ring, a star, a splash | any angle | either axis |
| `UPRIGHT` | anything that knows where the ground is | never | left to right |
| `AIMED` | anything directional — a beam end, a lance, a trail | to the aim | top to bottom |

The flip is *derived* from the turn rather than authored beside it: two
columns saying one thing is two chances to disagree, and which axis is safe
follows from which axis carries the meaning.

**The cell count is read off the sheet** — a row of squares is as many cells
as its width over its height — so re-rendering an effect at a different length
needs no edit in the game, and there is no count to drift out of step with the
file.

`forge_check` walks all of it: every effect has a sheet, **every sheet has an
effect** (the mirror direction, for the file that ships and can never be
played), the takes are pixel-for-pixel different, every effect is played by
something, every turn policy is obeyed on the sprites the player actually
stands up, and a density of zero plays nothing at all.

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
