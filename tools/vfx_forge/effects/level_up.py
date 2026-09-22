"""Light rising off the Warden when a level lands: a handful of columns that
lift out of the ground, thin as they climb, and a ring at the feet that
swells and runs outward.

The only vertical effect in the batch, so it is the only one built out of
`rise` and a flattened ellipse rather than out of the radius. The ellipse is
what makes the foot ring read as lying on the ground: the camera looks down
and slightly along, so a true circle at the feet reads as a hoop standing up.
"""

SPEC = {
    "frames": 20,
    "size": 96,
    "variants": 3,
    "why": "a hero level, a rank taken, an attribute placed",
}

LIFT = 1.35  # how far the columns travel; more and they leave by the top edge

# How tightly the columns are ruled, and how flat the foot ring lies. The
# noise reaches this one everywhere, so the takes already differ - what the
# table adds is a different number of shafts rather than the same shafts
# broken up differently.
TAKES = (
    (13.0, 0.89, 0.62, 0.26),
    (10.0, 0.86, 0.70, 0.23),
    (16.0, 0.91, 0.55, 0.30),
)


def build(f):
    ruled, gap, across, deep = TAKES[int(f.seed) % len(TAKES)]

    climbed = f.rise(LIFT)

    # Higher in the cell is harder to be lit at all, which is what makes the
    # columns thin out as they go rather than switching off at a line.
    thinner = f.math("ADD", 0.18,
                     f.math("MULTIPLY", f.math("ADD", f.y, 1.0), 0.30))
    fade = f.grain(thinner)

    # Stripes off the x coordinate, so the columns are even and parallel;
    # noise would give a crowd of flames instead of a shaft of light.
    stripe = f.math("GREATER_THAN",
                    f.math("ABSOLUTE", f.math("SINE", f.math("MULTIPLY", f.x, ruled))),
                    gap)
    within = f.math("LESS_THAN", f.math("ABSOLUTE", f.x), 0.78)

    # They stretch out of the ground first and are drawn out of the top of
    # themselves after, so the effect arrives rather than simply sliding.
    grown = f.math("MINIMUM", f.age, 0.52)
    spent = f.math("MAXIMUM", f.math("SUBTRACT", f.age, 0.60), 0.0)
    crown = f.math("SUBTRACT",
                   f.math("ADD", -0.70, f.math("MULTIPLY", grown, 1.15)),
                   f.math("MULTIPLY", spent, 0.85))
    shaft = f.both(f.math("GREATER_THAN", climbed, -1.05),
                   f.math("LESS_THAN", climbed, crown))
    columns = f.both(f.both(stripe, within), f.both(shaft, fade))

    # The foot ring, in a space where one unit up is worth less than one unit
    # across. Everything below is measured in that space, not in pixels.
    ex = f.math("MULTIPLY", f.x, 1.0 / across)
    ey = f.math("MULTIPLY", f.math("ADD", f.y, 0.72), 1.0 / deep)
    flat = f.math("SQRT", f.math("ADD", f.math("MULTIPLY", ex, ex),
                                 f.math("MULTIPLY", ey, ey)))
    at = f.math("ADD", 0.45, f.math("MULTIPLY", f.age, 0.80))
    wide = f.math("SUBTRACT",
                  f.math("ADD", 0.14, f.math("MULTIPLY",
                                             f.math("MINIMUM", f.age, 0.30), 0.60)),
                  f.math("MULTIPLY", f.math("MAXIMUM",
                                            f.math("SUBTRACT", f.age, 0.45), 0.0), 0.50))
    hoop = f.math("LESS_THAN", f.math("ABSOLUTE", f.math("SUBTRACT", flat, at)),
                  f.math("MAXIMUM", wide, 0.07))
    ring = f.both(hoop, f.grain(f.math("ADD", 0.25, f.math("MULTIPLY", f.age, 0.36))))

    # Motes carried up between the columns, so the air moves and not only the
    # light does.
    sparser = f.math("ADD", 0.60,
                     f.math("MULTIPLY", f.math("ADD", f.y, 1.0), 0.17))
    motes = f.both(f.both(f.grain(sparser),
                          f.math("LESS_THAN", f.math("ABSOLUTE", f.x), 0.86)),
                   f.both(f.math("GREATER_THAN", climbed, -1.00),
                          f.math("LESS_THAN", climbed, 0.10)))

    mask = f.either(columns, ring, motes)
    return f.Look(mask=mask, tone=f.lit(ring, 0.40, columns, 0.30))
