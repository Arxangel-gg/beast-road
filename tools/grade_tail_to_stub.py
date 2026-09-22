"""Paint Yuri's tail as bright and as coloured as the stub it continues.

    python tools/grade_tail_to_stub.py

**Ninth report, and the first to be answered in the file.** Every earlier pass
argued about what happens *between* the painting and the screen - a modulate,
a self_modulate, a shader, a per-channel harmony, a chroma, a value pull, a
seat - and the owner kept seeing a limb that was not the animal it hung from.
Measured on the paintings themselves, surface pixels only (ink held out):

    body stub, columns 0-42 (the hind leg starts at 44)   rgb(71.4, 76.6, 59.4)
    tail root, rightmost 30% of every tail frame           rgb(60.2, 64.1, 51.7)

The tail was painted a sixth darker than the stub it is meant to continue, and
then the runtime darkened it a further six percent on purpose. That is the whole
of what was on screen.

So this applies one per-channel gain - stub over root - to the surface of every
tail frame, and the runtime applies nothing at all. The tail is a child of the
body, so the body's grade multiplies into it at draw; with the paintings
agreeing at the join, "graded the same" is then true by construction and cannot
drift with a constant. Ink is left alone (a line is a line), alpha is left
alone, and no pixel is pushed past the brightest thing on the hide.

Self-limiting: once the root matches the stub the gain is one, so running it
twice changes nothing. `beast_tail_check` holds the match.
"""

from __future__ import annotations

import glob
import os
import statistics as st

from PIL import Image

ART = os.path.join(os.path.dirname(__file__), "..", "game", "art", "beast")
BODY = "beast_idle_00.png"
INK = 12            # at or below this in every channel a pixel is ink
STUB_COLUMNS = 42   # the hind leg starts at column 44
ROOT_SHARE = 0.30   # the rightmost share of the tail painting is its root


def surface(image: Image.Image, box) -> list:
    """Solid, non-ink pixels inside a box."""
    crop = image.crop(box).convert("RGBA")
    return [p for p in crop.getdata()
            if p[3] > 127 and not (p[0] <= INK and p[1] <= INK and p[2] <= INK)]


def mean_rgb(pixels: list) -> list:
    return [st.mean(p[i] for p in pixels) for i in range(3)]


def main() -> None:
    body = Image.open(os.path.join(ART, BODY))
    width, height = body.size
    stub = mean_rgb(surface(body, (0, 0, STUB_COLUMNS, height)))
    # The brightest surface pixel on the hide at the join, which is the same
    # region the gate reads its ceiling from: the lower left of the body.
    hide = surface(body, (0, height // 2, int(width * 0.375), height))
    ceiling = max(max(p[:3]) for p in hide)

    tails = sorted(glob.glob(os.path.join(ART, "beast_tail*.png")))
    roots = []
    for path in tails:
        tail = Image.open(path)
        tw, th = tail.size
        roots.append(mean_rgb(surface(tail, (int(tw * (1.0 - ROOT_SHARE)), 0, tw, th))))
    root = [st.mean(r[i] for r in roots) for i in range(3)]
    gain = [stub[i] / max(root[i], 1.0) for i in range(3)]
    print("stub   rgb(%.1f, %.1f, %.1f)" % tuple(stub))
    print("root   rgb(%.1f, %.1f, %.1f) over %d frames" % (*root, len(tails)))
    print("gain   (%.3f, %.3f, %.3f), hide ceiling %d" % (*gain, ceiling))

    clamped = 0
    for path in tails:
        tail = Image.open(path).convert("RGBA")
        px = tail.load()
        for y in range(tail.size[1]):
            for x in range(tail.size[0]):
                r, g, b, a = px[x, y]
                if a <= 127 or (r <= INK and g <= INK and b <= INK):
                    continue
                out = []
                for value, k in ((r, 0), (g, 1), (b, 2)):
                    lifted = int(round(value * gain[k]))
                    if lifted > ceiling:
                        lifted = ceiling
                        clamped += 1
                    out.append(lifted)
                px[x, y] = (out[0], out[1], out[2], a)
        tail.save(path)
        tw, th = tail.size
        after = mean_rgb(surface(tail, (int(tw * (1.0 - ROOT_SHARE)), 0, tw, th)))
        print("  %-24s root now rgb(%.1f, %.1f, %.1f)" % (os.path.basename(path), *after))
    print("done; %d channel values held at the hide's ceiling" % clamped)


if __name__ == "__main__":
    main()
