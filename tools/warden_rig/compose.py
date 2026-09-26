"""Put a held weapon on a frame at the rig's socket - the game's rule, in Python.

This is what `WardenDress` does at runtime, written once here so a pilot can be
judged on real pixels before any of it is built in GDScript: the weapon sprite
is drawn blade-up with its grip at `grip`, turned to the socket's screen angle,
shortened along its length by how much of it the camera sees, and laid in front
of the body or behind it by the hand's depth.
"""
from __future__ import annotations

import math

from PIL import Image

# Blade length in figure heights, by weapon family. The sprite's own length is
# rescaled to this, so every sword in the game is a sword's length on the body
# whatever canvas it was drawn on.
LENGTH = {"blade": 0.42, "haft": 0.62, "bow": 0.34}


def place(frame: Image.Image, weapon: Image.Image, grip: tuple, socket: dict,
          stature: float, family: str = "blade") -> Image.Image:
    """The frame with the weapon laid on it. `grip` is where the hand closes on
    the weapon sprite, in its own pixels; its blade points up the sprite."""
    alpha = weapon.getchannel("A")
    top = alpha.getbbox()[1]
    tip_len = grip[1] - top                       # grip to tip, in sprite pixels
    across = LENGTH[family] * stature / max(tip_len, 1)
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
    layer = weapon.transform(frame.size, Image.AFFINE, coeffs, resample=Image.BICUBIC)
    out = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    if socket["front"]:
        out.alpha_composite(frame)
        out.alpha_composite(layer)
    else:
        out.alpha_composite(layer)
        out.alpha_composite(frame)
    return out
