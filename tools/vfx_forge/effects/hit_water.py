"""A blow landing in water: a crown splash. A low wide rim running out along
the ground, and seven round droplets thrown up off it that arc over, shrink
and come down.

Every droplet is its own disc rather than an arc of a ring. An arc reads as a
piece of machinery at 64 pixels - the first cut of this file rendered as a
cog - and the one thing a player has to read off a water hit is that the
pieces are ROUND. That is the whole silhouette argument against fire, which
is many pointed licks where this is few round lumps, and against earth, whose
lumps are angular.
"""

import math

SPEC = {
    "frames": 12,
    "size": 64,
    "variants": 4,
    "why": "the hit on a water tower's shot, a water spell and a soaked body",
}

# Where each droplet is thrown, and how fast. Uneven on purpose: a splash
# thrown evenly is a flower.
THROWN = [
    (1.02, 0.26), (0.44, 0.86), (0.10, 0.62), (-0.38, 0.95),
    (-0.92, 0.30), (-0.58, -0.02), (0.72, -0.06),
]
FALL = 0.80
FROM_Y = -0.08






def _droplet(f, vx, vy, rad):
    """One round drop thrown along (vx, vy) and pulled back down.

    The age is the eased one, which slows the drop as it goes: that is what
    ballistics look like and it also front-loads the motion, so the splash
    has left the impact by the third cell.
    """
    px = f.math("MULTIPLY", f.age, vx)
    climb = f.math("SUBTRACT", f.math("MULTIPLY", f.age, vy),
                   f.math("MULTIPLY", f.math("MULTIPLY", f.age, f.age), FALL))
    dx = f.math("SUBTRACT", f.x, px)
    dy = f.math("SUBTRACT", f.y, f.math("ADD", climb, FROM_Y))
    gap = f.math("SQRT", f.math("ADD", f.math("MULTIPLY", dx, dx),
                                f.math("MULTIPLY", dy, dy)))
    return f.math("LESS_THAN", gap, rad)


def build(f):
    flat_r, flat_angle = f.r, f.angle

    # The rim: water running out along the ground, drawn low and sitting
    # under the middle so the droplets have somewhere to go.
    f.r, f.angle = f.squashed(1.75, 0.16)
    thin = f.math("SUBTRACT", 0.13, f.math("MULTIPLY", f.age, 0.07))
    rim = f.both(f.band(f.grow(0.66, 0.16), thin, 0.05),
                 # It breaks up as it spreads rather than ending on a hoop.
                 f.grain(f.math("MULTIPLY", f.age, 0.62)))

    # The column straight up out of the hole. Narrow and brief: the crown is
    # what the eye keeps, and a tall shape that lingers reads as a geyser.
    f.r, f.angle = f.squashed(0.32, -0.04)
    # It shoots up and drops back rather than standing at full height on the
    # first cell: water is thrown by the blow, it is not already in the air
    # when the blow lands. Past the half period the sine goes negative, which
    # is clamped to nothing - so the column ends on its own arithmetic and
    # needs no cut, and the sheet opens on a rise instead of a dip.
    # The phase is held at half a turn rather than allowed to run on: left
    # free it wraps past a full turn by the last cell and the sine comes back
    # positive, which grew a second column on the frame that must be empty.
    spout = f.math("SINE", f.math("MINIMUM", f.math(
        "MULTIPLY", f.age, math.pi / 0.44), math.pi))
    column = f.disc(f.math("MULTIPLY", spout, 0.21))

    f.r, f.angle = flat_r, flat_angle

    # Drops shrink to nothing rather than being cut, so the last cell empties
    # on its own arithmetic and nothing pops when the node is freed.
    rad = f.math("SUBTRACT", 0.24, f.math("MULTIPLY", f.age, 0.185))
    # Turned a little either way rather than all the way round: the crown
    # has to keep going up, so a take is a different scatter and never a
    # different direction.
    spin = (f.phase() - 0.5) * 0.85
    turned = [(vx * math.cos(spin) - vy * math.sin(spin),
               vx * math.sin(spin) + vy * math.cos(spin)) for vx, vy in THROWN]
    drops = f.either(*[_droplet(f, vx, vy, rad) for vx, vy in turned])

    # The strike: a round flash that dissolves in the swirl.
    burst = f.both(f.disc(f.shrink(0.34, 0.62)),
                   f.grain(f.math("MULTIPLY", f.age, 0.95)))

    # And a fine spray, sparse enough to read as thrown water rather than fog.
    spray = f.both(f.grain(f.math("ADD", f.math("MULTIPLY", f.age, 0.10), 0.74)),
                   f.ring_gap(f.grow(0.70, 0.22), f.grow(1.25, 0.40)))

    mask = f.either(rim, column, drops, burst, spray)
    return f.Look(mask=mask, tone=f.lit(burst, 0.42, column, 0.26, drops, 0.18))
