"""A meteor landing: a heavy, slow bloom of light and debris off the ground.

The biggest sheet in the set, and the only one with a ground under it. A flash
burns out into a wide low dome, a skirt runs outward along the floor, and
debris is thrown on a real ballistic arc - up, over, and still coming down on
the last cell, which is why the debris is not killed with everything else.

Three squashed distances do the work. The radial coordinate the forge hands
out is a circle, and a circle cannot be a dome, a floor skirt or a lofted
handful of rubble.
"""

SPEC = {
    "frames": 20,
    "size": 128,
    "variants": 3,
    "why": "a meteor, a boulder or any heavy body landing on the ground",
}

# Where the ground is, in object space. Everything here is built off it,
# and it sits just under the middle of the cell rather than near the bottom:
# the impact point is what the game lays this sheet on, so it belongs on the
# centre. A floor near the bottom edge leaves a quarter of every cell dead and
# hangs the bloom above wherever it was drawn.
_FLOOR = -0.10


def build(f):
    def hyp(ax, ay):
        return f.math("SQRT", f.math("ADD", f.math("MULTIPLY", ax, ax),
                                     f.math("MULTIPLY", ay, ay)))

    def inside(metric, to):
        return f.math("LESS_THAN", metric, to)

    def between(metric, inner, outer):
        return f.both(f.math("GREATER_THAN", metric, inner), inside(metric, outer))

    def ring(metric, at, thick):
        return f.math("LESS_THAN",
                      f.math("ABSOLUTE", f.math("SUBTRACT", metric, at)), thick)

    # Torn rather than ruled: a bloom cut off by a straight line reads as a
    # sprite sitting on a shelf.
    over = f.math("GREATER_THAN", f.y,
                  f.math("ADD", _FLOOR, f.math("MULTIPLY", f.noise_fac, 0.14)))

    # Wider than it is tall, which is the whole difference between a dome and
    # a ball. Squashing above one divides the vertical reach.
    lofted = f.math("MULTIPLY", f.math("SUBTRACT", f.y, _FLOOR), 1.08)
    dome_r = hyp(f.x, lofted)
    # Flat to the floor, so the skirt runs out along the ground rather than
    # being a second ring in the air.
    laid = f.math("MULTIPLY", f.math("SUBTRACT", f.y, _FLOOR), 2.6)
    skirt_r = hyp(f.x, laid)

    # The fireball. It *expands* and is burnt away rather than starting at
    # full width and shrinking: a solid disc on the first cell holds more lit
    # pixels than anything that follows it, so the sheet peaks on frame one
    # and every cell after it is a decay.
    #
    # Deliberately not held above the floor either. Clipped, it leaves the
    # impact point itself transparent - a black mouth under the brightest part
    # of the sheet - because nothing else reaches inside the skirt.
    flash = f.both(inside(dome_r, f.grow(0.42, 0.16)),
                   f.grain(f.math("MULTIPLY", f.age, 1.15)))

    # The dome: a shell that runs outward with a hollow chasing it, held to
    # 0.92 so its flanks stay inside the cell. It reaches full width at about
    # four fifths of the life, which is where the sheet should be biggest -
    # growing to the last cell would put the peak under the dissolve.
    crown = f.math("MINIMUM", f.grow(0.86, 0.20), 0.92)
    # The hollow has to chase the crown *closely*, or the shell is thick
    # enough to be 75% of a filled dome and the whole thing reads as a mound
    # of earth rather than as light thrown off one.
    hollow = f.math("MULTIPLY", f.math("POWER", f.age, 1.15), 0.74)
    dome = f.both(f.both(between(dome_r, hollow, crown), over),
                  f.grain(f.math("ADD", 0.16, f.math("MULTIPLY", f.age, 0.40))))

    # The one part that is *not* clipped to above the floor. A ground ring
    # under this camera is an ellipse around the impact, so half of it lies in
    # front of the point - which is also what fills the bottom of the cell.
    # Thin and broken from the first cell. Left thick it is a solid plate
    # under the dome and the pair read as a saucer rather than as a blow.
    skirt = f.both(ring(skirt_r, f.grow(0.62, 0.26),
                        f.math("SUBTRACT", 0.075, f.math("MULTIPLY", f.age, 0.03))),
                   f.grain(f.math("ADD", 0.26, f.math("MULTIPLY", f.age, 0.30))))

    # A real arc: up hard, over, and falling back by the last cells. Read off
    # the linear clock rather than the eased one, because easing an arc bends
    # the throw as well as the timing.
    lift = f.math("SUBTRACT", f.math("MULTIPLY", f.raw_age, 1.30),
                  f.math("MULTIPLY", f.math("MULTIPLY", f.raw_age, f.raw_age), 0.95))
    # Thrown wider than it is deep, and the ball is capped so the top of the
    # arc clears the cell edge rather than being shaved off by it.
    rubble_r = hyp(f.math("MULTIPLY", f.x, 0.62),
                   f.math("SUBTRACT", f.y, f.math("ADD", _FLOOR, lift)))
    # Not killed with the rest: the brief for this shape is debris still
    # coming down on the last cell, so it carries the sheet's tail alone.
    # A shell rather than a filled ball, so the chunks ride the outside of
    # the throw where there is dark behind them. Inside the ball they sit over
    # the lit dome and cannot be told from it.
    #
    # The bar stays under about 0.64. Measured on this noise, a threshold past
    # that passes nothing at all, so a debris field authored to thin out up to
    # 0.70 does not thin - it disappears, and the second cell from the end
    # comes out perfectly blank.
    ball = f.math("MINIMUM", f.grow(0.34, 0.14), 0.48)
    rubble = f.both(between(rubble_r, f.math("MULTIPLY", ball, 0.78), ball),
                    f.grain(f.math("ADD", 0.44, f.math("MULTIPLY", f.age, 0.16))))

    alive = f.grain(f.math("MULTIPLY", f.math("POWER", f.age, 2.6), 0.72))
    mask = f.either(f.both(f.either(flash, dome, skirt), alive), rubble)
    return f.Look(mask=mask,
                  tone=f.lit(flash, 0.45, dome, 0.20, skirt, 0.14))
