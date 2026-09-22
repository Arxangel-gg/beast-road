"""A meteor's streak, drawn pointing right: the head at the leading end and
the tail fraying away behind it.

It slides the whole way across the cell over its life and leaves by the right
edge, so the sheet is the passage rather than a still of one. It runs on the
raw age rather than the eased one, because a falling rock does not leap and
then linger - it crosses at one speed, and easing it reads as a stutter.

The game rotates the sheet to the meteor's own heading, so everything here is
authored along +x and nothing may depend on which way up the cell is.
"""

SPEC = {
    "frames": 12,
    "size": 128,
    "variants": 4,
    "why": "a meteor falling, and any fast body that leaves a streak behind it",
}


def build(f):
    # The take's own seed, spent on the streak's shape as well as on the
    # noise slice: four rocks that burn the same way are one rock.
    strands = 11.0 + float(int(f.seed) % 4) * 1.5
    waver = 5.0 + ((f.seed * 0.618) % 1.0) * 3.0
    length = 1.34 + ((f.seed * 0.377) % 1.0) * 0.22

    # The head crosses from off the left to off the right. It leaves the cell
    # before the last frame on purpose: a head still burning in the last cell
    # pops when the sheet is freed.
    head_x = f.math("SUBTRACT", f.math("MULTIPLY", f.raw_age, 1.85), 0.55)
    behind = f.math("SUBTRACT", head_x, f.x)
    from_axis = f.math("ABSOLUTE", f.y)

    ahead = f.math("SUBTRACT", f.x, head_x)
    # Drawn long rather than round: a circle at the leading end reads as a
    # ball with a streak stuck to it.
    squashed = f.math("MULTIPLY", ahead, 0.62)
    head = f.math("LESS_THAN",
                  f.math("ADD", f.math("MULTIPLY", squashed, squashed),
                         f.math("MULTIPLY", f.y, f.y)),
                  0.016)

    # The trail shortens as the rock leaves: what it drew is dissipating
    # behind it, so a trail of fixed length would still be at full reach on
    # the frame the head has gone.
    reach = f.math("SUBTRACT", length, f.math("MULTIPLY", f.raw_age, 0.70))
    along = f.math("DIVIDE", behind, reach)
    inside = f.both(f.math("GREATER_THAN", behind, 0.0),
                    f.math("LESS_THAN", along, 1.0))

    # Narrowing away from the head, and never to a hairline.
    half = f.math("MAXIMUM",
                  f.math("SUBTRACT", 0.16, f.math("MULTIPLY", along, 0.09)), 0.055)
    body = f.both(inside, f.math("LESS_THAN", from_axis, half))

    # Frayed by distance behind the head rather than by age alone, so the far
    # end of the trail is always the ragged end.
    # The fraying is held off until the last two thirds. The forge's noise is
    # coarser than this streak is wide, so a threshold climbing from the head
    # does not fray the trail - it deletes it in lumps, which is what the
    # first cut of this did.
    far = f.math("MAXIMUM", f.math("SUBTRACT", along, 0.38), 0.0)
    fray = f.math("ADD", f.math("ADD", 0.18, f.math("MULTIPLY", far, 1.05)),
                  f.math("MULTIPLY", f.raw_age, 0.10))

    # Filaments along the streak, wavering with the length they run: without
    # them the trail is one solid lozenge and reads as a blimp rather than as
    # something burning. The spine is held out of them, so the middle of the
    # streak stays whole and only its flanks come apart.
    filament = f.math("LESS_THAN",
                      f.math("FRACT",
                             f.math("ADD", f.math("MULTIPLY", f.y, strands),
                                    f.math("MULTIPLY",
                                           f.math("SINE", f.math("MULTIPLY", f.x, waver)),
                                           0.5))),
                      0.58)
    spine = f.both(inside, f.math("LESS_THAN", from_axis,
                                  f.math("MULTIPLY", half, 0.40)))
    trail = f.both(f.either(spine, f.both(body, filament)), f.grain(fray))

    # Sparks shed wider than the trail itself, which is what stops the edge
    # reading as a drawn line.
    sparks = f.both(f.both(inside,
                           f.math("LESS_THAN", from_axis,
                                  f.math("MULTIPLY", half, 2.3))),
                    f.grain(f.math("ADD", 0.62, f.math("MULTIPLY", f.raw_age, 0.08))))

    mask = f.either(head, trail, sparks)
    return f.Look(mask=mask, tone=f.lit(head, 0.45, trail, 0.16))
