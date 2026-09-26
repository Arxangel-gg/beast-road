"""Install the held weapon pictures and record where each one is gripped.

    python install_held.py <folder of <weapon id>.png>

Each picture is drawn blade-up on a 128 canvas (PixelLab Pro Flash, `view:
side`, the weapon's own icon as the style image). It is installed as it was
drawn, at `game/art/hero/held/held_<id>.png`, and the point the fist closes on
is written to `game/data/dress/held.json` - in the picture's own pixels, with
the top of the blade, so the runtime can lay the grip on the rig's socket and
measure the blade without reading the image.

**Where the fist closes is found, not typed.** On a blade it is just below the
guard - the widest row in the lower part of the picture - a third of the way
down the grip. On a two-handed haft it is the right hand's place, two thirds of
the way down, with the left a hand and a half below it along the haft (the rig
puts it there). A weapon added tomorrow is installed by the same rule.
"""
from __future__ import annotations

import json
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", "..", "game"))


def grip_of(kind: str) -> int:
    path = os.path.join(GAME, "data", "gear", kind + ".tres")
    text = open(path, encoding="utf-8").read()
    m = re.search(r"^grip = (\d+)", text, re.M)
    return int(m.group(1)) if m else 0


def find_grip(image: Image.Image, two_handed: bool) -> tuple:
    alpha = image.getchannel("A")
    left, top, right, bottom = alpha.getbbox()
    rows = {}
    for y in range(top, bottom):
        xs = [x for x in range(left, right) if alpha.getpixel((x, y)) > 100]
        if xs:
            rows[y] = (min(xs), max(xs))
    if two_handed:
        y = top + int((bottom - top) * 0.68)
    else:
        # Up from the pommel until the handle ends - the first row much wider
        # than the handle is the guard, or the blade of a knife that has none.
        # The widest row is not it: a cleaver's blade is wider than any guard,
        # and an axe's widest row is its head.
        # The pommel is the last few rows and is often wider than the grip -
        # a ring, a knob, a swept guard's tail - so the grip's width is
        # measured above it and the scan starts above it.
        span = bottom - top
        pommel = bottom - max(4, int(span * 0.08))
        base_rows = [rows[y][1] - rows[y][0] for y in range(pommel - max(4, span // 8), pommel) if y in rows]
        base = sorted(base_rows)[len(base_rows) // 2] if base_rows else 4
        guard = top
        for y in range(pommel - 1, top, -1):
            if y in rows and rows[y][1] - rows[y][0] >= max(base * 1.8, base + 4):
                guard = y
                break
        if guard >= top + span * 0.45:
            y = guard + max(3, int((bottom - guard) * 0.42))
        else:
            # The handle is most of the weapon - an axe, a rod, a hammer - and
            # one hand holds it near the end.
            y = top + int(span * 0.8)
    y = min(max(y, top), bottom - 1)
    while y not in rows and y > top:
        y -= 1
    x = (rows[y][0] + rows[y][1]) / 2.0
    return (round(x, 1), float(y)), top


def main() -> None:
    folder = sys.argv[1]
    out_dir = os.path.join(GAME, "art", "hero", "held")
    os.makedirs(out_dir, exist_ok=True)
    meta_path = os.path.join(GAME, "data", "dress", "held.json")
    os.makedirs(os.path.dirname(meta_path), exist_ok=True)
    table = {}
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".png"):
            continue
        kind = name[:-4]
        if not os.path.exists(os.path.join(GAME, "data", "gear", kind + ".tres")):
            print("skipping %s: no weapon of that id" % kind)
            continue
        image = Image.open(os.path.join(folder, name)).convert("RGBA")
        assert image.size == (128, 128), (name, image.size)
        (gx, gy), top = find_grip(image, grip_of(kind) == 1)
        image.save(os.path.join(out_dir, "held_%s.png" % kind))
        table[kind] = {"grip": [gx, gy], "tip": top}
        print("%-20s grip %s tip %d" % (kind, (gx, gy), top))
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(table, f, indent=1, sort_keys=True)
    print("%d held weapons" % len(table))


if __name__ == "__main__":
    main()
