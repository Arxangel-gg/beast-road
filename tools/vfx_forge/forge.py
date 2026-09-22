"""The VFX forge: stylised effect sheets out of Blender (docs/VFX_FORGE.md).

    python tools/vfx_forge/forge.py list
    python tools/vfx_forge/forge.py burst [--frames 16] [--size 96] [--variants 3]
    python tools/vfx_forge/forge.py --all [--variants 3] [--only hit_]

Renders an effect's frames headless in Blender 4.5 through `render.py`, packs
them left to right into one row, and writes the sheet to
`game/art/vfx/forge_<effect>.png` - and `_01`, `_02` for the takes after the
first. The sheet is white on transparent: the game tints it once per use, so
one sheet serves every element.

**Every effect is a file in `effects/`** and nothing lists them, so a file
dropped in that folder is in `list`, in `--all` and in the app without
anything being edited. An effect declares its own frames, size and takes in
its `SPEC`; the flags here override for a one-off.

A sheet is allowed only for an effect whose size is fixed decoration; a
telegraph is drawn at the blow's own radius and stays procedural. That line is
the design decision in VFX_FORGE.md §3 and it is not this tool's to move.
"""
import argparse
import glob
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import effects  # noqa: E402

BLENDER = os.environ.get(
    "BLENDER", r"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe")
ART = os.path.join(ROOT, "game", "art", "vfx")


def sheet_name(effect_id: str, variant: int) -> str:
    """Take zero keeps the plain name, so a caller that loaded a sheet before
    takes existed never had to learn about them."""
    if variant == 0:
        return "forge_%s.png" % effect_id
    return "forge_%s_%02d.png" % (effect_id, variant)


def render_one(effect_id: str, frames: int, size: int, variant: int,
               out_path: str = "") -> int:
    if not os.path.exists(BLENDER):
        print("blender not found at %s (set BLENDER)" % BLENDER)
        return 2
    with tempfile.TemporaryDirectory(prefix="forge_") as work:
        work = work.replace("\\", "/")
        result = subprocess.run(
            [BLENDER, "--background", "--python", os.path.join(HERE, "render.py"),
             "--", effect_id, work, str(frames), str(size), str(variant)],
            capture_output=True, text=True)
        tail = "\n".join(result.stdout.splitlines()[-6:])
        if result.returncode != 0:
            print(result.stdout[-3000:])
            print(result.stderr[-3000:])
            return result.returncode
        rendered = sorted(glob.glob(os.path.join(work, "frame_*.png")))
        if len(rendered) != frames:
            print("expected %d frames, blender wrote %d\n%s"
                  % (frames, len(rendered), tail))
            return 1
        sheet = Image.new("RGBA", (size * frames, size), (0, 0, 0, 0))
        lit = []
        for index, path in enumerate(rendered):
            frame = Image.open(path).convert("RGBA")
            if frame.size != (size, size):
                frame = frame.resize((size, size), Image.LANCZOS)
            sheet.paste(frame, (index * size, 0))
            alpha = frame.getchannel("A")
            lit.append(sum(1 for a in alpha.getdata() if a > 24))
        out = out_path or os.path.join(ART, sheet_name(effect_id, variant))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        sheet.save(out)
        print("forge: %s take %d -> %s (%dx%d, %d frames; lit %s)"
              % (effect_id, variant, os.path.basename(out),
                 sheet.size[0], sheet.size[1], frames, lit))
        # A material that rendered nothing packs into a perfectly well-formed
        # strip of nothing, which is the one failure a sheet cannot show.
        if all(n == 0 for n in lit):
            print("forge: the sheet is empty - the material rendered nothing")
            return 1
        if lit[0] == 0 and lit[len(lit) // 2] == 0:
            print("forge: nothing is lit in the first half - check the timing")
            return 1
    return 0


def render_effect(spec: dict, frames: int, size: int, variants: int) -> int:
    for variant in range(max(variants, 1)):
        code = render_one(spec["id"], frames, size, variant)
        if code != 0:
            return code
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("effect", nargs="?", default="",
                        help="an effect id, or 'list', or omit with --all")
    parser.add_argument("--frames", type=int)
    parser.add_argument("--size", type=int)
    parser.add_argument("--variants", type=int,
                        help="how many takes; defaults to the effect's own SPEC")
    parser.add_argument("--all", action="store_true", help="every effect on disk")
    parser.add_argument("--only", default="", help="with --all, an id prefix")
    parser.add_argument("--out", default="", help="one sheet to an explicit path")
    parser.add_argument("--json", action="store_true", help="list as JSON")
    args = parser.parse_args()

    if args.effect == "list" or (not args.effect and not args.all):
        rows = effects.catalogue()
        if args.json:
            print(json.dumps(rows, indent=2))
        else:
            for row in rows:
                print("%-18s %2d frames  %3dpx  %d take(s)  %s"
                      % (row["id"], row["frames"], row["size"],
                         row["variants"], row["why"]))
            print("%d effects" % len(rows))
        return 0

    wanted = effects.names() if args.all else [args.effect]
    if args.all and args.only:
        wanted = [name for name in wanted if name.startswith(args.only)]
    missing = [name for name in wanted if name not in effects.names()]
    if missing:
        print("unknown effect(s): %s" % ", ".join(missing))
        print("known: %s" % ", ".join(effects.names()))
        return 2

    failed = []
    for name in wanted:
        spec = effects.spec(name)
        frames = args.frames or spec["frames"]
        size = args.size or spec["size"]
        takes = args.variants if args.variants is not None else spec["variants"]
        if args.out:
            code = render_one(name, frames, size, 0, args.out)
        else:
            code = render_effect(spec, frames, size, takes)
        if code != 0:
            failed.append(name)
    if failed:
        print("forge: FAILED %s" % ", ".join(failed))
        return 1
    print("forge: %d effect(s) rendered" % len(wanted))
    return 0


if __name__ == "__main__":
    sys.exit(main())
