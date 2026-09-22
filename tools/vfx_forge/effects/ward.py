"""A shield being raised: a faceted shell that gathers, stands, then goes.

The one effect here that is not an impact, and it is shaped by that. Loose
motes condense into six straight plates with seams at the corners, a hoop
peels inward behind them, and the whole thing breaks up at the end. Its lit
curve is a plateau rather than a spike, because a ward that flashed would read
as a blow landing on the player rather than as a guard going up.
"""

SPEC = {
    "frames": 16,
    "size": 96,
    "variants": 3,
    "why": "a ward, an aegis, a shield granted: the guard standing up",
}

# cos and sin of 60 and 120 degrees, for the three hexagon axes.
_HALF = 0.5
_ROOT = 0.8660254


def build(f):
    # Two clocks, because a shell that forms and a shell that goes are not one
    # curve run backwards. It gathers in a third and is still standing at two.
    form = f.math("MINIMUM", f.math("MULTIPLY", f.raw_age, 3.0), 1.0)
    gone = f.math("MAXIMUM",
                  f.math("DIVIDE", f.math("SUBTRACT", f.raw_age, 0.55), 0.45),
                  0.0)
    # A third clock for the hoop, so it arrives *after* the plates. Structure
    # that appears all at once reads as a picture; structure that appears in
    # an order reads as being built.
    lock = f.math("MINIMUM",
                  f.math("MULTIPLY",
                         f.math("MAXIMUM", f.math("SUBTRACT", f.raw_age, 0.26), 0.0),
                         4.5),
                  1.0)

    def axis(cx, cy):
        return f.math("ABSOLUTE",
                      f.math("ADD", f.math("MULTIPLY", f.x, cx),
                             f.math("MULTIPLY", f.y, cy)))

    # A true hexagonal distance - the largest of three projections - so the
    # sides are straight and a corner is a corner. A sinusoidal bulge on the
    # radius was tried first and reads as a flower, because its lobes are
    # round and they bulge outward at exactly the seams.
    hexd = f.math("MAXIMUM", axis(1.0, 0.0),
                  f.math("MAXIMUM", axis(_HALF, _ROOT), axis(-_HALF, _ROOT)))

    def plate(at, thick):
        return f.math("LESS_THAN",
                      f.math("ABSOLUTE", f.math("SUBTRACT", hexd, at)), thick)

    # A hexagon fits a square frame better than a circle does: its corners sit
    # at (a, 0.577a), so an apothem of 0.9 still clears the cell edge.
    spine = 0.68
    # Almost all of the gathering is density rather than width. Shrinking a
    # wide cloud into a thin plate makes the lit count hump in the middle -
    # area falls faster than density rises - and a hump mid-formation reads
    # as a flicker.
    thick = f.math("SUBTRACT", 0.135, f.math("MULTIPLY", form, 0.050))
    # Seams on the corners: `spokes` peaks 30 degrees off the hexagon's sides,
    # so a turn of 30 degrees puts the plates on the flats.
    plates = f.spokes(6, 0.80, 0.5236)

    shell = f.both(
        f.both(f.both(plate(spine, thick), plates),
               f.grain(f.math("MULTIPLY",
                              f.math("SUBTRACT", 1.0, form), 0.52))),
        # A few flecks missing, drifting with the swirl. Without them the
        # standing shell is an inert icon for eight cells.
        f.hole(0.74))

    # A continuous hoop behind the panels, peeling inward off the shell rather
    # than switching on, which is why it rides the lock clock. It condenses on
    # that clock too: drawn solid from the first cell it is a finished hexagon
    # sitting behind a cloud, which is the opposite of gathering.
    hoop = f.both(
        plate(f.math("SUBTRACT", spine, f.math("MULTIPLY", lock, 0.22)), 0.05),
        f.grain(f.math("MULTIPLY", f.math("SUBTRACT", 1.0, lock), 0.52)))

    hub = f.math("LESS_THAN", hexd, f.math("MULTIPLY", form, 0.15))

    # It breaks up rather than dimming. The bar stops short of clearing the
    # frame so the last cell holds the shell coming apart rather than nothing.
    alive = f.grain(f.math("MULTIPLY", gone, 0.68))
    mask = f.both(f.either(shell, hoop, hub), alive)
    return f.Look(mask=mask, tone=f.lit(hub, 0.40, shell, 0.28, hoop, 0.05))
