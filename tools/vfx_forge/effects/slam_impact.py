"""A boss's fist landing: the heaviest blow in the game.

Two shocks rather than one - a fast ring racing out past the rim and a slow
heavy one still climbing behind it - because one ring is an impact and two is
a mass arriving. The eye between them is kept clear so the cracks can be seen
in it: the ground splits under the fist and stays split, so what takes the
fissures away is grit filling them in rather than any motion outward.
"""

SPEC = {
    "frames": 18,
    "size": 128,
    "variants": 4,
    "why": "a boss slam landing, and anything else heavy enough to split the ground",
}


def build(f):
    # The take's own seed, spent on geometry as well as on the noise slice it
    # already buys. Cracks that split the same seven ways every time are the
    # tell that four takes are one drawing.
    take = int(f.seed)
    fissures = 6 + take % 3
    turn = (f.seed * 2.399) % 6.283185
    pace = 0.90 + ((f.seed * 0.618) % 1.0) * 0.14

    # Both radii are named rather than inlined, because the grit is thrown
    # into the gap *between* the two shocks - grit everywhere fills the eye
    # and the whole blow reads as one expanding blob.
    fast_r = f.grow(pace, 0.22)
    slow_r = f.grow(0.34, 0.06)

    # The fast shock, out past the rim inside the life, thinning as it runs
    # and fraying harder the further it has gone.
    fast_thick = f.math("SUBTRACT", 0.16, f.math("MULTIPLY", f.age, 0.10))
    fast = f.both(f.band(fast_r, fast_thick, 0.05),
                  f.grain(f.math("ADD", 0.30, f.math("MULTIPLY", f.age, 0.37))))

    # The slow one: half the reach, still coming when the fast ring has gone.
    # This is the half that reads as weight.
    slow_thick = f.math("SUBTRACT", 0.15, f.math("MULTIPLY", f.age, 0.07))
    slow = f.both(f.band(slow_r, slow_thick, 0.07),
                  f.grain(f.math("ADD", 0.24, f.math("MULTIPLY", f.age, 0.39))))

    # Cracks. Thin and short: wide ones read as the teeth of a cog, and they
    # stay well inside both shocks so the rings have somewhere to run past.
    cracks = f.both(f.both(f.spokes(fissures, 0.15, turn=turn), f.ring_gap(0.10, 0.44)),
                    f.grain(f.math("ADD", 0.16, f.math("MULTIPLY", f.age, 0.52))))

    # Grit, in the wake of the leading shock only. A scatter across the
    # whole gap closes it up and the two shocks read as one blob.
    grit = f.both(f.both(f.grain(f.math("ADD", 0.74, f.math("MULTIPLY", f.age, 0.08))),
                         f.ring_gap(f.math("SUBTRACT", fast_r, 0.20),
                                    f.math("ADD", fast_r, 0.14))),
                  f.before(0.93))

    # The flash under the fist: small, and gone before the shocks are out.
    core = f.disc(f.shrink(0.34, 1.2))

    mask = f.either(fast, slow, cracks, grit, core)
    return f.Look(mask=mask, tone=f.lit(core, 0.45, fast, 0.20, cracks, 0.10))
