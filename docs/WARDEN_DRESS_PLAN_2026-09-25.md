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

## Two motion families

The 23 weapon kinds split by grip: one-handed (blades, sabers, knives, rods,
the lantern hook) and two-handed (mauls, hammers, axes, spears, pikes, glaives).
Each family has its own four-step combo; everything else - idle, walk, sprint,
dash, hurt, death, shoot - is shared. A weapon kind names its family.

## Budget, this cycle (4,317 generations left, reset 2026-10-11)

Fifteen animations (eleven shared plus four two-handed attacks), eight facings,
eight frames at 3 generations a facing: **360 a layer.**

| Item | Generations |
|---|---|
| Male base, female base (grip states + animation) | 60 + 720 |
| Light and heavy armour, both bodies (4 states + animation) | 120 + 1,440 |
| One cape shape (state + animation), shared by both bodies | 30 + 360 |
| Hair: four styles a body, eight views each | 240 |
| Helmets: three classes | 90 |
| Held weapon sprites, 23 kinds | 140 |
| Cape icons (fifteen) | 90 |
| **Total** | **~3,290**, leaving ~1,000 for retries |

Next cycle: medium armour, a second cape shape, more hair and faces, the
menu painting and story panels redrawn for the new Warden.

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
