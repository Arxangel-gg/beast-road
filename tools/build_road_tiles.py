"""Turn a PixelLab path-tile set into Beast Road's 16 autotile pieces.

    python tools/build_road_tiles.py <tiles-dir> <rules.json> <terrain-id> [road-value]

The engine indexes road art by a 4-bit neighbour mask (bit0=N, bit1=E, bit2=S,
bit3=W) and expects `path_<terrain>_NN.png`, so the job is to get from "eighteen
tiles in generator order" to "sixteen tiles named for what they connect".

Three things here were each learned the hard way, and all three are why this is a
script in the repository rather than something done by hand each time.

**The generator's tile order is not the mask order.** It ships explicit per-tile
edge rules; use them. Assuming `tile_N` is mask N produces a road that looks
plausible in a contact sheet and breaks into disconnected C and J shapes the
moment it is laid out.

**A set does not contain all sixteen masks.** Two or three are always missing.
They are recovered by rotating a tile that has the right shape, which works
because a quarter turn maps the mask bits round by one.

**The road is clipped to a canonical shape rather than colour-keyed out of its
background.** Keying was tried first and is a trap: it depends on the road and
the ground being different colours, which holds for a dirt road on marsh and
fails completely for a grey road on snow. Worse, it fails *quietly* - a keyed
tile looks right on its own and only shows as a hole or a seam once laid. The
canonical clip is independent of the art: every piece presents exactly the same
16-pixel-wide road at every edge it connects on, so the tiles cannot mis-join no
matter what the generator drew. The generated painting survives inside the clip;
only its silhouette is replaced.
"""

from __future__ import annotations

import json
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

TILE = 32
# The road's half-width at a tile edge. 16 of 32 is half the tile, which is what
# the battlefield's PIECE sizing assumes when it draws a piece at twice the
# carriageway (see Battlefield.ROAD_ART_SPAN).
BAND = (8, 24)
# Corner rounding radius, in source pixels. Big enough to read as a real bend at
# the twelvefold scale the road is drawn at, small enough to leave the straight
# sections straight. This is the number that decides whether the U-bends look
# curved or stepped, and stepped is what the first pass shipped.
ROUND = 4
# How deep the forced full-width collar runs in from a connected edge. Only the
# join has to be exact; inside the tile the road keeps whatever silhouette the
# generator painted, which is what stops it reading as a slab.
COLLAR = 3


def disc(r: int) -> np.ndarray:
    yy, xx = np.mgrid[-r : r + 1, -r : r + 1]
    return (xx * xx + yy * yy) <= r * r


def dilate(mask: np.ndarray, se: np.ndarray) -> np.ndarray:
    r = se.shape[0] // 2
    # Edge padding, so an arm that runs off the tile stays full width instead of
    # being eroded into a taper at the one place it must not be.
    pad = np.pad(mask, r, mode="edge")
    out = np.zeros_like(mask)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if se[dy + r, dx + r]:
                out |= pad[r + dy : r + dy + TILE, r + dx : r + dx + TILE]
    return out


def erode(mask: np.ndarray, se: np.ndarray) -> np.ndarray:
    return ~dilate(~mask, se)


def canonical_shape(mask: int) -> np.ndarray:
    """The silhouette every piece of mask `mask` must have."""
    lo, hi = BAND
    shape = np.zeros((TILE, TILE), dtype=bool)
    if mask == 0:
        return shape
    shape[lo:hi, lo:hi] = True                       # the junction itself
    if mask & 1:
        shape[0:hi, lo:hi] = True                    # N
    if mask & 2:
        shape[lo:hi, lo:TILE] = True                 # E
    if mask & 4:
        shape[lo:TILE, lo:hi] = True                 # S
    if mask & 8:
        shape[lo:hi, 0:hi] = True                    # W
    # Opening rounds the outside of a bend, closing rounds the inside. Together
    # they turn a right-angled elbow into a road that actually curves.
    se = disc(ROUND)
    shape = dilate(erode(shape, se), se)
    shape = erode(dilate(shape, se), se)
    # A dead-end stub keeps its square cap; rounding one looks like a bullet.
    return shape


def collar_of(mask: int) -> np.ndarray:
    """The band at each connected edge that must be solid whatever the art did.

    This is the entire seam guarantee: two tiles meet only along their outermost
    few pixels, so forcing exactly those to the full band makes every join exact
    while leaving the rest of the road free to be as narrow and irregular as it
    was painted. Forcing the whole envelope instead - which is what the first
    version did - turns a road into a row of slabs.
    """
    lo, hi = BAND
    band = np.zeros((TILE, TILE), dtype=bool)
    if mask & 1:
        band[0:COLLAR, lo:hi] = True
    if mask & 2:
        band[lo:hi, TILE - COLLAR : TILE] = True
    if mask & 4:
        band[TILE - COLLAR : TILE, lo:hi] = True
    if mask & 8:
        band[lo:hi, 0:COLLAR] = True
    return band


def strip_bevel(rgb: np.ndarray) -> np.ndarray:
    """Crop away the tile's slab faces and rescale the clean interior back out.

    The generator draws a tile as a slab lit from above, so it carries a bright
    cut face along one edge and a shaded one along the opposite. That is right
    for a tile placed on its own and wrong for one laid edge to edge: the faces
    line up into a repeating bar at every join and the road reads as a ladder.

    The depth is measured, not assumed - at a 60-degree view the shaded south
    face runs five pixels deep where the lit north face is three, so a fixed
    strip either leaves a bar or eats road.

    Cropping rather than replicating the first clean row outward. Replicating
    was tried and drags the road's edge pixels sideways into the verge, which
    shows as vertical streaking down every straight. Cropping keeps the interior
    exactly as painted; the canonical clip fixes the width afterwards regardless.
    """
    out = rgb.astype(float)
    interior = np.median(out[10:22, 10:22].reshape(-1, 3), axis=0)

    def inset(view: np.ndarray, reverse: bool) -> int:
        order = range(TILE - 1, -1, -1) if reverse else range(TILE)
        for step, i in enumerate(order):
            if step > 6:
                break
            line = view[i, BAND[0] : BAND[1]].mean(0)
            if np.linalg.norm(line - interior) < 22.0:
                return step
        return 0

    rows = out
    cols = out.transpose(1, 0, 2)
    top, bottom = inset(rows, False), inset(rows, True)
    left, right = inset(cols, False), inset(cols, True)
    crop = rgb[top : TILE - bottom, left : TILE - right]
    if crop.shape[0] < 8 or crop.shape[1] < 8:
        return rgb
    return np.array(
        Image.fromarray(crop).resize((TILE, TILE), Image.NEAREST)
    )


def seamless_floor(rgb: np.ndarray) -> np.ndarray:
    """The region's floor, built to tile with itself exactly.

    The generator draws each tile as a lit slab, and the slab's cut faces do not
    tile: laid out they line up into pale bars straight across the battlefield.
    Cropping them off is what the road pieces do, but cropping a *floor* also
    moves its edges, so a cropped tile no longer matches its own neighbour - the
    bars just move.

    Mirroring solves both at once. The bevel-free interior is reflected into four
    quadrants, so the left edge is the right edge and the top is the bottom by
    construction: it cannot seam, whatever the generator drew. The cost is a
    symmetry, which at twelve world units per texel and under the day/night grade
    is far less visible than a bar across the map.

    A mosaic of several variants was tried first and is the trap here: different
    variants share no edges, so it seams *more*, not less.
    """
    inset = 6
    core = rgb[inset:-inset, inset:-inset]
    top = np.concatenate([core, core[:, ::-1]], axis=1)
    return np.concatenate([top, top[::-1, :]], axis=0).astype(np.uint8)


def road_seed(envelope: np.ndarray) -> np.ndarray:
    """The part of the envelope that is unambiguously road surface.

    Deliberately geometric rather than a colour test. Classifying road by colour
    works for a tan road on dark marsh and falls apart on a grey road over white
    snow, where the two are a few values apart - and it fails *noisily*, giving a
    ragged silhouette that reads as damage rather than as a road. The middle of
    the envelope is road by construction, whatever the region looks like.
    """
    return erode(envelope, disc(4))


def fill_from_road(rgb: np.ndarray, road: np.ndarray, _want: np.ndarray) -> np.ndarray:
    """Push road colour outward into any part of the clip the art did not cover.

    The generator draws its road a little narrower than the canonical band, so
    without this the widened edge would be filled with ground colour and every
    join would show a pale collar.
    """
    out = rgb.copy()
    seen = road.copy()
    queue = deque(zip(*np.nonzero(road)))
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < TILE and 0 <= nx < TILE and not seen[ny, nx]:
                seen[ny, nx] = True
                out[ny, nx] = out[y, x]
                queue.append((ny, nx))
    return out


def normalise(tiles: dict[int, np.ndarray], road_value: float = 1.0) -> None:
    """Force every piece onto one road surface, in place.

    A generated set is not internally consistent: the same road comes out warm
    tan on one tile and grey-blue on the next, and a few keep a dark slab outline
    the crop could not find because their centre is ground rather than road. Laid
    out, that reads as a road that changes material every few metres with a black
    line at each change - which is exactly what it is.

    Each pixel keeps its own brightness relative to its tile, and that deviation
    is re-applied to the set's median colour. Texture and wear survive; hue drift
    and stray outlines do not.

    `road_value` scales the surface afterwards. A generator asked for a trodden
    road through snow will happily draw one the same value as the snow, and a
    road you cannot pick out from the ground is not a road, it is a shape. A
    per-region knob rather than a fixed correction, because the marsh set needs
    none at all.
    """
    opaque = [t[..., :3][t[..., 3] > 128].astype(float) for t in tiles.values()]
    stacked = np.concatenate([o for o in opaque if len(o)])
    target = np.clip(np.median(stacked, axis=0) * road_value, 0, 255)
    spread = np.percentile(stacked.mean(1), [10, 90])

    for tile in tiles.values():
        mask = tile[..., 3] > 128
        if not mask.any():
            continue
        rgb = tile[..., :3].astype(float)
        lum = rgb.mean(2)
        # Clipped to the set's own range, which is what discards the outline: a
        # near-black row is far outside the spread of actual road.
        scaled = np.clip(lum, spread[0], spread[1]) - np.median(lum[mask])
        out = np.clip(target + scaled[..., None], 0, 255)
        tile[..., :3] = np.where(mask[..., None], out.round().astype(np.uint8), tile[..., :3])


def rotate_mask(mask: int, quarter_turns: int) -> int:
    """A quarter turn clockwise moves every edge round by one."""
    for _ in range(quarter_turns % 4):
        mask = ((mask << 1) | (mask >> 3)) & 15
    return mask


def main() -> int:
    if len(sys.argv) not in (4, 5):
        print(__doc__)
        return 2
    src_dir, rules_path, terrain = sys.argv[1], sys.argv[2], sys.argv[3]
    road_value = float(sys.argv[4]) if len(sys.argv) == 5 else 1.0
    out_dir = os.path.join("game", "art", "battlefield")

    rules: dict[str, int] = json.load(open(rules_path, encoding="utf-8"))
    by_mask: dict[int, str] = {}
    for name, mask in rules.items():
        by_mask.setdefault(int(mask), name)

    # Recover any mask the set does not contain by turning one that has the same
    # shape. Every mask is some rotation of one that is present.
    plan: dict[int, tuple[str, int]] = {m: (n, 0) for m, n in by_mask.items()}
    for mask in range(16):
        if mask in plan:
            continue
        for turns in (1, 2, 3):
            source = rotate_mask(mask, -turns % 4)
            if source in by_mask:
                plan[mask] = (by_mask[source], turns)
                break

    written = 0
    built: dict[int, np.ndarray] = {}
    for mask in range(16):
        if mask not in plan:
            print(f"  mask {mask:2d}: NO SOURCE")
            continue
        name, turns = plan[mask]
        rgb = np.array(Image.open(os.path.join(src_dir, f"{name}.png")).convert("RGB"))
        if turns:
            rgb = np.rot90(rgb, -turns).copy()
        rgb = strip_bevel(rgb)

        envelope = canonical_shape(mask)
        seed = road_seed(envelope)
        if seed.any():
            # Grow the road's own surface out to the envelope edge. This is what
            # removes the generator's verge painting and the last of its slab
            # outline in one step: everything outside the seed is repainted from
            # the nearest road pixel, so the piece is road all the way to its
            # border and cannot show a rim of ground at a join.
            rgb = fill_from_road(rgb, seed, envelope)

        out = np.zeros((TILE, TILE, 4), dtype=np.uint8)
        out[..., :3] = rgb
        out[..., 3] = np.where(envelope, 255, 0)
        built[mask] = out
        print(f"  mask {mask:2d} <- {name}{f' turned {turns}' if turns else ''}")

    # The plain-ground tile is the region's floor. Taken from the same set as
    # the road on purpose: one generation, one palette, one pixel density, and
    # no chance of the ground and the road looking like different games.
    floor_name = by_mask.get(0)
    if floor_name is not None:
        floor = seamless_floor(
            np.array(Image.open(os.path.join(src_dir, f"{floor_name}.png")).convert("RGB")))
        floor_path = os.path.join("game", "art", "terrain", f"terrain_{terrain}.png")
        Image.fromarray(floor).save(floor_path)
        print(f"  ground   -> {floor_path} {floor.shape[1]}x{floor.shape[0]}")

    normalise(built, road_value)
    for mask, out in built.items():
        Image.fromarray(out).save(
            os.path.join(out_dir, f"path_{terrain}_{mask:02d}.png"))
        written += 1

    print(f"{written}/16 written to {out_dir}/path_{terrain}_NN.png")
    return 0 if written == 16 else 1


if __name__ == "__main__":
    raise SystemExit(main())
