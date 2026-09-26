"""Check generated frames against the skeleton they were drawn to.

    python qa.py <layer>                 every finished job in the layer's cache
    python qa.py --frames <dir> --keypoints <json>    one folder, for testing

Owner, 2026-09-25: *"some of those attack frames didn't come out right with the
sword not right ... If these are foundations they should be polished to prevent
further defects later on"*. `validate.py` holds the authored poses; this holds
what came back, because the pilot's worst frames were the generator's own:
told the motion was "a sword slash", it painted a sword into three frames of a
body that was meant to be empty-handed, and the socketed weapon then made two.

**Everything a body layer draws must lie inside its skeleton's envelope** - a
capsule round every bone, a disc round the head, the fists and boots past the
wrist and ankle, the lantern at the hip. A painted blade, a motion trail or a
second weapon is a long cluster outside it, and a frame with one is re-rolled
rather than shipped. The envelope is generous on purpose: the check exists to
catch an *object* that should not be there, not to argue with a sleeve.

And **the figure must be where it was told to be**: the fists on the wrists'
keypoints and the boots on the ankles'. A frame drawn off its skeleton would
carry a socketed weapon in mid-air.
"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np
from PIL import Image

import animations
import rig

HERE = os.path.dirname(os.path.abspath(__file__))

# Capsule radii, in figure heights.
BONES = [
    ("NECK", "_hips", 0.115),
    ("RIGHT SHOULDER", "RIGHT ELBOW", 0.062), ("RIGHT ELBOW", "RIGHT ARM", 0.060),
    ("LEFT SHOULDER", "LEFT ELBOW", 0.062), ("LEFT ELBOW", "LEFT ARM", 0.060),
    ("RIGHT HIP", "RIGHT KNEE", 0.070), ("RIGHT KNEE", "RIGHT LEG", 0.060),
    ("LEFT HIP", "LEFT KNEE", 0.070), ("LEFT KNEE", "LEFT LEG", 0.060),
    ("RIGHT SHOULDER", "LEFT SHOULDER", 0.060), ("RIGHT HIP", "LEFT HIP", 0.080),
    ("RIGHT ARM", "_r_fist", 0.050), ("LEFT ARM", "_l_fist", 0.050),
    ("RIGHT LEG", "_r_boot", 0.060), ("LEFT LEG", "_l_boot", 0.060),
    ("LEFT HIP", "_lantern", 0.070),
    ("_hips", "_hem", 0.105),
    ("RIGHT LEG", "_r_drop", 0.075), ("LEFT LEG", "_l_drop", 0.075),
]
HEAD_RADIUS = 0.085
FOOT_RADIUS = 0.125       # a stride can put the drawn foot a way from its ankle
STRAY_PIXELS = 15          # a cluster outside the envelope this big is an object
REGISTRATION = 0.035       # a fist or boot this far from its keypoint is drawn off it


def _px(kp: list, w: int, h: int) -> dict:
    out = {k["label"]: (k["x"] * w, k["y"] * h) for k in kp}
    hips = ((out["RIGHT HIP"][0] + out["LEFT HIP"][0]) / 2, (out["RIGHT HIP"][1] + out["LEFT HIP"][1]) / 2)
    out["_hips"] = hips
    for side, pre in (("r", "RIGHT"), ("l", "LEFT")):
        e, wr = out[pre + " ELBOW"], out[pre + " ARM"]
        d = (wr[0] - e[0], wr[1] - e[1])
        n = math.hypot(*d) or 1.0
        out["_%s_fist" % side] = (wr[0] + d[0] / n * 9.0, wr[1] + d[1] / n * 9.0)
        # The boot continues the shin past the ankle: straight down while the
        # foot is planted, backward and up when a stride has kicked it back. A
        # boot placed straight below the ankle called a sprint's rear foot
        # missing.
        k, a = out[pre + " KNEE"], out[pre + " LEG"]
        d = (a[0] - k[0], a[1] - k[1])
        n = math.hypot(*d) or 1.0
        out["_%s_boot" % side] = (a[0] + d[0] / n * 10.0, a[1] + d[1] / n * 10.0)
    lh = out["LEFT HIP"]
    out["_lantern"] = (lh[0], lh[1] + 14.0)
    # The tunic's hem flares below the hips, and a foot kicked back in a stride
    # is drawn lower than a front-facing skeleton asks - consistently, in every
    # layer, so it is allowed for rather than flagged.
    out["_hem"] = (hips[0], hips[1] + 16.0)
    for side, pre in (("r", "RIGHT"), ("l", "LEFT")):
        a = out[pre + " LEG"]
        out["_%s_drop" % side] = (a[0], a[1] + 20.0)
    ears = [out["RIGHT EAR"], out["LEFT EAR"], out["NOSE"]]
    out["_head"] = (sum(p[0] for p in ears) / 3, sum(p[1] for p in ears) / 3)
    return out


def _dist_seg(p, a, b):
    ab = (b[0] - a[0], b[1] - a[1])
    t = ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / max(ab[0] ** 2 + ab[1] ** 2, 1e-9)
    t = min(max(t, 0.0), 1.0)
    return math.hypot(p[0] - a[0] - ab[0] * t, p[1] - a[1] - ab[1] * t)


# A limb may bulge past its bone - the model draws a biceps a little wider than
# the skeleton's line, or a sleeve swinging out - and that is not a fault. An
# object painted into the frame reaches well past the body: the pilot's swords
# went twenty to fifty pixels beyond it. So every capsule is widened by this
# much before anything is counted as outside.
SLACK_PX = 3.0


def envelope(points: dict, stature: float, size: tuple) -> Image.Image:
    """Everything the skeleton says the body may cover, as a mask. Vectorised:
    a layer is eight facings of a hundred and fifteen frames, and a pixel loop
    over every capsule took minutes a layer."""
    w, h = size
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    xs += 0.5
    ys += 0.5
    inside = np.zeros((h, w), dtype=bool)
    discs = [(points["_head"], HEAD_RADIUS * stature + SLACK_PX),
             (points["RIGHT LEG"], FOOT_RADIUS * stature + SLACK_PX),
             (points["LEFT LEG"], FOOT_RADIUS * stature + SLACK_PX)]
    for (cx, cy), r in discs:
        inside |= (xs - cx) ** 2 + (ys - cy) ** 2 <= r * r
    for a_name, b_name, radius in BONES:
        ax, ay = points[a_name]
        bx, by = points[b_name]
        r = radius * stature + SLACK_PX
        dx, dy = bx - ax, by - ay
        length = max(dx * dx + dy * dy, 1e-9)
        t = np.clip(((xs - ax) * dx + (ys - ay) * dy) / length, 0.0, 1.0)
        inside |= (xs - ax - dx * t) ** 2 + (ys - ay - dy * t) ** 2 <= r * r
    return Image.fromarray((inside * 255).astype(np.uint8), "L")


def _skin(image: Image.Image) -> Image.Image:
    """Where the frame is skin. A limb that bulges past its bone is skin - a
    biceps, a forearm swung wide - and an object the generator paints is not:
    the pilot's painted blades measured saturation 0.13-0.18 and the arm that
    bulged 0.54 at an orange hue. So skin outside the envelope is a limb being
    a little wider than its line, and is never counted as an object."""
    hsv = np.array(image.convert("RGB").convert("HSV")).astype(np.float32) / 255.0
    h, s, v = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]
    skin = (h >= 0.02) & (h <= 0.11) & (s >= 0.30) & (s <= 0.78) & (v >= 0.25)
    return Image.fromarray((skin * 255).astype(np.uint8), "L")


def strays(image: Image.Image, mask: Image.Image) -> list:
    """Clusters of opaque pixels outside the envelope, largest first. Skin is
    part of the envelope by definition (`_skin`)."""
    alpha = image.getchannel("A").load()
    mask = Image.fromarray(np.maximum(np.array(mask), np.array(_skin(image))), "L")
    m = mask.load()
    w, h = image.size
    seen = set()
    out = []
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or alpha[x, y] < 96 or m[x, y]:
                continue
            stack, size, box = [(x, y)], 0, [x, y, x, y]
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                size += 1
                box = [min(box[0], cx), min(box[1], cy), max(box[2], cx), max(box[3], cy)]
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen \
                            and alpha[nx, ny] >= 96 and not m[nx, ny]:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if size >= STRAY_PIXELS:
                out.append((size, tuple(box)))
    return sorted(out, reverse=True)


def registration(image: Image.Image, points: dict, stature: float) -> list:
    """The fists and boots must be drawn where the skeleton put them."""
    alpha = image.getchannel("A").load()
    w, h = image.size
    radius = REGISTRATION * stature
    out = []
    for name in ("_r_fist", "_l_fist", "RIGHT LEG", "LEFT LEG"):
        cx, cy = points[name]
        found = False
        for dy in range(-int(radius), int(radius) + 1):
            for dx in range(-int(radius), int(radius) + 1):
                x, y = int(cx + dx), int(cy + dy)
                if 0 <= x < w and 0 <= y < h and alpha[x, y] >= 128 and dx * dx + dy * dy <= radius * radius:
                    found = True
                    break
            if found:
                break
        if not found:
            out.append(name.strip("_").replace("_", " ").lower())
    return out


def check_frame(image: Image.Image, kp: list, stature: float) -> list:
    points = _px(kp, image.width, image.height)
    faults = []
    found = strays(image, envelope(points, stature, image.size))
    if found:
        size, box = found[0]
        faults.append("%d px drawn outside the body at %s" % (size, box))
    missing = registration(image, points, stature)
    if missing:
        faults.append("nothing drawn at the %s" % ", ".join(missing))
    return faults


def check_layer(layer: str) -> int:
    with open(os.path.join(HERE, "layers.json"), encoding="utf-8") as f:
        spec = json.load(f)[layer]
    with open(os.path.join(HERE, "frames_%s.json" % spec["body"]), encoding="utf-8") as f:
        frames = {k: rig.Frame(**v) for k, v in json.load(f).items()}
    body = rig.BODIES[spec["body"]]
    bad = 0
    for c, clip in enumerate(animations.CLIPS):
        poses, spans = animations.clip_poses(clip)
        for facing in rig.ROW_ORDER:
            folder = os.path.join(HERE, "cache", layer, "clip%d" % c, facing)
            if not os.path.isdir(folder):
                continue
            for i, pose in enumerate(poses):
                path = os.path.join(folder, "%02d.png" % i)
                if not os.path.exists(path):
                    continue
                kp = rig.project(rig.solve(pose, body), facing, frames[facing])
                for fault in check_frame(Image.open(path).convert("RGBA"), kp, frames[facing].stature):
                    print("%s clip %d %s frame %d: %s" % (layer, c, facing, i, fault))
                    bad += 1
    print("qa %s: %s - %d faults" % (layer, "FAIL" if bad else "PASS", bad))
    return 1 if bad else 0


def main() -> int:
    if "--frames" in sys.argv:
        folder = sys.argv[sys.argv.index("--frames") + 1]
        with open(sys.argv[sys.argv.index("--keypoints") + 1], encoding="utf-8") as f:
            data = json.load(f)
        stature = float(sys.argv[sys.argv.index("--stature") + 1]) if "--stature" in sys.argv else 150.0
        bad = 0
        for i, kp in enumerate(data["frames"]):
            image = Image.open(os.path.join(folder, "%02d.png" % i)).convert("RGBA")
            for fault in check_frame(image, kp, stature):
                print("frame %d: %s" % (i, fault))
                bad += 1
        print("qa: %s - %d faults" % ("FAIL" if bad else "PASS", bad))
        return 1 if bad else 0
    return check_layer(sys.argv[1])


if __name__ == "__main__":
    sys.exit(main())
