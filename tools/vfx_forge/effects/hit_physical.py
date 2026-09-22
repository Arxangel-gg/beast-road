"""A blow landing with steel: a spark star. A hot middle, seven long needles
with seven short ones between them, and six loose sparks thrown clear that
shrink to nothing.

**Nothing here touches the noise.** Every other hit in this batch is broken
up by the swirl, and this one is not: that is the whole reading of a plain
blow against an elemental one, and it is what lets a player tell an unarmed
hit from a fire hit when both are drawn in white. Clean edges, straight
needles, no grain, no dust.

It is an eight-cell sheet because it is the shortest-lived of the five. A
spark is over before a splash has finished falling, and padding blank cells
on the end of a longer sheet costs the same memory and says nothing.
"""

import math

SPEC = {
    "frames": 8,
    "size": 64,
    "variants": 4,
    "why": "the hit on an unarmed blow, a plain arrow and a sword landing",
}

PI = 3.14159265

# Where the loose sparks go, and how far. Uneven, so the star is not a
# hexagon with the corners filed off.
SPARKS = [(26, 0.95), (78, 1.05), (137, 0.80), (195, 1.00), (258, 0.88),
          (312, 1.02)]





def _spark(f, turn_deg, reach, rad):
    """One loose spark: a small disc travelling straight out.

    Straight, because a spark off steel has no weight worth drawing at this
    size - the arc water's droplets follow is the difference between the two.
    """
    turn = math.radians(turn_deg)
    px = f.math("MULTIPLY", f.age, reach * math.cos(turn))
    py = f.math("MULTIPLY", f.age, reach * math.sin(turn))
    dx = f.math("SUBTRACT", f.x, px)
    dy = f.math("SUBTRACT", f.y, py)
    gap = f.math("SQRT", f.math("ADD", f.math("MULTIPLY", dx, dx),
                                f.math("MULTIPLY", dy, dy)))
    return f.math("LESS_THAN", gap, rad)


def _needles(f, count, sharpness, span, turn=0.0):
    """A star as a reach that varies with the angle.

    Spokes are wedges, so they are widest at the tip and read as a cartwheel;
    a lobed reach with a high exponent is a needle, which is what a spark is.
    """
    lean = f.math("ADD", f.angle, turn)
    lobe = f.math("ABSOLUTE", f.math("SINE",
                                     f.math("MULTIPLY", lean, count * 0.5)))
    tip = f.math("POWER", lobe, sharpness)
    return f.math("LESS_THAN", f.r,
                  f.math("ADD", 0.10, f.math("MULTIPLY", tip, span)))


def build(f):
    # Six, seven or eight needles by take. Arrangement is the only thing a
    # clean effect can vary, so the count carries most of it here.
    points = 6 + int(f.seed) % 3
    spin = f.phase() * 6.28318531 / points

    # Out hard and back to nothing well before the sheet ends, so the star is
    # spent by its own arithmetic and nothing is cut off between two cells.
    # Past the half period the sine is negative, which is clamped away.
    # It opens a tenth of the way in rather than at zero, so the very first
    # cell is already a spiky thing: a round flash there is what every other
    # hit in this batch opens with, and this one has to be told apart.
    swell = f.math("MAXIMUM", f.math("SINE", f.math(
        "MULTIPLY", f.math("ADD", f.age, 0.10), PI / 0.86)), 0.0)
    long_span = f.math("MULTIPLY", swell, 0.92)
    short_span = f.math("MULTIPLY", swell, 0.40)

    # Two sets, the short one turned half a lobe off the long one, so the
    # star has fourteen points of two lengths rather than seven of one.
    star = f.either(_needles(f, points, 5.0, long_span, spin),
                    _needles(f, points, 4.2, short_span, spin + PI / points))

    # The hot middle. It is the brightest thing in the cell and the first to
    # go: a spark is a flash with a shape, not a light that lingers.
    heart = f.disc(f.shrink(0.28, 0.62))

    rad = f.math("SUBTRACT", 0.15, f.math("MULTIPLY", f.age, 0.145))
    # Turned as a set and then each nudged off its own place, so a take is a
    # different scatter rather than the same scatter rotated.
    flung = [(deg + f.phase() * 360.0 + (index * 137.508) % 23.0 - 11.5,
              reach * (0.88 + ((index * 0.6180339887 + f.phase()) % 1.0) * 0.24))
             for index, (deg, reach) in enumerate(SPARKS)]
    sparks = f.either(*[_spark(f, deg, reach, rad) for deg, reach in flung])

    mask = f.either(star, heart, sparks)
    return f.Look(mask=mask, tone=f.lit(heart, 0.45, sparks, 0.30, star, 0.18))
