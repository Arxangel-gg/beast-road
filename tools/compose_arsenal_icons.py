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
    # The element weapons of 2026-09-27: each pattern in an element it lacked.
    if card_id == 'sawstones':
        stone = hue(spell('stonefall'), 0.0, 0.35, 0.95)
        c = orbit(stone, 3, 36, 56, radial=False)
        return glow(c, (200, 175, 140), 0.4)
    if card_id == 'ice_needles':
        for at in ((40, 84), (64, 64), (88, 44)):
            place(c, spell('frost_lance'), at, 112, angle=-20)
        return glow(c, (130, 205, 255), 1.0, 8)
    if card_id == 'arcane_missiles':
        bolt = hue(spell('ember_fall'), 0.66, 0.9, 1.1)
        for at, size in (((30, 90), 46), ((58, 70), 52), ((90, 82), 46), ((70, 38), 60)):
            place(c, bolt, at, size, angle=-25)
        return glow(c, (190, 160, 255), 0.65)
    if card_id == 'flame_nova':
        place(c, spell('cinder_nova'), (64, 64), 124)
        return glow(c, (255, 130, 60), 0.6)
    if card_id == 'frost_nova':
        place(c, hue(spell('cinder_nova'), 0.52, 0.9, 1.1), (64, 64), 124)
        place(c, spell('frost_lance'), (64, 64), 58, angle=45)
        return glow(c, (140, 210, 255), 0.6)
    if card_id == 'flame_trail':
        # Footprints of fire along the way walked, smallest where it began.
        for at, size in (((26, 100), 38), ((52, 76), 50), ((80, 52), 62), ((104, 26), 44)):
            place(c, spell('cinder_nova'), at, size)
        return glow(c, (255, 140, 60), 0.6)
    if card_id == 'frost_trail':
        frost = hue(spell('cinder_nova'), 0.52, 0.9, 1.1)
        for at, size in (((26, 100), 38), ((52, 76), 50), ((80, 52), 62), ((104, 26), 44)):
            place(c, frost, at, size)
        return glow(c, (140, 210, 255), 0.6)
    if card_id == 'lightning_strike':
        place(c, hue(spell('tremor'), 0.52, 0.8, 1.05), (64, 96), 90)
        place(c, spell('sky_lance'), (64, 52), 110, angle=-45)
        return glow(c, (170, 200, 255), 0.6)
    if card_id == 'ice_pillar':
        place(c, hue(spell('tremor'), 0.5, 0.8, 1.1), (64, 96), 90)
        place(c, spell('frost_lance'), (64, 56), 112, angle=-45)
        return glow(c, (140, 210, 255), 0.6)
    # The defence (2026-09-28, docs/ARSENAL_DEFENSIVE_2026-09-28.md).
    if card_id == 'lantern_ward':
        place(c, spell('bulwark_ward'), (64, 64), 118)
        return glow(c, (255, 225, 150), 0.7, 8)
    if card_id == 'marrow_mend':
        place(c, hue(spell('marrow_drain'), 0.28, 0.85, 1.15), (64, 64), 118)
        return glow(c, (150, 240, 200), 0.55)
    if card_id == 'thornskin':
        c = orbit(spell('thorn_volley'), 6, 40, 52)
        place(c, spell('bulwark_ward'), (64, 64), 62)
        return glow(c, (140, 210, 90), 0.45)
    if card_id == 'guardian_stones':
        c = orbit(hue(spell('stonefall'), 0.0, 0.35, 0.95), 3, 40, 46, radial=False)
        place(c, spell('bulwark_ward'), (64, 64), 54)
        return glow(c, (200, 180, 140), 0.4)
    if card_id == 'frostbound_ring':
        place(c, hue(spell('cinder_nova'), 0.52, 0.9, 1.1), (64, 72), 124)
        place(c, spell('bulwark_ward'), (64, 56), 52)
        return glow(c, (140, 210, 255), 0.6)
    if card_id == 'masons_wisps':
        place(c, tower('mason_shrine'), (64, 72), 96)
        c2 = orbit(hue(spell('cinder_nova'), 0.12, 0.6, 1.1), 3, 44, 34, centre=(64, 58), radial=False)
        c.alpha_composite(c2)
        return glow(c, (230, 210, 150), 0.45)
    if card_id == 'ward_lattice':
        place(c, tower('wind_relay'), (64, 74), 94)
        place(c, spell('bulwark_ward'), (64, 40), 58)
        return glow(c, (200, 220, 255), 0.5)
    if card_id == 'kiln_skin':
        place(c, tower('flash_kiln'), (64, 72), 94)
        place(c, spell('cinder_nova'), (64, 64), 84)
        return glow(c, (255, 140, 60), 0.55)
    if card_id == 'hearthstone':
        place(c, hue(spell('cinder_nova'), 0.06, 0.8, 1.1), (64, 64), 120)
        place(c, relic(11), (64, 62), 70)
        return glow(c, (255, 210, 120), 0.45)
    if card_id == 'gate_ward':
        place(c, tower('stonewatch'), (64, 76), 96)
        place(c, spell('bulwark_ward'), (64, 38), 56)
        return glow(c, (255, 235, 170), 0.5)
    if card_id == 'steadfast_salt':
        place(c, relic(40), (64, 64), 104)
        return glow(c, (220, 220, 240), 0.4)
    if card_id == 'aegis_of_the_road':
        c = orbit(spell('bulwark_ward'), 4, 38, 46, radial=False)
        place(c, spell('bulwark_ward'), (64, 64), 64)
        return glow(c, (255, 240, 170), 0.8, 8)
    if card_id == 'stone_choir':
        c = orbit(hue(spell('stonefall'), 0.0, 0.35, 0.95), 4, 40, 44, radial=False)
        place(c, hue(spell('cinder_nova'), 0.08, 0.5, 1.0), (64, 64), 58)
        return glow(c, (220, 200, 150), 0.55)
    # The second wave (2026-09-30): each pattern in the elements and on the
    # anchors it lacked, composed from the same paintings.
    if card_id == 'gale_blades':
        blade = hue(spell('sky_lance'), 0.43, 0.35, 1.25)
        c = orbit(blade, 3, 32, 92)
        return glow(c, (190, 225, 255), 0.9, 8)
    if card_id == 'hurled_stones':
        rock = hue(spell('stonefall'), 0.0, 0.5, 1.0)
        for at, size in (((34, 88), 44), ((64, 62), 54), ((96, 36), 62)):
            place(c, rock, at, size, angle=-20)
        return glow(c, (210, 180, 140), 0.35)
    if card_id == 'tidal_chain':
        wave = hue(spell('sky_lance'), 0.43, 0.9, 1.05)
        place(c, wave, (30, 42), 104, angle=-35)
        place(c, wave, (64, 74), 104, angle=35)
        place(c, wave, (98, 46), 104, angle=-35)
        return glow(c, (110, 190, 255), 0.7)
    if card_id == 'wildfire_leap':
        flame = hue(spell('sky_lance'), 0.93, 1.1, 1.05)
        place(c, flame, (30, 42), 104, angle=-35)
        place(c, flame, (64, 74), 104, angle=35)
        place(c, flame, (98, 46), 104, angle=-35)
        return glow(c, (255, 140, 60), 0.7)
    if card_id == 'rockslide':
        rock = hue(spell('stonefall'), 0.0, 0.4, 0.95)
        place(c, rock, (30, 40), 50)
        place(c, rock, (64, 78), 58)
        place(c, rock, (98, 44), 50)
        return glow(c, (200, 170, 130), 0.4)
    if card_id == 'quake_pulse':
        place(c, hue(spell('tremor'), 0.0, 0.8, 1.0), (64, 64), 124)
        place(c, hue(spell('stonefall'), 0.0, 0.5, 1.0), (64, 64), 54)
        return glow(c, (210, 180, 130), 0.4)
    if card_id == 'static_wake':
        spark = hue(spell('cinder_nova'), 0.55, 0.6, 1.15)
        for at, size in (((26, 100), 38), ((52, 76), 50), ((80, 52), 62), ((104, 26), 44)):
            place(c, spark, at, size)
        return glow(c, (170, 200, 255), 0.6)
    if card_id == 'meteor_shard':
        place(c, spell('stonefall'), (70, 70), 96)
        place(c, spell('ember_fall'), (44, 40), 70, angle=-30)
        return glow(c, (255, 150, 70), 0.6)
    if card_id == 'pyre_spirits':
        place(c, hue(spell('marrow_drain'), 0.95, 1.1, 1.1), (64, 64), 118)
        return glow(c, (255, 130, 60), 0.6)
    if card_id == 'frost_wraiths':
        place(c, hue(spell('marrow_drain'), 0.5, 0.9, 1.15), (64, 64), 118)
        return glow(c, (140, 210, 255), 0.6)
    if card_id == 'bone_shards':
        place(c, hue(spell('marrow_drain'), 0.12, 0.25, 1.25), (64, 64), 118)
        return glow(c, (235, 225, 200), 0.45)
    if card_id == 'tidewall':
        place(c, hue(spell('bulwark_ward'), 0.5, 0.9, 1.05), (64, 64), 118)
        return glow(c, (120, 200, 255), 0.7, 8)
    if card_id == 'static_skin':
        c = orbit(spell('sky_lance'), 6, 40, 46)
        place(c, spell('bulwark_ward'), (64, 64), 62)
        return glow(c, (170, 200, 255), 0.5)
    if card_id == 'wind_stones':
        c = orbit(hue(spell('stonefall'), 0.55, 0.3, 1.2), 3, 40, 44, radial=False)
        place(c, hue(spell('bulwark_ward'), 0.5, 0.5, 1.1), (64, 64), 54)
        return glow(c, (200, 225, 255), 0.45)
    if card_id == 'dawn_salve':
        place(c, hue(spell('marrow_drain'), 0.08, 0.9, 1.2), (64, 64), 118)
        return glow(c, (255, 210, 130), 0.6)
    if card_id == 'sucking_mire':
        place(c, hue(spell('cinder_nova'), 0.1, 0.35, 0.7), (64, 72), 124)
        place(c, hue(spell('bulwark_ward'), 0.1, 0.3, 0.8), (64, 56), 52)
        return glow(c, (150, 120, 80), 0.5)
    if card_id == 'brazier_wisps':
        place(c, tower('ember_spire'), (64, 72), 96)
        c2 = orbit(spell('ember_fall'), 3, 46, 36, centre=(64, 58), radial=False)
        c.alpha_composite(c2)
        return glow(c, (255, 150, 70), 0.45)
    if card_id == 'tidewire':
        place(c, tower('tide_caller'), (26, 76), 70)
        place(c, tower('tide_caller'), (102, 76), 70)
        place(c, hue(spell('sky_lance'), 0.43, 0.9, 1.05), (64, 44), 108, angle=90)
        return glow(c, (110, 190, 255), 0.5)
    if card_id == 'emberline':
        place(c, tower('sear_coil'), (26, 76), 70)
        place(c, tower('sear_coil'), (102, 76), 70)
        place(c, hue(spell('sky_lance'), 0.93, 1.1, 1.05), (64, 44), 108, angle=90)
        return glow(c, (255, 140, 60), 0.5)
    if card_id == 'storm_beacon':
        place(c, tower('stormvane'), (50, 78), 96)
        place(c, spell('sky_lance'), (94, 36), 70, angle=-45)
        return glow(c, (170, 200, 255), 0.45)
    if card_id == 'glacier_shards':
        place(c, tower('glacier'), (50, 78), 96)
        place(c, spell('frost_lance'), (94, 36), 70, angle=-45)
        return glow(c, (140, 210, 255), 0.45)
    if card_id == 'forge_ward':
        place(c, tower('bellows_forge'), (64, 74), 94)
        place(c, hue(spell('bulwark_ward'), 0.95, 1.0, 1.05), (64, 40), 58)
        return glow(c, (255, 170, 90), 0.5)
    if card_id == 'cinder_salve':
        place(c, tower('flash_kiln'), (64, 72), 96)
        c2 = orbit(hue(spell('cinder_nova'), 0.05, 0.8, 1.15), 3, 44, 34, centre=(64, 58), radial=False)
        c.alpha_composite(c2)
        return glow(c, (255, 190, 120), 0.45)
    if card_id == 'thorn_bastion':
        place(c, tower('bulwark'), (64, 74), 96)
        c2 = orbit(spell('thorn_volley'), 5, 44, 40)
        c.alpha_composite(c2)
        return glow(c, (140, 210, 90), 0.4)
    if card_id == 'tide_bell':
        place(c, hue(spell('tremor'), 0.5, 0.9, 1.1), (64, 64), 124)
        place(c, relic(11), (64, 62), 84)
        return glow(c, (120, 200, 255), 0.4)
    if card_id == 'icefall':
        place(c, hue(spell('cinder_nova'), 0.52, 0.9, 1.1), (78, 88), 76)
        for at, size in (((30, 40), 112), ((58, 58), 118), ((88, 44), 112)):
            place(c, spell('frost_lance'), at, size, angle=-60)
        return glow(c, (140, 210, 255), 1.0, 8)
    if card_id == 'watchfire_crows':
        place(c, spell('call_crow'), (64, 66), 112)
        return glow(c, (190, 215, 255), 0.5)
    if card_id == 'wellspring':
        place(c, tower('healing_well'), (64, 70), 100)
        return glow(c, (120, 200, 255), 0.5)
    # The third wave (2026-09-30, later): the same paintings, new elements.
    if card_id == 'quarry_arc':
        place(c, tower('granite_ballista'), (26, 80), 66)
        place(c, tower('granite_ballista'), (102, 80), 66)
        rock = hue(spell('stonefall'), 0.0, 0.5, 1.0)
        for at, size in (((44, 46), 30), ((64, 34), 36), ((84, 46), 30)):
            place(c, rock, at, size)
        return glow(c, (210, 180, 140), 0.45)
    if card_id == 'tide_motes':
        place(c, tower('tide_caller'), (64, 72), 96)
        c2 = orbit(hue(spell('frost_lance'), 0.0, 0.9, 1.1), 3, 46, 40, centre=(64, 58), radial=False)
        c.alpha_composite(c2)
        return glow(c, (120, 200, 255), 0.5)
    if card_id == 'cairn_stones':
        place(c, tower('mason_shrine'), (64, 72), 96)
        c2 = orbit(hue(spell('stonefall'), 0.0, 0.45, 1.0), 3, 46, 34, centre=(64, 58), radial=False)
        c.alpha_composite(c2)
        return glow(c, (210, 185, 140), 0.45)
    if card_id == 'hearth_flare':
        place(c, hue(spell('cinder_nova'), 0.0, 1.15, 1.1), (64, 64), 124)
        place(c, relic(11), (64, 62), 70)
        return glow(c, (255, 150, 70), 0.55)
    if card_id == 'bedrock_shrug':
        place(c, hue(spell('tremor'), 0.0, 0.55, 0.95), (64, 70), 124)
        rock = hue(spell('stonefall'), 0.0, 0.4, 0.95)
        for at, size in (((32, 40), 34), ((96, 40), 34), ((64, 28), 30)):
            place(c, rock, at, size)
        return glow(c, (205, 175, 130), 0.4)
    if card_id == 'drowned_bell':
        place(c, hue(spell('marrow_drain'), 0.52, 0.9, 1.0), (64, 70), 112)
        place(c, hue(relic(11), 0.5, 0.6, 1.0), (64, 58), 64)
        return glow(c, (110, 180, 255), 0.55)
    if card_id == 'cairnfall':
        rock = hue(spell('stonefall'), 0.0, 0.55, 1.05)
        place(c, rock, (30, 36), 40, angle=-10)
        place(c, rock, (62, 62), 52, angle=-10)
        place(c, rock, (96, 92), 62, angle=-10)
        return glow(c, (215, 185, 140), 0.5)
    if card_id == 'ember_rain':
        place(c, tower('flash_kiln'), (64, 92), 70)
        ember = hue(spell('ember_fall'), 0.0, 1.1, 1.1)
        for at, size in (((32, 30), 38), ((64, 22), 42), ((96, 34), 38)):
            place(c, ember, at, size, angle=-25)
        return glow(c, (255, 140, 60), 0.6)
    if card_id == 'cinder_skin':
        c = orbit(hue(spell('ember_fall'), 0.0, 1.1, 1.1), 6, 40, 40)
        place(c, spell('bulwark_ward'), (64, 64), 62)
        return glow(c, (255, 140, 60), 0.5)
    if card_id == 'ember_stones':
        c = orbit(hue(spell('cinder_nova'), 0.04, 1.0, 1.1), 3, 40, 42, radial=False)
        place(c, spell('bulwark_ward'), (64, 64), 54)
        return glow(c, (255, 160, 80), 0.5)
    if card_id == 'stone_rampart':
        place(c, tower('stonewatch'), (64, 76), 96)
        place(c, hue(spell('bulwark_ward'), 0.0, 0.3, 0.9), (64, 38), 56)
        return glow(c, (210, 190, 150), 0.45)
    if card_id == 'wellspring_tide':
        place(c, tower('stillwater_mirror'), (64, 72), 96)
        c2 = orbit(hue(spell('cinder_nova'), 0.52, 0.8, 1.15), 3, 44, 34, centre=(64, 58), radial=False)
        c.alpha_composite(c2)
        return glow(c, (130, 200, 255), 0.45)
    raise KeyError(card_id)


IDS = ['ember_wisps', 'frost_shards', 'seeking_flames', 'chain_spark', 'thunderclap',
       'thorn_wake', 'stone_rain', 'marrow_seekers', 'sentry_wisps', 'arc_lattice',
       'fortress_barrage', 'falling_stars', 'bell_of_the_hold', 'soulfire',
       'quickening_oil', 'twin_casting', 'wider_wake', 'long_burn', 'kindled_heart',
       'sunwheel', 'stormcrown', 'worldbreaker', 'briar_sea',
       'sawstones', 'ice_needles', 'arcane_missiles', 'flame_nova', 'frost_nova',
       'flame_trail', 'frost_trail', 'lightning_strike', 'ice_pillar',
       'lantern_ward', 'marrow_mend', 'thornskin', 'guardian_stones', 'frostbound_ring',
       'masons_wisps', 'ward_lattice', 'kiln_skin', 'hearthstone', 'gate_ward',
       'steadfast_salt', 'aegis_of_the_road', 'stone_choir',
       'gale_blades',
       'hurled_stones',
       'tidal_chain',
       'wildfire_leap',
       'rockslide',
       'quake_pulse',
       'static_wake',
       'meteor_shard',
       'pyre_spirits',
       'frost_wraiths',
       'bone_shards',
       'tidewall',
       'static_skin',
       'wind_stones',
       'dawn_salve',
       'sucking_mire',
       'brazier_wisps',
       'tidewire',
       'emberline',
       'storm_beacon',
       'glacier_shards',
       'forge_ward',
       'cinder_salve',
       'thorn_bastion',
       'tide_bell',
       'icefall',
       'watchfire_crows',
       'wellspring',
       'quarry_arc', 'tide_motes', 'cairn_stones', 'hearth_flare', 'bedrock_shrug',
       'drowned_bell', 'cairnfall', 'ember_rain', 'cinder_skin', 'ember_stones',
       'stone_rampart', 'wellspring_tide']

if __name__ == '__main__':
    import sys
    # ICON_OUT writes somewhere else, so a new recipe can be looked at before
    # it replaces anything the game draws.
    out = os.environ.get('ICON_OUT', OUT)
    os.makedirs(out, exist_ok=True)
    rows = (len(IDS) + 11) // 12
    sheet = Image.new('RGBA', (12 * 136 + 4, rows * 144 + 4), (34, 30, 28, 255))
    for i, card_id in enumerate(IDS):
        icon = compose(card_id)
        assert icon.size == (SIZE, SIZE)
        icon.save(os.path.join(out, 'card_%s.png' % card_id))
        x = (i % 12) * 136 + 4
        y = (i // 12) * 144 + 4
        sheet.alpha_composite(icon, (x, y))
    if len(sys.argv) > 1:
        sheet.save(sys.argv[1])
    print('icons', len(IDS))
