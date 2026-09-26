"""Hold every authored frame to what a body holding a weapon can do.

    python validate.py            every animation, both bodies; exit 1 on a fault

Owner, 2026-09-25, on the first pilot: *"some of those attack frames didn't come
out right with the sword not right or the player holding the sword's blade in
the other hand ... If these are foundations they should be polished"*. Both were
the keyframes' fault, not the generator's, and both are geometry - so they are
checked here, in three dimensions, which makes one verdict true of all eight
facings at once.

What is refused, per frame:

- **A wrist that cannot bend that far.** The weapon leaves the fist at an angle
  to the forearm, and a fist holds a blade somewhere between pointing ahead of
  the knuckles and square across them. A blade pointing back down the forearm is
  a wrist broken.
- **The off hand on the blade.** In a one-handed animation the left fist must
  stay clear of the blade's length; near it, it reads as grabbing the edge. A
  two-handed weapon's left hand is on the haft *below* the right, by
  construction, and is checked to be there.
- **A blade through the body.** The blade's length must pass clear of the torso
  and of the head, or it is drawn cutting through the person holding it.
- **A joint off the canvas.** The projection clamps it and the model is then
  told a pose the body is not in.
"""
from __future__ import annotations

import json
import math
import os
import sys

import animations
import rig

HERE = os.path.dirname(os.path.abspath(__file__))

BLADE = 0.42            # one-handed blade length, figure heights (compose.LENGTH)
HAFT = 0.62
WRIST_MIN = 15.0        # degrees between forearm and blade
WRIST_MAX = 150.0
OFF_HAND_CLEAR = 0.075  # the left fist's distance from any point of the blade
TORSO_RADIUS = 0.085
# On screen the off hand is judged by what a player sees, not by where it is in
# space: a fist behind a blade or in front of it reads as holding it the moment
# the two meet in the picture. In pixels, per facing.
OFF_HAND_SCREEN = 9.0
HEAD_RADIUS = 0.07
BOW = 0.34


def _seg_point(a, b, p):
    """Distance from point p to segment ab, and the parameter along ab."""
    ab = rig._sub(b, a)
    t = rig._dot(rig._sub(p, a), ab) / max(rig._dot(ab, ab), 1e-9)
    t = min(max(t, 0.0), 1.0)
    return rig._len(rig._sub(p, rig._add(a, rig._mul(ab, t)))), t


def _seg_seg(a, b, c, d, steps=24):
    """Closest distance between two segments, sampled - exact enough at the
    sizes involved and far easier to trust than the closed form."""
    best = 1e9
    for i in range(steps + 1):
        p = rig._add(a, rig._mul(rig._sub(b, a), i / steps))
        dist, _ = _seg_point(c, d, p)
        best = min(best, dist)
    return best


def faults(name: str, pose: rig.Pose, body: rig.Body) -> list:
    s = rig.solve(pose, body)
    out = []
    two = name.startswith("attack_2h")
    shoot = name == "shoot"
    held = [("r", HAFT if two else BLADE)]
    if shoot:
        held = [("l", BOW)]
    for key, length in held:
        pre = "RIGHT" if key == "r" else "LEFT"
        grip = s[key + "_grip"]
        direction = rig._norm(rig._sub(s[key + "_tip"], grip))
        forearm = rig._norm(rig._sub(s[pre + " ARM"], s[pre + " ELBOW"]))
        bend = math.degrees(math.acos(max(-1.0, min(1.0, rig._dot(forearm, direction)))))
        if not WRIST_MIN <= bend <= WRIST_MAX:
            out.append("%s wrist at %.0f deg (allowed %d-%d)" % (pre.lower(), bend, WRIST_MIN, WRIST_MAX))
        tip = rig._add(grip, rig._mul(direction, length))
        # The blade proper: past the fist and the guard. A second fist near the
        # hilt reads as a two-handed grip, not as holding the edge.
        start = rig._add(grip, rig._mul(direction, 0.10))
        neck = s["NECK"]
        hips = rig._mul(rig._add(s["RIGHT HIP"], s["LEFT HIP"]), 0.5)
        torso = _seg_seg(start, tip, neck, hips)
        if torso < TORSO_RADIUS:
            out.append("blade through the torso (%.3f)" % torso)
        head = _seg_point(start, tip, s["_head"])[0]
        if head < HEAD_RADIUS:
            out.append("blade through the head (%.3f)" % head)
        if key == "r" and not two and not shoot:
            clear, t = _seg_point(start, tip, s["l_grip"])
            if clear < OFF_HAND_CLEAR:
                out.append("off hand on the blade (%.3f at %.0f%% of its length)" % (clear, t * 100))
    if two:
        # The left fist is on the haft below the right, never above it.
        along = rig._dot(rig._sub(s["l_grip"], s["r_grip"]),
                         rig._norm(rig._sub(s["r_tip"], s["r_grip"])))
        if along > -0.03:
            out.append("left hand is not below the right on the haft (%.3f)" % along)
        reach = rig._len(rig._sub(s["LEFT ARM"], s["LEFT SHOULDER"]))
        if reach > body.upper_arm + body.fore_arm - 0.004:
            out.append("left arm cannot reach the haft")
    return out


def _screen_seg(a, b, p):
    ab = (b[0] - a[0], b[1] - a[1])
    t = ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / max(ab[0] ** 2 + ab[1] ** 2, 1e-9)
    t = min(max(t, 0.0), 1.0)
    q = (a[0] + ab[0] * t, a[1] + ab[1] * t)
    return math.hypot(p[0] - q[0], p[1] - q[1])


def on_screen(name: str, pose: rig.Pose, body_name: str) -> list:
    """The faults only a picture has: the off hand meeting the blade in a
    facing, which is the pilot's "holding the blade in the other hand"."""
    if name.startswith("attack_2h") or name == "shoot":
        return []
    frames = _frames(body_name)
    s = rig.solve(pose, rig.BODIES[body_name])
    grip = s["r_grip"]
    direction = rig._norm(rig._sub(s["r_tip"], grip))
    start = rig._add(grip, rig._mul(direction, 0.10))
    tip = rig._add(grip, rig._mul(direction, BLADE))
    out = []
    for facing in rig.ROW_ORDER:
        a = rig.to_screen(start, facing, frames[facing])
        b = rig.to_screen(tip, facing, frames[facing])
        h = rig.to_screen(s["l_grip"], facing, frames[facing])
        d = _screen_seg(a, b, h)
        if d < OFF_HAND_SCREEN:
            out.append("off hand meets the blade facing %s (%.1f px)" % (facing, d))
    return out


_FRAMES: dict = {}


def _frames(body_name: str) -> dict:
    if body_name not in _FRAMES:
        with open(os.path.join(HERE, "frames_%s.json" % body_name), encoding="utf-8") as f:
            _FRAMES[body_name] = {k: rig.Frame(**v) for k, v in json.load(f).items()}
    return _FRAMES[body_name]


def off_canvas(name: str, pose: rig.Pose, body_name: str) -> list:
    with open(os.path.join(HERE, "frames_%s.json" % body_name), encoding="utf-8") as f:
        frames = {k: rig.Frame(**v) for k, v in json.load(f).items()}
    s = rig.solve(pose, rig.BODIES[body_name])
    out = []
    for facing in rig.ROW_ORDER:
        for label in rig.LABELS:
            x, y, _ = rig.to_screen(s[label], facing, frames[facing])
            if not (1 <= x <= frames[facing].width - 1 and 1 <= y <= frames[facing].height - 1):
                out.append("%s off the canvas facing %s" % (label.lower(), facing))
    return sorted(set(out))


def main() -> int:
    bad = 0
    for body_name, body in rig.BODIES.items():
        for name in animations.ANIMATIONS:
            for i, pose in enumerate(animations.poses(name)):
                found = (faults(name, pose, body) + on_screen(name, pose, body_name)
                         + off_canvas(name, pose, body_name))
                for fault in found:
                    print("%-7s %-12s frame %d: %s" % (body_name, name, i, fault))
                bad += len(found)
    print("validate: %s - %d faults" % ("FAIL" if bad else "PASS", bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
