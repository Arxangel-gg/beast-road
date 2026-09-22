"""Debris caught in a tornado: pieces orbiting the throat and climbing it.

**It is built out of geometry rather than out of the noise field, and that is
the loop rather than a preference.** The forge drifts its noise slice with the
age so a grain never repeats, which is right for a blow that plays once and
wrong for the only effect here that has to come back round to where it
started. Every term is periodic in the raw age, so the last cell is the cell
before the first and the sheet can be played for as long as the funnel stands.

What keeps geometry from reading as a woven basket is shear. Every cut here
is skewed by the radius or the angle it crosses, so the pieces are uneven
quadrilaterals rather than bricks - and a skew carries no clock, so it costs
the loop nothing.
"""

TWO_PI = 6.283185
INV_TWO_PI = 0.159155

SPEC = {
    "frames": 20,
    "size": 96,
    "variants": 4,
    "why": "a tornado's funnel, and anything else that orbits and lifts while it stands",
}


def _turning_cut(f, count, duty, shear, turn):
    """`count` angular cuts, skewed outward by `shear` and turning with time.

    Advancing by `count` phases over the life is exactly one revolution, which
    is what makes the cut periodic whatever the count.
    """
    walk = f.math("ADD", f.math("MULTIPLY", f.angle, INV_TWO_PI * count),
                  f.math("MULTIPLY", f.r, shear))
    return f.math("LESS_THAN",
                  f.math("FRACT", f.math("ADD", walk, turn)), duty)


def _arm(f, count, inner, reach, thick, cuts, duty, shear):
    """One family of spiral arms, chopped into debris."""
    turn = f.math("MULTIPLY", f.raw_age, float(count))
    phase = f.math("FRACT", f.math("ADD",
                                   f.math("MULTIPLY", f.angle, INV_TWO_PI * count),
                                   turn))
    along = f.math("ADD", inner, f.math("MULTIPLY", phase, reach))
    # The arm is fatter in some quarters than others. Static, so the debris
    # swells and shrinks as it orbits through it rather than pulsing.
    swell = f.math("ADD", 0.72,
                   f.math("MULTIPLY",
                          f.math("ABSOLUTE",
                                 f.math("SINE", f.math("ADD",
                                                       f.math("MULTIPLY", f.angle, 2.5),
                                                       f.math("MULTIPLY", f.r, 3.0)))),
                          0.46))
    wide = f.math("MULTIPLY", thick, swell)
    arm = f.math("LESS_THAN", f.math("ABSOLUTE", f.math("SUBTRACT", f.r, along)), wide)
    chop = _turning_cut(f, cuts, duty, shear,
                        f.math("MULTIPLY", f.raw_age, float(cuts)))
    # A grating fixed in the frame, wobbled by the angle it crosses, cutting
    # across the turning chopper: two even cuts beating against each other
    # give pieces of uneven length where one alone gave a dashed line.
    grate = f.math("GREATER_THAN",
                   f.math("FRACT",
                          f.math("ADD", f.math("MULTIPLY", f.r, 5.0),
                                 f.math("MULTIPLY",
                                        f.math("SINE", f.math("MULTIPLY", f.angle, 3.0)),
                                        0.5))),
                   0.26)
    return f.both(f.both(arm, chop), grate)


def _climbing(f, phase, stripe):
    """A rank of debris lifting up the funnel and sliding across it.

    The lift wraps at the top, and nothing has to hide the wrap: at either end
    of the climb the rank sits past the throat's own reach and is clipped away
    by it, so it leaves the frame before it jumps.
    """
    high = f.math("FRACT", f.math("ADD", f.raw_age, phase))
    lifted = f.rise(1.9, of=high)
    # Thicker at the middle of the climb than at its ends, so a rank swells
    # as it comes round the near side rather than switching on.
    away = f.math("ABSOLUTE", f.math("SUBTRACT", high, 0.5))
    thick = f.math("SUBTRACT", 0.15, f.math("MULTIPLY", away, 0.16))
    rank = f.math("LESS_THAN",
                  f.math("ABSOLUTE", f.math("ADD", lifted, 0.95)), thick)
    # The swing is the orbit seen from the side: pieces cross to the far side
    # and back once, which is a full turn without anything rotating.
    swing = f.math("MULTIPLY",
                   f.math("SINE", f.math("MULTIPLY", f.raw_age, TWO_PI)), 0.45)
    cut = f.math("FRACT", f.math("ADD",
                                 f.math("MULTIPLY", f.math("ADD", f.x, swing), 3.0),
                                 stripe))
    return f.both(f.both(rank, f.math("LESS_THAN", cut, 0.55)),
                  f.both(f.disc(0.90), f.math("GREATER_THAN", f.r, 0.20)))


def build(f):
    # A wider throat than the debris needs, so the eye reads as a hole rather
    # than as a gap between pieces.
    throat = f.both(f.disc(0.92), f.math("GREATER_THAN", f.r, 0.20))

    heavy = f.both(_arm(f, 2, 0.16, 0.68, 0.105, 11, 0.52, 1.7), throat)
    light = f.both(_arm(f, 3, 0.24, 0.58, 0.055, 17, 0.44, -2.4), throat)

    mask = f.either(heavy, light,
                    _climbing(f, 0.0, 0.0), _climbing(f, 0.5, 0.37))
    return f.Look(mask=mask, tone=f.lit(heavy, 0.24))
