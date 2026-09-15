"""Contact sheets of every creature in the game beside the flag that flips it.

**No gate can see which way a sprite is drawn**, and this project has now paid
for that four times: enemies "facing backwards" three times before
`EnemyData.art_facing` existed, once more when the Rootshield's own art
disagreed with itself, and on 2026-09-15 the Ash Hound - a black wolf with an
orange fire crest, drawn facing left and authored `art_faces_right = true`, so
every one of them walked backwards for as long as it had existed. The owner
spotted each of them from play.

So the check is a picture, and this makes taking it one command rather than a
session of one-off scripts. Each cell is the creature's base sprite with the
flag that decides how the field flips it printed over it, and the whole roster
is on two pages - which is the only way a wrong one is *obvious* rather than
merely visible.

    python tools/facing_sheet.py            # wildlife, to the scratch folder
    python tools/facing_sheet.py --enemies  # the breeds, elites and bosses
    python tools/facing_sheet.py --out DIR

**How to read one.** Find the head. `R=true` must be a creature whose head is
on the right of the picture, `R=false` one whose head is on the left, and `TD`
is a creature drawn from above, which is neither - the field turns those onto
their heading instead of mirroring them. A creature whose head and whose
leading prop disagree - a shield on the wrong arm, a lantern in the wrong hand
- is art that cannot be fixed by any flag and has to be redrawn; that is the
2026-09-14 lesson and it is visible here too.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover - a helper, not a gate
    sys.exit("Pillow is needed: python -m pip install pillow")

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = ROOT / "game"

# Per family: where the data is, where the art is, how a sprite path is spelled,
# and which fields decide the flip. The art convention (CLAUDE.md §4) is that a
# sprite path is derived from the resource id, so nothing here is a list of
# files - adding a creature puts it on the sheet.
FAMILIES = {
    "wildlife": {
        "data": "data/wildlife",
        "art": "art/wildlife",
        "sprite": "wildlife_%s.png",
        "right": "art_faces_right",
        "top_down": "art_top_down",
    },
    "enemies": {
        "data": "data/enemies",
        # An enemy's art path is decided by its category - `enemy_` for rank and
        # file, `elite_` for a champion, `boss_` in another folder entirely - so
        # this mirrors `EnemyData.get_sprite_path` rather than assuming one
        # spelling. The first cut assumed `enemy_` and quietly left every elite
        # and every boss off the sheet, which is exactly the half of the roster
        # a facing report most wants to see.
        "art": None,
        "facing": "art_facing",
    },
}

## `EnemyData.Category` by number, and where each keeps its pictures.
CATEGORY_ART = {
    "0": ("art/enemies", "enemy_"),
    "1": ("art/enemies", "elite_"),
    "2": ("art/bosses", "boss_"),
    "3": ("art/enemies", "enemy_"),
    "4": ("art/enemies", "enemy_"),
}

CELL = 210
COLUMNS = 7
PER_PAGE = 21


def _flag(text: str, key: str) -> str | None:
    found = re.search(r"^%s = (.+)$" % re.escape(key), text, re.M)
    return found.group(1).strip() if found else None


def _label(text: str, family: dict) -> str:
    if "facing" in family:
        facing = _flag(text, family["facing"]) or "0"
        return {"0": "FRONT", "1": "R=true", "2": "R=false"}.get(facing, "?" + facing)
    right = _flag(text, family["right"]) or "false"
    top = _flag(text, family.get("top_down", "")) or "false"
    return "R=%s%s" % (right, "  TD" if top == "true" else "")


def _art_for(stem: str, text: str, family: dict) -> pathlib.Path | None:
    """Where this resource's picture lives, by the same rule the game uses."""
    if family["art"] is not None:
        return GAME / family["art"] / (family["sprite"] % stem)
    # `sprite_id` lets several resources share one painting, exactly as the game
    # reads it; without it the id is the name.
    visual = _flag(text, "sprite_id") or ""
    visual = visual.strip('"') or stem
    folder, prefix = CATEGORY_ART.get(_flag(text, "category") or "0",
        ("art/enemies", "enemy_"))
    return GAME / folder / ("%s%s.png" % (prefix, visual))


def _sheet(family: dict, out: pathlib.Path, name: str) -> int:
    rows: list[tuple[str, str, pathlib.Path]] = []
    for resource in sorted((GAME / family["data"]).glob("*.tres")):
        text = resource.read_text(encoding="utf-8", errors="ignore")
        art = _art_for(resource.stem, text, family)
        if art is not None and art.exists():
            rows.append((resource.stem, _label(text, family), art))
    pages = 0
    for start in range(0, len(rows), PER_PAGE):
        chunk = rows[start:start + PER_PAGE]
        tall = ((len(chunk) + COLUMNS - 1) // COLUMNS) * (CELL + 22)
        sheet = Image.new("RGBA", (COLUMNS * CELL, tall), (22, 22, 26, 255))
        pen = ImageDraw.Draw(sheet)
        for index, (stem, label, art) in enumerate(chunk):
            x = (index % COLUMNS) * CELL
            y = (index // COLUMNS) * (CELL + 22)
            picture = Image.open(art).convert("RGBA")
            # Nearest, always: these are pixel paintings and a smooth downscale
            # blurs exactly the eye and muzzle the reader is looking for.
            scale = min(CELL / picture.width, CELL / picture.height)
            picture = picture.resize((max(1, int(picture.width * scale)),
                max(1, int(picture.height * scale))), Image.NEAREST)
            sheet.alpha_composite(picture,
                (x + (CELL - picture.width) // 2, y + 22 + (CELL - picture.height) // 2))
            pen.text((x + 3, y + 5), "%s  %s" % (stem, label), fill=(255, 240, 200, 255))
        target = out / ("%s_facing_%d.png" % (name, pages))
        sheet.save(target)
        print("wrote %s" % target)
        pages += 1
    return len(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--enemies", action="store_true",
        help="the enemy roster instead of the wildlife one")
    parser.add_argument("--out", default=str(ROOT / "build" / "facing"),
        help="where to write the pages")
    args = parser.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    name = "enemies" if args.enemies else "wildlife"
    count = _sheet(FAMILIES[name], out, name)
    print("%d %s on the sheet" % (count, name))


if __name__ == "__main__":
    main()
