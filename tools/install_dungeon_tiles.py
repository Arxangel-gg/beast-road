"""Repacks a PixelLab top-down Wang tileset into the sheet a rift's floor reads.

    python tools/install_dungeon_tiles.py <kind> <tileset-id>

`kind` is `dungeon` or `rift`. `DungeonTiles` indexes a 4x4 sheet of 64px
tiles by its corners, **rock first**:

    index = NW * 8 + NE * 4 + SW * 2 + SE      (1 = rock, 0 = floor)

The tileset's "lower" terrain is the floor and its "upper" is the rock, which
is the opposite way round from the ponds: there the water is the lower terrain
and the ground is the upper, here the floor is what was cut *out of* the rock.

As with the ponds (`install_pond_tiles.py`): a tile's place on the sheet comes
from its own `bounding_box` and what it *is* from its `corners` map, never from
its `wang_N` name or its `original_position`.
"""
import io
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "art", "raid")
TILE = 64
ACROSS = 4
BASE = "https://api.pixellab.ai/mcp/tilesets/%s/%s"
KINDS = ("dungeon", "rift")


def fetch(tileset_id: str):
    from PIL import Image
    meta = json.loads(urllib.request.urlopen(
        BASE % (tileset_id, "metadata"), timeout=120).read().decode())
    sheet_bytes = urllib.request.urlopen(
        BASE % (tileset_id, "image?inline=true"), timeout=120).read()
    sheet = Image.open(io.BytesIO(sheet_bytes)).convert("RGBA")
    return meta["tileset_data"]["tiles"], sheet


def repack(kind: str, tileset_id: str) -> str:
    from PIL import Image
    if kind not in KINDS:
        raise SystemExit("kind must be one of %s" % (KINDS,))
    tiles, sheet = fetch(tileset_id)
    packed = Image.new("RGBA", (ACROSS * TILE, ACROSS * TILE), (0, 0, 0, 0))
    placed = set()
    for tile in tiles:
        corners = tile["corners"]
        # "upper" is the rock, which is corner value 1 for `DungeonTiles`.
        index = 0
        for bit, key in ((8, "NW"), (4, "NE"), (2, "SW"), (1, "SE")):
            if corners.get(key) == "upper":
                index += bit
        box = tile["bounding_box"]
        cut = sheet.crop((box["x"], box["y"],
                          box["x"] + box["width"], box["y"] + box["height"]))
        if cut.size != (TILE, TILE):
            cut = cut.resize((TILE, TILE), Image.LANCZOS)
        packed.paste(cut, ((index % ACROSS) * TILE, (index // ACROSS) * TILE))
        placed.add(index)
    missing = sorted(set(range(16)) - placed)
    if missing:
        raise SystemExit("tileset is missing corner combinations: %s" % missing)
    path = os.path.join(OUT, "dungeon_tiles_%s.png" % kind)
    packed.save(path)
    return path


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    path = repack(sys.argv[1], sys.argv[2])
    print("wrote", path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
