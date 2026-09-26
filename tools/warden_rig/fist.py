"""Find the fist a body frame actually drew, near where the skeleton asked.

The rig says where a hand should be; the generator draws it within a few pixels
of that (`qa.REGISTRATION`). A socketed weapon is laid on the *painted* fist,
because the game draws the stretch of handle under a gripping fist behind the
body so the fingers close over it (owner, 2026-09-25: *"make sure the part of
the hand that grips the weapon gets zsorted over the blade"*) - and a fist the
handle misses by three pixels is a hand holding its sword by the knuckles.

**A fist is the end of the forearm's skin.** The base body's arms are bare, so
the forearm and the fist are one blob of skin; what separates them is that the
fist is its far end. So: the skin near the rig's grip, measured along the
forearm, and the fist is what lies within a fist's length of the farthest of
it. A body that is not skin there - a gauntlet, a hand behind the chest, a
fist over the face - finds nothing it trusts, and the rig's own point stands.

Measured on the base layer and used for every layer of that body: they were
all drawn to one skeleton, so they put the fist in one place.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

import qa

REACH = 2.4          # skin this many fist half-lengths from the grip is looked at
TRUST = 0.035        # a found fist further than this (figure heights) is not trusted
FILL = 0.35          # a fist must fill this share of a fist-sized disc


def skin_mask(image: Image.Image) -> np.ndarray:
    alpha = np.array(image.getchannel("A")) >= 128
    return alpha & (np.array(qa._skin(image)) > 0)


def _joined_to(mask: np.ndarray, wrist: tuple) -> np.ndarray:
    """Only the skin joined to the wrist's. Beside the lantern the glass is an
    orange a skin rule cannot refuse, and it pulled the pilot's fist four pixels
    into the lamp; the iron frame round it is what keeps it apart."""
    h, w = mask.shape
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return mask
    d2 = (xs + 0.5 - wrist[0]) ** 2 + (ys + 0.5 - wrist[1]) ** 2
    seeds = [(int(ys[i]), int(xs[i])) for i in np.nonzero(d2 <= max(float(d2.min()), 9.0))[0]]
    out = np.zeros_like(mask)
    stack = list(seeds)
    for y, x in seeds:
        out[y, x] = True
    while stack:
        y, x = stack.pop()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True
                stack.append((ny, nx))
    return out


def centre(image: Image.Image, elbow: tuple, wrist: tuple, guess: tuple, stature: float,
           fist_half: float, skin: np.ndarray | None = None):
    """The painted fist's centre in the frame's pixels, or None when it cannot
    be told apart. `fist_half` is in figure heights (`rig.Body.fist_half`)."""
    if skin is None:
        skin = skin_mask(image)
    half = fist_half * stature
    ax, ay = wrist[0] - elbow[0], wrist[1] - elbow[1]
    n = math.hypot(ax, ay)
    if n < 1e-6:
        return None
    ux, uy = ax / n, ay / n
    h, w = skin.shape
    x0, x1 = max(int(guess[0] - REACH * half) - 1, 0), min(int(guess[0] + REACH * half) + 2, w)
    y0, y1 = max(int(guess[1] - REACH * half) - 1, 0), min(int(guess[1] + REACH * half) + 2, h)
    if x0 >= x1 or y0 >= y1:
        return None
    ys, xs = np.mgrid[y0:y1, x0:x1]
    px, py = xs + 0.5, ys + 0.5
    near = (px - guess[0]) ** 2 + (py - guess[1]) ** 2 <= (REACH * half) ** 2
    found = _joined_to(skin[y0:y1, x0:x1] & near, (wrist[0] - x0, wrist[1] - y0))
    if found.sum() < FILL * math.pi * half * half:
        return None
    fx, fy = px[found], py[found]
    along = (fx - wrist[0]) * ux + (fy - wrist[1]) * uy
    far = np.percentile(along, 95)
    fist = along >= far - 2.0 * half
    cx, cy = float(fx[fist].mean()), float(fy[fist].mean())
    if math.hypot(cx - guess[0], cy - guess[1]) > TRUST * stature:
        return None
    return cx, cy
