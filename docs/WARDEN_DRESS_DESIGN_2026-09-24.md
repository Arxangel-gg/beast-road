# The Warden's dress: character creation and modular gear on the body

**Status: design, with a pilot running.** Owner brief, 2026-09-24: *"character
creation and customization and the best way I can imagine it would be with
modular parts so that even wearing gear or weapons updates on the players
appearance properly with perfect polish. Consider the best way of creating a
new system that would be a perfect fit for our game."*

This document is the consideration. It ends in a recommendation, a pilot that
decides whether the recommendation is buildable, a budget, and an order. It is
written before the code because the last two customization notes in
`CLAUDE.md` both say the same thing: **scope it before buying generations.**

---

## 1. The bound, before anything else

Working rule 7 is unchanged and this adds nothing to it. **A customization may
change nothing but how the Warden looks.** No attribute, no stat, no unlock, no
currency, nothing the road can grow. The dye of 2026-09-21 already lives under
that bound and `warden_look_check` holds it by dressing a real hero and
reading every number back; the dress inherits the same gate.

What the dress adds to the save is **nothing**. Which armour class a Warden
wears is derived from the worn gear at draw time, exactly as the set aura
derives its colour; a Warden's *chosen* look (name, dyes, and later a hood or
mask) stays in `MetaState.look`, additive, `SAVE_VERSION` unmoved.

---

## 2. What exists, measured

- **The Warden is painted, not rigged.** Eleven states - idle, walk, sprint
  (owed), attack 1a/1b/2/3, hurt, dash, death, shoot - each a sheet of **8
  facings x 9 frames at 168x160**, 792 cells a state. `HeroAnimator` plays them
  by region. The sword, the lantern and the banner are **painted into every
  cell**.
- **The PixelLab character that made them no longer exists** (CLAUDE.md,
  2026-09-13). Every new drawn option has, until today, meant every sheet again.
- **A dye exists**: three hue bands (cloak/steel, sash/banner, leather) in
  `warden_look.gdshaderinc`, applied to the body sprite, the Hold's figures and
  the Warden card; relayed by value; six presets. The cloak and the plate share
  one band, so the dye cannot separate the hood from the pauldron.
- **Gear already shows in two places**: the swing signature is graded by the
  worn weapon's rarity (`Vfx._swing_signature`) and a finished set turns a ring
  at the feet (`SetAura`). Nothing about the *kind* of weapon or armour shows.
- **138 gear kinds in 8 slots**: 23 weapons, 20 armour, 20 charms, 15 each of
  helmet, gloves, boots, ring, amulet. Weapons are the only slot with a
  silhouette a player can read at 128px; armour and helmets are the next two.
- **Budget**: 4,625 PixelLab generations this cycle, refilling 2026-10-11.

---

## 3. Three ways to do it, and why two are refused

### A. A cut-out rig (`Skeleton2D` parts, gear as swapped textures) - refused

The professional answer for a *vector* game, and the wrong one here. The
Warden is a painted figure with a slight top-down view in eight facings; a
rig is five rigs at least (three mirrored), every part re-drawn per facing,
and the result moves like a puppet beside enemies that are painted frame by
frame. It is a restyle of the one character the player looks at most, and it
reads as cheaper than what ships. This is the "AI slop" direction from the
other side.

### B. Full-body sheets per combination - refused

Six weapon looks x four armour x four helmets is 96 Wardens x 11 states x 792
cells. Not a budget, a multiplication.

### C. Layered deltas on one shared skeleton - **recommended**

The idea that makes a paper doll possible on painted frames: **every layer is
generated in exactly the same poses as the body**, so the layers align by
construction rather than by hand.

PixelLab can do this in a way it could not when the dye was built. A character
made from the Warden's own south frame (`create_character`, v3 with a
reference image) **keeps its identity** across eight rotations and gains a
skeleton. A `create_character_state` of it ("wearing plate", "holding a
spear", "hands empty") **keeps the same individual, body type and proportions**
across all eight rotations. And a template animation (`walking-8-frames`,
`breathing-idle`, `hurt`, `falling-back-death` ...) poses *whichever state it
is given* onto the **same template skeleton**, frame for frame.

So the pipeline is:

1. **Re-found the Warden** as a PixelLab character from its own frame.
2. **Make a weaponless base state** ("hands empty, lantern kept"). The sword
   painted into today's frames is the one thing a paper doll cannot draw over.
3. **Every appearance class is a state** of that base: six weapon classes, four
   armour classes, four helmet classes. Fourteen states, not ninety-six.
4. **Animate every state with the same animation set** - templates where a
   template fits, `v3` with an action description for the four swings and the
   loose (the mount lesson: templates strip the tack, a described motion keeps
   it).
5. **Extract each class's delta** against the base, per cell: keep only the
   connected regions that differ strongly, which is what
   `tools/lock_tower_frames.py` already does for towers. A plate delta is the
   plate; a spear delta is the spear and the hand around it.
6. **Composite at runtime**: body sheet, then armour delta, then helmet delta,
   then weapon delta, all four sprites driven by `HeroAnimator` on the same
   cell. Ninety-six combinations from fifteen sheets a state.

**What it costs the shipping Warden.** The body sheets are re-animated on
the same templates so that the deltas align with *them*, which means the
owner-approved frames of today are replaced by regenerated ones. That is the
one real risk in this plan, and it is what the pilot photographs first.

---

## 4. The look classes

A kind names a class; the class has sheets. Data, never a branch
(working rule 3):

| slot | classes | how it shows |
|---|---|---|
| weapon | sword, greatblade, spear, axe, dagger, bow | a delta sheet; the swing signature keeps its rarity grade |
| armour | cloth, leather, mail, plate | a delta sheet, tinted by the kind's own colour through the steel band |
| helmet | hood, cap, helm, crown | a delta sheet over the hood |
| gloves, boots | - | the leather band's tint, from the kind |
| ring, amulet, charm | - | nothing on the body; rarity already glints in the swing and the set ring |

`GearData.look` (a `String`, e.g. `"weapon:spear"`) and `GearData.look_tint`.
A kind that authors nothing derives a class from its slot and name, so the
138 shipped kinds need no edit to keep loading; `look_check` refuses a kind
whose class has no sheet on disk and is not on a declared list, which is the
`DisciplineEffects` rule applied to art.

---

## 5. Runtime

- `WardenDress` composes a look: `{look, weapon_class, armour_class,
  helm_class, tints}` from `MetaState.look` and the worn gear on **this**
  machine.
- The hero carries four `Sprite2D`s; `HeroAnimator` sets the same `hframes`,
  `vframes`, `frame` and flip on all of them. A layer with no sheet for a state
  is hidden for that state, never a hole.
- The dye shader dresses the body; each delta wears the same include with the
  kind's tint in the relevant band, so a Chainbroken plate is the same plate
  in that piece's colour.
- **Co-op**: the class ids ride the look row **by value** - a partner's gear is
  not this machine's to read - appended to `WardenLook.KEYS`, never inserted,
  so an older partner's row still means what it meant. The Hold's seats and
  the lobby hello carry the same row.
- The Warden card, the Hold's figure, the lobby portrait and the creation
  screen all draw through `WardenDress`, so five pictures of one Warden cannot
  disagree.

---

## 6. Character creation

**The Warden's Glass**: a screen offered when a slot is new and standing in
the Hold afterwards. Name; the three dyes and the six presets; a turning
eight-facing preview of the Warden **wearing what they wear**; and, once the
states exist, a hood or a mask (each is one more state of the base). No
hair and no face: the Warden is hooded and skull-faced, and both are the
identity the owner approved. Nothing on it grants anything.

---

## 7. Budget and order

| step | generations |
|---|---|
| pilot: re-found the Warden, one plate state, one weaponless state, walk on all three | ~70 |
| base re-animation: 11 states x 8 facings (templates 1/dir, described swings ~2/dir) | ~150 |
| each class: state 20-40 + its 11 animations ~110 | ~150 |
| six weapons, four armours, four helmets | ~2,100 |
| **total** | **~2,300 of 4,625** |

**Order**: weapons first - the largest silhouette and the thing a player
changes most - then armour, then helmets, then the hood and mask options for
the Glass. **One class at a time, gated each time.** The first class is
photographed beside the shipping Warden in all eight facings before the
second is bought.

---

## 8. Gates

- `warden_look_check` (exists): every number unchanged by any look.
- `dress_check` (new): every delta sheet is the body's cell count and size
  and closes on its own ground line; every class a kind names is on disk or
  declared; the co-op row round-trips and a short row draws the plain Warden;
  a layer with no sheet for a state is hidden and never a hole; nothing about
  the dress persists beyond `MetaState.look`.
- `look_shot` (exists, extended): the Warden in every class, eight facings,
  beside the shipping frames - the one check no number can do.

---

## 9. The pilot

Bought today, ~70 generations, in this order, each waited on before the next:

1. `create_character` v3 from `References/warden_south_frame.png`: does the
   rotated Warden keep the hood, the skull, the lantern and the banner in all
   eight facings?
2. `create_character_state` "hands empty" and "heavy plate": does the
   individual survive?
3. `walking-8-frames` on the base and the plate state: **do the cells align
   frame for frame** - feet on the same pixel, the plate over the same
   shoulder - so that a delta is a delta and not a ghost?

If 3 holds, §3C is the plan. If it does not, the fallback is narrower and
still worth having: **weapons only**, as full-body states of the base
animated once each (six x eleven states), composited as whole sheets rather
than deltas, with armour and helmets shown by tint alone.

### Pilot result

**Step 1 - held.** `create_character` v3 from the shipping south frame (4
generations) returned eight facings that are unmistakably the Warden: hood,
skull, plate pauldrons, sash, banner, lantern and sword in every one, the
south rotation near pixel-identical to the frame it was made from. The
character is `97aeb7bd-...` ("Warden (dress pilot)"), 168x160, low top-down.

**Step 2 - held, with one lesson.** Both states kept the individual **and the
pose**: laid over the base facing by facing, the Plate state's feet, hips,
shoulders and lantern sit on the same pixels, with a closed great-helm over
the hood and riveted plate over the body in all eight. That is the alignment
the whole plan rests on, at the rotation level. The Unarmed state removed the
sword in **five of eight** facings and left it in west and east - a state
edit is applied per rotation and can disagree with itself across them, so
**a weaponless base is checked facing by facing and the stragglers are
re-edited** (`inpaint` on the two, or the state re-rolled), never trusted
from the south view alone. This is the facing-sheet lesson of the roster,
arriving on the Warden.

**Step 3 - the template walk failed the way the mount walks failed, and the
mode that answers it is known.** `walking-8-frames` in *template* mode
(1 generation a facing) re-renders the Warden each frame from the skeleton:
south came back **without the lantern or the sword** for the whole cycle and
without the banner for half of it, east kept the sword and lost the lantern,
and the legs barely moved. That is the lesson the mount walks recorded on
2026-09-17 - the template animations strip the tack - and it is why the
frames were never going to be usable as a base.

What is bought instead is **`mode: "skeleton-v3"`**: the *same* template
skeleton posed onto the character by the skeleton video model, which "moves
the character instead of redrawing it each frame". Same poses across every
state - which is the property the deltas need - with the pixels of the
reference kept, at 2-4 generations a facing. The v3-with-action-description
route that the mount walks took also keeps the tack, but its poses are the
model's own and would not match state to state; it is the fallback for the
four swings and the loose, which have no template.

**And the alignment held, measured rather than eyeballed.** The Plate state's
template walk over the base's, frame for frame in south and east: the feet
sit within 0-3 pixels of the same row on every one of sixteen frames, and
the silhouettes overlap at 0.63-0.78 IoU - the difference being exactly the
helm, the plate and the banner, which is what a delta *is*. Same template,
same skeleton, same pose, in two separately generated states. That is the
property §3C rests on, and it is true.

**Step 4 - `skeleton-v3` keeps everything, measured on the base's south
walk.** Six frames of the `walk` template through the skeleton video model:
the banner, the lantern, the sword, the pauldrons and the cloak are in every
frame, the legs actually stride, and the skull reads as the same face
throughout. It comes back on a 192x192 canvas - the same padding the mount
walks recorded - so frames are cropped by the union of their facing, never
each to its own content. **That is the mode the wardrobe is bought in.**

**Step 5 - and two states walked through the same skeleton land on the same
pixels.** The Plate state's `skeleton-v3` walk against the base's, six frames,
south: feet within 1-3 pixels on every frame, silhouettes at 0.70-0.76 IoU
with the difference being the helm and the plate, every piece of kit present
in both. The plan in §3C is buildable exactly as written: **re-found base,
weaponless state, one state per look class, every state animated through the
same skeleton templates in `skeleton-v3`, deltas extracted against the base,
composited in lockstep.** Pilot cost: 4 + ~60 + 8 + 8 + ~6 = about 90
generations. The pilot character and its three states stay in the account
(`Warden (dress pilot)`, group `1bdbac4f-...`) as the base the wardrobe is
built from - nothing here is thrown away.

**Cost re-read against that.** An animation is now 16-32 generations a state
rather than 8, so a class is ~300 rather than ~150, and fifteen classes are
~4,500 - the whole cycle. So the order in §7 is also a budget cut-off:
**weapons first** (six classes plus the two bases, ~2,400) fit this cycle;
armour and helmets are next cycle's. That is the honest number.
