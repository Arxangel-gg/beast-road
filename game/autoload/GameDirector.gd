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


func goto_splash() -> void:
	_change(SPLASH_SCENE)


func goto_menu() -> void:
	run_active = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	_change(MENU_SCENE)


func start_run() -> void:
	RunState.reset()
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

	var summary: Dictionary = {
		"victory": victory,
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
		"unlocks": _pay_out_unlocks(victory),
	}

	MetaState.runs_started += 1
	if victory:
		MetaState.runs_won += 1
		MetaState.act3_cleared = true
	MetaState.best_distance = maxf(MetaState.best_distance, RunState.distance_travelled)
	MetaState.total_enemies_killed += RunState.enemies_killed
	MetaState.save_game()

	EventBus.run_ended.emit(victory, summary)


## Everything the player touched this run enters the pool of things that *can*
## appear in future runs. Nothing carries over as power (GDD §10).
func _pay_out_unlocks(victory: bool) -> Array[String]:
	var earned: Array[String] = []

	for entry: Dictionary in RunState.tower_slots:
		var id: String = String(entry.get("tower_id", ""))
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

	return earned


func quit_game() -> void:
	MetaState.save_game()
	get_tree().quit()


func _change(path: String) -> void:
	# Deferred: this is routinely called from a signal handler inside the scene
	# being torn down, and changing scenes from inside one is a crash.
	get_tree().call_deferred("change_scene_to_file", path)
