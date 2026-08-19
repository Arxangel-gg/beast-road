"""Slice a PixelLab Wang tileset into Beast Road's 16 ground tiles.

    python tools/build_ground_tiles.py <tileset-id> <terrain-id>

A Wang (corner) set is what makes a floor look like ground instead of wallpaper.
Rather than one tile repeating, the region has two materials - earth and moss,
rock and snow - and sixteen tiles covering every way four corners can be one or
the other. Laid against a noise field they interlock into organic patches that
never show a repeat, because the repeat is in the *pattern*, not the image.

The engine indexes them by a 4-bit corner mask (bit0=NW, bit1=NE, bit2=SE,
bit3=SW; a set bit means the "upper" material), so the job here is to get from
the generator's sheet to `ground_<terrain>_NN.png`.

Two traps, both called out by the API and both easy to walk into:

**Slice by `bounding_box`, never by the tile's name or `original_position`.**
The name is a Wang index and the position is a cell in the generation grid whose
row can exceed the delivered sheet. Using either slices the wrong rectangles and
produces horizontal banding that looks like a generation fault rather than a
mistake in this script.

**Corners are named, not ordered.** Each tile reports NW/NE/SE/SW explicitly as
"upper" or "lower". Reading them positionally happens to work for some tiles and
silently mirrors the rest.
"""

from __future__ import annotations

import io
import json
import os
import sys
import urllib.request

from PIL import Image

API = "https://api.pixellab.ai/mcp/tilesets"
TOKEN = os.environ.get("PIXELLAB_TOKEN", "")

# Bit order the engine uses. Kept here as the single definition; the baker in
# Battlefield reads the same order out of the filename.
CORNERS = ["NW", "NE", "SE", "SW"]


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url)
    if TOKEN:
        request.add_header("Authorization", f"Bearer {TOKEN}")
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    tileset_id, terrain = sys.argv[1], sys.argv[2]

    meta = json.loads(fetch(f"{API}/{tileset_id}/metadata").decode("utf-8"))
    sheet = Image.open(io.BytesIO(fetch(f"{API}/{tileset_id}/image?inline=true"))).convert("RGBA")
    tiles = meta["tileset_data"]["tiles"]

    out_dir = os.path.join("game", "art", "terrain")
    written = 0
    seen: set[int] = set()
    for tile in tiles:
        corners = tile["corners"]
        mask = 0
        for bit, name in enumerate(CORNERS):
            if corners[name] == "upper":
                mask |= 1 << bit
        box = tile["bounding_box"]
        crop = sheet.crop((box["x"], box["y"],
                           box["x"] + box["width"], box["y"] + box["height"]))
        crop.save(os.path.join(out_dir, f"ground_{terrain}_{mask:02d}.png"))
        seen.add(mask)
        written += 1

    missing = sorted(set(range(16)) - seen)
    print(f"{written} tiles -> {out_dir}/ground_{terrain}_NN.png"
          + (f"  MISSING {missing}" if missing else "  all 16 corners covered"))
    return 0 if not missing else 1


if __name__ == "__main__":
    raise SystemExit(main())
