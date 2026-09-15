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

**Line art is not shading, and conflating the two is what went wrong.** A
histogram match is the right tool for a surface and the wrong one for an
outline. The tail carries 13.7% of its pixels at pure black - its outline and
its interior line work - and the hide carries 10.2% at value 3, which is the
same thing drawn a shade off black. Matching them as one distribution has to
push the tail's surplus black *upward*, and it did: measured after the first
cut, the tail had **0.0%** of its pixels below luminance 0.04 against the
hide's 13.5%. Its outline had been turned to grey. Beside a body still drawn
with crisp black lines and black moss hanging off it, the tail read as a flat,
lighter, plastic thing joined at the hip - which is what three owner reports
were describing while every global average agreed with itself.

So the line is separated from the surface. Pixels dark enough in every channel
to be ink are held out of the match and set to the ink the *body* is drawn
with; everything else is matched as before. The tail keeps its outline, and the
outline is the body's colour.

**And then its tones, which is the half the first cut missed.** Matching the
three channels independently makes the tail *the same colour* as the hide and
says nothing about how its light is distributed, and the fourth report was
about exactly that gap: measured after the first cut, 13.5% of the hide's
pixels sat below luminance 0.04 - the crevices between the plates and the moss
hanging off them - and **0.0% of the tail's did**. Not one true black in the
whole tail. Beside a body full of deep shadow it read as a flat, lighter,
plastic thing joined at the hip, which is what three owner reports had been
describing while every global average agreed.

So there is a second pass: the tail's *luminance* is matched to the hide's the
same way, and each pixel is scaled to its new brightness with its chroma ratios
kept. Hue survives the first pass; depth arrives in the second.

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
# At or below this in every channel, a pixel is ink rather than hide. Chosen
# from the two distributions rather than by eye: the hide's black spike sits at
# 3 and its next populated value is 5, while the tail's sits at 0 and its next
# is 3, so anything up to about a dozen is line and everything above it is
# surface. `beast_tail_check` measures the result, not this number.
INK = 12
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


def ink_mask(pixels: np.ndarray) -> np.ndarray:
    """Which pixels are outline rather than hide."""
    return (pixels <= INK).all(axis=-1)


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


def match_luminance(arr: np.ndarray, solid: np.ndarray, reference: np.ndarray) -> np.ndarray:
    """Give the tail the hide's distribution of *light*, keeping its colours.

    The per-channel pass above is about hue and it cannot see this: three
    channels can each land on the reference's distribution while the pixels
    they make up never go properly dark, because a dark pixel needs all three
    low *at once*. The hide's blacks are the crevices between its plates and
    the moss hanging off it, and a tail without them is a different material.

    Each pixel is moved to the luminance the same share of the hide sits at,
    and scaled there rather than shifted, so the ratios between its channels -
    which is to say its colour - come through untouched.
    """
    lum_weights = np.array([0.2126, 0.7152, 0.0722])
    tail_lum = arr[:, :, :3][solid] @ lum_weights
    ref_lum = reference @ lum_weights
    bins = np.arange(257)
    tail_hist = np.histogram(tail_lum, bins=bins)[0]
    ref_hist = np.histogram(ref_lum, bins=bins)[0]
    tail_cdf = np.cumsum(tail_hist) / max(tail_hist.sum(), 1)
    ref_cdf = np.cumsum(ref_hist) / max(ref_hist.sum(), 1)
    wanted = np.interp(tail_cdf, ref_cdf, np.arange(256))
    target = np.interp(tail_lum, np.arange(256), wanted)
    # A gain, not an offset. An offset would wash the colour out of the darks
    # and grey the highlights; a gain keeps R:G:B and therefore the hue.
    gain = np.where(tail_lum > 1.0, target / np.maximum(tail_lum, 1e-6), 1.0)
    # **Capped at the hide's own brightest.** A gain on a pixel that was nearly
    # black can be enormous, and one such pixel came out at pure white against
    # a body whose brightest highlight is 248 - a single blown speck on the
    # tail, which at menu scale is a visible star. The hide never goes there,
    # so neither may the tail.
    ceiling = reference.max(axis=0)
    out = arr.copy()
    pixels = arr[:, :, :3][solid].astype(np.float64) * gain[:, None]
    pixels = np.minimum(pixels, ceiling[None, :])
    out[:, :, :3][solid] = np.clip(pixels + 0.5, 0, 255).astype(np.uint8)
    return out


def summarise(pixels: np.ndarray) -> str:
    mean = pixels.mean(axis=0)
    lum = pixels @ np.array([0.2126, 0.7152, 0.0722])
    # `dark` is the share of pixels below a tenth of full brightness. It is the
    # number the first cut of this tool was blind to, so it is printed.
    dark = 100.0 * float((lum < 10.0).mean())
    return "mean (%5.1f %5.1f %5.1f) lum %5.1f  R/G %.3f B/G %.3f  dark %4.1f%%" % (
        mean[0], mean[1], mean[2], lum.mean(), mean[0] / mean[1], mean[2] / mean[1], dark)


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
    # The body's own ink, which is what the tail's outline becomes. A median
    # rather than a mean: an outline is one colour with a few anti-aliased
    # neighbours, and a mean would drag it toward them.
    reference_ink = reference[ink_mask(reference)]
    ink_colour = (np.median(reference_ink, axis=0) if len(reference_ink)
        else np.zeros(3))
    print("ink   %s  (%d px, %.1f%% of the hide)" % (
        " ".join("%5.1f" % value for value in ink_colour),
        len(reference_ink), 100.0 * len(reference_ink) / max(len(reference), 1)))
    print("hide  %s  (%d px over %d body frames)" % (summarise(reference), len(reference), len(BODY_FRAMES)))
    print("tail  %s  (%d px over %d tail frames)" % (summarise(pooled), len(pooled), len(frames)))
    # **Built from the surfaces only.** Feeding both outlines in is what turned
    # the tail's black lines to grey; holding them out lets the surface match
    # land where it should and leaves the line to be set outright.
    lut = build_lut(pooled[~ink_mask(pooled)], reference[~ink_mask(reference)])

    written = 0
    for path, image in frames:
        arr = np.asarray(image).copy()
        solid = arr[:, :, 3] >= SOLID
        ink = solid & ink_mask(arr[:, :, :3])
        hide = solid & ~ink
        for channel in range(3):
            arr[:, :, channel][hide] = lut[channel][arr[:, :, channel][hide]]
        arr = match_luminance(arr, hide, reference[~ink_mask(reference)])
        for channel in range(3):
            arr[:, :, channel][ink] = int(round(float(ink_colour[channel])))
        after = arr[solid][:, :3].astype(np.float64)
        line = "%-26s -> %s" % (path.name, summarise(after))
        if args.check:
            print(line + "  (check only)")
            continue
        stamp = PngInfo()
        stamp.add_text(PROVENANCE, "hide rows %d+ cols <%d, %d body frames, channels+luminance"
            % (HIDE_ROWS_FROM, HIDE_COLS_TO, len(BODY_FRAMES)))
        Image.fromarray(arr, mode="RGBA").save(path, optimize=True, pnginfo=stamp)
        written += 1
        print(line)
    print("%d of %d frames rewritten" % (written, len(frames)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
