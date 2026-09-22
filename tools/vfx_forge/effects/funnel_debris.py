"""Debris caught in a tornado: pieces orbiting the throat and climbing it.

**It is built out of geometry rather than out of the noise field, and that is
the loop rather than a preference.** The forge drifts its noise slice with the
age so a grain never repeats, which is right for a blow that plays once and
wrong for the only effect here that has to come back round to where it
started. Every term is periodic in the raw age, so the last cell is the cell
before the first and the sheet can be played for as long as the funnel stands.

What keeps geometry from reading as a woven basket is shape and shear: an arm
is far thinner than its pieces are long, so debris is a streak drawn out along
where it is going rather than a tile, and every cut is skewed by the radius it
crosses. A skew carries no clock, so it costs the loop nothing.
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


def _arm(f, count, inner, reach, thick, cuts, duty, shear, spin, lead):
    """One family of spiral arms, chopped into debris.

    `spin` is 1 or -1: which way the funnel turns. Either way the pattern
    advances a whole number of phases over the life, so a take that turns the
    other way loops exactly as the first does.
    """
    turn = f.math("MULTIPLY", f.raw_age, float(count) * spin)
    phase = f.math("FRACT", f.math("ADD",
                                   f.math("ADD", f.math("MULTIPLY", f.angle,
                                                        INV_TWO_PI * count), lead),
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
                        f.math("MULTIPLY", f.raw_age, float(cuts) * spin))
    return f.both(arm, chop)


def _climbing(f, phase, stripe, spin):
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
    thick = f.math("SUBTRACT", 0.10, f.math("MULTIPLY", away, 0.12))
    # The rank is bowed rather than ruled: a straight line of debris across
    # the funnel reads as a ruler, and what this is is the near edge of an
    # orbit, which curves away at both sides.
    bow = f.math("MULTIPLY", f.math("MULTIPLY", f.x, f.x), 0.34)
    rank = f.math("LESS_THAN",
                  f.math("ABSOLUTE",
                         f.math("SUBTRACT", f.math("ADD", lifted, 0.95), bow)),
                  thick)
    # The swing is the orbit seen from the side: pieces cross to the far side
    # and back once, which is a full turn without anything rotating.
    swing = f.math("MULTIPLY",
                   f.math("SINE", f.math("MULTIPLY", f.raw_age, TWO_PI)), 0.45 * spin)
    cut = f.math("FRACT", f.math("ADD",
                                 f.math("MULTIPLY", f.math("ADD", f.x, swing), 6.0),
                                 stripe))
    return f.both(f.both(rank, f.math("LESS_THAN", cut, 0.44)),
                  f.both(f.disc(0.90), f.math("GREATER_THAN", f.r, 0.20)))


def build(f):
    # Every other effect here takes its variety from the noise slice the take
    # is given. This one uses no noise at all, so four takes of it would have
    # been four identical files. The take's own seed decides the geometry
    # instead, in plain arithmetic rather than in nodes - and every one of
    # these is either a constant offset or a whole number of phases, so no
    # take loses the loop.
    take = int(f.seed)
    spin = 1.0 if take % 2 == 0 else -1.0
    lead = (f.seed * 0.6180339) % 1.0
    heavy_cuts = 7 + take % 3
    light_cuts = 12 + (take * 2) % 4
    shear = 1.4 + ((f.seed * 0.37) % 1.0) * 0.9

    # A wider throat than the debris needs, so the eye reads as a hole rather
    # than as a gap between pieces.
    throat = f.both(f.disc(0.92), f.math("GREATER_THAN", f.r, 0.20))

    heavy = f.both(_arm(f, 2, 0.16, 0.70, 0.050, heavy_cuts, 0.58,
                        shear, spin, lead), throat)
    light = f.both(_arm(f, 3, 0.24, 0.60, 0.032, light_cuts, 0.50,
                        -shear - 0.7, spin, lead * 0.5), throat)

    mask = f.either(heavy, light,
                    _climbing(f, 0.0, lead, spin),
                    _climbing(f, 0.5, lead + 0.37, spin))
    return f.Look(mask=mask, tone=f.lit(heavy, 0.24))
