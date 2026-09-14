extends Node

## The maze under a rift (2026-09-12): the floor `DungeonLayout` cuts, and
## what the arena does on it.
##
## What this holds, in the order it would go wrong:
##
## - the floor is one connected piece from the entry, with a vault at a real
##   walking depth, rooms on it, rock at every edge, and no open tile the
##   entry cannot reach - a maze that lies about its shape is worse than
##   less floor;
## - a rift is cut looser than a dungeon: a cavern with more floor;
## - bodies appear on open floor a walk away from the hero, never in a wall
##   and never underfoot, and are steered by the maze rather than through
##   rock: the hint from a far tile is a neighbouring open tile one step
##   nearer the hero, and the hero itself once adjacent;
## - the guardian wakes in the vault.
##
## The clock, the chest, the door and the reward are `rift_check`'s.

const ARENA: String = "res://scenes/rift/rift_arena.tscn"
const SEEDS: int = 12

var _failures: int = 0
var _checked: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260912)
	RunState.terrain_id = "jungle"
	RunState.act = Balance.DUNGEON_EVERY_ACTS
	RunState.phase = RunState.Phase.ROAD_BATTLE
	GameDirector.run_active = true
	await get_tree().process_frame

	_test_the_floor()
	await _test_the_arena()
	await _test_the_look()

	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Vfx.clear()
	for _f: int in 10:
		await get_tree().process_frame
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	GameDirector.run_active = false
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[dungeon] FAIL - %d of %d" % [_failures, _checked])
		get_tree().quit(1)
		return
	print("[dungeon] PASS - %d checks: the maze, the cavern, where bodies appear and how they come, and the look of the deep" % _checked)
	get_tree().quit(0)


func _test_the_floor() -> void:
	var maze_floor: int = 0
	var cavern_floor: int = 0
	for seed_index: int in SEEDS:
		for cavern: bool in [false, true]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + seed_index
			var layout := DungeonLayout.new(rng, cavern)
			var word: String = "cavern" if cavern else "maze"
			var open: Array[Vector2i] = layout.open_tiles()
			var reach: Dictionary = layout.distances_from(layout.entry)
			_check(layout.cell_at(layout.entry) == RaidLayout.Cell.OPEN, "%s %d: the entry is open" % [word, seed_index])
			_check(layout.cell_at(layout.deep) == RaidLayout.Cell.OPEN, "%s %d: the vault is open" % [word, seed_index])
			_check(reach.size() == open.size(),
				"%s %d: every open tile is reachable from the entry (%d of %d)" % [word, seed_index, reach.size(), open.size()])
			_check(layout.deepest() >= Balance.DUNGEON_SPAWN_MIN_TILES,
				"%s %d: the vault is a real walk away (depth %d)" % [word, seed_index, layout.deepest()])
			_check(layout.rooms.size() >= 3, "%s %d: rooms were cut (%d)" % [word, seed_index, layout.rooms.size()])
			var share: float = float(open.size()) / float(RaidLayout.SIZE * RaidLayout.SIZE)
			_check(share > 0.2 and share < 0.8, "%s %d: floor is %.0f%% of the field" % [word, seed_index, share * 100.0])
			var ring_sealed: bool = true
			for index: int in RaidLayout.SIZE:
				for tile: Vector2i in [Vector2i(index, 0), Vector2i(index, RaidLayout.SIZE - 1),
						Vector2i(0, index), Vector2i(RaidLayout.SIZE - 1, index)]:
					if layout.cell_at(tile) != RaidLayout.Cell.WALL:
						ring_sealed = false
			_check(ring_sealed, "%s %d: the edge is rock all the way round" % [word, seed_index])
			var levels_agree: bool = true
			for y: int in RaidLayout.SIZE:
				for x: int in RaidLayout.SIZE:
					var tile := Vector2i(x, y)
					var wall: bool = layout.cell_at(tile) == RaidLayout.Cell.WALL
					if layout.level_at(tile) != (DungeonLayout.WALL_LEVEL if wall else 0):
						levels_agree = false
			_check(levels_agree, "%s %d: floor is level 0 and rock is the wall level" % [word, seed_index])
			_check(not layout.can_step(layout.entry, Vector2i(0, 0)) and not layout.is_open(Vector2.ONE * -1e9),
				"%s %d: rock refuses a step" % [word, seed_index])
			if cavern:
				cavern_floor += open.size()
			else:
				maze_floor += open.size()
	_check(cavern_floor > maze_floor, "a rift's cavern has more floor than a dungeon's maze (%d vs %d)" % [cavern_floor, maze_floor])


func _test_the_arena() -> void:
	var rift: RiftArena = (load(ARENA) as PackedScene).instantiate() as RiftArena
	add_child(rift)
	for _f: int in 3:
		await get_tree().process_frame
	rift.open(RiftArena.Kind.DUNGEON, Vector2.ZERO)
	rift.set_process(false)
	var maze: DungeonLayout = rift.dungeon()
	_check(maze != null and not maze.cavern, "a dungeon's floor is the tight cut")
	if maze == null:
		rift.queue_free()
		return
	_check(maze.is_open(rift.hero.global_position), "the hero arrives on open floor")
	var hero_tile: Vector2i = RaidLayout.world_to_tile(rift.hero.global_position)
	# Where bodies appear.
	var far_enough: bool = true
	var on_floor: bool = true
	for _sample: int in 24:
		var at: Vector2 = rift._edge_point()
		if not maze.is_open(at):
			on_floor = false
		var tile: Vector2i = RaidLayout.world_to_tile(at)
		if int(maze.distances_from(hero_tile).get(tile, 0)) < Balance.DUNGEON_SPAWN_MIN_TILES:
			far_enough = false
	_check(on_floor, "bodies appear on open floor, never in rock")
	_check(far_enough, "bodies appear at least %d tiles' walk from the hero" % Balance.DUNGEON_SPAWN_MIN_TILES)
	# How they come: from the vault, the hint is a neighbour one step nearer.
	var from: Vector2 = RaidLayout.tile_to_world(maze.deep)
	var hint: Vector2 = rift.route_hint(from, rift.hero.global_position)
	var hint_tile: Vector2i = RaidLayout.world_to_tile(hint)
	var depth_from: int = int(maze.distances_from(hero_tile).get(maze.deep, -1))
	var depth_hint: int = int(maze.distances_from(hero_tile).get(hint_tile, -1))
	_check(hint != rift.hero.global_position, "a body in the vault is not told to walk through rock at the hero")
	_check(maze.is_open(hint), "the hint is open floor")
	_check((hint_tile - maze.deep).length() <= 1.01, "the hint is a neighbouring tile")
	_check(depth_hint >= 0 and depth_hint < depth_from, "and one step nearer the hero (%d -> %d)" % [depth_from, depth_hint])
	var beside: Vector2 = rift.hero.global_position + Vector2(RaidLayout.TILE * 0.9, 0.0)
	_check(rift.route_hint(beside, rift.hero.global_position) == rift.hero.global_position,
		"a body beside the hero is told the hero")
	_check(rift.objective_position(from) == hint, "the field's objective is the hint")
	# Spawning through the clock puts bodies on the floor.
	rift._process(Balance.DUNGEON_FIRST_SPAWN_DELAY + 0.1)
	for _tick: int in 12:
		rift._process(Balance.RIFT_SPAWN_INTERVAL + 0.01)
	var bodies: int = 0
	var bodies_on_floor: bool = true
	for node: Node in rift.entity_root.get_children():
		var enemy := node as Enemy
		if enemy == null:
			continue
		bodies += 1
		if not maze.is_open(enemy.global_position):
			bodies_on_floor = false
	_check(bodies >= 6, "the clock spawned bodies (%d)" % bodies)
	_check(bodies_on_floor, "every spawned body stands on floor")
	# The guardian wakes in the vault.
	var kills: int = int(ceil(1.0 / Balance.RIFT_FILL_PER_KILL))
	for _kill: int in kills:
		EventBus.enemy_died.emit("bogkin", Vector2.ZERO)
	rift._process(0.1)
	_check(rift._guardian != null and is_instance_valid(rift._guardian)
		and RaidLayout.world_to_tile(rift._guardian.global_position) == maze.deep,
		"the guardian wakes in the vault")
	# A rift is the cavern.
	rift.call("_finish", {"died": true})
	rift.open(RiftArena.Kind.RIFT, Vector2.ZERO)
	rift.set_process(false)
	_check(rift.dungeon() != null and rift.dungeon().cavern, "a rift's floor is the loose cut")
	rift.call("_finish", {"died": true})
	rift.queue_free()
	await get_tree().process_frame


## The look of the deep (2026-09-14): the sun does not reach it, the floor
## is drawn from its corners, the walls carry sconces, the floor is strewn,
## the vault wears its runes, the air moves, and the place groans and sheds
## rock before it comes down.
func _test_the_look() -> void:
	# The sun stays the sun.
	var was_night: bool = DayNight.is_night()
	var sun: float = DayNight.sun_darkness()
	DayNight.set_underground(true, Balance.DUNGEON_TINT)
	_check(is_equal_approx(DayNight.darkness, 1.0), "underground publishes deep night to the lights")
	_check(DayNight.tint == Balance.DUNGEON_TINT, "and the deep's own tint")
	_check(DayNight.is_night() == was_night, "the night's teeth stay with the sun")
	_check(is_equal_approx(DayNight.sun_darkness(), sun), "the sun's own reading is kept")
	DayNight.set_underground(false)
	_check(is_equal_approx(DayNight.darkness, sun), "back in the light, the sun is the sun again")
	# The floor is drawn from its corners.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1001
	var layout := DungeonLayout.new(rng, false)
	var art: String = DungeonTiles.art_for(RiftArena.Kind.DUNGEON)
	_check(ResourceLoader.exists(art), "the dungeon's tile sheet is on disk")
	_check(ResourceLoader.exists(DungeonTiles.art_for(RiftArena.Kind.RIFT)), "the rift's tile sheet is on disk")
	if ResourceLoader.exists(art):
		var tiles := DungeonTiles.new()
		add_child(tiles)
		tiles.lay(layout, load(art))
		var across: int = RaidLayout.SIZE + DungeonTiles.PAD * 2 + 1
		_check(tiles.get_used_cells().size() == across * across,
			"every cell of the floor and the rock is laid (%d)" % tiles.get_used_cells().size())
		var seen: Dictionary = {}
		for cell: Vector2i in tiles.get_used_cells():
			seen[tiles.get_cell_atlas_coords(cell)] = true
		_check(seen.size() >= 12, "the maze uses most of the sixteen corner tiles (%d)" % seen.size())
		_check(tiles.get_cell_atlas_coords(Vector2i(-DungeonTiles.PAD, -DungeonTiles.PAD))
			== DungeonTiles.atlas_coords(15), "beyond the rim is solid rock")
		_check(DungeonTiles.index_at(layout, layout.entry + Vector2i(1, 1)) != 15,
			"the entry is not rock")
		var floor_cells: int = 0
		for cell: Vector2i in tiles.get_used_cells():
			if tiles.get_cell_atlas_coords(cell) == DungeonTiles.atlas_coords(0):
				floor_cells += 1
		_check(floor_cells > 0, "there is open floor drawn (%d cells)" % floor_cells)
		tiles.queue_free()
	# The arena dresses the deep.
	var rift: RiftArena = (load(ARENA) as PackedScene).instantiate() as RiftArena
	add_child(rift)
	for _f: int in 3:
		await get_tree().process_frame
	rift.open(RiftArena.Kind.DUNGEON, Vector2.ZERO)
	rift.set_process(false)
	var maze: DungeonLayout = rift.dungeon()
	_check(DayNight.underground, "an open stage is underground")
	_check(rift.get_node_or_null("ArenaTint") is CanvasModulate
		and (rift.get_node("ArenaTint") as CanvasItem).visible, "the deep has its own dark")
	_check(rift.tiles() != null, "the stage's floor is the tile sheet")
	var decor: DungeonDecor = rift.decor()
	_check(decor != null, "the deep is dressed")
	if decor != null and maze != null:
		var count: int = decor.sconce_count()
		_check(count > 0 and count <= Balance.DUNGEON_SCONCE_MAX, "sconces hang on the walls (%d)" % count)
		var on_faces: bool = true
		var lights: int = 0
		var spaced: bool = true
		var spots: Array[DungeonSconce] = decor.sconces()
		for index: int in spots.size():
			var sconce: DungeonSconce = spots[index]
			var wall: Vector2i = RaidLayout.world_to_tile(sconce.position + Vector2(0.0, -RaidLayout.TILE * 0.5))
			if maze.cell_at(wall) != RaidLayout.Cell.WALL or maze.cell_at(wall + Vector2i(0, 1)) != RaidLayout.Cell.OPEN:
				on_faces = false
			if sconce.carries_light:
				lights += 1
			for other: int in range(index + 1, spots.size()):
				var there: Vector2i = RaidLayout.world_to_tile(spots[other].position + Vector2(0.0, -RaidLayout.TILE * 0.5))
				if maxi(absi(there.x - wall.x), absi(there.y - wall.y)) < Balance.DUNGEON_SCONCE_EVERY:
					spaced = false
		_check(on_faces, "every sconce hangs on a wall with floor at its foot")
		_check(spaced, "sconces keep their spacing")
		_check(lights >= 1 and lights <= int(ceil(float(count) / float(Balance.DUNGEON_SCONCE_LIGHT_EVERY))),
			"a few of them carry a real light (%d of %d)" % [lights, count])
		_check(decor.decal_count() > 0 and decor.decal_count() <= Balance.DUNGEON_DECAL_COUNT,
			"the floor is strewn (%d pieces)" % decor.decal_count())
		var strewn_on_floor: bool = true
		for piece: Sprite2D in decor.decals():
			if not maze.is_open(piece.global_position):
				strewn_on_floor = false
		_check(strewn_on_floor, "every piece lies on open floor")
		_check(decor.has_runes() and decor.runes_at() == RaidLayout.tile_to_world(maze.deep),
			"the runes sit on the vault")
	_check(rift.air() != null and rift.air().mote_count() == Balance.DUNGEON_MOTES,
		"the air of the deep moves (%d motes)" % (rift.air().mote_count() if rift.air() != null else 0))
	# The tell before the collapse: the place groans and sheds rock.
	rift._process(Balance.RIFT_TIME_LIMIT - Balance.DUNGEON_TREMOR_WARNING - 1.0)
	_check(_rocks_in(rift) == 0, "no rock falls before the warning")
	rift._process(1.0 + Balance.DUNGEON_TREMOR_EVERY + 0.1)
	_check(_rocks_in(rift) >= 1, "the place groans before it comes down (%d rocks)" % _rocks_in(rift))
	var before: int = _rocks_in(rift)
	rift._process(Balance.DUNGEON_TREMOR_WARNING)
	_check(bool(rift.status()["collapsing"]), "then it collapses")
	rift._process(1.05)
	_check(_rocks_in(rift) >= before + Balance.DUNGEON_ROCKS_PER_BITE,
		"every bite of the collapse sheds rock (%d)" % _rocks_in(rift))
	# A rock lands.
	var rock := FallingRock.new()
	add_child(rock)
	rock._process(Balance.DUNGEON_ROCK_FALL_SECONDS + 0.1)
	_check(rock.landed(), "a rock lands")
	rock.queue_free()
	rift.call("_finish", {"died": true})
	_check(not DayNight.underground, "leaving the deep gives the sun back")
	rift.queue_free()
	await get_tree().process_frame


func _rocks_in(rift: RiftArena) -> int:
	var rocks: int = 0
	for node: Node in rift.entity_root.get_children():
		if node is FallingRock:
			rocks += 1
	return rocks


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[dungeon] " + message)
