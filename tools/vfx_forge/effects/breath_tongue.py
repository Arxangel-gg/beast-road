"""A tongue of breath rolling out along +x: narrow at the mouth, widening,
torn at its edges, a bright core down its middle, and the root burning away
behind the front so the whole of it reads as travelling rather than growing.

Directional, so AIMED: the game lays it along the line the breath was
committed to and repeats it down that line, a few cells apart, so a long
breath is several tongues rather than one stretched picture. White on
transparent; the element is the tint - fire, frost, storm and stone are one
shape in four colours, which is what lets a non-fire dragon breathe plain
fire from the same sheet.
"""

SPEC = {
    "frames": 16,
    "size": 128,
    "variants": 4,
    "why": "a dragon's breath rolling down its committed line, tinted by element",
}


def build(f):
    # Distance from the mouth: 0 at the left edge of the cell, 2 at the right.
    xs = f.math("MAXIMUM", f.math("ADD", f.x, 1.0), 0.0)
    ay = f.math("ABSOLUTE", f.y)
    # The front runs right with age and never quite leaves the cell.
    front = f.grow(2.2, 0.30)
    # A flame's profile: opening with distance (a power under one, so it
    # swells fast from the mouth and then more slowly), and rounded off at
    # the front rather than cut, which is what the first cut was - a torn
    # block with a flat face.
    opening = f.math("MULTIPLY", f.math("POWER", f.math("MAXIMUM", xs, 0.001), 0.66), 0.52)
    to_front = f.math("MAXIMUM", f.math("SUBTRACT", front, xs), 0.0)
    rounding = f.math("POWER", f.math("MINIMUM", f.math("DIVIDE", to_front, 0.55), 1.0), 0.5)
    profile = f.math("MULTIPLY", opening, rounding)
    # Torn by the noise, so the edge licks.
    torn = f.math("MULTIPLY", profile, f.math("ADD", 0.72, f.math("MULTIPLY", f.noise_fac, 0.62)))
    body = f.math("LESS_THAN", ay, torn)
    # Late in its life the mouth end burns away first, so it leaves.
    gone = f.math("MULTIPLY", f.math("MAXIMUM", f.math("SUBTRACT", f.age, 0.62), 0.0), 2.6)
    root = f.math("GREATER_THAN", xs, gone)
    alive = f.grain(f.math("ADD", 0.26, f.math("MULTIPLY", f.age, 0.30)))
    shape = f.both(f.both(body, root), alive)
    core = f.both(f.math("LESS_THAN", ay, f.math("MULTIPLY", profile, 0.40)), shape)
    return f.Look(mask=shape, tone=f.lit(core, 0.45, shape, 0.12))
