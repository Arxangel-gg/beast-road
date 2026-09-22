"""Sit Yuri's tail in the shadow it grows out of.

    python tools/seat_tail_in_shadow.py [--root 0.82] [--tip 0.98]

**The tenth pass, and the first taken off a magnified photograph of the
join.** Every earlier one measured a statistic: the two paintings' means, their
medians, their channel ratios, their histograms. By 2026-09-22 those agree to
within one percent - body mean 74.5 / sd 36.4 / saturation 0.254 against tail
75.4 / 39.4 / 0.287 - and the owner could still see the seam at a glance.

What a crop of the render shows, and no global statistic can, is *which part*
of the body the limb leaves. The Worldstrider's back is pale plated stone and
its haunch is deep shadow under hanging vine; the tail emerges **from the
haunch** and is painted at the brightness of the **back**. So the limb is right
against the animal as a whole and wrong against the four inches of animal it
touches, which is the only place anybody looks.

So this is a gradient rather than a gain: darkest at the root, easing to
nothing by the tip, luminance only - the chroma is already matched and
touching it is what pushed an earlier attempt green. Run after
`grade_tail_to_stub.py`, which is what makes the *colour* agree; this is what
makes the *light* agree.

Idempotent by construction: it writes a marker file recording the factors it
last applied and re-derives from the original each time, so running it twice
does not darken twice.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import statistics as st

from PIL import Image

ART = os.path.join(os.path.dirname(__file__), "..", "game", "art", "beast")
MARK = os.path.join(ART, ".tail_shadow.json")
INK = 12
ROOT_SHARE = 0.30


def surface(image: Image.Image) -> list:
    return [p for p in image.convert("RGBA").getdata()
            if p[3] > 127 and not (p[0] <= INK and p[1] <= INK and p[2] <= INK)]


def luminance(px: list) -> float:
    return st.mean(0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2] for p in px)


def main() -> None:
    parser = argparse.ArgumentParser()
    # The root sits in the haunch's shadow; the tip hangs in open air and is
    # left where the colour match put it.
    parser.add_argument("--root", type=float, default=0.82)
    parser.add_argument("--tip", type=float, default=0.98)
    args = parser.parse_args()

    was = {}
    if os.path.exists(MARK):
        with open(MARK, encoding="utf-8") as handle:
            was = json.load(handle)
    old_root = float(was.get("root", 1.0))
    old_tip = float(was.get("tip", 1.0))

    tails = sorted(glob.glob(os.path.join(ART, "beast_tail*.png")))
    for path in tails:
        image = Image.open(path).convert("RGBA")
        width, height = image.size
        pixels = image.load()
        for x in range(width):
            # u runs 0 at the tip (left) to 1 at the root (right), because the
            # painting is drawn tip-first and the root is the last column.
            u = x / max(width - 1, 1)
            # Undo whatever the last run applied, then apply this one, so the
            # factor is always measured from the original art.
            before = old_tip + (old_root - old_tip) * u
            now = args.tip + (args.root - args.tip) * u
            factor = now / max(before, 0.001)
            if abs(factor - 1.0) < 0.0005:
                continue
            for y in range(height):
                r, g, b, a = pixels[x, y]
                if a <= 127 or (r <= INK and g <= INK and b <= INK):
                    continue
                pixels[x, y] = (min(255, int(round(r * factor))),
                                min(255, int(round(g * factor))),
                                min(255, int(round(b * factor))), a)
        image.save(path)

    body = Image.open(os.path.join(ART, "beast_idle_00.png"))
    bw, bh = body.size
    haunch = luminance(surface(body.crop((0, int(bh * 0.45), 52, bh))))
    tail = Image.open(tails[0])
    tw, th = tail.size
    root = luminance(surface(tail.crop((int(tw * (1.0 - ROOT_SHARE)), 0, tw, th))))
    whole = luminance(surface(tail))
    print("root %.2f  tip %.2f applied to %d frames" % (args.root, args.tip, len(tails)))
    print("body haunch %.1f   tail root %.1f   tail whole %.1f" % (haunch, root, whole))

    with open(MARK, "w", encoding="utf-8") as handle:
        json.dump({"root": args.root, "tip": args.tip}, handle)


if __name__ == "__main__":
    main()
