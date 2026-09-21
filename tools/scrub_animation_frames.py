"""Erase the bright blobs PixelLab's animator paints into the air around a sprite.

`scrub_menu_frames.py` found the rule on the Warden's menu cycles and it holds
for the roster too: every frame in a cycle adds pixels the base does not have,
because anything that moves has to, and those additions are the body's own
colours. What the animator *invents* - a slash trail, a burst, a white smear -
is a connected region that is opaque where the base is transparent, larger
than a nick, and brighter than anything the base itself is painted with. The
game draws its own hit effects; a strike painted into the sprite is a strike
that plays twice.

    python tools/scrub_animation_frames.py BASE.png FRAME.png [FRAME.png ...] [--check]
    python tools/scrub_animation_frames.py --roster enemies [--check]

`--roster` walks every `<base>_idle_NN`, `_move_NN` and `_attack_NN` beside
every base in that art folder. Only air is scrubbed: a bright region that
overlaps the body is left alone, because restoring the base there would put an
arm back where the animation moved it away from. Every file written carries a
`Wilderhold-scrubbed` chunk and is skipped on a second pass.
"""
from __future__ import annotations

import argparse
import pathlib
import re

import numpy as np
from PIL import Image
from PIL.PngImagePlugin import PngInfo

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOLID = 128
MIN_AREA = 60
OVER_BASE = 1.15
PROVENANCE = "Wilderhold-scrubbed"
LUMA = np.array([0.2126, 0.7152, 0.0722])
SEQUENCE = re.compile(r"^(.*)_(idle|move|attack|fly)_(\d\d)\.png$")


def regions(mask: np.ndarray) -> list[np.ndarray]:
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
                    if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            found.append(here)
    return found


def scrub(base_path: pathlib.Path, frame_path: pathlib.Path, check: bool) -> int:
    base = np.asarray(Image.open(base_path).convert("RGBA")).astype(float)
    base_solid = base[:, :, 3] >= SOLID
    if not base_solid.any():
        return 0
    ceiling = float((base[:, :, :3] @ LUMA)[base_solid].max()) / 255.0
    image = Image.open(frame_path)
    if PROVENANCE in (image.info or {}):
        return 0
    frame = np.asarray(image.convert("RGBA")).astype(float)
    if frame.shape != base.shape:
        return 0
    solid = frame[:, :, 3] >= SOLID
    # Grow the body by a pixel so an anti-aliased edge is never read as air.
    body = base_solid.copy()
    body[1:, :] |= base_solid[:-1, :]
    body[:-1, :] |= base_solid[1:, :]
    body[:, 1:] |= base_solid[:, :-1]
    body[:, :-1] |= base_solid[:, 1:]
    luma = (frame[:, :, :3] @ LUMA) / 255.0
    invented = solid & ~body
    erased = 0
    out = frame.copy()
    for region in regions(invented):
        area = int(region.sum())
        if area < MIN_AREA:
            continue
        # The region's own brightest paint against the body's brightest.
        if float(luma[region].max()) < ceiling * OVER_BASE:
            continue
        out[region] = 0.0
        erased += area
    if erased and not check:
        info = PngInfo()
        info.add_text(PROVENANCE, "%d" % erased)
        Image.fromarray(out.astype(np.uint8), "RGBA").save(frame_path, pnginfo=info)
    return erased


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*")
    parser.add_argument("--roster", default=None, help="an art folder under game/art to walk")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    pairs: list[tuple[pathlib.Path, pathlib.Path]] = []
    if args.roster:
        folder = ROOT / "game" / "art" / args.roster
        for frame in sorted(folder.glob("*.png")):
            match = SEQUENCE.match(frame.name)
            if match is None:
                continue
            base = folder / (match.group(1) + ".png")
            if base.exists():
                pairs.append((base, frame))
    elif len(args.paths) >= 2:
        base = pathlib.Path(args.paths[0])
        pairs = [(base, pathlib.Path(p)) for p in args.paths[1:]]
    else:
        parser.error("give BASE and FRAMES, or --roster FOLDER")
    total = 0
    for base, frame in pairs:
        erased = scrub(base, frame, args.check)
        if erased:
            total += 1
            print("%s: %d px %s" % (frame.relative_to(ROOT), erased, "would be scrubbed" if args.check else "scrubbed"))
    print("%d frame(s) %s" % (total, "flagged" if args.check else "scrubbed"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
