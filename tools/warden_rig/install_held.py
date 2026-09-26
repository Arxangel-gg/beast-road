"""Install the held weapon pictures and record where each one is held.

    python install_held.py <folder of <weapon id>.png>
    python install_held.py --installed      re-measure what is already installed

Each picture is drawn blade-up on a 128 canvas (PixelLab Pro Flash, `view:
side`, the weapon's own icon as the style image). It is installed as it was
drawn, at `game/art/hero/held/held_<id>.png`, and three things about it are
written to `game/data/dress/held.json`, in the picture's own pixels, so the
runtime can lay the weapon in a fist without reading the image:

- `grip` - the point the fist closes on;
- `tip` - the top of the blade, which the weapon's drawn length is measured to;
- `hilt` - the first and last rows of the handle the grip is on: what a fist
  may cover. The game draws the stretch of it under each gripping fist
  *behind* the body, so the fingers close over the handle, and everything else
  - the guard, the blade, the pommel - in front (owner, 2026-09-25: *"make sure
  the part of the hand that grips the weapon gets zsorted over the blade"*). A
  band that reached past the hilt would put a guard or a blade behind the fist,
  so the hilt is what bounds it.

**The handle is found, not typed**, and by what a handle is: the narrowest
sustained stretch in the lower half of a blade, grown up and down until the
picture widens - a guard, a head, a pommel ring - or, on a grip of wood or
leather, until it turns to bare metal: a knife's blade can be narrower than
its handle, and it is the material that says where one ends. A haft is all
handle until its head, so only the width bounds it - and nothing is handle
more than half the way from the grip to the tip, so a rod that is handle from
end to end still keeps its head out from under the fist.

**Where the fist closes** is a third of the way down a one-handed hilt, just
under the guard. On a two-handed haft it is the right hand's place, two thirds
of the way down the weapon, with the left a hand and a half below it along the
haft (the rig puts it there). A weapon added tomorrow is installed by the same
rule.
"""
from __future__ import annotations

import colorsys
import json
import math
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", "..", "game"))

OPAQUE = 100                 # alpha above this is part of the weapon
WIDER = 1.6                  # a row this much wider than the handle has left it...
WIDER_PX = 3                 # ...and by at least this many pixels
METAL_ROWS = 2               # rows of bare metal that end a grip of wood or leather
GRIP_COLOURED = 0.35         # a grip this saturated is wood or leather, and metal ends it
HILT_REACH = 0.5             # a hilt ends at most this share of the way from the grip to the tip
GRIP_DOWN_TWO_HAND = 0.68    # and this far down a two-handed weapon


def held_dir() -> str:
    return os.path.join(GAME, "art", "hero", "held")


def meta_path() -> str:
    return os.path.join(GAME, "data", "dress", "held.json")


def grip_of(kind: str) -> int:
    path = os.path.join(GAME, "data", "gear", kind + ".tres")
    text = open(path, encoding="utf-8").read()
    m = re.search(r"^grip = (\d+)", text, re.M)
    return int(m.group(1)) if m else 0


def _run(alpha, y: int, x: int, width: int):
    """The opaque run on row `y` holding column `x`, or the one nearest it."""
    runs, start = [], None
    for i in range(width + 1):
        on = i < width and alpha[i, y] > OPAQUE
        if on and start is None:
            start = i
        elif not on and start is not None:
            runs.append((start, i - 1))
            start = None
    if not runs:
        return None
    return min(runs, key=lambda r: 0 if r[0] <= x <= r[1] else min(abs(x - r[0]), abs(x - r[1])))


def _metal(rgb, y: int, run):
    """The share of a run that is bare metal - grey, unsaturated, lit - among
    its pixels that are neither outline nor shadow; None when there are none."""
    metal = counted = 0
    for x in range(run[0], run[1] + 1):
        r, g, b = rgb[x, y][:3]
        _, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        if v < 0.25:
            continue
        counted += 1
        metal += 1 if s < 0.25 and v >= 0.30 else 0
    return metal / counted if counted else None


def _grip(runs: dict, top: int, bottom: int, two_handed: bool) -> int:
    """The row the fist closes on (the rule of the first install, kept: every
    grip it placed was seen and accepted, bar one)."""
    span = bottom - top
    if two_handed:
        return top + int(span * GRIP_DOWN_TWO_HAND)
    # Up from the pommel until the handle ends - the first row much wider than
    # the handle is the guard, or the blade of a knife that has none. The
    # widest row is not it: a cleaver's blade is wider than any guard, and an
    # axe's widest row is its head. The pommel is often wider than the grip -
    # a ring, a knob, a swept guard's tail - so the grip's width is measured
    # above it, and **the guard is only looked for once the scan has been on
    # the handle for a few rows**: a pommel ring taller than the rows skipped
    # for it read as a guard, and put the Sunglass Saber's fist on its ring.
    pommel = bottom - max(4, int(span * 0.08))
    base_rows = sorted(runs[y][1] - runs[y][0] + 1 for y in range(pommel - max(4, span // 8), pommel) if y in runs)
    base = base_rows[len(base_rows) // 2] if base_rows else 4
    guard = top
    on_handle = 0
    for y in range(pommel - 1, top, -1):
        if y not in runs:
            continue
        w = runs[y][1] - runs[y][0] + 1
        if w <= base * 1.3 + 1:
            on_handle += 1
        elif on_handle >= 3 and w >= max(base * 1.8, base + 4):
            guard = y
            break
    if guard >= top + span * 0.45:
        return guard + max(3, int((bottom - guard) * 0.42))
    # The handle is most of the weapon - an axe, a rod, a hammer - and one
    # hand holds it near the end.
    return top + int(span * 0.8)


def _saturation(rgb, runs: dict, gy: int) -> float:
    """The median saturation of the grip's own lit pixels, around its row."""
    values = []
    for y in range(gy - 2, gy + 3):
        if y not in runs:
            continue
        for x in range(runs[y][0], runs[y][1] + 1):
            r, g, b = rgb[x, y][:3]
            _, sat, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if v >= 0.25:
                values.append(sat)
    values.sort()
    return values[len(values) // 2] if values else 0.0


def _hilt(image: Image.Image, runs: dict, gy: int, top: int, bottom: int, two_handed: bool) -> list:
    """The handle the grip is on: grown from the grip until the picture widens,
    or - on a grip of wood or leather - turns to bare metal."""
    alpha = image.getchannel("A").load()
    rgb = image.load()
    width = image.size[0]
    base_rows = sorted(runs[k][1] - runs[k][0] + 1 for k in range(gy - 2, gy + 3) if k in runs)
    base = base_rows[len(base_rows) // 2]
    limit = max(base * WIDER, base + WIDER_PX)
    # A haft is handle until its head, whatever it is bound with; and only a
    # grip that is plainly *coloured* - wood, leather, cord - can be told from
    # the metal above it. A dark grey wrap reads as metal to any rule simple
    # enough to trust, and stopped the Sunglass Saber's hilt at its own grip.
    watch_metal = not two_handed and _saturation(rgb, runs, gy) >= GRIP_COLOURED
    ends = []
    for step in (-1, 1):
        x = (runs[gy][0] + runs[gy][1]) // 2
        y = last = gy
        metal_rows = 0
        while top <= y + step <= bottom:
            run = _run(alpha, y + step, x, width)
            if run is None or run[1] - run[0] + 1 > limit or not (run[0] - 1 <= x <= run[1] + 1):
                break
            y += step
            if watch_metal:
                share = _metal(rgb, y, run)
                metal_rows = metal_rows + 1 if share is not None and share > 0.6 else 0
                if metal_rows >= METAL_ROWS:
                    # The handle ended where the metal began.
                    last = y - step * METAL_ROWS
                    break
            last = y
            x = (run[0] + run[1]) // 2
        ends.append(last)
    return ends


def measure(image: Image.Image, two_handed: bool) -> dict:
    alpha = image.getchannel("A").load()
    left, top, right, bottom = image.getchannel("A").getbbox()
    bottom -= 1
    centre = (left + right) // 2
    runs = {}
    for y in range(top, bottom + 1):
        run = _run(alpha, y, centre, image.size[0])
        if run is not None:
            runs[y] = run
    # The grip rule measures its span to the row past the last, as the first
    # install did; measured to the last row, every grip moved by one.
    gy = min(max(_grip(runs, top, bottom + 1, two_handed), top), bottom)
    while gy not in runs and gy > top:
        gy -= 1
    gx = (runs[gy][0] + runs[gy][1]) / 2.0
    hilt = _hilt(image, runs, gy, top, bottom, two_handed)
    # However much of a rod or a knife is handle, its head end is never under a
    # fist: pointed at the camera, a fist covers most of the picture, and the
    # half of a weapon toward its tip is the half that must stay in front.
    hilt[0] = max(hilt[0], int(math.ceil(gy - HILT_REACH * (gy - top))))
    return {"grip": [round(gx, 1), float(gy)], "tip": top, "hilt": hilt}


def main() -> None:
    installed = sys.argv[1] == "--installed"
    folder = held_dir() if installed else sys.argv[1]
    os.makedirs(held_dir(), exist_ok=True)
    table = {}
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".png"):
            continue
        kind = name[:-4]
        if installed:
            if not kind.startswith("held_"):
                continue
            kind = kind[len("held_"):]
        if not os.path.exists(os.path.join(GAME, "data", "gear", kind + ".tres")):
            print("skipping %s: no weapon of that id" % kind)
            continue
        image = Image.open(os.path.join(folder, name)).convert("RGBA")
        assert image.size == (128, 128), (name, image.size)
        entry = measure(image, grip_of(kind) == 1)
        if not installed:
            image.save(os.path.join(held_dir(), "held_%s.png" % kind))
        table[kind] = entry
        print("%-20s grip %-14s tip %3d hilt %s" % (kind, tuple(entry["grip"]), entry["tip"], entry["hilt"]))
    os.makedirs(os.path.dirname(meta_path()), exist_ok=True)
    with open(meta_path(), "w", encoding="utf-8") as f:
        json.dump(table, f, indent=1, sort_keys=True)
    print("%d held weapons" % len(table))


if __name__ == "__main__":
    main()
