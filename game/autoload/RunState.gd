extends Node

## The single source of truth for the current run (GDD §11 rule 1).
##
## No system caches run data locally. Everything here is destroyed on death;
## persistence is MetaState's job and its schema is deliberately tiny (GDD §10).

# --- Journey ---------------------------------------------------------------

var distance_travelled: float = 0.0
var beast_speed: float = Balance.BEAST_BASE_SPEED
var act: int = 1
var segment: int = 0
var terrain_id: String = ""

# --- Economy ---------------------------------------------------------------

var resources: int = 0
var blueprints: Array[String] = []

# --- Town ------------------------------------------------------------------

var town_hp: float = Balance.TOWN_MAX_HP
var town_max_hp: float = Balance.TOWN_MAX_HP

## Building id -> tier built. Absent or 0 means not built.
var building_tiers: Dictionary = {}

## The one construction in progress, or empty. Keys: id, tier, distance_needed,
## distance_done.
var construction: Dictionary = {}

## Captive ids held, and captive id -> building id for those assigned.
var captives: Array[String] = []
var captive_assignments: Dictionary = {}

# --- Relics ----------------------------------------------------------------

var socketed_relics: Array[String] = []
var held_relics: Array[String] = []
var boss_cores: Array[String] = []

# --- Towers ----------------------------------------------------------------

## Twelve slots: lane * 3 + slot_index. Each entry is {} or
## {"tower_id": String, "level": int}.
var tower_slots: Array[Dictionary] = []

# --- Hero ------------------------------------------------------------------

var equipped_spells: Array[String] = []
var hero_ascension: int = 0

## Carried between scopes so a raid is not a free heal and the walk back from
## the town is not a reset. -1 means "start at full".
var hero_hp: float = -1.0

# --- Combat state ----------------------------------------------------------

var wave_number: int = 0
var war_horn_uses: int = 0
var horn_active: bool = false
var raid_charge: float = 0.0
var weakened_until: float = 0.0

# --- Statistics ------------------------------------------------------------

var enemies_killed: int = 0
var hero_deaths: int = 0
var raids_completed: int = 0
var chieftains_taken: int = 0


func _ready() -> void:
	reset()


## Wipes everything. Called when a run begins, never mid-run — death wipes the
## run entirely (GDD §10).
func reset() -> void:
	distance_travelled = 0.0
	beast_speed = Balance.BEAST_BASE_SPEED
	act = 1
	segment = 0
	terrain_id = ""

	resources = Balance.STARTING_RESOURCES
	blueprints.clear()

	town_max_hp = Balance.TOWN_MAX_HP
	town_hp = town_max_hp
	building_tiers.clear()
	construction.clear()
	captives.clear()
	captive_assignments.clear()

	socketed_relics.clear()
	held_relics.clear()
	boss_cores.clear()

	tower_slots.clear()
	for i: int in Balance.LANE_COUNT * Balance.TOWER_SLOT_RADII.size():
		tower_slots.append({})

	equipped_spells.clear()
	hero_ascension = 0
	hero_hp = -1.0

	wave_number = 0
	war_horn_uses = 0
	horn_active = false
	raid_charge = 0.0
	weakened_until = 0.0

	enemies_killed = 0
	hero_deaths = 0
	raids_completed = 0
	chieftains_taken = 0

	var starting_terrain: TerrainData = ContentDB.terrain_for_act(1)
	if starting_terrain != null:
		terrain_id = starting_terrain.id

	# Buildings flagged available_from_start begin at tier 1, so a new run has a
	# town rather than an empty field.
	for b: BuildingData in ContentDB.buildings_sorted():
		if b.available_from_start:
			building_tiers[b.id] = 1


# --- Slot helpers -----------------------------------------------------------

static func slot_index(lane: int, slot: int) -> int:
	return lane * Balance.TOWER_SLOT_RADII.size() + slot


func slot_at(lane: int, slot: int) -> Dictionary:
	var i: int = slot_index(lane, slot)
	return tower_slots[i] if i >= 0 and i < tower_slots.size() else {}


func slot_is_empty(lane: int, slot: int) -> bool:
	return slot_at(lane, slot).is_empty()


func tower_in_slot(lane: int, slot: int) -> TowerData:
	var entry: Dictionary = slot_at(lane, slot)
	if entry.is_empty():
		return null
	return ContentDB.tower(String(entry.get("tower_id", "")))


func level_in_slot(lane: int, slot: int) -> int:
	return int(slot_at(lane, slot).get("level", 0))


func set_slot(lane: int, slot: int, tower_id: String, level: int) -> void:
	var i: int = slot_index(lane, slot)
	if i < 0 or i >= tower_slots.size():
		return
	tower_slots[i] = {"tower_id": tower_id, "level": level}
	EventBus.tower_slot_changed.emit(lane, slot)


func clear_slot(lane: int, slot: int) -> void:
	var i: int = slot_index(lane, slot)
	if i < 0 or i >= tower_slots.size():
		return
	tower_slots[i] = {}
	EventBus.tower_slot_changed.emit(lane, slot)


## The combination available in a lane's middle slot, or null. Requires both
## flanking slots to be built (GDD §4.1).
func available_combination(lane: int) -> TowerData:
	var inner: TowerData = tower_in_slot(lane, 0)
	var outer: TowerData = tower_in_slot(lane, 2)
	if inner == null or outer == null:
		return null
	return ContentDB.combination_for(inner.element, outer.element)


## True when a lane's two elemental towers share an element (GDD §4.2).
func lane_has_element_synergy(lane: int) -> bool:
	var inner: TowerData = tower_in_slot(lane, 0)
	var outer: TowerData = tower_in_slot(lane, 2)
	return inner != null and outer != null and inner.element == outer.element


# --- Economy helpers --------------------------------------------------------

func can_afford(cost: int) -> bool:
	return resources >= cost


func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	resources -= cost
	EventBus.resources_changed.emit(resources)
	return true


func gain_resources(amount: int) -> void:
	if amount == 0:
		return
	resources = maxi(resources + amount, 0)
	EventBus.resources_changed.emit(resources)


## Resource yield per distance unit, after Granary tiers and captive labour.
func resource_rate() -> float:
	var rate: float = Balance.RESOURCE_PER_DISTANCE
	var granary: BuildingData = ContentDB.building("granary")
	if granary != null:
		rate += granary.effect_at(building_tier("granary"))
	rate += float(assigned_captive_count()) * Balance.CAPTIVE_WORK_BONUS
	return rate


func building_tier(id: String) -> int:
	return int(building_tiers.get(id, 0))


func assigned_captive_count() -> int:
	return captive_assignments.size()


## Relic sockets available: Town Hall tier plus the one meta bonus.
func relic_slot_count() -> int:
	var tier: int = building_tier("town_hall")
	var base: int = Balance.TOWN_HALL_RELIC_SLOTS[clampi(tier - 1, 0, Balance.TOWN_HALL_RELIC_SLOTS.size() - 1)] if tier > 0 else 0
	return base + MetaState.bonus_relic_slots()


## Multiplier applied to enemy HP and damage from accumulated horn uses.
func enemy_escalation_multiplier() -> float:
	return 1.0 + float(war_horn_uses) * Balance.WAR_HORN_ESCALATION_PER_USE


func enemies_are_weakened() -> bool:
	return weakened_until > 0.0


## Total journey progress, 0..1.
func journey_ratio() -> float:
	return clampf(distance_travelled / Balance.JOURNEY_TOTAL_DISTANCE, 0.0, 1.0)


## Distance remaining until the next crossroad.
func distance_to_crossroad() -> float:
	var next_boundary: float = (floorf(distance_travelled / Balance.SEGMENT_DISTANCE) + 1.0) * Balance.SEGMENT_DISTANCE
	return maxf(next_boundary - distance_travelled, 0.0)
