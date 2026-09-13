"""Repacks a PixelLab top-down Wang tileset into the pond sheet the game reads.

    python tools/install_pond_tiles.py <region> <tileset-id>

`PondTiles` indexes a 4x4 sheet of 32px tiles by its corners, water first:

    index = NW * 8 + NE * 4 + SW * 2 + SE      (1 = water, 0 = ground)

PixelLab names its tiles `wang_N` and reports an `original_position` on its own
generation grid. **Neither is a position on the sheet it hands back** - using
either produces horizontal banding, which is exactly what the tool this one
replaces got wrong once. The only correct source for where a tile lives is its
own `bounding_box`, and the only correct source for what it *is* is its
`corners` map. Both come from the metadata endpoint.

The tileset's "lower" terrain is the water and its "upper" is the ground, which
is how the prompts are written: lower is what the pond is filled with.
"""
import io
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "art", "battlefield")
TILE = 32
ACROSS = 4
BASE = "https://api.pixellab.ai/mcp/tilesets/%s/%s"


def fetch(tileset_id: str):
    from PIL import Image
    meta = json.loads(urllib.request.urlopen(
        BASE % (tileset_id, "metadata"), timeout=120).read().decode())
    sheet_bytes = urllib.request.urlopen(
        BASE % (tileset_id, "image?inline=true"), timeout=120).read()
    sheet = Image.open(io.BytesIO(sheet_bytes)).convert("RGBA")
    return meta["tileset_data"]["tiles"], sheet


def repack(region: str, tileset_id: str) -> str:
    from PIL import Image
    tiles, sheet = fetch(tileset_id)
    packed = Image.new("RGBA", (ACROSS * TILE, ACROSS * TILE), (0, 0, 0, 0))
    placed = set()
    for tile in tiles:
        corners = tile["corners"]
        # "lower" is the water, which is corner value 1 for `PondTiles`.
        index = 0
        for bit, key in ((8, "NW"), (4, "NE"), (2, "SW"), (1, "SE")):
            if corners.get(key) == "lower":
                index += bit
        box = tile["bounding_box"]
        cut = sheet.crop((box["x"], box["y"],
                          box["x"] + box["width"], box["y"] + box["height"]))
        if cut.size != (TILE, TILE):
            cut = cut.resize((TILE, TILE), Image.NEAREST)
        packed.paste(cut, ((index % ACROSS) * TILE, (index // ACROSS) * TILE))
        placed.add(index)
    missing = sorted(set(range(16)) - placed)
    if missing:
        raise SystemExit("tileset is missing corner combinations: %s" % missing)
    path = os.path.join(OUT, "pond_tiles_%s.png" % region)
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
