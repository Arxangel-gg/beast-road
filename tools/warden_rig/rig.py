"""The Warden's skeleton, in three dimensions, projected into the game's camera.

Why this exists. The modular Warden (docs/WARDEN_DRESS_DESIGN_2026-09-24.md,
owner rulings 2026-09-25) is a stack of layers - body, cape, weapon, head
dressing - each animated or placed separately and composited at runtime. That
only works if every layer's frame N puts every joint in the same place, and
PixelLab's `animate_with_skeleton_v3` does exactly that when it is handed the
joints (measured: one job, every joint where it was sent). So a pose is
authored here, once, and every layer is animated to it - and because every
joint is authored, the hand and the head are known exactly in every frame,
which is what lets a weapon and a helmet be *socketed* rather than drawn into
every sheet.

A pose is authored in the body's own frame - right, up, forward, in figure
heights - and projected for each of the eight facings the way the game's camera
sees them: looking down and slightly along, so a point further from the camera
sits higher on the screen.

The joint names are PixelLab's own (the SDK's `SkeletonLabel`, COCO-18), and
RIGHT is the character's own right; a larger `z_index` is nearer the camera.
Both were confirmed by the 2026-09-25 test job rather than assumed.
"""
from __future__ import annotations

import json
import math
from dataclasses import dataclass, fields, replace

LABELS = [
    "NOSE", "NECK",
    "RIGHT SHOULDER", "RIGHT ELBOW", "RIGHT ARM",
    "LEFT SHOULDER", "LEFT ELBOW", "LEFT ARM",
    "RIGHT HIP", "RIGHT KNEE", "RIGHT LEG",
    "LEFT HIP", "LEFT KNEE", "LEFT LEG",
    "RIGHT EYE", "LEFT EYE", "RIGHT EAR", "LEFT EAR",
]

# The facing on the ground as (x, a): x is image right, a is away from the
# camera. South faces the viewer. **The diagonals are not at 45 degrees.**
# PixelLab draws a "south-east" figure turned about a third of the way from
# south, not half - measured by fitting shoulder and foot spread on the base
# rotations - so `DIAGONAL_TURN` is how far a diagonal sits from its nearest
# north or south cardinal.
DIAGONAL_TURN = 32.0


def _heading(degrees):
    """0 faces the camera (south), 90 faces image right (east)."""
    r = math.radians(degrees)
    return (math.sin(r), -math.cos(r))


HEADING = {
    "east": 90.0,
    "south-east": DIAGONAL_TURN,
    "south": 0.0,
    "south-west": -DIAGONAL_TURN,
    "west": -90.0,
    "north-west": -180.0 + DIAGONAL_TURN,
    "north": 180.0,
    "north-east": 180.0 - DIAGONAL_TURN,
}
FACINGS = {name: _heading(deg) for name, deg in HEADING.items()}

# The order HeroAnimator packs its rows in: row = round(angle / 45deg) with the
# angle measured from screen +x, y down - so row 0 is east and row 2 is south.
ROW_ORDER = ["east", "south-east", "south", "south-west",
             "west", "north-west", "north", "north-east"]

CAMERA_PITCH = math.radians(24.0)


@dataclass
class Body:
    """Heights as fractions of the figure, soles to crown; widths in the same
    unit. Measured off each base painting and then held, so every layer of one
    body shares one skeleton."""
    hip: float = 0.520
    shoulder: float = 0.800
    neck: float = 0.835
    nose: float = 0.905
    eye: float = 0.925
    ear: float = 0.918
    hip_half: float = 0.070
    shoulder_half: float = 0.125
    upper_arm: float = 0.170
    fore_arm: float = 0.160
    thigh: float = 0.215
    shin: float = 0.200
    eye_half: float = 0.022
    ear_half: float = 0.052
    face_forward: float = 0.055
    hand: float = 0.030        # wrist to the middle of the grip


# The female base's shoulders are 18% narrower at the same stature, measured
# off the two rotations at a quarter of the figure's height; the hips a little
# wider. Everything else is the same body.
BODIES = {
    "male": Body(),
    "female": Body(shoulder_half=0.105, hip_half=0.075, upper_arm=0.162, fore_arm=0.152),
}


def _add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _mul(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _len(a):
    return math.sqrt(_dot(a, a))


def _norm(a):
    n = _len(a) or 1.0
    return (a[0] / n, a[1] / n, a[2] / n)


def _toward(root, direction, length):
    return _add(root, _mul(_norm(direction), length))


def _yaw(p, degrees):
    """Turn about the vertical axis; positive carries the front toward the
    body's right."""
    c, s = math.cos(math.radians(degrees)), math.sin(math.radians(degrees))
    r, u, f = p
    return (r * c + f * s, u, -r * s + f * c)


def _pitch(p, degrees, pivot_u):
    """Lean about a horizontal axis through height `pivot_u`; positive leans
    forward."""
    c, s = math.cos(math.radians(degrees)), math.sin(math.radians(degrees))
    r, u, f = p
    du = u - pivot_u
    return (r, pivot_u + du * c - f * s, f * c + du * s)


def _roll(p, degrees, pivot_u):
    """Tilt sideways about the forward axis through `pivot_u`; positive drops
    the body's right side."""
    c, s = math.cos(math.radians(degrees)), math.sin(math.radians(degrees))
    r, u, f = p
    du = u - pivot_u
    return (r * c + du * s, pivot_u - r * s + du * c, f)


@dataclass
class Pose:
    """Joint angles in degrees, root offsets in figure heights. The defaults are
    the base painting's stance.

    An arm is either posed by angles (raise, spread, bend) or, when `r_hand` or
    `l_hand` is set, reaches for a point in the chest's own frame by two-bone IK
    with its elbow toward `*_pole`. Hands are authored as targets wherever two
    of them hold one haft, because two angle sets never meet exactly.
    `r_blade` is the direction a held weapon points, in the chest's frame."""
    shift_r: float = 0.0
    shift_u: float = 0.0
    shift_f: float = 0.0
    yaw: float = 0.0
    twist: float = 0.0
    lean: float = 0.0
    tilt: float = 0.0
    head_turn: float = 0.0
    head_nod: float = 0.0
    r_raise: float = 0.0
    r_spread: float = 14.0
    r_bend: float = 12.0
    l_raise: float = 0.0
    l_spread: float = 14.0
    l_bend: float = 12.0
    r_hand: tuple | None = None
    l_hand: tuple | None = None
    r_pole: tuple = (0.6, -0.5, -0.6)
    l_pole: tuple = (-0.6, -0.5, -0.6)
    # None derives the weapon's direction from the forearm: a relaxed carry
    # holds a blade halfway between the forearm and square to it, so a sword
    # at the side points forward and down. Square to it points straight at
    # whatever is ahead, which on a walk reads as a lunge.
    r_blade: tuple | None = None
    l_blade: tuple | None = None
    # Hand targets are authored in the chest's frame unless this is set, in
    # which case they are in the body's frame - after the chest has turned -
    # which is how a bow or a swing's path is described: along the facing.
    hands_in_body: bool = False
    # Both hands on one haft: the left hand takes the grip below the right,
    # along the blade, so a two-handed weapon is one line through two fists.
    two_hand: bool = False
    rl_raise: float = 0.0
    rl_spread: float = 4.0
    rl_bend: float = 0.0
    ll_raise: float = 0.0
    ll_spread: float = 4.0
    ll_bend: float = 0.0

    def but(self, **changes) -> "Pose":
        return replace(self, **changes)


def lerp(a: Pose, b: Pose, t: float) -> Pose:
    """Between two poses. A hand target blends only when both poses author one;
    otherwise the pose nearer in time wins, so an arm never snaps half way
    between IK and angles."""
    out = {}
    for f in fields(Pose):
        va, vb = getattr(a, f.name), getattr(b, f.name)
        if isinstance(va, tuple) and isinstance(vb, tuple):
            v = tuple(x + (y - x) * t for x, y in zip(va, vb))
            if f.name.endswith("_blade") or f.name.endswith("_pole"):
                v = _norm(v)
            out[f.name] = v
        elif va is None or vb is None or isinstance(va, bool):
            out[f.name] = va if t < 0.5 else vb
        else:
            out[f.name] = va + (vb - va) * t
    return Pose(**out)


def _limb_direction(side, raise_deg, spread_deg):
    ra = math.radians(raise_deg)
    sp = math.radians(spread_deg)
    return (side * math.sin(sp), -math.cos(ra) * math.cos(sp), math.sin(ra) * math.cos(sp))


def _ik(root, target, pole, l1, l2):
    """Two bones from `root` reaching for `target`, the middle joint bent
    toward `pole`. An unreachable target is reached for as far as the limb
    goes, never stretched."""
    d = _sub(target, root)
    dist = min(max(_len(d), abs(l1 - l2) + 1e-4), l1 + l2 - 1e-4)
    axis = _norm(d)
    a = (l1 * l1 + dist * dist - l2 * l2) / (2.0 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    p = _sub(pole, _mul(axis, _dot(pole, axis)))
    if _len(p) < 1e-6:
        p = (0.0, -1.0, 0.0)
    p = _norm(p)
    mid = _add(_add(root, _mul(axis, a)), _mul(p, h))
    end = _add(root, _mul(axis, dist))
    return mid, end


def _arm(shoulder, side, raise_, spread, bend, body):
    elbow = _toward(shoulder, _limb_direction(side, raise_, spread), body.upper_arm)
    wrist = _toward(elbow, _limb_direction(side, raise_ + bend, spread), body.fore_arm)
    return elbow, wrist


def _leg(hip, side, raise_, spread, bend, body):
    knee = _toward(hip, _limb_direction(side, raise_, spread), body.thigh)
    ankle = _toward(knee, _limb_direction(side, raise_ - bend, spread * 0.5), body.shin)
    return knee, ankle


def _chest(p, pose, b):
    p = _yaw(p, pose.twist)
    p = _pitch(p, pose.lean, b.hip)
    return _roll(p, pose.tilt, b.hip)


def _unchest(p, pose, b):
    """The inverse of `_chest`: a body-frame point in the chest's frame."""
    p = _roll(p, -pose.tilt, b.hip)
    p = _pitch(p, -pose.lean, b.hip)
    return _yaw(p, -pose.twist)


def _undir(d, pose):
    """A body-frame direction in the chest's frame."""
    d = _roll(d, -pose.tilt, 0.0)
    d = _pitch(d, -pose.lean, 0.0)
    return _yaw(d, -pose.twist)


def _root(p, pose):
    p = _yaw(p, pose.yaw)
    return (p[0] + pose.shift_r, p[1] + pose.shift_u, p[2] + pose.shift_f)


def solve(pose: Pose, body: Body) -> dict:
    """Every joint in the body's own frame, plus the sockets: the grip points of
    both hands, the blade directions and the head's centre and turn."""
    b = body
    out: dict = {}
    for side, pre, raise_, spread, bend in (
            (1.0, "RIGHT", pose.rl_raise, pose.rl_spread, pose.rl_bend),
            (-1.0, "LEFT", pose.ll_raise, pose.ll_spread, pose.ll_bend)):
        hip = (side * b.hip_half, b.hip, 0.0)
        knee, ankle = _leg(hip, side, raise_, spread, bend, b)
        out[pre + " HIP"] = _root(hip, pose)
        out[pre + " KNEE"] = _root(knee, pose)
        out[pre + " LEG"] = _root(ankle, pose)
    upper: dict = {"NECK": (0.0, b.neck, 0.0)}
    sockets: dict = {}
    targets = {"r": pose.r_hand, "l": pose.l_hand}
    blades = {"r": pose.r_blade, "l": pose.l_blade}
    if pose.hands_in_body:
        for key in ("r", "l"):
            if targets[key] is not None:
                targets[key] = _unchest(targets[key], pose, b)
            if blades[key] is not None:
                blades[key] = _undir(blades[key], pose)
    if pose.two_hand and targets["r"] is not None and blades["r"] is not None:
        # The haft runs through the right fist; the left takes it a hand's
        # breadth and a half nearer the pommel.
        targets["l"] = _sub(targets["r"], _mul(_norm(blades["r"]), 0.075))
        blades["l"] = blades["r"]
    for side, pre, key in ((1.0, "RIGHT", "r"), (-1.0, "LEFT", "l")):
        shoulder = (side * b.shoulder_half, b.shoulder, 0.0)
        target = targets[key]
        if target is not None:
            elbow, wrist = _ik(shoulder, target, getattr(pose, key + "_pole"),
                               b.upper_arm, b.fore_arm)
        else:
            elbow, wrist = _arm(shoulder, side, getattr(pose, key + "_raise"),
                                getattr(pose, key + "_spread"),
                                getattr(pose, key + "_bend"), b)
        upper[pre + " SHOULDER"] = shoulder
        upper[pre + " ELBOW"] = elbow
        upper[pre + " ARM"] = wrist
        grip = _toward(wrist, _sub(wrist, elbow), b.hand)
        blade = blades[key]
        if blade is None:
            blade = _pitch(_norm(_sub(wrist, elbow)), -45.0, 0.0)
        sockets[key + "_grip"] = grip
        sockets[key + "_tip"] = _add(grip, _norm(blade))
    head = {
        "NOSE": (0.0, b.nose, b.face_forward + 0.012),
        "RIGHT EYE": (b.eye_half, b.eye, b.face_forward),
        "LEFT EYE": (-b.eye_half, b.eye, b.face_forward),
        "RIGHT EAR": (b.ear_half, b.ear, -0.004),
        "LEFT EAR": (-b.ear_half, b.ear, -0.004),
        "_head": (0.0, (b.eye + b.neck) * 0.5 + 0.03, 0.0),
    }
    for name, p in head.items():
        p = _yaw(p, pose.head_turn)
        upper[name] = _pitch(p, pose.head_nod, b.neck)
    for name, p in upper.items():
        out[name] = _root(_chest(p, pose, b), pose)
    for name, p in sockets.items():
        out[name] = _root(_chest(p, pose, b), pose)
    out["_head_turn"] = pose.yaw + pose.twist + pose.head_turn
    return out


def joints(pose: Pose, body: Body | None = None) -> dict:
    return solve(pose, body or Body())


@dataclass
class Frame:
    """Where a figure stands in a sprite: the pixel under the midpoint of the
    soles, and the figure's height in pixels."""
    width: int
    height: int
    foot_x: float
    foot_y: float
    stature: float


def ground_of(p, facing):
    """A body-frame point on the ground plane: (image x, away), in figures."""
    fx, fa = FACINGS[facing]
    rx, ra = fa, -fx
    r, u, f = p
    return (r * rx + f * fx, r * ra + f * fa)


def to_screen(p, facing, frame: Frame):
    """A body-frame point in sprite pixels, and how far from the camera it is."""
    cp, sp = math.cos(CAMERA_PITCH), math.sin(CAMERA_PITCH)
    gx, ga = ground_of(p, facing)
    sx = frame.foot_x + gx * frame.stature
    sy = frame.foot_y - (p[1] * cp + ga * sp) * frame.stature
    return sx, sy, ga


def project(solved: dict, facing: str, frame: Frame) -> list:
    """PixelLab keypoints for one facing: x/y as fractions of the sprite with y
    down, and z_index ranked so the joint nearest the camera is highest."""
    keypoints = []
    away = {}
    for label in LABELS:
        sx, sy, ga = to_screen(solved[label], facing, frame)
        away[label] = ga
        # The endpoint refuses a joint off the canvas. A pose that reaches past
        # the edge is held at it - a lunge's fist, a leap's crown - and the
        # overlay shows where that happened, because a clamped joint is a pose
        # the canvas was too small for.
        keypoints.append({"label": label,
                          "x": round(min(max(sx / frame.width, 0.0), 1.0), 4),
                          "y": round(min(max(sy / frame.height, 0.0), 1.0), 4)})
    order = sorted(LABELS, key=lambda k: -away[k])
    rank = {label: i for i, label in enumerate(order)}
    for kp in keypoints:
        kp["z_index"] = rank[kp["label"]]
    return keypoints


def sockets(solved: dict, facing: str, frame: Frame) -> dict:
    """What the game needs to place a weapon and a head dressing on this frame:
    each hand's grip in sprite pixels, the blade's screen angle and how much of
    its length survives the camera, whether the hand is in front of the chest,
    and the head's centre and which of the eight views it shows."""
    out = {}
    chest = _mul(_add(solved["RIGHT SHOULDER"], solved["LEFT SHOULDER"]), 0.5)
    _, _, chest_away = to_screen(chest, facing, frame)
    for key in ("r", "l"):
        gx, gy, ga = to_screen(solved[key + "_grip"], facing, frame)
        tx, ty, _ = to_screen(solved[key + "_tip"], facing, frame)
        dx, dy = tx - gx, ty - gy
        out[key] = {
            "x": round(gx, 2), "y": round(gy, 2),
            "angle": round(math.degrees(math.atan2(dy, dx)), 2),
            "reach": round(math.hypot(dx, dy) / frame.stature, 4),
            "front": ga < chest_away,
        }
    hx, hy, _ = to_screen(solved["_head"], facing, frame)
    heading = (HEADING[facing] + solved["_head_turn"]) % 360.0
    view = min(HEADING, key=lambda k: abs(((HEADING[k] - heading + 180.0) % 360.0) - 180.0))
    out["head"] = {"x": round(hx, 2), "y": round(hy, 2), "view": view}
    return out


def to_pixels(keypoints: list, frame: Frame) -> dict:
    return {k["label"]: (k["x"] * frame.width, k["y"] * frame.height) for k in keypoints}


if __name__ == "__main__":
    f = Frame(208, 208, 104.0, 190.0, 150.0)
    s = joints(Pose())
    print(json.dumps(project(s, "south", f))[:300])
    print(sockets(s, "south", f))
