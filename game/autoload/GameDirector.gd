extends Node

## Owns scene flow and the run lifecycle (GDD §9).
##
## Splash -> Menu -> Run -> win/lose -> unlock payout -> Menu. Nothing else
## calls `change_scene_to_file`; systems ask here so there is one place that
## knows what state the game is in.

## The four scopes the player moves between during a run, plus the overlays
## that suspend them.
enum Scope {
	BATTLEFIELD,
	TOWN,
	BEAST,
	RAID,
	CROSSROAD,
}

const SPLASH_SCENE: String = "res://scenes/ui/splash.tscn"
const MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const RUN_SCENE: String = "res://scenes/run/run.tscn"

var current_scope: Scope = Scope.BATTLEFIELD

## True between run_started and run_ended.
var run_active: bool = false


func _ready() -> void:
	EventBus.boss_defeated.connect(_on_boss_felled)
	CursorKit.apply()


func _exit_tree() -> void:
	CursorKit.clear()


func goto_splash() -> void:
	_change(SPLASH_SCENE)


func goto_menu() -> void:
	run_active = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	CursorKit.use_default()
	_change(MENU_SCENE)


## `endless` starts the run already past its finish line: the three acts still
## play, but the escalation compounds from the first wave and nothing stops at
## the summit. Unlocked by finishing the campaign once.
func start_run(requested_seed: int = 0, endless: bool = false) -> void:
	var consumed_cache: bool = not MetaState.resource_cache.is_empty()
	RunState.reset(true, requested_seed)
	if endless:
		RunState.begin_endless(false)
	# Consuming Treasury carry-over is a real transaction. Persist it now so a
	# crash/restart cannot spend the same cache repeatedly.
	if consumed_cache:
		MetaState.save_game()
	run_active = true
	current_scope = Scope.BATTLEFIELD
	get_tree().paused = false
	Engine.time_scale = 1.0
	_change(RUN_SCENE)


## Ends the run, pays out unlocks, and records statistics. `victory` is true
## only when the Act 3 boss died.
func end_run(victory: bool) -> void:
	if not run_active:
		return
	run_active = false

	# A run that reached the summit is a win however it ends. Endless is the
	# victory lap, and the town falling on lap nine does not retract the win.
	victory = victory or RunState.summit_reached

	var summary: Dictionary = {
		"victory": victory,
		"seed": RunState.run_seed,
		"roads": RunState.road_history.duplicate(true),
		"distance": RunState.distance_travelled,
		"act": RunState.act,
		"kills": RunState.enemies_killed,
		"deaths": RunState.hero_deaths,
		"raids": RunState.raids_completed,
		"chieftains": RunState.chieftains_taken,
		"time": RunState.run_time_seconds,
		"planning_time": RunState.planning_time_seconds,
		"resources_earned": RunState.resources_earned,
		"resources_spent": RunState.resources_spent,
		"currency_earned": RunState.currency_earned.duplicate(true),
		"currency_spent": RunState.currency_spent.duplicate(true),
		"towers_built": RunState.towers_built,
		"tower_upgrades": RunState.tower_upgrades,
		"towers_sold": RunState.towers_sold,
		"towers_lost": RunState.towers_lost,
		"town_damage": RunState.town_damage_taken,
		"town_hits": RunState.town_hits_taken,
		"peak_pressure": RunState.peak_lane_pressure,
		"most_common_wave": RunState.most_common_wave_archetype(),
		"wave_archetypes": RunState.wave_archetype_counts.duplicate(true),
		"command_earned": RunState.command_earned,
		"command_orders": RunState.command_orders_used.duplicate(true),
		"wounds": RunState.wounds_suffered,
		"hearthmends": RunState.hearthmends_used,
		"endless_waves": RunState.endless_wave,
		"unlocks": _pay_out_unlocks(victory),
	}

	MetaState.runs_started += 1
	if victory:
		MetaState.runs_won += 1
		MetaState.act3_cleared = true
	MetaState.best_distance = maxf(MetaState.best_distance, RunState.distance_travelled)
	MetaState.total_enemies_killed += RunState.enemies_killed
	_bank_treasury_cache()
	MetaState.save_game()

	EventBus.run_ended.emit(victory, summary)


## Felling an act boss widens the roster by one tower, permanently.
##
## v4 §35: elements are never gated - the account opens able to build all four
## and every fusion. What is earned is the *roster*, the eight later towers that
## widen each element from two roles to four. Tied to act bosses so the toolkit
## grows at the pace the run does, and so a new player meets one new tower at a
## time instead of sixteen at once.
func _on_boss_felled(_boss_id: String, _act: int) -> void:
	var earned: String = MetaState.earn_next_roster_tower()
	if earned.is_empty():
		return
	EventBus.unlock_earned.emit("tower", earned)


## Everything the player touched this run enters the pool of things that *can*
## appear in future runs. Nothing carries over as power (GDD §10).
func _pay_out_unlocks(victory: bool) -> Array[String]:
	var earned: Array[String] = []

	for key: Variant in RunState.towers:
		var id: String = String(RunState.towers[key].get("tower_id", ""))
		if id.is_empty() or MetaState.unlocked_towers.has(id):
			continue
		MetaState.unlocked_towers.append(id)
		earned.append("tower:" + id)
		EventBus.unlock_earned.emit("tower", id)

	for relic_id: String in RunState.held_relics + RunState.socketed_relics:
		if MetaState.unlocked_relics.has(relic_id):
			continue
		MetaState.unlocked_relics.append(relic_id)
		earned.append("relic:" + relic_id)
		EventBus.unlock_earned.emit("relic", relic_id)

	# Reaching an act at all unlocks its terrain for future runs.
	for a: int in range(1, RunState.act + 1):
		var t: TerrainData = ContentDB.terrain_for_act(a)
		if t == null or MetaState.unlocked_terrains.has(t.id):
			continue
		MetaState.unlocked_terrains.append(t.id)
		earned.append("terrain:" + t.id)
		EventBus.unlock_earned.emit("terrain", t.id)

	if victory:
		for value: Variant in ContentDB.spells.values():
			var s := value as SpellData
			if s == null or MetaState.unlocked_spells.has(s.id):
				continue
			MetaState.unlocked_spells.append(s.id)
			earned.append("spell:" + s.id)

	# Milestone buildings enter the construction pool; they do not begin built.
	var milestones: Dictionary = {
		"treasury": RunState.act >= 2,
		"market": RunState.act >= 3,
		"watchtower": victory,
		"scavenging_post": RunState.chieftains_taken > 0,
	}
	for id: Variant in milestones:
		if bool(milestones[id]) and MetaState.unlock_building(String(id)):
			earned.append("building:" + String(id))

	return earned


func quit_game() -> void:
	MetaState.save_game()
	get_tree().quit()


func _bank_treasury_cache() -> void:
	var tier: int = RunState.building_tier("treasury")
	if tier <= 0:
		MetaState.resource_cache.clear()
		return
	var cap: int = Balance.TREASURY_CACHE_PER_TIER[clampi(
		tier - 1, 0, Balance.TREASURY_CACHE_PER_TIER.size() - 1)]
	MetaState.resource_cache.clear()
	for id: String in RunState.CURRENCIES:
		MetaState.resource_cache[id] = mini(RunState.currency(id), cap)


func _change(path: String) -> void:
	# Deferred: this is routinely called from a signal handler inside the scene
	# being torn down, and changing scenes from inside one is a crash.
	get_tree().call_deferred("change_scene_to_file", path)
