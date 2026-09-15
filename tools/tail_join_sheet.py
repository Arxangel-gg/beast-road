"""Draw the beast's tail join exactly as the game hangs it, from the art alone.

**The join is a dozen pixels in a 2560-wide photograph, and it has been
reported four times.** Every previous look at it went through a screenshot of
the whole menu, where the backdrop, the weather veil, the modulate and the
camera scale all sit between the eye and the question. This composes the two
assets by the same three constants the game uses and nothing else, so what is
left on screen is the join and only the join.

The arithmetic is the game's, not an approximation of it:

    root row   = the middle of what the body frame paints in its leftmost
                 columns, which is what `BeastTail.root_of` reads
    tail node  = root + (BEAST_TAIL_OVERLAP, -BEAST_TAIL_LIFT)
    tail image = the node, less the root fraction of its own canvas

  python tools/tail_join_sheet.py [--out PATH] [--zoom 3]
  python tools/tail_join_sheet.py --lift 10 --overlap 22

`--lift` and `--overlap` push the two constants without editing `Balance.gd`,
so a proposed nudge can be looked at before it is authored. The values printed
in the header are the ones actually drawn.
"""

from __future__ import annotations

import argparse
import pathlib
import re

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "game" / "art" / "beast"
BALANCE = ROOT / "game" / "scripts" / "Balance.gd"
SOLID = 128


def constant(name: str, fallback: float) -> float:
    text = BALANCE.read_text(encoding="utf-8")
    found = re.search(r"const %s: float = (-?[\d.]+)" % name, text)
    return float(found.group(1)) if found else fallback


def root_row(body: Image.Image) -> float:
    """The middle of what the frame paints in its leftmost columns - the same
    three columns `BeastTail.root_of` reads, and for the same reason: the
    haunches rise and fall with the gait and one authored row is wrong on most
    frames."""
    pixels = body.convert("RGBA").load()
    rows = [y for y in range(body.height)
            if any(pixels[x, y][3] >= SOLID for x in range(min(3, body.width)))]
    return (min(rows) + max(rows)) * 0.5 if rows else body.height * 0.5


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--body", default="beast_idle_00.png")
    parser.add_argument("--tail", default="beast_tail_idle_00.png")
    parser.add_argument("--lift", type=float, default=None)
    parser.add_argument("--overlap", type=float, default=None)
    parser.add_argument("--zoom", type=int, default=3)
    parser.add_argument("--out", default=None)
    args = parser.parse_args()

    body = Image.open(ART / args.body).convert("RGBA")
    tail = Image.open(ART / args.tail).convert("RGBA")
    lift = args.lift if args.lift is not None else constant("BEAST_TAIL_LIFT", 0.0)
    overlap = (args.overlap if args.overlap is not None
               else constant("BEAST_TAIL_OVERLAP", 28.0))
    root_x = constant("BEAST_TAIL_ROOT", 0.95)
    root_y = 0.365
    found = re.search(r"const BEAST_TAIL_ROOT: Vector2 = Vector2\(([\d.]+), ([\d.]+)\)",
                      BALANCE.read_text(encoding="utf-8"))
    if found:
        root_x, root_y = float(found.group(1)), float(found.group(2))

    # The body's own centre, and the node the tail hangs on.
    row = root_row(body)
    node_x = 1.0 + overlap
    node_y = row - lift
    # The tail image's root pixel lands on that node.
    at_x = int(round(node_x - tail.width * root_x))
    at_y = int(round(node_y - tail.height * root_y))

    pad = max(0, -at_x) + 8
    sheet = Image.new("RGBA", (body.width + pad + 16, body.height + 32), (30, 28, 38, 255))
    sheet.alpha_composite(tail, (at_x + pad, at_y + 16))
    sheet.alpha_composite(body, (pad, 16))

    out = pathlib.Path(args.out) if args.out else ROOT / "tail_join.png"
    zoom = max(1, args.zoom)
    sheet.resize((sheet.width * zoom, sheet.height * zoom), Image.NEAREST).save(out)
    print("stub row %.1f  ·  lift %.1f  ·  overlap %.1f  ·  root %.3f,%.3f"
          % (row, lift, overlap, root_x, root_y))
    print("tail image at %d,%d in the body's own pixels -> %s" % (at_x, at_y, out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
