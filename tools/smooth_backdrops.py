"""Resolve the beast-scope backdrops' dither into the gradient it stands for.

The ten `art/bg/macro_act*.png` skies are 688x384 pixel art and the beast scope
draws them 1080 world units tall - a 2.8125x magnification, with the nearest
filter every other piece of pixel art in this game wants.

**That magnifies the dithering with them.** A pixel artist draws a sky gradient
as two flat colours in a checkerboard, because at 1:1 the eye blends them; a
1-pixel checker becomes a 3-pixel one on screen at 2.8x, and what the owner sees
is a hard horizontal line with a screen door under it across the whole sky. It
was reported as "dithered banding in the beast scope" on 2026-09-14 and blamed
on two innocent layers before the backdrop art itself was read: `macro_act3.png`
row 126 is a solid line of one colour with a 124/159 checkerboard under it.

So the dither is resolved **offline, once**, rather than by turning the filter to
linear at runtime - which would have smoothed the mountains and the aurora too,
and those are the subject. Only the flat gradients move.

  python tools/smooth_backdrops.py [--factor 3] [--check] [--force]

`--check` reports what would change and writes nothing; `--force` re-processes a
sky this has already written, which is almost always a mistake.

**What counts as dither is a local spread, not a colour count.** Every 3x3
window is measured; a window whose channels span at most `GRADIENT_SPREAD` is a
gradient or a dither and is smoothed, and anything wider is an edge somebody drew
on purpose and is left exactly as it is. That is one threshold rather than a
palette analysis, and it cannot mistake a silhouette for a gradient: a mountain
against the sky spans 128 and a star against night sky 96, while the sky gradient
spans 35 and the moon's halo 82.

**It runs on the drawing, never on its own output.** Smoothing an already
smoothed sky compounds the blur and doubles the file, and nothing about the
result would say so. Every file this writes carries a `Wilderhold-dither` text
chunk and is refused on a second pass; to change the threshold, restore the
originals first (`git show <commit>^:game/art/bg/macro_actN.png`) and run it
again against those.

The blur is **normalised against the mask** (`G(x*m) / G(m)`), so no colour from
outside a smoothed region can bleed into it. A plain blur would have pulled the
mountain's black a third of the way into the sky beside it, which is the same
soft edge the runtime filter was rejected for.

Upscaling is what makes it stick. At 3x the sprite draws at 0.9375 rather than
2.8125, so the backdrop is minified like every other painting in the project and
there is nothing left to magnify.
"""

from __future__ import annotations

import argparse
import pathlib
import sys

import numpy as np
from PIL import Image, ImageFilter
from PIL.PngImagePlugin import PngInfo

# The repo's own art directory, found from this file rather than the cwd.
BACKDROP_DIR = pathlib.Path(__file__).resolve().parent.parent / "game" / "art" / "bg"
BACKDROP_GLOB = "macro_act*.png"

# How far a 3x3 window may span, per channel, and still be called a gradient.
#
# Measured on the ten skies. The sky-gradient dither that caused the report
# spans 35 (124 against 159 on blue) and the band above it 15; a mountain
# silhouette spans 113 to 128 and a star against night sky 96, and both of those
# have to stay exactly as drawn.
#
# **48 was the first value and it was too careful.** It resolved the flat
# gradients and left the moon's halo checkered, because that halo is dithered
# from four values at once - 92, 111, 159 and 174 - and a window holding the two
# ends of it spans 82. The halo is the single most obvious dither left in the
# game at 2.8x, so the threshold has to clear it.
#
# Contact-sheeted at 48, 70, 88 and 110 against the moon, the aurora and the
# mountains. 70 clears the halo but rings the small stars; 110 starts softening
# the snow line on the peaks, which is drawing. 88 clears the halo and the rings
# and leaves the mountains pixel-for-pixel what they were. [TUNE]
GRADIENT_SPREAD = 88

# Blur radius, in *source* pixels. One source pixel is the dither's own period,
# so a radius of one covers a checker and a little more; anything larger starts
# flattening the bands the gradient is made of into a single wash.
BLUR_SOURCE_RADIUS = 1.15


def spread_mask(pixels: np.ndarray, spread: int) -> np.ndarray:
    """True where a 3x3 window is flat enough to be a gradient rather than an edge."""
    height, width, _ = pixels.shape
    # Nine shifted copies, edge-clamped, so the window is defined everywhere.
    stack = []
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            shifted = np.roll(np.roll(pixels, dy, axis=0), dx, axis=1)
            if dy == -1:
                shifted[-1, :, :] = pixels[-1, :, :]
            elif dy == 1:
                shifted[0, :, :] = pixels[0, :, :]
            if dx == -1:
                shifted[:, -1, :] = pixels[:, -1, :]
            elif dx == 1:
                shifted[:, 0, :] = pixels[:, 0, :]
            stack.append(shifted)
    window = np.stack(stack, axis=0).astype(np.int16)
    span = window.max(axis=0) - window.min(axis=0)
    widest = span.max(axis=2)
    # Zero spread is a flat area with nothing to resolve; leaving it out of the
    # mask keeps the normalised blur's denominator meaningful where it matters.
    return (widest > 0) & (widest <= spread)


# Stamped into every sky this writes, and refused on the way back in.
PROVENANCE = "Wilderhold-dither"


def smooth(path: pathlib.Path, factor: int, check: bool,
        force: bool = False) -> tuple[bool, str]:
    source = Image.open(path)
    already = source.info.get(PROVENANCE, "")
    if already and not force:
        return False, "%-20s already resolved (%s)" % (path.name, already)
    had_alpha = source.mode in ("RGBA", "LA") or "transparency" in source.info
    source = source.convert("RGBA" if had_alpha else "RGB")
    pixels = np.asarray(source, dtype=np.uint8)
    mask = spread_mask(pixels[:, :, :3], GRADIENT_SPREAD)
    share = float(mask.mean())
    if share <= 0.0:
        return False, "%-20s nothing to resolve" % path.name

    big = source.resize((source.width * factor, source.height * factor), Image.NEAREST)
    big_mask = Image.fromarray((mask * 255).astype(np.uint8)).resize(
        big.size, Image.NEAREST)

    radius = BLUR_SOURCE_RADIUS * factor
    weight = np.asarray(big_mask.filter(ImageFilter.GaussianBlur(radius)),
        dtype=np.float32) / 255.0
    plate = np.asarray(big, dtype=np.float32)
    keep = np.asarray(big_mask, dtype=np.float32)[:, :, None] / 255.0

    # G(x * m) / G(m): only masked pixels contribute, so an edge outside the mask
    # cannot bleed across it. Where the weight is negligible the original stands.
    carried = np.zeros_like(plate)
    for channel in range(plate.shape[2]):
        lit = Image.fromarray((plate[:, :, channel] * keep[:, :, 0]).astype(np.uint8))
        carried[:, :, channel] = np.asarray(
            lit.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32)
    safe = np.maximum(weight, 1e-4)[:, :, None]
    resolved = carried / safe

    blend = np.clip(weight, 0.0, 1.0)[:, :, None] * keep
    out = plate * (1.0 - blend) + resolved * blend
    if had_alpha:
        # Alpha is a shape, never a gradient to resolve: a softened edge here is
        # a halo round the whole painting.
        out[:, :, 3] = plate[:, :, 3]
    result = Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8),
        mode="RGBA" if had_alpha else "RGB")

    line = "%-20s %dx%d -> %dx%d  %.1f%% resolved" % (path.name, source.width,
        source.height, result.width, result.height, share * 100.0)
    if check:
        return False, line + "  (check only)"
    stamp = PngInfo()
    stamp.add_text(PROVENANCE, "spread %d, blur %.2f, %dx"
        % (GRADIENT_SPREAD, BLUR_SOURCE_RADIUS, factor))
    result.save(path, optimize=True, pnginfo=stamp)
    return True, line + "  %d KB" % (path.stat().st_size // 1024)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factor", type=int, default=3,
        help="upscale factor; 3 takes the sky from 2.8x magnified to 0.94x minified")
    parser.add_argument("--check", action="store_true",
        help="report and write nothing")
    parser.add_argument("--force", action="store_true",
        help="re-process a sky this has already written; compounds the blur")
    args = parser.parse_args()
    if args.factor < 1:
        print("factor must be at least 1", file=sys.stderr)
        return 2

    paths = sorted(BACKDROP_DIR.glob(BACKDROP_GLOB),
        key=lambda p: int("".join(c for c in p.stem if c.isdigit()) or 0))
    if not paths:
        print("no backdrops under %s" % BACKDROP_DIR, file=sys.stderr)
        return 1
    written = 0
    for path in paths:
        did, line = smooth(path, args.factor, args.check, args.force)
        written += 1 if did else 0
        print(line)
    print("%d of %d rewritten" % (written, len(paths)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
