# The thumb cluster: what Wild Rift's layout teaches the phone HUD, 2026-10-06

Owner's item 25 of 2026-10-06: *"Wild Rift mobile layout screenshot as
inspiration for mobile UI"*, clarified on the same day as *"Layout inspiration
is for Mobile HUD."* The screenshot is the bottom-right corner of League of
Legends: Wild Rift in a fight. This is the reading of it against what the phone
HUD does today, and a cluster designed from it for the next session to build.
Nothing here is built.

## 1. What the reference does

Read off the screenshot, from the corner outward:

- **The attack is the anchor.** The largest button on the screen sits exactly
  where a right thumb rests, in the corner, and it is also the aim: a drag on
  it shows the direction and a release swings. Everything else is placed by
  its distance from this one button.
- **The abilities are an arc of equal reach.** Four circles, numbered, on one
  arc around the attack - the first due left of it, the fourth due above - so
  every ability is the same short roll of the thumb away. Each wears a thin
  blue arc that is its cooldown and its level, and the number sits inside it.
- **The small circles hug the big one.** The two summoner spells sit at the
  attack's foot, between it and the first ability; the item actives sit further
  out at the left end of the arc. Smaller, because they are pressed less.
- **What can be grown sits outside the arc.** A red chip beside each ability
  is the level-up, hopping when a point is waiting. It is *outside* the arc, so
  a thumb reaching for an ability never lands on it by accident.
- **A drag has a cancel.** While an ability is being aimed a cyan X appears at
  the top of the arc, and dragging into it aborts the cast.
- **The utility is at the top corner, small.** Recall is a single small arrow
  at the very top right - reachable, out of the way.

The principle under all of it: **the corner is the hand's rest, the arc is
the hand's reach, and size says how often a thing is pressed.**

## 2. What the phone HUD does today

`phone_hud_shot` at 1280x592 (the landscape phone shape), read on 2026-10-06:

- The right thumb has an **aiming stick** that owns the right 42% by 62% of
  the glass (invisible until touched), four **ability slots in a row** across
  the bottom middle (100-unit squares, numbered, EMPTY until learned), and a
  **DASH** circle in the bottom-right corner.
- The left thumb has the **move stick** in the mirror zone and a row of six
  **action tiles** (HORN, RAID, FIX, ORDERS, RATION, RIDE) along the bottom
  left, which are the tower-defence orders Wild Rift has no equivalent of.
- The right edge holds the **scope column** (the battlefield, the Town, Yuri,
  the speed, the scroll) and the **minimap**; the top left the run's readouts
  and the command panel.

What is wrong by the reference's own rule: the four slots are a row, so slot 1
is a long reach from the corner and slot 4 is a longer one; DASH, pressed
constantly, is the right size and in the right place, and the swing - pressed
more than anything - has no button at all, only a stick zone with nothing drawn
in it. The row also sits under the sheets a thumb opens in Preparation, which
is why `_stand_the_row_down` exists.

## 3. The cluster

One `ThumbCluster` control in the bottom-right corner, built only on a touch
layout, replacing the ability row and the DASH circle there. Logical units are
the road's 1680x777 landscape canvas (`UiMetrics`); the upright canvas is
900 wide and uses the same shape at a smaller radius.

| Thing | Place | Size | Pressed |
|---|---|---|---|
| **Primary** (the swing or the Spellblade's bolt) | the corner, centre 104 in from both edges | 152 across | hold to aim, release to swing - the aiming stick, drawn |
| **Slot 1** | 200 from the primary's centre, at 180° (due left) | 96 | tap to cast; hold to aim where the spell takes an aim |
| **Slot 2** | 200 at 142° | 96 | the same |
| **Slot 3** | 200 at 112° | 96 | the same |
| **Slot 4** (the ultimate) | 200 at 86° (due above) | 96 | the same |
| **DASH** | 120 at 165°, inside the arc | 72 | tap |
| **RIDE / charge** | 120 at 115°, inside the arc | 72 | tap; shows the mount's rest ring as it does today |
| **Cancel** | 260 at 100°, shown only while a slot is held | 64 | drag into it |

The arc is 200 units because at 1680 logical over a 150 mm phone a unit is about
0.09 mm: the furthest slot is 27 mm from the corner and the primary 9 mm, both
inside a thumb's comfortable 50 mm. The thumb minimum of 92 units (2026-09-13)
holds for every slot; DASH and RIDE are under it on purpose, as Wild Rift's
summoner spells are - a thing inside the arc is a thing the thumb crosses on the
way to the arc, and a smaller target there is a target that is not pressed by
accident.

Each slot wears what it does today (the skill's medallion, the digit) and a
cooldown arc round its rim in the arm's tint, the slot clock the HUD already
paints as a fill. The primary wears the form's tile (`HUD._primary_tile`, desktop
only since 2026-09-30) and so puts the primary on a thumb for the first time.

**Where a draft waits** - the road-rank strip's third door (2026-09-26) - a
hopping chip outside the arc at 250 at 160°, in the strip's own gold, is the
reference's level-up chip and is tapped exactly as the strip is.

## 4. Aiming on a thumb

Wild Rift's model is one gesture for everything: press shows, drag aims, release
commits, drag to the X aborts. The phone HUD already has every piece of this in
separate places - the aiming stick is a drag, a spell with an aim draws its ring
at the blow's own radius (`Vfx.ring`, 2026-09-11), and the placement cursor
already distinguishes a tap from a drag (`TOUCH_TAP_SECONDS`, `TOUCH_TAP_SLOP`,
2026-09-25). The cluster joins them:

- **A tap on a slot casts at the aim the stick last held**, which is what a
  tap does today.
- **A hold on a slot (past `TOUCH_TAP_SECONDS`) aims it**: the telegraph ring
  of the spell's own kind is drawn at the point the drag reaches, the field dims
  under it as the draft's scrim does, and the release casts there. For a spell
  with no aim (a nova, a ward) the hold does nothing more than the tap.
- **Dragging into the cancel aborts** with no cost: the mana is spent on the
  release that casts, never on the press.
- **The primary's hold is the aiming stick**, unchanged in what it does and
  drawn for the first time: the stick's knob is the button's own face sliding.

Nothing about a spell's reach, cost, cooldown or damage moves. **A look and a
gesture, never a number**: `spell_strike_check`, `mana_check` and
`chain_bolt_check` read the same casts, and the co-op wire carries the same
walk, aim and press it carries today (`HeroInput`, 2026-09-17).

## 5. What stays where it is

- **The move stick**, the left zone, the six action tiles: the reference has
  no left-hand orders and ours are the tower defence; the row is already the
  height of a slot and reads well in the photograph.
- **The scope column and the minimap** on the right edge above the cluster.
  The cluster's top slot reaches 777 - 104 - 200 = 473; the column's lowest
  button ends near 380 in the photograph, so the two do not meet. A phone with
  a shorter canvas moves the column up, not the cluster down: the corner is the
  hand's rest and the column is pressed between fights.
- **The sheets' rule** (`_stand_the_row_down`): a sheet that stood the row
  down stands the cluster down the same way, through the same door, so a
  Preparation sheet is never pressed through a slot.

## 6. Gates and photographs

- `layout_check` and `mobile_fit_check` at both phone shapes: every slot on the
  screen, no slot under the column or the minimap, the thumb minimum on the
  four slots and the primary.
- `touch_check`: a tap on a slot casts; a hold aims; a drag into the cancel
  casts nothing and spends nothing (the mana read before and after); a hold on
  a spell with no aim casts as a tap does.
- `road_sheet_check`: a sheet opened in Preparation stands the cluster down and
  puts it back, through the row's own door.
- `phone_hud_shot` at 1280x592 and 430x932, in a fight with four skills slotted
  and one being aimed, beside the reference. **Photograph before believing it**:
  a cluster that measures right and reads as a scatter of circles is the
  failure the reference's clean arc exists to show.

## 7. Decisions for the owner before it is built

1. **The primary as a drawn button in the corner, or the invisible stick zone
   as it is?** The reference draws it; this design draws it. A drawn button
   under the stick zone changes nothing about the gesture.
2. **Hold-to-aim on the slots, or keep "tap casts at the stick's aim"?**
   Hold-to-aim is the reference's whole model and the larger build; the arc
   alone is a layout change.
3. **Which two small circles sit inside the arc.** DASH and RIDE are the
   design's answer because both are pressed mid-fight; HORN and RATION stay on
   the left row.

## 8. Build order

The arc without the aiming is an afternoon and is most of the gain: lay the
cluster, move DASH and RIDE into it, draw the primary, photograph. Hold-to-aim
is the second commit, gated by `touch_check`, and the cancel zone comes with it.
The draft chip is last and optional.

## 9. Measured before it was built, 2026-10-08: the arc does not fit

Stage one was built on the design's own answers to §7 and photographed, and it
is **not shipped**. The arc itself worked - a solver (`ThumbCluster.lay`, kept
in the session's scratch) laid four slots round a drawn primary clear of
everything the HUD had drawn, and the picture read as an arc. What broke it is
the space §5 assumed.

§5 says the column's lowest button ends near 380 on the landscape canvas. It
ends at **498**, and that is the smaller half: with a spirit bonded, the spirit
readout stands left of the column at 108-261 and the minimap hangs under the
readout down to about 421. The top right is taken to the middle of a 777-tall
canvas whenever a spirit is out.

Three ways round it were measured and each is worse than the row:

- **Solve against what is showing.** The slots fit with no spirit out and moved
  the moment one was called - a slot that jumps under the thumb when the state
  changes is the one thing a thumb cluster must never do.
- **Solve against what *can* show** (the readout and minimap reserved). The only
  arc that clears them has a radius of 580-630 units: slot one 50 mm from the
  corner, which is the reach the design exists to shorten.
- **Move the minimap beside the readout on a thumb.** It frees the band, and
  lands on the top-centre banners (the message, the Chronicle goal, the boss
  track) - `layout_check` named all three at both phone shapes.

**What does fit**, for whoever takes this up with the owner: a two-by-two *fan*
rather than an arc - two slots at radius 200 (175° and 145°) and two at 320
(178° and 155°) round a primary in the corner, every slot under y 448 and left
of the column - with DASH in the 85-unit gap between the column's foot (498) and
the primary's top (591). The bow's trigger and the conditional buttons then have
no home under the column and want one decided. That is a layout decision with a
real cost to the bow, so it is the owner's, and nothing about it is built.

Found on the way and fixed: the spirit readout's order button (2026-10-07) had
pushed the readout to 291 of its 240 at both phone shapes, over the column.
