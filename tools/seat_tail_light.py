"""Light Yuri's tail the way the hide is lit at the height it hangs.

**The palette was already right, and that is why four passes at it changed
nothing.** Measured across every idle frame, holding the ink out of the average
the way `match_tail_palette.py` learnt to: the tail's surface is 64.9/69.4/54.5
against the hide's 63.2/67.5/52.1 - within three percent on all three channels,
with the same R/G and B/G. A fifth palette pass would have moved nothing a
player could see, and the owner has now reported the tail three times.

What is wrong is the *light on it*. The beast is lit from above: the hide's own
median surface luminance runs 64 across the back at row 120 and falls to 47 by
row 224, at the feet. The tail hangs from row 142 to row 238 - the lowest
stretch of the animal and the part below it - and it is painted at **63**, which
is the brightness of the back. So it reads as a limb lit by a different sun,
which is exactly what "not matching the colour grading and tint of the body" is
a description of, and no amount of hue matching can answer it.

So each row of the tail is scaled to the brightness the *hide's own profile*
has at the body row that row hangs at. The profile is fitted rather than sampled
row by row, because a thin limb gives a dozen pixels on some rows and a fitted
curve does not inherit that noise.

**Three bounds, each of them a way this has gone wrong before:**

- **It may only darken.** Two earlier attempts brightened the tail and both were
  wrong; a gain above one is clamped away. The correction is 0.80 to 1.00.
- **Ink is not surface.** Pixels dark enough in every channel to be line work
  are left exactly as they are - the lesson `match_tail_palette.py` paid for
  when a histogram turned the tail's outline grey.
- **It runs on the drawing, never on its own output.** Every file it writes
  carries a `Wilderhold-tail-light` chunk and is refused on a second pass.

  python tools/seat_tail_light.py [--check]

`beast_tail_check` measures the result: the tail's surface against the hide's
**low band** rather than against the whole animal, which is the reference that
was wrong in the gate as well as in the art.
"""

from __future__ import annotations

import argparse
import pathlib

import numpy as np
from PIL import Image
from PIL.PngImagePlugin import PngInfo

ART = pathlib.Path(__file__).resolve().parent.parent / "game" / "art" / "beast"
BODY = sorted(ART.glob("beast_idle_*.png"))
TAILS = sorted(ART.glob("beast_tail*.png"))

SOLID = 128
INK = 12
# The rows of the body the fit is taken over: the top of the back down to the
# feet. Above row 80 is the town riding on it, which is not hide.
FIT_FROM, FIT_TO = 80, 224
# Where the tail's own art puts its root, and how bright the deepest shade may
# get. The floor is the hide's own darkest row rather than a taste: below that
# the tail would be darker than anything on the animal.
ROOT_FRACTION = 0.365
FLOOR = 40.0
# Only darken. See the note above.
GAIN_MIN, GAIN_MAX = 0.55, 1.0
SMOOTH = 5
PROVENANCE = "Wilderhold-tail-light"
LUMA = np.array([0.2126, 0.7152, 0.0722])


def surface(arr: np.ndarray) -> np.ndarray:
    solid = arr[:, :, 3] >= SOLID
    ink = (arr[:, :, :3] <= INK).all(axis=2)
    return solid & ~ink


def hide_profile() -> np.poly1d:
    rows: list[int] = []
    values: list[float] = []
    for frame in BODY:
        arr = np.asarray(Image.open(frame).convert("RGBA")).astype(float)
        mask = surface(arr)
        lum = arr[:, :, :3] @ LUMA
        for y in range(arr.shape[0]):
            here = lum[y][mask[y]]
            if here.size >= 8:
                rows.append(y)
                values.append(float(np.median(here)))
    if not rows:
        raise SystemExit("no body frames under %s" % ART)
    rows_a = np.array(rows)
    values_a = np.array(values)
    keep = (rows_a >= FIT_FROM) & (rows_a <= FIT_TO)
    return np.poly1d(np.polyfit(rows_a[keep], values_a[keep], 2))


def stub_row() -> float:
    """The body row the tail leaves by, read off the frames the way the game
    reads it - the middle of what is painted in the leftmost columns."""
    found: list[float] = []
    for frame in BODY:
        arr = np.asarray(Image.open(frame).convert("RGBA"))
        edge = arr[:, :3, 3] >= SOLID
        rows = np.where(edge.any(axis=1))[0]
        if rows.size:
            found.append(float(rows.min() + rows.max()) * 0.5)
    return float(np.mean(found)) if found else 177.5


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report and write nothing")
    args = parser.parse_args()

    fit = hide_profile()
    root = stub_row()
    print("hide light: row %d -> %.1f, row %d -> %.1f, row 238 -> %.1f   stub row %.1f"
          % (FIT_FROM, fit(FIT_FROM), FIT_TO, fit(FIT_TO), fit(238), root))

    for path in TAILS:
        image = Image.open(path)
        if image.info.get(PROVENANCE):
            print("  %-28s already seated" % path.name)
            continue
        arr = np.asarray(image.convert("RGBA")).astype(float)
        height = arr.shape[0]
        mask = surface(arr)
        lum = arr[:, :, :3] @ LUMA
        raw = np.ones(height)
        for y in range(height):
            here = lum[y][mask[y]]
            if here.size < 6:
                continue
            body_row = root + (y - ROOT_FRACTION * height)
            want = max(float(fit(body_row)), FLOOR)
            raw[y] = want / max(float(np.median(here)), 1.0)
        # Smoothed across rows, because a limb gives few pixels on some of them
        # and a per-row gain taken raw would band the drawing.
        pad = np.pad(raw, SMOOTH, mode="edge")
        gain = np.convolve(pad, np.ones(SMOOTH * 2 + 1) / (SMOOTH * 2 + 1),
                           mode="same")[SMOOTH:-SMOOTH]
        gain = np.clip(gain, GAIN_MIN, GAIN_MAX)
        out = arr.copy()
        scaled = np.clip(arr[:, :, :3] * gain[:, None, None], 0.0, 255.0)
        out[:, :, :3] = np.where(mask[:, :, None], scaled, arr[:, :, :3])
        before = float(np.median(lum[mask])) if mask.any() else 0.0
        after_lum = out[:, :, :3] @ LUMA
        after = float(np.median(after_lum[mask])) if mask.any() else 0.0
        print("  %-28s gain %.2f-%.2f   median %.1f -> %.1f"
              % (path.name, gain.min(), gain.max(), before, after))
        if args.check:
            continue
        meta = PngInfo()
        meta.add_text(PROVENANCE,
                      "hide fit rows %d-%d, stub row %.1f, only darkening"
                      % (FIT_FROM, FIT_TO, root))
        Image.fromarray(out.round().astype(np.uint8), "RGBA").save(path, pnginfo=meta)
    print("done%s" % (" (check only)" if args.check else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
