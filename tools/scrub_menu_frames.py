"""Erase the white blobs PixelLab's animator painted onto two Warden frames.

**Found by looking at the art rather than at the screen.** The owner has been
looking at a pale egg-shaped smear beside the standing Warden on the main menu
since the camp was built. It is not lighting, it is not the lantern and it is
not a grading fault: `menu_warden_stand_idle_03.png` and `_idle_04.png` have a
645-pixel and a 365-pixel patch of near-white painted into the empty air beside
the figure, and the idle cycle shows each of them one frame in five. Every gate
passed the whole time, because a frame with an extra blob on it is still a frame
on disk of the right size with real art in it.

**What separates an artefact from animation is measured, not judged.** Across
all four menu cycles - the standing Warden, the seated one, the rider and the
horse - every frame adds pixels the base does not have, because a cloak that
moves has to. Those additions are dark: mean luminance 0.05 to 0.29, which is
the hide and the cloak. The two bad patches sit at **0.99**. Nothing on the
Warden is painted above 0.6.

So a connected region is scrubbed when it is (a) opaque where the base is
transparent, (b) larger than a nick, and (c) brighter than anything the base
itself is painted with. It is replaced by what the base has there, which is
nothing, so the frame goes back to being the figure and the air around it.

  python tools/scrub_menu_frames.py [--check]

Every file it writes carries a `Wilderhold-scrubbed` chunk and is skipped on a
second pass. `menu_camp_check` holds the rule afterwards, so the next animation
batch that invents one fails rather than ships.
"""

from __future__ import annotations

import argparse
import pathlib

import numpy as np
from PIL import Image
from PIL.PngImagePlugin import PngInfo

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "game" / "art" / "ui"
CYCLES = ["menu_warden_stand", "menu_warden_sit", "menu_warden_ride",
          "menu_fire_horse"]
SOLID = 128
## A region smaller than this is a nick on an edge and belongs to the motion.
MIN_AREA = 120
## How much brighter than the base's own brightest paint a region has to be
## before it is something the animator invented rather than something it moved.
OVER_BASE = 1.25
PROVENANCE = "Wilderhold-scrubbed"
LUMA = np.array([0.2126, 0.7152, 0.0722])


def regions(mask: np.ndarray) -> list[np.ndarray]:
    """Connected components, four-way, without a scipy dependency."""
    height, width = mask.shape
    seen = np.zeros(mask.shape, dtype=bool)
    found: list[np.ndarray] = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or seen[y, x]:
                continue
            stack = [(y, x)]
            seen[y, x] = True
            here = np.zeros(mask.shape, dtype=bool)
            while stack:
                cy, cx = stack.pop()
                here[cy, cx] = True
                for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                    if 0 <= ny < height and 0 <= nx < width \
                            and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            found.append(here)
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report and write nothing")
    args = parser.parse_args()

    scrubbed = 0
    for stem in CYCLES:
        base_path = ART / ("%s.png" % stem)
        if not base_path.exists():
            continue
        base = np.asarray(Image.open(base_path).convert("RGBA")).astype(float)
        base_solid = base[:, :, 3] >= SOLID
        if not base_solid.any():
            continue
        ceiling = float((base[:, :, :3] @ LUMA)[base_solid].max()) / 255.0
        for index in range(1, 9):
            frame_path = ART / ("%s_idle_%02d.png" % (stem, index))
            if not frame_path.exists():
                continue
            image = Image.open(frame_path)
            if image.info.get(PROVENANCE):
                continue
            arr = np.asarray(image.convert("RGBA")).astype(float)
            if arr.shape != base.shape:
                continue
            added = (arr[:, :, 3] >= SOLID) & ~base_solid
            if not added.any():
                continue
            out = arr.copy()
            wiped = 0
            for patch in regions(added):
                area = int(patch.sum())
                if area < MIN_AREA:
                    continue
                lit = float((arr[:, :, :3] @ LUMA)[patch].mean()) / 255.0
                if lit < ceiling * OVER_BASE:
                    continue
                out[patch] = base[patch]
                wiped += area
            if wiped == 0:
                continue
            scrubbed += 1
            print("  %-34s wiped %4d px brighter than the base's own %.2f"
                  % (frame_path.name, wiped, ceiling))
            if args.check:
                continue
            meta = PngInfo()
            meta.add_text(PROVENANCE, "invented bright regions removed against %s"
                          % base_path.name)
            Image.fromarray(out.round().astype(np.uint8), "RGBA").save(
                frame_path, pnginfo=meta)
    print("%d frames scrubbed%s" % (scrubbed, " (check only)" if args.check else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
