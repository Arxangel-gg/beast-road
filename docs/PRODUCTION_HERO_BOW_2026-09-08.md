# The Warden's bow — 2026-09-08

## DONE

**Ranged combat had no firing animation, and now it does.** The system shipped
on 2026-08-31; `hero_ranged.gd` made no animator call and `hero_animator.STATES`
had no entry for it, so the Warden loosed arrows standing in its idle pose.

`hero_shoot.png` — 8 facings × 9 frames, 1512×1280, packed to the same 168×160
cell as the other nine sheets. Generated as a **state of the existing PixelLab
hero** (`create_character_state` on group `7913682d-163d-4440-82cd-acc3f6f416cb`,
palette snapped to the source) rather than as new art, so the skull, hood, red
banner, armour and colours carry from idle unchanged. The lantern is stowed,
which is correct: both hands are on the bow.

Wiring is two lines and both were already safe by design. `hero_animator`
loads only sheets that exist, and `_lock_frames` answers to `has_state` — which
is exactly how the ranged system shipped for eight days without this art and
degraded to the static pose instead of blanking.

    hero_animator.STATES  += "shoot": {fps: 20.0, loop: false}
    hero.gd _on_loosed()  += _lock_frames("shoot")

**20 fps is paced off the fastest bow, not the slowest.** `request()` emits the
shot immediately and then sets `draw_time` as the cooldown, so this animation is
never what an arrow waits for. What matters is the other end: the shortbow's
0.54s is the shortest gap between two shots, and nine frames at 20 fps is 0.45s,
so the bow is never still lowering when the next arrow leaves it. The hand
ballista's 2.10s is a pause between shots, not a longer draw to fill.

## Why no gate caught the gap

`report` was right that all 1,598 manifest assets existed. Hero sheets are named
by state — `hero_<state>.png` — so **a state nobody asks for is not a missing
file**. There was nothing to be missing until the state existed. Every other
animation the code requests (`idle`, `walk`, `dash`, `hurt`, `death`, four
attack swings) had its sheet; ranged simply never asked.

## One frame was invisible, and the packer let it through

`shoot/south-east frame 8` generated 170px wide against the 168px cell.
`pack_hero_frames.py` reports that and then `continue`s — which **skips pasting
the frame**, leaving an empty cell. The Warden would have vanished for a
twentieth of a second when firing south-east.

Measured rather than noticed: a scan of all 72 cells found exactly one with no
content. Nothing else could have. `report` checks that the file exists and that
pixel (0,0) is not the magenta placeholder marker; a hole *inside* a packed
sheet is invisible to it, as it is to every other gate.

Fixed by regenerating that one direction with a prompt asking for a compact
pose — 144px, comfortably inside the cell — for 2 generations. The alternative,
widening `CELL_W`, would have meant repacking all ten sheets and paying texture
cost the packer's own docstring records as the whole frame-hitch budget.

**And the packer no longer writes a holed sheet.** It already exited non-zero,
but it saved the file first, and the file is what gets committed. It now skips
the save and says so, leaving the previous sheet in place — stale art is a
lesser wrong than a hole.

## CONFORM

`run_tool.gd -- audit` — **46 / 46 automatic probes**, unchanged. This adds an
asset and an animation state; it adds no v4 requirement.

## KILL Q

*Does the hero read as firing a bow, in every direction, without breaking the
character?*

The art says yes and the measurements support it: all 72 cells populated, none
touching a cell edge, real motion (1,584–6,448 changed pixels per frame pair),
content height stable at 123–126px, and feet-gap constant per direction at
29–30px — inside the 25–30 spread the existing states already occupy, so the
Warden does not sink or jump when it fires.

What that does **not** answer is whether 0.45s feels right at the shortbow's
cadence, or whether the loose reads at gameplay speed and scale. Nothing here
can; it needs play.

## FILES

Created — `game/art/hero/hero_shoot.png` (+ `.import`), this report.
Modified — `game/scripts/components/hero_animator.gd`, `game/scenes/hero/hero.gd`,
`tools/pack_hero_frames.py`, `docs/ASSET_MANIFEST.md`.

The raw per-frame export lives in `art_inbox/Pixellab/Hero/shoot/`, which is
gitignored; the packed sheet is the artefact. The other nine sheets repacked
byte-identical, so there is no churn in this change.

## ASSETS

One new manifest entry, `hero_shoot.png`, declared in §5.1. **18 subscription
generations** — the state, 16 for eight directions, 2 for the south-east retry.

## BLOCKED

Nothing on this change. Minimum-spec hardware, real-device portrait/controller
acceptance, two-machine co-op, the `menu_layout_check` Linux segfault and the
service-restricted leaderboards all remain open on their own terms.

## NEXT

Play it. Every remaining question about this animation is a judgement about how
it feels, and no gate in the project can answer one.
