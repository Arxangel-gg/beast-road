"""Composes the Arsenal's card icons.

    python tools/compose_arsenal_icons.py [contact-sheet.png]

The Arsenal's card icons, composed from the game's own painted art (2026-09-27).

PixelLab's allowance is spent until 2026-10-11 and the production-art gate
refuses a placeholder, so every icon here is a new arrangement of shipped
paintings - spell effects, relics and towers - never a shape drawn in code.
A soft glow under each is the art's own alpha, blurred and tinted.
"""
import os, math
from PIL import Image, ImageFilter, ImageEnhance, ImageChops

GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'game')
OUT = os.path.join(GAME, 'art', 'icons', 'road_cards')
SIZE = 128


def art(rel):
    return Image.open(os.path.join(GAME, rel)).convert('RGBA')


def spell(name):
    return art('art/icons/spells/spell_%s.png' % name)


def relic(n):
    return art('art/icons/relics/relic_%02d.png' % n)


def tower(name):
    im = art('art/towers/tower_%s.png' % name)
    box = im.getbbox()
    return im.crop(box) if box else im


def fit(im, size):
    w, h = im.size
    scale = size / max(w, h)
    return im.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)


def hue(im, shift=0.0, sat=1.0, bright=1.0):
    """Turns an image's hue by `shift` of the wheel, keeping its alpha."""
    r, g, b, a = im.split()
    hsv = Image.merge('RGB', (r, g, b)).convert('HSV')
    h, s, v = hsv.split()
    h = h.point(lambda x: int((x + shift * 255) % 256))
    s = s.point(lambda x: max(0, min(255, int(x * sat))))
    v = v.point(lambda x: max(0, min(255, int(x * bright))))
    out = Image.merge('HSV', (h, s, v)).convert('RGB')
    out.putalpha(a)
    return out


def place(canvas, im, centre, size, angle=0.0):
    piece = fit(im, size)
    if angle:
        piece = piece.rotate(angle, resample=Image.BICUBIC, expand=True)
    x = int(centre[0] - piece.width / 2)
    y = int(centre[1] - piece.height / 2)
    layer = Image.new('RGBA', canvas.size)
    layer.alpha_composite(piece, (max(x, -piece.width), max(y, -piece.height)) if False else (0, 0))
    layer = Image.new('RGBA', canvas.size)
    layer.paste(piece, (x, y), piece)
    canvas.alpha_composite(layer)


def glow(canvas, tint, strength=0.55, radius=6):
    """A halo from the composition's own alpha."""
    a = canvas.split()[3].filter(ImageFilter.GaussianBlur(radius))
    a = a.point(lambda x: int(x * strength))
    halo = Image.new('RGBA', canvas.size, tint + (0,))
    halo.putalpha(a)
    base = Image.new('RGBA', canvas.size)
    base.alpha_composite(halo)
    base.alpha_composite(canvas)
    return base


def orbit(im, count, ring, size, centre=(64, 64), start=-90.0, radial=True):
    canvas = Image.new('RGBA', (SIZE, SIZE))
    for i in range(count):
        a = math.radians(start + 360.0 * i / count)
        at = (centre[0] + math.cos(a) * ring, centre[1] + math.sin(a) * ring)
        place(canvas, im, at, size, angle=(-math.degrees(a) - 90.0) if radial else 0.0)
    return canvas


def compose(card_id):
    c = Image.new('RGBA', (SIZE, SIZE))
    if card_id == 'ember_wisps':
        c = orbit(spell('ember_fall'), 3, 34, 58)
        return glow(c, (255, 140, 60))
    if card_id == 'frost_shards':
        c = orbit(spell('frost_lance'), 6, 30, 84)
        return glow(c, (120, 200, 255), 0.9, 7)
    if card_id == 'seeking_flames':
        place(c, spell('ember_fall'), (46, 80), 70, angle=-20)
        place(c, spell('ember_fall'), (82, 46), 84, angle=-20)
        return glow(c, (255, 150, 70))
    if card_id == 'chain_spark':
        place(c, spell('sky_lance'), (30, 42), 104, angle=-35)
        place(c, spell('sky_lance'), (64, 74), 104, angle=35)
        place(c, spell('sky_lance'), (98, 46), 104, angle=-35)
        return glow(c, (150, 190, 255), 0.7)
    if card_id == 'thunderclap':
        place(c, hue(spell('tremor'), 0.52, 0.8, 1.05), (64, 64), 124)
        place(c, spell('sky_lance'), (64, 60), 64)
        return glow(c, (160, 190, 255), 0.4)
    if card_id == 'thorn_wake':
        place(c, spell('thorn_volley'), (44, 84), 70)
        place(c, spell('thorn_volley'), (84, 48), 88)
        return glow(c, (140, 210, 90), 0.4)
    if card_id == 'stone_rain':
        place(c, spell('stonefall'), (40, 50), 64)
        place(c, spell('stonefall'), (76, 76), 96)
        return c
    if card_id == 'marrow_seekers':
        place(c, hue(spell('marrow_drain'), 0.33, 0.9, 1.1), (64, 64), 118)
        return glow(c, (150, 240, 190), 0.5)
    if card_id == 'sentry_wisps':
        place(c, tower('arc_coil'), (64, 72), 96)
        c2 = orbit(hue(spell('cinder_nova'), 0.12, 0.6, 1.1), 3, 46, 40, centre=(64, 58), radial=False)
        c.alpha_composite(c2)
        return glow(c, (230, 240, 150), 0.45)
    if card_id == 'arc_lattice':
        place(c, tower('arc_coil'), (26, 76), 70)
        place(c, tower('arc_coil'), (102, 76), 70)
        place(c, spell('sky_lance'), (64, 44), 108, angle=90)
        return glow(c, (150, 190, 255), 0.5)
    if card_id == 'fortress_barrage':
        place(c, tower('stonewatch'), (50, 76), 96)
        place(c, spell('stonefall'), (94, 36), 60)
        return c
    if card_id == 'falling_stars':
        star = hue(spell('ember_fall'), 0.06, 0.7, 1.15)
        place(c, star, (30, 36), 44, angle=-10)
        place(c, star, (60, 64), 56, angle=-10)
        place(c, star, (96, 92), 64, angle=-10)
        return glow(c, (255, 220, 140), 0.6)
    if card_id == 'bell_of_the_hold':
        place(c, spell('tremor'), (64, 64), 124)
        place(c, relic(11), (64, 62), 84)
        return glow(c, (255, 210, 120), 0.35)
    if card_id == 'soulfire':
        place(c, hue(spell('marrow_drain'), 0.9, 1.1, 1.05), (64, 64), 118)
        return glow(c, (255, 120, 60), 0.55)
    if card_id == 'quickening_oil':
        place(c, relic(17), (64, 64), 104)
        return glow(c, (255, 200, 110), 0.35)
    if card_id == 'twin_casting':
        place(c, spell('ember_fall'), (42, 68), 100, angle=20)
        place(c, hue(spell('ember_fall'), 0.55, 0.9, 1.05), (86, 60), 100, angle=-20)
        return glow(c, (255, 190, 140), 0.45)
    if card_id == 'wider_wake':
        place(c, spell('tremor'), (64, 64), 124)
        return c
    if card_id == 'long_burn':
        place(c, relic(65), (64, 70), 104)
        return glow(c, (255, 150, 60), 0.4)
    if card_id == 'kindled_heart':
        place(c, relic(2), (64, 66), 100)
        return glow(c, (255, 110, 60), 0.7, 8)
    if card_id == 'sunwheel':
        c = orbit(spell('ember_fall'), 6, 40, 46)
        place(c, spell('cinder_nova'), (64, 64), 64)
        return glow(c, (255, 190, 80), 0.7)
    if card_id == 'stormcrown':
        c = orbit(spell('sky_lance'), 7, 36, 58)
        return glow(c, (170, 200, 255), 0.8, 8)
    if card_id == 'worldbreaker':
        place(c, hue(spell('tremor'), 0.0, 0.7, 0.9), (64, 70), 124)
        place(c, spell('stonefall'), (64, 58), 104)
        return c
    if card_id == 'briar_sea':
        place(c, spell('thorn_volley'), (34, 86), 64)
        place(c, spell('thorn_volley'), (94, 86), 64)
        place(c, spell('thorn_volley'), (64, 48), 90)
        return glow(c, (120, 220, 90), 0.5)
    raise KeyError(card_id)


IDS = ['ember_wisps', 'frost_shards', 'seeking_flames', 'chain_spark', 'thunderclap',
       'thorn_wake', 'stone_rain', 'marrow_seekers', 'sentry_wisps', 'arc_lattice',
       'fortress_barrage', 'falling_stars', 'bell_of_the_hold', 'soulfire',
       'quickening_oil', 'twin_casting', 'wider_wake', 'long_burn', 'kindled_heart',
       'sunwheel', 'stormcrown', 'worldbreaker', 'briar_sea']

if __name__ == '__main__':
    import sys
    sheet = Image.new('RGBA', (len(IDS) * 136 // 2 + 136, 290), (34, 30, 28, 255))
    for i, card_id in enumerate(IDS):
        icon = compose(card_id)
        assert icon.size == (SIZE, SIZE)
        icon.save(os.path.join(OUT, 'card_%s.png' % card_id))
        x = (i % 12) * 136 + 4
        y = (i // 12) * 144 + 4
        sheet.alpha_composite(icon, (x, y))
    if len(sys.argv) > 1:
        sheet.save(sys.argv[1])
    print('icons', len(IDS))
