extends SceneTree

## Every camp a raid can generate must be playable.
##
##   godot --headless --path game --script res://tools/raid_layout_check.gd
##
## Procedural terrain fails differently from authored terrain: it is right on the
## seed you looked at and wrong on one you have not seen yet. So this builds a
## few hundred camps and asserts the properties that make one playable, rather
## than eyeballing a screenshot of the first.
##
## Pure geometry, so it needs no scene, no autoload and no viewport.

const SEEDS: int = 300

var _failures: PackedStringArray = []


func _init() -> void:
	var stats: Dictionary = {"islands": 0, "ramps": 0, "chests": 0, "locked": 0,
		"high_chests": 0, "raised": 0}

	for seed: int in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed * 7919 + 13
		var layout := RaidLayout.new(rng)

		# Nothing may be stranded. This is the property that decides whether a
		# camp is playable at all: an island the hero cannot climb is loot they
		# can see and never take, which reads as a bug however pretty it is.
		var reached: Dictionary = {}
		for tile: Vector2i in layout.reachable_tiles():
			reached[tile] = true
		var stranded: int = 0
		var raised: int = 0
		for y: int in RaidLayout.SIZE:
			for x: int in RaidLayout.SIZE:
				var tile := Vector2i(x, y)
				if layout.cell_at(tile) == RaidLayout.Cell.WALL:
					continue
				if layout.level_at(tile) > 0:
					raised += 1
				if not reached.has(tile):
					stranded += 1
		if stranded > 0:
			_fail(seed, "%d tiles are unreachable" % stranded)
		stats["raised"] += raised

		# The arrival point has to be standable, and clear.
		var centre := Vector2i(RaidLayout.SIZE / 2, RaidLayout.SIZE / 2)
		if layout.cell_at(centre) == RaidLayout.Cell.WALL:
			_fail(seed, "the arrival point is inside a wall")
		if layout.level_at(centre) != 0:
			_fail(seed, "the arrival point is on raised ground")

		# A camp with no relief is the old circle with extra steps.
		if raised < 40:
			_fail(seed, "only %d raised tiles - the camp is effectively flat" % raised)

		var ramps: int = 0
		for y: int in RaidLayout.SIZE:
			for x: int in RaidLayout.SIZE:
				if layout.cell_at(Vector2i(x, y)) == RaidLayout.Cell.RAMP:
					ramps += 1
		stats["ramps"] += ramps

		# Treasure has to exist, be reachable, and every locked chest needs its
		# key. A locked chest with no key is a promise the camp cannot keep.
		if layout.chests.is_empty():
			_fail(seed, "no chests")
		var locked: int = 0
		for index: int in layout.chests.size():
			var tile: Vector2i = RaidLayout.world_to_tile(layout.chests[index])
			if not reached.has(tile):
				_fail(seed, "chest %d is unreachable" % index)
			if layout.locked_chests[index]:
				locked += 1
				if layout.level_at(tile) > 0:
					stats["high_chests"] += 1
		if locked != layout.keys.size():
			_fail(seed, "%d locked chests but %d keys" % [locked, layout.keys.size()])
		for index: int in layout.keys.size():
			if not reached.has(RaidLayout.world_to_tile(layout.keys[index])):
				_fail(seed, "key %d is unreachable" % index)
		stats["chests"] += layout.chests.size()
		stats["locked"] += locked

	var runs: float = float(SEEDS)
	print("[raid] %d camps: %.1f ramps, %.1f chests (%.1f locked, %.0f%% of those high), %.0f raised tiles"
		% [SEEDS, stats["ramps"] / runs, stats["chests"] / runs, stats["locked"] / runs,
			(float(stats["high_chests"]) / maxf(float(stats["locked"]), 1.0)) * 100.0,
			stats["raised"] / runs])
	for problem: String in _failures:
		push_error("[raid] " + problem)
	print("[raid] %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)


func _fail(seed: int, message: String) -> void:
	if _failures.size() < 12:
		_failures.append("seed %d: %s" % [seed, message])
