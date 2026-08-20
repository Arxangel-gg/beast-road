class_name RaidTerrain
extends Node2D

## Draws a raid camp's elevation.
##
## One node with one `_draw`, rather than a few hundred `ColorRect`s. A ColorRect
## is a Control and does not belong in a world-space tree at all; several hundred
## of them is also several hundred nodes rebuilt every raid, which is exactly the
## kind of growth `perf_check` exists to catch.
##
## Flat plates with a hard lit edge, not a tileset. The camp is regenerated every
## raid and its silhouette is what a player reads to decide where to stand — a
## tiled surface at this scale competes with that reading, while the regional
## ground texture underneath already carries the material. What the shape needs
## is legibility: higher is lighter, and every cliff has an edge you can see.

var layout: RaidLayout = null


func _draw() -> void:
	if layout == null:
		return
	var size := Vector2(RaidLayout.TILE, RaidLayout.TILE)
	var half: Vector2 = size * 0.5

	for level: int in range(1, RaidLayout.MAX_LEVEL + 1):
		var tint: Color = Balance.RAID_LEVEL_TINT[
			mini(level, Balance.RAID_LEVEL_TINT.size() - 1)]
		for y: int in RaidLayout.SIZE:
			for x: int in RaidLayout.SIZE:
				var tile := Vector2i(x, y)
				if layout.level_at(tile) != level:
					continue
				var at: Vector2 = RaidLayout.tile_to_world(tile) - half
				draw_rect(Rect2(at, size), tint)

	# The way up, in its own colour. Without this a ramp is an invisible gap in a
	# cliff and the player finds it by walking into the wall until they do not.
	for y: int in RaidLayout.SIZE:
		for x: int in RaidLayout.SIZE:
			var tile := Vector2i(x, y)
			if layout.cell_at(tile) != RaidLayout.Cell.RAMP:
				continue
			var at: Vector2 = RaidLayout.tile_to_world(tile) - half
			draw_rect(Rect2(at, size), Balance.RAID_RAMP_TINT)

	# Cliff edges last, over the plates, so the outline reads unbroken.
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
				var lit: bool = layout.cell_at(tile) == RaidLayout.Cell.RAMP \
					or layout.cell_at(next) == RaidLayout.Cell.RAMP
				draw_line(centre - along, centre + along,
					Balance.RAID_RAMP_TINT if lit else Balance.RAID_CLIFF_EDGE,
					Balance.RAID_CLIFF_EDGE_WIDTH)
