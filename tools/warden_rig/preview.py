"""Stick-figure previews of the rig's animations, in every facing, for free.

    python preview.py <body> <rotations folder> <out folder> [animation ...]

Each animation becomes one sheet: a row per facing, a column per frame, the
bones in white, the right side red, the left blue, and the weapon drawn from
its socket - a blade from the right fist, a bow from the left when shooting.
Nothing is bought until a pose reads here.
"""
from __future__ import annotations

import json
import math
import os
import sys

from PIL import Image, ImageDraw

import animations
import overlay
import rig

BONES = overlay.BONES
SCALE = 2
WEAPON_LENGTH = {"blade": 0.42, "haft": 0.62, "bow": 0.34}


def frames_for(folder: str) -> dict:
    """The frame each facing's figure stands in, fitted once off the base
    rotations and then held for every layer."""
    out = {}
    for facing in rig.ROW_ORDER:
        image = Image.open(os.path.join(folder, facing + ".png")).convert("RGBA")
        out[facing] = overlay.fit(image, facing)
    return out


def draw_pose(d: ImageDraw.ImageDraw, solved: dict, facing: str, frame: rig.Frame,
              ox: float, oy: float, weapon: str, bow: bool) -> None:
    px = {}
    for label in rig.LABELS:
        x, y, _ = rig.to_screen(solved[label], facing, frame)
        px[label] = (ox + x * SCALE, oy + y * SCALE)
    for a, b in BONES:
        colour = (240, 240, 240)
        if a.startswith("RIGHT") or b.startswith("RIGHT"):
            colour = (255, 110, 110)
        elif a.startswith("LEFT") or b.startswith("LEFT"):
            colour = (110, 170, 255)
        d.line([px[a], px[b]], fill=colour, width=2)
    sock = rig.sockets(solved, facing, frame)
    hx, hy = sock["head"]["x"], sock["head"]["y"]
    d.ellipse([ox + hx * SCALE - 9, oy + hy * SCALE - 11, ox + hx * SCALE + 9, oy + hy * SCALE + 11],
              outline=(240, 220, 120), width=2)
    for key, kind in (("r", weapon), ("l", "bow" if bow else None)):
        if kind is None:
            continue
        s = sock[key]
        length = WEAPON_LENGTH[kind] * frame.stature * s["reach"] * SCALE
        a = math.radians(s["angle"])
        gx, gy = ox + s["x"] * SCALE, oy + s["y"] * SCALE
        back = 0.25 if kind == "haft" else (0.5 if kind == "bow" else 0.08)
        start = (gx - math.cos(a) * length * back, gy - math.sin(a) * length * back)
        end = (gx + math.cos(a) * length, gy + math.sin(a) * length)
        colour = (255, 215, 90) if s["front"] else (140, 120, 60)
        d.line([start, end], fill=colour, width=4 if s["front"] else 3)


def render(body_name: str, frames: dict, name: str, out: str) -> None:
    body = rig.BODIES[body_name]
    poses = animations.poses(name)
    two = name.startswith("attack_2h")
    weapon = "haft" if two else "blade"
    bow = name == "shoot"
    w, h = frames["south"].width * SCALE, frames["south"].height * SCALE
    sheet = Image.new("RGB", (w * len(poses), h * 8), (30, 34, 32))
    d = ImageDraw.Draw(sheet)
    for row, facing in enumerate(rig.ROW_ORDER):
        for col, pose in enumerate(poses):
            ox, oy = col * w, row * h
            d.rectangle([ox, oy, ox + w - 1, oy + h - 1], outline=(50, 56, 52))
            solved = rig.solve(pose, body)
            draw_pose(d, solved, facing, frames[facing], ox, oy,
                      None if bow else weapon, bow)
        d.text((4, row * h + 4), facing, fill=(200, 200, 200))
    sheet.save(out)


def main() -> None:
    body_name, folder, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    names = sys.argv[4:] or list(animations.ANIMATIONS)
    frames = frames_for(folder)
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "frames_%s.json" % body_name), "w") as f:
        json.dump({k: v.__dict__ for k, v in frames.items()}, f, indent=1)
    for name in names:
        render(body_name, frames, name, os.path.join(out_dir, "%s_%s.png" % (body_name, name)))
        print("rendered", name)


if __name__ == "__main__":
    main()
