"""Packs a mount's PixelLab frames into the sheets `MountRig` reads.

    python tools/pack_mount_frames.py <mount_id> idle <dir>=<url> ...
    python tools/pack_mount_frames.py <mount_id> walk --frames <dir>=<url,url,...> ...

**One sheet per state, rows = the eight facings, columns = frames**, which is the
packing `HeroAnimator` already reads and `tools/pack_hero_frames.py` already
builds. A second packing for mounts would be a second thing to keep in step with
the engine's own facing order, and that order is the part that is easy to get
silently wrong.

**The row order is the engine's, not PixelLab's.** `Vector2.angle()` grows
clockwise on screen because Y grows downward, so index 0 is east and index 2 is
south - which is why `MountRig._direction` starts at 2 and calls it "the base
facing". PixelLab names its rotations by compass point in a different order
entirely. Getting this wrong does not error: every horse simply faces somewhere
other than where it is going, which is the family of fault this project has
already paid for six times with `art_facing`.

**Frames are aligned to the base's ground line**, for the reason
`tools/lock_animation_region.py --align-ground` exists: the animator re-renders
the whole sprite, so feet wander by a pixel or two between frames and a walk
cycle that drifts reads as a horse skating. The correction is a translation and
never a repaint - a generated pixel is never invented here.
"""

import argparse
import io
import os
import re
import sys
import urllib.request

from PIL import Image

# The engine's facing order. Index 0 is east; see the module docstring.
FACINGS = [
    "east",
    "south-east",
    "south",
    "south-west",
    "west",
    "north-west",
    "north",
    "north-east",
]

CELL = 192
ART = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "game", "art", "mounts")


def fetch(url: str) -> Image.Image:
    # **A User-Agent, because the store refuses the default one.** Backblaze
    # answers urllib's `Python-urllib/3.x` with 403 and the same URL with 200
    # from curl, which reads as an expired link rather than as a blocked client.
    request = urllib.request.Request(url, headers={"User-Agent": "Wilderhold/1.0"})
    with urllib.request.urlopen(request, timeout=120) as body:
        return Image.open(io.BytesIO(body.read())).convert("RGBA")


def floor_of(frame: Image.Image) -> int:
    """The lowest row with any ink in it, or -1 for an empty frame."""
    box = frame.getbbox()
    return -1 if box is None else box[3]


def fit(frame: Image.Image) -> Image.Image:
    """One frame on a CELL x CELL canvas, centred horizontally, feet at the
    bottom of its own content. Never resampled: a mount is pixel art and a
    resize is a repaint."""
    if frame.size == (CELL, CELL):
        return frame
    if frame.width > CELL or frame.height > CELL:
        raise SystemExit("frame is %dx%d, larger than the %d cell"
                         % (frame.width, frame.height, CELL))
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    out.alpha_composite(frame, ((CELL - frame.width) // 2,
                                (CELL - frame.height) // 2))
    return out


def align(frames, ground: int):
    """Every frame translated so its content sits on the same ground line."""
    out = []
    worst = 0
    for frame in frames:
        floor = floor_of(frame)
        if floor < 0:
            out.append(frame)
            continue
        shift = ground - floor
        worst = max(worst, abs(shift))
        if shift == 0:
            out.append(frame)
            continue
        moved = Image.new("RGBA", frame.size, (0, 0, 0, 0))
        moved.alpha_composite(frame, (0, shift))
        out.append(moved)
    # A correction bigger than an eighth of the cell is not a wandering foot,
    # it is a different pose - and silently sliding one into line would hide
    # the real problem. The same assertion `install_boss_frames.py` makes.
    if worst > CELL // 8:
        raise SystemExit("a frame needed a %d px correction to reach the ground "
                         "line; that is a different pose, not a wandering foot"
                         % worst)
    return out


def expand(url: str, count: int):
    """`.../south/0.png?t=123` becomes frames 0 to count-1 under the same
    folder. PixelLab numbers an animation's frames by index, so the whole state
    is one URL plus a count."""
    match = re.match(r"^(.*/)(\d+)(\.png.*)$", url)
    if match is None:
        raise SystemExit("%r does not end in a numbered frame, so --frames has "
                         "nothing to count from" % url)
    head, _index, tail = match.groups()
    return ["%s%d%s" % (head, n, tail) for n in range(count)]


def ground_of_base(mount_id: str):
    """Where the installed base painting's feet are, or None when there is no
    base yet."""
    path = os.path.join(ART, "mount_%s.png" % mount_id)
    if not os.path.exists(path):
        return None
    return floor_of(Image.open(path).convert("RGBA"))


def pack(mount_id: str, state: str, rows) -> str:
    """rows is a list of eight lists of frames, in engine facing order."""
    columns = max(len(row) for row in rows)
    if columns == 0:
        raise SystemExit("no frames to pack")
    for index, row in enumerate(rows):
        if len(row) != columns:
            raise SystemExit("%s has %d frames and %s has %d - a sheet is a "
                             "rectangle" % (FACINGS[index], len(row),
                                            FACINGS[0], columns))
    sheet = Image.new("RGBA", (columns * CELL, len(rows) * CELL), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, frame in enumerate(row):
            sheet.paste(frame, (x * CELL, y * CELL))
    os.makedirs(ART, exist_ok=True)
    path = os.path.join(ART, "mount_%s_%s.png" % (mount_id, state))
    sheet.save(path)
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mount_id")
    parser.add_argument("state", choices=["idle", "walk", "gallop"])
    parser.add_argument("sources", nargs="+",
                        help="<facing>=<url>[,<url>...], one per facing")
    parser.add_argument("--base", action="store_true",
                        help="also write the single base painting from the "
                             "south facing's first frame")
    parser.add_argument("--frames", type=int, default=0,
                        help="expand each URL ending /0.png into /0..N-1.png. "
                             "PixelLab names an animation's frames by index "
                             "under one folder, so eight URLs a state become "
                             "one - and a hand-pasted list of sixty-four is a "
                             "list with a typo in it.")
    args = parser.parse_args()

    by_facing = {}
    for entry in args.sources:
        if "=" not in entry:
            raise SystemExit("expected <facing>=<url>, got %r" % entry)
        facing, urls = entry.split("=", 1)
        facing = facing.strip()
        if facing not in FACINGS:
            raise SystemExit("%r is not one of %s" % (facing, ", ".join(FACINGS)))
        listed = [u for u in urls.split(",") if u]
        if args.frames > 0:
            if len(listed) != 1:
                raise SystemExit("--frames expands one URL per facing, got %d "
                                 "for %s" % (len(listed), facing))
            listed = expand(listed[0], args.frames)
        by_facing[facing] = listed

    missing = [f for f in FACINGS if f not in by_facing]
    if missing:
        raise SystemExit("no frames for %s - a sheet with a blank row draws "
                         "nothing at all when the mount turns that way"
                         % ", ".join(missing))

    # **One ground line for every state, taken from the base painting.**
    #
    # Aligning each sheet to its own first frame makes each sheet internally
    # consistent and lets the *sheets* disagree with each other - so the horse
    # jumps a few pixels the moment it starts walking, which reads as the mount
    # popping rather than as a foot wandering. The base is the master, the way
    # `lock_tower_frames.py` makes a tower's base the master for its frames.
    rows = []
    ground = ground_of_base(args.mount_id)
    for facing in FACINGS:
        frames = [fit(fetch(url)) for url in by_facing[facing]]
        if ground is None:
            ground = floor_of(frames[0])
        rows.append(align(frames, ground))
        print("  %-11s %d frame(s)" % (facing, len(rows[-1])), file=sys.stderr)

    path = pack(args.mount_id, args.state, rows)
    print(path)

    if args.base:
        south = rows[FACINGS.index("south")][0]
        base = os.path.join(ART, "mount_%s.png" % args.mount_id)
        south.save(base)
        print(base)


if __name__ == "__main__":
    main()
