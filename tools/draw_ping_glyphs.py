"""Draws the eight ping glyphs, `game/art/icons/ui/ui_ping_<id>.png`.

The party's pings (triage of 2026-10-07, item 63) are interface chrome, so they
are drawn in the chrome language `draw_save_slot_glyph.py` records for
`ui_settings`, `ui_lock` and `ui_close`: a flat glyph in bone and amber with a
thick near-black outline. The outline is the shape's own silhouette grown, so
every glyph has the same weight of edge whatever its shape.

A glyph is read at 24 pixels in the wheel's spokes and over a mark on the field,
so each is one bold shape: a pin, crossed blades, a shield, coins, a turned
arrow, a cross in a ring, chevrons, and a warning triangle.

    python tools/draw_ping_glyphs.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "art", "icons", "ui")

AMBER = (232, 163, 61, 255)
INK = (11, 20, 22, 255)
BONE = (217, 205, 184, 255)
SCALE = 4
SIZE = 128 * SCALE
LINE = 6 * SCALE


def s(value: float) -> float:
    return value * SCALE


def outlined(fill: Image.Image) -> Image.Image:
    """The fill over its own silhouette grown by the line, in ink."""
    alpha = fill.getchannel("A")
    grown = alpha
    for _step in range(LINE // 4):
        grown = grown.filter(ImageFilter.MaxFilter(9))
    ink = Image.new("RGBA", fill.size, INK)
    base = Image.new("RGBA", fill.size, (0, 0, 0, 0))
    base.paste(ink, (0, 0), grown)
    base.alpha_composite(fill)
    return base


def bar(draw: ImageDraw.ImageDraw, a: tuple, b: tuple, width: float, fill: tuple) -> None:
    draw.line((s(a[0]), s(a[1]), s(b[0]), s(b[1])), fill=fill, width=int(s(width)))
    for end in (a, b):
        r = s(width) * 0.5
        draw.ellipse((s(end[0]) - r, s(end[1]) - r, s(end[0]) + r, s(end[1]) + r), fill=fill)


def here() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    # A map pin: a round head and a point to the ground.
    draw.ellipse((s(30), s(12), s(98), s(80)), fill=AMBER)
    draw.polygon([(s(36), s(62)), (s(92), s(62)), (s(64), s(118))], fill=AMBER)
    out = outlined(image)
    d = ImageDraw.Draw(out)
    d.ellipse((s(50), s(32), s(78), s(60)), fill=INK)
    return out


def attack() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    # Two blades crossed, the hilts amber below.
    bar(draw, (26, 104), (100, 22), 13, BONE)
    bar(draw, (102, 104), (28, 22), 13, BONE)
    bar(draw, (18, 86), (44, 112), 10, AMBER)
    bar(draw, (110, 86), (84, 112), 10, AMBER)
    return outlined(image)


def defend() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    # A heater shield: a flat top and a point.
    points = [(s(22), s(16)), (s(106), s(16)), (s(106), s(58))]
    for step in range(13):
        t = step / 12.0
        points.append((s(106 - 42 * t), s(58 + 58 * math.sin(t * math.pi * 0.5))))
    for step in range(13):
        t = step / 12.0
        points.append((s(64 - 42 * t), s(116 - 58 * (1.0 - math.cos(t * math.pi * 0.5)))))
    points.append((s(22), s(16)))
    draw.polygon(points, fill=BONE)
    out = outlined(image)
    d = ImageDraw.Draw(out)
    d.ellipse((s(48), s(36), s(80), s(68)), fill=AMBER, outline=INK, width=int(s(4)))
    return out


def loot() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    # Coins stacked and one leaning on them.
    for index in range(3):
        y = 92 - index * 16
        draw.ellipse((s(14), s(y - 14), s(78), s(y + 14)), fill=AMBER)
    draw.ellipse((s(56), s(30), s(116), s(90)), fill=AMBER)
    out = outlined(image)
    d = ImageDraw.Draw(out)
    for index in range(3):
        y = 92 - index * 16
        d.arc((s(14), s(y - 14), s(78), s(y + 14)), 0, 180, fill=INK, width=int(s(3)))
    d.ellipse((s(70), s(44), s(102), s(76)), outline=INK, width=int(s(4)))
    return out


def retreat() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    # A return arrow: back along the top, round, and down - the way you came.
    draw.arc((s(44), s(36), s(116), s(108)), -90, 90, fill=BONE, width=int(s(20)))
    draw.rectangle((s(42), s(36), s(80), s(56)), fill=BONE)
    draw.rectangle((s(56), s(88), s(80), s(108)), fill=BONE)
    draw.polygon([(s(6), s(46)), (s(46), s(14)), (s(46), s(78))], fill=AMBER)
    return outlined(image)


def help_() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    # A cross in a ring: the mark every game reads as "help me".
    draw.ellipse((s(14), s(14), s(114), s(114)), fill=BONE)
    out = outlined(image)
    d = ImageDraw.Draw(out)
    d.rectangle((s(54), s(30), s(74), s(98)), fill=INK)
    d.rectangle((s(30), s(54), s(98), s(74)), fill=INK)
    d.rectangle((s(58), s(34), s(70), s(94)), fill=AMBER)
    d.rectangle((s(34), s(58), s(94), s(70)), fill=AMBER)
    return out


def coming() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    # Two chevrons, going.
    for x in (22, 62):
        draw.polygon([(s(x), s(22)), (s(x + 22), s(22)), (s(x + 48), s(64)),
                      (s(x + 22), s(106)), (s(x), s(106)), (s(x + 26), s(64))],
                     fill=BONE if x == 22 else AMBER)
    return outlined(image)


def danger() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.polygon([(s(64), s(12)), (s(118), s(110)), (s(10), s(110))], fill=AMBER)
    out = outlined(image)
    d = ImageDraw.Draw(out)
    d.rounded_rectangle((s(57), s(40), s(71), s(80)), radius=int(s(5)), fill=INK)
    d.ellipse((s(56), s(86), s(72), s(102)), fill=INK)
    return out


GLYPHS = {"here": here, "attack": attack, "defend": defend, "loot": loot,
          "retreat": retreat, "help": help_, "coming": coming, "danger": danger}


def main() -> None:
    for name, build in GLYPHS.items():
        image = build().resize((128, 128), Image.LANCZOS)
        path = os.path.join(OUT, "ui_ping_%s.png" % name)
        image.save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
