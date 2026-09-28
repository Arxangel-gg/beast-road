"""A guard's stone breaking: a shell coming apart into chips where a shot was
swallowed.

The ward's shell shape, taken apart: a flash where the shot met the stone,
and chips thrown outward in wedges that thin and scatter. It is the one
moment a defence is *seen* to do its work, so the first cells are the
brightest thing on the sheet and the rest is debris.
"""

SPEC = {
    "frames": 14,
    "size": 96,
    "variants": 3,
    "why": "Guardian Stones and Stone Choir swallowing a hostile shot",
}


def build(f):
    # Chips run outward from a ring that widens; wedges keep them as pieces
    # rather than a spray, and the grain scatters the pieces.
    out = f.math("MINIMUM", f.grow(0.85, 0.22), 0.92)
    inner = f.grow(0.60, 0.10)
    chips = f.both(f.both(f.spokes(7, 0.42, f.phase(0.9)), f.ring_gap(inner, out)),
                   f.grain(0.50))

    # The stone itself, still there for the first cells and then gone.
    stone = f.both(f.disc(f.shrink(0.30, 0.55)), f.hole(0.66))

    # The flash of the swallow: a bright disc that is gone by a third.
    flash = f.both(f.disc(f.shrink(0.42, 1.3)), f.before(0.32))

    alive = f.grain(f.math("MULTIPLY", f.math("POWER", f.age, 1.8), 0.66))
    mask = f.both(f.either(chips, stone, flash), alive)
    return f.Look(mask=mask, tone=f.lit(flash, 0.5, stone, 0.2, chips, 0.22))
