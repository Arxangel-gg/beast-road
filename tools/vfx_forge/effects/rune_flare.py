"""The vault circle's flare when a guardian steps through: a ring of even
marks that swells to full and then blows outward and frays.

The marks are cut from the angle rather than from the noise because a rune
circle is carved and a carved thing is even; the noise only arrives at the
end, when the circle is coming apart and evenness is the wrong answer.
"""

SPEC = {
    "frames": 16,
    "size": 96,
    "variants": 3,
    "why": "a rift guardian arriving, a vault circle firing, a summon landing",
}

# Where the circle stops swelling and starts leaving. Two figures read it, so
# it is named rather than typed twice.
BREAK = 0.55

# How many marks, how wide each one is, and how far out the circle is drawn.
# The noise reaches this effect only in its last third, so without a table
# the takes would be the same picture for two cells out of three.
TAKES = (
    (10, 0.15, 0.400, 0.170),
    (8, 0.18, 0.440, 0.190),
    (12, 0.13, 0.365, 0.155),
)


def build(f):
    count, duty, circle, hoop_at = TAKES[int(f.seed) % len(TAKES)]

    early = f.math("MINIMUM", f.age, BREAK)
    late = f.math("MAXIMUM", f.math("SUBTRACT", f.age, BREAK), 0.0)

    # It holds its ground while it charges and only then leaves, which is
    # what makes the departure read as a departure.
    reach = f.math("ADD", circle, f.math("MULTIPLY", late, 0.95))
    thick = f.math("SUBTRACT",
                   f.math("ADD", 0.045, f.math("MULTIPLY", early, 0.20)),
                   f.math("MULTIPLY", late, 0.22))

    # Solid while it is a circle, frayed once it is debris: the threshold
    # climbs with the departure, so the marks thin out rather than snapping.
    keep = f.either(f.before(BREAK + 0.03),
                    f.grain(f.math("ADD", 0.35, f.math("MULTIPLY", late, 0.55))))
    marks = f.both(f.both(f.spokes(count, duty), f.band(reach, thick, 0.03)), keep)

    # The inner hoop is swallowed by the middle rather than switched off: a
    # part that vanishes on one cell pops.
    hoop = f.band(f.shrink(hoop_at, 0.20), 0.028, 0.024)

    # The moment itself - the guardian's own step - blooms and is gone.
    off = f.math("ABSOLUTE", f.math("SUBTRACT", f.age, 0.58))
    swell = f.math("MAXIMUM", f.math("SUBTRACT", 1.0, f.math("MULTIPLY", off, 4.0)), 0.0)
    core = f.disc(f.math("MULTIPLY", swell, 0.34))

    mask = f.either(marks, hoop, core)
    return f.Look(mask=mask, tone=f.lit(core, 0.45, marks, 0.28))
