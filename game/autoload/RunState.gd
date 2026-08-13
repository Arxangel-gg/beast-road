extends Node

## The single source of truth for the current run (GDD §11 rule 1).
##
## No system caches run data locally. Everything here is destroyed on death;
## persistence is MetaState's job and its schema is deliberately tiny (GDD §10).

# --- Journey ---------------------------------------------------------------

enum Phase {
	PREPARATION,
	ROAD_BATTLE,
	BOSS,
	RAID,
	FINAL_ASCENT,
	ENDED,
}

var distance_travelled: float = 0.0
var beast_speed: float = Balance.BEAST_BASE_SPEED
var act: int = 1
var segment: int = 0
var terrain_id: String = ""
var phase: Phase = Phase.PREPARATION

# --- Economy ---------------------------------------------------------------

const WOOD: String = "wood"
const FOOD: String = "food"
const GOLD: String = "gold"
const STONE: String = "stone"
const CURRENCIES: Array[String] = Balance.CURRENCY_IDS

## Four role-specific wallets. `resources` remains a read/write Gold alias for
## old diagnostic tools; production gameplay names the currency it means.
var currencies: Dictionary = {}
var resources: int:
	get:
		return currency(GOLD)
	set(value):
		currencies[GOLD] = maxi(value, 0)
## Fractional enemy drops carried between kills. Large waves stay rewarding
## without turning every one-HP body into a whole resource.
var kill_resource_remainder: float = 0.0
var blueprints: Array[String] = []
var market_trades_remaining: int = 0
var market_service_act: int = 0
var market_service_id: String = ""

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
var hero_wounds: int = 0
var has_resurrection_draught: bool = false

# --- Combat state ----------------------------------------------------------

var wave_number: int = 0
var war_horn_uses: int = 0
var horn_active: bool = false
var horn_used_this_battle: bool = false
var raid_charge: float = 0.0
var weakened_until: float = 0.0

## Command is earned only by active hero play and is reset between battles.
var command: float = 0.0
var last_stand_used: bool = false

# --- Statistics ------------------------------------------------------------

var enemies_killed: int = 0
var hero_deaths: int = 0
var raids_completed: int = 0
var chieftains_taken: int = 0
## Active combat time. Preparation and crossroads are tracked separately so
## balance telemetry is not distorted by thoughtful planning.
var run_time_seconds: float = 0.0
var planning_time_seconds: float = 0.0
var resources_earned: int = 0
var resources_spent: int = 0
var currency_earned: Dictionary = {}
var currency_spent: Dictionary = {}
var towers_built: int = 0
var tower_upgrades: int = 0
var towers_sold: int = 0
var towers_lost: int = 0
var town_damage_taken: float = 0.0
var town_hits_taken: int = 0
var peak_lane_pressure: float = 0.0
var wave_archetype_counts: Dictionary = {}
var command_earned: float = 0.0
var command_orders_used: Dictionary = {}
var wounds_suffered: int = 0
var hearthmends_used: int = 0


func _ready() -> void:
	reset()


func _process(delta: float) -> void:
	if not GameDirector.run_active:
		return
	if phase == Phase.PREPARATION:
		planning_time_seconds += delta
	elif phase != Phase.ENDED:
		run_time_seconds += delta


## Wipes everything. Called when a run begins, never mid-run — death wipes the
## run entirely (GDD §10).
func reset(use_treasury_cache: bool = false) -> void:
	distance_travelled = 0.0
	beast_speed = Balance.BEAST_BASE_SPEED
	act = 1
	segment = 0
	terrain_id = ""
	phase = Phase.PREPARATION

	currencies = {
		WOOD: Balance.STARTING_WOOD,
		FOOD: Balance.STARTING_FOOD,
		GOLD: Balance.STARTING_GOLD,
		STONE: Balance.STARTING_STONE,
	}
	if use_treasury_cache:
		for id: String in CURRENCIES:
			currencies[id] = currency(id) + int(MetaState.resource_cache.get(id, 0))
		MetaState.resource_cache.clear()
	kill_resource_remainder = 0.0
	blueprints.clear()
	market_trades_remaining = Balance.MARKET_TRADES_PER_PREPARATION
	market_service_act = 0
	market_service_id = ""

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
	hero_wounds = 0
	has_resurrection_draught = false

	wave_number = 0
	war_horn_uses = 0
	horn_active = false
	horn_used_this_battle = false
	raid_charge = 0.0
	weakened_until = 0.0
	command = 0.0
	last_stand_used = false

	enemies_killed = 0
	hero_deaths = 0
	raids_completed = 0
	chieftains_taken = 0
	run_time_seconds = 0.0
	planning_time_seconds = 0.0
	resources_earned = 0
	resources_spent = 0
	currency_earned.clear()
	currency_spent.clear()
	for id: String in CURRENCIES:
		currency_earned[id] = 0
		currency_spent[id] = 0
	towers_built = 0
	tower_upgrades = 0
	towers_sold = 0
	towers_lost = 0
	town_damage_taken = 0.0
	town_hits_taken = 0
	peak_lane_pressure = 0.0
	wave_archetype_counts.clear()
	command_earned = 0.0
	command_orders_used.clear()
	wounds_suffered = 0
	hearthmends_used = 0

	_equip_starting_spells()

	var starting_terrain: TerrainData = ContentDB.terrain_for_act(1)
	if starting_terrain != null:
		terrain_id = starting_terrain.id

	# Buildings flagged available_from_start begin at tier 1, so a new run has a
	# town rather than an empty field.
	for b: BuildingData in ContentDB.buildings_sorted():
		if b.available_from_start:
			building_tiers[b.id] = 1


## Two spells to begin with, drawn from the unlock pool where there is one.
## A first-ever run has an empty pool, and starting with no spells at all would
## make the hero strictly worse than the prototype — so the pool is a preference,
## not a gate.
func _equip_starting_spells() -> void:
	var pool: Array[String] = []
	for id: String in MetaState.unlocked_spells:
		if ContentDB.spells.has(id):
			pool.append(id)
	if pool.is_empty():
		for id: Variant in ContentDB.spells:
			pool.append(String(id))
	pool.sort()
	for i: int in mini(Balance.STARTING_SPELLS, pool.size()):
		equipped_spells.append(pool[i])


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
	var priority: int = int(tower_slots[i].get("target_priority", TowerData.TargetPriority.FIRST))
	tower_slots[i] = {"tower_id": tower_id, "level": level, "target_priority": priority}
	EventBus.tower_slot_changed.emit(lane, slot)


func clear_slot(lane: int, slot: int) -> void:
	var i: int = slot_index(lane, slot)
	if i < 0 or i >= tower_slots.size():
		return
	tower_slots[i] = {}
	EventBus.tower_slot_changed.emit(lane, slot)


func target_priority_in_slot(lane: int, slot: int) -> int:
	return int(slot_at(lane, slot).get("target_priority", TowerData.TargetPriority.FIRST))


func cycle_target_priority(lane: int, slot: int) -> int:
	var i: int = slot_index(lane, slot)
	if i < 0 or i >= tower_slots.size() or tower_slots[i].is_empty():
		return TowerData.TargetPriority.FIRST
	var count: int = TowerData.TargetPriority.size()
	var priority: int = (target_priority_in_slot(lane, slot) + 1) % count
	tower_slots[i]["target_priority"] = priority
	EventBus.tower_targeting_changed.emit(lane, slot, priority)
	return priority


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


# --- Phase and Command -----------------------------------------------------

func set_phase(next_phase: Phase) -> void:
	if phase == next_phase:
		return
	var previous: Phase = phase
	phase = next_phase
	EventBus.phase_changed.emit(int(phase), int(previous))


func is_preparation() -> bool:
	return phase == Phase.PREPARATION


func can_build_now() -> bool:
	return is_preparation()


func is_command_combat() -> bool:
	return phase == Phase.ROAD_BATTLE or phase == Phase.BOSS \
		or phase == Phase.FINAL_ASCENT


func begin_command_battle() -> void:
	command = 0.0
	last_stand_used = false
	horn_used_this_battle = false
	EventBus.command_changed.emit(command, Balance.COMMAND_MAX)


func add_wound() -> int:
	hero_wounds = mini(hero_wounds + 1, Balance.HERO_MAX_WOUNDS)
	wounds_suffered += 1
	EventBus.hero_wounds_changed.emit(hero_wounds, Balance.HERO_MAX_WOUNDS)
	return hero_wounds


func hearthmend() -> void:
	hero_wounds = 0
	hearthmends_used += 1
	hero_hp = -1.0
	var repair: float = town_max_hp * Balance.HEARTHMEND_TOWN_REPAIR_FRACTION
	town_hp = minf(town_hp + repair, town_max_hp)
	EventBus.hero_wounds_changed.emit(hero_wounds, Balance.HERO_MAX_WOUNDS)
	EventBus.town_health_changed.emit(town_hp, town_max_hp)
	EventBus.hearthmend_completed.emit(act)


func gain_command(amount: float) -> void:
	if amount <= 0.0 or not is_command_combat():
		return
	var before: float = command
	command = clampf(command + amount, 0.0, Balance.COMMAND_MAX)
	command_earned += command - before
	if not is_equal_approx(command, before):
		EventBus.command_changed.emit(command, Balance.COMMAND_MAX)


func can_spend_command(cost: float) -> bool:
	return is_command_combat() and cost >= 0.0 and command >= cost


func spend_command(cost: float, order_id: String) -> bool:
	if not can_spend_command(cost):
		return false
	command = maxf(command - cost, 0.0)
	command_orders_used[order_id] = int(command_orders_used.get(order_id, 0)) + 1
	EventBus.command_changed.emit(command, Balance.COMMAND_MAX)
	return true


# --- Economy helpers --------------------------------------------------------

func currency(id: String) -> int:
	return int(currencies.get(id, 0))


func currency_name(id: String) -> String:
	return id.capitalize()


func format_cost(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id: String in CURRENCIES:
		var amount: int = int(cost.get(id, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, currency_name(id)])
	return " + ".join(parts)


func can_afford_cost(cost: Dictionary) -> bool:
	for key: Variant in cost:
		var id: String = String(key)
		if currency(id) < int(cost[key]):
			return false
	return true


func spend_cost(cost: Dictionary) -> bool:
	if not can_afford_cost(cost):
		return false
	for key: Variant in cost:
		var id: String = String(key)
		var amount: int = maxi(int(cost[key]), 0)
		currencies[id] = currency(id) - amount
		currency_spent[id] = int(currency_spent.get(id, 0)) + amount
		resources_spent += amount
		_emit_currency(id)
	return true


func gain_currency(id: String, amount: int) -> void:
	if not CURRENCIES.has(id) or amount == 0:
		return
	currencies[id] = maxi(currency(id) + amount, 0)
	if amount > 0:
		currency_earned[id] = int(currency_earned.get(id, 0)) + amount
		resources_earned += amount
	_emit_currency(id)


func _emit_currency(id: String) -> void:
	EventBus.currency_changed.emit(id, currency(id))
	if id == GOLD:
		EventBus.resources_changed.emit(currency(GOLD))


## Compatibility wrappers for v3 tools and content. The old pooled resource is
## now explicitly Gold; new gameplay code must use a typed cost dictionary.
func can_afford(cost: int) -> bool:
	return currency(GOLD) >= cost


func spend(cost: int) -> bool:
	return spend_cost({GOLD: cost})


func gain_resources(amount: int) -> void:
	gain_currency(GOLD, amount)


## Adds a scaled enemy drop while retaining fractions across kills.
func gain_kill_resources(base_amount: int) -> void:
	if base_amount <= 0:
		return
	var earned: float = float(base_amount) * Balance.KILL_RESOURCE_SCALE \
		* Modifiers.multiplier(Modifiers.KILL_RESOURCES)
	kill_resource_remainder += earned
	var whole: int = int(floor(kill_resource_remainder))
	if whole <= 0:
		return
	kill_resource_remainder -= float(whole)
	gain_resources(whole)


## Maximum tower level the current Forge tier supports. Tier 0 still permits
## the opening two levels; each Forge tier unlocks one additional mastery tier.
func tower_level_cap() -> int:
	return clampi(Balance.TOWER_BASE_LEVEL_CAP + building_tier("forge"),
		Balance.TOWER_BASE_LEVEL_CAP, Balance.TOWER_MAX_LEVEL)


## Resource yield per distance unit, after Granary tiers and captive labour.
func production_rate(currency_id: String) -> float:
	var building_id: String = "woodcutter" if currency_id == WOOD else "granary"
	if currency_id != WOOD and currency_id != FOOD:
		return 0.0
	var producer: BuildingData = ContentDB.building(building_id)
	var rate: float = producer.effect_at(building_tier(building_id)) \
		if producer != null else 0.0
	rate += float(assigned_captive_count()) * Balance.CAPTIVE_WORK_BONUS \
		* Modifiers.multiplier(Modifiers.CAPTIVE_OUTPUT)
	return rate * Modifiers.multiplier(Modifiers.RESOURCE_RATE)


## v3 compatibility: passive "resources" means the combined basic production.
func resource_rate() -> float:
	return production_rate(WOOD) + production_rate(FOOD)


func begin_preparation_market() -> void:
	market_trades_remaining = Balance.MARKET_TRADES_PER_PREPARATION


func market_service_bought_this_act() -> bool:
	return market_service_act == act


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


## Distance at which this act ends and its boss walks in.
func act_boss_distance() -> float:
	return float(act) * Balance.ACT_DISTANCE


## How far the beast still has to walk before the act boss appears. This was
## invisible, which made a correctly-working boss trigger look like a bug: with
## nothing on screen counting down, "wave 33 and no boss" reads as broken rather
## than as "still 600 units out".
func distance_to_boss() -> float:
	return maxf(act_boss_distance() - distance_travelled, 0.0)


## 0..1 progress through the current act.
func act_progress() -> float:
	var start: float = float(act - 1) * Balance.ACT_DISTANCE
	return clampf((distance_travelled - start) / Balance.ACT_DISTANCE, 0.0, 1.0)


## Distance remaining until the next crossroad.
func distance_to_crossroad() -> float:
	var next_boundary: float = (floorf(distance_travelled / Balance.SEGMENT_DISTANCE) + 1.0) * Balance.SEGMENT_DISTANCE
	return maxf(next_boundary - distance_travelled, 0.0)


func record_wave_archetype(id: String) -> void:
	if id.is_empty():
		return
	wave_archetype_counts[id] = int(wave_archetype_counts.get(id, 0)) + 1


func most_common_wave_archetype() -> String:
	var best_id: String = ""
	var best_count: int = 0
	for key: Variant in wave_archetype_counts:
		var count: int = int(wave_archetype_counts[key])
		if count > best_count:
			best_count = count
			best_id = String(key)
	return best_id
