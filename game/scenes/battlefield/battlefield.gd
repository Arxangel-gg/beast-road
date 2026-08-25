class_name Battlefield
extends EnemyField

## The tower-defense scope (GDD §3): four cardinal lanes, three build spots on
## each, a town in the middle, and the hero.
##
## Lanes and build spots are generated from Balance rather than authored in the
## scene, so changing TOWER_SLOT_RADII moves the spots instead of desynchronising
## the scene from the tuning.
##
## The whole scope freezes as a unit during a raid (GDD §6.3) — see `suspend`.
## Nothing in here may run off a timer the battlefield does not own.

@export var enemy_scene: PackedScene
@export var tower_scene: PackedScene
@export var projectile_scene: PackedScene

@export var ground: Sprite2D
@export var lane_root: Node2D
@export var slot_root: Node2D
@export var entity_root: Node2D
@export var effect_root: Node2D
@export var town: TownCore
@export var hero: Hero
@export var wave_director: WaveDirector

## Each scope owns its camera; the run makes the right one current when the
## scope changes, so switching does not leave the view sitting in another scope.
@export var camera: Camera2D

## The partner's hero, when a second player is here. Null-safe everywhere: in a
## single-player run this exists and does nothing.
var _coop_heroes: CoopHeroes = null

## Enemies and towers, made to agree on two machines. Inert when playing alone.
var _coop_world: CoopWorld = null


func activate() -> void:
	if camera != null:
		camera.make_current()
	if RunState.is_preparation():
		CursorKit.use_build()
	else:
		CursorKit.use_attack()
	if hero != null:
		# Preparation is safe construction time, but it is still a playable view.
		# The hero remains the active local avatar so the player can inspect roads,
		# brace torches and move between build sites while the formation is paused.
		hero.set_active(RunState.is_command_combat() or RunState.is_preparation())

## Placed towers, keyed by footprint anchor. Replaces the fixed slot nodes:
## with free placement there is nothing to pre-instantiate, so towers appear and
## disappear as RunState changes and this dictionary is how they are found again.
var _towers: Dictionary = {}
var _suspended: bool = false

## Lane pressure, 0..1, recomputed on a slow tick rather than every frame.
var _pressure: Array[float] = []
var _pressure_timer: float = 0.0
var _feedback_root: Node2D = null

const PRESSURE_INTERVAL: float = 0.2

## Draw layers. Compared before y position, so the floor can never be sorted
## above a unit and a unit can never sink beneath the floor.
const Z_GROUND: int = -40
const Z_LANES: int = -30
const Z_SORTED: int = 0
const Z_CLOUDS: int = 30

## Road art, tiled along each cardinal lane only.
## The fallback path set. Regional production sets use the same 16-mask
## contract at 64px; a missing region still resolves through these files.
const PATH_TILE_FORMAT: String = "res://art/battlefield/path_tile_%02d.png"

## The same set, per region. Derived from the terrain id exactly the way every
## other asset path in the project is derived from an id (CLAUDE.md SS4), so
## giving an act its own road is dropping sixteen files in - no manifest lookup,
## no code change. Falls back to PATH_TILE_FORMAT for any region without a set,
## which is how one act can be re-skinned without breaking the other two.
const PATH_TILE_REGION_FORMAT: String = "res://art/battlefield/path_%s_%02d.png"

## The region's corner (Wang) ground set. Derived from the terrain id, like every
## other asset path in the project. Absent means the region falls back to a
## single repeating tile.
const GROUND_TILE_FORMAT: String = "res://art/terrain/ground_%s_%02d.png"
const PATH_TILE_PIXELS: int = 64

## The carriageway, three tiles across in the authored layout.
const ROAD_CELL: int = BattleGrid.ROAD_WIDTH_TILES

## Fraction of a path tile its painted road actually covers across the road.
## The rest is the shoulder, which is transparent and shows the terrain.
const ROAD_ART_SPAN: float = 0.5

## World size of one road piece, so its painted surface is exactly a carriageway.
const PIECE: float = BattleGrid.TILE * float(ROAD_CELL) / ROAD_ART_SPAN

## Texture pixels per world unit in the baked road surface.
##
## Regional sources are 64px across and the bake holds each source pixel on an
## exact 3x grid (384 world units * 0.5 = 192 output pixels). Every road distance
## is a multiple of a 64-unit grid cell, so pieces and partial runs still land on
## whole texture pixels and cannot open a seam between independently laid pieces.
const ROAD_BAKE_PPU: float = 0.5

var _path_tiles: Array = []
var _path_variants_cache: Dictionary = {}

## Counts torches actually built, so the every-Nth light and shadow rules stay
## evenly spread after the minimum-gap filter has removed some.
var _torch_index: int = 0
var _ground_tiles_cache: Array = []
var _ground_variants_cache: Dictionary = {}
var _ground_cache_id: String = ""

## How much wider the road is than the walkable lane, so enemies travel on it
## rather than beside it.
const LANE_ROAD_SCALE: float = 1.72

## Road colour. Alpha and darkening both live in Balance because both of them
## are "can you see the lane", which is a tuning question and was answered wrong
## once already.
static func lane_road_tint() -> Color:
	var shade: float = Balance.PATH_DARKEN
	var warm: Color = Balance.PATH_WARMTH
	return Color(warm.r * shade, warm.g * shade, warm.b * shade, Balance.PATH_TINT_ALPHA)


## The tile grid and the four bent roads (GDD §13). Built before anything that
## reads geometry, because the road art, the spawn points and enemy pathing all
## come off it now instead of off a straight line from the spawn radius.
var grid: BattleGrid = null

## Draws the build footprint under the mouse and turns a click into an anchor.
var placement: PlacementCursor = null


func _ready() -> void:
	_pressure.resize(Balance.LANE_COUNT)
	_setup_sorting()
	_build_feedback_root()
	_setup_lighting()
	_setup_ground()
	grid = BattleGrid.new()
	_build_lanes()
	EventBus.tower_changed.connect(_on_tower_changed)
	placement = PlacementCursor.new()
	placement.name = "PlacementCursor"
	placement.setup(self)
	slot_root.add_child(placement)
	_build_torches()
	_build_foliage()
	wave_director.battlefield = self
	wave_director.stop()
	# Spells and the melee arc both need to find enemies, and the hero must not
	# go looking up the tree for the scope it happens to be sitting in.
	if hero != null:
		hero.field = self
		# Set from the grid rather than authored in the scene, so the playable
		# area follows the map instead of having to be remembered whenever the
		# map changes. It was not remembered: the scene still carried an 880
		# circle from the 30x30 field.
		hero.bounds_extent = Vector2.ONE * (BattleGrid.HALF_EXTENT - BattleGrid.TILE)
	# The partner's hero, when there is one. Created unconditionally and inert in
	# a single-player run: it spawns nothing, sends nothing and costs one early
	# return per physics frame. A system that only exists in co-op is a system
	# that only gets exercised in co-op.
	_coop_heroes = CoopHeroes.new()
	_coop_heroes.name = "CoopHeroes"
	_coop_heroes.field = self
	add_child(_coop_heroes)
	_coop_world = CoopWorld.new()
	_coop_world.name = "CoopWorld"
	_coop_world.field = self
	add_child(_coop_world)
	# Transient effects are parented into the scope that owns them, so leaving
	# the battlefield takes its sparks with it.
	Vfx.bind_world(_feedback_root if _feedback_root != null else self)


func _process(delta: float) -> void:
	_pressure_timer -= delta
	if _pressure_timer <= 0.0:
		_pressure_timer = PRESSURE_INTERVAL
		_update_pressure()


# --- Suspension -------------------------------------------------------------

## Freezes the entire scope exactly as it is. Used when the player enters a raid
## or a crossroad; resuming continues the wave mid-flight (GDD §6.3).
func suspend() -> void:
	if _suspended:
		return
	_suspended = true
	if hero != null:
		hero.set_active(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false


func resume() -> void:
	if not _suspended:
		return
	_suspended = false
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true


func is_suspended() -> bool:
	return _suspended


func enter_preparation() -> void:
	# The precondition below is a real one and was silently false on the crossroad
	# path: Preparation opened on a living pack, which then ate the towers during
	# the phase that exists to be safe.
	#
	# Printed rather than pushed as a warning. The structural guard is
	# `Run._road_is_busy`, which both the crossroad and the boss now ask before
	# opening Preparation, and the gate is `_test_crossroad_waits_for_the_road`.
	# This line is the third layer, and a third layer that fails the release build
	# every time a test constructs a deliberately impossible field is a check that
	# gets deleted rather than read.
	if enemy_count() > 0:
		print("[battlefield] Preparation opened with %d enemies still standing: %s"
			% [enemy_count(), living_enemy_summary()])
	wave_director.stop()
	# EntityRoot also owns the battlefield Hero. Preparation only starts after
	# WaveDirector has proved its queue and living-enemy count are empty, while
	# Tower._process already gates itself on command combat. Keeping this branch
	# live restores movement without allowing a hidden formation to advance.
	entity_root.process_mode = Node.PROCESS_MODE_INHERIT
	effect_root.process_mode = Node.PROCESS_MODE_DISABLED
	if hero != null:
		hero.set_active(true)
	if visible:
		CursorKit.use_build()


func begin_battle() -> void:
	entity_root.process_mode = Node.PROCESS_MODE_INHERIT
	effect_root.process_mode = Node.PROCESS_MODE_INHERIT
	if RunState.wave_number == 0:
		wave_director._wave_timer = minf(wave_director._wave_timer,
			Balance.ROAD_START_WARNING_SECONDS)
	wave_director.start()
	if hero != null and visible:
		hero.set_active(true)
	if visible:
		CursorKit.use_attack()


## Draw order.
##
## The previous version enabled y-sorting on the battlefield root, which made the
## *ground* a sorting participant. The ground sits at y=0 and covers everything,
## so any unit above the origin sorted behind it and disappeared underneath. That
## is the bug where the hero vanished walking north.
##
## The fix is a layer split. Only things that should sort against each other go
## in the sorted layer; the floor is pushed below it by z_index and never sorts
## at all. z_index is compared before y position, so a lower layer can never be
## overtaken by a unit's position no matter where it stands.
func _setup_sorting() -> void:
	# The root must NOT sort: it holds the floor.
	y_sort_enabled = false

	if ground != null:
		ground.y_sort_enabled = false
		ground.z_index = Z_GROUND
	if lane_root != null:
		lane_root.y_sort_enabled = false
		lane_root.z_index = Z_LANES

	# Towers, units and ground effects share one sorted parent so they interleave
	# by depth. Separate parents cannot sort against each other: each group sorts
	# internally, then the groups stack by tree order.
	var sorted := Node2D.new()
	sorted.name = "Sorted"
	sorted.y_sort_enabled = true
	sorted.z_index = Z_SORTED
	add_child(sorted)

	for node: Node2D in [slot_root, entity_root, effect_root]:
		if node == null:
			continue
		var previous: Node = node.get_parent()
		if previous != null:
			previous.remove_child(node)
		sorted.add_child(node)
		# Children of a y-sorted node must themselves sort, and must share a
		# z_index, or z wins and the sorting is decorative.
		node.y_sort_enabled = true
		node.z_index = 0


## Command and construction feedback remains live during Preparation while the
## entity and projectile layers are frozen. Keeping presentation separate is
## what prevents a build burst from waiting until Ride On to suddenly appear.
func _build_feedback_root() -> void:
	_feedback_root = Node2D.new()
	_feedback_root.name = "FeedbackRoot"
	_feedback_root.y_sort_enabled = true
	_feedback_root.z_index = 0
	var sorted: Node = slot_root.get_parent() if slot_root != null else self
	sorted.add_child(_feedback_root)


## A CanvasModulate tints everything under it, which is what turns the day/night
## phase into an actual look rather than a number on the HUD.
func _setup_lighting() -> void:
	var modulate_node := CanvasModulate.new()
	modulate_node.name = "DayTint"
	add_child(modulate_node)
	DayNight.phase_changed.connect(
		func(_p: float, tint: Color, _d: float) -> void:
			modulate_node.color = Graphics.graded(tint))
	modulate_node.color = Graphics.graded(DayNight.tint)
	# Grouped so `Graphics.apply_to_scene` can re-grade a field that is already
	# standing. Without it, changing brightness from the pause menu does nothing
	# until the next battlefield is built - which is the one moment a player is
	# most likely to reach for the setting.
	modulate_node.add_to_group(Graphics.TINT_GROUP)

	# Above the sorted layer so a passing shadow darkens the units standing in it,
	# not only the ground under them.
	# A full-field scrolling noise shader. Pure atmosphere, and the first thing a
	# player chasing frames should be able to switch off.
	# Built once and hidden by the quality setting. That makes the switch fully
	# reversible during a run instead of requiring the next battlefield scene.
	var clouds := CloudShadows.new()
	clouds.name = "CloudShadows"
	clouds.z_index = Z_CLOUDS
	clouds.visible = Graphics.cloud_shadows()
	add_child(clouds)

	# Contact shadows follow the sun, and the sun follows the beast walking.
	ShadowKit.attach_sun(self)

	if town != null:
		# No shadows on this one, and the reason is worth keeping.
		#
		# It is a 620px light with a dozen small occluders wandering around inside
		# it, and Godot's 2D shadows are hard-edged wedges that run all the way to
		# the light's rim. Every enemy near the town therefore painted a spoke
		# across half the battlefield, and thirteen-tap filtering fanned each spoke
		# into several. The result was a red starburst the size of the map.
		#
		# Cast shadows want *small, local* lights. The torches are exactly that,
		# and they are where the effect actually reads.
		LightKit.add_light(town, Balance.TOWN_LIGHT_COLOUR,
			Balance.TOWN_LIGHT_RADIUS, Balance.TOWN_LIGHT_ENERGY, 0.05)


## Shots are parented to the effect layer, not to the tower, so selling a tower
## mid-flight does not delete its shot.
func add_projectile(shot: Projectile, at: Vector2) -> void:
	effect_root.add_child(shot)
	shot.global_position = at


## Torches down both sides of every road: three stops each side, four roads,
## twenty-four in total.
##
## The stops are explicit distances rather than an even division of the road,
## because an even division put them level with the build spots — a torch beside
## a tower fights it for attention and sits over the thing the player is trying
## to click. TORCH_ALONG_STOPS threads them through the gaps instead, and
## TORCH_LANE_OFFSET stands them well back from both.
## Torches stand on the road's *shoulder*, following the bend.
##
## They used to be placed on a straight line out from the town, which was right
## when the roads were straight and puts them in the middle of the carriageway
## now. Walking the polyline keeps them beside the road the whole way round,
## symmetrically on both sides, and evenly spaced by arc length rather than by
## distance from the origin - on a bent road those are not the same thing.
##
## The shoulder is deliberately *on* the road surface, just outside the corridor
## enemies walk down. Road ground is unbuildable, so a torch there can never
## stand where the player wanted a tower, and the light still falls across the
## path it is meant to light.
## The two towers whose adjacency would fuse into `combo` on `anchor`, or an
## empty array when that pair is not flanking this tile (GDD v4 SS13).
##
## Fusion is a property of *where you built*, not a menu: two finished towers
## either side of an empty plot offer their combination there and nowhere else.
## `RunState` owns what has been built and answers which pairs flank a tile; this
## is the battlefield-side name for that question, so callers asking "can these
## two fuse here" have one place to ask rather than assembling it from parts.
func fusion_pair_for(anchor: Vector2i, combo: TowerData) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if combo == null or not combo.is_combination:
		return empty
	for option: Dictionary in RunState.combinations_for_tile(anchor):
		if (option["tower"] as TowerData) != combo:
			continue
		return [option["a"] as Vector2i, option["b"] as Vector2i] as Array[Vector2i]
	return empty


func _build_torches() -> void:
	if grid == null:
		return
	# One torch per corridor, and every one of them lit.
	#
	# The previous scheme placed a dense row along each lane and then, for frame
	# rate, gave only one torch in two an actual light. That is the worst of both
	# trades: more sprites *and* less light, and it produced exactly what was
	# reported - stretches of road lined with torches that were nonetheless dark,
	# because the lit ones were somewhere else.
	#
	# A corridor is about 450 units long and a torch pool reaches 360, so one at
	# the middle of each covers it, and there is no unlit prop anywhere.
	var wanted: Array[Vector2] = _torch_candidates()
	var kept: Array[Vector2] = []
	var claimed: Dictionary = {}
	for at: Vector2 in wanted:
		if claimed.has(_orbit_key(at)):
			continue
		# Accepted or rejected as a quarter-turn orbit, never one at a time. The
		# map is four-fold symmetric and the lighting has to be too; deciding per
		# torch lets a crowding rule keep one road's post and drop the matching
		# one on the road beside it, which reads as sloppiness rather than as a
		# rule.
		var orbit: Array[Vector2] = []
		for turn: int in Balance.LANE_COUNT:
			orbit.append(at.rotated(TAU * float(turn) / float(Balance.LANE_COUNT)))
		for member: Vector2 in orbit:
			claimed[_orbit_key(member)] = true
		if not _orbit_is_clear(orbit, kept):
			continue
		for member: Vector2 in orbit:
			kept.append(member)
			_place_torch(_lane_of(member), member)


## One position per corridor, on whichever side faces away from the town.
##
## Outward rather than "the first side that is open", because outward is the same
## choice under a quarter turn and "first" is not — that alone made the field
## asymmetric.
func _torch_candidates() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var done: Dictionary = {}
	for node: Vector2i in grid.lattice_nodes():
		for other: Vector2i in grid.lattice_neighbours(node):
			var key: String = "%d|%d" % [
				mini(_key(node), _key(other)), maxi(_key(node), _key(other))]
			if done.has(key):
				continue
			done[key] = true
			var middle: Vector2 = BattleGrid.tile_to_world(node).lerp(
				BattleGrid.tile_to_world(other), 0.5)
			var across: Vector2 = (BattleGrid.tile_to_world(other)
				- BattleGrid.tile_to_world(node)).normalized().orthogonal()
			if across.dot(middle) < 0.0:
				across = -across
			var at: Vector2 = middle + across * Balance.TORCH_LANE_OFFSET
			if grid.cell_at(BattleGrid.world_to_tile(at)) != BattleGrid.Cell.OPEN:
				at = middle - across * Balance.TORCH_LANE_OFFSET
			if grid.cell_at(BattleGrid.world_to_tile(at)) == BattleGrid.Cell.OPEN:
				out.append(at)
	return out


## A rotation-stable identity for a candidate, so an orbit is only decided once.
static func _orbit_key(at: Vector2) -> String:
	return "%d,%d" % [roundi(at.x), roundi(at.y)]


func _orbit_is_clear(orbit: Array[Vector2], kept: Array[Vector2]) -> bool:
	for i: int in orbit.size():
		if grid.cell_at(BattleGrid.world_to_tile(orbit[i])) != BattleGrid.Cell.OPEN:
			return false
		for other: Vector2 in kept:
			if orbit[i].distance_to(other) < Balance.TORCH_MIN_GAP:
				return false
		for j: int in range(i + 1, orbit.size()):
			if orbit[i].distance_to(orbit[j]) < Balance.TORCH_MIN_GAP:
				return false
	return true


## Which road a point belongs to, for torch bookkeeping and snuff pressure.
func _lane_of(at: Vector2) -> int:
	var best: int = 0
	var nearest: float = -INF
	for lane: int in Balance.LANE_COUNT:
		var along: float = at.dot(BattleGrid.lane_vector(lane))
		if along > nearest:
			nearest = along
			best = lane
	return best


func _crowds(at: Vector2, placed: Array[Vector2]) -> bool:
	for other: Vector2 in placed:
		if at.distance_to(other) < Balance.TORCH_MIN_GAP:
			return true
	return false


func _place_torch(lane: int, at: Vector2) -> void:
	var torch := Torch.new()
	torch.lane = lane
	torch.position = at
	# Every torch lights. The quality tier decides whether it also *casts*, which
	# is the expensive half; a light with no shadow is cheap and is what stops the
	# road going dark between posts.
	torch.carries_light = true
	torch.shadow_on_ultra_only = _torch_index % Balance.TORCH_FEATURED_SHADOW_EVERY != 0
	_torch_index += 1
	entity_root.add_child(torch)


## A point a given distance along a polyline, with the local heading there.
func _point_along(path: PackedVector2Array, distance: float) -> Dictionary:
	var walked: float = 0.0
	for i: int in path.size() - 1:
		var span: float = path[i].distance_to(path[i + 1])
		if walked + span >= distance and span > 0.0:
			var t: float = (distance - walked) / span
			return {
				"at": path[i].lerp(path[i + 1], t),
				"direction": (path[i + 1] - path[i]).normalized(),
			}
		walked += span
	var last: int = path.size() - 1
	return {
		"at": path[last],
		"direction": (path[last] - path[maxi(last - 1, 0)]).normalized(),
	}


func _build_foliage() -> void:
	var foliage := Foliage.new()
	foliage.name = "Foliage"
	# Assigned before it enters the tree: the first scatter runs on ready and has
	# to know where the roads are.
	foliage.grid = grid
	# In the sorted layer so a plant in front of the hero occludes them and one
	# behind does not.
	entity_root.add_child(foliage)


## 0..1, how dark a lane is. Dimming is continuous, so pressure grows before the
## last flame goes out rather than jumping six binary steps.
func lane_darkness(lane: int) -> float:
	var total: int = 0
	var light: float = 0.0
	for node: Node in get_tree().get_nodes_in_group(Torch.GROUP):
		var torch := node as Torch
		if torch == null or torch.lane != lane:
			continue
		total += 1
		light += torch.light_strength()
	return 1.0 - light / float(total) if total > 0 else 0.0


# --- Lane geometry ----------------------------------------------------------

## Lane 0 = north, then clockwise: east, south, west.
static func lane_vector(lane: int) -> Vector2:
	return Vector2.UP.rotated(TAU * float(lane) / float(Balance.LANE_COUNT))


func lane_direction(lane: int) -> Vector2:
	return lane_vector(lane)


## Where a lane's enemies appear: the head of its road.
##
## Static for the callers that have no field handy; those get the straight-line
## radius, which is the same point the road starts from. `road_spawn_point`
## below is the exact one and is what the field itself uses.
static func lane_spawn_point(lane: int) -> Vector2:
	return lane_vector(lane) * Balance.LANE_SPAWN_RADIUS


func road_spawn_point(lane: int) -> Vector2:
	if grid == null:
		return lane_spawn_point(lane)
	var path: PackedVector2Array = grid.lane_paths[lane]
	return path[0]


## The road a lane's enemies walk, spawn to gate.
func lane_path(lane: int) -> PackedVector2Array:
	if grid == null:
		return PackedVector2Array([lane_spawn_point(lane), Vector2.ZERO])
	return grid.lane_paths[lane]


## One of the ways in from this lane's spawn, drawn per enemy.
##
## Rolled from the combat stream so a seeded replay sends the same enemy down the
## same corridor. The bias toward shorter routes lives in the grid; this only
## supplies the roll.
func lane_route(lane: int) -> PackedVector2Array:
	if grid == null:
		return lane_path(lane)
	return grid.route_for(lane, RunState.rng("combat").randf())


static func slot_position(lane: int, slot: int) -> Vector2:
	var direction: Vector2 = lane_vector(lane)
	var along: float = Balance.TOWER_SLOT_RADII[clampi(slot, 0, Balance.TOWER_SLOT_RADII.size() - 1)]
	# Both flanks of the road are built on now, so the side comes from which trio
	# the spot belongs to. It used to come from whether the spot was the
	# combination one, which put the middle spot opposite its own neighbours.
	return direction * along \
		+ direction.orthogonal() * Balance.TOWER_SLOT_OFFSET * Balance.slot_side_sign(slot)


func town_position() -> Vector2:
	return town.global_position if town != null else Vector2.ZERO


func town_node() -> Node2D:
	return town


## The partner's hero, or null when playing alone.
##
## `hero` stays "the hero this player drives" everywhere it is already used —
## the camera target, the HUD's subject, the one the vignette follows. Renaming
## that to mean "either hero" would have been the change that quietly broke
## every one of those.
func partner_hero() -> Hero:
	return _coop_heroes.partner() if _coop_heroes != null else null


## Both heroes on the field, in a single-player run just the one.
func heroes() -> Array[Hero]:
	var found: Array[Hero] = []
	if hero != null:
		found.append(hero)
	var second: Hero = partner_hero()
	if second != null:
		found.append(second)
	return found


func hero_node() -> Node2D:
	return hero


func hero_is_alive() -> bool:
	return hero != null and hero.is_alive()


## Body radius of anything an enemy might walk up to and hit.
func target_radius(node: Node2D) -> float:
	if node == town:
		return town.radius()
	if node == hero:
		return hero.contact_radius()
	return 40.0


# --- Queries ----------------------------------------------------------------

## The taunting tower in a lane, if one is built and still standing.
func taunting_tower_in_lane(lane: int) -> Node2D:
	for tower: Tower in all_towers():
		if tower.lane() == lane and tower.data != null and tower.data.taunts:
			return tower
	return null


## Nearest live structure on this road. A stable nearest-target rule makes
## siege enemies legible: they attack what they visibly reach instead of
## changing targets because a farther tower happens to be more damaged.
func vulnerable_tower_in_lane(lane: int, from: Vector2) -> Node2D:
	var nearest: Tower = null
	var nearest_squared: float = INF
	for built: Tower in all_towers():
		if built.lane() != lane or not built.is_vulnerable():
			continue
		var distance_squared: float = built.global_position.distance_squared_to(from)
		if distance_squared < nearest_squared:
			nearest = built
			nearest_squared = distance_squared
	return nearest


func lane_pressure(lane: int) -> float:
	return _pressure[lane] if lane >= 0 and lane < _pressure.size() else 0.0


func lane_armour(lane: int) -> float:
	var total: float = 0.0
	for built: Tower in all_towers():
		if built.lane() != lane or built.data == null:
			continue
		total += built.data.lane_armour_bonus * built.data.utility_at(built.level) \
			* Balance.TOWER_ARMOUR_EFFECT_SCALE
	return total + Modifiers.value(Modifiers.TOWER_ARMOUR)


# --- Spawning ---------------------------------------------------------------

func spawn_enemy(data: EnemyData, lane: int, hp_scale: float,
		damage_scale: float = -1.0, speed_scale: float = 1.0) -> Enemy:
	if enemy_scene == null:
		return null
	var enemy := enemy_scene.instantiate() as Enemy
	if enemy == null:
		return null
	enemy.setup(data, lane, self, hp_scale, damage_scale, speed_scale)
	var spread: Vector2 = lane_vector(lane).orthogonal() \
		* RunState.rng("combat").randf_range(-Balance.LANE_WIDTH, Balance.LANE_WIDTH) * 0.5
	# Spawn on the head of the road. `spawn_distance_scale` still pulls certain
	# breeds in closer, but it now slides them *along the road* rather than along
	# a straight line that the road no longer follows.
	enemy.position = road_spawn_point(lane) * data.spawn_distance_scale + spread
	entity_root.add_child(enemy)
	# Announced *after* it is in the tree, so the position the guest is told is
	# the one it actually spawned at. Does nothing in a single-player run, and
	# nothing on a guest - which is what stops a mirrored enemy being announced
	# back and spawning a mirror of a mirror.
	if _coop_world != null:
		_coop_world.announce_enemy(enemy)
	return enemy


## Placeholder VFX. A line that fades is not art — it is the readout that a
## tower fired at something, and it gets replaced wholesale when real effects
## exist (see ASSET_MANIFEST §7).
## How close the nearest living enemy has come to the town.
##
## The wave watchdog's measure of progress. INF when the road is clear, which
## reads as "no longer waiting on anything".
## Drops a collectable reward on the field.
##
## Parented into the effect root rather than the sorted layer: a coin is feedback,
## not a participant, and y-sorting it against units would have it flicker in
## front of and behind whatever it landed next to.
func spawn_loot(currency: String, amount: int, at: Vector2) -> void:
	if amount <= 0:
		return
	var drop := LootDrop.new()
	drop.setup(currency, amount, at)
	(_feedback_root if _feedback_root != null else self).add_child(drop)


func spawn_gear(piece: Dictionary, at: Vector2) -> void:
	if piece.is_empty():
		return
	var drop := LootDrop.new()
	drop.setup_gear(piece, at)
	(_feedback_root if _feedback_root != null else self).add_child(drop)


func nearest_enemy_distance() -> float:
	var nearest: float = INF
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dying():
			nearest = minf(nearest, enemy.global_position.length())
	return nearest


## Aggregate health across both sides of the live wave. Any material change
## means combat is resolving even if the nearest ranged attacker is stationary.
func wave_activity_checksum() -> float:
	var total: float = town.health.current_hp if town != null and town.health != null else 0.0
	for group: StringName in [Enemy.GROUP, Tower.GROUP]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node):
				continue
			var health: Health = Health.of(node)
			if health != null and not health.is_dead:
				total += health.current_hp
	return total


## Last-resort recovery after the activity watchdog proves a formation cannot
## move, deal damage or take damage. Resolving through Health keeps death
## rewards, counts and VFX on the normal path and removes every enemy from the
## live group synchronously before Preparation can open.
func resolve_stalled_wave() -> int:
	var resolved: int = 0
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
			continue
		var health: Health = Health.of(enemy)
		if health != null:
			health.kill(town_position())
			resolved += 1
	return resolved


func spawn_tracer(from: Vector2, to: Vector2, colour: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 3.0
	line.default_color = colour
	effect_root.add_child(line)
	var tween: Tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.14)
	tween.tween_callback(line.queue_free)


func spawn_ground_zone(at: Vector2, dps: float, duration: float, radius: float,
		element: int = 0) -> void:
	var zone := GroundZone.new()
	zone.configure(dps, duration, radius, self, element)
	zone.position = at
	effect_root.add_child(zone)


# --- Build API (called by the UI) -------------------------------------------

## Returns "" on success, or a reason the build was refused.
##
## `anchor` is the top-left tile of the 2x2 footprint. Placement is free: any
## four open off-path tiles will do, and there is no cap on how many towers a
## run may stand up (GDD §13).
func try_build(anchor: Vector2i, tower_data: TowerData) -> String:
	if not RunState.can_build_now():
		return "Construction is locked until Preparation."
	if tower_data == null:
		return "No tower selected."
	var refusal: String = placement_problem(anchor)
	if not refusal.is_empty():
		return refusal

	if tower_data.is_combination:
		var offered: Array[Dictionary] = RunState.combinations_for_tile(anchor)
		var allowed: bool = false
		for option: Dictionary in offered:
			if option["tower"] == tower_data:
				allowed = true
		if not allowed:
			return "Nothing beside this tile fuses into %s." % tower_data.display_name

	var build_cost: Dictionary = cost_of(tower_data)
	if not RunState.can_afford_cost(build_cost):
		return "Needs %s." % RunState.format_cost(build_cost)
	RunState.spend_cost(build_cost)
	RunState.set_tower(anchor, tower_data.id, 1)
	RunState.towers_built += 1
	Vfx.build_burst(BattleGrid.footprint_centre(anchor),
		TowerData.element_colour(tower_data.element))
	return ""


## Why a 2x2 tower cannot stand here, or "".
##
## Two separate questions, because two different objects own the answers: the
## grid knows the map (roads, town, border) and RunState knows what has already
## been built. Asking one object about both is how the two end up disagreeing.
func placement_problem(anchor: Vector2i) -> String:
	if grid == null:
		return "The battlefield is not ready."
	if not grid.footprint_is_open(anchor):
		return "That ground cannot be built on."
	for tile: Vector2i in BattleGrid.footprint_tiles(anchor):
		if not _occupied_anchors_touching(tile).is_empty():
			return "That space is taken."
	return ""


## Every placed tower whose footprint covers this tile.
func _occupied_anchors_touching(tile: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	# A 2x2 tower covering `tile` can only be anchored within one tile of it.
	for dx: int in range(-BattleGrid.FOOTPRINT + 1, 1):
		for dy: int in range(-BattleGrid.FOOTPRINT + 1, 1):
			var candidate: Vector2i = tile + Vector2i(dx, dy)
			if not RunState.tile_is_empty(candidate):
				found.append(candidate)
	return found


func try_upgrade(anchor: Vector2i) -> String:
	if not RunState.can_build_now():
		return "Upgrades are locked until Preparation."
	var tower_data: TowerData = RunState.tower_at(anchor)
	if tower_data == null:
		return "Nothing built there."
	var level: int = RunState.level_at(anchor)
	if level >= Balance.TOWER_MAX_LEVEL:
		return "Already at maximum level."
	if level >= RunState.tower_level_cap():
		return "Upgrade the Forge to unlock tower level %d." % (level + 1)
	var cost: int = upgrade_cost_of(level)
	if not RunState.can_afford_cost({RunState.GOLD: cost}):
		return "Needs %d Gold." % cost
	RunState.spend_cost({RunState.GOLD: cost})
	RunState.set_tower(anchor, tower_data.id, level + 1)
	RunState.tower_upgrades += 1
	return ""


## Build and upgrade prices after relics. One place, so the UI quotes exactly
## what the purchase will charge.
static func build_cost_of(tower_data: TowerData) -> int:
	var scale: float = maxf(1.0 + Modifiers.value(Modifiers.BUILD_COST), 0.25)
	return maxi(int(round(float(tower_data.build_cost()) * scale)), 1)


## Everything a tower costs to place, after relics. One function, so the price
## the HUD quotes and the price actually charged cannot drift apart - they were
## assembled separately before and only one of them knew about the secondary
## currency each element draws on.
static func cost_of(tower_data: TowerData) -> Dictionary:
	var scale: float = maxf(1.0 + Modifiers.value(Modifiers.BUILD_COST), 0.25)
	var cost: Dictionary = {}
	for key: Variant in tower_data.build_cost_table():
		var id: String = String(key)
		var amount: int = int(tower_data.build_cost_table()[key])
		# Relics discount Gold only. A build-cost relic that also halved Stone
		# would quietly undo the point of a scarce second currency.
		cost[id] = maxi(int(round(float(amount) * scale)), 1) if id == RunState.GOLD else amount
	return cost


static func upgrade_cost_of(level: int) -> int:
	var base: int = TowerData.upgrade_cost(level)
	if base < 0:
		return -1
	var scale: float = maxf(1.0 + Modifiers.value(Modifiers.BUILD_COST), 0.25)
	return maxi(int(round(float(base) * scale)), 1)


func try_sell(anchor: Vector2i) -> String:
	if not RunState.can_build_now():
		return "Selling is locked until Preparation."
	var tower_data: TowerData = RunState.tower_at(anchor)
	if tower_data == null:
		return "Nothing built there."
	var level: int = RunState.level_at(anchor)
	var spent: int = build_cost_of(tower_data)
	for l: int in range(1, level):
		spent += upgrade_cost_of(l)
	RunState.gain_currency(RunState.GOLD,
		int(round(float(spent) * Balance.TOWER_SELL_REFUND)))
	# Every secondary currency comes back at its own rate, not just Stone.
	for key: Variant in tower_data.build_cost_table():
		var id: String = String(key)
		if id == RunState.GOLD:
			continue
		RunState.gain_currency(id, int(round(
			float(tower_data.build_cost_table()[key]) * Balance.TOWER_STONE_SELL_REFUND)))
	RunState.towers_sold += 1
	RunState.clear_tower(anchor)
	# Selling a fusion parent orphans the fusion. Refunded rather than left
	# standing at reduced output forever, because the player chose to remove it
	# and a silently crippled tower is worse than the Gold back.
	_refund_orphaned_fusions()
	return ""


## Any fusion whose flanking parents no longer stand is sold back.
func _refund_orphaned_fusions() -> void:
	var orphans: Array[Vector2i] = []
	for key: Variant in RunState.towers:
		var anchor: Vector2i = key
		var built: TowerData = RunState.tower_at(anchor)
		if built != null and built.is_combination 				and not RunState.fusion_parents_intact(anchor):
			orphans.append(anchor)
	for anchor: Vector2i in orphans:
		var built: TowerData = RunState.tower_at(anchor)
		RunState.gain_currency(RunState.GOLD,
			int(round(float(build_cost_of(built)) * Balance.TOWER_SELL_REFUND)))
		RunState.gain_currency(RunState.STONE,
			int(round(float(Balance.TOWER_COMBO_STONE_COST) * Balance.TOWER_STONE_SELL_REFUND)))
		RunState.clear_tower(anchor)


## Field rations between formations.
##
## Reported: "the player should also have some way of being able to restore
## health and regenerate health". Before this there were three, and all of them
## were somebody else's decision: Hearthmend, three times a run and only before
## an act boss; a spell, if the build happened to include one; and a wound
## revive, which costs a Wound. Across a whole road the hero simply attritted.
##
## Deliberately shaped like Repair Town rather than as a new system: Preparation
## only, a flat amount for a flat price, and paid in Food, which v4's economy
## table (§691) already assigns to hero upkeep. It cannot be spammed mid-fight
## and it competes with the same Preparation budget as everything else.
func try_tend_hero() -> String:
	if not RunState.can_build_now():
		return "The hero is tended between road battles."
	if hero == null or hero.health == null:
		return "The hero cannot be reached."
	if hero.health.current_hp >= hero.health.max_hp:
		return "The hero is already whole."
	if not RunState.can_afford_cost({RunState.FOOD: Balance.HERO_TEND_COST}):
		return "Needs %d Food." % Balance.HERO_TEND_COST
	RunState.spend_cost({RunState.FOOD: Balance.HERO_TEND_COST})
	# A fraction of maximum, so it stays worth buying once Wounds have cut the
	# ceiling and a flat number would be most of a bar.
	hero.health.heal(hero.health.max_hp * Balance.HERO_TEND_FRACTION)
	Vfx.ring(hero.global_position, 90.0, Color(0.62, 0.9, 0.72, 0.6), 0.45, 5.0)
	Vfx.spark(hero.global_position, Color("cdf0d6"), 14, Vector2.UP, 150.0)
	Sfx.play("sfx_tower_upgrade", -5.0)
	return ""


func try_repair_town() -> String:
	if not RunState.can_build_now():
		return "Repairs are prepared between road battles."
	if town == null or town.health == null:
		return "The town cannot be reached."
	if town.health.current_hp >= town.health.max_hp:
		return "The town is already whole."
	if not RunState.can_afford_cost({RunState.WOOD: Balance.TOWN_REPAIR_COST}):
		return "Needs %d Wood." % Balance.TOWN_REPAIR_COST
	RunState.spend_cost({RunState.WOOD: Balance.TOWN_REPAIR_COST})
	town.health.heal(Balance.TOWN_REPAIR_AMOUNT)
	Vfx.ring(town.global_position, Balance.TOWN_RADIUS * 1.3,
		Color(0.55, 0.88, 0.68, 0.65), 0.55, 6.0)
	Vfx.spark(town.global_position, Color("b7e6c0"), 18, Vector2.UP, 180.0)
	Sfx.play("sfx_tower_upgrade", -3.0)
	return ""


func try_repair_tower(anchor: Vector2i) -> String:
	if not RunState.can_build_now():
		return "Tower repairs are prepared between road battles."
	var built: Tower = tower_at_anchor(anchor)
	if built == null:
		return "Nothing built there."
	if not built.needs_repair():
		return "That tower is already whole."
	if not RunState.can_afford_cost({RunState.WOOD: Balance.TOWER_REPAIR_WOOD_COST}):
		return "Needs %d Wood." % Balance.TOWER_REPAIR_WOOD_COST
	RunState.spend_cost({RunState.WOOD: Balance.TOWER_REPAIR_WOOD_COST})
	built.repair(Balance.TOWER_REPAIR_FRACTION)
	return ""


# --- Setup ------------------------------------------------------------------

## The floor is the act's terrain, tiled. Roads are *not* part of it — a lane is
## a strip of trodden ground running out along one cardinal, and everywhere else
## is open country.
## The act's terrain changed; re-skin the floor without rebuilding the scope.
func refresh_terrain() -> void:
	_setup_ground()
	# The road is regional too, so a new act re-lays it. Without this the ground
	# changed underfoot and the road stayed the previous region's.
	_path_tiles.clear()
	_path_variants_cache.clear()
	for piece: Node in lane_root.get_children():
		piece.queue_free()
	_build_lanes()


func _setup_ground() -> void:
	if ground == null:
		return
	# Sized against the visible area, not the arena: at CAMERA_ZOOM_BATTLEFIELD
	# the viewport shows far more world than the lanes occupy, and anything the
	# floor does not reach renders as empty grey.
	var visible_half: float = maxf(1920.0, 1080.0) / Balance.CAMERA_ZOOM_BATTLEFIELD
	var extent: float = maxf(Balance.LANE_SPAWN_RADIUS * 1.4, visible_half)
	ground.centered = true
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	# Sample from texel centres so linear filtering cannot reveal a grid at the
	# repeating image boundaries. Unlike the former four-sample blend, this does
	# not average away the terrain painting or make the whole field darker.
	ground.material = TerrainSeam.material()

	# The region is in *texture* space and the sprite is scaled up afterwards, so
	# one repeat covers GROUND_UNITS_PER_TEXEL of world per source pixel.
	# One texel is one fixed slice of world, whatever size the floor art is. That
	# is what keeps the ground and the road at the same resolution when either
	# one is regenerated.
	var tile_scale: float = Balance.GROUND_UNITS_PER_TEXEL
	var half: float = extent / tile_scale
	ground.region_rect = Rect2(-half, -half, half * 2.0, half * 2.0)
	ground.scale = Vector2.ONE * tile_scale

	# Nearest, so the floor stays pixel art at the scale it is drawn.
	ground.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	ground.add_to_group(Graphics.FILTER_GROUP)

	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	var baked: ImageTexture = _bake_ground(extent)
	if baked != null:
		# A baked floor is already the whole field, so it must not repeat and it
		# is drawn 1:1 - the tiling happened at bake time.
		ground.texture = baked
		ground.region_enabled = false
		ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		ground.material = null
		ground.scale = Vector2.ONE * Balance.GROUND_UNITS_PER_TEXEL
	elif terrain != null and ResourceLoader.exists(terrain.get_sprite_path()):
		ground.texture = load(terrain.get_sprite_path())


## Bakes the region's floor from its corner (Wang) tileset.
##
## A single tile repeating is wallpaper: the eye finds the period within a second
## and the whole battlefield reads as graph paper. A corner set gives the region
## two materials - earth and moss, rock and snow - and sixteen tiles covering
## every way four corners can be one or the other, so which tile goes where is
## decided by a noise field rather than by position. The repeat lives in the
## *pattern* and there is nothing regular left for the eye to lock onto.
##
## Baked into one texture for the same reason the road is: as sprites the tiles
## abut in world space and the rasteriser rounds each quad on its own, so a
## hairline of background opens along some joins and which joins depends on the
## camera.
##
## Returns null when the region has no set, and the caller falls back to the
## single repeating tile - which is what every region had before this.
func _bake_ground(extent: float) -> ImageTexture:
	var tiles: Array = _ground_tiles()
	if tiles.is_empty():
		return null

	var tile_px: int = (tiles[0] as Image).get_width()
	var cells: int = int(ceil(extent * 2.0 / (float(tile_px) * Balance.GROUND_UNITS_PER_TEXEL)))
	cells = maxi(cells, 1)
	var canvas: Image = Image.create_empty(cells * tile_px, cells * tile_px,
		false, Image.FORMAT_RGBA8)

	# Seeded from the run, so a given seed always grows the same ground - the
	# debrief promises a seed reproduces the run, and the floor is part of that.
	var noise := FastNoiseLite.new()
	noise.seed = RunState.run_seed
	noise.frequency = Balance.GROUND_PATCH_FREQUENCY
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	var flipped: bool = terrain != null and terrain.moss_dominant

	for cy: int in cells:
		for cx: int in cells:
			# Corners are shared with the neighbouring cells by construction,
			# which is the whole trick: adjacent tiles agree on the corner they
			# share, so the two materials interlock instead of butting.
			var mask: int = 0
			const OFFSETS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0),
				Vector2i(1, 1), Vector2i(0, 1)]
			for bit: int in 4:
				var at: Vector2i = Vector2i(cx, cy) + OFFSETS[bit]
				if noise.get_noise_2d(float(at.x), float(at.y)) > Balance.GROUND_PATCH_THRESHOLD:
					mask |= 1 << bit
			# Read the other way round for regions whose upper material is the
			# common one: the tile for a mask's complement carries the opposite
			# material on exactly those corners, so this swaps which of the two
			# covers the field without needing a second tileset.
			if flipped:
				mask = 15 - mask
			# Eight legal rotations/reflections are available for every topology:
			# transform a different source mask into the requested one. That keeps
			# shared corners exact while ensuring large same-material patches do not
			# stamp the identical crack or root motif in one orientation.
			var transform_id: int = posmod(hash(Vector3i(cx, cy, RunState.run_seed)), 8)
			var piece: Image = _ground_variant(mask, transform_id)
			if piece == null:
				continue
			canvas.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()),
				Vector2i(cx * tile_px, cy * tile_px))
	return ImageTexture.create_from_image(canvas)


## The region's sixteen corner tiles, cached, indexed by corner mask.
func _ground_tiles() -> Array:
	if _ground_cache_id == RunState.terrain_id:
		return _ground_tiles_cache
	_ground_cache_id = RunState.terrain_id
	_ground_tiles_cache = []
	_ground_variants_cache.clear()
	for mask: int in 16:
		var path: String = GROUND_TILE_FORMAT % [RunState.terrain_id, mask]
		if not ResourceLoader.exists(path):
			_ground_tiles_cache = []
			return _ground_tiles_cache
		var image: Image = (load(path) as Texture2D).get_image()
		image.convert(Image.FORMAT_RGBA8)
		_ground_tiles_cache.append(image)
	return _ground_tiles_cache


## One of the eight dihedral transforms of a Wang tile, selected so the result's
## corner mask still equals `wanted_mask`. Cached once per region rather than
## rotating thousands of pixels every time the field is redrawn.
func _ground_variant(wanted_mask: int, transform_id: int) -> Image:
	var key: int = wanted_mask * 8 + transform_id
	if _ground_variants_cache.has(key):
		return _ground_variants_cache[key] as Image
	var source_mask: int = wanted_mask
	for candidate: int in 16:
		if _transform_ground_mask(candidate, transform_id) == wanted_mask:
			source_mask = candidate
			break
	var source: Image = _ground_tiles_cache[source_mask] as Image
	var result: Image = _transform_ground_image(source, transform_id)
	_ground_variants_cache[key] = result
	return result


static func _transform_ground_mask(mask: int, transform_id: int) -> int:
	const CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(1, 1), Vector2i(0, 1)]
	var out: int = 0
	for bit: int in 4:
		if (mask & (1 << bit)) == 0:
			continue
		var point: Vector2i = CORNERS[bit]
		for _turn: int in transform_id % 4:
			point = Vector2i(1 - point.y, point.x)
		if transform_id >= 4:
			point.x = 1 - point.x
		var output_bit: int = CORNERS.find(point)
		out |= 1 << output_bit
	return out


static func _transform_ground_image(source: Image, transform_id: int) -> Image:
	var side: int = source.get_width()
	var out: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	for sy: int in side:
		for sx: int in side:
			var point := Vector2i(sx, sy)
			for _turn: int in transform_id % 4:
				point = Vector2i(side - 1 - point.y, point.x)
			if transform_id >= 4:
				point.x = side - 1 - point.x
			out.set_pixelv(point, source.get_pixel(sx, sy))
	return out


## Four road strips, one per cardinal, from the town wall out to the spawn point.
## Each is the lane_path texture tiled along its own length and rotated onto the
## lane, so the road art only ever appears where a road actually is.
## Bakes the road into a single texture from an autotiled path set.
##
## Replaces four rotated strips, which could only ever draw a straight road and
## left a notch on the inside of every bend.
##
## Two decisions here were each arrived at the hard way.
##
## **Pieces follow the lane polyline, not a lattice.** A lattice is the obvious
## way to autotile and it cannot work: the U-bend turns at 7 and 13 tiles out and
## runs 8 deep, none of which is a multiple of the 3-tile carriageway, so
## quantising the road onto road-sized cells put every piece up to a tile off its
## own road and dropped a cell wherever the rounding went the other way. Those
## distances are tuned pocket geometry (see BattleGrid), so the renderer bends.
##
## **The pieces are composited into one image rather than left as sprites.** As
## sprites they abut in *world* space and the rasteriser rounds each quad to
## screen pixels on its own, so a hairline of terrain opens along some joins and
## which joins depends on the camera. Growing the pieces to overlap only moves
## the problem around. Compositing at a fixed whole-pixel scale settles it at the
## source, and it costs 28 draw calls rather than adding any.
func _build_lanes() -> void:
	if grid == null:
		return
	var extent: float = BattleGrid.HALF_EXTENT + PIECE
	var side: int = int(round(extent * 2.0 * ROAD_BAKE_PPU))
	var canvas: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)

	# Baked from the corridor lattice, not from the lane paths.
	#
	# The authored map forks and rejoins, so corridors are shared: several routes
	# and often several lanes run down the same stretch of road. Baking per route
	# would draw those stretches two and three times over, which costs nothing in
	# frames but does compound the tiles' alpha edges into a visible darker seam
	# wherever routes overlap. The lattice visits every junction and every
	# corridor exactly once, which is also simply what the road *is*.
	var done: Dictionary = {}
	for node: Vector2i in grid.lattice_nodes():
		var at: Vector2 = BattleGrid.tile_to_world(node)
		var mask: int = 0
		for other: Vector2i in grid.lattice_neighbours(node):
			mask |= _dir_bit(Vector2(other - node))
			var key: String = "%s|%s" % [mini(_key(node), _key(other)), maxi(_key(node), _key(other))]
			if done.has(key):
				continue
			done[key] = true
			_bake_corridor(canvas, extent, at, BattleGrid.tile_to_world(other))
		_bake_piece(canvas, extent, at, mask, Vector2(PIECE, PIECE))

	# The stubs out to the map edge, so enemies do not walk in over bare ground.
	for lane: int in Balance.LANE_COUNT:
		var path: PackedVector2Array = grid.lane_paths[lane]
		if path.size() >= 2:
			_bake_corridor(canvas, extent, path[0], path[1])

	var surface := Sprite2D.new()
	surface.name = "RoadSurface"
	surface.texture = ImageTexture.create_from_image(canvas)
	surface.centered = true
	surface.scale = Vector2.ONE / ROAD_BAKE_PPU
	# Nearest, or the road stops being pixel art the moment it reaches the screen.
	surface.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	surface.add_to_group(Graphics.FILTER_GROUP)
	lane_root.add_child(surface)


## A stable ordering key for a lattice node, so an edge can be deduplicated
## without caring which end it was reached from.
static func _key(node: Vector2i) -> int:
	return node.y * BattleGrid.SIZE + node.x


## Lays straight road between two junctions, stopping half a piece short of each
## so the junction tile itself is what covers the turn.
func _bake_corridor(canvas: Image, extent: float, from: Vector2, to: Vector2) -> void:
	var along: Vector2 = (to - from).normalized()
	var half: float = PIECE * 0.5
	var start: Vector2 = from + along * half
	var run: float = (to - along * half - start).dot(along)
	var laid: float = 0.0
	while run - laid > 1.0:
		# Whole pieces, and a slice of one for the remainder. Squashing a tile
		# into a short run instead would compress its surface detail, so the
		# road's grain would visibly change size between one bend and the next.
		var take: float = minf(PIECE, run - laid)
		_bake_piece(canvas, extent, start + along * (laid + take * 0.5),
			_straight_mask(along), _piece_size(along, take))
		laid += take


## A piece covering `take` along its own axis and a full carriageway across.
func _piece_size(along: Vector2, take: float) -> Vector2:
	var axis := Vector2(absf(along.x), absf(along.y))
	return Vector2(axis.y, axis.x) * PIECE + axis * take


## The straight that runs along `along`: both cardinals on that axis.
func _straight_mask(along: Vector2) -> int:
	return _dir_bit(along) | _dir_bit(-along)


## Which edge of a tile a cardinal direction leaves by, as an autotile bit.
func _dir_bit(dir: Vector2) -> int:
	if absf(dir.x) > absf(dir.y):
		return 2 if dir.x > 0.0 else 8
	return 1 if dir.y < 0.0 else 4


## Composites one piece of road surface into the canvas.
##
## The painted road covers half of each tile across, so a piece is drawn at twice
## the carriageway for its surface to come out the right width.
func _bake_piece(canvas: Image, extent: float, at: Vector2, mask: int, size: Vector2) -> void:
	# A legal rotation/reflection of an equivalent mask keeps every connection
	# exact while changing which scars and ruts face the eye. Long straights no
	# longer stamp one painting from town to map edge.
	var cell := Vector2i((at / BattleGrid.TILE).round())
	var transform_id: int = posmod(hash(Vector3i(cell.x, cell.y, RunState.run_seed)), 8)
	var src: Image = _path_variant(mask, transform_id)
	if src == null:
		return
	var whole: int = int(round(PIECE * ROAD_BAKE_PPU))
	var px := Vector2i((size * ROAD_BAKE_PPU).round())
	if px.x <= 0 or px.y <= 0:
		return
	var piece: Image = src.duplicate()
	piece.resize(maxi(px.x, whole), maxi(px.y, whole), Image.INTERPOLATE_NEAREST)
	var corner: Vector2 = at - size * 0.5 + Vector2(extent, extent)
	canvas.blend_rect(piece, Rect2i(Vector2i.ZERO, px),
		Vector2i((corner * ROAD_BAKE_PPU).round()))


## The path tiles as images, cached, indexed by autotile mask.
func _path_image(mask: int) -> Image:
	if _path_tiles.is_empty():
		for index: int in 16:
			var path: String = PATH_TILE_REGION_FORMAT % [RunState.terrain_id, index]
			if not ResourceLoader.exists(path):
				path = PATH_TILE_FORMAT % index
			if not ResourceLoader.exists(path):
				_path_tiles.append(null)
				continue
			var image: Image = (load(path) as Texture2D).get_image()
			# blend_rect needs a matching, uncompressed format.
			image.convert(Image.FORMAT_RGBA8)
			_path_tiles.append(image)
	if mask < 0 or mask >= _path_tiles.size():
		return null
	return _path_tiles[mask] as Image


## One of the eight legal dihedral transforms of an edge-connected path tile.
## The source mask is chosen so transforming it produces `wanted_mask`, keeping
## the canonical N/E/S/W contract while providing deterministic visual variety.
func _path_variant(wanted_mask: int, transform_id: int) -> Image:
	# Populate the source cache before indexing it.
	if _path_image(wanted_mask) == null:
		return null
	var key: int = wanted_mask * 8 + transform_id
	if _path_variants_cache.has(key):
		return _path_variants_cache[key] as Image
	var source_mask: int = wanted_mask
	for candidate: int in 16:
		if _transform_path_mask(candidate, transform_id) == wanted_mask:
			source_mask = candidate
			break
	var source: Image = _path_tiles[source_mask] as Image
	if source == null:
		return null
	var result: Image = _transform_ground_image(source, transform_id)
	_path_variants_cache[key] = result
	return result


static func _transform_path_mask(mask: int, transform_id: int) -> int:
	const EDGES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 1),
		Vector2i(1, 2), Vector2i(0, 1)]
	var out: int = 0
	for bit: int in 4:
		if (mask & (1 << bit)) == 0:
			continue
		var point: Vector2i = EDGES[bit]
		for _turn: int in transform_id % 4:
			point = Vector2i(2 - point.y, point.x)
		if transform_id >= 4:
			point.x = 2 - point.x
		var output_bit: int = EDGES.find(point)
		out |= 1 << output_bit
	return out


## Keeps the tower nodes in step with RunState.
##
## RunState is the source of truth (CLAUDE.md rule 6); this only ever reacts to
## it. That is why building, selling, refunding an orphaned fusion and a tower
## being destroyed all end up here through one signal rather than each spawning
## and freeing nodes for themselves.
func _on_tower_changed(anchor: Vector2i) -> void:
	var wanted: TowerData = RunState.tower_at(anchor)
	var existing: Tower = _towers.get(anchor, null) as Tower

	if wanted == null:
		if existing != null and is_instance_valid(existing):
			existing.queue_free()
		_towers.erase(anchor)
		_refresh_tower_modifiers()
		return

	if existing != null and is_instance_valid(existing) and existing.data == wanted:
		existing.upgrade_to(RunState.level_at(anchor))
		_refresh_tower_modifiers()
		return

	if existing != null and is_instance_valid(existing):
		existing.queue_free()

	var instance := tower_scene.instantiate() as Tower
	if instance == null:
		return
	instance.projectile_scene = projectile_scene
	instance.setup(wanted, RunState.level_at(anchor), anchor, self)
	# On the plot front edge, not its middle: see Balance.TOWER_SORT_LIFT.
	var plot: Vector2 = BattleGrid.footprint_centre(anchor)
	instance.position = plot + Vector2(0.0, Balance.TOWER_SORT_LIFT)
	slot_root.add_child(instance)
	_towers[anchor] = instance
	_refresh_tower_modifiers()


## A placement change can alter another tower's synergy or road armour, so every
## standing tower recomputes rather than guessing which ones were affected.
func _refresh_tower_modifiers() -> void:
	for key: Variant in _towers:
		var built: Tower = _towers[key] as Tower
		if built != null and is_instance_valid(built):
			built.refresh_modifiers()


## A legal build anchor near a road's bend pocket, or the pocket itself.
##
## Free placement has no slot list, so anything that needs "somewhere sensible to
## put a tower" - the soak, the perf harness, the breather check, a future
## build hint - would otherwise each grow its own search. One copy, here.
func free_anchor_near(lane: int, search: int = 3) -> Vector2i:
	if grid == null:
		return Vector2i.ZERO
	var origin: Vector2i = BattleGrid.world_to_tile(grid.lane_pocket_centre(lane))
	for ring: int in search + 1:
		for dx: int in range(-ring, ring + 1):
			for dy: int in range(-ring, ring + 1):
				if absi(dx) != ring and absi(dy) != ring:
					continue
				var candidate: Vector2i = origin + Vector2i(dx, dy) * BattleGrid.FOOTPRINT
				if placement_problem(candidate).is_empty():
					return candidate
	return origin


func tower_at_anchor(anchor: Vector2i) -> Tower:
	return _towers.get(anchor, null) as Tower


func all_towers() -> Array[Tower]:
	var found: Array[Tower] = []
	for key: Variant in _towers:
		var built: Tower = _towers[key] as Tower
		if built != null and is_instance_valid(built):
			found.append(built)
	return found

## Pressure is how much of a lane's threat is close to the town, so a lane full
## of enemies that just spawned reads calmer than one about to break.
func _update_pressure() -> void:
	var counts: Array[float] = []
	counts.resize(Balance.LANE_COUNT)
	counts.fill(0.0)

	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dying():
			continue
		# The lane the enemy is in *now*, not the one it spawned in.
		#
		# `enemy.lane` is written once at spawn and never again, so the readout
		# was describing the wave's opening shape for as long as the wave lasted.
		# An enemy that breaks off the road to chase the hero can end up bearing
		# on a different side of the town entirely, and it was still counted
		# against the road it entered by - lighting the wrong arc, and grading its
		# depth by projecting onto a road it had already left, which gives a
		# smaller number the further off-road it gets. Two wrong answers that
		# happened to look plausible together.
		var lane: int = grid.lane_at(enemy.global_position) if grid != null \
			else clampi(enemy.lane, 0, Balance.LANE_COUNT - 1)
		# Distance *along the road*, not straight-line. With a U-bend those are
		# different answers: an enemy at the far end of the detour is close to the
		# town as the crow flies and still has most of the road left to walk.
		# Ranking by the crow would call a lane critical while it is fine.
		var distance: float = grid.distance_to_town_along(lane, enemy.global_position) 			if grid != null else enemy.global_position.length()
		var road_length: float = grid.lane_length(lane) if grid != null 			else Balance.LANE_SPAWN_RADIUS
		var closeness: float = 1.0 - clampf(
			(distance - Balance.TOWN_RADIUS) / maxf(road_length - Balance.TOWN_RADIUS, 1.0),
			0.0, 1.0)
		counts[lane] += 0.25 + closeness * closeness * 2.0

	for lane: int in Balance.LANE_COUNT:
		var value: float = clampf(counts[lane] / 12.0, 0.0, 1.0)
		RunState.peak_lane_pressure = maxf(RunState.peak_lane_pressure, value)
		if not is_equal_approx(value, _pressure[lane]):
			_pressure[lane] = value
			EventBus.lane_pressure_changed.emit(lane, value)
