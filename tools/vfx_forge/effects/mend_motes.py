"""A mend: motes rising off the ground and gathering into the chest.

Upright, because it knows which way is up - the motes come from below and
lift, and the gathering happens above the middle of the cell where a body's
chest is. Three clocks: a cloud that lifts, a gathering that closes in, and a
glow that arrives once the motes have.
"""

SPEC = {
    "frames": 16,
    "size": 96,
    "variants": 3,
    "why": "a mend landing on a Warden, a tower or the wall: motes gathering in",
}


def build(f):
    # The cloud lifts with age: the frame is shifted upward, so a mote drawn at
    # a fixed place in the shifted frame climbs on the sheet.
    ry = f.rise(1.1)
    lifted = f.math("SQRT", f.math("ADD", f.math("MULTIPLY", f.x, f.x),
                                   f.math("MULTIPLY", ry, ry)))
    cloud = f.both(f.both(f.math("LESS_THAN", lifted, 0.95), f.grain(0.60)),
                   f.before(0.8))

    # The gathering: a disc closing in on the chest, thinned by a bar that
    # falls as it closes so the motes read as condensing rather than a plate
    # shrinking.
    closing = f.shrink(0.6, 0.55)
    gather = f.both(f.disc(closing),
                    f.grain(f.math("SUBTRACT", 0.64, f.math("MULTIPLY", f.age, 0.22))))

    # The glow that arrives once they have: nothing for the first half, then a
    # soft disc that swells and is gone with the rest.
    late = f.math("MAXIMUM", f.math("SUBTRACT", f.age, 0.5), 0.0)
    core = f.disc(f.math("MULTIPLY", late, 0.55))

    alive = f.grain(f.math("MULTIPLY", f.math("POWER", f.age, 2.6), 0.62))
    mask = f.both(f.either(cloud, gather, core), alive)
    return f.Look(mask=mask, tone=f.lit(core, 0.45, gather, 0.25, cloud, 0.08))
