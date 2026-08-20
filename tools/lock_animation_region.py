"""Keep generated structure motion inside explicitly art-directed regions.

PixelLab preserves the canvas and anchor well, but a hollow or circular tower
can tempt an animation model to invent orbiting rings outside the requested
motion. Production frames still come from PixelLab; this final deterministic
pass restores the authored base everywhere outside the approved moving parts.

The optional ground-alignment pass translates a generated frame back onto the
base sprite's alpha-foot before regional locking. It corrects whole-canvas
drift without repainting any generated pixels.

Usage:
    python tools/lock_animation_region.py BASE FRAME [FRAME ...] \
        [--align-ground] [--allow X,Y,WIDTH,HEIGHT ...]
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def parse_rect(raw: str) -> tuple[int, int, int, int]:
    values = tuple(int(value.strip()) for value in raw.split(","))
    if len(values) != 4 or values[2] <= 0 or values[3] <= 0:
        raise argparse.ArgumentTypeError("region must be X,Y,WIDTH,HEIGHT")
    return values


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("base", type=Path)
    parser.add_argument("frames", nargs="+", type=Path)
    parser.add_argument("--allow", action="append", type=parse_rect, default=[])
    parser.add_argument(
        "--align-ground",
        action="store_true",
        help="translate each generated frame so its alpha-foot matches the base",
    )
    args = parser.parse_args()
    if not args.allow and not args.align_ground:
        parser.error("provide --allow, --align-ground, or both")

    with Image.open(args.base) as source:
        base = source.convert("RGBA")
    for frame_path in args.frames:
        with Image.open(frame_path) as source:
            generated = source.convert("RGBA")
        if generated.size != base.size:
            raise SystemExit(
                f"{frame_path}: {generated.size} does not match base {base.size}"
            )
        if args.align_ground:
            base_box = base.getchannel("A").getbbox()
            generated_box = generated.getchannel("A").getbbox()
            if base_box is None or generated_box is None:
                raise SystemExit(f"{frame_path}: cannot align an empty alpha silhouette")
            base_center = (base_box[0] + base_box[2] - 1) // 2
            generated_center = (generated_box[0] + generated_box[2] - 1) // 2
            offset = (base_center - generated_center, base_box[3] - generated_box[3])
            aligned = Image.new("RGBA", base.size)
            aligned.alpha_composite(generated, offset)
            generated = aligned
        locked = generated if not args.allow else base.copy()
        for x, y, width, height in args.allow:
            box = (x, y, x + width, y + height)
            locked.alpha_composite(generated.crop(box), (x, y))
        locked.save(frame_path, format="PNG", optimize=True)


if __name__ == "__main__":
    main()
