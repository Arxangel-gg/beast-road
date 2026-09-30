"""Draws `game/art/icons/ui/ui_save_slot.png`, the Wardens (save slots) glyph,
and `ui_pen.png`, the Pen's paw.

Owner, 2026-09-30: "Save Slot icon needed on main menu." The button asked
`IconKit` for an icon called "spirit" that was never drawn, so it showed none.

It is interface chrome, so it is drawn in the chrome language the manifest
names for `ui_settings`, `ui_lock` and `ui_close`: a flat glyph in bone and
amber with a thick near-black outline, sampled off those files. Three Warden
cards fanned behind one another - several Wardens on one machine - the front
one carrying a head-and-shoulders bust. Drawn at four times the size and
reduced, which is how a flat glyph keeps a clean edge at 128.

    python tools/draw_save_slot_glyph.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "art", "icons", "ui", "ui_save_slot.png")
PEN = os.path.join(ROOT, "game", "art", "icons", "ui", "ui_pen.png")

AMBER = (232, 163, 61, 255)
INK = (11, 20, 22, 255)
BONE = (217, 205, 184, 255)
SCALE = 4
SIZE = 128 * SCALE
LINE = 6 * SCALE


def card(draw: ImageDraw.ImageDraw, box: tuple, fill: tuple) -> None:
    """A rounded card: the outline is the card drawn larger in ink."""
    x0, y0, x1, y1 = box
    draw.rounded_rectangle((x0 - LINE, y0 - LINE, x1 + LINE, y1 + LINE),
                           radius=14 * SCALE, fill=INK)
    draw.rounded_rectangle(box, radius=9 * SCALE, fill=fill)


def main() -> None:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    s = SCALE
    # Two cards behind, stepped up and to the right: more than one Warden.
    card(draw, (52 * s, 14 * s, 112 * s, 92 * s), BONE)
    card(draw, (38 * s, 24 * s, 98 * s, 102 * s), BONE)
    # The front card, amber, the one being chosen.
    card(draw, (22 * s, 34 * s, 84 * s, 116 * s), AMBER)
    # The bust on it: shoulders, then the head, both in ink so they read at 24px.
    draw.pieslice((31 * s, 76 * s, 75 * s, 124 * s), 180, 360, fill=INK)
    draw.ellipse((42 * s, 50 * s, 64 * s, 72 * s), fill=INK)
    # The front card's frame is redrawn over the bust so it stays inside it.
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle((22 * s, 34 * s, 84 * s, 116 * s),
                                           radius=9 * s, fill=255)
    inside = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    inside.paste(image, (0, 0), mask)
    frame = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    card(ImageDraw.Draw(frame), (22 * s, 34 * s, 84 * s, 116 * s), AMBER)
    frame.alpha_composite(inside)
    back = image.copy()
    front_box = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(front_box).rounded_rectangle(
        (22 * s - LINE, 34 * s - LINE, 84 * s + LINE, 116 * s + LINE), radius=14 * s, fill=255)
    back.paste((0, 0, 0, 0), (0, 0), front_box)
    back.alpha_composite(frame)
    out = back.resize((128, 128), Image.LANCZOS)
    out.save(OUT)
    print("wrote", OUT)
    paw()


def blob(draw: ImageDraw.ImageDraw, box: tuple, fill: tuple) -> None:
    """An ellipse with the chrome outline: the ellipse drawn larger in ink."""
    x0, y0, x1, y1 = box
    draw.ellipse((x0 - LINE, y0 - LINE, x1 + LINE, y1 + LINE), fill=INK)


def paw() -> None:
    """The Pen's glyph: a paw print, amber pad and toes in the chrome outline.
    The Pen button asked for "spirit" too, which was never drawn."""
    s = SCALE
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    pad = (34 * s, 58 * s, 94 * s, 110 * s)
    toes = [(16 * s, 40 * s, 38 * s, 66 * s), (36 * s, 16 * s, 58 * s, 44 * s),
            (70 * s, 16 * s, 92 * s, 44 * s), (90 * s, 40 * s, 112 * s, 66 * s)]
    for box in [pad] + toes:
        blob(draw, box, INK)
    for box in [pad] + toes:
        draw.ellipse(box, fill=AMBER)
    # A bone highlight on the pad, the one second colour the chrome carries.
    draw.ellipse((46 * s, 66 * s, 66 * s, 80 * s), fill=BONE)
    image.resize((128, 128), Image.LANCZOS).save(PEN)
    print("wrote", PEN)


if __name__ == "__main__":
    main()
