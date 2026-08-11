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

var _slots: Array[TowerSlot] = []
var _suspended: bool = false

## Lane pressure, 0..1, recomputed on a slow tick rather than every frame.
var _pressure: Array[float] = []
var _pressure_timer: float = 0.0

const PRESSURE_INTERVAL: float = 0.2


func _ready() -> void:
	_pressure.resize(Balance.LANE_COUNT)
	_setup_ground()
	_build_lanes()
	_build_slots()
	wave_director.battlefield = self
	wave_director.start()


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


# --- Spawning ---------------------------------------------------------------

func spawn_enemy(data: EnemyData, lane: int, stat_scale: float) -> Enemy:
	if enemy_scene == null:
		return null
	var enemy := enemy_scene.instantiate() as Enemy
	if enemy == null:
		return null
	enemy.setup(data, lane, self, stat_scale)
	var spread: Vector2 = lane_vector(lane).orthogonal() * randf_range(-Balance.LANE_WIDTH, Balance.LANE_WIDTH) * 0.5
	enemy.position = lane_spawn_point(lane) + spread
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
	var cost: int = tower_data.build_cost()
	if not RunState.can_afford(cost):
		return "Needs %d resources." % cost
	RunState.spend(cost)
	RunState.set_slot(lane, slot, tower_data.id, 1)
	return ""


func try_upgrade(lane: int, slot: int) -> String:
	var tower_data: TowerData = RunState.tower_in_slot(lane, slot)
	if tower_data == null:
		return "Nothing built there."
	var level: int = RunState.level_in_slot(lane, slot)
	if level >= Balance.TOWER_MAX_LEVEL:
		return "Already at maximum level."
	var cost: int = TowerData.upgrade_cost(level)
	if not RunState.can_afford(cost):
		return "Needs %d resources." % cost
	RunState.spend(cost)
	RunState.set_slot(lane, slot, tower_data.id, level + 1)
	return ""


func try_sell(lane: int, slot: int) -> String:
	var tower_data: TowerData = RunState.tower_in_slot(lane, slot)
	if tower_data == null:
		return "Nothing built there."
	var level: int = RunState.level_in_slot(lane, slot)
	var spent: int = tower_data.build_cost()
	for l: int in range(1, level):
		spent += TowerData.upgrade_cost(l)
	RunState.gain_resources(int(round(float(spent) * Balance.TOWER_SELL_REFUND)))
	RunState.clear_slot(lane, slot)
	return ""


# --- Setup ------------------------------------------------------------------

func _setup_ground() -> void:
	if ground == null:
		return
	var extent: float = Balance.LANE_SPAWN_RADIUS * 1.4
	ground.centered = true
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	ground.region_rect = Rect2(-extent, -extent, extent * 2.0, extent * 2.0)


## One line per lane, from the spawn point to the town. Greybox: the real thing
## is a painted road (ASSET_MANIFEST §5.13).
func _build_lanes() -> void:
	for lane: int in Balance.LANE_COUNT:
		var line := Line2D.new()
		var direction: Vector2 = lane_vector(lane)
		line.points = PackedVector2Array([
			direction * Balance.LANE_SPAWN_RADIUS,
			direction * Balance.TOWN_RADIUS,
		])
		line.width = Balance.LANE_WIDTH
		line.default_color = Color(0.72, 0.66, 0.52, 0.13)
		lane_root.add_child(line)


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
		if not is_equal_approx(value, _pressure[lane]):
			_pressure[lane] = value
			EventBus.lane_pressure_changed.emit(lane, value)
