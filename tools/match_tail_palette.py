"""Paint Yuri's tail in the colours of the hide it grows out of.

The beast's body and its tail were generated separately, and for three reports
running the tail has read as a different animal joined at the hip - lighter,
greyer, bluer, depending on the light it was seen in. Two attempts to fix it
were a `modulate` on the tail: one darkened it, the next pushed it green. Both
were measured, both were wrong, and both had to be, because a single gain
cannot make one *distribution* of colours into another. The owner's brief was
"identically", and identical is a property of the pixels.

So this rewrites the tail's pixels. The reference is the body's own hide at the
join - the stub, the haunch, the belly and the rear legs, which is the lower
left of every body frame and carries none of the town - and every tail frame is
histogram-matched to it, channel by channel: the tail's darkest pixel becomes
the hide's darkest, its median the hide's median, its brightest the hide's
brightest, and everything between lands where the same share of the hide does.
The tail keeps its own shading - the tip is still the tip, the underside still
the underside - and gives up only its palette.

  python tools/match_tail_palette.py [--check]

**One mapping for every frame.** The tail's own distribution is pooled across
all its frames before the mapping is built, so a walk frame and an idle frame
that agreed before still agree after; matching each frame on its own would let
the palette breathe with the animation.

**It runs on the drawing, never on its own output.** Every file it writes
carries a `Wilderhold-palette` chunk and is refused on a second pass; restore
the originals from git before running it against a different reference.
`beast_tail_check` measures the result rather than trusting it.
"""

from __future__ import annotations

import argparse
import pathlib
import sys

import numpy as np
from PIL import Image
from PIL.PngImagePlugin import PngInfo

ART = pathlib.Path(__file__).resolve().parent.parent / "game" / "art" / "beast"
BODY_FRAMES = sorted(ART.glob("beast_walk_*.png"))
TAIL_FRAMES = sorted(ART.glob("beast_tail*.png"))

# The hide at the join, in the body frame: rows from the middle down and the
# left third of the canvas. Above that is the town on the beast's back; to the
# right is the flank the tail never touches. Verified by eye on a mask.
HIDE_ROWS_FROM = 96
HIDE_COLS_TO = 96

SOLID = 128
PROVENANCE = "Wilderhold-palette"


def opaque_pixels(image: Image.Image, box=None) -> np.ndarray:
    arr = np.asarray(image.convert("RGBA"))
    if box is not None:
        y0, y1, x0, x1 = box
        arr = arr[y0:y1, x0:x1]
    return arr[arr[:, :, 3] >= SOLID][:, :3].astype(np.float64)


def reference_hide() -> np.ndarray:
    pooled = []
    for frame in BODY_FRAMES:
        pooled.append(opaque_pixels(Image.open(frame),
            (HIDE_ROWS_FROM, None, 0, HIDE_COLS_TO)))
    if not pooled:
        raise SystemExit("no body frames under %s" % ART)
    return np.concatenate(pooled)


def build_lut(source: np.ndarray, reference: np.ndarray) -> np.ndarray:
    """A 256-entry map per channel taking the source's CDF onto the reference's."""
    lut = np.zeros((3, 256), dtype=np.uint8)
    for channel in range(3):
        src_hist = np.bincount(source[:, channel].astype(int), minlength=256)
        ref_hist = np.bincount(reference[:, channel].astype(int), minlength=256)
        src_cdf = np.cumsum(src_hist) / max(src_hist.sum(), 1)
        ref_cdf = np.cumsum(ref_hist) / max(ref_hist.sum(), 1)
        ref_values = np.arange(256)
        # For every source value, the reference value at the same share of the
        # distribution.
        lut[channel] = np.clip(np.interp(src_cdf, ref_cdf, ref_values) + 0.5,
            0, 255).astype(np.uint8)
    return lut


def summarise(pixels: np.ndarray) -> str:
    mean = pixels.mean(axis=0)
    lum = pixels @ np.array([0.2126, 0.7152, 0.0722])
    return "mean (%5.1f %5.1f %5.1f) lum %5.1f  R/G %.3f B/G %.3f" % (
        mean[0], mean[1], mean[2], lum.mean(), mean[0] / mean[1], mean[2] / mean[1])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report and write nothing")
    args = parser.parse_args()

    frames = []
    for path in TAIL_FRAMES:
        image = Image.open(path)
        if image.info.get(PROVENANCE, ""):
            print("%-26s already matched (%s)" % (path.name, image.info[PROVENANCE]))
            continue
        frames.append((path, image.convert("RGBA")))
    if not frames:
        print("nothing to do")
        return 0

    reference = reference_hide()
    pooled = np.concatenate([opaque_pixels(image) for _, image in frames])
    print("hide  %s  (%d px over %d body frames)" % (summarise(reference), len(reference), len(BODY_FRAMES)))
    print("tail  %s  (%d px over %d tail frames)" % (summarise(pooled), len(pooled), len(frames)))
    lut = build_lut(pooled, reference)

    written = 0
    for path, image in frames:
        arr = np.asarray(image).copy()
        solid = arr[:, :, 3] >= SOLID
        for channel in range(3):
            arr[:, :, channel][solid] = lut[channel][arr[:, :, channel][solid]]
        after = arr[solid][:, :3].astype(np.float64)
        line = "%-26s -> %s" % (path.name, summarise(after))
        if args.check:
            print(line + "  (check only)")
            continue
        stamp = PngInfo()
        stamp.add_text(PROVENANCE, "hide rows %d+ cols <%d, %d body frames"
            % (HIDE_ROWS_FROM, HIDE_COLS_TO, len(BODY_FRAMES)))
        Image.fromarray(arr, mode="RGBA").save(path, optimize=True, pnginfo=stamp)
        written += 1
        print(line)
    print("%d of %d frames rewritten" % (written, len(frames)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
