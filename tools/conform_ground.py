"""Folds a generated ground tileset into its region's palette.

    python tools/conform_ground.py jungle
    python tools/conform_ground.py --check jungle desert snow

## Why this exists

PixelLab generates a region's floor from a prose description, and prose does not
constrain a palette. The jungle set came back with 2-7% of every tile in the
magenta band -- purple flecks scattered through what was asked for as "warm brown
soil" -- an earth that had drifted to salmon, and a moss saturated to neon. None
of that is wrong enough for the generator to reject and all of it is wrong on
screen: the flecks cluster into pink patches, and a neon green floor makes every
muted, painterly sprite standing on it look pasted in.

Regenerating is the wrong lever. It is slow, it costs credits, and it re-rolls
everything -- including the parts that were right -- against a prompt that has
already shown it cannot express "these hues and no others".

So this is a **conform pass, not a paint pass**. It moves hues that are outside a
region's gamut to the nearest edge, caps saturation, and folds generated value
outliers into the act's exposure envelope. It invents nothing, it draws nothing,
and it is deterministic: the same input always produces the same output, so the
committed PNG is reproducible from the generated one.

## The rule

Each region declares the hue arcs its floor is allowed to occupy and a saturation
ceiling. Every pixel is examined once:

  - a hue inside an allowed arc is left where it is
  - a hue outside every arc is moved to the nearest arc edge
  - saturation above the ceiling is scaled down to it

  - regions with a value envelope clamp outliers into that envelope

The value clamp exists because prompt wording did not stop snow rims reaching
pure white or dark hardpan reaching near-black. A global per-region mapping
preserves every edge and detail while keeping both materials on one moody plane.
"""

import colorsys
import sys
from pathlib import Path

from PIL import Image

ART = Path(__file__).resolve().parent.parent / "game" / "art" / "terrain"

# Hue is in turns, not degrees: 0.0 red, 0.083 orange, 0.25 green, 0.5 cyan.
# An arc whose start is above its end wraps through 1.0; none currently does.
#
# Arcs are taken from where each region's pixels actually sit, not from an idea
# of where they ought to. Measured over all sixteen tiles of each set:
#
#   jungle  hue p2-p98  0.02 .. 0.96   with 13% of it in the magenta band
#   desert  hue p2-p98  0.02 .. 0.15   no magenta, saturation never above 0.47
#   snow    hue p2-p98  0.40 .. 0.70   no magenta, saturation p50 0.21
#
# Which is the finding: **only the jungle set is out of gamut.** Desert and snow
# are declared here anyway, at bounds that are no-ops for the current art, so
# that a future regeneration of either is measured against something rather than
# trusted.
REGIONS = {
    # Wet umber, blue-green standing water and near-red dead roots. The separated
    # arcs deliberately leave magenta/purple out without folding the generated
    # teal material into brown and destroying the two-material read.
    "jungle": {"arcs": [(0.00, 0.15), (0.40, 0.60), (0.90, 1.00)],
               "saturation": 0.55},
    # Smoky umber hardpan and petrol-blue saltglass are both intentional.
    "desert": {"arcs": [(0.01, 0.17), (0.50, 0.68)],
               "saturation": 0.48, "value_range": (0.16, 0.58)},
    # Oxblood basalt under dirty blue snow: two restrained temperature families.
    "snow": {"arcs": [(0.00, 0.08), (0.50, 0.72), (0.94, 1.00)],
             "saturation": 0.48, "value_range": (0.18, 0.54)},
}


def _in_arc(hue: float, low: float, high: float) -> bool:
    if low <= high:
        return low <= hue <= high
    return hue >= low or hue <= high


def _distance(hue: float, edge: float) -> float:
    """Shortest way round the colour wheel, which is circular."""
    raw = abs(hue - edge)
    return min(raw, 1.0 - raw)


# Folded hues land this far *inside* the arc rather than exactly on its edge.
#
# Without it the pass is not idempotent, which matters more than it sounds: a
# hue folded to exactly 0.36 becomes 8-bit RGB, and converting that back finds
# 0.3601 — outside the arc again. Run the pass twice and it folds the same
# pixels a second time, and a third, quietly walking the art away from the
# generated original with every invocation.
INSET = 0.004


def _fold(hue: float, arcs: list[tuple[float, float]]) -> float:
    """The nearest allowed hue, or the hue itself when it is already allowed."""
    for low, high in arcs:
        if _in_arc(hue, low, high):
            return hue
    best = None
    for low, high in arcs:
        for edge, inset in ((low, INSET), (high, -INSET)):
            candidate = (edge + inset) % 1.0
            distance = _distance(hue, edge)
            if best is None or distance < best[0]:
                best = (distance, candidate)
    return best[1]


def conform(region: str, check_only: bool) -> int:
    rules = REGIONS[region]
    arcs = rules["arcs"]
    ceiling = rules["saturation"]
    folded_count = 0
    capped_count = 0
    graded_count = 0
    total = 0

    for mask in range(16):
        path = ART / ("ground_%s_%02d.png" % (region, mask))
        image = Image.open(path).convert("RGBA")
        pixels = image.load()
        width, height = image.size

        for y in range(height):
            for x in range(width):
                r, g, b, a = pixels[x, y]
                if a <= 128:
                    continue
                total += 1
                h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)

                # Grey has no meaningful hue, so folding it would invent one.
                folded = h if s < 0.08 else _fold(h, arcs)
                # Capped just under the ceiling, for the same round-trip reason
                # the fold is inset — and only when it is over by more than the
                # inset. On a dark pixel, saturation is (max-min)/max with a
                # small max, so its 8-bit steps are coarse and a value cannot
                # always be represented under the ceiling at all. Without the
                # tolerance those pixels are "capped" on every run forever, and
                # the pass reports work it did not do.
                capped = min(s, ceiling - INSET) if s > ceiling + INSET else s
                graded = v
                if "value_range" in rules:
                    low, high = rules["value_range"]
                    graded = min(max(v, low), high)
                if folded == h and capped == s and graded == v:
                    continue
                nr, ng, nb = colorsys.hsv_to_rgb(folded, capped, graded)
                output = (round(nr * 255), round(ng * 255), round(nb * 255))
                # HSV values can remain microscopically beyond a limit after an
                # 8-bit round trip even when the resulting RGB is already exact.
                # Comparing the actual bytes is what makes the pass idempotent.
                if output == (r, g, b):
                    continue
                if folded != h:
                    folded_count += 1
                if capped != s:
                    capped_count += 1
                if graded != v:
                    graded_count += 1
                if check_only:
                    continue
                pixels[x, y] = (*output, a)

        if not check_only:
            image.save(path)

    # Reported apart, because they are different kinds of edit. Folding a hue
    # replaces a colour; capping a saturation grades one. A pass that folds a
    # lot is repainting the art and should be a regeneration instead.
    verb = "would fold" if check_only else "folded"
    share = 100.0 / max(total, 1)
    print("  %-7s %s %d hues (%.1f%%), capped %d saturations (%.1f%%), graded %d values, of %d pixels"
          % (region, verb, folded_count, folded_count * share,
             capped_count, capped_count * share, graded_count, total))
    return folded_count


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = "--check" in sys.argv
    for name in args or sorted(REGIONS):
        conform(name, only)
