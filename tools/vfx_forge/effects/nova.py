"""The archetypal spell impact: a shock disc that expands and hollows out.

A solid flare at birth, a bright leading edge that runs outward, and a middle
that *opens* behind it - the hollow chases the front rather than never filling,
so the thing reads as a wave leaving the blow instead of a circle getting
bigger. Embers are thrown ahead of the front and the whole shell frays away.
"""

SPEC = {
    "frames": 16,
    "size": 96,
    "variants": 4,
    "why": "a spell landing: the nova, the shockwave, any area cast resolving",
}


def build(f):
    # The front runs outward and the hollow chases it. The chase is raised to
    # a power so it starts slower than the front: that lag is the whole read,
    # because two radii leaving together would never open a middle at all.
    front = f.grow(0.66, 0.18)
    hollow = f.math("MULTIPLY", f.math("POWER", f.age, 1.6), 0.62)

    # The one part that stays solid. It narrows as it runs but never to a
    # hairline, which the band's own floor holds.
    edge = f.band(front,
                  f.math("SUBTRACT", 0.13, f.math("MULTIPLY", f.age, 0.05)),
                  0.055)

    # The body between the two radii, frayed by a bar that rises so the shock
    # comes apart as it spends itself rather than thinning evenly.
    body = f.both(f.ring_gap(hollow, front),
                  f.grain(f.math("ADD", 0.18, f.math("MULTIPLY", f.age, 0.42))))

    # The detonation the shell left. It has to be *burnt away* rather than
    # gated off: a hollow that is simply empty from the second cell reads as a
    # hoop from birth, and the brief for this shape is a middle that opens.
    core = f.both(f.disc(f.shrink(0.34, 0.50)),
                  f.grain(f.math("MULTIPLY", f.age, 1.4)))

    # Thrown ahead of the front, and capped short of the cell edge so the
    # speckle dies out rather than being cut off in a straight line.
    thrown = f.math("MINIMUM", f.grow(0.95, 0.30), 0.90)
    embers = f.both(
        f.both(f.ring_gap(front, thrown),
               f.grain(f.math("ADD", 0.64, f.math("MULTIPLY", f.age, 0.14)))),
        f.after(0.12))

    # Everything comes apart together at the end. Raised hard, so the shell
    # is still solid through the middle of its life and only the last few
    # cells break up - a linear fade would read as a slow dimming. The bar
    # stops short of emptying the frame: the last cell holds a scatter of the
    # shell rather than nothing, which is what stops the sheet ending on two
    # wasted cells.
    alive = f.grain(f.math("MULTIPLY", f.math("POWER", f.age, 2.2), 0.68))

    mask = f.both(f.either(edge, body, core, embers), alive)
    return f.Look(mask=mask, tone=f.lit(core, 0.45, edge, 0.34, body, 0.10))
