"""Crop each beast-scope horizon strip to its own content, on both axes.

`ParallaxStrip` lays a strip down in **mirrored pairs**: one copy, then the same
copy flipped and pushed a full width along, so every join is an edge against its
own reflection and the art needs no tiling constraint. That trick has exactly one
requirement, and it is about the canvas rather than the drawing: **the art must
reach the left and right edges of its own image.** A transparent margin there is
a column of sky at every join, 35 device pixels wide at the scale these are
drawn - three of the ten shipped with one.

The vertical crop is the other half, and it is why these are not all one height.
`ParallaxStrip` scales every strip by the same `band_height / REFERENCE_HEIGHT`,
so a strip trimmed to its content keeps its *stature* relative to the others: the
Iron Steppe is 54 rows of open plain and the Last Terrace is the full 128, and
one number in `Balance` moves the ten together. Padding them all back to 128
would make a sparse horizon as tall as a dense one.

  python tools/trim_skylines.py [--check]

Idempotent - a strip already tight against its content is left alone - so run it
after generating a replacement and put the height it reports into
`docs/ASSET_MANIFEST.md`, which `run_tool.gd -- report` reads.
"""

from __future__ import annotations

import argparse
import pathlib
import sys

from PIL import Image

STRIP_DIR = pathlib.Path(__file__).resolve().parent.parent / "game" / "art" / "beast"
STRIP_GLOB = "skyline_*.png"

# Below this an alpha is a generator's stray haze rather than drawing, and
# cropping to it would keep a margin that is invisible but still empty.
SOLID_ENOUGH = 8


def content_box(image: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A").point(lambda v: 255 if v > SOLID_ENOUGH else 0)
    return alpha.getbbox()


def trim(path: pathlib.Path, check: bool) -> tuple[bool, str]:
    image = Image.open(path).convert("RGBA")
    box = content_box(image)
    if box is None:
        return False, "%-28s is empty" % path.name
    left, top, right, bottom = box
    wide, tall = image.size
    if (left, top, right, bottom) == (0, 0, wide, tall):
        return False, "%-28s %dx%d already tight" % (path.name, wide, tall)
    cut = "L%d R%d T%d B%d" % (left, wide - right, top, tall - bottom)
    line = "%-28s %dx%d -> %dx%d  cut %s" % (path.name, wide, tall,
        right - left, bottom - top, cut)
    if check:
        return False, line + "  (check only)"
    image.crop(box).save(path, optimize=True)
    return True, line


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
        help="report and write nothing")
    args = parser.parse_args()
    paths = sorted(STRIP_DIR.glob(STRIP_GLOB))
    if not paths:
        print("no horizon strips under %s" % STRIP_DIR, file=sys.stderr)
        return 1
    cropped = 0
    for path in paths:
        did, line = trim(path, args.check)
        cropped += 1 if did else 0
        print(line)
    print("%d of %d cropped" % (cropped, len(paths)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
