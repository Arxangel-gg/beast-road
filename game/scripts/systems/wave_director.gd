class_name WaveDirector
extends Node

## Decides what arrives, where, and when (GDD §3).
##
## Waves scale with the wave number rather than with elapsed time, so pausing
## for a crossroad or a raid does not silently make the next wave harder.

@export var battlefield: Battlefield

var _wave_timer: float = 0.0
var _spawn_queue: Array[Dictionary] = []
var _spawn_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _running: bool = false


func _ready() -> void:
	_rng.randomize()
	_wave_timer = Balance.WAVE_INTERVAL * 0.35


func start() -> void:
	_running = true


func stop() -> void:
	_running = false


func _process(delta: float) -> void:
	if not _running:
		return

	if not _spawn_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_next()
		return

	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_begin_wave()


## Seconds until the next wave, for the HUD.
func time_to_next_wave() -> float:
	return maxf(_wave_timer, 0.0)


func _begin_wave() -> void:
	RunState.wave_number += 1
	var wave: int = RunState.wave_number
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)

	var interval: float = Balance.WAVE_INTERVAL
	if terrain != null:
		interval *= terrain.wave_interval_multiplier
	if RunState.horn_active:
		interval /= Balance.HORN_SPAWN_RATE_SCALE
	_wave_timer = interval

	var lanes: Array[int] = _pick_lanes(wave)
	var per_lane: int = _wave_size(wave, terrain)

	for lane: int in lanes:
		for i: int in per_lane:
			_spawn_queue.append({"lane": lane, "elite": false})

	if wave >= 3 and _rng.randf() < Balance.WAVE_ELITE_CHANCE:
		var elite_lane: int = lanes[_rng.randi_range(0, lanes.size() - 1)]
		_spawn_queue.append({"lane": elite_lane, "elite": true})

	_spawn_queue.shuffle()
	_spawn_timer = 0.0
	EventBus.wave_started.emit(wave, lanes)


## Waves start on one lane and open up to all four as the act progresses, so the
## triage decision arrives gradually instead of on wave one.
func _pick_lanes(wave: int) -> Array[int]:
	var count: int = clampi(
		Balance.WAVE_LANES_START + int(floor(float(wave - 1) / 2.0)),
		1, Balance.WAVE_LANES_MAX)
	# After dark they come down more lanes at once, which is what actually
	# creates the triage pressure rather than just tougher individuals.
	if DayNight.is_night():
		count = clampi(count + 1, 1, Balance.WAVE_LANES_MAX)
	var all: Array[int] = []
	for i: int in Balance.LANE_COUNT:
		all.append(i)
	all.shuffle()
	return all.slice(0, count)


func _wave_size(wave: int, terrain: TerrainData) -> int:
	var size: float = Balance.WAVE_BASE_COUNT + Balance.WAVE_COUNT_GROWTH * float(wave - 1)
	if terrain != null:
		size *= terrain.wave_size_multiplier
	return maxi(int(round(size)), 1)


func _spawn_next() -> void:
	if _spawn_queue.is_empty():
		return
	if battlefield.enemy_count() >= Balance.BATTLEFIELD_MAX_ENEMIES:
		_spawn_timer = Balance.WAVE_SPAWN_SPACING
		return

	var entry: Dictionary = _spawn_queue.pop_front()
	var data: EnemyData = _pick_enemy(bool(entry.get("elite", false)))
	if data != null:
		battlefield.spawn_enemy(data, int(entry.get("lane", 0)), _stat_scale())

	var spacing: float = Balance.WAVE_SPAWN_SPACING
	if RunState.horn_active:
		spacing /= Balance.HORN_SPAWN_RATE_SCALE
	_spawn_timer = spacing


func _pick_enemy(elite: bool) -> EnemyData:
	if elite:
		var elites: Array[EnemyData] = ContentDB.enemies_of_category(EnemyData.Category.ELITE)
		if not elites.is_empty():
			return elites[_rng.randi_range(0, elites.size() - 1)]
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null:
		var breed: EnemyData = ContentDB.enemy(terrain.breed_id)
		if breed != null:
			return breed
	var breeds: Array[EnemyData] = ContentDB.enemies_of_category(EnemyData.Category.BREED)
	return breeds[0] if not breeds.is_empty() else null


## Per-wave stat growth, war horn escalation, and the weakened window all fold
## into one multiplier applied at spawn.
func _stat_scale() -> float:
	var scale: float = 1.0 + Balance.WAVE_STAT_GROWTH * float(RunState.wave_number - 1)
	scale *= RunState.enemy_escalation_multiplier()
	# Night is a difficulty state, not just a colour grade: the same wave that is
	# survivable at noon should not be at midnight.
	scale *= DayNight.difficulty_multiplier()
	return scale
