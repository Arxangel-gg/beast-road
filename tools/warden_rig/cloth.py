"""Where a frame of the Warden is the top and where it is the trousers.

Owner, 2026-09-30: *"Players should be able to tint their appearance, such as
the color of their cape or tops and bottoms."* The first cut found the cloth by
colour alone in the shader and it could not be done: the linen top's own shadow
sits at the trousers' value and saturation, so a dyed top wore a rim of the
trousers' colour, and the linen's brightest highlight has no hue at all, so it
stayed white in blotches. Photographed on the Warden's Glass; no number saw it.

**So cloth is a colour and a place**, exactly as skin is (`skin.py`). A pixel is
cloth when it is quiet - not skin, not leather, not the lantern's glass or iron,
not ink - and the top when it lies nearer the torso and the upper arms than the
legs, the trousers when it lies nearer the thighs and the shins above the boot.
The bones are the frame's own, which the rig knows because the frame was animated
to them. Light armour's vest and bracers are leather, and so saturated, and so
stay as painted; heavy armour's steel is cool and is left alone by the colour
test below as well.
"""
from __future__ import annotations

import numpy as np
from PIL import Image

import skin

# Quiet enough to be cloth: under this saturation. The linen measures 0.14 and
# the trousers 0.27 at their middles; leather is 0.45 and up.
SAT_MAX = 0.40
# Dark and saturated is ink or leather; below this value is outline.
VAL_MIN = 0.12
# Cool is steel (heavy armour measures hue 0.62); cloth here is warm or has no
# hue at all. A pixel this far round the wheel with any colour in it is metal.
COOL_FROM, COOL_TO = 0.30, 0.85
COOL_SAT = 0.08
# How far from the torso or a leg bone cloth may lie, as a share of stature.
REACH = 0.20
# Where a boot begins, as a share of the way from knee to ankle - `skin.BOOT_TOP`.
BOOT_TOP = skin.BOOT_TOP
# **How far the competitors reach**, as shares of stature. The head claims a
# disc round the face; a forearm, a hand or a boot only a tight band round its
# bone. Unbounded, a forearm hanging down the side in profile claimed the back
# half of the top and the thigh behind it - photographed, 2026-09-30.
HEAD_REACH = 0.13
LIMB_REACH = 0.055
# **A forearm claims only what is clearly its own**: under `ARM_SHARE` of the
# body's distance, and never on the body's own line (`CORE_REACH`). In profile
# every bone projects onto nearly one line, so the forearm hanging at the side
# runs straight down the torso and the thigh; measured on the male idle, the
# back of the tunic sat 7 px from both. A bracer sits on the forearm and well
# off the upper arm's bone, which is what the share asks.
ARM_SHARE = 0.5
CORE_REACH = 0.035
# **Below the ankles is the boot**, whatever it is nearest: a foot reaches
# forward past the ankle's bone, and light armour's metal shoes were read as
# trousers. This far above the lower ankle is still the boot. [TUNE]
FOOT_ABOVE_ANKLE = 0.03


def _bones(joints: dict) -> tuple:
    """The top's bones (torso and upper arms), the trousers' (thighs and the
    shins down to the boot), and what competes with both: the head, the forearms
    and hands, and the boots. A pixel nearer one of those is none of the cloth -
    the first cut had no competitors and dyed a bald crown's highlight, the eyes'
    whites and the bracers of light armour with the top."""
    neck = joints["NECK"]
    face = [joints[k] for k in ("NOSE", "RIGHT EYE", "LEFT EYE", "RIGHT EAR", "LEFT EAR")]
    head = (sum(p[0] for p in face) / len(face), sum(p[1] for p in face) / len(face))
    top = []
    legs = []
    arms = []
    boots = []
    for side in ("RIGHT", "LEFT"):
        shoulder, elbow, wrist = joints[side + " SHOULDER"], joints[side + " ELBOW"], joints[side + " ARM"]
        hip = joints[side + " HIP"]
        top += [(neck, hip), (shoulder, hip), (shoulder, elbow), (neck, shoulder)]
        hand = (wrist[0] + (wrist[0] - elbow[0]) * skin.HAND_REACH, wrist[1] + (wrist[1] - elbow[1]) * skin.HAND_REACH)
        arms += [(elbow, wrist), (wrist, hand)]
        knee, ankle = joints[side + " KNEE"], joints[side + " LEG"]
        boot = (knee[0] + (ankle[0] - knee[0]) * BOOT_TOP, knee[1] + (ankle[1] - knee[1]) * BOOT_TOP)
        legs += [(hip, knee), (knee, boot)]
        boots += [(boot, ankle)]
    return top, legs, arms, boots, head


def quiet(image: Image.Image) -> np.ndarray:
    """Opaque, and coloured the way cloth is: low in saturation, not ink, not
    cool metal."""
    alpha = np.array(image.getchannel("A")) >= 128
    hsv = np.array(image.convert("RGB").convert("HSV")).astype(np.float32) / 255.0
    h, s, v = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]
    cool = (h >= COOL_FROM) & (h <= COOL_TO) & (s > COOL_SAT)
    return alpha & (s <= SAT_MAX) & (v >= VAL_MIN) & ~cool


# **What armour wears over the top** (owner, 2026-09-30: *"The colors set on
# the player tops in the warden glass do not properly cover the tops properly
# anymore"*). Under light armour the top a player reads is the leather vest, and
# under heavy it is the breastplate; the linen mask above leaves both alone, so
# a chosen top coloured only a linen sleeve and a hem. The armour's torso is its
# own channel, lacquered in the shader rather than painted, so leather keeps its
# grain and steel its highlights. Above the belt only: the belt is leather on
# the torso's bone too, and a belt the colour of the shirt reads as a smear.
BELT_FROM = 0.80
# Ink stays ink, as everywhere else - and no higher: the female's vest is a
# darker leather than the male's, and at 0.16 more than half of it was read as
# ink and kept its brown.
ARMOUR_VAL_MIN = 0.07
# How far down the torso the collar runs, where bare skin may still show.
COLLAR_SHARE = 0.22


def _along(px: np.ndarray, py: np.ndarray, a: tuple, b: tuple) -> np.ndarray:
    """How far along a bone from `a` to `b` each pixel lies, 0 to 1."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = max(dx * dx + dy * dy, 1e-6)
    return np.clip(((px - a[0]) * dx + (py - a[1]) * dy) / length, 0.0, 1.0)


def armour_top(image: Image.Image, joints: dict, stature: float, top: np.ndarray) -> np.ndarray:
    """The armour over the torso and the upper arms, where it is not linen
    already: opaque, not skin, not ink, on the top's own bones, above the belt,
    and not the lantern's."""
    h, w = image.height, image.width
    py, px = np.mgrid[0:h, 0:w].astype(np.float32)
    px += 0.5
    py += 0.5
    top_bones, leg_bones, arm_bones, boot_bones, head = _bones(joints)
    to_top = np.min([skin._segment_distance(px, py, a, b) for a, b in top_bones], axis=0)
    to_leg = np.min([skin._segment_distance(px, py, a, b) for a, b in leg_bones], axis=0)
    to_arm = np.min([skin._segment_distance(px, py, a, b) for a, b in arm_bones], axis=0)
    to_head = np.hypot(px - head[0], py - head[1])
    alpha = np.array(image.getchannel("A")) >= 128
    value = np.array(image.convert("RGB").convert("HSV")).astype(np.float32)[:, :, 2] / 255.0
    neck = joints["NECK"]
    hip = ((joints["RIGHT HIP"][0] + joints["LEFT HIP"][0]) * 0.5,
           (joints["RIGHT HIP"][1] + joints["LEFT HIP"][1]) * 0.5)
    above_belt = _along(px, py, neck, hip) < BELT_FROM
    torso = (to_top <= REACH * stature) & (to_top < to_leg) & above_belt \
        & ~((to_head <= HEAD_REACH * stature) & (to_head < to_top)) \
        & ~((to_arm <= LIMB_REACH * stature) & (to_arm < to_top * ARM_SHARE))
    not_lantern = np.ones((h, w), dtype=bool)
    if "LANTERN" in joints:
        lx, ly = joints["LANTERN"]
        not_lantern = np.hypot(px - lx, py - ly) > skin.LANTERN_RADIUS * stature
    # The skin mask is honoured only at the collar. Under a vest or a plate the
    # torso is not skin, and the leather down a vest's middle is the skin's
    # own hue on the neck's line - the skin mask claims it, and a vest with a
    # brown stripe down a coloured chest read as unfinished.
    collar = _along(px, py, neck, hip) < COLLAR_SHARE
    # Only the trunk: an upper arm is bare skin under a vest, and its own.
    trunk = skin._segment_distance(px, py, neck, hip)
    upper_arm = np.min([skin._segment_distance(px, py, joints[side + " SHOULDER"], joints[side + " ELBOW"])
                        for side in ("RIGHT", "LEFT")], axis=0)
    collar = collar | (upper_arm < trunk)
    return alpha & torso & (value >= ARMOUR_VAL_MIN) & ~(skin.mask(image, joints, stature) & collar) \
        & ~top & not_lantern


def masks(image: Image.Image, joints: dict, stature: float) -> tuple:
    """The top and the trousers, as boolean arrays the frame's size."""
    h, w = image.height, image.width
    py, px = np.mgrid[0:h, 0:w].astype(np.float32)
    px += 0.5
    py += 0.5
    top_bones, leg_bones, arm_bones, boot_bones, head = _bones(joints)
    to_top = np.min([skin._segment_distance(px, py, a, b) for a, b in top_bones], axis=0)
    to_leg = np.min([skin._segment_distance(px, py, a, b) for a, b in leg_bones], axis=0)
    to_arm = np.min([skin._segment_distance(px, py, a, b) for a, b in arm_bones], axis=0)
    to_boot = np.min([skin._segment_distance(px, py, a, b) for a, b in boot_bones], axis=0)
    cloth = quiet(image) & ~skin.mask(image, joints, stature)
    near = np.minimum(to_top, to_leg) <= REACH * stature
    to_head = np.hypot(px - head[0], py - head[1])
    body = np.minimum(to_top, to_leg)
    claimed = ((to_head <= HEAD_REACH * stature) & (to_head < to_top)) \
        | ((to_arm <= LIMB_REACH * stature) & (to_arm < body * ARM_SHARE) & (body > CORE_REACH * stature)) \
        | ((to_boot <= LIMB_REACH * stature) & (to_boot < body))
    top = cloth & near & (to_top <= to_leg) & ~claimed
    ankle_y = max(joints["RIGHT LEG"][1], joints["LEFT LEG"][1])
    hip_y = max(joints["RIGHT HIP"][1], joints["LEFT HIP"][1])
    # Only standing: a Warden lying dead has ankles level with the hips.
    standing = ankle_y > hip_y + 0.25 * stature
    foot = (py > ankle_y - FOOT_ABOVE_ANKLE * stature) & standing
    bottom = cloth & near & (to_leg < to_top) & ~claimed & ~foot
    return top, bottom
