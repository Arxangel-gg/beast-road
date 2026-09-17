"""Repacks a PixelLab top-down Wang tileset into a sheet the Hold's ground reads.

    python tools/install_hold_tiles.py <name> <tileset-id>

`name` is the file it becomes - `hold_turf`, `hold_flags` - and the sheet is a
4x4 of 64px tiles indexed by its corners, **upper terrain first**:

    index = NW * 8 + NE * 4 + SW * 2 + SE      (1 = upper, 0 = lower)

which is the same rule `DungeonTiles` and `PondTiles` already read, so nothing
in the game learns a second way to look a tile up.

**Why the Hold has these at all.** Owner, 2026-09-17: the first cut of the
terraces was quads of one ground texture, and a quad has a hard edge by
construction - *"really make nicer looking procedural modular tilesets that
don't just have hard edges"*. A Wang set is the answer this project already
uses for its ponds and its deep, and the transition art is authored rather than
computed, which is what makes the join between a grass shelf and the earth
below it read as ground rather than as a cut.

As with the ponds and the deep: a tile's place on the sheet comes from its own
`bounding_box` and what it *is* from its `corners` map, never from its `wang_N`
name or its `original_position`. That rule was learned by losing a tileset to
it once.
"""
import io
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "art", "terrain")
TILE = 64
ACROSS = 4
BASE = "https://api.pixellab.ai/mcp/tilesets/%s/%s"


def fetch(tileset_id: str):
    from PIL import Image
    meta = json.loads(urllib.request.urlopen(
        BASE % (tileset_id, "metadata"), timeout=180).read().decode())
    sheet_bytes = urllib.request.urlopen(
        BASE % (tileset_id, "image?inline=true"), timeout=180).read()
    sheet = Image.open(io.BytesIO(sheet_bytes)).convert("RGBA")
    return meta["tileset_data"]["tiles"], sheet


def repack(name: str, tileset_id: str) -> str:
    from PIL import Image
    tiles, sheet = fetch(tileset_id)
    packed = Image.new("RGBA", (ACROSS * TILE, ACROSS * TILE), (0, 0, 0, 0))
    placed = set()
    for tile in tiles:
        corners = tile["corners"]
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
    path = os.path.join(OUT, "%s.png" % name)
    packed.save(path)
    return path


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    print("wrote", repack(sys.argv[1], sys.argv[2]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
