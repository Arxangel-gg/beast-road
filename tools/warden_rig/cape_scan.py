"""Lists cape frames that shrink by more than half against their own row.

A generator draws a long cape inconsistently: a shoulder mantle for a few frames
of a swing, a dissolve into specks, a stride where it vanishes. The dress gate
only refuses a frame that is nearly empty, and a cape that halves still pops on
screen. This prints every such frame so each can be looked at and either held
on a neighbour in repairs.json or left alone because the cape is swinging.

    python cape_scan.py male|female
"""
import json
import os
import statistics
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", "..", "game"))
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
            median = statistics.median(counts)
            for k, count in enumerate(counts):
                if median > 200 and count < 0.5 * median:
                    found += 1
                    print("%-12s %-10s frame %d: %d pixels against a row median of %d"
                          % (state, ROWS[row], k, count, median))
    print("%d frame(s) to look at" % found)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "male")
