extends Node

## Trees grow outside the field, in different amounts per region, and nowhere
## near a lane mouth.
##
## Every one of those is a rule that fails silently. A tree inside the grid hides
## a lane or covers a tower slot and looks like a bug in the map; a tree across a
## spawn mouth hides an arrival, which looks like the wave cheating; and identical
## density everywhere means the regions stopped being different places without
## anything erroring.

var _failures: int = 0


func _ready() -> void:
	var counts: Dictionary = {}
	for region: String in ["jungle", "desert", "snow"]:
		RunState.terrain_id = region
		var grid := BattleGrid.new()
		# `lane_paths` is filled in by the battlefield, not by the grid, so the
		# mouths are synthesised here from the lane directions the grid itself
		# defines. Without them the clearance rule below would pass by having
		# nothing to check, which is the worst way for a gate to be green.
		var lanes: Array = []
		var edge: float = float(BattleGrid.SIZE) * BattleGrid.TILE * 0.5
		for lane: int in 4:
			var mouth: Vector2 = BattleGrid.lane_vector(lane) * edge
			lanes.append(PackedVector2Array([mouth, mouth * 0.5]))
		grid.lane_paths = lanes
		var trees := Treeline.new()
		trees.grid = grid
		add_child(trees)
		trees.scatter()
		counts[region] = trees.count()
		_check(trees.count() > 0, "%s must grow trees, got none" % region)

		# **Not one inside the grid.** This is the rule the whole system exists
		# to keep, so it is checked on every tree rather than sampled.
		var inside: int = 0
		var near_mouth: int = 0
		var mouths: Array = []
		for path: Variant in grid.lane_paths:
			var points: PackedVector2Array = path as PackedVector2Array
			if points.size() > 0:
				mouths.append(points[0])
		for child: Node in trees.get_children():
			var tree := child as Sprite2D
			if tree == null:
				continue
			if BattleGrid.in_bounds(BattleGrid.world_to_tile(tree.position)):
				inside += 1
			for mouth: Variant in mouths:
				var outward: Vector2 = (mouth as Vector2).normalized()
				var along: float = tree.position.dot(outward)
				if along <= 0.0:
					continue
				if (tree.position - outward * along).length() < Treeline.LANE_CLEARANCE:
					near_mouth += 1
					break
		_check(inside == 0,
			"%s planted %d tree(s) inside the build grid" % [region, inside])
		_check(near_mouth == 0,
			"%s planted %d tree(s) across a lane mouth" % [region, near_mouth])

		# Anchored at the trunk, or the sorting is measured from the wrong pixel.
		for child: Node in trees.get_children():
			var tree := child as Sprite2D
			if tree != null and tree.texture != null:
				_check(tree.offset.y < 0.0,
					"a tree must be anchored at its trunk, offset was %.1f"
						% tree.offset.y)
				_check(tree.scale.y >= 0.85,
					"the perimeter trees must remain large enough to frame the map")
				break
		trees.queue_free()

	# The regions have to read differently, or they are one region with three
	# palettes. Jungle closes in; the waste is a scattering of survivors.
	_check(int(counts["jungle"]) > int(counts["desert"]),
		"a jungle must be denser than a desert, got %d against %d"
			% [int(counts["jungle"]), int(counts["desert"])])
	_check(int(counts["snow"]) > int(counts["desert"]),
		"a snowfield must be denser than a desert, got %d against %d"
			% [int(counts["snow"]), int(counts["desert"])])
	print("[treeline] jungle %d  snow %d  desert %d" % [
		int(counts["jungle"]), int(counts["snow"]), int(counts["desert"])])

	if _failures == 0:
		print("[treeline] PASS - trees outside the field, clear of the mouths, "
			+ "and each region its own density")
	else:
		printerr("[treeline] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[treeline] FAIL: %s" % why)
