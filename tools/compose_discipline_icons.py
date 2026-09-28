"""Composes the Disciplines' branch, Oath and Spellblade icons.

    python tools/compose_discipline_icons.py [contact-sheet.png]

The tree's phase 2 (2026-09-28, docs/SKILL_TREE_D4_2026-09-28.md) hangs an
enhancement and two forks off every skill, and a fork's icon is its skill's
with an emblem laid over a corner - which is what Diablo IV does with the same
icon in a different frame, and what lets a player read "a branch of Ember
Fall" at a glance. PixelLab's allowance is spent until 2026-10-11 and the
production-art gate refuses a placeholder, so every emblem is a shipped relic
painting, never a shape drawn in code; the halo is the emblem's own alpha,
blurred and tinted. Installing a bespoke painting is overwriting its file.

Reads the node files rather than a table of its own, so a node authored later
gets its icon from the same rule.
"""
import glob, os, re, sys
from PIL import Image, ImageFilter, ImageEnhance

GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'game')
DATA = os.path.join(GAME, 'data', 'disciplines')
OUT = os.path.join(GAME, 'art', 'icons', 'disciplines')
SIZE = 192
KIND_FORM, KIND_UPGRADE, KIND_OATH = 1, 3, 4
ARM_GLOW = [(200, 70, 60), (240, 210, 120), (224, 122, 46), (127, 168, 255)]

# What each branch key wears, as a relic number: the object that says what the
# branch does, from the paintings the road already drops.
EMBLEMS = {
    'enhance': 26,      # the gold orb: more of the same
    'up_power': 18, 'form_power': 18,
    'up_cooldown': 13,
    'up_mana': 70, 'up_kill_mana': 70, 'form_finisher_mana': 70,
    'up_reach': 17,
    'up_radius': 40,
    'up_duration': 42,
    'up_extra': 12,
    'up_shove': 50,
    'up_status_burn': 65, 'form_splash_burn': 65, 'up_vs_burning': 65,
    'up_status_wet': 61, 'up_vs_wet': 58,
    'up_status_brand': 47, 'form_brand_power': 47, 'form_brand_seconds': 47, 'form_vs_branded': 47,
    'up_status_bleed': 2, 'form_bleed_every_hit': 2, 'up_vs_bleeding': 2,
    'up_kill_cooldown': 14,
    'up_heal': 41, 'form_finisher_heal': 41,
    'up_ward': 45, 'form_splash_shield': 45,
    'form_finisher_arc': 49,
    'form_finisher_dash_refund': 9,
    'form_finisher_bolt': 16,
    'form_finisher_cast_discount': 63,
    # The Oaths wear their relic large.
    'oath_lifesteal': 2, 'oath_ward_tower': 19, 'oath_dash_strike': 52, 'oath_mana_pool': 61,
}


def read_node(path):
    s = open(path, encoding='utf-8').read()
    def g(key, default=''):
        m = re.search(r'^%s = (.*)$' % key, s, re.M)
        return m.group(1).strip().strip('"') if m else default
    return {
        'id': g('id'), 'kind': int(g('kind', '0')), 'parent': g('parent_id'),
        'exclusive': g('exclusive'), 'effect': g('effect_id'), 'arm': int(g('discipline', '0')),
    }


def relic(n):
    return Image.open(os.path.join(GAME, 'art', 'icons', 'relics', 'relic_%02d.png' % n)).convert('RGBA')


def icon(node_id):
    p = os.path.join(OUT, 'discipline_%s.png' % node_id)
    return Image.open(p).convert('RGBA') if os.path.exists(p) else None


def fit(im, size):
    box = im.getbbox()
    if box:
        im = im.crop(box)
    w, h = im.size
    scale = size / max(w, h)
    return im.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)


def halo(piece, tint, strength=0.7, radius=9):
    pad = radius * 3
    canvas = Image.new('RGBA', (piece.width + pad * 2, piece.height + pad * 2))
    canvas.paste(piece, (pad, pad), piece)
    a = canvas.split()[3].filter(ImageFilter.GaussianBlur(radius)).point(lambda x: int(x * strength))
    glow = Image.new('RGBA', canvas.size, tint + (0,))
    glow.putalpha(a)
    glow.alpha_composite(canvas)
    return glow


def lay(base, piece, centre):
    layer = Image.new('RGBA', base.size)
    layer.paste(piece, (int(centre[0] - piece.width / 2), int(centre[1] - piece.height / 2)), piece)
    base.alpha_composite(layer)


def root_of(node, nodes):
    at = node
    for _ in range(8):
        if at['kind'] != KIND_UPGRADE:
            return at['id']
        at = nodes.get(at['parent'])
        if at is None:
            return ''
    return ''


def compose(node, nodes):
    tint = ARM_GLOW[node['arm'] % 4]
    if node['kind'] == KIND_UPGRADE:
        base = icon(root_of(node, nodes))
        if base is None:
            return None
        base = base.copy()
        key = 'enhance' if not node['exclusive'] else node['effect']
        if node['exclusive']:
            # A fork's medallion turns a little toward warm or cool, so the two
            # twins read apart on the trunk before the emblem is read.
            base = ImageEnhance.Color(base).enhance(1.12)
        emblem = halo(fit(relic(EMBLEMS.get(key, 26)), 66), (255, 200, 110) if key == 'enhance' else tint)
        lay(base, emblem, (146, 146))
        return base
    if node['kind'] == KIND_OATH:
        form = next((n for n in nodes.values() if n['arm'] == node['arm'] and n['kind'] == KIND_FORM), None)
        base = icon(form['id']) if form else None
        if base is None:
            return None
        base = ImageEnhance.Brightness(base.copy()).enhance(0.55)
        emblem = halo(fit(relic(EMBLEMS.get(node['effect'], 80)), 108), tint, 0.9, 12)
        lay(base, emblem, (96, 98))
        return base
    if node['id'] == 'spellblade':
        base = icon('frost_lance_rite')
        if base is None:
            return None
        base = ImageEnhance.Brightness(base.copy()).enhance(0.6)
        blade = halo(fit(relic(57), 118), (150, 190, 255), 0.9, 12)
        lay(base, blade, (96, 96))
        return base
    return None


def main():
    nodes = {}
    for path in sorted(glob.glob(os.path.join(DATA, '*.tres'))):
        node = read_node(path)
        nodes[node['id']] = node
    made = []
    # Enhancements first, so a fork composed over its root finds the root drawn.
    order = sorted(nodes.values(), key=lambda n: (n['kind'] != KIND_FORM, n['kind'] != KIND_UPGRADE, bool(n['exclusive']), n['id']))
    for node in order:
        target = os.path.join(OUT, 'discipline_%s.png' % node['id'])
        if os.path.exists(target) and node['id'] != 'spellblade' and node['kind'] not in (KIND_UPGRADE, KIND_OATH):
            continue
        image = compose(node, nodes)
        if image is None:
            continue
        image.save(target)
        made.append(node['id'])
    print('composed %d icons' % len(made))
    if len(sys.argv) > 1:
        cols = 12
        cell = 100
        sheet = Image.new('RGBA', (cols * cell, ((len(made) + cols - 1) // cols) * cell), (24, 24, 28, 255))
        for i, node_id in enumerate(made):
            im = icon(node_id).resize((92, 92), Image.LANCZOS)
            sheet.paste(im, ((i % cols) * cell + 4, (i // cols) * cell + 4), im)
        sheet.save(sys.argv[1])


if __name__ == '__main__':
    main()
