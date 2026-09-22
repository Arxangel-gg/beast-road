"""A meteor landing: a heavy, slow bloom of fire off the ground.

The biggest sheet in the set, and the only one with a ground under it. A
flash burns out into a rising dome, tongues of fire climb out of the top of
it, a skirt runs outward along the floor, and debris is thrown on a real
ballistic arc - up, over, and still coming down on the last cell, which is
why the debris is not killed with everything else.

**The first cut read as a flat lens and the reason was one number.** The dome
was measured on `hypot(x, (y - floor) * 1.08)`, which scales y *up* - so the
shape reached less far vertically than horizontally and came out wider than
it was tall. Stacked on a skirt that is deliberately flatter still, the pair
read as an eye. A bloom is taller than it is wide, so the dome's y is scaled
*down*, and what makes it a bloom rather than a dome is that fire leaves the
top of it.

Four squashed distances do the work. The radial coordinate the forge hands
out is a circle, and a circle cannot be a rising dome, a floor skirt or a
lofted handful of rubble.
"""

SPEC = {
    "frames": 20,
    "size": 128,
    "variants": 3,
    "why": "a meteor, a boulder or any heavy body landing on the ground",
}

# Where the ground is, in object space. Everything here is built off it, and
# it sits below the middle of the cell rather than on it: a bloom goes up, so
# what is above the floor needs most of the room. The impact point is what
# the game lays this sheet on, and `Vfx` draws the cell centred on that - so
# the floor a little below centre is the impact point standing a little below
# the middle of its own picture, which is correct.
_FLOOR = -0.26
# Taller than wide, which is the whole difference between a bloom and a
# saucer. Below one stretches the vertical reach.
_RISE = 0.66
# And flat to the floor, so the skirt runs out along the ground rather than
# being a second ring in the air.
_LAID = 2.6


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
                  f.math("ADD", _FLOOR, f.math("MULTIPLY", f.noise_fac, 0.12)))

    above = f.math("SUBTRACT", f.y, _FLOOR)
    lofted = f.math("MULTIPLY", above, _RISE)
    dome_r = hyp(f.x, lofted)
    laid = f.math("MULTIPLY", above, _LAID)
    skirt_r = hyp(f.x, laid)

    # The fireball. It *expands* and is burnt away rather than starting at
    # full width and shrinking: a solid disc on the first cell holds more lit
    # pixels than anything that follows it, so the sheet would peak on frame
    # one and every cell after it would be a decay.
    #
    # Deliberately not clipped to above the floor either. Clipped, it leaves
    # the impact point itself transparent - a black mouth under the brightest
    # part of the sheet - because nothing else reaches inside the skirt.
    flash = f.both(inside(dome_r, f.grow(0.40, 0.16)),
                   f.grain(f.math("MULTIPLY", f.age, 1.15)))

    # The dome: a shell running outward with a hollow chasing it closely. Left
    # thick it is 75% of a filled dome and reads as a mound of earth rather
    # than as light thrown off one.
    crown = f.math("MINIMUM", f.grow(0.84, 0.20), 0.90)
    hollow = f.math("MULTIPLY", f.math("POWER", f.age, 1.15), 0.72)
    dome = f.both(f.both(between(dome_r, hollow, crown), over),
                  f.grain(f.math("ADD", 0.16, f.math("MULTIPLY", f.age, 0.40))))

    # **Tongues leaving the top of it**, which is what makes this a bloom
    # rather than a dome. `lobes` is the outline itself - pointed at the tip
    # and joined at the root - so these are flames rather than the wedges
    # `spokes` would give, which are widest where a flame is thinnest.
    #
    # They are measured on the dome's own metric and reach past its crown, so
    # they leave the shell rather than sitting on top of it, and they are
    # held above the floor so none of them licks downward into the ground.
    tongue_reach = f.math("MULTIPLY", f.math("ADD", crown, 0.26),
                          f.math("ADD", 0.52, f.math("MULTIPLY",
                                                     f.lobes(7, 2.6, f.phase(3.1)), 0.62)))
    tongues = f.both(
        f.both(between(dome_r, f.math("MULTIPLY", crown, 0.72), tongue_reach), over),
        # Thinning as they climb, and gone by the last third: fire that is
        # still standing when the dust has settled reads as a bonfire.
        f.grain(f.math("ADD", 0.22, f.math("MULTIPLY", f.math("POWER", f.age, 1.4), 0.46))))

    # The one part that is *not* clipped to above the floor. A ground ring
    # under this camera is an ellipse around the impact, so half of it lies in
    # front of the point - which is also what fills the bottom of the cell.
    # Thin and broken from the first cell; left thick it is a solid plate
    # under the dome and the pair read as a saucer rather than as a blow.
    skirt = f.both(ring(skirt_r, f.grow(0.60, 0.26),
                        f.math("SUBTRACT", 0.070, f.math("MULTIPLY", f.age, 0.028))),
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
    # coming down on the last cell, so it carries the sheet's tail alone. A
    # shell rather than a filled ball, so the chunks ride the outside of the
    # throw where there is dark behind them; inside the ball they sit over the
    # lit dome and cannot be told from it.
    #
    # The bar stays under about 0.64. Measured on this noise, a threshold past
    # that passes nothing at all, so a debris field authored to thin out up to
    # 0.70 does not thin - it disappears, and the second cell from the end
    # comes out perfectly blank.
    ball = f.math("MINIMUM", f.grow(0.34, 0.14), 0.48)
    rubble = f.both(between(rubble_r, f.math("MULTIPLY", ball, 0.78), ball),
                    f.grain(f.math("ADD", 0.44, f.math("MULTIPLY", f.age, 0.16))))

    alive = f.grain(f.math("MULTIPLY", f.math("POWER", f.age, 2.6), 0.72))
    mask = f.either(f.both(f.either(flash, dome, tongues, skirt), alive), rubble)
    return f.Look(mask=mask,
                  tone=f.lit(flash, 0.45, dome, 0.20, tongues, 0.16, skirt, 0.12))
