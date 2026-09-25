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

## **The face of the ledge, and the steps up it** (owner brief, 2026-09-13:
## "raids need an overhaul, especially the stairs and upper levels ... an
## elevation tileset for this so it looks correct").
##
## The camp had elevation, ramps, a stepping rule and cliff collision from the
## day it was built, and every one of those is real. What it did not have is any
## way to *see* the height: a raised plate was the region's ground with a
## two-pixel line around it, which reads as a paint mark on flat earth rather
## than as a ledge you are standing on top of.
##
## So the south edge of every ledge gets a face - the exposed earth bank under
## it, with grass overhanging - and every ramp gets steps cut into that face.
## South only, and that is not a shortcut: the camera looks down and slightly
## along, so the south side is the only face a player can see. A north face
## would be drawn behind the plate that owns it.
##
## Baked into the same texture as the plates rather than drawn as sprites,
## because it is the same argument the plates were baked under - a few hundred
## nodes rebuilt every raid is the growth `perf_check` exists to catch.
const FACE_ART: String = "res://art/raid/raid_cliff_face.png"
## **The flights, and they are the Hold's.**
##
## Owner, 2026-09-17: *"the stair solution should also apply to dungeons with
## the correct adaptations for each environment"*, and separately that the old
## ones *"still suck"*. `art/raid/raid_stairs.png` was a 128x64 strip that every
## camp and every rift shared and that the Hold was borrowing; the two pieces
## here are the same staircases the Hold climbs.
##
## **The adaptation is the material rather than a second painting.** Earth for a
## camp, which is cut into a hillside under the sky, and cut stone for a rift,
## which is not. Each is then tinted to its own region exactly as the bank
## already is, so ten regions cost two files rather than twenty.
const STAIR_ART: String = "res://art/terrain/stair_earth_north.png"
const DEEP_STAIR_ART: String = "res://art/terrain/stair_stone_north.png"
## How tall the face is, as a share of a tile. Two thirds reads as a step up a
## person's height without the face swallowing the ground below it.
const FACE_SHARE: float = 0.72
## How much darker a face is than the ground it belongs to. A face is the side
## the sun is not on, and a bank as bright as the plate above it reads as a
## second floor rather than as a drop.
const FACE_SHADE: float = 0.82

var layout: RaidLayout = null

## Whether this arena is under the ground, which decides which stone the flights
## are cut from: earth under the sky, cut stone below it.
##
## **It lives here as well as on `_Faces` because the arena can only reach this
## node.** `raid_arena.gd` sets `terrain.underground` before the tree is
## entered; without this declaration GDScript writes a dynamic property on the
## outer node, nothing errors, and the inner class keeps its own default - which
## is exactly what happened, so every rift was cutting earth steps into rock.
var underground: bool = false

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
	# **The faces, drawn rather than baked.** The first cut of this blended them
	# into the plate texture, which is baked at half a texel per world unit -
	# so a bank authored 64 pixels tall was squashed into 21 and then scaled
	# back up on screen. It read as a coloured stripe, which is exactly the
	# "low res from being scaled up" the owner reported about the foliage.
	#
	# One `Node2D` and one `_draw`: a few hundred textured quads on one canvas
	# item, rather than a few hundred nodes, which is the same argument the
	# plates were baked under.
	var faces := _Faces.new()
	faces.layout = layout
	faces.underground = underground
	add_child(faces)

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


## The exposed bank under every south-facing ledge, and the steps cut into it.
##
## South only, and that is not a shortcut: the camera looks down and slightly
## along, so the south side is the only face a player can see. A north face
## would be drawn behind the plate that owns it.
##
## Ascending by level, so a second ledge's face falls over the first one's
## surface exactly as it would on the ground.
class _Faces extends Node2D:
	var layout: RaidLayout = null
	## Whether this arena is under the ground, which decides which stone the
	## flights are cut from. Set before the node enters the tree.
	var underground: bool = false
	var _bank: Texture2D = null
	var _steps: Texture2D = null

	func _ready() -> void:
		if ResourceLoader.exists(FACE_ART):
			_bank = load(FACE_ART) as Texture2D
		var flight: String = DEEP_STAIR_ART if underground else STAIR_ART
		if ResourceLoader.exists(flight):
			_steps = load(flight) as Texture2D
		texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
		add_to_group(Graphics.FILTER_GROUP)
		# **Tinted to the region it is cut out of.** One bank is authored and
		# ten regions use it, so a Saltpan ledge would otherwise be the same
		# brown earth as a Rustwood one - and a snow camp would have a summer
		# bank in it. The region's own mean colour is the tint, darkened,
		# because a face is the side the sun is not on.
		modulate = _regional_tint()


	## The average colour of this region's ground, lifted so the bank keeps its
	## own light and shade rather than being flattened to one hue.
	func _regional_tint() -> Color:
		var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
		if terrain == null or not ResourceLoader.exists(terrain.get_sprite_path()):
			return Color(FACE_SHADE, FACE_SHADE, FACE_SHADE)
		var texture: Texture2D = load(terrain.get_sprite_path()) as Texture2D
		if texture == null:
			return Color(FACE_SHADE, FACE_SHADE, FACE_SHADE)
		var image: Image = texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		# A sixteenth of a side is plenty for a mean and costs nothing; the
		# whole point is the hue, not the detail.
		image.resize(8, 8, Image.INTERPOLATE_BILINEAR)
		var total := Color(0.0, 0.0, 0.0)
		for y: int in 8:
			for x: int in 8:
				total += image.get_pixel(x, y)
		var mean: Color = total / 64.0
		# Normalised to its own brightness first, so a dark region does not
		# black the bank out and a bright one does not wash it white.
		var lift: float = maxf(maxf(mean.r, maxf(mean.g, mean.b)), 0.08)
		return Color(mean.r / lift, mean.g / lift, mean.b / lift) * FACE_SHADE

	func _draw() -> void:
		if layout == null or _bank == null:
			return
		var tall: float = RaidLayout.TILE * FACE_SHARE
		var wide: float = float(_bank.get_width()) * 0.5
		var high: float = float(_bank.get_height())
		for level: int in range(1, RaidLayout.MAX_LEVEL + 1):
			for y: int in RaidLayout.SIZE:
				for x: int in RaidLayout.SIZE:
					var tile := Vector2i(x, y)
					if layout.level_at(tile) != level:
						continue
					var below := Vector2i(x, y + 1)
					# The rim of the map counts as lower ground: a ledge that
					# runs off the edge still has a face, or the camp ends in a
					# cut through solid earth.
					var lower: int = layout.level_at(below) \
						if RaidLayout.in_bounds(below) else 0
					if lower >= level:
						continue
					var top_left: Vector2 = RaidLayout.tile_to_world(tile) \
						+ Vector2(-RaidLayout.TILE, RaidLayout.TILE) * 0.5
					var into := Rect2(top_left, Vector2(RaidLayout.TILE, tall))
					if layout.cell_at(tile) == RaidLayout.Cell.RAMP and _steps != null:
						# **Up over the lip as well as down the face.** The old
						# strip was drawn into the face alone, so a ramp was a
						# band of steps with the ledge's own ground cut off
						# square above it. A flight covers the tile it starts on
						# and the rise it crosses, which is what makes it read as
						# climbing rather than as a texture on a wall.
						var climb := Rect2(into.position.x,
							into.position.y - RaidLayout.TILE,
							into.size.x, into.size.y + RaidLayout.TILE)
						draw_texture_rect_region(_steps, climb,
							Rect2(0.0, 0.0, float(_steps.get_width()),
								float(_steps.get_height())))
					else:
						# Alternating halves of a two-tile band, so a long ledge
						# is not one slice repeated forty times.
						draw_texture_rect_region(_bank, into,
							Rect2(float(x % 2) * wide, 0.0, wide, high))
