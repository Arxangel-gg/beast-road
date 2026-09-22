"""A blow landing in fire: a knot of licking tongues that lean off their own
roots, fray at the tip and go out from the bottom up.

Tongues are a *radius that varies with the angle*, never spokes. A spoke is a
wedge, so it is widest where a flame is thinnest and the whole thing renders
as a sunburst; a lobed reach with a sharp exponent is pointed at the tip and
joined at the root, which is the shape of fire.

The busiest and thinnest of the five hits. Many narrow licks against water's
few fat droplets and earth's few fat chunks is what separates the elements in
silhouette alone, which they have to be: the game tints one white sheet, so
hue can never tell a player which element hit them.
"""

SPEC = {
    "frames": 12,
    "size": 64,
    "variants": 4,
    "why": "the hit on a fire tower's shot, a fire spell and a burning body",
}

PI = 3.14159265

def _phase(f):
    """This take's own arrangement, 0..1.

    The seed reaches an effect only through the noise field, so anything not
    broken up by the swirl renders identically on every take - the first cut
    of the clean hit wrote four byte-identical sheets. A golden-ratio step
    off the seed turns the takes into different arrangements as well as
    different grain, and never repeats a spacing.
    """
    return (f.seed * 0.6180339887) % 1.0



def build(f):
    spin = _phase(f) * 6.28318531 / 9.0
    curl = 1.30 + (_phase(f) - 0.5) * 0.50
    # Fire leaves the ground, so the whole crown climbs off the impact point,
    # and x is squeezed so the crown is taller than it is wide.
    lifted = f.rise(0.34)
    narrow = f.math("MULTIPLY", f.x, 1.35)
    reach_r = f.math("SQRT", f.math("ADD", f.math("MULTIPLY", narrow, narrow),
                                    f.math("MULTIPLY", lifted, lifted)))
    # The lean grows with the radius rather than being a flat rotation: every
    # tongue turning together is the crown spinning, not a lick curling.
    lean = f.math("ADD", f.math("ADD", f.math("ARCTAN2", lifted, narrow), spin),
                  f.math("MULTIPLY", reach_r, f.math("MULTIPLY", f.age, curl)))
    lobe = f.math("ABSOLUTE", f.math("SINE", f.math("MULTIPLY", lean, 4.5)))
    tip = f.math("POWER", lobe, 2.8)

    # Up and out, then down: the crown is gone on the last cell by its own
    # arithmetic rather than by a cut, so nothing pops when the node is freed.
    puff = f.math("SINE", f.math("MULTIPLY", f.age, PI * 0.92))
    crown = f.math("ADD", 0.13, f.math("MULTIPLY", f.math("MULTIPLY", tip, puff), 0.95))

    # The edge is eaten by the swirl. The noise sits near 0.5 with little
    # spread, so it is biased and gained before it is spent - subtracting the
    # raw field shaves an even sliver and reads as a smooth outline.
    bite = f.math("MULTIPLY", f.math("SUBTRACT", f.noise_fac, 0.28), 0.70)
    tongues = f.math("LESS_THAN", reach_r, f.math("SUBTRACT", crown, bite))

    # The hot base sits at the impact rather than on the climbing frame, so it
    # stays where the blow landed and is the first thing to go.
    base = f.both(f.disc(f.shrink(0.32, 0.60)), f.before(0.50))

    # The flash dissolves rather than ending on a frame: a bloom cut off
    # between two cells is a pop, and a climbing threshold is it breaking up.
    bloom = f.both(f.disc(f.grow(0.95, 0.18)),
                   f.grain(f.math("ADD", f.math("MULTIPLY", f.age, 0.55), 0.30)))

    # Sparks thrown ahead of the licks, in a shell rather than over the whole
    # upper half, which reads as haze.
    embers = f.both(
        f.both(f.grain(f.math("ADD", f.math("MULTIPLY", f.age, 0.14), 0.70)),
               f.ring_gap(f.grow(0.70, 0.22), f.grow(1.25, 0.34))),
        f.math("GREATER_THAN", f.y, -0.25))

    # It goes out from the bottom up, which is also what empties the last cell.
    floor = f.math("SUBTRACT", f.math("MULTIPLY", f.age, 1.45), 0.95)
    alight = f.math("GREATER_THAN", f.y, floor)

    mask = f.both(f.either(tongues, base, bloom, embers), alight)
    return f.Look(mask=mask, tone=f.lit(base, 0.45, bloom, 0.20, tongues, 0.14))
