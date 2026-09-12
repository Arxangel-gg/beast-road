extends SceneTree

## Renders the battlefield grid to a PNG so the layout can be looked at.
## Diagnostic only, never a gate.
##
##   godot --headless --path game --script res://tools/grid_map.gd

func _init() -> void:
	var grid := BattleGrid.new()
	var scale: int = 8
	var img := Image.create(BattleGrid.SIZE * scale, BattleGrid.SIZE * scale, false, Image.FORMAT_RGBA8)
	var colours: Dictionary = {
		BattleGrid.Cell.OPEN: Color("1e2e33"),
		BattleGrid.Cell.ROAD: Color("8a6b3f"),
		BattleGrid.Cell.TOWN: Color("d9cdb8"),
		BattleGrid.Cell.BORDER: Color("0b1416"),
		BattleGrid.Cell.CAMP: Color("6b2f2f"),
	}
	for ty: int in BattleGrid.SIZE:
		for tx: int in BattleGrid.SIZE:
			var c: Color = colours[grid.cell_at(Vector2i(tx, ty))]
			for py: int in scale:
				for px: int in scale:
					var edge: bool = px == 0 or py == 0
					img.set_pixel(tx * scale + px, ty * scale + py, c.darkened(0.25) if edge else c)
	for node: Vector2i in grid.lattice_nodes():
		for py: int in range(2, scale - 2):
			for px: int in range(2, scale - 2):
				img.set_pixel(node.x * scale + px, node.y * scale + py, Color("e8e8e8"))
	for lane: int in Balance.LANE_COUNT:
		for spawn: Variant in grid.active_spawn_points(lane):
			_dot(img, scale, BattleGrid.world_to_tile(spawn as Vector2), Color("4fe86a"))
		for spawn: Variant in grid.far_spawn_points[lane]:
			_dot(img, scale, BattleGrid.world_to_tile(spawn as Vector2), Color("4fc0e8"))
		var t: Vector2i = BattleGrid.world_to_tile(grid.lane_pocket_centre(lane))
		_dot(img, scale, t, Color("e8a33d"))
		for pair: Variant in [grid.barriers[lane]]:
			for barrier: Dictionary in (pair as Array):
				_dot(img, scale, BattleGrid.world_to_tile(barrier["at"] as Vector2), Color("ff4fd8"))
	var out: String = "user://grid_map.png"
	img.save_png(out)
	print("[grid] map -> %s" % ProjectSettings.globalize_path(out))
	print("[grid] lattice nodes %d, camps %d" % [grid.lattice_nodes().size(), grid.camps.size()])
	for lane: int in Balance.LANE_COUNT:
		print("[grid] lane %d: %d near routes, %d far routes, spawn %s, far %s" % [lane,
			(grid.routes[lane] as Array).size(), (grid.far_routes[lane] as Array).size(),
			grid.spawn_points[lane], grid.far_spawn_points[lane]])
	quit(0)


func _dot(img: Image, scale: int, t: Vector2i, colour: Color) -> void:
	if not BattleGrid.in_bounds(t):
		t = Vector2i(clampi(t.x, 0, BattleGrid.SIZE - 1), clampi(t.y, 0, BattleGrid.SIZE - 1))
	for py: int in scale:
		for px: int in scale:
			img.set_pixel(t.x * scale + px, t.y * scale + py, colour)
