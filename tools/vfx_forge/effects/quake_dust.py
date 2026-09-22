"""The dust an earthquake pushes out along the ground: low, rough and slow.

Almost none of it is in the middle. The cloud is a rim that tracks its own
leading edge rather than a disc that hollows out later - a disc that opens
late is six solid cells of nothing happening, which is what the first cut of
this was. It runs on a clock of its own, slower than the forge's eased age,
because a quake arrives and leaves over seconds where an impact is over in a
moment.
"""

SPEC = {
    "frames": 20,
    "size": 128,
    "variants": 4,
    "why": "an earthquake rolling out along the ground, and any heavy ground collapse",
}


def build(f):
    # Slower than the eased age and slower than linear: dust does not leap.
    roll = f.math("POWER", f.raw_age, 1.25)

    outer = f.grow(0.72, 0.22, of=roll)
    # The body narrows as it spreads, so the cloud is a rim from the third
    # cell on rather than a growing disc.
    body = f.math("SUBTRACT", 0.30, f.math("MULTIPLY", roll, 0.21))
    inner = f.math("SUBTRACT", outer, body)

    # Rough twice over: a threshold that climbs as the dust thins, and
    # pinholes torn in whatever is left. One threshold alone reads as a
    # smooth cloud with a ragged edge rather than as dust.
    thinning = f.grain(f.math("ADD", 0.40, f.math("MULTIPLY", roll, 0.26)))
    pinholes = f.hole(0.86)

    # Three slow billows rather than nine: an even count of narrow gaps reads
    # as the teeth of a pinwheel, and this has to read as weather.
    lobes = f.spokes(3, 0.90, turn=f.math("MULTIPLY", roll, 0.6))

    cloud = f.both(f.both(f.ring_gap(inner, outer), f.both(thinning, pinholes)), lobes)

    # The leading edge, a shade brighter, so the rim reads as the front of
    # something rather than as the outside of a blob.
    rim = f.both(f.band(outer, 0.08, 0.05), thinning)

    mask = f.either(cloud, rim)
    return f.Look(mask=mask, tone=f.lit(rim, 0.20))
