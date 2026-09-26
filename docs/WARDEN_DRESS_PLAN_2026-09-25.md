# The modular Warden - build plan (2026-09-25)

The design is `WARDEN_DRESS_DESIGN_2026-09-24.md`; this is how it is built,
after the owner's rulings of 2026-09-25 (CLAUDE.md, "The Warden becomes a
modular, customizable body"): no hooded skull, capes as a stat slot, male and
female bodies, and "max perfection".

## What the test proved

`tools/warden_rig/` holds a 3D skeleton projected into the game's camera for all
eight facings. One `animate_with_skeleton_v3` job (2 generations, base B, south
east, right arm raised overhead) came back with **every joint where it was
sent** - same canvas, no drift, the same person, the lantern kept. So:

- RIGHT is the character's own right (PixelLab's labels are COCO-18).
- A larger `z_index` is nearer the camera.
- PixelLab's diagonals are drawn about 32 degrees off a cardinal, not 45
  (`rig.DIAGONAL_TURN`).

Because every joint is authored, the hand and the head are known exactly in
every frame of every facing. That decides the architecture.

## Four kinds of layer

| Layer | How it is made | Why |
|---|---|---|
| **Body** - base linen, light armour, heavy armour; male and female | A full frame per state, animated to the rig. The body layer is *chosen*, not composited: armour covers the body, so a delta would only carry noise. | The largest part of the figure is never a difference image. |
| **Cape** | A state wearing a flat bright green cape, animated to the rig, **chroma-keyed** to its shading and tinted by the cape kind's colour at runtime. Drawn behind the body facing south and in front of it facing north, per the rig's depth. | One cape shape serves every cape kind, and keying a colour nothing else wears is robust where a difference image is not. |
| **Weapon** | Socketed. One held sprite per weapon *kind*, placed at the rig's hand and turned along the blade's projected direction, in front of or behind the body by the hand's depth. | The exact weapon worn is shown - the owner's first wish - for a few generations a kind instead of hundreds a class. |
| **Head dressing** - hair, helmet, facial hair | Socketed. Eight views per option (a state's rotations, keyed), placed at the rig's head point and chosen by the head's facing. | Rigid at game scale; eight images instead of a whole animation set. |

Skin, hair colour and cape colour are shader tints; the cloak and sash dyes of
2026-09-21 become the cape and trim dyes.

### The fist closes over the handle

Owner, 2026-09-25: *"make sure the part of the hand that grips the weapon gets
zsorted over the blade"*. A weapon in front of the body is cut along its own
picture into bands: a fist's width of handle round each gripping fist is drawn
**under** the body (the painted fingers cover it), and the rest - guard, blade,
pommel - over it. A weapon behind the body is drawn whole under it.

| Piece | Where it comes from |
|---|---|
| The hilt a fist may cover | `held.json` `hilt`, measured by `install_held.py` from the picture |
| Where the fist is | the socket, moved by `pack.py` onto the fist the base layer drew (`fist.py`) |
| How wide a fist is | `rig.Body.fist_half` (0.037 of the figure, measured on both bases), written to the meta as `fist` |
| The rule | `DressLayers.grip_bands`; `compose.grip_bands` is the same rule for pilot pictures |

Under the body means hung from `DressBehind`, a holder that is the body
sprite's own child: `show_behind_parent` orders a node only against its parent,
so a part flagged behind one level deeper is drawn over the body.

## Two motion families

The 23 weapon kinds split by grip: one-handed (blades, sabers, knives, rods,
the lantern hook) and two-handed (mauls, hammers, axes, spears, pikes, glaives).
Each family has its own four-step combo; everything else - idle, walk, sprint,
dash, hurt, death, shoot - is shared. A weapon kind names its family.

## Budget, this cycle (4,317 generations at the start of the day, reset 2026-10-11)

A skeleton job costs by frame count and barely moves with it (8 frames 3, 15
frames 4), so two animations share one 15-frame job: eight clips a facing,
**248 generations a layer** (`batch.py plan`).

| Item | Generations | Status |
|---|---|---|
| Base candidates, female base, grip states | ~80 | done |
| Fifteen cape icons | ~90 | done, in the game |
| Twenty-three held weapons | ~140 | done, in the game, grips found |
| Pilots (three short jobs) | 10 | done |
| Male and female base layers | 496 | waiting on the pilot's sign-off |
| Light and heavy armour, both bodies (4 states + animation) | ~1,110 | after the bases |
| Long cape, both bodies (2 states + animation) | ~560 | after the bases |
| Hair (four a body) and helmets (four classes) | ~360 | after the bases |
| **Remaining** | **~2,530** | of 4,085 left after the day's 232 |

## The checks every layer passes through

Owner, on the first pilot: *"If these are foundations they should be polished
to prevent further defects later on"*. So nothing is bought or shipped on a
person's eye alone:

1. **`validate.py`** - every authored frame of every animation, both bodies,
   all eight facings: the wrist's bend, the blade clear of the torso and the
   head, two-handed grips within reach, and the off hand clear of the blade *in
   each facing's projection*, which is what a player sees. Run before any job.
2. **`qa.py`** - every generated frame against its own skeleton: anything drawn
   outside the body that is not skin is an object the generator invented (the
   pilot's painted swords), and the fists and feet must be where they were
   told to be. Flags for review; it never re-rolls on its own.
3. **`dress_check`** (in the game, both bars) - every gear kind names a class
   the drawing knows, every weapon is held and sized by what it is, and the
   runtime lays every part on its socket, proven on a synthetic dress: under
   or over the body by the holder it hangs from, and the fist closed over the
   handle in every case - in front, behind, foreshortened, two fists on a haft,
   a pair.

## Order

1. Grip states of both bases on a 208 canvas (headroom for an overhead swing).
2. One animation through all eight facings on the male base, photographed
   beside the shipping Warden - the pilot. Nothing else is bought until it
   reads as well as what ships.
3. The cape state and the same animation; key it; composite; photograph.
4. The rest of the body layers, then heads, then weapons.
5. Runtime: `WardenDress` composites; `HeroAnimator` plays layers in lockstep;
   rig sockets exported per frame to `art/hero/rig/`; the Warden's Glass
   (creation screen); co-op look row; the Hold and the lobby draw the same.
6. Gates: `dress_check` (layers register, sockets land on hands, every look
   option has every sheet), `look_shot` photographs every combination class.
