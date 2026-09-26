"""Lists cape frames that a generator drew wrong.

A generator draws a long cape inconsistently: a shoulder mantle for a few frames
of a swing, a dissolve into specks, a stride where it vanishes, and - in the
back view - a cape arranged as if seen from the front, open down the middle, for
half a loop. The dress gate only refuses a frame that is nearly empty. This
prints two lists, each against the fullest frame of its own row:

- **Loops seen from behind** (idle, walk and sprint facing north), held to
  `LOOP_SHARE`. From behind the cape is most of the picture and a loop plays
  for as long as the player stands or walks, so a cape that opens and closes
  every cycle is the worst flicker the layer can have. Every other row is left
  out: on a diagonal or a side the cape streams out with the stride and its size
  moves by a third legitimately - photographed on the sprint's back diagonals,
  where the first cut of this check named a cape flying out behind the run.
- **Everything**, held to `COLLAPSE_SHARE`: a frame that lost most of its cape.
  A swing flings the cape aside and halves it on purpose, so this list is
  looser, and each entry is a picture to look at rather than a verdict.

Against the fullest frame, never the median: the female back-view walk dropped
the cape for six frames of eight, the median was the fault, and the two good
frames looked normal beside it.

    python cape_scan.py male|female
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", "..", "game"))
# A back-view loop frame under this share of its row's fullest is listed. [TUNE]
LOOP_SHARE = 0.85
# Any frame under this share of its row's fullest is listed. [TUNE]
COLLAPSE_SHARE = 0.40
LOOPS = ("idle", "walk", "sprint")
BACK_ROWS = (6,)
ROWS = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]


def main(body: str) -> None:
    meta_dir = os.path.join(GAME, "data", "dress", body)
    art = os.path.join(GAME, "art", "hero", "dress", body + "_cape_long")
    found = 0
    for name in sorted(os.listdir(meta_dir)):
        state = name[:-5]
        sheet = os.path.join(art, state + ".png")
        if not os.path.exists(sheet):
            continue
        meta = json.load(open(os.path.join(meta_dir, name), encoding="utf-8"))
        cw, ch = int(meta["cell"][0]), int(meta["cell"][1])
        frames = int(meta["frames"])
        alpha = Image.open(sheet).convert("RGBA").getchannel("A")
        for row in range(8):
            counts = []
            for k in range(frames):
                cell = alpha.crop((k * cw, row * ch, k * cw + cw, row * ch + ch))
                counts.append(sum(1 for v in cell.getdata() if v > 40))
            fullest = max(counts)
            share = LOOP_SHARE if state in LOOPS and row in BACK_ROWS else COLLAPSE_SHARE
            for k, count in enumerate(counts):
                if fullest > 200 and count < share * fullest:
                    found += 1
                    print("%-12s %-10s frame %d: %d pixels against the row's fullest %d%s"
                          % (state, ROWS[row], k, count, fullest,
                             "  (loop seen from behind)" if share == LOOP_SHARE else ""))
    print("%d frame(s) to look at" % found)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "male")
