class_name MapLayouts
extends RefCounted

## The cores the new map modes lay, in place of the authored one.
##
## **Why these exist.** The authored core Classic ships is a pinwheel: measured
## on 2026-09-23 it matches itself under a quarter turn on 100% of its road and
## its own mirror image on 44%, so every road winds the same way round the town
## and the whole reads as a swastika. Mirroring only the outskirts could never
## fix that. Each mode here is **mirror-symmetric by construction** - a shape
## with a mirror line cannot be a pinwheel - and every one keeps the four
## entries at the middle of each edge, so the outskirts, the camps, the forks,
## the ponds and everything else laid around the core carry on unchanged.
##
## **Corridors, not curves.** The road network is a lattice of three-wide
## straight corridors: `BattleGrid` finds their centre lines by a run of exactly
## three road tiles, walks routes along them, and the renderer, the torches and
## the minimap all read that lattice. So every road here is an axis-aligned run
## between two centre points, parallel runs sit at least five tiles apart so a
## tower fits between them, and nothing is drawn within four tiles of the core's
## edge except the four entries.
##
## **The lanes are balanced by their walks.** Measured to the town along the
## shortest way in, each mode's four lanes sit within the bound
## `map_mode_check` holds, because a road that is half the length of the others
## is the road every wave is lost on.

const CORE: int = 45
const MID: int = CORE / 2
## Where Wild Roads' corridors may run, as offsets from the middle: seven apart,
## which leaves a four-tile strip between two parallel roads - two towers
## abreast - exactly as the authored core does.
const WILD_LINES: Array[int] = [-14, -7, 0, 7, 14]
## How many tries a Wild road gets before it falls back to the Keep. Each try is
## a few dozen dictionary operations, and a fallback is a map rather than a
## crash.
const WILD_ATTEMPTS: int = 400
## The first try's chance of laying each pair of corridors.
const WILD_DENSITY: float = 0.62
## Shortest way in, in tiles, that a Wild lane may have. A straight road from
## the edge to the town is 22; this refuses it, because a lane with no bend has
## no inside of a bend for a tower.
const WILD_MIN_WALK: int = 29
## How much longer one lane's shortest way in may be than another's.
const WILD_MAX_LANE_RATIO: float = 1.45
## How much of the lattice may be road, as a range of edges out of forty.
const WILD_EDGES_MIN: int = 12
const WILD_EDGES_MAX: int = 28
## How many independent loops a Wild network must hold: islands are where the
## good tower spots are.
const WILD_MIN_LOOPS: int = 2
## Tries a varied layout gets before it is laid as designed.
const VARIED_ATTEMPTS: int = 60
## The bounds every varied layout is held to by `_sound`, in tiles along the
## road: the shortest a lane may be, how much longer one lane may be than
## another, and the least room for towers (Classic's core has about a thousand).
const VARIED_MIN_WALK: int = 26
const VARIED_MAX_LANE_RATIO: float = 1.45
const VARIED_MIN_GROUND: int = 600


## The core for `mode`, as `CORE * CORE` grid cells. `rng` is the layout's own
## stream, already past the draws `BattleGrid` takes from it.
##
## `varied` is what Random asks for: the same layout with its proportions rolled
## - how far out a wall stands, where a bar or a rib crosses, how wide a braid
## is, which ties a double wall keeps. Every roll is drawn from ranges that keep
## parallel roads five tiles apart, and is then held to `_sound` - every entry
## reaches the town, no lane is much longer than another, there is room to
## build - and rolled again if it is not. A named layout picked in the dropdown
## is laid exactly as designed, so the thing being tested is the thing named.
static func lay(mode: String, rng: RandomNumberGenerator, varied: bool = false) -> Array[int]:
	var core: Array[int] = []
	core.resize(CORE * CORE)
	if mode == MapModes.WILD:
		core.fill(BattleGrid.Cell.OPEN)
		if not _wild(core, rng):
			core.fill(BattleGrid.Cell.OPEN)
			_keep(core, _keep_plan(rng, false))
		_town(core)
		return core
	if varied:
		for _attempt: int in VARIED_ATTEMPTS:
			core.fill(BattleGrid.Cell.OPEN)
			_lay_mode(core, mode, rng, true)
			_town(core)
			if _sound(core):
				return core
	core.fill(BattleGrid.Cell.OPEN)
	_lay_mode(core, mode, rng, false)
	_town(core)
	return core


static func _lay_mode(core: Array[int], mode: String, rng: RandomNumberGenerator,
		varied: bool) -> void:
	match mode:
		MapModes.CITADEL:
			_citadel(core, _citadel_plan(rng, varied))
		MapModes.BEAST_AXIS:
			_beast_axis(core, _beast_plan(rng, varied))
		MapModes.CONFLUENCE:
			_confluence(core, _confluence_plan(rng, varied))
		MapModes.FOUR_RINGS:
			_four_rings(core, _four_rings_plan(rng, varied))
		_:
			_keep(core, _keep_plan(rng, varied))


## Whether a laid core is one a road can be walked on and built beside: every
## entry reaches the town, the lanes are within `VARIED_MAX_LANE_RATIO` of each
## other and none is a straight shot, and there is room for towers.
static func _sound(core: Array[int]) -> bool:
	var walks: Array[int] = []
	var dist: Dictionary = _walk_from_town(core)
	for entry: Vector2i in [Vector2i(MID, 0), Vector2i(CORE - 1, MID), Vector2i(MID, CORE - 1),
			Vector2i(0, MID)]:
		if not dist.has(entry):
			return false
		walks.append(int(dist[entry]))
	if walks.min() < VARIED_MIN_WALK:
		return false
	if float(walks.max()) / float(walks.min()) > VARIED_MAX_LANE_RATIO:
		return false
	return _anchors(core) >= VARIED_MIN_GROUND


static func _walk_from_town(core: Array[int]) -> Dictionary:
	var dist: Dictionary = {}
	var queue: Array[Vector2i] = []
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var tile := Vector2i(MID + dx, MID + dy)
			dist[tile] = 0
			queue.append(tile)
	var head: int = 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = at + step
			if next.x < 0 or next.y < 0 or next.x >= CORE or next.y >= CORE or dist.has(next):
				continue
			if core[next.y * CORE + next.x] != BattleGrid.Cell.ROAD:
				continue
			dist[next] = int(dist[at]) + 1
			queue.append(next)
	return dist


static func _anchors(core: Array[int]) -> int:
	var count: int = 0
	for y: int in CORE - 1:
		for x: int in CORE - 1:
			if core[y * CORE + x] == BattleGrid.Cell.OPEN \
					and core[y * CORE + x + 1] == BattleGrid.Cell.OPEN \
					and core[(y + 1) * CORE + x] == BattleGrid.Cell.OPEN \
					and core[(y + 1) * CORE + x + 1] == BattleGrid.Cell.OPEN:
				count += 1
	return count


static func _roll(rng: RandomNumberGenerator, low: int, high: int) -> int:
	return rng.randi_range(low, maxi(low, high))


# --- The layouts -------------------------------------------------------------
#
# Written as offsets from the middle, so each is visibly its own mirror image.
# Each is drawn from a plan; the plan's canonical values are the layout as
# designed, and a varied plan rolls them inside the ranges that keep it sound.

## Two walls: an outer ring, an inner ring, the ties between them, and four
## gates into the town. A road meets the outer wall at its middle, walks out to
## a tie, and doubles back along the inner wall to its gate: a U round the
## island between the walls.
static func _keep_plan(rng: RandomNumberGenerator, varied: bool) -> Dictionary:
	if not varied:
		return {"outer": 17, "inner": 9, "top": true, "bottom": true, "sides": true}
	var outer: int = _roll(rng, 16, 18)
	return {"outer": outer, "inner": _roll(rng, 8, mini(10, outer - 7)),
		"top": rng.randf() < 0.8, "bottom": rng.randf() < 0.8, "sides": rng.randf() < 0.8}


static func _keep(core: Array[int], plan: Dictionary) -> void:
	var outer: int = int(plan["outer"])
	var inner: int = int(plan["inner"])
	_rect(core, outer, outer)
	_rect(core, inner, inner)
	for sx: int in [-1, 1]:
		if bool(plan["top"]):
			_run(core, inner * sx, -outer, inner * sx, -inner)
		if bool(plan["bottom"]):
			_run(core, inner * sx, outer, inner * sx, inner)
		if bool(plan["sides"]):
			for sy: int in [-1, 1]:
				_run(core, outer * sx, inner * sy, inner * sx, inner * sy)
	_spokes(core, inner, inner)
	_entries(core, outer, outer)


## One wall and two gates, east and west. Every road arrives at a bastion - a
## bar and two legs round an island - so no lane walks straight into a gate.
static func _citadel_plan(rng: RandomNumberGenerator, varied: bool) -> Dictionary:
	if not varied:
		return {"wide": 13, "tall": 12, "bar": 19, "leg": 7, "side_bar": 19, "side_leg": 7}
	var wide: int = _roll(rng, 12, 14)
	var tall: int = _roll(rng, 11, 13)
	return {"wide": wide, "tall": tall,
		"bar": _roll(rng, tall + 5, mini(20, tall + 8)), "leg": _roll(rng, 5, wide - 5),
		"side_bar": _roll(rng, wide + 5, mini(20, wide + 8)), "side_leg": _roll(rng, 5, tall - 5)}


static func _citadel(core: Array[int], plan: Dictionary) -> void:
	var wide: int = int(plan["wide"])
	var tall: int = int(plan["tall"])
	var bar: int = int(plan["bar"])
	var leg: int = int(plan["leg"])
	var side_bar: int = int(plan["side_bar"])
	var side_leg: int = int(plan["side_leg"])
	_rect(core, wide, tall)
	_run(core, -wide, 0, -2, 0)
	_run(core, wide, 0, 2, 0)
	for sy: int in [-1, 1]:
		_run(core, 0, 22 * sy, 0, bar * sy)
		_run(core, -leg, bar * sy, leg, bar * sy)
		_run(core, -leg, bar * sy, -leg, tall * sy)
		_run(core, leg, bar * sy, leg, tall * sy)
	for sx: int in [-1, 1]:
		_run(core, 22 * sx, 0, side_bar * sx, 0)
		_run(core, side_bar * sx, -side_leg, side_bar * sx, side_leg)
		_run(core, side_bar * sx, -side_leg, wide * sx, -side_leg)
		_run(core, side_bar * sx, side_leg, wide * sx, side_leg)


## The beast from above: a wall round the body, a spine from bow to stern
## through the town, and ribs across it. Bow and stern arrive through bastions
## onto the wall beside the spine; the flanks arrive on the wall's long sides
## and cut in along a rib.
static func _beast_plan(rng: RandomNumberGenerator, varied: bool) -> Dictionary:
	if not varied:
		return {"wide": 13, "tall": 13, "ribs": [7], "bar": 19, "leg": 7}
	var wide: int = _roll(rng, 12, 14)
	var tall: int = _roll(rng, 12, 15)
	var ribs: Array = []
	if tall >= 15 and rng.randf() < 0.5:
		ribs = [5, 10]
	else:
		ribs = [_roll(rng, 5, tall - 5)]
	return {"wide": wide, "tall": tall, "ribs": ribs,
		"bar": _roll(rng, tall + 5, mini(20, tall + 7)), "leg": _roll(rng, 5, wide - 5)}


static func _beast_axis(core: Array[int], plan: Dictionary) -> void:
	var wide: int = int(plan["wide"])
	var tall: int = int(plan["tall"])
	var bar: int = int(plan["bar"])
	var leg: int = int(plan["leg"])
	_rect(core, wide, tall)
	_run(core, 0, -tall, 0, tall)
	for rib: Variant in plan["ribs"]:
		_run(core, -wide, -int(rib), wide, -int(rib))
		_run(core, -wide, int(rib), wide, int(rib))
	for sy: int in [-1, 1]:
		_run(core, 0, 22 * sy, 0, bar * sy)
		_run(core, -leg, bar * sy, leg, bar * sy)
		_run(core, -leg, bar * sy, -leg, tall * sy)
		_run(core, leg, bar * sy, leg, tall * sy)
	for sx: int in [-1, 1]:
		_run(core, 22 * sx, 0, wide * sx, 0)


## Two braided trunks, west and east, each a loop round an island that rejoins
## before the town. The north and south roads split along a yoke and drop onto
## the braids' outer strands, so every road ends on a trunk.
static func _confluence_plan(rng: RandomNumberGenerator, varied: bool) -> Dictionary:
	if not varied:
		return {"outer": 17, "inner": 7, "strand": 6, "yoke": 18, "leg": 12}
	var inner: int = _roll(rng, 6, 8)
	var outer: int = _roll(rng, inner + 10, mini(19, inner + 12))
	var strand: int = _roll(rng, 5, 7)
	return {"outer": outer, "inner": inner, "strand": strand,
		"yoke": _roll(rng, maxi(16, strand + 9), 20), "leg": _roll(rng, inner + 5, outer - 5)}


static func _confluence(core: Array[int], plan: Dictionary) -> void:
	var outer: int = int(plan["outer"])
	var inner: int = int(plan["inner"])
	var strand: int = int(plan["strand"])
	var yoke: int = int(plan["yoke"])
	var leg: int = int(plan["leg"])
	for sx: int in [-1, 1]:
		_run(core, 22 * sx, 0, outer * sx, 0)
		_run(core, outer * sx, -strand, outer * sx, strand)
		_run(core, inner * sx, -strand, inner * sx, strand)
		_run(core, outer * sx, -strand, inner * sx, -strand)
		_run(core, outer * sx, strand, inner * sx, strand)
		_run(core, inner * sx, 0, 2 * sx, 0)
	for sy: int in [-1, 1]:
		_run(core, 0, 22 * sy, 0, yoke * sy)
		_run(core, -leg, yoke * sy, leg, yoke * sy)
		_run(core, -leg, yoke * sy, -leg, strand * sy)
		_run(core, leg, yoke * sy, leg, strand * sy)


## Confluence with a ring for every road (owner, 2026-09-23: "another version
## of confluence that has the rings for the north and south as well so that each
## direction has their own ring"). Four braids, one a road, each a loop round an
## island before a trunk to the town. The rings stand far enough off the middle
## that no two of them touch at a corner - two rings sharing a tile would be a
## road nobody laid.
##
## The west and east rings mirror each other and share a plan; the north and
## south rings stand on the mirror line, so each may take its own and the field
## is still its own mirror image left to right.
static func _four_rings_plan(rng: RandomNumberGenerator, varied: bool) -> Dictionary:
	if not varied:
		var even: Dictionary = {"outer": 18, "inner": 9, "strand": 5}
		return {"sides": even, "north": even, "south": even}
	return {"sides": _ring_plan(rng), "north": _ring_plan(rng), "south": _ring_plan(rng)}


static func _ring_plan(rng: RandomNumberGenerator) -> Dictionary:
	var strand: int = _roll(rng, 5, 6)
	var inner: int = _roll(rng, strand + 4, strand + 5)
	return {"outer": _roll(rng, inner + 8, 19), "inner": inner, "strand": strand}


static func _four_rings(core: Array[int], plan: Dictionary) -> void:
	# One ring, drawn along an axis: `along` the unit step out from the town,
	# `across` the step sideways.
	var rings: Array = [
		[Vector2i(-1, 0), plan["sides"]], [Vector2i(1, 0), plan["sides"]],
		[Vector2i(0, -1), plan["north"]], [Vector2i(0, 1), plan["south"]]]
	for ring: Array in rings:
		var along: Vector2i = ring[0]
		var shape: Dictionary = ring[1]
		var across := Vector2i(absi(along.y), absi(along.x))
		var outer: int = int(shape["outer"])
		var inner: int = int(shape["inner"])
		var strand: int = int(shape["strand"])
		_run_v(core, along * 22, along * outer)
		_run_v(core, along * outer - across * strand, along * outer + across * strand)
		_run_v(core, along * inner - across * strand, along * inner + across * strand)
		_run_v(core, along * outer - across * strand, along * inner - across * strand)
		_run_v(core, along * outer + across * strand, along * inner + across * strand)
		_run_v(core, along * inner, along * 2)


static func _run_v(core: Array[int], a: Vector2i, b: Vector2i) -> void:
	_run(core, a.x, a.y, b.x, b.y)


## A network rolled for this road alone, on a five-by-five lattice of corridor
## lines, mirrored left to right. Rolled until it passes: every entry reaches the
## town, no lane has a straight shot, the lanes are within a bound of each other,
## there are loops to build inside, and the roads leave room to build at all.
static func _wild(core: Array[int], rng: RandomNumberGenerator) -> bool:
	for _attempt: int in WILD_ATTEMPTS:
		var edges: Dictionary = _wild_roll(rng)
		if edges.is_empty():
			continue
		for key: Variant in edges:
			var edge: Array = edges[key] as Array
			var a: Vector2i = edge[0]
			var b: Vector2i = edge[1]
			_run(core, WILD_LINES[a.x], WILD_LINES[a.y], WILD_LINES[b.x], WILD_LINES[b.y])
		_entries(core, 14, 14)
		return true
	return false


# --- Wild Roads --------------------------------------------------------------

## One try: a mirrored set of lattice edges, or empty when it fails a bound.
static func _wild_roll(rng: RandomNumberGenerator) -> Dictionary:
	var edges: Dictionary = {}
	# The left half and the axis, each mirrored onto the right. A horizontal
	# edge (i, j)-(i+1, j) mirrors to (3-i, j)-(4-i, j); a vertical one at
	# column i mirrors to column 4-i, and the axis column is its own mirror.
	for j: int in 5:
		for i: int in 2:
			if rng.randf() < WILD_DENSITY:
				_wild_add(edges, Vector2i(i, j), Vector2i(i + 1, j))
	for i: int in 3:
		for j: int in 4:
			if rng.randf() < WILD_DENSITY:
				_wild_add(edges, Vector2i(i, j), Vector2i(i, j + 1))
	var town := Vector2i(2, 2)
	var entries: Array[Vector2i] = [Vector2i(2, 0), Vector2i(4, 2), Vector2i(2, 4), Vector2i(0, 2)]
	# **No lane walks straight in.** Each entry's two-step line to the town is
	# never laid whole: when the roll takes both halves, it gives one back. Done
	# here rather than refused afterwards, because a quarter of all rolls took
	# some straight line and a generator that mostly refuses is one that falls
	# back to the Keep.
	for pair: Array in [[Vector2i(2, 0), Vector2i(2, 1)], [Vector2i(2, 4), Vector2i(2, 3)],
			[Vector2i(0, 2), Vector2i(1, 2)]]:
		var outer: Vector2i = pair[0]
		var inner: Vector2i = pair[1]
		var toward: Vector2i = town - inner
		var first: String = _wild_key(outer, inner)
		var second: String = _wild_key(inner, inner + toward.sign())
		if edges.has(first) and edges.has(second):
			if rng.randf() < 0.5:
				_wild_remove(edges, outer, inner)
			else:
				_wild_remove(edges, inner, inner + toward.sign())
	_wild_prune(edges, entries, town)
	var count: int = edges.size()
	if count < WILD_EDGES_MIN or count > WILD_EDGES_MAX:
		return {}
	# At least two gates into the town. One would funnel all four lanes through
	# a single door, which is a chokepoint the whole road network exists to avoid.
	var gates: int = 0
	for key: Variant in edges:
		var edge: Array = edges[key] as Array
		if edge[0] == town or edge[1] == town:
			gates += 1
	if gates < 2:
		return {}
	var walks: Array[int] = []
	for entry: Vector2i in entries:
		var steps: int = _wild_distance(edges, entry, town)
		if steps < 0:
			return {}
		# Seven tiles a lattice step, eight from the core's edge to the first line.
		walks.append(steps * 7 + 8)
	var shortest: int = walks.min()
	if shortest < WILD_MIN_WALK:
		return {}
	if float(walks.max()) / float(shortest) > WILD_MAX_LANE_RATIO:
		return {}
	# Independent loops: edges - nodes + components. One component by now.
	var nodes: Dictionary = {}
	for key: Variant in edges:
		var edge: Array = edges[key] as Array
		nodes[edge[0]] = true
		nodes[edge[1]] = true
	if count - nodes.size() + 1 < WILD_MIN_LOOPS:
		return {}
	return edges


static func _wild_add(edges: Dictionary, a: Vector2i, b: Vector2i) -> void:
	edges[_wild_key(a, b)] = [a, b]
	var ma := Vector2i(4 - a.x, a.y)
	var mb := Vector2i(4 - b.x, b.y)
	edges[_wild_key(ma, mb)] = [ma, mb]


static func _wild_remove(edges: Dictionary, a: Vector2i, b: Vector2i) -> void:
	edges.erase(_wild_key(a, b))
	edges.erase(_wild_key(Vector2i(4 - a.x, a.y), Vector2i(4 - b.x, b.y)))


static func _wild_key(a: Vector2i, b: Vector2i) -> String:
	var low: Vector2i = a if [a.x, a.y] < [b.x, b.y] else b
	var high: Vector2i = b if low == a else a
	return "%d,%d-%d,%d" % [low.x, low.y, high.x, high.y]


## Drops what a body would never walk: anything not connected to the town, and
## dead ends that are not an entry. Removed in mirrored pairs, so the network
## stays its own mirror image.
static func _wild_prune(edges: Dictionary, entries: Array[Vector2i], town: Vector2i) -> void:
	var reached: Dictionary = _wild_reach(edges, town)
	for key: Variant in edges.keys():
		# Removed in mirrored pairs, so a later key may already be gone.
		if not edges.has(key):
			continue
		var edge: Array = edges[key] as Array
		if not reached.has(edge[0]):
			_wild_remove(edges, edge[0], edge[1])
	var changed: bool = true
	while changed:
		changed = false
		var degree: Dictionary = {}
		for key: Variant in edges:
			var edge: Array = edges[key] as Array
			degree[edge[0]] = int(degree.get(edge[0], 0)) + 1
			degree[edge[1]] = int(degree.get(edge[1], 0)) + 1
		for key: Variant in edges.keys():
			if not edges.has(key):
				continue
			var edge: Array = edges[key] as Array
			for end: Vector2i in [edge[0], edge[1]]:
				if int(degree.get(end, 0)) == 1 and end != town and not entries.has(end):
					_wild_remove(edges, edge[0], edge[1])
					changed = true
					break


static func _wild_reach(edges: Dictionary, from: Vector2i) -> Dictionary:
	var seen: Dictionary = {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var node: Vector2i = queue.pop_front()
		for key: Variant in edges:
			var edge: Array = edges[key] as Array
			var other: Variant = null
			if edge[0] == node:
				other = edge[1]
			elif edge[1] == node:
				other = edge[0]
			if other != null and not seen.has(other):
				seen[other] = true
				queue.append(other)
	return seen


## Lattice steps from `from` to `to` along the network, or -1.
static func _wild_distance(edges: Dictionary, from: Vector2i, to: Vector2i) -> int:
	var dist: Dictionary = {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var node: Vector2i = queue.pop_front()
		if node == to:
			return int(dist[node])
		for key: Variant in edges:
			var edge: Array = edges[key] as Array
			var other: Variant = null
			if edge[0] == node:
				other = edge[1]
			elif edge[1] == node:
				other = edge[0]
			if other != null and not dist.has(other):
				dist[other] = int(dist[node]) + 1
				queue.append(other)
	return -1


# --- Drawing -----------------------------------------------------------------

## A closed wall `half_x` by `half_y` from the middle.
static func _rect(core: Array[int], half_x: int, half_y: int) -> void:
	_run(core, -half_x, -half_y, half_x, -half_y)
	_run(core, half_x, -half_y, half_x, half_y)
	_run(core, half_x, half_y, -half_x, half_y)
	_run(core, -half_x, half_y, -half_x, -half_y)


## Four gates: a road from the wall at `half_x` / `half_y` into the town.
static func _spokes(core: Array[int], half_x: int, half_y: int) -> void:
	_run(core, 0, -half_y, 0, -2)
	_run(core, 0, half_y, 0, 2)
	_run(core, -half_x, 0, -2, 0)
	_run(core, half_x, 0, 2, 0)


## The four entries, from the middle of each edge to the first road inside.
static func _entries(core: Array[int], half_x: int, half_y: int) -> void:
	_run(core, 0, -MID, 0, -half_y)
	_run(core, 0, MID, 0, half_y)
	_run(core, -MID, 0, -half_x, 0)
	_run(core, MID, 0, half_x, 0)


## A three-wide corridor along a straight line between two centre points, given
## as offsets from the middle. Every point on the line stamps its three-by-three,
## so a corner is square and a junction is solid.
static func _run(core: Array[int], x0: int, y0: int, x1: int, y1: int) -> void:
	var a := Vector2i(MID + x0, MID + y0)
	var b := Vector2i(MID + x1, MID + y1)
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var at: Vector2i = a
	while true:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				_mark(core, at + Vector2i(dx, dy), BattleGrid.Cell.ROAD)
		if at == b:
			break
		at += step


## The town: three by three in the middle, as the authored core has it.
static func _town(core: Array[int]) -> void:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			_mark(core, Vector2i(MID + dx, MID + dy), BattleGrid.Cell.TOWN)


static func _mark(core: Array[int], tile: Vector2i, cell: int) -> void:
	if tile.x < 0 or tile.y < 0 or tile.x >= CORE or tile.y >= CORE:
		return
	core[tile.y * CORE + tile.x] = cell
