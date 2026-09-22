"""A fan of pellets arriving: pocks opening at three depths, a few frames
apart, so the eye reads several small hits rather than one.

What separates this from the bolt is that it never has a middle and never has
a clean edge. The marks also do not travel - a pellet punches a hole where it
landed and the hole stays there while it fades, which is the whole reason this
effect carries a field of its own.
"""

SPEC = {
    "frames": 12,
    "size": 64,
    "variants": 4,
    "why": "a scattergun breed's fan landing on a hero or a tower",
}


def _still_field(f):
    """Noise that does not drift with age.

    The shared field swirls and its slice moves, which is right for a wave
    leaving a blow and wrong for a hole punched in something: on the shared
    field a pellet mark crawls across the cell while it dies.
    """
    grid = f.new("ShaderNodeCombineXYZ", "Still")
    f.links.new(f.x, grid.inputs[0])
    f.links.new(f.y, grid.inputs[1])
    grid.inputs[2].default_value = f.seed * 5.117
    noise = f.new("ShaderNodeTexNoise", "StillNoise")
    f.links.new(grid.outputs[0], noise.inputs["Vector"])
    # Coarser than the shared field looks at this cell size: cut finer than
    # this the marks stop reading as pellet holes and become a fizz.
    noise.inputs["Scale"].default_value = 3.8
    noise.inputs["Detail"].default_value = 2.0
    noise.inputs["Roughness"].default_value = 0.5
    return noise.outputs["Fac"]


def _pocks(f, field, coarse, inner, reach, opens, shuts, rate):
    """One volley of pellet marks: speckle in an annulus that opens outward
    over two cells and then holds at `reach`.

    Holding is the point. A shell that kept growing would be a wave, and the
    three of them together would be one wave with a rough edge; pinned at
    their own depths they read as three volleys landing.
    """
    # Measured from the volley's own arrival rather than from the effect's
    # clock: grown on the shared age a late shell is already at full width on
    # the cell it appears, which reads as a shape being switched on.
    since = f.math("MAXIMUM", f.math("SUBTRACT", f.age, opens), 0.0)
    outer = f.math("MINIMUM", f.grow(1.1, inner + 0.05, of=since), reach)
    gone = f.math("MAXIMUM",
                  f.math("MULTIPLY", f.math("SUBTRACT", f.age, shuts), rate), 0.0)
    marks = f.grain(f.math("ADD", coarse, gone), source=field)
    return f.both(f.both(marks, f.ring_gap(inner, outer)), f.after(opens))


def build(f):
    field = _still_field(f)

    # The bar each shell cuts the field at climbs slowly: the field is tight
    # about its middle, so a tenth on the bar is most of the speckle and a
    # fast rate is a volley that vanishes between two cells rather than frays.
    near = _pocks(f, field, 0.405, 0.00, 0.38, -0.1, 0.12, 0.62)
    mid = _pocks(f, field, 0.450, 0.26, 0.58, 0.13, 0.42, 0.60)
    far = _pocks(f, field, 0.492, 0.50, 0.88, 0.26, 0.60, 0.42)

    # One solid pellet at the point of aim, so the scatter has an origin to be
    # a scatter from, and so the first cell is not a handful of specks.
    seed = f.disc(f.shrink(0.36, 0.72))

    mask = f.either(near, mid, far, seed)
    return f.Look(mask=mask, tone=f.lit(seed, 0.4, near, 0.2, far, 0.12))
