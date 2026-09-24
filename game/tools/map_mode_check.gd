extends SceneTree

## Every map mode, laid for real and walked: the battlefield it would give a road.
##
##   godot --headless --path game --script res://tools/map_mode_check.gd
##   ... -- --shots=<folder>      also writes one picture per mode
##
## Owner, 2026-09-23: map modes in the settings "so all variations can be tested
## and current method can be preserved to revisit as needed". Two promises, and
## this holds both:
##
##   * **Classic is the map it always was.** A grid made without a mode and a
##     grid made as Classic are the same grid, cell for cell and route for route,
##     and its core is the authored file exactly. If this fails, the thing to
##     change is not this check.
##   * **Every other mode is a battlefield the game can actually play.** Four
##     lanes, each with ways in from both pools that are road the whole way and
##     end at a gate; camps where the outskirts put them; spawns on the field;
##     lanes within a bound of each other's walk; room to build; and a core that
##     is its own mirror image - which is the property that makes a pinwheel
##     impossible rather than merely absent.
##
## Wild Roads is rolled from the seed, so it is walked on several: each must
## pass, the same seed must give the same road, different seeds must give
## different roads, and none may have quietly fallen back to the Keep.

const SEEDS: Array[int] = [1, 7, 42, 1234, 99991, 314159, 2718281, 55555]
## How much longer one lane's shortest way in may be than another's. The
## layouts are designed well inside it; a road half the length of the others
## is the road every wave is lost on.
const MAX_LANE_RATIO: float = 1.6
## The least build ground a mode may leave in the core, as a share of what
## Classic leaves.
const MIN_GROUND_SHARE: float = 0.55
## How nearly a new core must be its own mirror image, left to right.
const MIN_MIRROR: float = 0.99

var _failures: Array[String] = []


func _init() -> void:
	_check_sanitise()
	var classic := BattleGrid.new(SEEDS[0])
	_check_classic_is_classic(classic)
	var classic_ground: int = _core_anchors(classic)
	print("[map-mode] classic: %s" % _describe(classic))

	var shots: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.substr(8)

	for mode: String in MapModes.ids():
		if mode == MapModes.CLASSIC:
			if not shots.is_empty():
				_shoot(classic, shots)
			continue
		var seeds: Array[int] = []
		if mode == MapModes.WILD:
			seeds.assign(SEEDS)
		else:
			seeds.assign([SEEDS[0], SEEDS[3]])
		for seed_value: int in seeds:
			var grid := BattleGrid.new(seed_value, mode)
			_check_mode(grid, mode, seed_value, classic_ground)
			if seed_value == seeds[0]:
				print("[map-mode] %s: %s" % [mode, _describe(grid)])
				if not shots.is_empty():
					_shoot(grid, shots)
		_check_varied(mode, classic_ground, shots)
	_check_wild()
	_check_random()

	for problem: String in _failures:
		push_error("[map-mode] " + problem)
	print("[map-mode] %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)


func _check_sanitise() -> void:
	_check(MapModes.sanitise("nonsense") == MapModes.CLASSIC,
		"an unknown mode must read as Classic, not reach the grid")
	_check(MapModes.sanitise(7) == MapModes.CLASSIC, "a mode that is not text must read as Classic")
	for id: String in MapModes.ids():
		_check(MapModes.sanitise(id) == id, "%s must survive sanitising" % id)
		_check(not MapModes.label_of(id).is_empty() and not MapModes.blurb_of(id).is_empty(),
			"%s needs a label and a line for the dropdown" % id)
	_check(MapModes.ids()[0] == MapModes.CLASSIC,
		"Classic is the default and must stay first in the dropdown")


## Classic without a mode, Classic by name, and the authored file: one map.
func _check_classic_is_classic(classic: BattleGrid) -> void:
	for seed_value: int in [SEEDS[0], SEEDS[2]]:
		var plain := BattleGrid.new(seed_value)
		var named := BattleGrid.new(seed_value, MapModes.CLASSIC)
		_check(plain.cells == named.cells,
			"seed %d: a grid made as Classic differs from one made without a mode" % seed_value)
		_check(str(plain.routes) == str(named.routes) and str(plain.far_routes) == str(named.far_routes),
			"seed %d: Classic's routes differ from the unmoded grid's" % seed_value)
	var text: String = FileAccess.get_file_as_string(BattleGrid.LAYOUT_PATH)
	var parsed: Variant = JSON.parse_string(text)
	var rows: Array = (parsed as Dictionary).get("tiles", []) if parsed is Dictionary else []
	var differ: int = 0
	for y: int in rows.size():
		for x: int in (rows[y] as Array).size():
			var tile := Vector2i(x + BattleGrid.OUTSKIRTS, y + BattleGrid.OUTSKIRTS)
			var id: int = int((rows[y] as Array)[x])
			var road: bool = id in [BattleGrid.TILE_PATH, BattleGrid.TILE_START,
				BattleGrid.TILE_END, BattleGrid.TILE_SPAWN]
			var cell: int = classic.cell_at(tile)
			# The outskirts overwrite the edge row at each entry, as they always have.
			if road and cell != BattleGrid.Cell.ROAD and cell != BattleGrid.Cell.TOWN:
				differ += 1
	_check(differ == 0, "Classic's core no longer matches the authored file on %d road tiles" % differ)


func _check_mode(grid: BattleGrid, mode: String, seed_value: int, classic_ground: int) -> void:
	var tag: String = "%s seed %d" % [mode, seed_value]
	_check(grid.mode == mode, "%s: the grid says it is %s" % [tag, grid.mode])
	_check(grid.lane_paths.size() == Balance.LANE_COUNT and grid.routes.size() == Balance.LANE_COUNT,
		"%s: every lane needs a road" % tag)
	var town_node := Vector2i(BattleGrid.SIZE / 2, BattleGrid.SIZE / 2)
	var gates: Array[Vector2i] = grid.lattice_neighbours(town_node)
	_check(gates.size() >= 2, "%s: the town stands on %d gates" % [tag, gates.size()])

	var walks: Array[float] = []
	for lane: int in Balance.LANE_COUNT:
		var near: Array = grid.routes[lane] if lane < grid.routes.size() else []
		var far: Array = grid.far_routes[lane] if lane < grid.far_routes.size() else []
		_check(near.size() >= 2, "%s lane %d: %d near ways in - a lane needs a choice" % [tag, lane, near.size()])
		_check(not far.is_empty(), "%s lane %d: no way in from the legs" % [tag, lane])
		_check_routes(grid, gates, tag, lane, "near", near, 1)
		_check_routes(grid, gates, tag, lane, "far", far, 0)
		if not near.is_empty():
			walks.append(_length(near[0]))
		_check(grid.camps_of(lane).size() == 3, "%s lane %d: %d camps" % [tag, lane, grid.camps_of(lane).size()])
		for point: Variant in (grid.ambush_points[lane] as Array) + (grid.far_spawn_points[lane] as Array):
			var at: Vector2 = point
			_check(absf(at.x) <= BattleGrid.HALF_EXTENT and absf(at.y) <= BattleGrid.HALF_EXTENT,
				"%s lane %d: a spawn stands off the field at %s" % [tag, lane, at])
	if walks.size() == Balance.LANE_COUNT:
		var ratio: float = walks.max() / maxf(walks.min(), 1.0)
		_check(ratio <= MAX_LANE_RATIO,
			"%s: the lanes' shortest ways in are %s - %.2fx apart, over %.2f"
				% [tag, _rounded(walks), ratio, MAX_LANE_RATIO])

	var mirror: float = _mirror_share(grid)
	_check(mirror >= MIN_MIRROR,
		"%s: the core is only %.0f%% its own mirror image - a layout without a mirror line can wind"
			% [tag, mirror * 100.0])
	var ground: int = _core_anchors(grid)
	_check(float(ground) >= float(classic_ground) * MIN_GROUND_SHARE,
		"%s: %d places for a tower in the core against Classic's %d" % [tag, ground, classic_ground])


func _check_routes(grid: BattleGrid, gates: Array[Vector2i], tag: String, lane: int, pool: String,
		options: Array, first_step: int) -> void:
	var town: Vector2i = BattleGrid.world_to_tile(Vector2.ZERO)
	for index: int in options.size():
		var route: PackedVector2Array = options[index]
		if route.size() < 2:
			_check(false, "%s lane %d %s route %d has %d points" % [tag, lane, pool, index, route.size()])
			continue
		var last: Vector2i = BattleGrid.world_to_tile(route[route.size() - 1])
		_check(gates.has(last), "%s lane %d %s route %d ends at %s, not at a gate %s"
			% [tag, lane, pool, index, last, gates])
		for i: int in route.size():
			if BattleGrid.world_to_tile(route[i]) == town:
				_check(false, "%s lane %d %s route %d walks onto the town's tile" % [tag, lane, pool, index])
				break
		for i: int in range(first_step, route.size() - 1):
			if not _corridor_is_road(grid, route[i], route[i + 1]):
				_check(false, "%s lane %d %s route %d crosses open ground between %s and %s"
					% [tag, lane, pool, index, route[i], route[i + 1]])
				break


## Random's version of a layout: every seed a sound road, the same seed the same
## road, and the seeds between them more than one road - a variation that never
## varies is the named layout wearing Random's label.
func _check_varied(mode: String, classic_ground: int, shots: String) -> void:
	var shapes: Dictionary = {}
	for seed_value: int in SEEDS:
		var grid := BattleGrid.new(seed_value, mode, true)
		_check(grid.varied, "%s seed %d: asked for a varied road and got the named one" % [mode, seed_value])
		_check_mode(grid, mode, seed_value, classic_ground)
		var again := BattleGrid.new(seed_value, mode, true)
		_check(grid.cells == again.cells,
			"%s varied seed %d: the same seed laid two different roads" % [mode, seed_value])
		shapes[_core_signature(grid)] = true
		if not shots.is_empty() and SEEDS.find(seed_value) < 3:
			_shoot(grid, shots, "_varied_%d" % seed_value)
	_check(shapes.size() >= 3, "%s varied: %d seeds laid only %d different roads"
		% [mode, SEEDS.size(), shapes.size()])
	print("[map-mode] %s varied: %d different roads from %d seeds" % [mode, shapes.size(), SEEDS.size()])


## Random: a choice that is never a road, never Classic, and deals every other
## layout; a named layout is laid as designed.
func _check_random() -> void:
	var dealt: Dictionary = {}
	for road_seed: int in range(1, 400):
		var road: Array = MapModes.resolve(MapModes.RANDOM, road_seed)
		_check(String(road[0]) != MapModes.CLASSIC, "Random dealt Classic on road %d" % road_seed)
		_check(String(road[0]) != MapModes.RANDOM, "Random resolved to itself on road %d" % road_seed)
		_check(bool(road[1]), "Random laid road %d as designed rather than varied" % road_seed)
		dealt[String(road[0])] = true
	for id: String in MapModes.random_pool():
		_check(dealt.has(id), "Random never dealt %s in 400 roads" % id)
	_check(MapModes.resolve(MapModes.RANDOM, 77) == MapModes.resolve(MapModes.RANDOM, 77),
		"Random dealt two different layouts for one road")
	for id: String in MapModes.ids():
		var named: Array = MapModes.resolve(id, 5)
		_check(String(named[0]) == id and not bool(named[1]),
			"picking %s laid %s, varied %s" % [id, named[0], named[1]])
	_check(MapModes.sanitise(MapModes.RANDOM) == MapModes.CLASSIC,
		"Random must never reach the grid as a layout")
	_check(MapModes.sanitise_choice(MapModes.RANDOM) == MapModes.RANDOM,
		"Random must survive as a choice")
	_check(String(MapModes.choices()[0]["id"]) == MapModes.CLASSIC
		and String(MapModes.choices()[1]["id"]) == MapModes.RANDOM,
		"the dropdown opens with Classic and then Random")
	_check(BattleGrid.new(3, MapModes.CLASSIC, true).cells == BattleGrid.new(3).cells,
		"Classic asked to vary must still be Classic")


## Wild Roads: the same seed lays the same road, other seeds lay other roads,
## and none of them is the Keep it falls back to.
func _check_wild() -> void:
	var keep := BattleGrid.new(SEEDS[0], MapModes.KEEP)
	var shapes: Dictionary = {}
	var fallbacks: int = 0
	for seed_value: int in SEEDS:
		var one := BattleGrid.new(seed_value, MapModes.WILD)
		var two := BattleGrid.new(seed_value, MapModes.WILD)
		_check(one.cells == two.cells, "wild seed %d: the same seed laid two different roads" % seed_value)
		var core: String = _core_signature(one)
		shapes[core] = true
		if core == _core_signature(keep):
			fallbacks += 1
	_check(fallbacks == 0, "wild: %d of %d seeds fell back to the Keep" % [fallbacks, SEEDS.size()])
	_check(shapes.size() >= SEEDS.size() - 1,
		"wild: %d seeds laid only %d different networks" % [SEEDS.size(), shapes.size()])


# --- Measures ----------------------------------------------------------------

func _core_signature(grid: BattleGrid) -> String:
	var out: PackedStringArray = []
	for y: int in BattleGrid.CORE_SIZE:
		var row: String = ""
		for x: int in BattleGrid.CORE_SIZE:
			row += str(grid.cell_at(Vector2i(x + BattleGrid.OUTSKIRTS, y + BattleGrid.OUTSKIRTS)))
		out.append(row)
	return "|".join(out)


## Share of the core's road that is road in its left-right mirror image too.
func _mirror_share(grid: BattleGrid) -> float:
	var road: int = 0
	var matched: int = 0
	var o: int = BattleGrid.OUTSKIRTS
	var last: int = BattleGrid.CORE_SIZE - 1
	for y: int in BattleGrid.CORE_SIZE:
		for x: int in BattleGrid.CORE_SIZE:
			if not _is_road(grid, Vector2i(x + o, y + o)):
				continue
			road += 1
			if _is_road(grid, Vector2i(last - x + o, y + o)):
				matched += 1
	return float(matched) / float(maxi(road, 1))


## Places a two-by-two tower fits in the core.
func _core_anchors(grid: BattleGrid) -> int:
	var count: int = 0
	var o: int = BattleGrid.OUTSKIRTS
	for y: int in range(o, o + BattleGrid.CORE_SIZE - 1):
		for x: int in range(o, o + BattleGrid.CORE_SIZE - 1):
			if grid.footprint_is_open(Vector2i(x, y)):
				count += 1
	return count


func _describe(grid: BattleGrid) -> String:
	var walks: Array[float] = []
	var counts: Array[int] = []
	for lane: int in Balance.LANE_COUNT:
		var near: Array = grid.routes[lane]
		walks.append(_length(near[0]) if not near.is_empty() else 0.0)
		counts.append(near.size())
	var town_node := Vector2i(BattleGrid.SIZE / 2, BattleGrid.SIZE / 2)
	return "shortest ways in %s, near routes %s, %d gates, %d tower places, mirror %.0f%%" % [
		_rounded(walks), counts, grid.lattice_neighbours(town_node).size(),
		_core_anchors(grid), _mirror_share(grid) * 100.0]


func _rounded(values: Array[float]) -> Array[int]:
	var out: Array[int] = []
	for value: float in values:
		out.append(roundi(value))
	return out


func _is_road(grid: BattleGrid, tile: Vector2i) -> bool:
	var cell: int = grid.cell_at(tile)
	return cell == BattleGrid.Cell.ROAD or cell == BattleGrid.Cell.TOWN


func _corridor_is_road(grid: BattleGrid, from: Vector2, to: Vector2) -> bool:
	var steps: int = maxi(1, int(from.distance_to(to) / (BattleGrid.TILE * 0.5)))
	for i: int in steps + 1:
		var at: Vector2 = from.lerp(to, float(i) / float(steps))
		if not _is_road(grid, BattleGrid.world_to_tile(at)):
			return false
	return true


static func _length(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	return total


## One picture of the whole field: ground, road, town, camps, the core's edge
## and every spawn.
func _shoot(grid: BattleGrid, folder: String, suffix: String = "") -> void:
	const PX: int = 7
	var size: int = BattleGrid.SIZE * PX
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var colours: Dictionary = {
		BattleGrid.Cell.OPEN: Color8(58, 92, 52), BattleGrid.Cell.ROAD: Color8(206, 168, 108),
		BattleGrid.Cell.TOWN: Color8(214, 92, 60), BattleGrid.Cell.BORDER: Color8(30, 42, 30),
		BattleGrid.Cell.CAMP: Color8(150, 40, 44)}
	for y: int in BattleGrid.SIZE:
		for x: int in BattleGrid.SIZE:
			var colour: Color = colours.get(grid.cell_at(Vector2i(x, y)), Color.MAGENTA)
			image.fill_rect(Rect2i(x * PX, y * PX, PX - 1, PX - 1), colour)
	var o: int = BattleGrid.OUTSKIRTS * PX
	var edge: int = BattleGrid.CORE_SIZE * PX
	for i: int in edge:
		for point: Vector2i in [Vector2i(o + i, o), Vector2i(o + i, o + edge), Vector2i(o, o + i), Vector2i(o + edge, o + i)]:
			image.set_pixelv(point, Color.WHITE)
	for lane: int in Balance.LANE_COUNT:
		for point: Variant in (grid.ambush_points[lane] as Array) + (grid.far_spawn_points[lane] as Array):
			var tile: Vector2i = BattleGrid.world_to_tile(point as Vector2)
			image.fill_rect(Rect2i(tile.x * PX - 2, tile.y * PX - 2, PX + 4, PX + 4), Color(0.2, 0.9, 1.0))
	var path: String = folder.path_join("map_mode_%s%s.png" % [grid.mode, suffix])
	image.save_png(path)
	print("[map-mode] wrote %s" % path)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
