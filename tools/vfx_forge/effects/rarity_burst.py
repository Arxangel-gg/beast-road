"""The star that opens under a good drop: a bright middle and four long clean
arms with four shorter ones between them, thrown out and drawn back in.

The one effect here that never touches the noise. A rarity tell has to read
at a glance and has to read the same every time - a frayed star is a splash,
and the player would be learning the sheet rather than the rarity.
"""

SPEC = {
    "frames": 16,
    "size": 96,
    "variants": 3,
    "why": "a rare piece landing, a set completing, a chest paying out",
}

# The arms, how fat each set is at its root, and the glints riding out on
# them. There is no noise anywhere in this effect, so the seed reaches it
# through this table or it does not reach it at all.
TAKES = (
    (4, 0.22, 0.30, 8, 0.055),
    (8, 0.15, 0.20, 12, 0.045),
    (4, 0.27, 0.35, 6, 0.065),
)


def _swell(f, of, head=0.14):
    """A half sine over the life: something at birth, most in the middle,
    nothing at the end.

    `head` is how far into the sine it starts, which is what keeps the first
    cell from being blank while still letting the last one be.
    """
    return f.math("SINE",
                  f.math("MULTIPLY",
                         f.math("ADD", head, f.math("MULTIPLY", of, 1.0 - head)),
                         3.1415927))


def _needles(f, count, duty, reach, turn=0.0):
    """Arms that narrow to a point at their own tips.

    `f.spokes` is a wedge of fixed angle, which widens outward and reads as a
    slice of pie; a star's arm is widest where it leaves the middle.
    """
    along = f.math("MINIMUM", f.math("DIVIDE", f.r, reach), 1.0)
    taper = f.math("POWER", f.math("SUBTRACT", 1.0, along), 1.4)
    turned = f.math("ADD", f.angle, turn)
    wave = f.math("ABSOLUTE",
                  f.math("SINE", f.math("MULTIPLY", turned, float(count) * 0.5)))
    bar = f.math("SUBTRACT", 1.0, f.math("MULTIPLY", taper, duty))
    return f.both(f.math("GREATER_THAN", wave, bar), f.math("LESS_THAN", f.r, reach))


def build(f):
    arm_count, arm_duty, stub_duty, glint_count, glint_thick = \
        TAKES[int(f.seed) % len(TAKES)]

    # The middle blooms a little ahead of the arms, so the light reads as the
    # thing the arms came out of.
    core = f.disc(f.math("ADD", 0.06,
                         f.math("MULTIPLY", _swell(f, f.raw_age, 0.18), 0.26)))

    thrown = _swell(f, f.age, 0.12)
    reach = f.math("ADD", 0.10, f.math("MULTIPLY", thrown, 0.80))
    arms = _needles(f, arm_count, arm_duty, reach)
    # Half a lobe round puts the short set between the long ones rather than
    # on top of them, which is what makes eight points out of two sets.
    stubs = _needles(f, arm_count, stub_duty,
                     f.math("MULTIPLY", reach, 0.52), 3.1415927 / float(arm_count))

    # Detached glints riding out on the arms. Discs rather than a hoop: a
    # hoop that closes back in has to pass through a hairline to get there.
    glints = f.both(f.spokes(glint_count, 0.06),
                    f.band(f.math("MULTIPLY", reach, 0.78), glint_thick, 0.03))

    mask = f.either(core, arms, stubs, glints)
    return f.Look(mask=mask, tone=f.lit(core, 0.42, arms, 0.20, glints, 0.25))
