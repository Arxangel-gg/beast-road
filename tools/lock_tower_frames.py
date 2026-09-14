"""Lock every tower's animation frames to its base sprite.

A tower's idle and attack frames come from PixelLab's animator, which re-renders
the whole sprite: the masonry drifts a pixel or two between frames, pebbles at
the foundation are re-invented or dropped (a transparent hole where the base has
stone), and fine detail is smoothed away. None of that is animation. The base is
the master; a frame may only differ from it where something is genuinely moving.

For each frame: align it to the base by the best integer shift of its silhouette,
then keep the frame's pixels only in connected regions where it differs strongly
from the base (a glow, water, ice, a discharge) or where it adds pixels the base
does not have (a splash, a flash); everywhere else the base's own pixels stand.
The loop therefore closes exactly on the base, which is frame zero.

    python tools/lock_tower_frames.py [--out DIR] [--only id,id] [--report]
"""
import argparse, glob, os, re, sys
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "art", "towers")
ALPHA = 32          # below this a pixel is transparent
COLOUR_T = 48.0     # RGB distance a moving thing exceeds; smoothing and re-rendering do not
MIN_BLOB = 24       # a difference smaller than this many pixels is noise
SEARCH = 6          # pixels of drift to search for


def load(path):
    return np.array(Image.open(path).convert("RGBA")).astype(np.int32)


def best_shift(base, frame):
    b = base[:, :, 3] > ALPHA
    f = frame[:, :, 3] > ALPHA
    best = (None, 0, 0)
    for dy in range(-SEARCH, SEARCH + 1):
        for dx in range(-SEARCH, SEARCH + 1):
            s = np.roll(np.roll(f, dy, 0), dx, 1)
            diff = np.count_nonzero(b != s)
            if best[0] is None or diff < best[0]:
                best = (diff, dx, dy)
    return best[1], best[2]


def lock(base, frame):
    dx, dy = best_shift(base, frame)
    if dx or dy:
        frame = np.roll(np.roll(frame, dy, 0), dx, 1)
        # Rolled-in pixels are wrapped garbage; clear them.
        if dy > 0: frame[:dy, :] = 0
        if dy < 0: frame[dy:, :] = 0
        if dx > 0: frame[:, :dx] = 0
        if dx < 0: frame[:, dx:] = 0
    b_on = base[:, :, 3] > ALPHA
    f_on = frame[:, :, 3] > ALPHA
    colour = np.sqrt(((frame[:, :, :3] - base[:, :, :3]) ** 2).sum(axis=2))
    strong = (colour > COLOUR_T) & b_on & f_on
    added = f_on & ~b_on
    keep = strong | added
    # Drop speckle: open, then label and drop small blobs, then grow a pixel so
    # the edge of a moving thing is not a ring of base pixels.
    keep = ndimage.binary_opening(keep, structure=np.ones((2, 2)))
    labels, n = ndimage.label(keep)
    if n:
        sizes = ndimage.sum(keep, labels, range(1, n + 1))
        small = np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s < MIN_BLOB])
        keep &= ~small
    keep = ndimage.binary_dilation(keep, iterations=1) & (f_on | ~b_on)
    out = base.copy()
    out[keep] = frame[keep]
    return out, (dx, dy), int(keep.sum())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=None, help="write here instead of in place")
    ap.add_argument("--only", default=None)
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--root", default=ROOT, help="the towers folder")
    args = ap.parse_args()
    root = args.root
    bases = sorted(f for f in glob.glob(os.path.join(root, "tower_*.png"))
                   if not re.search(r"_(idle|attack)_\d+\.png$", f))
    only = set(args.only.split(",")) if args.only else None
    for base_path in bases:
        tid = os.path.basename(base_path)[6:-4]
        if only and tid not in only:
            continue
        base = load(base_path)
        for frame_path in sorted(glob.glob(os.path.join(root, f"tower_{tid}_*_*.png"))):
            frame = load(frame_path)
            if frame.shape != base.shape:
                print(f"skip {os.path.basename(frame_path)}: size differs", file=sys.stderr)
                continue
            out, shift, kept = lock(base, frame)
            target = frame_path if args.out is None else os.path.join(args.out, os.path.basename(frame_path))
            Image.fromarray(out.astype(np.uint8), "RGBA").save(target)
            if args.report:
                print(f"{os.path.basename(frame_path):36s} shift {shift} kept {kept:6d} px")


if __name__ == "__main__":
    main()
