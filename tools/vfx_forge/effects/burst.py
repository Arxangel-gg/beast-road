"""A shock ring leaving a blow: the pilot effect, and the shape every other
impact here is a variation on.

A band that runs outward and thins, a second fainter one in its wake so the
shock reads as a wave rather than as one line, a core that blooms and dies,
and embers thrown along the swirl.
"""

SPEC = {
    "frames": 16,
    "size": 96,
    "variants": 3,
    "why": "the generic impact: a projectile landing, a slam, a shot striking",
}


def build(f):
    # The band thins as it runs and never below a visible width: the first
    # render fell to a hairline by the fifth frame and read as a wire.
    thin = f.math("SUBTRACT", 0.28, f.math("MULTIPLY", f.age, 0.20))
    ring = f.both(f.band(f.grow(1.25), thin, 0.07),
                  # Roughened, and the bar rises with age so it frays as it goes.
                  f.grain(f.math("ADD", f.math("MULTIPLY", f.age, 0.45), 0.25)))

    core = f.disc(f.shrink(0.55, 1.0))

    embers = f.both(
        f.both(f.grain(f.math("ADD", 0.62, f.math("MULTIPLY", f.age, 0.2))),
               f.disc(f.grow(1.5, 0.15))),
        f.before(0.92))

    # A second, fainter ring at two thirds of the reach, so the shock has a
    # wake. It starts late, which is what makes it read as trailing.
    wake = f.both(f.both(f.band(f.grow(0.8, 0.04), 0.05), f.grain(0.55)),
                  f.after(0.2))

    mask = f.either(ring, wake, core, embers)
    return f.Look(mask=mask, tone=f.lit(core, 0.45, ring, 0.25))
