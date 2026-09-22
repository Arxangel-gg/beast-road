"""A curse landing: arms of light winding inward and a throat opening in the
middle that swallows them.

Everything here closes rather than opens, which is the whole read. A blow
throws a wave outward; a hex takes something, so its boundary shrinks, its
arms turn as they come in, and the last thing on screen is the middle rather
than the rim. It is the slowest sheet of the five for the same reason - a
drain that is over in half a second is a bang.
"""

SPEC = {
    "frames": 16,
    "size": 64,
    "variants": 3,
    "why": "a hexing breed's shot landing on a hero, and mana leaving them",
}

ARMS = 3


def _winding(f, bar, turn):
    """`f.spokes` with a bar that may move.

    The shared helper takes its duty as a plain number, because a spoke count
    is fixed by the shape being drawn. Here the arms have to broaden as they
    wind in - thin threads at the rim, thick ropes at the throat - so the bar
    is a socket and the test is written out.
    """
    turned = f.math("ADD", f.angle, turn)
    wave = f.math("SINE", f.math("MULTIPLY", turned, ARMS * 0.5))
    return f.math("GREATER_THAN", f.math("ABSOLUTE", wave), bar)


def build(f):
    # The turn carries a radius term as well as an age term, which is what
    # makes an arm a spiral rather than a spoke that happens to rotate.
    turn = f.math("ADD", f.math("MULTIPLY", f.age, 3.0),
                  f.math("MULTIPLY", f.r, 3.6))
    bar = f.math("SUBTRACT", 0.94, f.math("MULTIPLY", f.age, 0.34))

    # The mouth reaches out to the rim over the first three cells and only
    # then begins to close. Started at its full width it is a sheet that was
    # already playing before the shot landed, and the whole curve is a
    # decline from the first cell.
    mouth = f.math("MINIMUM",
                   f.math("MINIMUM", f.grow(3.4, 0.22), 0.90),
                   f.shrink(1.30, 1.05))
    frayed = f.math("MAXIMUM",
                    f.math("MULTIPLY", f.math("SUBTRACT", f.age, 0.72), 2.15), 0.0)
    # The throat: it opens as the arms feed it, holds, and is pulled shut over
    # the last cells. Nothing survives it, which is the point of a drain.
    lip = f.math("MINIMUM",
                 f.math("MINIMUM", f.grow(0.75, 0.06), 0.42),
                 f.shrink(2.2, 2.2))

    # And an eye opened in the middle of it, which the arms are cut away from
    # as well. Without it the throat is a solid white ball for five cells in
    # the middle of the sheet, and a drain with nothing to drain into reads as
    # a light being switched on. Kept as a share of the lip so the eye can
    # never outrun it, and so the two close together at the end.
    eye = f.math("MULTIPLY", lip,
                 f.math("MINIMUM",
                        f.math("MAXIMUM",
                               f.math("MULTIPLY",
                                      f.math("SUBTRACT", f.age, 0.28), 1.30), 0.0),
                        0.75))
    clear_of_eye = f.math("GREATER_THAN", f.r, eye)

    arms = f.both(f.both(f.both(_winding(f, bar, turn), f.disc(mouth)),
                         f.grain(frayed)), clear_of_eye)

    # A rim that closes with the mouth, so the boundary is a line rather than
    # the ragged ends of three arms.
    rim = f.both(f.band(f.shrink(0.88, 0.62), 0.06, 0.05), f.grain(frayed))

    throat = f.both(f.disc(lip), clear_of_eye)

    mask = f.either(arms, rim, throat)
    return f.Look(mask=mask, tone=f.lit(throat, 0.45, arms, 0.18))
