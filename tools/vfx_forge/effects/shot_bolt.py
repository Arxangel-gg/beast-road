"""An ordinary bolt landing: a disc that flashes and one thin ring behind it.

The plainest impact in the catalogue on purpose. Every other shot kind is read
by how it differs from this one, so this one may carry no signature of its
own - no spokes, no scatter, no spiral, one ring and a pop.
"""

SPEC = {
    "frames": 12,
    "size": 64,
    "variants": 4,
    "why": "the default enemy shot striking a hero, a companion or the wall",
}


def build(f):
    # The flash blooms for two frames and then closes, rather than being
    # widest on the first cell: an impact that starts at its peak reads as a
    # sheet that was already playing before the shot arrived.
    core = f.disc(f.math("MINIMUM", f.grow(1.4, 0.28), f.shrink(0.62, 0.95)))

    # One ring, clean while it is young and frayed as it runs. The break-up is
    # what lets it die without the hard cut that makes a freed effect pop.
    fray = f.math("MAXIMUM",
                  f.math("MULTIPLY", f.math("SUBTRACT", f.age, 0.47), 1.25), 0.0)
    thin = f.math("SUBTRACT", 0.13, f.math("MULTIPLY", f.age, 0.07))
    ring = f.both(f.band(f.grow(0.60, 0.10), thin, 0.055), f.grain(fray))

    mask = f.either(core, ring)
    return f.Look(mask=mask, tone=f.lit(core, 0.45, ring, 0.2))
