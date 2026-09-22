"""The ring of motes that turns at the feet of a Warden wearing a finished
set: two thin rings of small blobs going opposite ways, breathing as they go.

Faint on purpose. This one is on screen for as long as the set is worn, and
the aura is a tell rather than an event - anything bright enough to be
noticed on the first pass is bright enough to be tiring on the thousandth.

It loops, so nothing in it touches the noise: the noise field drifts and
swirls with age and can never come back to where it started. Every figure
here is either static or a whole number of turns over the life.
"""

SPEC = {
    "frames": 24,
    "size": 96,
    "variants": 3,
    "why": "a completed gear set worn, a standing aura at the feet",
}

# How many motes on each ring, and how far out. Nothing in this effect reads
# the noise, so without a table the takes would be one picture rendered three
# times - the seed reaches an effect through the noise field and this one has
# none of it.
#
# **As many rows as the highest `variants` ever asked for.** A table indexed
# by the seed repeats the moment the take count passes its length, silently -
# the render succeeds and writes a file identical to one already on disk.
TAKES = (
    (12, 0.62, 8, 0.40),
    (9, 0.66, 6, 0.355),
    (14, 0.575, 10, 0.43),
    (11, 0.595, 7, 0.385),
)


def _cycle(f, turns, phase=0.0):
    """A 0..1 wave over the life that closes exactly on itself."""
    ang = f.math("ADD", f.math("MULTIPLY", f.raw_age, 6.2831853 * turns), phase)
    return f.math("MULTIPLY", f.math("ADD", f.math("SINE", ang), 1.0), 0.5)


def _orbit(f, count, lobes, sign=1.0):
    """A turn of whole lobes over the life: the motes travel and the last
    cell still draws what the first one drew."""
    return f.math("MULTIPLY", f.raw_age,
                  sign * lobes * 6.2831853 / float(count))


def build(f):
    many, far, few, near = TAKES[int(f.seed) % len(TAKES)]

    # The two rings breathe out of phase, so the aura never has a moment of
    # being uniformly bright or uniformly dim.
    swell_far = _cycle(f, 3.0)
    swell_near = _cycle(f, 3.0, 3.1415927)

    outer = f.both(
        f.spokes(many, 0.07, _orbit(f, many, 2.0, 1.0)),
        f.band(far, f.math("ADD", 0.050, f.math("MULTIPLY", swell_far, 0.030)), 0.045))

    # Counter-turning, which is what stops two rings reading as one thick one.
    inner = f.both(
        f.spokes(few, 0.06, _orbit(f, few, 2.0, -1.0)),
        f.band(near, f.math("ADD", 0.042, f.math("MULTIPLY", swell_near, 0.026)), 0.038))

    mask = f.either(outer, inner)
    return f.Look(mask=mask, tone=f.lit(outer, 0.22, inner, 0.14))
