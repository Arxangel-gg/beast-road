"""Where a frame of the Warden is skin, for the skin-tone choice.

The body sheet is painted with skin, a tunic, trousers, a belt, boots and a
lantern, and the game recolours only the skin (owner, 2026-09-26: *"make sure
players can also properly select their skintones"*). A colour rule cannot do it
alone: the boots and the belt are painted in the skin's own hue and much of its
saturation - `qa._skin` counts both as skin, which is right for what QA asks
and wrong here - so a boot would turn with the face.

**So skin is a colour and a place.** A pixel is skin when it is skin-coloured
and it lies on a part of the body the outfit leaves bare - the head, the neck,
the forearms and hands, the upper arms below the sleeve - measured as capsules
round the frame's own bones, which the rig knows because the frame was animated
to them. The boots are on the shins and the belt on the waist, and neither is
inside an arm unless a hand is on it; a dark saturated pixel is leather or ink
and is left as painted either way, which also keeps the skin's own outline - a
dark line round a pale hand is what a pale hand looks like in this art.
"""
from __future__ import annotations

import numpy as np
from PIL import Image

import rig

# How far from the bare parts' bones a skin-coloured pixel may lie and still be
# skin, as a share of the figure's height. Generous on purpose (owner,
# 2026-09-26, of the first cut: "the shader seems to not have covered all parts
# of the skin"): the generator paints a limb a few pixels off the bone it was
# asked for - most of all the near arm in a side view, which the first cut's
# tight capsules missed whole - and on a deep tone every missed highlight is a
# pale patch. What keeps the boots out is not the reach but the shins: a pixel
# nearer a shin than a bare bone is a boot's.
BARE_REACH = 0.13
# How far past the wrist the hand reaches, as a share of the forearm.
HAND_REACH = 0.45
# The neck continues into the tunic's open collar, this share of the way to
# the hips, so the skin in the V is the neck's.
COLLAR_REACH = 0.22
# Skin colour, looser than `qa._skin` at the light end: a highlight on the
# crown of a bald head is barely saturated, and left out it would stay painted
# on a head turned dark. What separates that highlight from the tunic's shaded
# linen is brightness - both are low in saturation, and only the skin is bright
# with it - so the saturation floor falls as the value rises: SAT_MIN_DIM at
# SAT_BRIGHT_FROM and below, SAT_MIN_BRIGHT from SAT_BRIGHT_AT up. Measured on
# the male base: a crown highlight at s 0.17, v 0.94; linen in shadow at s 0.22,
# v 0.71; a trouser's warm shadow at s 0.31, v 0.29, which VAL_MIN refuses.
HUE_MIN, HUE_MAX = 0.0, 0.12
SAT_MIN_DIM, SAT_MIN_BRIGHT = 0.30, 0.14
SAT_BRIGHT_FROM, SAT_BRIGHT_AT = 0.65, 0.85
SAT_MAX = 0.80
VAL_MIN = 0.42
# Dark and saturated is leather, the lantern's iron, or the skin's own ink.
INK_VAL = 0.36
INK_SAT = 0.50
# The lantern's lit glass is in the skin's hues and hangs beside a hand: bright
# and saturated together is glass, never skin (a lit crown is bright and pale).
GLOW_VAL = 0.88
GLOW_SAT = 0.45
# The lantern's iron is painted in the skin's own shadow - (128, 72, 42) is on
# the lantern and on the jaw of the same frame - so no colour tells them apart,
# and a hand hangs beside it. So it has a place: hanging from the left hip,
# this far outward, forward and down in the body's own frame, fitted to the lit
# glass of the eight reference rotations (4.3 px rms; the rotations themselves
# disagree by about that). A pixel this near it, and nearer it than any bare
# bone, is the lantern's.
LANTERN_OUT = 0.02
LANTERN_FORWARD = 0.06
LANTERN_DOWN = 0.05
LANTERN_RADIUS = 0.065


def _segment_distance(px: np.ndarray, py: np.ndarray, a: tuple, b: tuple) -> np.ndarray:
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    length2 = dx * dx + dy * dy
    if length2 < 1e-6:
        return np.hypot(px - ax, py - ay)
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / length2, 0.0, 1.0)
    return np.hypot(px - (ax + t * dx), py - (ay + t * dy))


def _bones(joints: dict) -> tuple:
    """The bare parts' bones and the legs', as segments in canvas pixels."""
    face = [joints[k] for k in ("NOSE", "RIGHT EYE", "LEFT EYE", "RIGHT EAR", "LEFT EAR")]
    head = (sum(p[0] for p in face) / len(face), sum(p[1] for p in face) / len(face))
    neck = joints["NECK"]
    hips = ((joints["RIGHT HIP"][0] + joints["LEFT HIP"][0]) / 2, (joints["RIGHT HIP"][1] + joints["LEFT HIP"][1]) / 2)
    collar = (neck[0] + (hips[0] - neck[0]) * COLLAR_REACH, neck[1] + (hips[1] - neck[1]) * COLLAR_REACH)
    bare = [(head, head), (neck, head), (neck, collar)]
    legs = []
    for side in ("RIGHT", "LEFT"):
        shoulder, elbow, wrist = joints[side + " SHOULDER"], joints[side + " ELBOW"], joints[side + " ARM"]
        hand = (wrist[0] + (wrist[0] - elbow[0]) * HAND_REACH, wrist[1] + (wrist[1] - elbow[1]) * HAND_REACH)
        bare += [(shoulder, elbow), (elbow, wrist), (wrist, hand)]
        # The shins alone: the boots are the only thing below the belt painted
        # in skin's colours - the trousers are grey - and a thigh competing
        # took the near hand in every profile, where it hangs over the thigh.
        knee, ankle = joints[side + " KNEE"], joints[side + " LEG"]
        legs += [(knee, ankle)]
    return bare, legs


def bare(shape: tuple, joints: dict, stature: float) -> np.ndarray:
    """Where a skin-coloured pixel is skin: within reach of a bare part's bone,
    nearer it than any shin, and not the lantern's."""
    h, w = shape
    py, px = np.mgrid[0:h, 0:w].astype(np.float32)
    px += 0.5
    py += 0.5
    bare_bones, leg_bones = _bones(joints)
    to_bare = np.min([_segment_distance(px, py, a, b) for a, b in bare_bones], axis=0)
    to_leg = np.min([_segment_distance(px, py, a, b) for a, b in leg_bones], axis=0)
    out = (to_bare <= BARE_REACH * stature) & (to_bare <= to_leg)
    if "LANTERN" in joints:
        lx, ly = joints["LANTERN"]
        to_lantern = np.hypot(px - lx, py - ly)
        out &= ~((to_lantern <= LANTERN_RADIUS * stature) & (to_lantern < to_bare))
    return out


def coloured(image: Image.Image) -> np.ndarray:
    """Skin-coloured, opaque, and neither ink nor lit glass."""
    alpha = np.array(image.getchannel("A")) >= 128
    hsv = np.array(image.convert("RGB").convert("HSV")).astype(np.float32) / 255.0
    h, s, v = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]
    t = np.clip((v - SAT_BRIGHT_FROM) / (SAT_BRIGHT_AT - SAT_BRIGHT_FROM), 0.0, 1.0)
    sat_min = SAT_MIN_DIM + (SAT_MIN_BRIGHT - SAT_MIN_DIM) * t
    skin = (h >= HUE_MIN) & (h <= HUE_MAX) & (s >= sat_min) & (s <= SAT_MAX) & (v >= VAL_MIN)
    ink = (v < INK_VAL) & (s > INK_SAT)
    glow = (v > GLOW_VAL) & (s > GLOW_SAT)
    return alpha & skin & ~ink & ~glow


def mask(image: Image.Image, joints: dict, stature: float) -> np.ndarray:
    return coloured(image) & bare((image.height, image.width), joints, stature)


def lantern(solved: dict) -> tuple:
    """Where the lantern hangs, in the body's frame, from its solved joints."""
    lh, rh, neck = np.array(solved["LEFT HIP"]), np.array(solved["RIGHT HIP"]), np.array(solved["NECK"])
    out = lh - rh
    out /= np.linalg.norm(out)
    down = (lh + rh) / 2.0 - neck
    down /= np.linalg.norm(down)
    forward = -np.cross(down, out)
    p = lh + out * LANTERN_OUT + forward * LANTERN_FORWARD + down * LANTERN_DOWN
    return (float(p[0]), float(p[1]), float(p[2]))


def joints_for(body: str, pose: rig.Pose, facing: str, frame: rig.Frame) -> dict:
    """The frame's joints in canvas pixels, and where its lantern hangs."""
    solved = rig.solve(pose, rig.BODIES[body])
    joints = rig.to_pixels(rig.project(solved, facing, frame), frame)
    sx, sy, _ = rig.to_screen(lantern(solved), facing, frame)
    joints["LANTERN"] = (sx, sy)
    return joints


def painted_mean(images: list, masks: list) -> tuple:
    """The mean colour of everything the masks call skin, 0-255."""
    total = np.zeros(3, dtype=np.float64)
    count = 0
    for image, m in zip(images, masks):
        rgb = np.array(image.convert("RGB")).astype(np.float64)
        total += rgb[m].sum(axis=0)
        count += int(m.sum())
    if count == 0:
        return (0.0, 0.0, 0.0)
    mean = total / count
    return (round(float(mean[0]), 1), round(float(mean[1]), 1), round(float(mean[2]), 1))
