class_name RaidTerrain
extends Node2D

## Draws a raid camp's elevation as textured ground with cut cliff edges.
##
## One node baking one texture, rather than a few hundred `ColorRect`s. A
## ColorRect is a Control and does not belong in a world-space tree at all;
## several hundred of them is also several hundred nodes rebuilt every raid,
## which is the kind of growth `perf_check` exists to catch.
##
## ## Textured, not tinted
##
## The first version drew flat tinted plates. It was legible and it looked like
## programmer art, which is a fair trade for a prototype and not for a release.
##
## The raised ground is drawn with the region's cohesive terrain painting. The
## material is sampled in world order across the whole bake, so a raid island
## reads as one landform rather than repeating a conspicuous patch per cell.
##
## Legibility then comes from the **cliff line** drawn over the top rather than
## from a colour difference, which is the stronger cue anyway: an edge reads at
## any brightness, and the camp is often played at night.

## World units per baked texel. Matches the ground bake, so the island surface
## and the floor under it have the same grain.
const BAKE_PPU: float = 0.5

var layout: RaidLayout = null

var _surface: Sprite2D
var _edges: Node2D


func _ready() -> void:
	if layout == null:
		return
	_surface = Sprite2D.new()
	_surface.texture = _bake()
	_surface.centered = true
	_surface.scale = Vector2.ONE / BAKE_PPU
	_surface.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_surface.add_to_group(Graphics.FILTER_GROUP)
	add_child(_surface)

	# Edges are drawn rather than baked: they are one pixel wide at bake scale
	# and would disappear into the texture, and they have to sit crisply over the
	# surface at whatever zoom the camera is at.
	_edges = _EdgeLines.new()
	(_edges as _EdgeLines).layout = layout
	add_child(_edges)


## Composites the raised ground into one texture.
func _bake() -> ImageTexture:
	var span: int = int(round(RaidLayout.TILE * BAKE_PPU))
	var side: int = RaidLayout.SIZE * span
	var canvas: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	var material: Image = _regional_material(side)

	for level: int in range(1, RaidLayout.MAX_LEVEL + 1):
		for y: int in RaidLayout.SIZE:
			for x: int in RaidLayout.SIZE:
				var tile := Vector2i(x, y)
				if layout.level_at(tile) < level:
					continue
				var at := Vector2i(x * span, y * span)
				if material != null:
					canvas.blend_rect(material, Rect2i(at, Vector2i(span, span)), at)
				else:
					# No art for the region: fall back to the tint, so a camp is
					# still readable rather than invisible.
					var flat: Image = Image.create_empty(span, span, false,
						Image.FORMAT_RGBA8)
					flat.fill(Balance.RAID_LEVEL_TINT[
						mini(level, Balance.RAID_LEVEL_TINT.size() - 1)])
					canvas.blend_rect(flat, Rect2i(Vector2i.ZERO, flat.get_size()), at)

				# Each tier above the first is lightened a touch, so two stacked
				# plates of the same material still read as two.
				if level > 1:
					var lift: Image = Image.create_empty(span, span, false,
						Image.FORMAT_RGBA8)
					lift.fill(Balance.RAID_TIER_LIFT)
					canvas.blend_rect(lift, Rect2i(Vector2i.ZERO, lift.get_size()), at)

	# Ramps in the region's own material but lifted warm, so the way up is
	# findable without a coloured square sitting on top of the texture.
	for y: int in RaidLayout.SIZE:
		for x: int in RaidLayout.SIZE:
			if layout.cell_at(Vector2i(x, y)) != RaidLayout.Cell.RAMP:
				continue
			var warm: Image = Image.create_empty(span, span, false, Image.FORMAT_RGBA8)
			warm.fill(Balance.RAID_RAMP_TINT)
			canvas.blend_rect(warm, Rect2i(Vector2i.ZERO, warm.get_size()),
				Vector2i(x * span, y * span))

	return ImageTexture.create_from_image(canvas)


## Repeats the region painting over the raid bake once. Individual raised cells
## then copy from their matching world position, preserving continuous detail.
func _regional_material(side: int) -> Image:
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain == null or not ResourceLoader.exists(terrain.get_sprite_path()):
		return null
	var texture: Texture2D = load(terrain.get_sprite_path()) as Texture2D
	if texture == null:
		return null
	var source: Image = texture.get_image()
	source.convert(Image.FORMAT_RGBA8)
	var tiled: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	for y: int in range(0, side, source.get_height()):
		for x: int in range(0, side, source.get_width()):
			var copy_size := Vector2i(
				mini(source.get_width(), side - x),
				mini(source.get_height(), side - y))
			tiled.blit_rect(source, Rect2i(Vector2i.ZERO, copy_size), Vector2i(x, y))
	return tiled


## The cliff outline, drawn over the baked surface.
class _EdgeLines extends Node2D:
	var layout: RaidLayout = null

	func _draw() -> void:
		if layout == null:
			return
		var half: float = RaidLayout.TILE * 0.5
		for y: int in RaidLayout.SIZE:
			for x: int in RaidLayout.SIZE:
				var tile := Vector2i(x, y)
				for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
					var next: Vector2i = tile + step
					if not RaidLayout.in_bounds(next):
						continue
					if layout.level_at(tile) == layout.level_at(next):
						continue
					var centre: Vector2 = (RaidLayout.tile_to_world(tile)
						+ RaidLayout.tile_to_world(next)) * 0.5
					var along := Vector2(float(step.y), float(step.x)) * half
					# A ramp's own edges are drawn warm, so the gap in the cliff
					# reads as a way through rather than as a missing line.
					var walkable: bool = layout.can_step(tile, next) \
						and layout.can_step(next, tile)
					draw_line(centre - along, centre + along,
						Balance.RAID_RAMP_TINT if walkable else Balance.RAID_CLIFF_EDGE,
						Balance.RAID_CLIFF_EDGE_WIDTH)
