class_name DungeonTiles
extends TileMapLayer

## The floor and the rock of a rift, drawn from one corner-indexed Wang sheet
## (2026-09-14).
##
## The first cut drew a maze as the raid draws a camp: the rock was the
## region's ground on a raised plate with a line round it, which reads as a
## paint mark on flat earth rather than as a wall you are walking between.
## This is the same trick the ponds use (`PondTiles`), the other way round:
## there the water is what was *added* to the ground, here the floor is what
## was *cut out* of the rock, so the rock is the upper terrain and corner
## value 1.
##
## One `TileMapLayer` on a dual grid: cell (i, j) sits over the corner shared
## by tiles (i-1, j-1), (i, j-1), (i-1, j) and (i, j), and its tile is chosen
## by which of those four are rock - so a wall's edge is the sheet's own
## transition rather than a square, and the rock continues past the layout's
## rim (`PAD`) to the edge of the arena's ground, where the dark begins.
##
## Nothing reads it. Collision is still the arena's `Cliffs` body, and
## `can_step` still answers from the layout: this is what the place looks like,
## never what it is.

const TILE: int = 64
const SHEET_ACROSS: int = 4
const ART_FORMAT: String = "res://art/raid/dungeon_tiles_%s.png"
## Cells of solid rock laid beyond the layout's own ring: far enough that the
## camera at play zoom, standing in a corner room, never sees where the rock
## stops. The fog's rim shades it to near-black long before that, so what
## this buys is that the shade has rock under it rather than a hard edge.
const PAD: int = 24

## One TileSet per sheet, shared by every stage that uses it.
static var _sets: Dictionary = {}


static func art_for(kind: int) -> String:
	return ART_FORMAT % ("rift" if kind == RiftArena.Kind.RIFT else "dungeon")


## A TileSet over the canonical 4x4 sheet.
static func tileset_for(texture: Texture2D) -> TileSet:
	var key: String = texture.resource_path
	if not key.is_empty() and _sets.has(key):
		return _sets[key] as TileSet
	var set := TileSet.new()
	set.tile_size = Vector2i(TILE, TILE)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	for index: int in 16:
		source.create_tile(atlas_coords(index))
	set.add_source(source, 0)
	if not key.is_empty():
		_sets[key] = set
	return set


## Where a corner-indexed tile sits on the canonical sheet.
static func atlas_coords(index: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(index % SHEET_ACROSS, index / SHEET_ACROSS)


static func tile_index(nw: bool, ne: bool, sw: bool, se: bool) -> int:
	return (8 if nw else 0) + (4 if ne else 0) + (2 if sw else 0) + (1 if se else 0)


## Rock: a wall, or anything past the rim.
static func rock_at(layout: RaidLayout, tile: Vector2i) -> bool:
	return not RaidLayout.in_bounds(tile) or layout.cell_at(tile) == RaidLayout.Cell.WALL


## The corner index of cell (i, j) of the dual grid.
static func index_at(layout: RaidLayout, cell: Vector2i) -> int:
	return tile_index(
		rock_at(layout, cell + Vector2i(-1, -1)), rock_at(layout, cell + Vector2i(0, -1)),
		rock_at(layout, cell + Vector2i(-1, 0)), rock_at(layout, cell))


## Lays the whole floor and its rock for `layout` from `texture`.
func lay(layout: RaidLayout, texture: Texture2D) -> void:
	tile_set = tileset_for(texture)
	texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	if not is_in_group(Graphics.FILTER_GROUP):
		add_to_group(Graphics.FILTER_GROUP)
	y_sort_enabled = false
	# Cell (i, j)'s top-left corner is a whole tile up and left of tile (i, j)'s
	# centre, which puts the cell's own centre on the corner it describes.
	position = Vector2.ONE * (-RaidLayout.HALF_EXTENT - RaidLayout.TILE * 0.5)
	clear()
	if layout == null:
		return
	for j: int in range(-PAD, RaidLayout.SIZE + PAD + 1):
		for i: int in range(-PAD, RaidLayout.SIZE + PAD + 1):
			var cell := Vector2i(i, j)
			set_cell(cell, 0, atlas_coords(index_at(layout, cell)))
