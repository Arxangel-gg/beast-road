class_name HazardPlants
extends Node2D

## **The region's harmful plants** (owner, 2026-10-07; `HazardPlantData`), laid
## on the outskirts each act and re-laid with everything regional.
##
## **Placed the way the gathering nodes and the wayside encounters are**: from
## `Fishing.band_tiles`, on open ground with a ring of open ground round it,
## clear of the spawns, the town, the gates, the camps, the plots, the nodes and
## the water - so a plant never takes a build spot worth having and never stands
## on a road body's route. What it hurts is whatever leaves the road: a Warden
## gathering or fishing, a body chasing one, an animal.
##
## **From the run's seed, on its own stream**, so both machines grow the same
## plants and a plant moves no roll anything else is drawn on. Never on the Walk.

const GROUP: StringName = &"hazard_plants"
const PLANT_GROUP: StringName = &"hazard_plant"

var grid: BattleGrid = null
var field: Node = null
## Ground already claimed: gates, camps, plots, gathering nodes, the wayside.
var avoid: PackedVector2Array = []
## The ponds, as the rectangles they occupy.
var avoid_water: Array[Rect2] = []

var _plants: Array[HazardPlant] = []
## The thorns, kept apart so a mover's slow asks a handful and not every plant.
var _thorns: Array[HazardPlant] = []


func _ready() -> void:
	add_to_group(GROUP)
	Vfx.bind_hazards(self)


func plants() -> Array[HazardPlant]:
	return _plants


## The plants this act's region grows, weighted.
static func pool_for(act: int) -> Array[HazardPlantData]:
	var out: Array[HazardPlantData] = []
	for id_value: Variant in ContentDB.hazard_plant_ids():
		var plant: HazardPlantData = ContentDB.hazard_plant(String(id_value))
		if plant != null and plant.acts.has(act) and plant.weight > 0.0:
			out.append(plant)
	return out


func scatter() -> void:
	_clear()
	if grid == null or RunState.walking:
		return
	var pool: Array[HazardPlantData] = pool_for(RunState.act)
	if pool.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = RunState.run_seed * 1000003 + hash("hazards:%d:%s" % [RunState.act, RunState.terrain_id])
	var anchors: Array[Vector2i] = Fishing.band_tiles(grid, Balance.GATHER_EDGE_BAND)
	if anchors.is_empty():
		return
	var wanted: int = Balance.HAZARD_PER_ACT if RunState.act > 1 else Balance.HAZARD_PER_ACT_OPENING
	var total: float = 0.0
	for plant: HazardPlantData in pool:
		total += plant.weight
	var placed: PackedVector2Array = []
	for _attempt: int in wanted * Balance.HAZARD_PLACEMENT_ATTEMPTS:
		if _plants.size() >= wanted:
			break
		var tile: Vector2i = anchors[rng.randi_range(0, anchors.size() - 1)]
		var at: Vector2 = BattleGrid.tile_to_world(tile) + Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0))
		var pick: float = rng.randf() * total
		var chosen: HazardPlantData = pool[pool.size() - 1]
		for plant: HazardPlantData in pool:
			pick -= plant.weight
			if pick <= 0.0:
				chosen = plant
				break
		if not is_good_ground(at, placed, chosen):
			continue
		_plant(chosen, at, rng.randf() * 10.0)
		placed.append(at)


## Lays one plant at `at`. Also the gate's door.
func plant_at(data: HazardPlantData, at: Vector2) -> HazardPlant:
	return _plant(data, at, 0.0)


func _plant(data: HazardPlantData, at: Vector2, phase: float) -> HazardPlant:
	var plant := HazardPlant.new()
	plant.name = "Hazard_%s" % data.id
	plant.setup(data, field, phase)
	plant.position = at - global_position
	add_child(plant)
	_plants.append(plant)
	if data.behaviour == HazardPlantData.Behaviour.THORNS and data.slow < 1.0:
		_thorns.append(plant)
	return plant


## **A place of work is not a firing range**: a spitter grows further than its
## own range from every pond, seam, plot, gate, camp and wayside, so a Warden
## fishing or felling is not spat at from across the water. Everything else
## keeps `HAZARD_SPACING`.
static func clearance_for(data: HazardPlantData) -> float:
	if data != null and data.behaviour == HazardPlantData.Behaviour.SPITTER:
		return maxf(Balance.HAZARD_SPACING, data.spit_range + Balance.HAZARD_SPITTER_MARGIN)
	return Balance.HAZARD_SPACING


func is_good_ground(at: Vector2, placed: PackedVector2Array = [], data: HazardPlantData = null) -> bool:
	var keep: float = clearance_for(data)
	var half := Vector2.ONE * BattleGrid.TILE
	var rim := Rect2(at - half, half * 2.0)
	if not Fishing.ground_is_open(grid, rim, Balance.GATHER_NODE_CLEARANCE_TILES):
		return false
	if at.length() < Balance.FISHING_TOWN_CLEARANCE:
		return false
	for spawn: Variant in grid.spawn_points:
		if rim.grow(Balance.FISHING_SPAWN_CLEARANCE).has_point(spawn as Vector2):
			return false
	for lane: int in grid.ambush_points.size():
		for spawn: Variant in (grid.ambush_points[lane] as Array):
			if rim.grow(Balance.FISHING_SPAWN_CLEARANCE).has_point(spawn as Vector2):
				return false
	for taken: Vector2 in avoid:
		if at.distance_to(taken) < keep:
			return false
	for other: Vector2 in placed:
		if at.distance_to(other) < Balance.HAZARD_SPACING:
			return false
	for pond: Rect2 in avoid_water:
		var near := Vector2(clampf(at.x, pond.position.x, pond.end.x),
			clampf(at.y, pond.position.y, pond.end.y))
		if at.distance_to(near) < keep:
			return false
	return true


## **Where an animal may stand instead of in thorns**: a point inside a patch is
## moved out past its edge, along the way it already lay from the middle. An
## animal crosses thorns if its way lies through them; it never settles in them.
func clear_of_thorns(at: Vector2) -> Vector2:
	for plant: HazardPlant in _thorns:
		if not is_instance_valid(plant) or plant.slow_at(at) >= 1.0:
			continue
		var away: Vector2 = at - plant.global_position
		if away.length_squared() < 1.0:
			away = Vector2.RIGHT
		return plant.global_position + away.normalized() * (plant.data.reach + Balance.HAZARD_ANIMAL_BERTH)
	return at


## **How much of its speed a mover keeps at `at`**: the slowest thorn patch it
## is standing in, or 1.0.
func slow_at(at: Vector2) -> float:
	var keep: float = 1.0
	for plant: HazardPlant in _thorns:
		if is_instance_valid(plant):
			keep = minf(keep, plant.slow_at(at))
	return keep


func positions() -> PackedVector2Array:
	var out: PackedVector2Array = []
	for plant: HazardPlant in _plants:
		if is_instance_valid(plant):
			out.append(plant.global_position)
	return out


func _clear() -> void:
	for plant: HazardPlant in _plants:
		if is_instance_valid(plant):
			plant.queue_free()
	_plants.clear()
	_thorns.clear()
