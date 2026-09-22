"""A blow landing in stone: a blocky core that shatters, five fat wedges of
rubble flung out and stopping short, three diamond chips thrown clear, and a
low dust puff that settles over all of it.

Everything is straight-edged. A wedge cut out of a ring has two radial edges
and reads as a chunk at 64 pixels; a diamond reads as a chip. That is the
whole silhouette argument against water, which is the same idea built out of
circles, and against fire, which is pointed.

Stone also does not hang in the air: the rubble decelerates hard and stops
where it lands, and what removes it is the grain crumbling it rather than any
of it drifting on.
"""

import math

SPEC = {
    "frames": 12,
    "size": 64,
    "variants": 4,
    "why": "the hit on an earth tower's shot, a stone spell and an armoured body",
}

# Where the loose chips go. Uneven, because rock does not shatter evenly.
CHIPS = [(0.78, 0.46), (-0.34, 0.72), (-0.86, 0.18)]
CHIP_FALL = 0.62

def _phase(f):
    """This take's own arrangement, 0..1.

    The seed reaches an effect only through the noise field, so anything not
    broken up by the swirl renders identically on every take - the first cut
    of the clean hit wrote four byte-identical sheets. A golden-ratio step
    off the seed turns the takes into different arrangements as well as
    different grain, and never repeats a spacing.
    """
    return (f.seed * 0.6180339887) % 1.0



def _squashed(f, by, drop=0.0):
    """The forge's radius and angle on a frame whose y is scaled, so a disc
    drawn there lands here as a low ellipse: dust lies on the ground."""
    y = f.math("MULTIPLY", f.math("ADD", f.y, drop), by)
    r = f.math("SQRT", f.math("ADD", f.math("MULTIPLY", f.x, f.x),
                              f.math("MULTIPLY", y, y)))
    return r, f.math("ARCTAN2", y, f.x)


def _shard(f, vx, vy, half):
    """One chip, drawn as a diamond rather than a disc.

    A diamond is four straight edges, which is what makes this hit read as
    stone next to water's round droplets when both are white.
    """
    px = f.math("MULTIPLY", f.age, vx)
    py = f.math("SUBTRACT", f.math("MULTIPLY", f.age, vy),
                f.math("MULTIPLY", f.math("MULTIPLY", f.age, f.age), CHIP_FALL))
    dx = f.math("ABSOLUTE", f.math("SUBTRACT", f.x, px))
    dy = f.math("ABSOLUTE", f.math("SUBTRACT", f.y, py))
    return f.math("LESS_THAN", f.math("ADD", dx, dy), half)


def build(f):
    flat_r, flat_angle = f.r, f.angle

    # The block that was struck: notched rather than round, and shrinking
    # away as the pieces leave it.
    core = f.both(f.disc(f.shrink(0.32, 0.70)), f.spokes(7, 0.68, _phase(f) * 6.28318531 / 7.0))

    # Rubble. It flies out hard, decelerates and stops - `throw` reaching one
    # is the moment the pieces land, and nothing moves after that.
    throw = f.math("MINIMUM", f.math("MULTIPLY", f.age, 1.6), 1.0)
    outer = f.math("ADD", 0.20, f.math("MULTIPLY", throw, 0.62))
    thick = f.math("SUBTRACT", 0.28, f.math("MULTIPLY", f.age, 0.12))
    wedges = f.both(
        f.both(f.ring_gap(f.math("SUBTRACT", outer, thick), outer),
               f.spokes(5, 0.34, 0.4 + _phase(f) * 6.28318531 / 5.0)),
        # Crumbling is what takes the rubble away, so it goes to gravel
        # before it goes to nothing rather than fading as whole blocks.
        f.grain(f.math("ADD", f.math("MULTIPLY", f.age, 0.54), 0.10)))

    half = f.math("SUBTRACT", 0.20, f.math("MULTIPLY", f.age, 0.155))
    spin = (_phase(f) - 0.5) * 1.30
    flung = [(vx * math.cos(spin) - vy * math.sin(spin),
              vx * math.sin(spin) + vy * math.cos(spin)) for vx, vy in CHIPS]
    chips = f.either(*[_shard(f, vx, vy, half) for vx, vy in flung])

    # Dust lies low and settles. It is the last thing left, which is why its
    # threshold climbs more slowly than the rubble's.
    f.r, f.angle = _squashed(f, 2.10, 0.22)
    dust = f.both(f.disc(f.grow(0.62, 0.22)),
                  f.grain(f.math("ADD", f.math("MULTIPLY", f.age, 0.52), 0.20)))
    f.r, f.angle = flat_r, flat_angle

    mask = f.either(core, wedges, chips, dust)
    return f.Look(mask=mask, tone=f.lit(core, 0.42, chips, 0.30, wedges, 0.18))
