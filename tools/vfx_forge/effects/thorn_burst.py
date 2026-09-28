"""A retort: thorns bursting out of the body that was struck.

Spikes rather than a ring, because the answer to a blow is not a wave - it is
a hedge of points thrown outward from the one who was hit. The spokes are
even by construction; what the seed moves is where they point and how they
fray at the tips.
"""

SPEC = {
    "frames": 14,
    "size": 96,
    "variants": 3,
    "why": "a retort: Thornskin and Kiln Skin answering a blow with a burst",
}


def build(f):
    # The tips run outward fast and stop short of the cell edge; the root
    # follows more slowly, so the spikes lengthen and then hollow at the base.
    tip = f.math("MINIMUM", f.grow(1.1, 0.10), 0.92)
    root = f.grow(0.45, 0.02)
    # **Lobes, not spokes.** A spoke is a wedge and so widest at its tip, which
    # is the one shape a thorn is not; a lobe is the outline itself, joined at
    # the root and pointed at the end, and a high power is a thin point.
    reach = f.math("ADD", root, f.math("MULTIPLY", f.math("SUBTRACT", tip, root),
                                       f.lobes(9, 3.0, f.phase(0.7))))
    spikes = f.both(f.math("LESS_THAN", f.r, reach), f.math("GREATER_THAN", f.r, root))
    # Frayed toward the tip: a bar that climbs with the radius, so a spike is
    # solid at its root and breaks into points at its end.
    frayed = f.both(spikes, f.grain(f.math("MULTIPLY", f.r, 0.52)))

    # A hoop at the root, the moment of the burst.
    hoop = f.both(f.band(root, 0.06), f.before(0.7))

    # A flash at the middle for the first cells only.
    flash = f.both(f.disc(f.shrink(0.28, 0.9)), f.before(0.35))

    alive = f.grain(f.math("MULTIPLY", f.math("POWER", f.age, 2.0), 0.66))
    mask = f.both(f.either(frayed, hoop, flash), alive)
    return f.Look(mask=mask, tone=f.lit(flash, 0.45, hoop, 0.35, frayed, 0.22))
