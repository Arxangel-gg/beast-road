"""Takes the generator's glints off Yuri's tail.

    python tools/clip_tail_glints.py

The tail paintings are the ones the generator made (restored 2026-09-28 - the
passes that repainted them were what made the tail a different animal), and
each carries exactly one near-white speck the hide never reaches: an
animator's invented highlight, the artefact `animator-invents-bright-blobs`
records. `beast_tail_check` refuses a tail brighter than the hide, so the speck
is replaced by the median of its neighbours and nothing else is touched.
Idempotent: a frame with no pixel over the hide's brightest is left alone.
"""
import glob, os
import numpy as np
from PIL import Image

GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'game')
BODY = os.path.join(GAME, 'art', 'beast', 'beast_idle_00.png')


def luminance(rgb):
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


INK = 0.09


def brightest(path):
    """The hide's brightest channel, over the region `beast_tail_check` calls the
    hide: the lower-left of the body frame, below the town. Ink is held out."""
    a = np.array(Image.open(path).convert('RGBA')).astype(float) / 255.0
    h, w = a.shape[:2]
    region = a[h // 2:, :int(w * 0.375)]
    solid = region[region[..., 3] > 0.5]
    surface = solid[np.max(solid[:, :3], axis=1) > INK]
    return float(np.max(surface[:, :3]))


def clip(path, ceiling):
    im = Image.open(path).convert('RGBA')
    a = np.array(im)
    peak = np.max(a[..., :3].astype(float) / 255.0, axis=2)
    over = np.argwhere((peak > ceiling) & (a[..., 3] > 128))
    for y, x in over:
        ys, xs = slice(max(y - 1, 0), y + 2), slice(max(x - 1, 0), x + 2)
        block = a[ys, xs]
        near = block[(block[..., 3] > 128) & (np.max(block[..., :3].astype(float) / 255.0, axis=-1) <= ceiling)]
        if len(near):
            a[y, x, :3] = np.median(near[:, :3], axis=0).astype(np.uint8)
    if len(over):
        Image.fromarray(a).save(path)
    return len(over)


if __name__ == '__main__':
    ceiling = brightest(BODY)
    total = 0
    for path in sorted(glob.glob(os.path.join(GAME, 'art', 'beast', 'beast_tail_*.png'))):
        n = clip(path, ceiling)
        total += n
        print('%-26s %d glint(s)' % (os.path.basename(path), n))
    print('hide brightest %.3f, clipped %d' % (ceiling, total))
