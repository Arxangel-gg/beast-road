"""Author an idle loop for a tower whose motion is too small for the animator.

PixelLab's animator treats "an object at rest" as nearly still: asked for a
glowing crystal or a reflecting pool it returns a loop that moves thirty to
eighty pixels, and `lock_tower_frames.py` - correctly - reads that as
re-rendering noise and erases it. Frostpoint and the Stillwater Mirror shipped
three idle frames identical to their base painting for exactly that reason
(owner report, 2026-09-25: "Gen the idle animations for those 2 towers").

The motion both want is specific and small in area, so it is authored here from
the base painting itself rather than generated:

- Frostpoint: the crystal spear pulses (brighter, then a cold halo, then back),
  and a glint slides down the ice facets over the three frames.
- Stillwater Mirror: the reflection ripples as a travelling wobble across its
  rows, the sky in it sways a pixel, and small glints wink on the water.

Frame 0 is the painting and is not written: the loader hands it back as the
first frame, and every displacement here is zero at t = 0, so the loop closes on
the base exactly. Only pixels of the moving part are touched, so the silhouette,
the stone and the iron are the painting's own and the foot never moves.

    python tools/paint_still_idle.py [--out DIR] [--only frostpoint,stillwater_mirror]
"""
import argparse, math, os
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "art", "towers")
FRAMES = 3   # continuation frames; frame 0 is the base painting


def load(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64)


def save(arr, path):
    Image.fromarray(np.clip(np.round(arr), 0, 255).astype(np.uint8), "RGBA").save(path)


def phase(t):
    # 0 at the base frame, rising through 1 and 2 and falling at 3.
    return (1.0 - math.cos(2.0 * math.pi * t / (FRAMES + 1))) / 2.0


def frostpoint(base):
    out = []
    a = base[..., 3]
    r, g, b = base[..., 0], base[..., 1], base[..., 2]
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    ys, xs = np.nonzero(a > 32)
    top = ys.min()
    # The spear: the narrow crystal above the tower's crown.
    spear = np.zeros(a.shape, bool)
    spear[top:top + 34, 84:103] = True
    spear &= (a > 32) & (b > r + 10) & (lum > 110)
    # Ice facets: bright, blue, and not the iron bands.
    ice = (a > 32) & (b > r + 25) & (lum > 125)
    h, w = a.shape
    yy, xx = np.mgrid[0:h, 0:w]
    # Where the motes start: just outside the crown's shoulders, either side.
    motes = [(64, top + 50), (122, top + 48), (72, top + 30), (114, top + 31), (84, top + 22)]
    for t in range(1, FRAMES + 1):
        f = base.copy()
        p = phase(t)
        # The pulse: the crystal brightens toward white-cyan.
        lift = 0.55 * p
        for c, tint in ((0, 210.0), (1, 250.0), (2, 255.0)):
            f[..., c] = np.where(spear, f[..., c] + (tint - f[..., c]) * lift, f[..., c])
        # A cold halo one pixel out from the spear on the peak frame only,
        # nearly white: a mid-alpha tint over a warm ground reads as grey fuzz
        # rather than light (photographed, 2026-09-25).
        if p > 0.8:
            grown = spear.copy()
            grown[1:, :] |= spear[:-1, :]
            grown[:-1, :] |= spear[1:, :]
            grown[:, 1:] |= spear[:, :-1]
            grown[:, :-1] |= spear[:, 1:]
            halo = grown & (a <= 32)
            f[..., 0] = np.where(halo, 225.0, f[..., 0])
            f[..., 1] = np.where(halo, 248.0, f[..., 1])
            f[..., 2] = np.where(halo, 255.0, f[..., 2])
            f[..., 3] = np.where(halo, 150.0, f[..., 3])
        # The glint: a diagonal band sliding down the facets, one step a frame,
        # with a four-point sparkle where it crosses the left face.
        centre = top + 44 + (t - 1) * 44
        band = np.abs((yy - centre) - (xx - 93) * 0.55) < 3.5
        glint = band & ice & ~spear
        for c, tint in ((0, 240.0), (1, 253.0), (2, 255.0)):
            f[..., c] = np.where(glint, f[..., c] + (tint - f[..., c]) * 0.8, f[..., c])
        # The ice is already near white (mean luminance 194), so a lighter band
        # alone has nothing to read against. A deeper blue trailing edge under it
        # is what makes a streak of light on a pale surface visible.
        edge = (np.abs((yy - centre) - (xx - 93) * 0.55 - 4.5) < 1.5) & ice & ~spear
        for c, tint in ((0, 96.0), (1, 168.0), (2, 226.0)):
            f[..., c] = np.where(edge, f[..., c] + (tint - f[..., c]) * 0.45, f[..., c])
        row_y = int(centre - 12 * 0.55)
        if 0 <= row_y < h:
            cols = np.nonzero(ice[row_y, :93])[0]
            if cols.size:
                sx = int(cols[cols.size // 2])
                for ox, oy, k in ((0, 0, 1.0), (1, 0, 0.7), (-1, 0, 0.7), (0, 1, 0.7), (0, -1, 0.7)):
                    x, y = sx + ox, row_y + oy
                    if 0 <= x < w and 0 <= y < h and a[y, x] > 32:
                        f[y, x, :3] = f[y, x, :3] + (255.0 - f[y, x, :3]) * k
        # Frost motes lifting off the crown: born on the first frame, risen on
        # the second, fading on the third, and gone on the base frame - so they
        # read on any ground, which a streak on pale ice does not.
        for i, (mx, my) in enumerate(motes):
            rise = 7 * (t - 1) + (i % 2) * 2
            y, x = my - rise, mx + ((t + i) % 2)
            alpha = (230.0, 200.0, 110.0)[t - 1]
            if 0 <= y < h and 0 <= x < w and a[y, x] <= 32:
                f[y, x] = (232.0, 249.0, 255.0, alpha)
                for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    inside = 0 <= y + oy < h and 0 <= x + ox < w
                    if inside and a[y + oy, x + ox] <= 32 and f[y + oy, x + ox, 3] < alpha * 0.35:
                        f[y + oy, x + ox] = (210.0, 240.0, 255.0, alpha * 0.35)
        out.append(f)
    return out


def stillwater_mirror(base):
    out = []
    a = base[..., 3]
    r, g, b = base[..., 0], base[..., 1], base[..., 2]
    h, w = a.shape
    yy, xx = np.mgrid[0:h, 0:w]
    # The water is the ellipse inside the rim; within it, the blue and the
    # clouds are water and the beige stone of the rim is not.
    blue = (a > 32) & (b > r + 25) & (b > g + 5) & (yy < 90)
    bys, bxs = np.nonzero(blue)
    cx, cy = (bxs.min() + bxs.max()) / 2.0, (bys.min() + bys.max()) / 2.0
    rx, ry = (bxs.max() - bxs.min()) / 2.0, (bys.max() - bys.min()) / 2.0
    inside = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1.0
    water = inside & (a > 32) & (b >= r - 4)
    rng = np.random.default_rng(20260925)
    glints = [(int(cx + rng.uniform(-0.7, 0.7) * rx), int(cy + rng.uniform(-0.6, 0.6) * ry))
              for _ in range(9)]
    for t in range(1, FRAMES + 1):
        f = base.copy()
        s = math.sin(2.0 * math.pi * t / (FRAMES + 1))
        c = phase(t)
        for y in range(h):
            row = np.nonzero(water[y])[0]
            if row.size < 3:
                continue
            k = 2.0 * math.pi * (y - cy) / 9.0
            dx = int(round(1.6 * (s * math.sin(k) + c * math.cos(k))))
            if dx == 0:
                continue
            src = np.clip(row - dx, row.min(), row.max())
            # Only sample the water itself, so the rim never smears inward.
            src = np.where(water[y, src], src, row)
            f[y, row, :3] = base[y, src, :3]
        # Glints wink on the water, three a frame, never on the base frame.
        for i, (gx, gy) in enumerate(glints):
            if i % FRAMES != t - 1:
                continue
            for ddx in (-1, 0, 1):
                x = gx + ddx
                if 0 <= x < w and water[gy, x]:
                    k = 0.85 if ddx == 0 else 0.45
                    f[gy, x, :3] = f[gy, x, :3] + (np.array([245.0, 252.0, 255.0]) - f[gy, x, :3]) * k
        out.append(f)
    return out


RECIPES = {"frostpoint": frostpoint, "stillwater_mirror": stillwater_mirror}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=None)
    ap.add_argument("--only", default=None)
    args = ap.parse_args()
    only = set(args.only.split(",")) if args.only else set(RECIPES)
    for tid, recipe in RECIPES.items():
        if tid not in only:
            continue
        base = load(os.path.join(ROOT, "tower_%s.png" % tid))
        for i, frame in enumerate(recipe(base), start=1):
            name = "tower_%s_idle_%02d.png" % (tid, i)
            save(frame, os.path.join(args.out or ROOT, name))
            print("wrote", name)


if __name__ == "__main__":
    main()
