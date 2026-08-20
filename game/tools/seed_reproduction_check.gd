extends Node

## Release gate for GDD §44/§52 deterministic reproduction.
##
## Replays all six crossroad decisions twice with one seed, once with another,
## and also proves formation plans and Watchtower disclosure are reproducible.

const REPLAY_SEED: int = 314159265
const ALTERNATE_SEED: int = 271828182
const CROSSROAD_SEGMENTS: Array[int] = [1, 2, 4, 5, 7, 8]

var _failures: PackedStringArray = []


func _ready() -> void:
	var first: Array[String] = _route(REPLAY_SEED)
	var replay: Array[String] = _route(REPLAY_SEED)
	var alternate: Array[String] = _route(ALTERNATE_SEED)
	_check(first.size() == 6, "a run must produce all six crossroad decisions")
	_check(first == replay, "the same seed must reproduce all six road decisions exactly")
	_check(first != alternate, "different seeds must produce a distinct itinerary")

	var waves_a: Array[String] = _wave_plan(REPLAY_SEED)
	var waves_b: Array[String] = _wave_plan(REPLAY_SEED)
	_check(waves_a == waves_b and waves_a.size() == 10,
		"the same seed must reproduce ten formation and lane plans")
	_test_watchtower_layers()

	print("[seed] %09d  %s" % [REPLAY_SEED, " > ".join(first)])
	print("[seed] %09d  %s" % [ALTERNATE_SEED, " > ".join(alternate)])
	for problem: String in _failures:
		push_error("[seed] " + problem)
	print("[seed] %s — six-crossroad and wave reproduction" % (
		"PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _route(run_seed: int) -> Array[String]:
	RunState.reset(false, run_seed)
	var screen := CrossroadScreen.new()
	screen._rng = RunState.rng("roads")
	var itinerary: Array[String] = []
	for index: int in CROSSROAD_SEGMENTS.size():
		var segment: int = CROSSROAD_SEGMENTS[index]
		var offers: Array[Dictionary] = screen.draw_offers(segment)
		_check(offers.size() == Balance.CROSSROAD_OPTIONS_SHOWN,
			"segment %d must offer two roads" % segment)
		if offers.is_empty():
			continue
		# Alternate left/right so the test exercises selection, not only drawing.
		var chosen: Dictionary = offers[index % offers.size()]
		var road: RoadData = chosen["road"] as RoadData
		var difficulty: RoadDifficultyData = chosen["difficulty"] as RoadDifficultyData
		RunState.record_road_choice(segment, road.id, difficulty.id)
		itinerary.append("%d:%s/%s" % [segment, road.id, difficulty.id])
	_check(RunState.road_history.size() == 6,
		"the debrief must retain six selected road records")
	screen.free()
	return itinerary


func _wave_plan(run_seed: int) -> Array[String]:
	RunState.reset(false, run_seed)
	RunState.terrain_id = "jungle"
	RunState.act = 1
	DayNight._apply(0.18)
	var director := WaveDirector.new()
	director._rng = RunState.rng("waves")
	var plan: Array[String] = []
	for act_wave: int in range(1, 11):
		director._prepare_preview(act_wave)
		var archetype: String = director._preview_archetype.id \
			if director._preview_archetype != null else "advance"
		plan.append("%s:%s" % [archetype, str(director._preview_lanes)])
		director._last_archetype_id = archetype
		director._preview_archetype = null
		director._preview_lanes.clear()
	director.free()
	return plan


func _test_watchtower_layers() -> void:
	var screen := CrossroadScreen.new()
	var road: RoadData = ContentDB.road("relic_hunt")
	var difficulty: RoadDifficultyData = ContentDB.road_difficulty("perilous")
	RunState.building_tiers["watchtower"] = 0
	var hidden: String = screen._exact_consequences(road, difficulty)
	RunState.building_tiers["watchtower"] = 1
	var threat: String = screen._exact_consequences(road, difficulty)
	RunState.building_tiers["watchtower"] = 2
	var depth: String = screen._exact_consequences(road, difficulty)
	RunState.building_tiers["watchtower"] = 3
	var exact: String = screen._exact_consequences(road, difficulty)
	RunState.building_tiers["watchtower"] = 0
	RunState.socketed_relics = ["24"]
	Modifiers.rebuild()
	var relic_intel: String = screen._exact_consequences(road, difficulty)
	_check(hidden.contains("threat details unknown") and hidden.contains("reward depth unknown"),
		"an unbuilt Watchtower must preserve road uncertainty")
	_check(threat.contains("bodies") and threat.contains("durability"),
		"Watchtower tier 1 must reveal road threat values")
	_check(depth.contains("3 reward rolls"),
		"Watchtower tier 2 must reveal hidden reward depth")
	_check(exact.contains("Regional relic choice") and exact.contains("Gold"),
		"Watchtower tier 3 must reveal exact reward categories")
	_check(relic_intel.contains("bodies") and relic_intel.contains("reward depth unknown"),
		"a socketed foresight relic must supply one bounded intelligence tier")
	RunState.socketed_relics.clear()
	Modifiers.rebuild()
	screen.free()


func _check(condition: bool, problem: String) -> void:
	if not condition:
		_failures.append(problem)
