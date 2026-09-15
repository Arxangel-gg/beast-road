"""Give every painted plant a soft edge.

**Owner report, 2026-09-15:** "there are still foliages that ... have hard
edges. If you can, make their edges feathered out softly."

Measured before believing it: **192 of the 330 plant and grass sprites have an
entirely binary silhouette** - every pixel is either fully opaque or fully
transparent, with nothing in between. On its own that is just pixel art. What
makes it a fault here is the other half of the arithmetic: `Foliage` draws these
between 1.15 and 2.35 times their painted size, and `Graphics.canvas_filter`
is NEAREST unless the player turns smoothing on. A binary edge magnified by two
with no filtering is a staircase, and a staircase is what "hard edges" is.

So this anti-aliases the silhouette the only way that does not damage the art:
**one ring of partial alpha added outside it**, tinted with the colours of the
opaque pixels it touches.

  python tools/feather_foliage.py [--check]

**Outside, never inside.** The obvious alternative - taking the outermost
opaque ring down to half alpha - eats the plant's own dark outline, and this
project has already paid for confusing an outline with shading once, on Yuri's
tail (`tools/match_tail_palette.py`). The silhouette grows by one painted pixel,
which at the field's own scale is two on screen, and every pixel the artist drew
is exactly where it was.

**The fringe is the plant's colour, not black.** Each new pixel takes the mean
RGB of its opaque neighbours, so a pale blossom feathers pale and a dark fern
feathers dark. A black fringe would be a drop shadow round every leaf.

**It runs on the drawing, never on its own output.** Every file it writes
carries a `Wilderhold-feather` chunk and is refused on a second pass; a second
ring would be a halo. Restore from git before re-running with different numbers.
`foliage_art_check` measures the result rather than trusting it.
"""

from __future__ import annotations

import argparse
import pathlib

import numpy as np
from PIL import Image
from PIL.PngImagePlugin import PngInfo

ART = pathlib.Path(__file__).resolve().parent.parent / "game" / "art" / "foliage"
PROVENANCE = "Wilderhold-feather"
# How opaque the new ring is. Enough to read as a soft edge at two times
# magnification, little enough that the plant's own outline still carries the
# shape. Measured by eye against the field's own scale.
FRINGE = 112
SOLID = 200


def families() -> list[pathlib.Path]:
    return sorted(list(ART.glob("plant_*.png")) + list(ART.glob("grass_*.png")))


def feather(image: Image.Image) -> tuple[Image.Image, int]:
    arr = np.asarray(image.convert("RGBA")).astype(np.int32)
    alpha = arr[:, :, 3]
    solid = alpha >= SOLID
    if not solid.any():
        return image, 0
    # The four-neighbour dilation of the silhouette, minus the silhouette: one
    # ring of transparent pixels touching something opaque.
    grown = np.zeros_like(solid)
    grown[1:, :] |= solid[:-1, :]
    grown[:-1, :] |= solid[1:, :]
    grown[:, 1:] |= solid[:, :-1]
    grown[:, :-1] |= solid[:, 1:]
    ring = grown & (alpha < 32)
    if not ring.any():
        return image, 0

    # Each new pixel takes the mean colour of the opaque neighbours it touches.
    # Summed by shifting rather than by looping: a 96x128 sprite times 330 of
    # them is 4 million pixels, and this runs in a second.
    rgb = arr[:, :, :3] * solid[:, :, None]
    total = np.zeros_like(rgb)
    count = np.zeros_like(alpha)
    for shift in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        total += np.roll(rgb, shift, axis=(0, 1))
        count += np.roll(solid.astype(np.int32), shift, axis=(0, 1))
    count = np.maximum(count, 1)
    mean = (total // count[:, :, None]).astype(np.int32)

    out = arr.copy()
    out[:, :, :3] = np.where(ring[:, :, None], mean, arr[:, :, :3])
    out[:, :, 3] = np.where(ring, FRINGE, alpha)
    return Image.fromarray(out.astype(np.uint8), mode="RGBA"), int(ring.sum())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report and write nothing")
    args = parser.parse_args()

    written = 0
    skipped = 0
    added = 0
    for path in families():
        image = Image.open(path)
        if image.info.get(PROVENANCE, ""):
            skipped += 1
            continue
        feathered, ring = feather(image)
        if ring == 0:
            skipped += 1
            continue
        added += ring
        if args.check:
            written += 1
            continue
        stamp = PngInfo()
        stamp.add_text(PROVENANCE, "one ring at alpha %d" % FRINGE)
        feathered.save(path, optimize=True, pnginfo=stamp)
        written += 1
    print("%d sprites feathered, %d already soft or stamped, %d pixels added%s"
          % (written, skipped, added, " (check only)" if args.check else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
