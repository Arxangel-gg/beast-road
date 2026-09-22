"""Debris caught in a tornado: a cone of it, orbiting the throat and climbing.

**The first cut was drawn in plan and read as a plan.** Every term was built
on `f.r`, the radial coordinate in the plane, which is a circle seen from
directly overhead - so however the arms were chopped and sheared the result
was a wheel of dashes rather than a funnel. Photographed on a contact sheet
beside the rest of the catalogue, it was the one effect nobody could name.

What a funnel is, from a camera that looks down and slightly along, is a
**stack of ellipses**: narrow and low at the throat, wider and higher up the
column, each one turning. Five of them are enough for the eye to join into a
cone, and each is chopped into debris by an angular cut that shears with its
own height so no two ranks line up.

**Every term is periodic in the raw age**, which is the loop rather than a
preference: the forge drifts its noise slice with the age so grain can never
come back to where it started, and this is the only effect here that has to.
It is played over and over for as long as the funnel stands. So it uses no
noise at all, and its variety comes from `f.phase()` instead.
"""

TWO_PI = 6.283185
INV_TWO_PI = 0.159155

SPEC = {
    "frames": 20,
    "size": 96,
    "variants": 4,
    "why": "a tornado's funnel, and anything else that orbits and lifts while it stands",
}

# The cone, in object space. The throat sits below the middle of the cell and
# the mouth near the top, because what the sheet is laid on is the ground the
# funnel is standing on.
FLOOR = -0.78
TOP = 0.86
# How flat a ring lies. The camera looks down and slightly along, so an orbit
# is an ellipse about a third as tall as it is wide; a true circle at any
# height reads as a hoop standing up.
SQUASH = 3.1
# How wide the column is at the throat and at the mouth.
THROAT = 0.16
MOUTH = 0.74
# How many ranks of debris are stacked up it.
RANKS = 5


def _ring(f, height, turn_rate, cuts, duty, lead, spin, thick):
    """One rank of debris orbiting at a given height up the cone.

    `height` runs 0 at the throat to 1 at the mouth. The ellipse's radius and
    its centre both follow it, which is what makes the stack a cone rather
    than a cylinder.
    """
    at_y = FLOOR + (TOP - FLOOR) * height
    reach = THROAT + (MOUTH - THROAT) * height
    # The ellipse: y measured from this rank's own centre and scaled, so a
    # circle of `reach` lands as a wide flat orbit.
    dy = f.math("MULTIPLY", f.math("SUBTRACT", f.y, at_y), SQUASH)
    er = f.math("SQRT", f.math("ADD", f.math("MULTIPLY", f.x, f.x),
                               f.math("MULTIPLY", dy, dy)))
    band = f.math("LESS_THAN",
                  f.math("ABSOLUTE", f.math("SUBTRACT", er, reach)), thick)

    # Chopped into pieces that travel round it. Advancing by a whole number of
    # phases over the life is exactly one revolution, so the last cell draws
    # what the first cell drew.
    ang = f.math("ARCTAN2", dy, f.x)
    walk = f.math("ADD", f.math("MULTIPLY", ang, INV_TWO_PI * cuts),
                  f.math("MULTIPLY", f.raw_age, float(cuts) * turn_rate * spin))
    chopped = f.math("LESS_THAN",
                     f.math("FRACT", f.math("ADD", walk, lead)), duty)

    # **The near half only.** A rank drawn all the way round is a hoop; the
    # far side of a real orbit is behind the column and the eye does not see
    # it. Faded rather than cut - the pieces thin out as they go round the
    # back, which is what reads as depth.
    near = f.math("GREATER_THAN", dy, f.math("MULTIPLY", er, -0.55))
    return f.both(f.both(band, chopped), f.either(near, f.math("LESS_THAN",
        f.math("FRACT", f.math("MULTIPLY", walk, 2.0)), 0.30)))


def _wall(f, spin, lead):
    """The column itself: a faint taper between the throat and the mouth, so
    the debris is hanging on something rather than floating in a stack."""
    # How wide the cone is at this height.
    height = f.math("DIVIDE", f.math("SUBTRACT", f.y, FLOOR), TOP - FLOOR)
    wide = f.math("ADD", THROAT,
                  f.math("MULTIPLY", f.math("MAXIMUM", height, 0.0),
                         MOUTH - THROAT))
    inside = f.math("LESS_THAN", f.math("ABSOLUTE", f.x), wide)
    # Only its two flanks, which is all that is lit on a hollow column.
    flank = f.math("GREATER_THAN", f.math("ABSOLUTE", f.x),
                   f.math("MULTIPLY", wide, 0.74))
    within = f.both(f.math("GREATER_THAN", f.y, FLOOR),
                    f.math("LESS_THAN", f.y, TOP))
    # Streaked, and the streaks travel up: a wall of solid light is a cone of
    # paint, and what a funnel is made of is moving.
    lifted = f.math("SUBTRACT", f.y, f.math("MULTIPLY", f.raw_age, TOP - FLOOR))
    streak = f.math("LESS_THAN",
                    f.math("FRACT", f.math("ADD",
                                           f.math("MULTIPLY", lifted, 3.0 * spin),
                                           lead)), 0.42)
    return f.both(f.both(inside, flank), f.both(within, streak))


def build(f):
    # Every other effect here takes its variety from the noise slice its take
    # is given. This one uses no noise at all, so four takes of it would have
    # been four identical files; the take's own phase decides the geometry
    # instead. Every one of these is a constant offset or a whole number of
    # phases, so no take loses the loop.
    take = int(f.seed)
    spin = 1.0 if take % 2 == 0 else -1.0
    lead = f.phase()
    cuts = 6 + take % 4

    parts = [_wall(f, spin, lead)]
    for rank in range(RANKS):
        height = float(rank) / float(RANKS - 1)
        # A rank higher up the cone is wider, so it needs more pieces to read
        # as the same debris, and it turns more slowly - which is what the eye
        # reads as the column leaning away.
        parts.append(_ring(
            f, height,
            1.0 + 0.4 * (1.0 - height),
            cuts + rank * 2,
            0.38 + 0.10 * height,
            lead + 0.21 * float(rank),
            spin,
            0.030 + 0.016 * height))
    mask = f.either(*parts)
    # Brighter low, where the debris is dense and the light is caught.
    low = f.math("LESS_THAN", f.y, FLOOR + (TOP - FLOOR) * 0.4)
    return f.Look(mask=mask, tone=f.lit(f.both(mask, low), 0.28))
