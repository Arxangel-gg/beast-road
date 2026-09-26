"""Put a held weapon on a frame at the rig's socket - the game's rule, in Python.

This is what `DressLayers` does at runtime, written once here so a pilot can be
judged on real pixels before any of it is built in GDScript: the weapon sprite
is drawn blade-up with its grip at `grip`, turned to the socket's screen angle,
shortened along its length by how much of it the camera sees, and laid in front
of the body or behind it by the hand's depth.

**And the fist closes over the handle** (owner, 2026-09-25: *"make sure the
part of the hand that grips the weapon gets zsorted over the blade"*). A weapon
in front of the body is drawn in two parts: the stretch of handle under each
gripping fist - a fist's width, never past the hilt - goes behind the body, and
the rest - guard, blade, pommel - in front. So the painted fingers cover the
handle they hold, and nothing but the handle ever goes under them.
`grip_bands` is the rule, and `DressLayers.grip_bands` is the same rule.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

# Blade length in figure heights, by weapon family, for pilots that name no
# weapon class. The game sizes a weapon by its class (`Balance.DRESS_WEAPON_LENGTH`).
LENGTH = {"blade": 0.42, "haft": 0.62, "bow": 0.34}


def grip_bands(grip_row: float, hilt: tuple, fist_px: float, along: float, holds: list) -> list:
    """The picture rows drawn behind the body: a fist's width of handle round
    each gripping fist's row, clipped to the hilt, as [start, end) pairs."""
    if fist_px <= 0.0 or not holds:
        return []
    half = fist_px / max(along, 1e-6)
    spans = []
    for row in holds:
        a = math.floor(max(row - half, hilt[0]))
        b = math.ceil(min(row + half, hilt[1] + 1))
        if b > a:
            spans.append([a, b])
    spans.sort()
    merged = []
    for a, b in spans:
        if merged and a <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], b)
        else:
            merged.append([a, b])
    return [tuple(s) for s in merged]


def place(frame: Image.Image, weapon: Image.Image, grip: tuple, socket: dict,
          stature: float, family: str = "blade", length: float | None = None,
          hilt: tuple | None = None, fist_px: float = 0.0, left: dict | None = None) -> Image.Image:
    """The frame with the weapon laid on it. `grip` is where the hand closes on
    the weapon sprite, in its own pixels; its blade points up the sprite. `left`
    is the left hand's socket when both hands hold the haft."""
    alpha = weapon.getchannel("A")
    top = alpha.getbbox()[1]
    tip_len = grip[1] - top                       # grip to tip, in sprite pixels
    across = (length if length is not None else LENGTH[family]) * stature / max(tip_len, 1)
    along = across * max(socket["reach"], 0.08)
    a = math.radians(socket["angle"])
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    gx, gy = socket["x"], socket["y"]
    # Output pixel p maps back to sprite pixel u:
    #   u.x = grip.x + ((p - g) . n) / across
    #   u.y = grip.y - ((p - g) . d) / along
    coeffs = (
        nx / across, ny / across, grip[0] - (gx * nx + gy * ny) / across,
        -dx / along, -dy / along, grip[1] + (gx * dx + gy * dy) / along,
    )

    # Filtered linearly, as the game draws it.
    layer = weapon.transform(frame.size, Image.AFFINE, coeffs, resample=Image.BILINEAR)
    out = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    if not socket["front"]:
        out.alpha_composite(layer)
        out.alpha_composite(frame)
        return out
    holds = [grip[1]]
    if left is not None and left.get("front"):
        # The left fist's row on the haft: its distance from the right fist
        # along the blade, in the picture's rows.
        holds.append(grip[1] - ((left["x"] - gx) * dx + (left["y"] - gy) * dy) / along)
    spans = grip_bands(grip[1], hilt if hilt is not None else (0, weapon.height - 1), fist_px, along, holds)
    # Which picture row every output pixel was sampled from, so the split is
    # made where the game makes it - between the rows of the picture - and the
    # two halves meet without a seam.
    w, h = frame.size
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    row = coeffs[3] * xs + coeffs[4] * ys + coeffs[5]
    under = np.zeros((h, w), dtype=bool)
    for a0, b0 in spans:
        under |= (row >= a0) & (row < b0)
    pixels = np.array(layer)
    behind = pixels.copy()
    behind[~under] = 0
    front = pixels
    front[under] = 0
    out.alpha_composite(Image.fromarray(behind, "RGBA"))
    out.alpha_composite(frame)
    out.alpha_composite(Image.fromarray(front, "RGBA"))
    return out
