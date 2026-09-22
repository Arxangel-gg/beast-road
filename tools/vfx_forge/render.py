"""The forge's Blender half. Run by `forge.py`, never by hand:

    blender --background --python tools/vfx_forge/render.py -- <id> <out> <frames> <size> <seed>

Stands up the shared scene from `forge_kit`, imports the effect named by its
id from `effects/`, and renders its frames as RGBA PNGs on a transparent film.

**Everything an effect may differ in is in its own file**, and everything it
may not - the camera, the film, the clock, the radial coordinate, the swirl,
the noise, the emission, the cell size - is in `forge_kit`. That split is the
whole point: two effects authored a month apart cannot disagree about what a
frame is or how big a cell is, and adding an effect is adding a file.

Everything is white on transparent so the game tints it once per use; the rim
is greyed so a tint reads as a bright core inside a darker edge.
"""
import importlib
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import forge_kit  # noqa: E402  (the path has to be set first)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
EFFECT = argv[0] if len(argv) > 0 else "burst"
OUT = argv[1] if len(argv) > 1 else "/tmp/forge"
FRAMES = int(argv[2]) if len(argv) > 2 else 16
SIZE = int(argv[3]) if len(argv) > 3 else 96
SEED = float(argv[4]) if len(argv) > 4 else 0.0

try:
    module = importlib.import_module("effects.%s" % EFFECT)
except ImportError as problem:
    raise SystemExit("unknown effect %s (%s)" % (EFFECT, problem))

scene, plane = forge_kit.build_world(FRAMES, SIZE)
tree = forge_kit.build_material(plane, EFFECT)
forge = forge_kit.Forge(tree, FRAMES, SIZE, SEED)
forge.build_scene()
look = module.build(forge)
if look is None or look.mask is None:
    raise SystemExit("effect %s built no mask" % EFFECT)
forge_kit.finish(forge, look)

os.makedirs(OUT, exist_ok=True)
for frame in range(1, FRAMES + 1):
    scene.frame_set(frame)
    scene.render.filepath = os.path.join(OUT, "frame_%03d.png" % frame)
    bpy.ops.render.render(write_still=True)

print("forge rendered %d frames of %s at %d to %s" % (FRAMES, EFFECT, SIZE, OUT))
