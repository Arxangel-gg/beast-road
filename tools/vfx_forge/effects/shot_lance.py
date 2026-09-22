"""A pierce: a long flash driven out along +x with a burst where it entered
and sparks dragged along behind it.

Drawn pointing right and turned by the game, which is why every shape here is
one cone rather than a ring. The near end runs forward faster than the tip
over the second half, so the flash leaves along its own line instead of
fading where it stood - a lance that dies in place reads as a beam switching
off, and a beam is what this must not be mistaken for.
"""

SPEC = {
    "frames": 12,
    "size": 96,
    "variants": 3,
    "why": "a lancing shot passing through a hero or into the wall",
}


def build(f):
    # A cone is two cones, opposite each other, so the half behind the impact
    # has to be cut away or the lance points both ways.
    ahead = f.math("GREATER_THAN", f.x, 0.0)

    # What has been left behind. Zero for the first half - the lance is driven
    # in before it is drawn out.
    near = f.math("MAXIMUM",
                  f.math("MULTIPLY", f.math("SUBTRACT", f.age, 0.42), 1.55), 0.0)

    # Two cones rather than one: a narrow one reaching further than the wide
    # one is a point on the end, and a single cone is a wedge of light that
    # only widens - which reads as a cast, not as something driven through.
    body = f.math("MINIMUM", f.grow(2.4, 0.20), 0.80)
    point = f.math("MINIMUM", f.grow(2.9, 0.26), 0.95)
    shaft = f.both(f.both(f.wedge(0.26), ahead), f.ring_gap(near, body))
    tip = f.both(f.both(f.wedge(0.085), ahead), f.ring_gap(near, point))

    # The entry wound: it blooms for a cell and is gone before the flash has
    # finished leaving, so the eye is pulled from the near end to the far one.
    burst = f.disc(f.math("MINIMUM", f.grow(1.6, 0.17), f.shrink(0.44, 1.05)))

    # Sparks in a wider cone around the shaft, thinning as the flash goes.
    # They are what stop the lance reading as a solid painted triangle.
    thinning = f.math("MAXIMUM",
                      f.math("MULTIPLY", f.math("SUBTRACT", f.age, 0.30), 0.30), 0.0)
    sparks = f.both(
        f.both(f.both(f.wedge(0.46), ahead), f.grain(f.math("ADD", 0.42, thinning))),
        f.ring_gap(f.math("MULTIPLY", near, 0.55), point))

    mask = f.either(shaft, tip, burst, sparks)
    return f.Look(mask=mask, tone=f.lit(burst, 0.42, tip, 0.3, shaft, 0.14))
