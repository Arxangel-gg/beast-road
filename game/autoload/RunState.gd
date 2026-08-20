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
## True once this run has killed the Act 3 boss.
##
## The run does not end there any more - it rolls into Endless - so the win has
## to be remembered rather than reported on the spot. Without it, dying in
## Endless would file a run that beat the game as a loss.
var summit_reached: bool = false

## True while the run is past its finish line and simply seeing how far it goes.
var endless: bool = false

## Waves survived since Endless began. Drives the extra escalation on top of the
## ordinary per-wave growth, so Endless keeps getting harder rather than settling
## at whatever Act 3 happened to end on.
var endless_wave: int = 0

var phase: Phase = Phase.PREPARATION
var active_road_id: String = ""
var active_road_difficulty_id: String = ""
## Populated only after a Relic Hunt is completed, then consumed by its modal.
var pending_road_relics: Array[String] = []

## Public QA/debrief seed. Every gameplay-random system receives its own named
## stream derived from this value, so adding a spark or audio variation cannot
## silently change tomorrow's formation or crossroad.
var run_seed: int = 1
var road_history: Array[Dictionary] = []
var _rng_streams: Dictionary = {}

const RNG_MIN_SEED: int = 100000000
const RNG_MAX_SEED: int = 999999999
const RNG_STREAM_SALTS: Dictionary = {
	"waves": 104729,
	"roads": 224737,
	"raids": 350377,
	"rewards": 479909,
	"bosses": 611953,
	"combat": 746773,
}

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
## Every tower standing on the battlefield, keyed by the top-left tile of its
## 2x2 footprint (GDD §13). Placement is free, so there is no fixed slot list
## any more and no upper bound - the economy is the limit.
##
## Run-only, like everything else here. Nothing about a battlefield reaches the
## account save.
var towers: Dictionary = {}

# --- Hero ------------------------------------------------------------------

var equipped_spells: Array[String] = []
var trained_discipline_nodes: Array[String] = []
var equipped_discipline_slots: Array[String] = []
var discipline_offers: Array[String] = []
var discipline_respec_uses: int = 0
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


## Rebuilds every gameplay stream. Tests and QA call this with an explicit
## value; normal runs receive a fresh nine-digit code from time, date and pid.
func set_seed(value: int) -> void:
	run_seed = clampi(absi(value), 1, RNG_MAX_SEED)
	_rng_streams.clear()
	# Keep global gameplay calls deterministic while named streams protect major
	# systems from consuming each other's sequence.
	seed(run_seed)


func rng(stream: String) -> RandomNumberGenerator:
	if _rng_streams.has(stream):
		return _rng_streams[stream] as RandomNumberGenerator
	var generator := RandomNumberGenerator.new()
	var salt: int = int(RNG_STREAM_SALTS.get(stream, hash(stream)))
	generator.seed = run_seed * 1000003 + salt
	_rng_streams[stream] = generator
	return generator


func record_road_choice(segment_index: int, road_id: String, difficulty_id: String) -> void:
	road_history.append({
		"segment": segment_index,
		"road": road_id,
		"difficulty": difficulty_id,
	})


func seed_code() -> String:
	return "%09d" % run_seed


## Watchtower tiers and socketed foresight relics feed one bounded information
## ladder. A relic can supply a missing tier but can never reveal beyond tier 3.
func foresight_tier() -> int:
	return clampi(building_tier("watchtower") \
		+ int(round(Modifiers.value(Modifiers.WAVE_FORESIGHT))), 0, 3)


func _fresh_seed() -> int:
	var stamp: Dictionary = Time.get_datetime_dict_from_system(true)
	var value: int = int(Time.get_ticks_usec()) ^ OS.get_process_id() * 7919
	value ^= int(stamp.get("year", 0)) * 366 + int(stamp.get("day", 0)) * 86400
	return RNG_MIN_SEED + posmod(value, RNG_MAX_SEED - RNG_MIN_SEED + 1)


## Wipes everything. Called when a run begins, never mid-run — death wipes the
## run entirely (GDD §10).
func reset(use_treasury_cache: bool = false, requested_seed: int = 0) -> void:
	set_seed(requested_seed if requested_seed != 0 else _fresh_seed())
	distance_travelled = 0.0
	beast_speed = Balance.BEAST_BASE_SPEED
	summit_reached = false
	endless = false
	endless_wave = 0
	act = 1
	segment = 0
	terrain_id = ""
	phase = Phase.PREPARATION
	active_road_id = ""
	active_road_difficulty_id = ""
	pending_road_relics.clear()
	road_history.clear()

	currencies = {
		WOOD: Balance.STARTING_WOOD,
		FOOD: Balance.STARTING_FOOD,
		GOLD: Balance.STARTING_GOLD,
		STONE: Balance.STARTING_STONE,
	}
	# Sigil rank 1: a modest bundle on every currency (v4 §36). Applied before
	# the Treasury cache so the two stack rather than one replacing the other.
	var bundle: int = MetaState.sigil_starting_supply()
	if bundle > 0:
		for id: String in CURRENCIES:
			currencies[id] = currency(id) + bundle

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

	towers.clear()

	equipped_spells.clear()
	trained_discipline_nodes.clear()
	equipped_discipline_slots.clear()
	equipped_discipline_slots.resize(Balance.HERO_MAX_SPELL_SLOTS)
	equipped_discipline_slots.fill("")
	discipline_offers.clear()
	discipline_respec_uses = 0
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

	_setup_starting_disciplines()

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


## Curated first-run pair. Attack modifies the basic chain; Defense is a cast.
## The ids remain content, and the existence checks make save migration safe if
## a future release replaces either starter.
func _setup_starting_disciplines() -> void:
	for id: String in ["hemorrhage_edge", "aegis_step"]:
		var node: DisciplineNodeData = ContentDB.discipline_node(id)
		if node == null:
			continue
		trained_discipline_nodes.append(id)
		var slot: int = node.slot_index()
		if slot >= 0 and equipped_discipline_slots[slot].is_empty():
			equipped_discipline_slots[slot] = id
	_sync_discipline_spells()
	refresh_discipline_offers()


func discipline_node_in_slot(slot: int) -> DisciplineNodeData:
	if slot < 0 or slot >= equipped_discipline_slots.size():
		return null
	return ContentDB.discipline_node(equipped_discipline_slots[slot])


func refresh_discipline_offers() -> void:
	discipline_offers.clear()
	var mansion_tier: int = building_tier("sanctum")
	if mansion_tier <= 0:
		return
	var eligible: Array[DisciplineNodeData] = []
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.mansion_tier <= mansion_tier and not trained_discipline_nodes.has(node.id):
			eligible.append(node)
	# Deterministic per-road rotation: replaying a save cannot reroll by reopening
	# the panel, while the next road still produces a new set.
	eligible.sort_custom(func(a: DisciplineNodeData, b: DisciplineNodeData) -> bool:
		var offer_seed: int = run_seed + segment * 97 + wave_number * 31 + act * 13
		return hash(a.id + str(offer_seed)) < hash(b.id + str(offer_seed)))
	for node: DisciplineNodeData in eligible:
		if discipline_offers.size() >= 3:
			break
		discipline_offers.append(node.id)
	# Always expose at least one off-discipline choice when the eligible pool has
	# one, rather than letting synergy turn into a forced mono-build.
	if not discipline_offers.is_empty():
		var lead: DisciplineNodeData = ContentDB.discipline_node(discipline_offers[0])
		var has_off: bool = false
		for id: String in discipline_offers:
			var offered: DisciplineNodeData = ContentDB.discipline_node(id)
			has_off = has_off or (offered != null and lead != null \
				and offered.discipline != lead.discipline)
		if not has_off and lead != null:
			for node: DisciplineNodeData in eligible:
				if node.discipline != lead.discipline:
					discipline_offers[discipline_offers.size() - 1] = node.id
					break


func try_train_discipline(id: String) -> String:
	if not is_preparation():
		return "Hero training is available only in Preparation."
	var node: DisciplineNodeData = ContentDB.discipline_node(id)
	if node == null:
		return "That discipline node is unavailable."
	if trained_discipline_nodes.has(id):
		return "Already trained."
	if trained_discipline_nodes.size() >= Balance.DISCIPLINE_MAX_TRAINED:
		return "Six nodes is the run limit. Respec before training another."
	if building_tier("sanctum") < node.mansion_tier:
		return "Hero Mansion tier %d is required." % node.mansion_tier
	if not discipline_offers.has(id):
		return "That node is not in this road's offers."
	if not can_afford_cost({FOOD: node.food_cost}):
		return "Needs %d Food." % node.food_cost
	spend_cost({FOOD: node.food_cost})
	trained_discipline_nodes.append(id)
	discipline_offers.erase(id)
	if node.is_active_slot() and node.is_slot_unlocked(act):
		var slot: int = node.slot_index()
		if equipped_discipline_slots[slot].is_empty():
			equipped_discipline_slots[slot] = id
			_sync_discipline_spells()
	EventBus.discipline_trained.emit(id, node.food_cost)
	return ""


func try_equip_discipline(id: String) -> String:
	if not is_preparation():
		return "Loadout changes are available only in Preparation."
	if not trained_discipline_nodes.has(id):
		return "Train that node first."
	var node: DisciplineNodeData = ContentDB.discipline_node(id)
	if node == null or not node.is_active_slot():
		return "That node is a doctrine, not an active slot."
	if not node.is_slot_unlocked(act):
		return "%s unlocks after the Act %d boss." % [node.slot_name(),
			1 if node.role == DisciplineNodeData.Role.POWER else 2]
	var slot: int = node.slot_index()
	equipped_discipline_slots[slot] = id
	_sync_discipline_spells()
	EventBus.discipline_equipped.emit(slot, id)
	return ""


func discipline_respec_cost() -> int:
	return Balance.DISCIPLINE_RESPEC_BASE_COST \
		+ discipline_respec_uses * Balance.DISCIPLINE_RESPEC_COST_STEP


func try_respec_disciplines() -> String:
	if not is_preparation():
		return "Respec is available only in Preparation."
	var cost: int = discipline_respec_cost()
	if not can_afford_cost({FOOD: cost}):
		return "Needs %d Food." % cost
	spend_cost({FOOD: cost})
	discipline_respec_uses += 1
	trained_discipline_nodes.clear()
	equipped_discipline_slots.fill("")
	_setup_starting_disciplines()
	EventBus.discipline_respecced.emit(cost, discipline_respec_uses)
	return ""


func _sync_discipline_spells() -> void:
	equipped_spells.clear()
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		var node: DisciplineNodeData = discipline_node_in_slot(slot)
		equipped_spells.append(node.spell_id if node != null else "")
	EventBus.spells_changed.emit()


# --- Tower placement --------------------------------------------------------

func tower_entry(anchor: Vector2i) -> Dictionary:
	return towers.get(anchor, {})


func tile_is_empty(anchor: Vector2i) -> bool:
	return not towers.has(anchor)


func tower_at(anchor: Vector2i) -> TowerData:
	var entry: Dictionary = tower_entry(anchor)
	if entry.is_empty():
		return null
	return ContentDB.tower(String(entry.get("tower_id", "")))


func level_at(anchor: Vector2i) -> int:
	return int(tower_entry(anchor).get("level", 0))


func set_tower(anchor: Vector2i, tower_id: String, level: int) -> void:
	var priority: int = int(tower_entry(anchor).get("target_priority",
		TowerData.TargetPriority.FIRST))
	towers[anchor] = {"tower_id": tower_id, "level": level, "target_priority": priority}
	EventBus.tower_changed.emit(anchor)


func clear_tower(anchor: Vector2i) -> void:
	if not towers.has(anchor):
		return
	towers.erase(anchor)
	EventBus.tower_changed.emit(anchor)


func target_priority_at(anchor: Vector2i) -> int:
	return int(tower_entry(anchor).get("target_priority", TowerData.TargetPriority.FIRST))


func cycle_target_priority(anchor: Vector2i) -> int:
	if not towers.has(anchor):
		return TowerData.TargetPriority.FIRST
	var count: int = TowerData.TargetPriority.size()
	var priority: int = (target_priority_at(anchor) + 1) % count
	towers[anchor]["target_priority"] = priority
	EventBus.tower_targeting_changed.emit(anchor, priority)
	return priority


## Which road a tower answers to, for lane armour, Rally and pressure.
##
## Free placement means a tower is not *in* a lane any more, but several systems
## still need one: road armour applies to a road, Rally targets a road. The
## nearest cardinal by angle is the honest answer - it is the road the tower is
## most plausibly defending.
static func tower_lane(anchor: Vector2i) -> int:
	var at: Vector2 = BattleGrid.footprint_centre(anchor)
	if at.is_zero_approx():
		return 0
	var best: int = 0
	var best_dot: float = -INF
	for lane: int in Balance.LANE_COUNT:
		var dot: float = at.normalized().dot(BattleGrid.lane_vector(lane))
		if dot > best_dot:
			best_dot = dot
			best = lane
	return best


## Every anchor whose tower answers to this road.
func towers_on_lane(lane: int) -> Array:
	var found: Array = []
	for key: Variant in towers:
		var anchor: Vector2i = key
		if tower_lane(anchor) == lane:
			found.append(anchor)
	return found


# --- Fusion by adjacency ----------------------------------------------------

## The four orthogonal neighbours a fusion could pair across.
##
## A tower is 2x2, so "exactly one tower-width gap" is a step of four tiles: two
## for this tower, two for the gap. Diagonals are deliberately excluded (GDD §13).
const FUSION_STEP: int = BattleGrid.FOOTPRINT * 2

static func fusion_partners(anchor: Vector2i) -> Array[Vector2i]:
	return [
		anchor + Vector2i(FUSION_STEP, 0),
		anchor + Vector2i(-FUSION_STEP, 0),
		anchor + Vector2i(0, FUSION_STEP),
		anchor + Vector2i(0, -FUSION_STEP),
	]


## Every combination that could be built on this tile, given what flanks it.
##
## Returns one entry per qualifying pair: {"tower": TowerData, "a": Vector2i,
## "b": Vector2i}. More than one pair can qualify, and v4 §13 says the player
## chooses rather than the game picking for them.
func combinations_for_tile(anchor: Vector2i) -> Array[Dictionary]:
	var offered: Array[Dictionary] = []
	var seen: Dictionary = {}
	# From the *gap*, each parent is one footprint away - not two. Two is the
	# distance between the parents themselves, which is what `fusion_partners`
	# measures; measuring from the middle with the same number looked past both
	# of them and offered nothing.
	for axis: Vector2i in [Vector2i(BattleGrid.FOOTPRINT, 0), Vector2i(0, BattleGrid.FOOTPRINT)]:
		var a: Vector2i = anchor - axis
		var b: Vector2i = anchor + axis
		var left: TowerData = tower_at(a)
		var right: TowerData = tower_at(b)
		if left == null or right == null:
			continue
		# A fusion parent may not itself be a fusion.
		if left.is_combination or right.is_combination:
			continue
		var made: TowerData = ContentDB.combination_for(left.element, right.element)
		if made == null or seen.has(made.id):
			continue
		seen[made.id] = true
		offered.append({"tower": made, "a": a, "b": b})
	return offered


## True when this tower's flanking parents still stand.
##
## A fusion whose parent was destroyed keeps firing at reduced output (GDD §20),
## so this is a question about utility, not existence.
func fusion_parents_intact(anchor: Vector2i) -> bool:
	var entry: Dictionary = tower_entry(anchor)
	if entry.is_empty():
		return true
	var built: TowerData = tower_at(anchor)
	if built == null or not built.is_combination:
		return true
	for axis: Vector2i in [Vector2i(BattleGrid.FOOTPRINT, 0), Vector2i(0, BattleGrid.FOOTPRINT)]:
		if tower_at(anchor - axis) != null and tower_at(anchor + axis) != null:
			return true
	return false


## True when this tower is one of a matching pair that could fuse (GDD §4.2).
##
## Same-element resonance now follows the same adjacency rule as fusion: the pair
## that *would* fuse is the pair that resonates. A tower with a same-element
## partner exactly one tower-width away, orthogonally, gets the bonus - so
## resonance is something the player arranges on the grid rather than something a
## fixed slot handed them.
func has_fusion_synergy(anchor: Vector2i) -> bool:
	var mine: TowerData = tower_at(anchor)
	if mine == null or mine.is_combination:
		return false
	for partner: Vector2i in fusion_partners(anchor):
		var other: TowerData = tower_at(partner)
		if other != null and not other.is_combination and other.element == mine.element:
			return true
	return false


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
	Modifiers.rebuild()
	EventBus.hero_wounds_changed.emit(hero_wounds, Balance.HERO_MAX_WOUNDS)
	return hero_wounds


func hearthmend() -> void:
	hero_wounds = 0
	hearthmends_used += 1
	Modifiers.rebuild()
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


## Funds every wallet. For harnesses that want to build without the economy
## being the subject of the test - since towers draw on a secondary currency per
## element now, funding Gold alone buys only the Fire roster.
func gain_every_currency(amount: int) -> void:
	for id: String in CURRENCIES:
		gain_currency(id, amount)


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


func active_road() -> RoadData:
	return ContentDB.road(active_road_id)


func active_road_difficulty() -> RoadDifficultyData:
	return ContentDB.road_difficulty(active_road_difficulty_id)


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
	var remaining: float = maxf(next_boundary - distance_travelled, 0.0)
	var road: RoadData = active_road()
	return remaining * (road.distance_scale if road != null else 1.0)


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


## True while the run is climbing to the summit, past the three acts.
func is_final_ascent() -> bool:
	return act >= Balance.FINAL_ASCENT_ACT


## Distance at which the Chainmaker is due.
func final_ascent_target() -> float:
	return Balance.JOURNEY_TOTAL_DISTANCE + Balance.FINAL_ASCENT_DISTANCE


## Leaves the three acts behind and starts the climb.
func begin_final_ascent() -> void:
	act = Balance.FINAL_ASCENT_ACT
	set_phase(Phase.FINAL_ASCENT)


## Switches the run to Endless.
##
## `from_summit` is what separates the victory lap from the mode picked off the
## menu: only the former is a win. Without the distinction, starting Endless from
## the front door would file every death as a completed campaign.
func begin_endless(from_summit: bool) -> void:
	summit_reached = summit_reached or from_summit
	endless = true
	endless_wave = 0


## Counts one Endless wave. Called by the wave director, not by the clock, so
## the escalation tracks what the player actually fought.
func count_endless_wave() -> void:
	if endless:
		endless_wave += 1


## Extra multiplier applied on top of ordinary wave growth once Endless starts.
func endless_scale(per_wave: float) -> float:
	return 1.0 + per_wave * float(endless_wave)
