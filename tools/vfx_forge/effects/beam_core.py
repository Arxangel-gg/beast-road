"""One segment of a hyperbeam: a band across the whole cell whose width
breathes, a white-hot core, and two crackling arcs spiralling round it -
the plasma and the lightning in one picture. Tiled end to end along the
beam by the game, AIMED along it, so the arcs are what make it read as
moving rather than as a bar.

It holds for most of its life and burns out at the end, because a beam that
eroded from its first cell would read as a spark rather than a sustained
ray.
"""

SPEC = {
    "frames": 12,
    "size": 128,
    "variants": 3,
    "why": "the fire dragon's ultra breath: a plasma hyperbeam, tiled along its line",
}


def build(f):
    ay = f.math("ABSOLUTE", f.y)
    # The band's width breathes along x and with time.
    wave = f.math("SINE", f.math("ADD", f.math("MULTIPLY", f.x, 9.0),
                                 f.math("MULTIPLY", f.raw_age, 21.0)))
    width = f.math("ADD", 0.17, f.math("MULTIPLY", wave, 0.05))
    band = f.math("LESS_THAN", ay, width)
    core = f.math("LESS_THAN", ay, f.math("MULTIPLY", width, 0.42))
    turn = f.phase(6.283)
    swing1 = f.math("MULTIPLY", 0.30, f.math("SINE", f.math("ADD", f.math(
        "ADD", f.math("MULTIPLY", f.x, 7.0), f.math("MULTIPLY", f.raw_age, 31.0)), turn)))
    arc1 = f.math("LESS_THAN", f.math("ABSOLUTE", f.math("SUBTRACT", f.y, swing1)), 0.035)
    swing2 = f.math("MULTIPLY", 0.25, f.math("SINE", f.math("ADD", f.math(
        "SUBTRACT", f.math("MULTIPLY", f.x, 11.0), f.math("MULTIPLY", f.raw_age, 27.0)),
        f.math("MULTIPLY", turn, 2.0))))
    arc2 = f.math("LESS_THAN", f.math("ABSOLUTE", f.math("ADD", f.y, swing2)), 0.03)
    # Arcs break up; the band only frays at the very end of the sheet.
    arcs = f.both(f.either(arc1, arc2), f.grain(0.44))
    late = f.math("MAXIMUM", f.math("SUBTRACT", f.age, 0.72), 0.0)
    held = f.grain(f.math("ADD", 0.18, f.math("MULTIPLY", late, 1.6)))
    mask = f.both(f.either(band, arcs), held)
    return f.Look(mask=mask, tone=f.lit(core, 0.45, band, 0.16, arcs, 0.2))
