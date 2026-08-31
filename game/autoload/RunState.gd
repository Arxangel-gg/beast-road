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
	"gear": 518363,
	"mender": 571219,
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

## Crossroad pairs this run may still redraw. Granted by Sigil rank 2.
var crossroad_rerolls_left: int = 0
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

## Traps laid on the roads, keyed by tile: {trap_id, triggers_left}.
##
## Beside the towers rather than inside them, because the two obey opposite
## placement rules - a tower may not stand on a lane and a trap is worthless
## anywhere else - and one dictionary holding both would mean every reader had to
## know which kind it had found before it could ask anything useful.
var traps: Dictionary = {}

## Barricades raised across the roads, keyed by tile: {barricade_id, health}.
##
## Health as a *fraction* rather than an absolute, so a guest told about one
## rebuilds it against its own `max_hp` and the two cannot drift if the resource
## is ever retuned mid-version.
var barricades: Dictionary = {}

# --- Hero ------------------------------------------------------------------

var equipped_spells: Array[String] = []
var trained_discipline_nodes: Array[String] = []
var equipped_discipline_slots: Array[String] = []
var discipline_offers: Array[String] = []
var discipline_respec_uses: int = 0
var hero_ascension: int = 0

# --- Levelling ---------------------------------------------------------------
#
# All of it run-scoped. GDD v4 SS974 forbids a hero level persisting, and
# CLAUDE.md SS7 names the save's whole contents - none of this is in it.

## The four attributes, in the order their points are stored.
enum Attribute { MIGHT, VIGOUR, SWIFTNESS, FOCUS }

## The weather over the battlefield. Rolled per road, held for its duration.
##
## Per road rather than per wave: weather that changed every ninety seconds would
## be noise a player cannot plan around, and the whole point is that it is a
## condition you build *for* during Preparation.
## Keys picked up in the current raid camp.
##
## Not persisted and not carried between camps: a key is a thing you found in
## *this* camp, and banking them would turn the second raid of a run into a free
## chest opening rather than a search.
var raid_keys: int = 0

var weather_id: String = "clear"

## The campaign tier this run is being played on.
var tier_id: String = "normal"

var hero_level: int = 1
var hero_xp: float = 0.0

## Points earned and not yet placed.
var hero_attribute_points: int = 0
var hero_skill_points: int = 0

## Points placed, one entry per Attribute.
var hero_attributes: Array[int] = [0, 0, 0, 0]

## Carried between scopes so a raid is not a free heal and the walk back from
## the town is not a reset. -1 means "start at full".
var hero_hp: float = -1.0
var hero_wounds: int = 0
## Run-only reward from Oath of the Last Scar. Never written to MetaState.
var hero_max_wounds_bonus: int = 0
var has_resurrection_draught: bool = false

# --- Run challenges and rare recovery ---------------------------------------

var last_scar_offered: bool = false
var last_scar_pending: bool = false
var last_scar_active: bool = false
var last_scar_resolved: bool = false
var last_scar_failed: bool = false
var last_scar_pursuer_spawned: bool = false
var last_scar_pursuer_defeated: bool = false
var last_scar_min_town_ratio: float = 1.0

## Act number -> count. Dictionaries make a later act-count change harmless.
var mender_sparks_claimed_by_act: Dictionary = {}
var mender_eligible_elites_by_act: Dictionary = {}

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
var traps_laid: int = 0
var barricades_raised: int = 0
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
	# Shared XP arrives here rather than in a battlefield system, and the two-
	# process live check is what showed why. It was handled in `CoopHeroes`
	# first, which only exists while a battlefield does - so an award landing in
	# a raid, on a crossroad, or in a harness with no field simply vanished. Hero
	# experience is run-level state, and this is where run-level state lives.
	EventBus.coop_xp_awarded.connect(_on_coop_xp_awarded)
	EventBus.town_health_changed.connect(_on_town_health_for_last_scar)
	EventBus.coop_last_scar_resolved.connect(_on_coop_last_scar_resolved)


## The host earned experience, so this player earns the same amount.
##
## Applied to *this machine's own* hero against its own curve. The award is
## shared; the hero it lands on is not. A guest arriving at level 20 beside a
## level-5 host keeps their level and simply progresses more slowly for the same
## award, exactly as the curve already does in a solo run.
##
## Guest-only. On the host `gain_hero_xp` is what emitted this, and applying it
## again would pay the host twice.
## How much snow is lying on the field, 0..1.
##
## Here rather than only inside the weather system, because it stopped being a
## drawing concern the moment enemies started slipping on it. Working rule 6: the
## run's state lives in one place and nothing caches its own copy.
var snow_cover: float = 0.0


func _on_coop_xp_awarded(amount: float) -> void:
	if Coop.is_guest():
		gain_hero_xp(amount)


func _on_coop_last_scar_resolved(success: bool, reason: String,
		maximum: int) -> void:
	var relay: CoopRelay = Coop.relay()
	if Coop.is_guest() and relay != null and relay.is_replaying():
		mirror_last_scar_resolution(success, reason, maximum)


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
	act = 1
	segment = 0
	terrain_id = ""
	phase = Phase.PREPARATION
	active_road_id = ""
	active_road_difficulty_id = ""
	pending_road_relics.clear()
	road_history.clear()

	# **Ammunition is a run resource and resets with the run** (working rule 7).
	# The *knowledge* of how to make it persists in MetaState; the arrows
	# themselves do not, exactly like Gold. A quiver that carried over would make
	# the first road of every later run trivial for anyone who stockpiled.
	last_blow.clear()
	ammo.clear()
	ranged_id = ""
	ammo_id = ""

	currencies = {
		WOOD: Balance.STARTING_WOOD,
		FOOD: Balance.STARTING_FOOD,
		GOLD: Balance.STARTING_GOLD,
		STONE: Balance.STARTING_STONE,
	}
	# Sigil rank 2: crossroad redraws, granted per run and spent from the
	# crossroad screen. Held here rather than on MetaState because it is run
	# state - the account earns the rank, the run spends the charge.
	crossroad_rerolls_left = MetaState.sigil_crossroad_rerolls()

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
	traps.clear()
	barricades.clear()

	equipped_spells.clear()
	trained_discipline_nodes.clear()
	equipped_discipline_slots.clear()
	equipped_discipline_slots.resize(Balance.HERO_MAX_SPELL_SLOTS)
	equipped_discipline_slots.fill("")
	discipline_offers.clear()
	discipline_respec_uses = 0
	hero_ascension = 0
	raid_keys = 0
	weather_id = "clear"
	# Restored from the account, not zeroed.
	#
	# This is the owner amendment of 2026-08-20 in one place: the hero is the only
	# thing that survives a run. Towers, relics, currencies and building tiers are
	# all cleared above, exactly as they always were - a player carries who they
	# have become, not the defence they built.
	hero_level = MetaState.hero_level
	hero_xp = MetaState.hero_xp
	hero_attribute_points = MetaState.hero_attribute_points
	hero_skill_points = MetaState.hero_skill_points
	hero_attributes = MetaState.hero_attributes.duplicate()
	tier_id = MetaState.last_tier_id
	hero_hp = -1.0
	hero_wounds = 0
	hero_max_wounds_bonus = 0
	has_resurrection_draught = false
	last_scar_offered = false
	last_scar_pending = false
	last_scar_active = false
	last_scar_resolved = false
	last_scar_failed = false
	last_scar_pursuer_spawned = false
	last_scar_pursuer_defeated = false
	last_scar_min_town_ratio = 1.0
	mender_sparks_claimed_by_act.clear()
	mender_eligible_elites_by_act.clear()

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
	traps_laid = 0
	barricades_raised = 0
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
	#
	# **The seed goes in front of the id, not behind it.** Godot hashes a string
	# by running a multiply-accumulate over its characters, so a *shared suffix*
	# scales both operands by the same factor and leaves the sign of their
	# difference intact: `hash(a + seed) < hash(b + seed)` gave the same ordering
	# for almost every seed. Twenty-seven nodes rotated through three.
	#
	# Nothing noticed because every assertion asked for three unique offers and
	# always got three unique offers - the same three. `discipline_check` counts
	# how many distinct nodes the rotation can actually reach now.
	var offer_seed: int = run_seed + segment * 97 + wave_number * 31 + act * 13
	var stamp: String = str(offer_seed) + "|"
	eligible.sort_custom(func(a: DisciplineNodeData, b: DisciplineNodeData) -> bool:
		return hash(stamp + a.id) < hash(stamp + b.id))
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


## Spends a key if one is held. Returns whether it could.
func spend_raid_key() -> bool:
	if raid_keys <= 0:
		return false
	raid_keys -= 1
	return true


## The live weather, or null when the roster is missing.
func weather() -> WeatherData:
	return ContentDB.weather(weather_id)


## How much a weather helps or hurts one element right now.
func weather_scale(element: int) -> float:
	var live: WeatherData = weather()
	return live.scale_for(element) if live != null else 1.0


## Rolls the weather for a new road, weighted, and never the same twice running.
##
## Excluding a repeat matters more than it looks: with five entries and a weighted
## draw, the same weather twice in a row is common enough that players read it as
## the system being broken rather than as chance.
func roll_weather() -> void:
	var options: Array[WeatherData] = ContentDB.weathers_for_act(act)
	if options.is_empty():
		return
	var pool: Array[WeatherData] = []
	for option: WeatherData in options:
		if option.id != weather_id or options.size() == 1:
			pool.append(option)
	var total: float = 0.0
	for option: WeatherData in pool:
		total += option.weight_for_act(act)
	if total <= 0.0:
		return
	var target: float = rng("weather").randf() * total
	for option: WeatherData in pool:
		target -= option.weight_for_act(act)
		if target <= 0.0:
			weather_id = option.id
			MetaState.record_seen("weather", option.id)
			EventBus.weather_changed.emit(option.id)
			return


## XP required to leave a level.
static func hero_xp_for_level(level: int) -> float:
	if level >= Balance.HERO_MAX_LEVEL:
		return INF
	return Balance.HERO_XP_BASE * pow(float(maxi(level, 1)), Balance.HERO_XP_CURVE)


## Awards experience and resolves however many levels it crosses.
##
## Loops rather than levelling once, because a single boss kill late in a run is
## worth several levels and dropping the remainder would quietly waste it.
func gain_hero_xp(amount: float) -> void:
	if amount <= 0.0 or hero_level >= Balance.HERO_MAX_LEVEL:
		return
	# Shared XP in co-op. Owner ruling, 2026-08-25, closing the gap recorded in
	# docs/COOP_DESIGN.md §10: both players are awarded the same amount.
	#
	# The **award** travels, never the total. That distinction is the whole of
	# making this safe: hero level and XP persist per account (CLAUDE.md rule 7),
	# so two players arrive with heroes at different levels. Relaying an absolute
	# would overwrite a level-20 guest with a level-5 host's number and *demote*
	# them - a shared pool would quietly delete somebody's progress.
	#
	# Emitted before the local application so the two machines credit the same
	# figure; each then applies it to its own hero, against its own curve.
	if Coop.is_host() and Coop.partner_present():
		EventBus.coop_xp_awarded.emit(amount)
	hero_xp += amount
	var gained: int = 0
	while hero_level < Balance.HERO_MAX_LEVEL:
		var needed: float = hero_xp_for_level(hero_level)
		if hero_xp < needed:
			break
		hero_xp -= needed
		hero_level += 1
		gained += 1
		hero_attribute_points += 1
		if hero_level % Balance.HERO_SKILL_POINT_EVERY == 0:
			hero_skill_points += 1
	if hero_level >= Balance.HERO_MAX_LEVEL:
		hero_xp = 0.0
	# Keep sub-level progress in the account state as it is earned. A level-up
	# persists immediately below; otherwise the normal run-end save writes this
	# value without turning every enemy death into a disk write.
	MetaState.hero_xp = hero_xp
	if gained > 0:
		_store_hero()
		EventBus.hero_levelled.emit(hero_level, hero_attribute_points, hero_skill_points)
	var needed: float = hero_xp_for_level(hero_level)
	EventBus.hero_xp_changed.emit(hero_xp, 0.0 if is_inf(needed) else needed,
		hero_level)


## Writes hero progression back to the account.
##
## On every level and every point placed, rather than at the end of a run. A
## crash or an alt-F4 forty minutes in should not cost a player the levels they
## earned - and "the run ended properly" is exactly the case that does not
## happen when someone rage-quits a losing Hell run, which is when they most need
## the grind to have counted.
func _store_hero() -> void:
	MetaState.hero_level = hero_level
	MetaState.hero_xp = hero_xp
	MetaState.hero_attribute_points = hero_attribute_points
	MetaState.hero_skill_points = hero_skill_points
	MetaState.hero_attributes = hero_attributes.duplicate()
	MetaState.last_tier_id = tier_id
	MetaState.save_game()


## The campaign tier this run is on.
func tier() -> CampaignTierData:
	var found: CampaignTierData = ContentDB.tier(tier_id)
	if found != null:
		return found
	var all: Array[CampaignTierData] = ContentDB.tiers_sorted()
	return all[0] if not all.is_empty() else null


## What the tier expects the hero to be worth at this act's boss.
func expected_boss_level(for_act: int) -> int:
	var live: CampaignTierData = tier()
	return live.expected_level(for_act) if live != null else 1


## How far under the tier's expectancy the hero is, as a fraction. Zero when at
## or above it.
func under_levelled(for_act: int) -> float:
	var want: int = expected_boss_level(for_act)
	if want <= 1 or hero_level >= want:
		return 0.0
	return clampf(1.0 - float(hero_level) / float(want), 0.0, 1.0)


## Fraction of the way to the next level, for the HUD.
func hero_level_progress() -> float:
	if hero_level >= Balance.HERO_MAX_LEVEL:
		return 1.0
	return clampf(hero_xp / maxf(hero_xp_for_level(hero_level), 1.0), 0.0, 1.0)


## Places one point. Returns why not, or "" when it landed.
func spend_attribute_point(attribute: int) -> String:
	if hero_attribute_points <= 0:
		return "No attribute points to spend."
	if attribute < 0 or attribute >= hero_attributes.size():
		return "No such attribute."
	hero_attribute_points -= 1
	hero_attributes[attribute] += 1
	_store_hero()
	EventBus.hero_attributes_changed.emit()
	return ""


## An attribute's total: points the player placed, plus points their gear grants.
##
## Gear is folded in here rather than at each use site, so every consumer -
## damage, health, movement, command - reads one number and none of them can be
## the one that forgot about equipment.
func attribute(which: int) -> int:
	if which < 0 or which >= hero_attributes.size():
		return 0
	var worn: Array[int] = MetaState.gear_attribute_points()
	var bonus: int = worn[which] if which < worn.size() else 0
	return hero_attributes[which] + bonus


## How many discipline nodes this hero may hold, which grows with level.
func discipline_cap() -> int:
	return Balance.DISCIPLINE_MAX_TRAINED 		+ int(hero_level / Balance.HERO_DISCIPLINE_CAP_EVERY)


func try_train_discipline(id: String) -> String:
	if not is_preparation():
		return "Hero training is available only in Preparation."
	var node: DisciplineNodeData = ContentDB.discipline_node(id)
	if node == null:
		return "That discipline node is unavailable."
	if trained_discipline_nodes.has(id):
		return "Already trained."
	if trained_discipline_nodes.size() >= discipline_cap():
		return "%d nodes is the limit at level %d. Level up or respec." 			% [discipline_cap(), hero_level]
	# A skill point as well as the Food. Two gates on purpose: the point is the
	# growth the player earned by fighting, the Food is the Preparation decision
	# they make against their towers. Either alone would be weaker - skill points
	# only, and the hero stops competing with the defence for resources; Food
	# only, and levelling has nothing to say about the skill tree.
	if hero_skill_points <= 0:
		return "Needs a skill point. Level up to earn one."
	if building_tier("sanctum") < node.mansion_tier:
		return "Hero Mansion tier %d is required." % node.mansion_tier
	if not discipline_offers.has(id):
		return "That node is not in this road's offers."
	if not can_afford_cost({FOOD: node.food_cost}):
		return "Needs %d Food." % node.food_cost
	spend_cost({FOOD: node.food_cost})
	hero_skill_points -= 1
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


## What is laid on a tile, or null.
func trap_at(tile: Vector2i) -> TrapData:
	var entry: Dictionary = traps.get(tile, {}) as Dictionary
	return ContentDB.trap(String(entry.get("trap_id", "")))


## How many triggers that trap has left.
func trap_triggers_left(tile: Vector2i) -> int:
	return int((traps.get(tile, {}) as Dictionary).get("triggers_left", 0))


func set_trap(tile: Vector2i, trap_id: String, triggers_left: int) -> void:
	traps[tile] = {"trap_id": trap_id, "triggers_left": triggers_left}
	EventBus.trap_changed.emit(tile)


func clear_trap(tile: Vector2i) -> void:
	if not traps.has(tile):
		return
	traps.erase(tile)
	EventBus.trap_changed.emit(tile)


## What stands on a tile, or null.
func barricade_at(tile: Vector2i) -> BarricadeData:
	var entry: Dictionary = barricades.get(tile, {}) as Dictionary
	return ContentDB.barricade(String(entry.get("barricade_id", "")))


func barricade_health(tile: Vector2i) -> float:
	return float((barricades.get(tile, {}) as Dictionary).get("health", 1.0))


func set_barricade(tile: Vector2i, barricade_id: String, health: float) -> void:
	barricades[tile] = {"barricade_id": barricade_id, "health": health}
	EventBus.barricade_changed.emit(tile)


func clear_barricade(tile: Vector2i) -> void:
	if not barricades.has(tile):
		return
	barricades.erase(tile)
	EventBus.barricade_changed.emit(tile)


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
	hero_wounds = mini(hero_wounds + 1, max_wounds())
	wounds_suffered += 1
	if last_scar_active:
		last_scar_failed = true
	Modifiers.rebuild()
	EventBus.hero_wounds_changed.emit(hero_wounds, max_wounds())
	return hero_wounds


func hearthmend() -> void:
	hero_wounds = 0
	hearthmends_used += 1
	Modifiers.rebuild()
	hero_hp = -1.0
	var repair: float = town_max_hp * Balance.HEARTHMEND_TOWN_REPAIR_FRACTION
	town_hp = minf(town_hp + repair, town_max_hp)
	EventBus.hero_wounds_changed.emit(hero_wounds, max_wounds())
	EventBus.town_health_changed.emit(town_hp, town_max_hp)
	EventBus.hearthmend_completed.emit(act)


func max_wounds() -> int:
	return Balance.HERO_MAX_WOUNDS + hero_max_wounds_bonus


## One authored offer, once per run. Having suffered rather than still carrying
## a Wound lets Hearthmend work without erasing qualification.
func can_offer_last_scar() -> bool:
	return act == Balance.LAST_SCAR_OFFER_ACT and wounds_suffered > 0 \
		and not last_scar_offered and not last_scar_resolved


func accept_last_scar() -> bool:
	if not can_offer_last_scar():
		return false
	last_scar_offered = true
	last_scar_pending = true
	EventBus.last_scar_changed.emit("pending")
	return true


func mirror_accept_last_scar() -> void:
	last_scar_offered = true
	last_scar_pending = true
	EventBus.last_scar_changed.emit("pending")


## The vow attaches to the road ultimately chosen, not to opening its card.
func start_last_scar_road() -> void:
	if not last_scar_pending:
		return
	last_scar_pending = false
	last_scar_active = true
	last_scar_failed = false
	last_scar_pursuer_spawned = false
	last_scar_pursuer_defeated = false
	last_scar_min_town_ratio = town_hp / town_max_hp if town_max_hp > 0.0 else 0.0
	EventBus.last_scar_changed.emit("active")


func last_scar_locks_rations() -> bool:
	return last_scar_active


func mark_last_scar_pursuer_spawned() -> void:
	last_scar_pursuer_spawned = true


func mark_last_scar_pursuer_defeated() -> void:
	if last_scar_active:
		last_scar_pursuer_defeated = true
		EventBus.last_scar_changed.emit("pursuer_defeated")


func _on_town_health_for_last_scar(current: float, maximum: float) -> void:
	if last_scar_active and maximum > 0.0:
		last_scar_min_town_ratio = minf(last_scar_min_town_ratio, current / maximum)


## Settled at the next road boundary. An empty dictionary means no active oath.
func resolve_last_scar_road() -> Dictionary:
	if not last_scar_active:
		return {}
	var reason: String = "complete"
	if last_scar_failed:
		reason = "wound"
	elif last_scar_min_town_ratio < Balance.LAST_SCAR_TOWN_MIN_RATIO:
		reason = "town"
	elif not last_scar_pursuer_defeated:
		reason = "pursuer"
	var success: bool = reason == "complete"
	last_scar_active = false
	last_scar_resolved = true
	if success:
		hero_max_wounds_bonus = Balance.LAST_SCAR_MAX_WOUND_BONUS
		EventBus.hero_wounds_changed.emit(hero_wounds, max_wounds())
	EventBus.last_scar_resolved.emit(success, reason, max_wounds())
	return {"success": success, "reason": reason, "maximum": max_wounds()}


## Applies the authority's settled result on a guest.
func mirror_last_scar_resolution(success: bool, reason: String, maximum: int) -> void:
	last_scar_pending = false
	last_scar_active = false
	last_scar_resolved = true
	hero_max_wounds_bonus = maxi(maximum - Balance.HERO_MAX_WOUNDS, 0) if success else 0
	EventBus.hero_wounds_changed.emit(hero_wounds, max_wounds())
	EventBus.last_scar_resolved.emit(success, reason, max_wounds())


func can_roll_mender_spark() -> bool:
	return int(mender_sparks_claimed_by_act.get(act, 0)) \
		< Balance.MENDER_SPARK_MAX_PER_ACT


## Pity is per act. The allowance is consumed when the drop appears, so leaving
## it on the road is a tactical choice rather than a reroll.
func roll_mender_spark() -> bool:
	if not can_roll_mender_spark():
		return false
	var eligible: int = int(mender_eligible_elites_by_act.get(act, 0)) + 1
	mender_eligible_elites_by_act[act] = eligible
	var drops: bool = eligible >= Balance.MENDER_SPARK_PITY_ELITES \
		or rng("mender").randf() <= Balance.MENDER_SPARK_DROP_CHANCE
	if drops:
		mender_sparks_claimed_by_act[act] = \
			int(mender_sparks_claimed_by_act.get(act, 0)) + 1
		mender_eligible_elites_by_act[act] = 0
	return drops


func gain_command(amount: float) -> void:
	if amount <= 0.0 or not is_command_combat():
		return
	# Focus. Applied to the gain rather than to the ceiling, so it makes orders
	# come round faster without letting a player bank more of them.
	amount *= 1.0 + float(attribute(Attribute.FOCUS)) * Balance.HERO_FOCUS_COMMAND_PER_POINT
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

## The last thing to hurt a hero, and how hard.
##
## **Recorded where the blow is dealt, not where it lands.** `Health.take_damage`
## receives a position and an amount; it has no idea what swung. The attacker is
## the only one who knows its own name, so each source says so on its way past.
##
## Cleared with the run. The debrief reads it to answer the one question a death
## screen has always owed the player: what killed me, and for how much.
var last_blow: Dictionary = {}


## Notes a blow against a hero. Cheap enough to call from every strike.
func note_blow(source_name: String, amount: float) -> void:
	if source_name.is_empty() or amount <= 0.0:
		return
	last_blow = {"source": source_name, "amount": amount}


## "a Rimewarded Bogkin for 34", or "" when nothing has landed yet.
func last_blow_line() -> String:
	if last_blow.is_empty():
		return ""
	return "%s for %d" % [String(last_blow.get("source", "?")),
		int(round(float(last_blow.get("amount", 0.0))))]


# --- Ranged combat -----------------------------------------------------------
#
# Owner decision, 2026-08-31. Three pieces of run state and one rule.

## Ammunition held, by ammo id. **Its own purse, not the four currencies and not
## the stash.**
##
## Kept apart deliberately. Ammunition in the normal inventory would make every
## arrow compete with loot for room, which is how players come to resent a system
## meant to give them options - and a decision about arrows must never compete
## with the wall about to be overrun, the same reasoning that keeps Marks off the
## tower economy.
var ammo: Dictionary = {}

## What the hero has drawn, and what is nocked. Empty means melee only, which is
## where every run starts.
var ranged_id: String = ""
var ammo_id: String = ""


## How much room the quiver has left, counting each shot's bulk.
##
## Bulk is the whole of the scarcity model: no rarity tiers, no encumbrance, no
## second currency. A quiver simply holds fewer bombs than arrows.
func ammo_bulk_used() -> int:
	var used: int = 0
	for id: Variant in ammo.keys():
		var kind := ContentDB.ammo_kinds.get(id, null) as AmmoData
		if kind != null:
			used += int(ammo[id]) * kind.bulk
	return used


func ammo_room() -> int:
	return maxi(Balance.AMMO_CAPACITY - ammo_bulk_used(), 0)


func ammo_count(id: String) -> int:
	return int(ammo.get(id, 0))


## Adds ammunition, refusing what will not fit. Returns how many actually went in.
##
## Refuses rather than silently discarding: a pickup that vanishes into a full
## quiver reads as the game losing it.
func gain_ammo(id: String, amount: int) -> int:
	var kind := ContentDB.ammo_kinds.get(id, null) as AmmoData
	if kind == null or amount <= 0:
		return 0
	var fits: int = ammo_room() / maxi(kind.bulk, 1)
	var taken: int = mini(amount, fits)
	if taken <= 0:
		return 0
	ammo[id] = ammo_count(id) + taken
	EventBus.ammo_changed.emit(id, ammo_count(id))
	return taken


## Spends one shot. False when the quiver is empty, which is the caller's cue to
## fall back rather than to fire nothing.
func spend_one_ammo(id: String) -> bool:
	var held: int = ammo_count(id)
	if held <= 0:
		return false
	if held == 1:
		ammo.erase(id)
	else:
		ammo[id] = held - 1
	EventBus.ammo_changed.emit(id, ammo_count(id))
	return true


## The ammunition this weapon can fire, in a stable order, known recipes only.
func ammo_for_weapon(weapon_id: String) -> Array[AmmoData]:
	var out: Array[AmmoData] = []
	var weapon := ContentDB.ranged_weapons.get(weapon_id, null) as RangedWeaponData
	if weapon == null:
		return out
	var ids: Array = ContentDB.ammo_kinds.keys()
	ids.sort()
	for id: Variant in ids:
		var kind := ContentDB.ammo_kinds[id] as AmmoData
		if kind != null and kind.family == weapon.family:
			out.append(kind)
	return out


## Makes a batch. Returns "" on success, or the reason it refused.
##
## **Blueprint first, then cost, then room.** Checked in that order because they
## are three different answers: one says learn it, one says gather more, and one
## says you are already carrying as much as you can.
func craft_ammo(id: String, batches: int = 1) -> String:
	var kind := ContentDB.ammo_kinds.get(id, null) as AmmoData
	if kind == null:
		return "Nothing is made to that pattern."
	if not kind.known_from_the_start and not MetaState.knows_recipe("ammo", id):
		return "You do not know how to make %s." % kind.display_name
	var runs: int = maxi(batches, 1)
	var cost: Dictionary = {}
	for currency_id: Variant in kind.craft_cost.keys():
		cost[currency_id] = int(kind.craft_cost[currency_id]) * runs
	if not can_afford_cost(cost):
		return "Needs %s." % format_cost(cost)
	var made: int = kind.craft_batch * runs
	if ammo_room() < made * kind.bulk:
		return "No room for that many %s." % kind.display_name
	spend_cost(cost)
	gain_ammo(id, made)
	return ""


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
	# Twice the bodies into one shared pool is twice the income, and the tower
	# curve was tuned against one player earning. The trim is 1.0 today because
	# the measured curve did not need one; it exists so that if co-op ever plays
	# rich, the fix is a constant rather than a redesign.
	if Coop.partner_present():
		earned *= Balance.COOP_KILL_INCOME_SCALE
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
