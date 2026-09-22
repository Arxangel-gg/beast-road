"""The VFX forge: stylised effect sheets out of Blender (docs/VFX_FORGE.md).

    python tools/vfx_forge/forge.py burst [--frames 16] [--size 96]

Renders the effect's frames headless in Blender 4.5 through `render.py`,
packs them left to right into one row, and writes the sheet to
`game/art/vfx/forge_<effect>.png`. The sheet is white on transparent: the
game tints it once per use, so one sheet serves every element. Every sheet
is declared in docs/ASSET_MANIFEST.md at its exact size, like every asset.

A sheet is allowed only for an effect whose size is fixed decoration; a
telegraph is drawn at the blow's own radius and stays procedural. That line
is the design decision in VFX_FORGE.md and it is not this tool's to move.
"""
import argparse
import glob
import os
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe")
EFFECTS = {"burst": {"frames": 16, "size": 96}}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("effect", choices=sorted(EFFECTS))
    parser.add_argument("--frames", type=int)
    parser.add_argument("--size", type=int)
    parser.add_argument("--out")
    # **How many sheets of this effect to render** (owner, 2026-09-22: the
    # forged effects should "have variations and more procedural in-game
    # variation"). Variant 0 keeps the plain file name, so nothing that
    # already loads a sheet has to learn about this; the rest are numbered.
    parser.add_argument("--variants", type=int, default=1)
    args = parser.parse_args()
    spec = EFFECTS[args.effect]
    frames = args.frames or spec["frames"]
    size = args.size or spec["size"]
    if not os.path.exists(BLENDER):
        print("blender not found at %s (set BLENDER)" % BLENDER)
        return 2
    for variant in range(max(args.variants, 1)):
        code = _render(args, frames, size, variant)
        if code != 0:
            return code
    return 0


def _render(args, frames: int, size: int, variant: int) -> int:
    with tempfile.TemporaryDirectory(prefix="forge_") as work:
        work = work.replace("\\", "/")
        result = subprocess.run(
            [BLENDER, "--background", "--python", os.path.join(HERE, "render.py"), "--",
             args.effect, work, str(frames), str(size), str(variant)],
            capture_output=True, text=True)
        tail = "\n".join(result.stdout.splitlines()[-6:])
        if result.returncode != 0:
            print(result.stdout[-3000:])
            print(result.stderr[-3000:])
            return result.returncode
        rendered = sorted(glob.glob(os.path.join(work, "frame_*.png")))
        if len(rendered) != frames:
            print("expected %d frames, blender wrote %d\n%s" % (frames, len(rendered), tail))
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
        # Variant 0 keeps the plain name. A caller that asked for one sheet
        # gets exactly the file it always got.
        name = "forge_%s.png" % args.effect if variant == 0             else "forge_%s_%02d.png" % (args.effect, variant)
        out = args.out or os.path.join(ROOT, "game", "art", "vfx", name)
        sheet.save(out)
        print("forge: %s -> %s (%dx%d, %d frames; lit pixels per frame %s)"
              % (args.effect, out, sheet.size[0], sheet.size[1], frames, lit))
        if lit[0] == 0 or all(n == 0 for n in lit):
            print("forge: the sheet is empty - the material rendered nothing")
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
