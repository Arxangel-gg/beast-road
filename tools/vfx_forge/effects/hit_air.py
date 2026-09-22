"""A blow landing in air: a thin pressure ring that runs out fast, with
spiral streaks dragged along behind it, and a snap of a core that is gone
almost at once.

The fastest of the five, and it is a ten-cell sheet rather than a twelve
because that is the honest way to be fast: padding four blank cells onto the
end of a long one costs the same memory and says nothing.

The ring leaves the cell rather than fading in place - the whole reading of
an air hit is that the pressure went somewhere - and nothing here is more
than a couple of pixels thick, against fire's mass and earth's blocks.
"""

SPEC = {
    "frames": 10,
    "size": 64,
    "variants": 4,
    "why": "the hit on an air tower's shot, a gust spell and a body knocked back",
}


def build(f):
    # The shock. It thins as it runs, and never to a hairline: a band that
    # reaches zero width renders as a wire rather than as a wave.
    front = f.grow(1.30, 0.14)
    thin = f.math("SUBTRACT", 0.085, f.math("MULTIPLY", f.age, 0.045))
    ring = f.band(front, thin, 0.045)

    # Streaks trailing inward from the front, turned by their own radius so
    # they curve back. A flat turn rotates the whole set together, which
    # reads as a wheel; a turn that grows with the radius is a spiral.
    trail = f.ring_gap(f.math("SUBTRACT", front, 0.17),
                       f.math("ADD", front, 0.02))
    streaks = f.both(trail, f.spokes(7, 0.13, f.math("MULTIPLY", f.r, 2.30)))

    # A second, fainter front in the wake, so the shock reads as a wave
    # rather than as one line. It starts late, which is what makes it trail.
    wake = f.both(f.both(f.band(f.grow(0.80, 0.05), 0.045), f.grain(0.52)),
                  f.after(0.18))

    # The snap at the middle: gone by the third cell, which is what makes the
    # rest read as fast.
    snap = f.disc(f.shrink(0.30, 1.05))

    # One threshold takes all of it away, so the parts cannot disagree about
    # when the hit is over.
    spent = f.grain(f.math("ADD", f.math("MULTIPLY", f.age, 0.44), 0.20))

    mask = f.either(snap, f.both(f.either(ring, streaks, wake), spent))
    return f.Look(mask=mask, tone=f.lit(snap, 0.45, ring, 0.22))
