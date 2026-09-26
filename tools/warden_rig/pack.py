"""Pack a body's animated layers into the game's sheets, with their sockets.

    python pack.py <body> [--game <game dir>]

Reads every layer of that body out of `cache/<layer>/clip<N>/<facing>/NN.png`
(written by `batch.py`), splits each clip back into its animations, and writes
for every animation:

    game/art/hero/dress/<layer>/<state>.png     rows = facings, columns = frames
    game/data/dress/<body>/<state>.json          cell, origin, sockets

**Every layer of a body shares one cell per animation.** The cell is the union
of what any layer of that body draws in that animation, plus a margin, so the
body, the armour and the cape of one frame are cropped from their canvases by
the same rectangle and land on each other exactly - which is the whole reason
they were animated to one skeleton. Adding a layer re-packs the body, because a
wider cape can widen the cell; that is deterministic and costs nothing.

Rows run in `HeroAnimator`'s order (east, south-east, south, ... north-east), and
the sockets are in the cell's own pixels, so the game never needs to know how
large the canvas the frames were drawn on was.

**A hand's socket is the fist that was drawn, not the one that was asked for.**
The rig says where each fist should be and the generator draws it within a few
pixels of that; `fist.py` finds the painted fist on the base layer and the
socket moves onto it, because the game draws the stretch of handle under a
gripping fist behind the body so the fingers close over it, and a handle that
misses the fist by three pixels is held by the knuckles. Where no fist can be
told apart - a hand behind the chest, a gauntlet - the rig's point stands. The
meta carries the fist's half-width in pixels (`fist`), which is how much handle
the game hides under it.

A cape is packed as it was drawn and keyed at runtime rather than here, so a
layer's sheet is always a picture a person can open and understand.
"""
from __future__ import annotations

import json
import os
import sys

from PIL import Image

import animations
import fist
import rig

HERE = os.path.dirname(os.path.abspath(__file__))
MARGIN = 3


def layer_names(body: str) -> list:
    with open(os.path.join(HERE, "layers.json"), encoding="utf-8") as f:
        spec = json.load(f)
    return [k for k, v in spec.items() if v["body"] == body]


def frames_of(layer: str, clip_index: int, facing: str) -> list:
    folder = os.path.join(HERE, "cache", layer, "clip%d" % clip_index, facing)
    if not os.path.isdir(folder):
        return []
    names = sorted(n for n in os.listdir(folder) if n.endswith(".png"))
    return [Image.open(os.path.join(folder, n)).convert("RGBA") for n in names]


def animation_frames(layer: str) -> dict:
    """{state: {facing: [images]}} for whatever this layer has finished."""
    out: dict = {}
    for c, clip in enumerate(animations.CLIPS):
        _, spans = animations.clip_poses(clip)
        for facing in rig.ROW_ORDER:
            images = frames_of(layer, c, facing)
            if not images:
                continue
            for state, (start, end) in spans.items():
                if end <= len(images):
                    out.setdefault(state, {})[facing] = images[start:end]
    return out


def union_box(boxes: list, canvas: tuple) -> tuple:
    boxes = [b for b in boxes if b]
    left = min(b[0] for b in boxes) - MARGIN
    top = min(b[1] for b in boxes) - MARGIN
    right = max(b[2] for b in boxes) + MARGIN
    bottom = max(b[3] for b in boxes) + MARGIN
    return (max(left, 0), max(top, 0), min(right, canvas[0]), min(bottom, canvas[1]))


def _frames(body: str) -> dict:
    with open(os.path.join(HERE, "frames_%s.json" % body), encoding="utf-8") as f:
        return {k: rig.Frame(**v) for k, v in json.load(f).items()}


def sockets_for(body: str, state: str, cell_origin: tuple, painted: dict | None = None,
                moved: list | None = None) -> dict:
    """Per facing, per frame: the right hand, the left hand and the head, in the
    cell's own pixels. `painted` is the base layer's frames for this state,
    {facing: [images]}; each hand's socket is moved onto the fist it drew."""
    with open(os.path.join(HERE, "frames_%s.json" % body), encoding="utf-8") as f:
        frames = {k: rig.Frame(**v) for k, v in json.load(f).items()}
    skeleton = rig.BODIES[body]
    poses = animations.poses(state)
    out = {}
    for facing in rig.ROW_ORDER:
        rows = []
        images = (painted or {}).get(facing, [])
        for i, pose in enumerate(poses):
            solved = rig.solve(pose, skeleton)
            s = rig.sockets(solved, facing, frames[facing])
            if i < len(images):
                joints = rig.to_pixels(rig.project(solved, facing, frames[facing]), frames[facing])
                skin = fist.skin_mask(images[i])
                for key, side in (("r", "RIGHT"), ("l", "LEFT")):
                    found = fist.centre(images[i], joints[side + " ELBOW"], joints[side + " ARM"],
                                        (s[key]["x"], s[key]["y"]), frames[facing].stature,
                                        skeleton.fist_half, skin)
                    if found is None:
                        if moved is not None:
                            moved.append(None)
                        continue
                    if moved is not None:
                        moved.append(((found[0] - s[key]["x"]) ** 2 + (found[1] - s[key]["y"]) ** 2) ** 0.5)
                    s[key]["x"], s[key]["y"] = found
            row = []
            for key in ("r", "l"):
                row += [round(s[key]["x"] - cell_origin[0], 2), round(s[key]["y"] - cell_origin[1], 2),
                        s[key]["angle"], s[key]["reach"], 1 if s[key]["front"] else 0]
            row += [round(s["head"]["x"] - cell_origin[0], 2), round(s["head"]["y"] - cell_origin[1], 2),
                    rig.ROW_ORDER.index(s["head"]["view"])]
            rows.append(row)
        out[facing] = rows
    return out


def pack(body: str, game: str) -> None:
    layers = layer_names(body)
    per_layer = {layer: animation_frames(layer) for layer in layers}
    states = sorted({s for frames in per_layer.values() for s in frames})
    with open(os.path.join(HERE, "frames_%s.json" % body), encoding="utf-8") as f:
        south = json.load(f)["south"]
    canvas = (south["width"], south["height"])
    for state in states:
        boxes = []
        for frames in per_layer.values():
            for images in frames.get(state, {}).values():
                boxes += [im.getchannel("A").getbbox() for im in images]
        if not boxes:
            continue
        box = union_box(boxes, canvas)
        cell = (box[2] - box[0], box[3] - box[1])
        count = len(animations.poses(state))
        for layer, frames in per_layer.items():
            if state not in frames or len(frames[state]) < len(rig.ROW_ORDER):
                continue    # a layer is packed only when every facing has it
            sheet = Image.new("RGBA", (cell[0] * count, cell[1] * len(rig.ROW_ORDER)), (0, 0, 0, 0))
            for row, facing in enumerate(rig.ROW_ORDER):
                for col, image in enumerate(frames[state][facing]):
                    sheet.alpha_composite(image.crop(box), (col * cell[0], row * cell[1]))
            out_dir = os.path.join(game, "art", "hero", "dress", layer)
            os.makedirs(out_dir, exist_ok=True)
            sheet.save(os.path.join(out_dir, state + ".png"))
        moved: list = []
        sockets = sockets_for(body, state, (box[0], box[1]), per_layer.get(body + "_base", {}).get(state),
                              moved)
        found = [m for m in moved if m is not None]
        stature = _frames(body)["south"].stature
        meta = {
            "cell": list(cell), "origin": [box[0], box[1]], "canvas": list(canvas),
            # Where the soles are on the canvas, per facing, so the game can
            # stand the dressed Warden's feet exactly where the painted one's
            # were.
            "foot": {f: [round(fr.foot_x, 2), round(fr.foot_y, 2)] for f, fr in _frames(body).items()},
            # The figure's height in pixels, which a socketed weapon's length
            # is measured in.
            "stature": round(stature, 2),
            # Half a fist's width in pixels: the handle this far either side of
            # a gripping fist is drawn behind the body.
            "fist": round(rig.BODIES[body].fist_half * stature, 2),
            "frames": count, "loop": animations.ANIMATIONS[state][1],
            "sockets": sockets,
        }
        meta_dir = os.path.join(game, "data", "dress", body)
        os.makedirs(meta_dir, exist_ok=True)
        with open(os.path.join(meta_dir, state + ".json"), "w", encoding="utf-8") as f:
            json.dump(meta, f, separators=(",", ":"))
        print("packed %-12s %s cell %dx%d, %d of %d fists found on the paint (moved up to %.1f px)" % (
            state, body, cell[0], cell[1], len(found), len(moved), max(found) if found else 0.0))


def main() -> None:
    body = sys.argv[1]
    game = os.path.normpath(os.path.join(HERE, "..", "..", "game"))
    if "--game" in sys.argv:
        game = sys.argv[sys.argv.index("--game") + 1]
    pack(body, game)


if __name__ == "__main__":
    main()
