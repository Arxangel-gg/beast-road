"""Chooses which of an animator's frames to install for a structure (2026-10-07).

PixelLab's animator invents things a still structure does not do: a white
splat over a crossbow's idle, a staircase or a puff beside a structure in every
idle frame, a burst painted across an obelisk's attack. So:

  An idle frame is clipped to the base's own silhouette (`clip_to_base`): a
  structure at rest breathes inside its outline and grows nothing beside it.
  What is left is judged by `bright_added` - near-white pixels further than
  NEAR from any white the base already has, so a pale subject moving a pixel
  (ice, steam, a glass shell) is motion and a splat on stone is not. A frame
  over the bound is replaced by the pinned last frame (the base at rest), and a
  structure that loses two is named so its idle can be generated again.

  An attack keeps the three of its four frames that add the fewest bright
  pixels, in their order; it is not clipped, because a recoil may lean out.

Every bound was read off the 2026-10-07 batch of eighty structures.

    python tools/pick_generated_frames.py <base.png> <idle_1..4.png> <attack_1..4.png>
"""
import sys
from PIL import Image, ImageFilter

# Read off the 2026-10-07 batch. BRIGHT counts new white further than NEAR from
# the base's own white, judged after the idle is clipped to its silhouette: real
# idles stay under 50, a white streak across stone was 68 and the splat 498.
# SOLID is opaque pixels outside the grown silhouette, for an attack's report:
# the staircase was 1100.
BRIGHT = 60
SOLID = 500
GROW = 3
# How far from the base's own white a new white pixel is still motion.
NEAR = 4


def bright_added(base_path, frame_path):
    """Near-white opaque pixels the frame adds further than NEAR from any white
    the base already has - so a pale subject (ice, steam, a glass shell) moving
    a pixel is motion, and a white splat on grey stone is not."""
    base = Image.open(base_path).convert("RGBA")
    near = Image.new("L", base.size, 0)
    bp, np_ = base.load(), near.load()
    width, height = base.size
    for y in range(height):
        for x in range(width):
            br, bg, bb, ba = bp[x, y]
            if ba > 200 and br > 200 and bg > 200 and bb > 190:
                np_[x, y] = 255
    near = near.filter(ImageFilter.MaxFilter(NEAR * 2 + 1)).load()
    frame = Image.open(frame_path).convert("RGBA")
    pixels = frame.load()
    count = 0
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a > 200 and r > 225 and g > 225 and b > 215 and near[x, y] == 0:
                count += 1
    return count


def solid_added(base_path, frame_path):
    mask = Image.open(base_path).convert("RGBA").split()[3].point(lambda a: 255 if a > 40 else 0)
    mask = mask.filter(ImageFilter.MaxFilter(GROW * 2 + 1)).load()
    frame = Image.open(frame_path).convert("RGBA")
    alpha = frame.split()[3].load()
    width, height = frame.size
    return sum(1 for y in range(height) for x in range(width) if alpha[x, y] > 200 and mask[x, y] == 0)


def clip_to_base(base_path, frame_path, out_path=None):
    """An idle frame cut to the base's own silhouette, grown by GROW: a still
    structure breathes inside its outline and never grows a staircase or a puff
    beside it. Returns the clipped image, and writes it when given a path."""
    mask = Image.open(base_path).convert("RGBA").split()[3].point(lambda a: 255 if a > 40 else 0)
    mask = mask.filter(ImageFilter.MaxFilter(GROW * 2 + 1))
    frame = Image.open(frame_path).convert("RGBA")
    r, g, b, a = frame.split()
    a = Image.composite(a, Image.new("L", frame.size, 0), mask)
    clipped = Image.merge("RGBA", (r, g, b, a))
    if out_path:
        clipped.save(out_path)
    return clipped


def choose_idle(base_path, frames):
    """frames: the generated idle frames 1..3; returns indices into 1..4 where 4
    is the pinned last frame, and whether the idle should be generated again.
    Judged as it will be installed - clipped to the silhouette."""
    import tempfile, os
    chosen = []
    for n, path in enumerate(frames, 1):
        handle, tmp = tempfile.mkstemp(suffix=".png")
        os.close(handle)
        clip_to_base(base_path, path, tmp)
        bad = bright_added(base_path, tmp) > BRIGHT
        os.remove(tmp)
        chosen.append(4 if bad else n)
    return chosen, chosen.count(4) >= 2


def choose_attack(base_path, frames):
    """frames: the four generated attack frames; the three calmest, in order."""
    marks = sorted((bright_added(base_path, path), n) for n, path in enumerate(frames, 1))
    return sorted(n for _, n in marks[:3])


if __name__ == "__main__":
    base, rest = sys.argv[1], sys.argv[2:]
    idle, redo = choose_idle(base, rest[:3])
    print("idle", idle, "regenerate" if redo else "")
    if len(rest) >= 8:
        print("attack", choose_attack(base, rest[4:8]))
