"""Pack a body's animated layers into the game's sheets, with their sockets.

    python pack.py <body> [--game <game dir>]

Reads every layer of that body out of `cache/<layer>/clip<N>/<facing>/NN.png`
(written by `batch.py`), splits each clip back into its animations, and writes
for every animation:

    game/art/hero/dress/<layer>/<state>.png      rows = facings, columns = frames
    game/art/hero/dress/<layer>/<state>_skin.png the same, white where it is skin
    game/data/dress/<body>/<state>.json           cell, origin, sockets, skin mean

**The skin mask** (owner, 2026-09-26: skin tones) is `skin.py`'s: skin-coloured
*and* on a part the outfit leaves bare, measured round the frame's own bones.
The meta carries the painted skin's mean over the whole base layer, which is
what a chosen tone is a turn of. The manifest section listing every sheet and
mask is rewritten by this step, so the folder and the manifest cannot disagree.

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

import numpy as np

import animations
import fist
import rig
import skin

HERE = os.path.dirname(os.path.abspath(__file__))
MARGIN = 3
GAME = os.path.normpath(os.path.join(HERE, "..", "..", "game"))
MANIFEST = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "ASSET_MANIFEST.md"))
MANIFEST_HEADING = "### 5.35 Dressed Warden bodies of 2026-09-26"
MANIFEST_BEFORE = "### 5.34 Head dressings"
MANIFEST_INTRO = """The modular Warden's bodies (owner, 2026-09-25: a modular, customizable
Warden, male and female), one folder a layer: every animation as a sheet of
eight facings by its frames, and beside it a skin mask of the same layout -
white where the painting is skin - which the body shader turns to the chosen
skin tone (owner, 2026-09-26). Written by `tools/warden_rig/pack.py`, which
rewrites these rows whenever it packs a body.
"""


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
                    out.setdefault(state, {})[facing] = hold_dissolved_end(state, images[start:end])
    return out


# A one-shot's last frame is held on screen for as long as the state lasts - a
# death is held until the run ends - so a last frame the generator drew
# dissolving (a death fading into specks: west's scored 41 pin-holes and lone
# pixels against single figures for every other frame of every death) is the
# picture a player stares at. Past this many, and this many times the clip's
# own median, it holds the frame before it instead.
DISSOLVE_FLOOR = 25
DISSOLVE_RATIO = 3.0


def dither(image: Image.Image) -> int:
    """Pin-holes a pixel wide and opaque pixels nearly alone: a dissolve."""
    a = np.asarray(image.getchannel("A")) > 127
    p = np.pad(a, 1)
    around = p[:-2, 1:-1].astype(int) + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:]
    return int(((~a) & (around >= 3)).sum() + (a & (around <= 1)).sum())


def hold_dissolved_end(state: str, images: list) -> list:
    """A one-shot whose last frame dissolves ends on the frame before it."""
    if animations.ANIMATIONS[state][1] or len(images) < 3:
        return images
    scores = [dither(im) for im in images]
    usual = float(np.median(scores[:-1]))
    if scores[-1] > max(DISSOLVE_FLOOR, DISSOLVE_RATIO * usual):
        print("  %s: last frame dissolves (%d against %.0f) - holding the one before" % (
            state, scores[-1], usual))
        return images[:-1] + [images[-2]]
    return images


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


def _mask_sheet(body: str, state: str, frames: dict, box: tuple, cell: tuple, count: int) -> tuple:
    """The skin mask for one layer's state, cropped as its sheet is, and the
    sum and count of the skin it found, for the painted mean."""
    rig_frames = _frames(body)
    poses = animations.poses(state)
    sheet = Image.new("RGBA", (cell[0] * count, cell[1] * len(rig.ROW_ORDER)), (0, 0, 0, 0))
    total = np.zeros(3, dtype=np.float64)
    found = 0
    for row, facing in enumerate(rig.ROW_ORDER):
        for col, image in enumerate(frames[facing]):
            joints = skin.joints_for(body, poses[min(col, len(poses) - 1)], facing, rig_frames[facing])
            m = skin.mask(image, joints, rig_frames[facing].stature)
            total += np.array(image.convert("RGB")).astype(np.float64)[m].sum(axis=0)
            found += int(m.sum())
            white = np.zeros((image.height, image.width, 4), dtype=np.uint8)
            white[m] = (255, 255, 255, 255)
            sheet.alpha_composite(Image.fromarray(white, "RGBA").crop(box), (col * cell[0], row * cell[1]))
    return sheet, total, found


def _write_manifest(game: str) -> None:
    """Every body sheet and mask on disk, as rows of one section."""
    nl, crlf = chr(10), chr(13) + chr(10)
    root = os.path.join(game, "art", "hero", "dress")
    rows = ["| File | Size | Type | Placeholder colour |", "|------|------|------|--------------------|"]
    count = 0
    for layer in sorted(os.listdir(root)):
        folder = os.path.join(root, layer)
        if layer == "head" or not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            if not name.endswith(".png"):
                continue
            with Image.open(os.path.join(folder, name)) as im:
                w, h = im.size
            rows.append("| `%s/%s` | %d%s%d | T | `#3A3128` |" % (layer, name, w, chr(215), h))
            count += 1
    with open(MANIFEST, encoding="utf-8", newline="") as f:
        raw = f.read()
    was_crlf = crlf in raw
    text = raw.replace(crlf, nl)
    section = "%s %s `res://art/hero/dress/`%s%s%s%s%s%s" % (
        MANIFEST_HEADING, chr(8212), nl + nl, MANIFEST_INTRO, nl, nl.join(rows), nl, nl)
    start = text.find(MANIFEST_HEADING)
    if start >= 0:
        end = text.find(nl + "### ", start + 1)
        text = text[:start] + section + text[end + 1:]
    else:
        at = text.find(MANIFEST_BEFORE)
        if at < 0:
            raise SystemExit("no %r in the manifest to put the bodies before" % MANIFEST_BEFORE)
        text = text[:at] + section + text[at:]
    with open(MANIFEST, "w", encoding="utf-8", newline="") as f:
        f.write(text.replace(nl, crlf) if was_crlf else text)
    print("manifest: %d body sheets and masks listed" % count)


def pack(body: str, game: str) -> None:
    layers = layer_names(body)
    base_layer = body + "_base"
    skin_total = np.zeros(3, dtype=np.float64)
    skin_found = 0
    metas: dict = {}
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
            mask, total, found = _mask_sheet(body, state, frames[state], box, cell, count)
            mask.save(os.path.join(out_dir, state + "_skin.png"))
            if layer == base_layer:
                skin_total += total
                skin_found += found
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
        metas[state] = meta
        print("packed %-12s %s cell %dx%d, %d of %d fists found on the paint (moved up to %.1f px)" % (
            state, body, cell[0], cell[1], len(found), len(moved), max(found) if found else 0.0))
    # The painted skin's mean over the whole base layer, in every state's meta:
    # the one number a chosen tone turns, the same whichever state is drawn.
    mean = (skin_total / skin_found).round(1).tolist() if skin_found else []
    meta_dir = os.path.join(game, "data", "dress", body)
    os.makedirs(meta_dir, exist_ok=True)
    for state, meta in metas.items():
        meta["skin"] = mean
        with open(os.path.join(meta_dir, state + ".json"), "w", encoding="utf-8") as f:
            json.dump(meta, f, separators=(",", ":"))
    print("painted skin mean %s over %d pixels" % (mean, skin_found))
    # A pack into a scratch folder (`--game`) is a test, and its files are not
    # the game's: the manifest lists only what the real game holds.
    if os.path.normcase(os.path.normpath(game)) == os.path.normcase(GAME):
        _write_manifest(game)


def main() -> None:
    body = sys.argv[1]
    game = os.path.normpath(os.path.join(HERE, "..", "..", "game"))
    if "--game" in sys.argv:
        game = sys.argv[sys.argv.index("--game") + 1]
    pack(body, game)


if __name__ == "__main__":
    main()
