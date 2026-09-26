"""The Warden's animations, as timed keyframes on the rig.

Every layer of the modular Warden - both bodies, every armour, the cape - is
animated to these, so they are authored once and nowhere else. A keyframe is a
`Pose`; `sample` turns a list of (time, pose) into eight evenly spaced frames.

Two families of attack. The one-handed combo is the one that shipped - a
forehand, a backhand, an overhead chop and a leaping slam - and the two-handed
combo is its heavier cousin for mauls, axes and polearms, with both fists on the
haft (`two_hand`). Everything else is shared by both.

The timing lives in the keyframe times, not in the frame rate: an attack spends
its first third winding up and crosses the strike in one or two frames, because
a swing that moves at an even pace reads as a wave rather than a blow.
"""
from __future__ import annotations

import math

from rig import Pose, lerp

FRAMES = 8
REST = Pose()


def _ease(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)


def sample(keys: list, loop: bool, frames: int = FRAMES) -> list:
    """Eight poses from keyframes. A loop samples [0, 1) and wraps its last key
    back to its first; a one-shot samples [0, 1] and ends on its last key."""
    if loop:
        keys = keys + [(1.0, keys[0][1])]
        times = [i / frames for i in range(frames)]
    else:
        times = [i / (frames - 1) for i in range(frames)]
    out = []
    for t in times:
        for (t0, p0), (t1, p1) in zip(keys, keys[1:]):
            if t0 <= t <= t1:
                u = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
                out.append(lerp(p0, p1, _ease(u)))
                break
        else:
            out.append(keys[-1][1])
    return out


def cycle(fn, frames: int = FRAMES) -> list:
    """A loop made from a function of the cycle's phase, for gaits."""
    return [fn(2.0 * math.pi * i / frames) for i in range(frames)]


# --- Shared ------------------------------------------------------------------

def idle(frames: int = FRAMES) -> list:
    breathe = REST.but(shift_u=-0.007, r_raise=4.0, l_raise=4.0, head_nod=3.0, lean=2.0)
    return sample([(0.0, REST), (0.5, breathe)], loop=True, frames=frames)


def _gait(phi, stride, lift, bob, swing, lean, arm_bend, twist):
    s, c = math.sin(phi), math.cos(phi)
    return REST.but(
        rl_raise=stride * s, ll_raise=-stride * s,
        rl_bend=lift * max(0.0, c) ** 1.5 + 4.0,
        ll_bend=lift * max(0.0, -c) ** 1.5 + 4.0,
        shift_u=bob * math.cos(2.0 * phi) - abs(bob),
        r_raise=-swing * s, l_raise=swing * s,
        r_bend=arm_bend, l_bend=arm_bend,
        twist=-twist * s, yaw=twist * 0.5 * s, lean=lean)


def walk(frames: int = FRAMES) -> list:
    return cycle(lambda p: _gait(p, 24.0, 40.0, 0.012, 20.0, 3.0, 18.0, 7.0), frames)


def sprint(frames: int = FRAMES) -> list:
    return cycle(lambda p: _gait(p, 40.0, 75.0, 0.022, 38.0, 14.0, 70.0, 11.0), frames)


def dash(frames: int = FRAMES) -> list:
    crouch = REST.but(shift_u=-0.03, lean=18.0, rl_bend=25.0, ll_bend=25.0,
                      r_raise=-15.0, l_raise=-15.0)
    lunge = REST.but(shift_u=-0.05, shift_f=0.04, lean=32.0,
                     ll_raise=48.0, ll_bend=55.0, rl_raise=-32.0, rl_bend=10.0,
                     r_raise=-45.0, l_raise=-40.0, r_bend=20.0, l_bend=20.0, head_nod=-10.0)
    land = REST.but(shift_u=-0.02, lean=12.0, ll_raise=20.0, ll_bend=25.0,
                    rl_raise=-10.0, r_raise=-10.0, l_raise=-10.0)
    return sample([(0.0, REST), (0.25, crouch), (0.55, lunge), (1.0, land)], loop=False, frames=frames)


def hurt(frames: int = FRAMES) -> list:
    struck = REST.but(lean=-14.0, head_nod=-16.0, twist=12.0, shift_f=-0.03,
                      r_raise=40.0, r_spread=38.0, r_bend=30.0, l_raise=-20.0, l_spread=30.0,
                      rl_raise=-8.0, ll_raise=10.0, ll_bend=12.0)
    reel = struck.but(lean=-8.0, head_nod=-6.0, twist=6.0, l_raise=-28.0)
    return sample([(0.0, REST), (0.18, struck), (0.5, reel), (1.0, REST)], loop=False, frames=frames)


def death(frames: int = FRAMES) -> list:
    stagger = REST.but(lean=-12.0, head_nod=-22.0, twist=10.0, shift_f=-0.02,
                       r_raise=36.0, r_spread=34.0, r_bend=26.0, l_raise=-16.0, l_spread=26.0)
    buckle = REST.but(shift_u=-0.10, lean=12.0, head_nod=10.0,
                      rl_raise=34.0, rl_bend=62.0, ll_raise=28.0, ll_bend=58.0,
                      r_raise=12.0, l_raise=12.0, r_spread=24.0, l_spread=24.0)
    kneel = REST.but(shift_u=-0.24, lean=22.0, head_nod=18.0,
                     rl_raise=78.0, rl_bend=118.0, ll_raise=70.0, ll_bend=112.0,
                     r_raise=18.0, l_raise=14.0, r_spread=18.0, l_spread=18.0)
    slump = kneel.but(shift_u=-0.28, lean=52.0, head_nod=34.0,
                      r_raise=34.0, l_raise=30.0, r_bend=6.0, l_bend=6.0)
    return sample([(0.0, REST), (0.15, stagger), (0.42, buckle), (0.7, kneel), (1.0, slump)],
                  loop=False, frames=frames)


def shoot(frames: int = FRAMES) -> list:
    """A right-handed archer: the chest turns so the left shoulder leads, the
    bow arm reaches along the facing and the right fist draws to the cheek.
    The bow is the left hand's socket, pointing up its own stave."""
    base = REST.but(hands_in_body=True, twist=48.0, head_turn=-40.0,
                    rl_spread=10.0, ll_spread=10.0, ll_raise=8.0)
    low = base.but(l_hand=(-0.02, 0.50, 0.22), l_blade=(0.0, 0.85, 0.5),
                   r_hand=(0.10, 0.56, 0.12), r_blade=(0.0, -0.5, 0.86), twist=20.0)
    nock = base.but(l_hand=(-0.02, 0.78, 0.30), l_blade=(0.0, 1.0, 0.1),
                    r_hand=(0.00, 0.80, 0.24), r_blade=(0.0, -0.3, 0.95))
    drawn = base.but(l_hand=(-0.02, 0.80, 0.33), l_blade=(0.0, 1.0, 0.05),
                     r_hand=(0.02, 0.86, 0.02), r_blade=(0.0, -0.2, 0.98))
    loosed = drawn.but(r_hand=(0.06, 0.86, -0.06), r_spread=30.0)
    return sample([(0.0, low), (0.2, nock), (0.45, drawn), (0.62, drawn),
                   (0.72, loosed), (1.0, low)], loop=False, frames=frames)


# --- One-handed combo ---------------------------------------------------------

def _swing(**kw) -> Pose:
    return REST.but(hands_in_body=True, **kw)


READY_1H = _swing(r_hand=(0.19, 0.58, 0.17), r_blade=(0.1, 0.45, 0.88),
                  l_hand=(-0.25, 0.60, -0.02), l_pole=(-0.7, -0.4, -0.4), rl_spread=8.0,
                  ll_spread=8.0)


def attack_1a(frames: int = FRAMES) -> list:
    """Forehand: a flat cut from the right across to the left."""
    wind = READY_1H.but(twist=58.0, r_hand=(0.30, 0.82, -0.12), r_blade=(0.55, 0.2, -0.8),
                        lean=-4.0, rl_raise=-10.0, rl_bend=8.0, shift_u=-0.01,
                        head_turn=-20.0, l_hand=(-0.06, 0.68, 0.26))
    cut = READY_1H.but(twist=0.0, r_hand=(0.04, 0.74, 0.42), r_blade=(-0.5, 0.05, 0.86),
                       lean=12.0, shift_f=0.06, shift_u=-0.02, ll_raise=30.0, ll_bend=26.0,
                       rl_raise=-18.0, l_hand=(-0.26, 0.62, -0.12))
    follow = cut.but(twist=-58.0, r_hand=(-0.22, 0.68, 0.26), r_blade=(-0.7, -0.1, -0.7),
                     head_turn=18.0, l_hand=(-0.20, 0.58, -0.22))
    settle = follow.but(twist=-22.0, r_hand=(-0.04, 0.60, 0.20), r_blade=(-0.4, 0.3, 0.85),
                        lean=5.0)
    return sample([(0.0, READY_1H), (0.32, wind), (0.52, cut), (0.7, follow), (1.0, settle)],
                  loop=False, frames=frames)


def attack_1b(frames: int = FRAMES) -> list:
    """Backhand: back across from the left to the right."""
    start = READY_1H.but(twist=-22.0, r_hand=(-0.04, 0.60, 0.20), r_blade=(-0.4, 0.3, 0.85),
                         lean=5.0, shift_f=0.03, ll_raise=18.0, ll_bend=14.0,
                         l_hand=(-0.22, 0.56, -0.20))
    wind = start.but(twist=-60.0, r_hand=(-0.22, 0.78, 0.04), r_blade=(-0.25, 0.8, -0.55),
                     head_turn=15.0)
    cut = start.but(twist=5.0, r_hand=(0.08, 0.72, 0.42), r_blade=(0.5, 0.05, 0.86),
                    l_hand=(-0.24, 0.60, -0.16),
                    lean=12.0, shift_f=0.06, rl_raise=26.0, rl_bend=22.0, ll_raise=-14.0,
                    ll_bend=4.0)
    follow = cut.but(twist=55.0, r_hand=(0.32, 0.68, 0.18), r_blade=(0.9, 0.0, 0.35),
                     head_turn=-15.0)
    return sample([(0.0, start), (0.3, wind), (0.5, cut), (0.72, follow), (1.0, READY_1H)],
                  loop=False, frames=frames)


def attack_2(frames: int = FRAMES) -> list:
    """An overhead chop, high on the right down to low on the left."""
    wind = READY_1H.but(twist=28.0, r_hand=(0.20, 1.06, -0.04), r_blade=(0.3, 0.6, -0.75),
                        lean=-10.0, l_hand=(-0.26, 0.70, 0.04), rl_raise=-8.0,
                        head_nod=-8.0)
    chop = READY_1H.but(twist=-26.0, r_hand=(-0.04, 0.50, 0.42), r_blade=(-0.2, -0.85, 0.5),
                        lean=26.0, shift_f=0.07, shift_u=-0.03, ll_raise=32.0, ll_bend=30.0,
                        rl_raise=-18.0, head_nod=10.0, l_hand=(-0.30, 0.68, -0.20))
    hold = chop.but(lean=14.0, r_hand=(-0.06, 0.52, 0.30))
    return sample([(0.0, READY_1H), (0.35, wind), (0.55, chop), (0.72, hold), (1.0, READY_1H)],
                  loop=False, frames=frames)


def attack_3(frames: int = FRAMES) -> list:
    """The finisher: gather, leap, and bring it down into the ground."""
    gather = READY_1H.but(shift_u=-0.04, twist=30.0, rl_bend=30.0, ll_bend=30.0,
                          rl_raise=10.0, ll_raise=10.0,
                          r_hand=(0.22, 0.50, -0.15), r_blade=(0.3, -0.5, -0.8), lean=8.0)
    rise = READY_1H.but(shift_u=0.06, twist=8.0, lean=-8.0, rl_bend=30.0, ll_bend=40.0,
                        ll_raise=24.0, r_hand=(0.12, 1.06, 0.04), r_blade=(0.1, 0.5, -0.85),
                        l_hand=(-0.16, 0.86, 0.14))
    slam = READY_1H.but(shift_u=-0.05, lean=30.0, twist=-6.0, rl_bend=45.0, ll_bend=45.0,
                        ll_raise=30.0, rl_raise=-12.0,
                        r_hand=(0.02, 0.34, 0.42), r_blade=(0.0, -0.97, 0.25),
                        l_hand=(-0.30, 0.80, -0.24))
    held = slam.but(lean=24.0, shift_u=-0.04)
    return sample([(0.0, READY_1H), (0.25, gather), (0.45, rise), (0.6, slam), (1.0, held)],
                  loop=False, frames=frames)


# --- Two-handed combo ---------------------------------------------------------

READY_2H = _swing(two_hand=True, r_hand=(0.04, 0.60, 0.24), r_blade=(0.1, 0.7, 0.7),
                  rl_spread=9.0, ll_spread=9.0, ll_raise=8.0)


def attack_2h_1(frames: int = FRAMES) -> list:
    """A wide sweep from the right hip across to the left."""
    wind = READY_2H.but(twist=60.0, r_hand=(0.10, 0.66, 0.10), r_blade=(0.55, 0.15, -0.82),
                        lean=-4.0, rl_raise=-10.0)
    cut = READY_2H.but(twist=-5.0, r_hand=(0.02, 0.64, 0.30), r_blade=(-0.72, 0.05, 0.69),
                       lean=10.0, shift_f=0.05, ll_raise=24.0, ll_bend=20.0)
    follow = cut.but(twist=-60.0, r_hand=(-0.08, 0.62, 0.14), r_blade=(-0.9, -0.1, -0.4))
    swing = wind.but(twist=30.0, r_hand=(0.08, 0.66, 0.22), r_blade=(0.85, 0.1, 0.5))
    return sample([(0.0, READY_2H), (0.34, wind), (0.45, swing), (0.55, cut), (0.74, follow),
                   (1.0, follow.but(twist=-40.0))],
                  loop=False, frames=frames)


def attack_2h_2(frames: int = FRAMES) -> list:
    """The return: low on the left, rising across to high on the right."""
    start = READY_2H.but(twist=-45.0, r_hand=(-0.08, 0.62, 0.14), r_blade=(-0.9, -0.1, -0.4),
                         shift_f=0.04, ll_raise=22.0, ll_bend=18.0)
    wind = start.but(twist=-62.0, r_hand=(-0.08, 0.56, 0.12), r_blade=(-0.8, -0.3, -0.5))
    cut = start.but(twist=8.0, r_hand=(0.02, 0.70, 0.30), r_blade=(0.45, 0.35, 0.82),
                    rl_raise=16.0, rl_bend=14.0, ll_raise=4.0)
    follow = cut.but(twist=55.0, r_hand=(0.08, 0.92, 0.08), r_blade=(0.6, 0.7, -0.35))
    swing = wind.but(twist=-30.0, r_hand=(-0.06, 0.60, 0.22), r_blade=(-0.9, -0.15, 0.4))
    return sample([(0.0, start), (0.3, wind), (0.41, swing), (0.52, cut), (0.74, follow),
                   (1.0, READY_2H)],
                  loop=False, frames=frames)


def attack_2h_3(frames: int = FRAMES) -> list:
    """Overhead, both hands, straight down in front."""
    wind = READY_2H.but(twist=10.0, r_hand=(0.02, 1.02, 0.02), r_blade=(0.05, 0.25, -0.97),
                        lean=-8.0, rl_raise=-8.0)
    chop = READY_2H.but(r_hand=(0.00, 0.46, 0.34), r_blade=(0.0, -0.75, 0.66), lean=25.0,
                        shift_f=0.05, ll_raise=26.0, ll_bend=22.0, rl_raise=-10.0)
    hold = chop.but(lean=20.0)
    return sample([(0.0, READY_2H), (0.38, wind), (0.56, chop), (0.76, hold), (1.0, READY_2H)],
                  loop=False, frames=frames)


def attack_2h_4(frames: int = FRAMES) -> list:
    """The heavy finisher: up off the ground and down onto it, head first."""
    gather = READY_2H.but(shift_u=-0.05, twist=35.0, rl_bend=34.0, ll_bend=34.0,
                          rl_raise=10.0, ll_raise=12.0, lean=10.0,
                          r_hand=(0.08, 0.50, 0.02), r_blade=(0.4, -0.4, -0.8))
    rise = READY_2H.but(shift_u=0.07, lean=-10.0, rl_bend=34.0, ll_bend=44.0, ll_raise=26.0,
                        r_hand=(0.02, 1.04, 0.00), r_blade=(0.05, 0.25, -0.97))
    slam = READY_2H.but(shift_u=-0.06, lean=34.0, rl_bend=48.0, ll_bend=48.0, ll_raise=32.0,
                        rl_raise=-12.0, r_hand=(0.00, 0.34, 0.36), r_blade=(0.0, -0.97, 0.25))
    held = slam.but(lean=28.0, shift_u=-0.05)
    return sample([(0.0, READY_2H), (0.25, gather), (0.45, rise), (0.6, slam), (1.0, held)],
                  loop=False, frames=frames)


# The sheet each animation becomes: its builder, whether it loops, and how
# many frames it is drawn at. The names are HeroAnimator's states; the
# two-handed combo is its own four states.
#
# **The frame counts are chosen to pack.** A skeleton job costs by frame count
# and barely moves with it - 8 frames is 3 generations, 15 is 4 - so two
# animations of 8 and 7 frames share one 15-frame job for 4 generations
# instead of 6. Loops keep 8, because a loop's frame count is its smoothness;
# most one-shots take 7, which at their rates is still more than one frame
# every 50ms.
ANIMATIONS = {
    "idle": (idle, True, 8),
    "walk": (walk, True, 8),
    "sprint": (sprint, True, 8),
    "dash": (dash, False, 7),
    "hurt": (hurt, False, 7),
    "death": (death, False, 8),
    "shoot": (shoot, False, 8),
    "attack_1a": (attack_1a, False, 7),
    "attack_1b": (attack_1b, False, 7),
    "attack_2": (attack_2, False, 7),
    "attack_3": (attack_3, False, 8),
    "attack_2h_1": (attack_2h_1, False, 7),
    "attack_2h_2": (attack_2h_2, False, 7),
    "attack_2h_3": (attack_2h_3, False, 7),
    "attack_2h_4": (attack_2h_4, False, 8),
}

# How the animations share jobs. Each clip is at most 15 frames, and each pair
# is ordered so the join falls between two similar poses - the job is drawn by a
# video model, and a pose that jumps between two frames is a pose it may smear.
CLIPS = [
    ["idle", "dash"],
    ["walk", "hurt"],
    ["attack_1b", "death"],
    ["sprint", "attack_1a"],
    ["shoot", "attack_2"],
    ["attack_2h_1", "attack_3"],
    ["attack_2h_2", "attack_2h_4"],
    ["attack_2h_3"],
]


# What each animation is called in the job's `action` field. **Motion words
# only.** The pilot of 2026-09-25 was labelled "sprint, then a sword slash" and
# the model painted a sword into three frames of an empty-handed body - which
# is the recorded lesson that effect words paint effects, and weapon words
# paint weapons. The weapon is the socket's; the body is only ever told what
# its limbs do.
ACTION_WORDS = {
    "idle": "stand still and breathe",
    "walk": "walk",
    "sprint": "run",
    "dash": "lunge forward low",
    "hurt": "recoil backward",
    "death": "stagger and collapse to the knees",
    "shoot": "raise the left arm forward and pull the right fist back to the cheek",
    "attack_1a": "twist and sweep the right arm across the body",
    "attack_1b": "twist back and sweep the right arm outward",
    "attack_2": "raise the right arm high and bring it down in front",
    "attack_3": "crouch, hop and bring the right arm down to the ground",
    "attack_2h_1": "twist and sweep both fists together across the body",
    "attack_2h_2": "twist back and sweep both fists together up and out",
    "attack_2h_3": "raise both fists together overhead and bring them down",
    "attack_2h_4": "crouch, hop and bring both fists together down to the ground",
}


def action_of(clip: list) -> str:
    return ", then ".join(ACTION_WORDS[n] for n in clip)


def poses(name: str) -> list:
    fn, _, frames = ANIMATIONS[name]
    return fn(frames)


def clip_poses(clip: list) -> list:
    """Every pose of a clip in order, and where each animation starts in it."""
    out, spans = [], {}
    for name in clip:
        start = len(out)
        out.extend(poses(name))
        spans[name] = (start, len(out))
    assert len(out) <= 15, (clip, len(out))
    return out, spans
