"""A field's ring: cold drifting outward along the ground.

Flattened for the camera - a circle on the ground is an ellipse under a camera
that looks down and slightly along - and slow, because a field is a place
rather than a blow: the ring leaves the anchor and the frost it leaves behind
lingers where it passed.
"""

SPEC = {
    "frames": 16,
    "size": 96,
    "variants": 3,
    "why": "Frostbound Ring pulsing: a field on the ground, seen from the road's camera",
}


def build(f):
    # The radius on a frame whose y is doubled, so a ring lands half as tall
    # as it is wide. (Measured: `squashed(0.5)` stands the ellipse *up* - the
    # radius reaches its threshold later along y - which is the first cut's
    # sheet, a ring taller than wide on a ground the camera looks down on.)
    flat, _angle = f.squashed(2.0)
    at = f.math("MINIMUM", f.grow(0.72, 0.12), 0.90)
    gap = f.math("ABSOLUTE", f.math("SUBTRACT", flat, at))
    ring = f.math("LESS_THAN", gap, f.math("SUBTRACT", 0.10, f.math("MULTIPLY", f.age, 0.04)))

    # Frost left behind the front: inside the ring, speckled, thinning with age.
    frost = f.both(f.math("LESS_THAN", flat, at),
                   f.grain(f.math("ADD", 0.56, f.math("MULTIPLY", f.age, 0.08))))

    alive = f.grain(f.math("MULTIPLY", f.math("POWER", f.age, 2.2), 0.64))
    mask = f.both(f.either(ring, frost), alive)
    return f.Look(mask=mask, tone=f.lit(ring, 0.40, frost, 0.10))
