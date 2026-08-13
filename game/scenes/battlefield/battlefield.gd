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
	if hero != null:
		hero.set_active(true)

var _slots: Array[TowerSlot] = []
var _suspended: bool = false

## Lane pressure, 0..1, recomputed on a slow tick rather than every frame.
var _pressure: Array[float] = []
var _pressure_timer: float = 0.0

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
const LANE_ROAD_SCALE: float = 1.6

## Road colour. Alpha and darkening both live in Balance because both of them
## are "can you see the lane", which is a tuning question and was answered wrong
## once already.
static func lane_road_tint() -> Color:
	var shade: float = Balance.PATH_DARKEN
	var warm: Color = Balance.PATH_WARMTH
	return Color(warm.r * shade, warm.g * shade, warm.b * shade, Balance.PATH_TINT_ALPHA)


func _ready() -> void:
	_pressure.resize(Balance.LANE_COUNT)
	_setup_sorting()
	_setup_lighting()
	_setup_ground()
	_build_lanes()
	_build_slots()
	_build_torches()
	_build_foliage()
	wave_director.battlefield = self
	wave_director.start()
	# Spells and the melee arc both need to find enemies, and the hero must not
	# go looking up the tree for the scope it happens to be sitting in.
	if hero != null:
		hero.field = self
	# Transient effects are parented into the scope that owns them, so leaving
	# the battlefield takes its sparks with it.
	Vfx.bind_world(effect_root if effect_root != null else self)


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
	var clouds := CloudShadows.new()
	clouds.name = "CloudShadows"
	clouds.z_index = Z_CLOUDS
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
		for along: float in Balance.TORCH_ALONG_STOPS:
			for sign: float in [-1.0, 1.0]:
				var torch := Torch.new()
				torch.lane = lane
				torch.position = direction * along + side * Balance.TORCH_LANE_OFFSET * sign
				entity_root.add_child(torch)


func _build_foliage() -> void:
	var foliage := Foliage.new()
	foliage.name = "Foliage"
	# In the sorted layer so a plant in front of the hero occludes them and one
	# behind does not.
	entity_root.add_child(foliage)


## 0..1, how dark a lane is. 1 means every torch on it is out.
func lane_darkness(lane: int) -> float:
	var total: int = 0
	var dark: int = 0
	for node: Node in get_tree().get_nodes_in_group(Torch.GROUP):
		var torch := node as Torch
		if torch == null or torch.lane != lane:
			continue
		total += 1
		if not torch.is_lit():
			dark += 1
	return float(dark) / float(total) if total > 0 else 0.0


# --- Lane geometry ----------------------------------------------------------

## Lane 0 = north, then clockwise: east, south, west.
static func lane_vector(lane: int) -> Vector2:
	return Vector2.UP.rotated(TAU * float(lane) / float(Balance.LANE_COUNT))


func lane_direction(lane: int) -> Vector2:
	return lane_vector(lane)


static func lane_spawn_point(lane: int) -> Vector2:
	return lane_vector(lane) * Balance.LANE_SPAWN_RADIUS


static func slot_position(lane: int, slot: int) -> Vector2:
	var direction: Vector2 = lane_vector(lane)
	var along: float = Balance.TOWER_SLOT_RADII[clampi(slot, 0, Balance.TOWER_SLOT_RADII.size() - 1)]
	# The combination slot sits on the opposite side of the path so that "the
	# one in the middle" reads at a glance.
	var side: float = -1.0 if slot == Balance.COMBO_SLOT_INDEX else 1.0
	return direction * along + direction.orthogonal() * Balance.TOWER_SLOT_OFFSET * side


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
	var spread: Vector2 = lane_vector(lane).orthogonal() * randf_range(-Balance.LANE_WIDTH, Balance.LANE_WIDTH) * 0.5
	enemy.position = lane_spawn_point(lane) * data.spawn_distance_scale + spread
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
	if not RunState.can_afford(cost):
		return "Needs %d resources." % cost
	RunState.spend(cost)
	RunState.set_slot(lane, slot, tower_data.id, 1)
	RunState.towers_built += 1
	return ""


func try_upgrade(lane: int, slot: int) -> String:
	var tower_data: TowerData = RunState.tower_in_slot(lane, slot)
	if tower_data == null:
		return "Nothing built there."
	var level: int = RunState.level_in_slot(lane, slot)
	if level >= Balance.TOWER_MAX_LEVEL:
		return "Already at maximum level."
	if level >= RunState.tower_level_cap():
		return "Upgrade the Forge to unlock tower level %d." % (level + 1)
	var cost: int = upgrade_cost_of(level)
	if not RunState.can_afford(cost):
		return "Needs %d resources." % cost
	RunState.spend(cost)
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
	var tower_data: TowerData = RunState.tower_in_slot(lane, slot)
	if tower_data == null:
		return "Nothing built there."
	var level: int = RunState.level_in_slot(lane, slot)
	var spent: int = build_cost_of(tower_data)
	for l: int in range(1, level):
		spent += upgrade_cost_of(l)
	RunState.gain_resources(int(round(float(spent) * Balance.TOWER_SELL_REFUND)))
	RunState.towers_sold += 1
	RunState.clear_slot(lane, slot)
	return ""


func try_repair_town() -> String:
	if town == null or town.health == null:
		return "The town cannot be reached."
	if town.health.current_hp >= town.health.max_hp:
		return "The town is already whole."
	if not RunState.can_afford(Balance.TOWN_REPAIR_COST):
		return "Needs %d resources." % Balance.TOWN_REPAIR_COST
	RunState.spend(Balance.TOWN_REPAIR_COST)
	town.health.heal(Balance.TOWN_REPAIR_AMOUNT)
	Vfx.ring(town.global_position, Balance.TOWN_RADIUS * 1.3,
		Color(0.55, 0.88, 0.68, 0.65), 0.55, 6.0)
	Vfx.spark(town.global_position, Color("b7e6c0"), 18, Vector2.UP, 180.0)
	Sfx.play("sfx_tower_upgrade", -3.0)
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

	var length: float = Balance.LANE_SPAWN_RADIUS - Balance.TOWN_RADIUS
	for lane: int in Balance.LANE_COUNT:
		var direction: Vector2 = lane_vector(lane)
		var strip := Sprite2D.new()
		strip.texture = road
		strip.centered = true
		strip.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		strip.region_enabled = true
		# Region is in texture space, so the road tiles along the strip instead
		# of being stretched into a smear.
		strip.region_rect = Rect2(0.0, 0.0, length, Balance.LANE_WIDTH * LANE_ROAD_SCALE)
		# Built along +X, then rotated onto the lane; +X is a quarter turn from
		# lane 0 (north), which is what lane_vector returns.
		strip.rotation = direction.angle()
		strip.position = direction * (Balance.TOWN_RADIUS + length * 0.5)
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
		var distance: float = enemy.global_position.length()
		var closeness: float = 1.0 - clampf(
			(distance - Balance.TOWN_RADIUS) / maxf(Balance.LANE_SPAWN_RADIUS - Balance.TOWN_RADIUS, 1.0),
			0.0, 1.0)
		counts[lane] += 0.25 + closeness * closeness * 2.0

	for lane: int in Balance.LANE_COUNT:
		var value: float = clampf(counts[lane] / 12.0, 0.0, 1.0)
		RunState.peak_lane_pressure = maxf(RunState.peak_lane_pressure, value)
		if not is_equal_approx(value, _pressure[lane]):
			_pressure[lane] = value
			EventBus.lane_pressure_changed.emit(lane, value)
