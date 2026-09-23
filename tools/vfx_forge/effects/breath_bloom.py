"""The mouth of a breath: a bloom with licking petals and a white-hot heart,
played where the breath leaves the dragon as it opens, and at the far end
where it lands. Radial, so FREE - it may spin and flip, and a road of forty
breaths is forty different blooms.
"""

SPEC = {
    "frames": 14,
    "size": 96,
    "variants": 3,
    "why": "the bloom at a breath's mouth and where it lands",
}


def build(f):
    out = f.grow(0.95, 0.14)
    petals = f.math("LESS_THAN", f.r,
                    f.math("MULTIPLY", out,
                           f.math("ADD", 0.55,
                                  f.math("MULTIPLY", f.lobes(7, 2.0, f.phase(6.283)), 0.62))))
    heart = f.disc(f.shrink(0.40, 0.46))
    alive = f.grain(f.math("ADD", 0.30, f.math("MULTIPLY", f.age, 0.30)))
    mask = f.both(f.either(petals, heart), alive)
    return f.Look(mask=mask, tone=f.lit(heart, 0.45, petals, 0.14))
