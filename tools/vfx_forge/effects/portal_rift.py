"""The aperture a rift tears in the air: a torn ring of churning light with a
dark middle, drawn for a gate that stands there rather than for a blow.

It is a looping sheet, so nothing that decides where the light is may run on
the effect's own clock in one direction. The tears are cut out of the lip by
wedges turning by whole lobes over the life rather than by the noise field,
because the noise drifts and swirls with age and can never come back to
where it started - the first render of this closed 54% short of its own
first cell for exactly that reason.
"""

SPEC = {
    "frames": 24,
    "size": 96,
    "variants": 3,
    "why": "a rift gate, a dungeon mouth, a portal standing open",
}

# The two bite counts and how wide the aperture is. Counts with no common
# factor, so the pair of them never lines up twice in one turn.
TAKES = (
    (7, 11, 0.560),
    (5, 9, 0.605),
    (8, 13, 0.520),
)


def _cycle(f, turns, phase=0.0):
    """A 0..1 wave over the life that closes exactly on itself."""
    ang = f.math("ADD", f.math("MULTIPLY", f.raw_age, 6.2831853 * turns), phase)
    return f.math("MULTIPLY", f.math("ADD", f.math("SINE", ang), 1.0), 0.5)


def _spin(f, count, duty, sign=1.0):
    """Spokes that turn by exactly one lobe over the life.

    A lobe is where the pattern repeats, so the last cell draws what the
    first cell drew while everything between it has travelled.
    """
    turn = f.math("MULTIPLY", f.raw_age, sign * 6.2831853 / float(count))
    return f.spokes(count, duty, turn)


def build(f):
    few, many, mouth = TAKES[int(f.seed) % len(TAKES)]

    breath = _cycle(f, 1.0)
    churn = _cycle(f, 2.0, 1.1)

    # The lip breathes rather than pulses: a gate that throbs reads as a
    # heartbeat, and this one is supposed to be a hole.
    lip = f.math("ADD", mouth, f.math("MULTIPLY", breath, 0.045))
    thick = f.math("ADD", 0.075, f.math("MULTIPLY", churn, 0.035))

    # Where both sets of bites open at once the lip is torn through, which
    # wanders round the ring without any one gap landing twice.
    bites = f.either(_spin(f, few, 0.32, 1.0), _spin(f, many, 0.30, -1.0))
    torn = f.both(f.band(lip, thick, 0.045), bites)

    # The middle is a hole and has to read as one, so what is inside it is a
    # handful of specks rather than any fill at all.
    wisps = f.both(f.grain(0.70), f.disc(f.math("SUBTRACT", lip, thick)))

    # And the outside frays into the air the gate was torn in.
    sparks = f.both(f.grain(0.76),
                    f.ring_gap(f.math("ADD", lip, thick), 0.90))

    mask = f.either(torn, wisps, sparks)
    return f.Look(mask=mask, tone=f.lit(torn, 0.42, sparks, 0.18))
