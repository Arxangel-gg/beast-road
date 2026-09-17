"""Brings a generated ground sheet into the palette this game is painted in.

    python tools/grade_to_ground.py <png> [<png> ...] --value 1.15 --sat 0.34

**Why this exists.** Owner, 2026-09-17, on the first photograph of the Hold's
new tilesets: *"that green is too bright and not fitting for the game's
aesthetic"*. Measured rather than argued:

    valley floor (terrain_jungle)   value 0.198   saturation 0.302
    generated turf                  value 0.363   saturation 0.551
    generated flagstones            value 0.443   saturation 0.028

So every sheet came back at roughly **twice the brightness and twice the
saturation** of the ground it has to sit beside. That is not a tint anybody
chose; it is what a generator hands over, and it is the same finding the gear
icons cost this project once before - a batch that is internally consistent,
readable, and obviously from a different game the moment it is put beside what
ships.

**Why it is baked rather than modulated.** A `modulate` multiplies, so it can
darken and it cannot desaturate: pulling a vivid green toward the muted olive
of this game's ground needs to know where grey is. Baking also means the file
on disk *is* the game's palette, so the next person to open it sees what ships
rather than a source that disagrees with the render.

**What it preserves.** Hue, exactly. Grass stays green and stone stays grey;
what changes is the light they are standing in. The value is matched to the
reference times a factor - a shelf catches a little more light than the valley
floor it rises out of, and cut stone more than soil - and the saturation is set
outright, because "how colourful is this ground" is the thing that was wrong.

Idempotent in the way that matters: the tileset installer re-fetches from
PixelLab every run, so a graded sheet is always graded once from the source.
Run by hand on a file already on disk, it will grade what it finds - so pass
`--from` to restate the reference and check the printed before/after.
"""
from __future__ import annotations

import argparse
import colorsys
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

## The ground every other ground in the Hold has to belong beside.
REFERENCE = os.path.join(ROOT, "game", "art", "terrain", "terrain_jungle.png")

## Below this alpha a pixel is not part of the material and is not measured -
## a transparent margin averaged in drags every figure toward nothing.
OPAQUE = 40


def measure(image) -> tuple[float, float]:
    """The mean value and saturation of everything opaque in an image."""
    px = image.load()
    w, h = image.size
    value = 0.0
    sat = 0.0
    seen = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < OPAQUE:
                continue
            _hue, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            value += v
            sat += s
            seen += 1
    if seen == 0:
        return (0.0, 0.0)
    return (value / seen, sat / seen)


def grade(path: str, want_value: float, want_sat: float, reference: str,
          want_hue: float = -1.0, hue_pull: float = 0.0) -> str:
    from PIL import Image
    with Image.open(reference) as source:
        ground = source.convert("RGBA")
    base_value, base_sat = measure(ground)
    with Image.open(path) as source:
        sheet = source.convert("RGBA")
    was_value, was_sat = measure(sheet)
    if was_value <= 0.001:
        raise SystemExit("%s has nothing opaque in it" % path)

    # The value is *scaled* so the material keeps its own internal contrast -
    # a flat set-to-the-mean would iron every tile into one colour - and the
    # saturation is set, because how colourful the ground is is the thing that
    # was wrong rather than how varied it is.
    lift = (base_value * want_value) / was_value
    px = sheet.load()
    w, h = sheet.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hue, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if hue_pull > 0.0 and want_hue >= 0.0:
                # Pulled the short way round the wheel, so a cold blue-grey
                # warms toward the valley's own light rather than travelling
                # through green to get there.
                var_gap = ((want_hue / 360.0) - hue + 1.5) % 1.0 - 0.5
                hue = (hue + var_gap * hue_pull) % 1.0
            v = min(v * lift, 1.0)
            s = min(s * (want_sat / was_sat) if was_sat > 0.001 else s, 1.0)
            nr, ng, nb = colorsys.hsv_to_rgb(hue, s, v)
            px[x, y] = (int(round(nr * 255.0)), int(round(ng * 255.0)),
                        int(round(nb * 255.0)), a)
    sheet.save(path)
    now_value, now_sat = measure(sheet)
    return ("%s  value %.3f -> %.3f (ground %.3f)  sat %.3f -> %.3f"
            % (os.path.basename(path), was_value, now_value, base_value,
               was_sat, now_sat))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("sheets", nargs="+")
    parser.add_argument("--value", type=float, default=1.15,
                        help="share of the reference's mean value to sit at")
    parser.add_argument("--sat", type=float, default=0.34,
                        help="mean saturation to set the material to")
    parser.add_argument("--hue", type=float, default=-1.0,
                        help="hue in degrees to pull the material toward")
    parser.add_argument("--hue-pull", type=float, default=0.0,
                        help="how far of the way to that hue, 0 to 1")
    parser.add_argument("--from", dest="reference", default=REFERENCE)
    args = parser.parse_args()
    for sheet in args.sheets:
        print(grade(sheet, args.value, args.sat, args.reference,
                    args.hue, args.hue_pull))
    return 0


if __name__ == "__main__":
    sys.exit(main())
