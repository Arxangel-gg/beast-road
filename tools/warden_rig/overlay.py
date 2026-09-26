"""Draw the rig's joints over a character's eight rotations, to check the fit.

    python overlay.py <folder of <facing>.png> <out.png> [male|female]

A skeleton that does not match its reference frame quietly costs transparency
and colour accuracy (PixelLab's own warning), so every reference pose is
looked at before any animation is bought.
"""
from __future__ import annotations

import math
import sys

from PIL import Image, ImageDraw

import rig

BONES = [
    ("NECK", "NOSE"), ("NECK", "RIGHT SHOULDER"), ("NECK", "LEFT SHOULDER"),
    ("RIGHT SHOULDER", "RIGHT ELBOW"), ("RIGHT ELBOW", "RIGHT ARM"),
    ("LEFT SHOULDER", "LEFT ELBOW"), ("LEFT ELBOW", "LEFT ARM"),
    ("NECK", "RIGHT HIP"), ("NECK", "LEFT HIP"), ("RIGHT HIP", "LEFT HIP"),
    ("RIGHT HIP", "RIGHT KNEE"), ("RIGHT KNEE", "RIGHT LEG"),
    ("LEFT HIP", "LEFT KNEE"), ("LEFT KNEE", "LEFT LEG"),
    ("NOSE", "RIGHT EYE"), ("NOSE", "LEFT EYE"), ("RIGHT EYE", "RIGHT EAR"),
    ("LEFT EYE", "LEFT EAR"),
]


def fit(image: Image.Image, facing: str) -> rig.Frame:
    """Where the figure stands, read off its silhouette."""
    alpha = image.getchannel("A")
    left, top, right, bottom = alpha.getbbox()
    # The soles: the middle of the lowest quarter of the figure, which holds
    # both boots. The lowest rows alone hold only the nearer one, and a
    # diagonal fitted to that stands half a stride to the side.
    band = alpha.crop((left, bottom - (bottom - top) // 4, right, bottom))
    b_left, _, b_right, _ = band.getbbox()
    foot_x = left + (b_left + b_right) / 2.0
    stature = (bottom - top) / math.cos(rig.CAMERA_PITCH)
    # The painting's lowest pixel is the *nearer* sole. The frame's foot point
    # is the midpoint between the soles, which on a diagonal is further away
    # and so a little higher on the screen.
    rest = rig.joints(rig.Pose())
    nearest = min(rig.ground_of(rest[k], facing)[1] for k in ("RIGHT LEG", "LEFT LEG"))
    foot_y = bottom - 1.0 + nearest * math.sin(rig.CAMERA_PITCH) * stature
    return rig.Frame(image.width, image.height, foot_x, foot_y, stature)


def draw(image: Image.Image, keypoints: list, frame: rig.Frame, scale: int) -> Image.Image:
    big = image.resize((image.width * scale, image.height * scale), Image.NEAREST)
    canvas = Image.new("RGBA", big.size, (40, 46, 40, 255))
    canvas.alpha_composite(big)
    d = ImageDraw.Draw(canvas)
    px = {k: (x * scale, y * scale) for k, (x, y) in rig.to_pixels(keypoints, frame).items()}
    for a, b in BONES:
        d.line([px[a], px[b]], fill=(255, 255, 255, 170), width=2)
    for k in keypoints:
        x, y = px[k["label"]]
        colour = (255, 70, 70) if k["label"].startswith("RIGHT") else \
            (70, 160, 255) if k["label"].startswith("LEFT") else (255, 230, 80)
        d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=colour + (255,))
        d.text((x + 6, y - 6), str(k["z_index"]), fill=(255, 255, 255, 255))
    return canvas


def main() -> None:
    folder, out = sys.argv[1], sys.argv[2]
    body = rig.BODIES[sys.argv[3] if len(sys.argv) > 3 else "male"]
    scale = 3
    tiles = []
    for facing in rig.ROW_ORDER:
        image = Image.open("%s/%s.png" % (folder, facing)).convert("RGBA")
        frame = fit(image, facing)
        keypoints = rig.project(rig.solve(rig.Pose(), body), facing, frame)
        tiles.append(draw(image, keypoints, frame, scale))
    w, h = tiles[0].size
    sheet = Image.new("RGBA", (w * 4, h * 2), (0, 0, 0, 255))
    for i, t in enumerate(tiles):
        sheet.alpha_composite(t, ((i % 4) * w, (i // 4) * h))
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
