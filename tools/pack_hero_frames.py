"""Packs Pixellab's per-frame hero export into one sheet per animation state.

    python tools\\pack_hero_frames.py

Pixellab exports `<state>/**/<direction>/frame_NNN.png` — 648 separate files for
the hero — and it does not export them all at the same canvas size. Measured
across the set: 168, 172, 176 and 180 pixels square, varying by direction *and*
by state.

That matters more than it looks. The engine positions the character and the
sprite draws around that point, so a canvas that changes size between two frames
moves the character by half the difference. Switching from idle (172) to walk
(180) would jump the Warden four pixels sideways every time they started moving.

The fix is to composite every frame onto one canvas, and the alignment to use is
not obvious until you measure it:

* **Horizontally: centre to centre.** The content's horizontal offset from centre
  runs from -9 to +9 and tracks the facing direction — a figure facing east
  genuinely sits east of centre. Centring preserves that; bounding-box alignment
  would flatten it and make the character appear to snap back as it turned.

* **Vertically: bottom to bottom.** The gap below the feet is 26 pixels in almost
  every frame of every state, so the canvas bottom is a reliable ground line. The
  exceptions are real animation and must survive: the dash lifts the feet
  (26 -> 20 -> 27) and the death collapse drops them (26 -> 17). Bounding-box
  alignment would delete both by pinning the lowest pixel to the same row.

Output is one PNG per state, rows = the 8 facings, columns = frames. Nine files
instead of seventy-two, and the region maths in `hero_animator.gd` is a
multiply.
"""

from __future__ import annotations

import os
import re
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required:  pip install pillow")

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(REPO, "art_inbox", "Pixellab", "Hero")
DEST = os.path.join(REPO, "game", "art", "hero")

# The sheet cell, derived from the art rather than rounded up to a power of two.
#
# Measured over all 648 frames with the anchoring below: content reaches at most
# 157 pixels above the canvas bottom and 83 either side of the canvas centre. So
# 168x160 holds every frame with a small margin and nothing is ever cropped.
#
# 192x192 also worked and cost 37% more texture. Nine sheets is enough memory
# that the difference was three frame hitches a minute on a 3070 Ti - the whole
# perf budget - so the cell is measured, not guessed.
CELL_W = 168
CELL_H = 160

# Row order is the engine's direction index, so the lookup is
# `int(round(atan2(dir.y, dir.x) / (TAU / 8))) % 8` with no table in between.
# Screen y grows downward, so this runs clockwise from east.
DIRECTIONS = [
    "east",
    "south-east",
    "south",
    "south-west",
    "west",
    "north-west",
    "north",
    "north-east",
]

# Pixellab names a folder after the prompt it was generated from, so the source
# names are prose. These are the ids the game uses.
STATES = {
    "A_game_character_sprite-Idle": "idle",
    "A_game_character_sprite-walk_full_stride_cy": "walk",
    "A_game_character_sprite-Attack_1": "attack_1a",
    "A_game_character_sprite-attack_1_fast_horiz": "attack_1b",
    "A_game_character_sprite-attack_2_return_sla": "attack_2",
    "A_game_character_sprite-attack_3_the_finish": "attack_3",
    "A_game_character_sprite-hurt_flinch_in_plac": "hurt",
    "A_game_character_sprite-dash_starting_frame": "dash",
    "A_game_character_sprite-collapsing_for_death": "death",
}


def frames_for(state_dir: str, direction: str) -> list[str]:
    """Every frame of one direction, in order, wherever Pixellab buried it."""
    for dirpath, _dirs, files in os.walk(state_dir):
        if os.path.basename(dirpath) != direction:
            continue
        frames = [f for f in files if re.fullmatch(r"frame_\d+\.png", f)]
        if frames:
            return [os.path.join(dirpath, f) for f in sorted(frames)]
    return []


def place(sheet: Image.Image, frame: Image.Image, col: int, row: int) -> None:
    """Centre horizontally, bottom-align vertically. See the module docstring."""
    x = col * CELL_W + (CELL_W - frame.width) // 2
    y = row * CELL_H + (CELL_H - frame.height)
    sheet.paste(frame, (x, y), frame)


def main() -> int:
    if not os.path.isdir(SOURCE):
        sys.exit("No hero export at %s" % SOURCE)
    os.makedirs(DEST, exist_ok=True)

    problems: list[str] = []
    written = 0

    for source_name, state_id in STATES.items():
        state_dir = os.path.join(SOURCE, source_name)
        if not os.path.isdir(state_dir):
            problems.append("missing state folder: %s" % source_name)
            continue

        per_direction = {d: frames_for(state_dir, d) for d in DIRECTIONS}
        missing = [d for d, f in per_direction.items() if not f]
        if missing:
            problems.append("%s is missing directions: %s" % (state_id, ", ".join(missing)))
            continue

        counts = {len(f) for f in per_direction.values()}
        if len(counts) != 1:
            # A state whose directions disagree on length cannot be one sheet;
            # the shortest would either freeze or run off the end.
            problems.append("%s has uneven frame counts across directions: %s"
                            % (state_id, sorted(counts)))
            continue
        frame_count = counts.pop()

        sheet = Image.new("RGBA", (frame_count * CELL_W, len(DIRECTIONS) * CELL_H), (0, 0, 0, 0))
        for row, direction in enumerate(DIRECTIONS):
            for col, path in enumerate(per_direction[direction]):
                with Image.open(path) as raw:
                    frame = raw.convert("RGBA")
                # The canvas may be taller than the cell; what must fit is the
                # *content*. Bottom-anchoring clips empty rows off the top, and
                # the cell was sized from the measured reach so it never clips
                # a pixel that is actually drawn.
                box = frame.getbbox()
                if box is not None:
                    reach_up = frame.height - box[1]
                    centre = frame.width / 2.0
                    half = max(abs(box[0] - centre), abs(box[2] - centre))
                    if reach_up > CELL_H or half * 2 > CELL_W:
                        problems.append(
                            "%s/%s frame %d content reaches %dpx up and %.0fpx wide, "
                            "past the %dx%d cell"
                            % (state_id, direction, col, reach_up, half * 2, CELL_W, CELL_H))
                        continue
                place(sheet, frame, col, row)

        out = os.path.join(DEST, "hero_%s.png" % state_id)
        sheet.save(out)
        written += 1
        print("  hero_%-10s %d frames x %d directions -> %dx%d"
              % (state_id, frame_count, len(DIRECTIONS), sheet.width, sheet.height))

    print("\n%d sheets written to game/art/hero/" % written)
    if problems:
        print("\nPROBLEMS")
        for p in problems:
            print("  " + p)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
