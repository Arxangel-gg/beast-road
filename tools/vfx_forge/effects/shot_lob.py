"""A mortar shot landing: a wide flat ring thrown out along the ground with a
skirt of dust running ahead of it, and a heavy bloom inside at the impact.

Everything here is measured on a squashed radius, so every shape is an ellipse
lying on the floor rather than a hoop standing up in the air. That is what
tells a lob from a bolt at a glance and it is worth a radius of its own: the
camera looks down and slightly along, and a circle drawn flat on that ground
is an ellipse on the screen.

The dust runs outside the ring rather than behind it. Inside, it would be
hidden under the ring's own band and would cost a shape that draws nothing -
the whole effect would read as one hard hoop widening.
"""

SPEC = {
    "frames": 14,
    "size": 64,
    "variants": 3,
    "why": "a mortar or lobbed shot landing on the ground beside a hero",
}

# How much wider than tall the ground reads. Flat enough to be obviously not a
# circle, not so flat that the ring's near and far edges merge into one line.
SQUASH = 2.1


def _ground_r(f):
    """Distance from the impact measured along the floor."""
    flat = f.math("MULTIPLY", f.y, SQUASH)
    return f.math("SQRT", f.math("ADD", f.math("MULTIPLY", f.x, f.x),
                                 f.math("MULTIPLY", flat, flat)))


def _within(f, er, to):
    return f.math("LESS_THAN", er, to)


def _ground_band(f, er, at, thick, floor):
    """The band helper again, on the squashed radius. Same floor rule: a ring
    that thins to nothing reads as a wire drawn on the ground."""
    gap = f.math("ABSOLUTE", f.math("SUBTRACT", er, at))
    return f.math("LESS_THAN", gap, f.math("MAXIMUM", thick, floor))


def build(f):
    er = _ground_r(f)

    # The ring starts as a filled splat - its inner edge is behind the middle
    # for the first few cells - and only opens into a ring as it runs. A lob
    # that is a hoop from frame one has landed nothing.
    at = f.grow(0.44, 0.12)
    thick = f.math("SUBTRACT", 0.19, f.math("MULTIPLY", f.age, 0.105))
    worn = f.math("MAXIMUM",
                  f.math("MULTIPLY", f.math("SUBTRACT", f.age, 0.46), 1.35), 0.0)
    ring = f.both(_ground_band(f, er, at, thick, 0.075), f.grain(worn))
    edge = f.math("ADD", at, thick)

    # The bloom sits inside the band and is read as a bright middle rather
    # than as a shape of its own, which is what the tone is for.
    core = _within(f, er, f.math("MINIMUM", f.grow(0.60, 0.26),
                                 f.shrink(0.52, 0.85)))

    # Dust thrown out past the ring, settling as it goes: the outer edge runs
    # faster than the ring so the skirt widens, and the bar it is cut at
    # climbs so it thins to nothing rather than being switched off.
    settling = f.math("MAXIMUM",
                      f.math("MULTIPLY", f.math("SUBTRACT", f.age, 0.28), 0.42), 0.0)
    skirt = f.both(
        f.both(f.grain(f.math("ADD", 0.42, settling)),
               f.math("GREATER_THAN", er, edge)),
        _within(f, er, f.math("MINIMUM", f.grow(0.62, 0.36), 0.93)))

    mask = f.either(core, ring, skirt)
    return f.Look(mask=mask, tone=f.lit(core, 0.45, ring, 0.22, skirt, 0.1))
