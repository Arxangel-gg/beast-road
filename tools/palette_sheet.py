"""A palette check per region: does everything in a region belong to it?

    python tools/palette_sheet.py <out_folder> [region ...]

Core Keeper holds about ninety colours across its whole world, grouped by hue,
and that discipline is most of why a thousand props read as one place
(docs/IDEAS_REVIEW_2026-09-23.md). No gate can see a palette, so this is a
picture, not a verdict: one sheet per region with the region's own palette
across the top - read off its ground, its foliage and its ponds - and every
sprite that walks or stands there below it, ordered by how far its colours sit
from that palette. The ones past the line are flagged in red; they are where to
look first, not faults by definition. A boss may be meant to clash.

Run it after any batch of art for a region, before the art is committed.
"""
import glob
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
PALETTE_SIZE = 16
FLAG_DISTANCE = 0.22
THUMB = 96


def _load(path):
    try:
        return Image.open(path).convert("RGBA")
    except OSError:
        return None


def _pixels(image, step=2):
    out = []
    w, h = image.size
    px = image.load()
    for y in range(0, h, step):
        for x in range(0, w, step):
            r, g, b, a = px[x, y]
            if a >= 200:
                out.append((r / 255.0, g / 255.0, b / 255.0))
    return out


def _palette(pixels, count):
    """A small k-means over the region's reference pixels."""
    if not pixels:
        return []
    pixels = pixels[:: max(1, len(pixels) // 6000)]
    centres = [pixels[int(i * len(pixels) / count)] for i in range(count)]
    for _ in range(8):
        buckets = [[] for _ in centres]
        for p in pixels:
            best = min(range(len(centres)), key=lambda i: _d2(p, centres[i]))
            buckets[best].append(p)
        centres = [tuple(sum(c[k] for c in b) / len(b) for k in range(3)) if b else centres[i]
                   for i, b in enumerate(buckets)]
    return sorted(centres, key=lambda c: (_hue(c), sum(c)))


def _d2(a, b):
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def _hue(c):
    import colorsys
    return colorsys.rgb_to_hsv(*c)[0]


def _distance(pixels, palette):
    """Mean distance from each pixel to its nearest palette colour, 0 to ~1.7."""
    if not pixels or not palette:
        return 0.0
    sample = pixels[:: max(1, len(pixels) // 1500)]
    return sum(min(_d2(p, c) for c in palette) ** 0.5 for p in sample) / len(sample)


def _ids(field, text):
    found = re.search(field + r' = Array\[String\]\(\[(.*?)\]\)', text)
    return re.findall(r'"([^"]+)"', found.group(1)) if found else []


def _enemy_art(enemy_id):
    data = os.path.join(GAME, "data", "enemies", enemy_id + ".tres")
    visual, folder, prefix = enemy_id, "enemies", "enemy_"
    if os.path.exists(data):
        text = open(data, encoding="utf-8").read()
        sprite = re.search(r'sprite_id = "([^"]+)"', text)
        if sprite:
            visual = sprite.group(1)
        category = re.search(r"category = (\d+)", text)
        if category and category.group(1) == "2":
            folder, prefix = "bosses", "boss_"
        elif category and category.group(1) == "1":
            prefix = "elite_"
    return os.path.join(GAME, "art", folder, prefix + visual + ".png")


def region_sheet(region, out):
    tres = os.path.join(GAME, "data", "terrains", region + ".tres")
    text = open(tres, encoding="utf-8").read()
    reference = [os.path.join(GAME, "art", "terrain", "terrain_%s.png" % region)]
    reference += [p for p in glob.glob(os.path.join(GAME, "art", "foliage", "plant_%s_*.png" % region))
                  if "_idle_" not in p]
    ref_pixels = []
    for path in reference:
        image = _load(path)
        if image is not None:
            ref_pixels += _pixels(image, 3)
    palette = _palette(ref_pixels, PALETTE_SIZE)

    subjects = []
    for enemy_id in _ids("enemy_ids", text) + _ids("veteran_ids", text):
        subjects.append((enemy_id, _enemy_art(enemy_id)))
    boss = re.search(r'boss_id = "([^"]+)"', text)
    if boss:
        subjects.append((boss.group(1), _enemy_art(boss.group(1))))
    for path in sorted(p for p in glob.glob(os.path.join(GAME, "art", "foliage", "plant_%s_*.png" % region))
                       if "_idle_" not in p):
        subjects.append((os.path.basename(path)[6:-4], path))

    rows = []
    for name, path in subjects:
        image = _load(path)
        if image is None:
            continue
        rows.append((_distance(_pixels(image), palette), name, image))
    rows.sort(key=lambda r: -r[0])

    per_row = 8
    lines = (len(rows) + per_row - 1) // per_row
    sheet = Image.new("RGB", (per_row * (THUMB + 12) + 20, 90 + lines * (THUMB + 34)), (22, 24, 21))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arial.ttf", 15)
        small = ImageFont.truetype("arial.ttf", 11)
    except OSError:
        font = small = ImageFont.load_default()
    draw.text((10, 8), "%s - palette of its ground and foliage, then its sprites, furthest first"
              % region, fill=(236, 236, 228), font=font)
    for i, colour in enumerate(palette):
        rgb = tuple(int(c * 255) for c in colour)
        draw.rectangle([10 + i * 34, 34, 10 + i * 34 + 30, 64], fill=rgb, outline=(8, 8, 8))
    flagged = []
    for index, (distance, name, image) in enumerate(rows):
        x = 10 + (index % per_row) * (THUMB + 12)
        y = 80 + (index // per_row) * (THUMB + 34)
        thumb = image.copy()
        thumb.thumbnail((THUMB, THUMB))
        plate = Image.new("RGBA", (THUMB, THUMB), (44, 48, 42, 255))
        plate.alpha_composite(thumb, ((THUMB - thumb.width) // 2, (THUMB - thumb.height) // 2))
        sheet.paste(plate.convert("RGB"), (x, y))
        far = distance > FLAG_DISTANCE
        if far:
            flagged.append(name)
            draw.rectangle([x - 2, y - 2, x + THUMB + 1, y + THUMB + 1], outline=(220, 60, 60), width=2)
        draw.text((x, y + THUMB + 3), "%s" % name[:16], fill=(220, 220, 212), font=small)
        draw.text((x, y + THUMB + 16), "%.2f" % distance,
                  fill=(236, 110, 100) if far else (170, 176, 166), font=small)
    path = os.path.join(out, "palette_%s.png" % region)
    sheet.save(path)
    return path, flagged


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    regions = sys.argv[2:] or sorted(os.path.basename(p)[:-5]
                                      for p in glob.glob(os.path.join(GAME, "data", "terrains", "*.tres")))
    for region in regions:
        path, flagged = region_sheet(region, out)
        print("%s: %s%s" % (region, path, ("  flagged: " + ", ".join(flagged)) if flagged else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
