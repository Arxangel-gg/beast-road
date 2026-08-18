extends SceneTree

## Renders the battlefield grid to a PNG so the layout can be looked at.
## Diagnostic only, never a gate.
##
##   godot --headless --path game --script res://tools/grid_map.gd

func _init() -> void:
	var grid := BattleGrid.new()
	var scale: int = 12
	var img := Image.create(BattleGrid.SIZE * scale, BattleGrid.SIZE * scale, false, Image.FORMAT_RGBA8)
	var colours: Dictionary = {
		BattleGrid.Cell.OPEN: Color("1e2e33"),
		BattleGrid.Cell.ROAD: Color("8a6b3f"),
		BattleGrid.Cell.TOWN: Color("d9cdb8"),
		BattleGrid.Cell.BORDER: Color("0b1416"),
	}
	for ty: int in BattleGrid.SIZE:
		for tx: int in BattleGrid.SIZE:
			var c: Color = colours[grid.cell_at(Vector2i(tx, ty))]
			for py: int in scale:
				for px: int in scale:
					var edge: bool = px == 0 or py == 0
					img.set_pixel(tx * scale + px, ty * scale + py, c.darkened(0.25) if edge else c)
	for lane: int in Balance.LANE_COUNT:
		var t: Vector2i = BattleGrid.world_to_tile(grid.lane_pocket_centre(lane))
		for py: int in scale:
			for px: int in scale:
				img.set_pixel(t.x * scale + px, t.y * scale + py, Color("e8a33d"))
	var out: String = "user://grid_map.png"
	img.save_png(out)
	print("[grid] map -> %s" % ProjectSettings.globalize_path(out))
	quit(0)
