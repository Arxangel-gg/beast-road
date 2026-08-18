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
@export var tower_slot_scene: PackedScene
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

var _slots: Array[TowerSlot] = []
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
const LANE_TEXTURE: String = "res://art/battlefield/lane_path.png"

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


func _ready() -> void:
	_pressure.resize(Balance.LANE_COUNT)
	_setup_sorting()
	_build_feedback_root()
	_setup_lighting()
	_setup_ground()
	grid = BattleGrid.new()
	_build_lanes()
	_build_slots()
	_build_torches()
	_build_foliage()
	wave_director.battlefield = self
	wave_director.stop()
	# Spells and the melee arc both need to find enemies, and the hero must not
	# go looking up the tree for the scope it happens to be sitting in.
	if hero != null:
		hero.field = self
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
		func(_p: float, tint: Color, _d: float) -> void: modulate_node.color = tint)
	modulate_node.color = DayNight.tint

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
func _build_torches() -> void:
	for lane: int in Balance.LANE_COUNT:
		var direction: Vector2 = Battlefield.lane_vector(lane)
		var side: Vector2 = direction.orthogonal()
		for stop_index: int in Balance.TORCH_ALONG_STOPS.size():
			var along: float = Balance.TORCH_ALONG_STOPS[stop_index]
			for side_index: int in 2:
				var sign: float = -1.0 if side_index == 0 else 1.0
				var torch := Torch.new()
				torch.lane = lane
				# High features one local shadow pool on each lane. Ultra promotes
				# the other twenty torches in place, without rebuilding the field.
				var featured: bool = stop_index == Balance.TORCH_FEATURED_SHADOW_STOP \
					and side_index == lane % 2
				torch.shadow_on_ultra_only = not featured
				torch.position = direction * along + side * Balance.TORCH_LANE_OFFSET * sign
				entity_root.add_child(torch)


func _build_foliage() -> void:
	var foliage := Foliage.new()
	foliage.name = "Foliage"
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
	for slot: TowerSlot in _slots:
		if slot.lane != lane or slot.is_empty():
			continue
		var tower: Tower = slot.tower()
		if tower != null and tower.data != null and tower.data.taunts:
			return tower
	return null


## Nearest live structure on this road. A stable nearest-target rule makes
## siege enemies legible: they attack what they visibly reach instead of
## changing targets because a farther tower happens to be more damaged.
func vulnerable_tower_in_lane(lane: int, from: Vector2) -> Node2D:
	var nearest: Tower = null
	var nearest_squared: float = INF
	for built_slot: TowerSlot in _slots:
		if built_slot.lane != lane or built_slot.is_empty():
			continue
		var built: Tower = built_slot.tower()
		if built == null or not built.is_vulnerable():
			continue
		var distance_squared: float = built.global_position.distance_squared_to(from)
		if distance_squared < nearest_squared:
			nearest = built
			nearest_squared = distance_squared
	return nearest


func slot_at(lane: int, slot: int) -> TowerSlot:
	for s: TowerSlot in _slots:
		if s.lane == lane and s.slot == slot:
			return s
	return null


func all_slots() -> Array[TowerSlot]:
	return _slots


func lane_pressure(lane: int) -> float:
	return _pressure[lane] if lane >= 0 and lane < _pressure.size() else 0.0


func lane_armour(lane: int) -> float:
	var total: float = 0.0
	for slot_node: TowerSlot in _slots:
		if slot_node.lane != lane or slot_node.is_empty():
			continue
		var built: Tower = slot_node.tower()
		if built != null and built.data != null:
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
	return enemy


## Placeholder VFX. A line that fades is not art — it is the readout that a
## tower fired at something, and it gets replaced wholesale when real effects
## exist (see ASSET_MANIFEST §7).
func spawn_tracer(from: Vector2, to: Vector2, colour: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 3.0
	line.default_color = colour
	effect_root.add_child(line)
	var tween: Tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.14)
	tween.tween_callback(line.queue_free)


func spawn_ground_zone(at: Vector2, dps: float, duration: float, radius: float) -> void:
	var zone := GroundZone.new()
	zone.configure(dps, duration, radius, self)
	zone.position = at
	effect_root.add_child(zone)


# --- Build API (called by the UI) -------------------------------------------

## Returns "" on success, or a reason the build was refused.
func try_build(lane: int, slot: int, tower_data: TowerData) -> String:
	if not RunState.can_build_now():
		return "Construction is locked until Preparation."
	if tower_data == null:
		return "No tower selected."
	if not RunState.slot_is_empty(lane, slot):
		return "That spot is taken."
	var target_slot: TowerSlot = slot_at(lane, slot)
	if target_slot == null:
		return "No such build spot."
	if target_slot.is_combo_slot():
		var allowed: TowerData = target_slot.buildable_combination()
		if allowed == null:
			return "Build both flanking towers first."
		if allowed != tower_data:
			return "Those two elements make %s." % allowed.display_name
	elif tower_data.is_combination:
		return "Combination towers only go in the middle spot."
	var cost: int = build_cost_of(tower_data)
	var build_cost: Dictionary = {RunState.GOLD: cost}
	if tower_data.is_combination:
		build_cost[RunState.STONE] = Balance.TOWER_COMBO_STONE_COST
	if not RunState.can_afford_cost(build_cost):
		return "Needs %s." % RunState.format_cost(build_cost)
	RunState.spend_cost(build_cost)
	RunState.set_slot(lane, slot, tower_data.id, 1)
	RunState.towers_built += 1
	Vfx.build_burst(slot_position(lane, slot), TowerData.element_colour(tower_data.element))
	return ""


func try_upgrade(lane: int, slot: int) -> String:
	if not RunState.can_build_now():
		return "Upgrades are locked until Preparation."
	var tower_data: TowerData = RunState.tower_in_slot(lane, slot)
	if tower_data == null:
		return "Nothing built there."
	var level: int = RunState.level_in_slot(lane, slot)
	if level >= Balance.TOWER_MAX_LEVEL:
		return "Already at maximum level."
	if level >= RunState.tower_level_cap():
		return "Upgrade the Forge to unlock tower level %d." % (level + 1)
	var cost: int = upgrade_cost_of(level)
	if not RunState.can_afford_cost({RunState.GOLD: cost}):
		return "Needs %d Gold." % cost
	RunState.spend_cost({RunState.GOLD: cost})
	RunState.set_slot(lane, slot, tower_data.id, level + 1)
	RunState.tower_upgrades += 1
	return ""


## Build and upgrade prices after relics. One place, so the UI quotes exactly
## what the purchase will charge.
static func build_cost_of(tower_data: TowerData) -> int:
	var scale: float = maxf(1.0 + Modifiers.value(Modifiers.BUILD_COST), 0.25)
	return maxi(int(round(float(tower_data.build_cost()) * scale)), 1)


static func upgrade_cost_of(level: int) -> int:
	var base: int = TowerData.upgrade_cost(level)
	if base < 0:
		return -1
	var scale: float = maxf(1.0 + Modifiers.value(Modifiers.BUILD_COST), 0.25)
	return maxi(int(round(float(base) * scale)), 1)


func try_sell(lane: int, slot: int) -> String:
	if not RunState.can_build_now():
		return "Selling is locked until Preparation."
	var tower_data: TowerData = RunState.tower_in_slot(lane, slot)
	if tower_data == null:
		return "Nothing built there."
	var level: int = RunState.level_in_slot(lane, slot)
	var spent: int = build_cost_of(tower_data)
	for l: int in range(1, level):
		spent += upgrade_cost_of(l)
	RunState.gain_currency(RunState.GOLD,
		int(round(float(spent) * Balance.TOWER_SELL_REFUND)))
	if tower_data.is_combination:
		RunState.gain_currency(RunState.STONE,
			int(round(float(Balance.TOWER_COMBO_STONE_COST) * Balance.TOWER_STONE_SELL_REFUND)))
	RunState.towers_sold += 1
	RunState.clear_slot(lane, slot)
	return ""


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


func try_repair_tower(lane: int, slot: int) -> String:
	if not RunState.can_build_now():
		return "Tower repairs are prepared between road battles."
	var built_slot: TowerSlot = slot_at(lane, slot)
	var built: Tower = built_slot.tower() if built_slot != null else null
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
	# one repeat covers GROUND_TILE_WORLD_SIZE of world rather than its 512
	# source pixels. Drawn 1:1 the tile repeats eight times across the screen and
	# the seams turn the floor into wallpaper.
	var tile_scale: float = Balance.GROUND_TILE_WORLD_SIZE / 512.0
	var half: float = extent / tile_scale
	ground.region_rect = Rect2(-half, -half, half * 2.0, half * 2.0)
	ground.scale = Vector2.ONE * tile_scale

	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null and ResourceLoader.exists(terrain.get_sprite_path()):
		ground.texture = load(terrain.get_sprite_path())


## Four road strips, one per cardinal, from the town wall out to the spawn point.
## Each is the lane_path texture tiled along its own length and rotated onto the
## lane, so the road art only ever appears where a road actually is.
func _build_lanes() -> void:
	var road: Texture2D = null
	if ResourceLoader.exists(LANE_TEXTURE):
		road = load(LANE_TEXTURE)

	# One strip per *segment*, not one per lane. A road with a U-bend is a
	# polyline, and a single rotated strip can only ever draw a straight one -
	# which would leave enemies walking a bend across painted-on straight ground.
	for lane: int in Balance.LANE_COUNT:
		var path: PackedVector2Array = grid.lane_paths[lane]
		for i: int in path.size() - 1:
			_build_road_segment(road, lane, path[i], path[i + 1], lane_root)


## One tiled strip of road between two points.
func _build_road_segment(road: Texture2D, lane: int, from: Vector2, to: Vector2,
		lane_root: Node2D) -> void:
	var span: Vector2 = to - from
	# Overlap each end by half a road width so the corners join without a notch
	# showing the ground through the inside of every bend.
	var half_width: float = Balance.LANE_WIDTH * LANE_ROAD_SCALE * 0.5
	var length: float = span.length() + half_width * 2.0
	if length > 0.0:
		var direction: Vector2 = span.normalized()
		var strip := Sprite2D.new()
		strip.texture = road
		strip.centered = true
		strip.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		strip.region_enabled = true
		# Region is in texture space, so the road tiles along the strip instead
		# of being stretched into a smear.
		strip.region_rect = Rect2(0.0, 0.0, length, Balance.LANE_WIDTH * LANE_ROAD_SCALE)
		# Built along +X, then rotated onto the segment.
		strip.rotation = direction.angle()
		strip.position = (from + to) * 0.5
		strip.modulate = lane_road_tint()
		# Noisy fringe on the outer band only, so the road wears into the ground
		# instead of sitting on it like a sticker with four straight edges — while
		# its interior stays solid, because the interior is what the player reads
		# enemies against.
		#
		# The shader is handed the region-to-texture ratio because the region is
		# bigger than the road art: that is what makes it tile, and it is also
		# what makes UV run past 1. See PathBlend for what that broke.
		var uv_scale := Vector2(
			strip.region_rect.size.x / maxf(road.get_width(), 1.0),
			strip.region_rect.size.y / maxf(road.get_height(), 1.0)) if road != null else Vector2.ONE
		strip.material = PathBlend.material_for(
			lane, Balance.LANE_WIDTH * LANE_ROAD_SCALE * 0.5, uv_scale)
		lane_root.add_child(strip)


func _build_slots() -> void:
	for lane: int in Balance.LANE_COUNT:
		for slot: int in Balance.TOWER_SLOT_RADII.size():
			var instance := tower_slot_scene.instantiate() as TowerSlot
			if instance == null:
				continue
			instance.setup(lane, slot, self)
			instance.position = slot_position(lane, slot)
			slot_root.add_child(instance)
			_slots.append(instance)


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
		var lane: int = clampi(enemy.lane, 0, Balance.LANE_COUNT - 1)
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
