"""Install a generated boss's base and its frames in one shared coordinate space.

    python tools/install_boss_frames.py SOURCE_DIR game/art/bosses boss_last_anchor 384

`SOURCE_DIR` holds the raw generated PNGs at the animator's own canvas:

    base.png          the sprite every frame was animated from
    idle_*.png        the breathing loop, in order
    move_*.png        the walk cycle, in order
    atk_*.png         the swing, in order

**Why this is not `prepare_generated_sprite.py` run once per file.** That script
trims each image to its *own* subject and centres it, which is right for one
sprite and wrong for a sequence: a frame whose arms are down crops tighter than
one with them raised, so every frame lands at a different scale and the body
jumps between them. `enemy_walk_check` measures exactly that kind of drift and
`tools/lock_animation_region.py` exists to repair it after the fact.

So the transform is computed **once**, from the union of every frame's bounds,
and applied to all of them. A frame that reaches further than the base is not
clipped, the ground line is the same row in every frame by construction, and
nothing has to be re-aligned afterwards.

The base is re-written with the rest, because it has to share their space: a
base fitted on its own is a base the frames are all slightly wrong against.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

# How much of the canvas the widest pose may fill. The same 0.92 the single
# sprite path uses, so a boss installed this way is the size bosses are.
FILL: float = 0.92
# Alpha at or below which a texel is treated as invisible. The generator leaves
# a very broad soft matte and counting it expands every bound to the canvas.
HAZE: int = 10


def _bounds(image: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A").point(lambda value: 255 if value > HAZE else 0)
    return alpha.getbbox()


def _alpha_correct_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    clipped = alpha.point(lambda value: 0 if value <= HAZE else value)
    rgba.putalpha(clipped)
    # Pillow premultiplies internally; clearing invisible RGB first stops the
    # generator's matte colour bleeding into the edge.
    clean = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    clean.alpha_composite(rgba)
    return clean.resize(size, Image.Resampling.LANCZOS)


def install(source: Path, destination: Path, stem: str, canvas: int) -> None:
    jobs: list[tuple[str, Path]] = []
    base = source / "base.png"
    if not base.exists():
        raise SystemExit("no base.png in %s" % source)
    jobs.append(("", base))
    for prefix, pattern in (("idle", "idle_*.png"), ("move", "move_*.png"),
                            ("attack", "atk_*.png")):
        for index, path in enumerate(sorted(source.glob(pattern)), start=1):
            jobs.append(("_%s_%02d" % (prefix, index), path))

    images = [(suffix, Image.open(path).convert("RGBA")) for suffix, path in jobs]

    # One transform for the whole sequence, from the union of every pose.
    low_x = low_y = 10 ** 9
    high_x = high_y = 0
    for _suffix, image in images:
        found = _bounds(image)
        if found is None:
            continue
        low_x, low_y = min(low_x, found[0]), min(low_y, found[1])
        high_x, high_y = max(high_x, found[2]), max(high_y, found[3])
    if high_x <= low_x or high_y <= low_y:
        raise SystemExit("nothing visible in %s" % source)

    wide, tall = high_x - low_x, high_y - low_y
    room = int(round(canvas * FILL))
    scale = min(room / wide, room / tall)
    size = (max(1, int(round(wide * scale))), max(1, int(round(tall * scale))))
    at = ((canvas - size[0]) // 2, (canvas - size[1]) // 2)

    # Fit every pose through the one transform first, then stand them all on
    # the base's own ground line.
    #
    # **Both steps are needed and they fix different things.** The shared
    # transform is what stops the body changing *size* between frames; the
    # alignment is what stops it changing *height*, which a shared transform
    # cannot do because the animator legitimately moves the subject inside the
    # canvas - a slam reaches lower than a stand, and the bounds grow with it.
    # `tools/lock_animation_region.py --align-ground` is the same repair applied
    # afterwards; doing it here means it never has to be.
    destination.mkdir(parents=True, exist_ok=True)
    fitted_sheets: list[tuple[str, Image.Image, int]] = []
    for suffix, image in images:
        subject = image.crop((low_x, low_y, high_x, high_y))
        fitted = _alpha_correct_resize(subject, size)
        sheet = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        sheet.alpha_composite(fitted, at)
        found = _bounds(sheet)
        fitted_sheets.append((suffix, sheet, found[3] if found else 0))

    ground = next(floor for suffix, _sheet, floor in fitted_sheets if suffix == "")
    worst = 0
    for suffix, sheet, floor in fitted_sheets:
        shift = ground - floor
        worst = max(worst, abs(shift))
        if shift != 0:
            moved = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
            moved.alpha_composite(sheet, (0, shift))
            sheet = moved
        out = destination / ("%s%s.png" % (stem, suffix))
        sheet.save(out, optimize=True)
        print("%s  %dx%d  ground %+d" % (out.name, canvas, canvas, shift))

    # **Asserting the spread after aligning would prove nothing** - it is zero
    # by construction, which is the shape of a check that compares two
    # nothings. What is worth knowing is how far a frame had to be moved: a
    # pose a few pixels off its base is animation, and one a long way off is
    # the animator having drawn a different subject.
    print("largest ground correction across %d frames: %d px"
          % (len(fitted_sheets), worst))
    if worst > canvas // 8:
        raise SystemExit(
            "a frame stands %d px off the base - that is a different pose, not a"
            " drift" % worst)


if __name__ == "__main__":
    if len(sys.argv) != 5:
        raise SystemExit(
            "usage: install_boss_frames.py SOURCE_DIR DEST_DIR STEM CANVAS")
    install(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], int(sys.argv[4]))
