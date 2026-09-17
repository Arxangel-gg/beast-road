"""Author the pool bars' frame and gloss at the size they are actually drawn.

    python tools/build_bar_frames.py

Writes `game/art/ui/ui_bar_frame.png` and `game/art/ui/ui_bar_gloss.png`.

**Why these are built rather than generated or drawn in code.**

*Not generated.* A bar frame is twenty-six pixels tall on screen. A model draws
UI panels at 256 and up; downscaled to a sixteen-pixel trough every bevel it put
in turns to mush, and the thing that makes a small frame read as a frame is the
single row of highlight along its top and the single row of shadow under it.
That is a decision per pixel, so it is made per pixel.

*Not drawn at runtime.* CLAUDE.md section 4 is clear: art lives in a file at its
final path and final size. This script is the same shape as
`install_pond_tiles.py` and `build_road_tiles.py` - it produces an asset, it does
not paint one every frame.

**The gloss is greyscale on purpose, and that is the fix for the colour report.**
The shipped `ui_bar_fill.png` is a saturated orange ramp with its blue channel
between 0.17 and 0.24, so a bar tinted through it can never be indigo: the
channel simply has no room. `HUD._multiply_for` corrects the *mean* and cannot
correct the *range*. A neutral ramp multiplied by a colour is that colour at
every texel, which is why the pools draw their own fill through this instead.

The frame is a nine-patch with six-pixel margins, so one file serves a tall
health bar and a short stamina one without either bevel being stretched.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "game" / "art" / "ui"

# The palette is the interface's own: the dark warm rim every plate is edged
# with, stone through to a lit top, and bronze rivets at the corners.
RIM = (36, 31, 27, 255)
LIT = (154, 142, 124, 255)
BODY = (107, 98, 87, 255)
DEEP = (84, 76, 67, 255)
SHADE = (43, 39, 35, 255)
TROUGH = (20, 18, 15, 255)
RIVET = (201, 161, 90, 255)
RIVET_LIT = (233, 203, 143, 255)
# **The interior is transparent, not dark.** The frame is laid *over* a bar
# whose own background paints the trough and whose fill paints the pool, so a
# painted centre here would hide both. What this file owns is the ring.
CLEAR = (0, 0, 0, 0)

# Nine-patch: 24 square with six-pixel margins, so the centre a bar stretches is
# twelve and every corner keeps its own bevel at any height.
SIZE = 24
MARGIN = 6


def _frame() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = image.load()

    # **The light is above, so the two long edges are not mirror images.**
    # The top edge is lit on its *outside* and shadowed on the inside face,
    # which points down into the trough; the bottom edge is the other way
    # round, with a lit lip on the inside face that points up. Getting that
    # backwards is what makes a frame read as a flat outline with a hole in
    # it rather than as something cut into the plate.
    top = [RIM, LIT, BODY, DEEP, SHADE, CLEAR]
    bottom = [CLEAR, LIT, BODY, DEEP, SHADE, RIM]
    # The sides carry no such asymmetry - a vertical face catches the same
    # light along its whole length - so they are one profile used both ways.
    side = [RIM, BODY, DEEP, DEEP, SHADE, CLEAR]

    for y in range(SIZE):
        for x in range(SIZE):
            from_top = y
            from_bottom = SIZE - 1 - y
            from_left = x
            from_right = SIZE - 1 - x
            # Whichever edge this texel is nearest decides its colour, so the
            # corners resolve without a special case.
            nearest = min(from_top, from_bottom, from_left, from_right)
            if nearest >= MARGIN - 1:
                px[x, y] = CLEAR
                continue
            if nearest == from_top:
                px[x, y] = top[nearest]
            elif nearest == from_bottom:
                px[x, y] = bottom[MARGIN - 1 - nearest]
            elif nearest == from_left:
                px[x, y] = side[nearest]
            else:
                px[x, y] = side[nearest]

    # Rivets, one per corner, inside the margin so a nine-patch keeps all four
    # however wide or tall the bar is drawn.
    for cx, cy in ((3, 3), (SIZE - 4, 3), (3, SIZE - 4), (SIZE - 4, SIZE - 4)):
        px[cx, cy] = RIVET
        px[cx, cy - 1] = RIVET_LIT
        px[cx + 1, cy] = RIVET
        px[cx + 1, cy - 1] = RIVET
    return image

def _gloss() -> Image.Image:
    """A neutral vertical ramp: lit near the top, falling away below.

    White with a varying alpha rather than a grey with none, so a bar can lay it
    over its own colour and get a sheen instead of a wash - and because a colour
    multiplied by grey loses saturation, which is the whole fault this replaces.
    """
    tall = 32
    image = Image.new("RGBA", (4, tall), (0, 0, 0, 0))
    px = image.load()
    for y in range(tall):
        share = y / float(tall - 1)
        # A short bright lip at the top, then a long fade, then a little lift at
        # the very bottom so the fill does not die into the trough.
        if share < 0.18:
            alpha = 150 - int(share / 0.18 * 60)
        elif share < 0.82:
            alpha = 90 - int((share - 0.18) / 0.64 * 86)
        else:
            alpha = 4 + int((share - 0.82) / 0.18 * 26)
        for x in range(4):
            px[x, y] = (255, 255, 255, max(0, min(255, alpha)))
    return image


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    frame = _frame()
    frame.save(OUT / "ui_bar_frame.png", optimize=True)
    gloss = _gloss()
    gloss.save(OUT / "ui_bar_gloss.png", optimize=True)
    print("ui_bar_frame.png  %dx%d (nine-patch margin %d)" % (SIZE, SIZE, MARGIN))
    print("ui_bar_gloss.png  %dx%d" % gloss.size)


if __name__ == "__main__":
    main()
