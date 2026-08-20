# Structure art pipeline

This is the reproducible production contract for Beast Road's PixelLab towers
and town buildings. The exact runtime and manifest paths remain derived from the
resource `id`; an art replacement never needs a code or data edit.

## Package contract

- Canvas: 192×192 RGBA with genuine transparency.
- View and light: the existing three-quarter-above gameplay view and the base
  sprite's upper-left key light.
- Loop: four runtime poses at `Balance.STRUCTURE_IDLE_FRAME_RATE`.
- Paths: the canonical base plus `_idle_01.png`, `_idle_02.png`, and
  `_idle_03.png` immediately before the extension.
- Buildings: tier one uses the canonical base. Tiers two and three use
  `_tier_02.png` and `_tier_03.png`, with the same idle suffix convention.
- Anchor: the alpha silhouette's bottom-centre may move at most two pixels.
- Architecture stays rigid. Motion belongs to flame, smoke, steam, water,
  crystals, cloth, rotors, glow, or another clearly authored moving component.

`res://tools/structure_art_check.tscn` enforces completeness, canvas size,
alpha, anchor stability, and bounded silhouette-width drift for all 53 packages.
The release workflow runs it after the generic asset report.

## PixelLab generation recipe

Use the canonical 192×192 transparent sprite as both the first and last frame,
with `frame_count=4` and background removal enabled. PixelLab returns the source
pose, interpolation poses, and the pinned terminal source pose. Ship the source
plus the first three generated poses; the duplicate terminal image exists only
to close the generation.

Idle prompt template:

> A seamless closed idle cycle: [one restrained material or mechanism motion],
> then return exactly to the starting pose. Keep the building/tower architecture,
> perspective, footprint, ground anchor, palette, lighting, outline, transparency,
> and silhouette rigid and unchanged. No camera motion, orbiting effects, added
> objects, external rings, zoom, translation, rotation of the whole structure,
> or background.

Tier-edit prompt template:

> Upgrade this exact [building] into a clearly readable tier [2/3] while
> preserving its identity, 192×192 transparent canvas, three-quarter-above
> perspective, bottom-centre ground anchor, palette, lighting, outline language,
> and gameplay-scale readability. Add [specific permanent architectural growth].
> Do not add a background, crop, zoom, move the footprint, or merely scale the
> existing sprite.

Each prompt should name only the part intended to move or grow. Negative
constraints are specific to rejected artifacts, not a generic wall of style
terms.

## Review and correction

Review every pose at native resolution and as a four-frame loop. Reject added
halos, detached particles, melted walls, changing footprints, camera motion, or
motion too small to survive gameplay zoom. The source and terminal pose must
match exactly by construction.

PixelLab remains the author of the animation frames. When it adds motion outside
an explicitly approved component, `tools/lock_animation_region.py` restores the
canonical base outside one or more `--allow X,Y,W,H` rectangles. When the whole
generated sprite drifts on an otherwise correct canvas, `--align-ground`
translates its pixels so the alpha-foot matches the source. Both operations are
deterministic and must be followed by a Godot reimport and the structure gate.

Every added PNG is listed in `docs/ASSET_MANIFEST.md` in the same change, and a
release must report the same number of manifest rows and files with zero
placeholder markers.
