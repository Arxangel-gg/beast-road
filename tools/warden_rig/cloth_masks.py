"""Writes every dressed body sheet's cloth mask (2026-09-30).

    python tools/warden_rig/cloth_masks.py male
    python tools/warden_rig/cloth_masks.py female

`game/art/hero/dress/<layer>/<state>_cloth.png`, the sheet's own layout texel for
texel: red where the frame is the top, green where it is the trousers
(`cloth.py`). Cropped exactly as `pack.py` crops the sheet - the same frames, the
same union box, the same cells - so it lines up with the sheet and the skin mask
beside it; and it writes nothing else, so the sheets `pack.py` made are not
touched. The manifest section is rewritten through `pack._write_manifest`, which
lists every PNG in the dress folders.
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image

import animations
import cloth
import pack
import rig
import skin


def write(body: str, game: str) -> int:
    # **Not heavy armour**: its top and trousers are plate and mail, and a dye
    # there caught the steel's near-white highlights and nothing else. A layer
    # with no cloth mask samples black, which is the painting as worn.
    layers = [layer for layer in pack.layer_names(body)
              if not pack.is_cape(layer) and not layer.endswith("_heavy")]
    per_layer = {layer: pack.animation_frames(layer) for layer in pack.layer_names(body)}
    base = body + "_base"
    wanted = set(animations.ANIMATIONS)
    for layer in list(per_layer):
        if layer == base:
            continue
        frames = per_layer[layer]
        if any(st not in frames or len(frames[st]) < len(rig.ROW_ORDER) for st in wanted):
            del per_layer[layer]
    with open(os.path.join(pack.HERE, "frames_%s.json" % body), encoding="utf-8") as f:
        south = json.load(f)["south"]
    canvas = (south["width"], south["height"])
    rig_frames = pack._frames(body)
    written = 0
    states = sorted({s for frames in per_layer.values() for s in frames})
    for state in states:
        boxes = []
        for frames in per_layer.values():
            for images in frames.get(state, {}).values():
                boxes += [im.getchannel("A").getbbox() for im in images]
        if not boxes:
            continue
        box = pack.union_box(boxes, canvas)
        cell = (box[2] - box[0], box[3] - box[1])
        poses = animations.poses(state)
        count = len(poses)
        for layer in layers:
            frames = per_layer.get(layer, {})
            if state not in frames or len(frames[state]) < len(rig.ROW_ORDER):
                continue
            sheet = Image.new("RGBA", (cell[0] * count, cell[1] * len(rig.ROW_ORDER)), (0, 0, 0, 0))
            for row, facing in enumerate(rig.ROW_ORDER):
                for col, image in enumerate(frames[state][facing]):
                    joints = skin.joints_for(body, poses[min(col, count - 1)], facing, rig_frames[facing])
                    top, bottom = cloth.masks(image, joints, rig_frames[facing].stature)
                    painted = np.zeros((image.height, image.width, 4), dtype=np.uint8)
                    painted[top] = (255, 0, 0, 255)
                    painted[bottom] = (0, 255, 0, 255)
                    sheet.alpha_composite(Image.fromarray(painted, "RGBA").crop(box),
                                          (col * cell[0], row * cell[1]))
            out = os.path.join(game, "art", "hero", "dress", layer, state + "_cloth.png")
            existing = os.path.join(game, "art", "hero", "dress", layer, state + ".png")
            if not os.path.exists(existing):
                continue
            with Image.open(existing) as im:
                if im.size != sheet.size:
                    raise SystemExit("%s: the cloth mask is %s and the sheet %s" % (out, sheet.size, im.size))
            sheet.save(out)
            written += 1
    return written


def main() -> None:
    body = sys.argv[1]
    game = pack.GAME
    print("cloth masks for %s: %d" % (body, write(body, game)))
    pack._write_manifest(game)


if __name__ == "__main__":
    main()
