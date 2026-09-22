"""Where a beam lands: a hot point, a radial star, and spray thrown back
along the beam's own axis.

The spray is the one directional thing in this batch. It is drawn leaning
right, along +x, and the game turns the sprite to lay it back up the beam - so
nothing here may be a mirrored pair, and everything that is not spray is
radial. That is what lets the sheet be rotated to any angle without half of it
pointing into the surface it is hitting.
"""

SPEC = {
    "frames": 14,
    "size": 96,
    "variants": 4,
    "why": "a beam, a lance or a ray terminating on what it has hit",
}


def build(f):
    # The cosine of the angle off the axis: one straight ahead, zero at the
    # sides, negative behind. It biases the grain *bar* rather than cutting a
    # wedge, and that is the whole difference between a splash and a blade -
    # a wedge has two dead straight edges, and nothing thrown off a surface
    # has an edge like that. It also means the spray simply runs out behind
    # rather than being clipped, so there is no seam to see.
    lean = f.math("MULTIPLY",
                  f.math("DIVIDE", f.x, f.math("MAXIMUM", f.r, 0.02)), 0.54)
    # The bar rises, so the spray thins into droplets as it flies. It has to
    # start well above the lean: set any lower, the bar along the axis never
    # reaches the noise at all and the splash stays a solid lune for its whole
    # life, which is what the cut before this one did.
    bar = f.math("ADD", 0.84, f.math("MULTIPLY", f.age, 0.32))
    sprayed = f.math("GREATER_THAN", f.math("ADD", f.noise_fac, lean), bar)

    # The point the beam is standing on. It holds for the first third and then
    # burns down rather than switching off, because a terminus that vanishes
    # reads as the beam having stopped rather than as the splash leaving.
    hot = f.math("SUBTRACT", 0.27, f.math("MULTIPLY", f.age, 0.20))
    point = f.both(f.disc(hot), f.grain(f.math("MULTIPLY", f.age, 1.05)))

    # A radial star at the impact, which is rotation-safe where the spray is
    # not, and is most of what makes the first cells read as a hit rather than
    # as the beginning of a spray.
    star = f.both(f.both(f.spokes(8, 0.11), f.disc(f.grow(0.34, 0.30))),
                  # Gone by the third cell: a star still standing while the
                  # spray is halfway out reads as a rosette rather than as
                  # the flash the blow made on arrival.
                  f.grain(f.math("MULTIPLY", f.age, 1.9)))

    # The body of the splash, leaving the point as its near edge opens.
    reach = f.grow(0.74, 0.18)
    near = f.math("MULTIPLY", f.math("POWER", f.age, 1.5), 0.62)
    body = f.both(sprayed, f.ring_gap(near, reach))

    # Filaments running past the body's own front: a splash is droplet trails
    # rather than a sheet, and these are what read as thrown. Held to the
    # thinnest part of the spray so they stay near the axis.
    past = f.math("MINIMUM", f.math("ADD", reach, 0.22), 0.93)
    # Each filament ends where the noise under it says, so their tips are
    # ragged and no two are the same length. Evenly spaced spokes all ending
    # on one arc read as the teeth of a cog, which is what the first cut of
    # this was.
    tip = f.math("MULTIPLY", past,
                 f.math("ADD", 0.40, f.math("MULTIPLY", f.noise_fac, 1.05)))
    threads = f.both(
        f.both(f.spokes(18, 0.08),
               f.math("GREATER_THAN", f.math("ADD", f.noise_fac, lean),
                      f.math("ADD", bar, 0.02))),
        f.ring_gap(f.math("MULTIPLY", hot, 0.6), tip))

    alive = f.grain(f.math("MULTIPLY", f.math("POWER", f.age, 2.0), 0.62))
    mask = f.both(f.either(point, star, body, threads), alive)
    return f.Look(mask=mask, tone=f.lit(point, 0.45, star, 0.26, body, 0.16))
