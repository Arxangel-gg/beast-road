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
var _act_wave: int = 0
var _preview_lanes: Array[int] = []


func _ready() -> void:
	_rng.randomize()
	_wave_timer = Balance.WAVE_INTERVAL * 0.35
	EventBus.act_started.connect(_on_act_started)


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

	# The cadence belongs to waves, not to the tail of the previous queue. Late
	# packs deliberately overlap; otherwise a 150-body Act 3 assault quietly
	# turns a 20-second interval into nearly a minute of single-file spawning.
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_begin_wave()


## Seconds until the next wave, for the HUD.
func time_to_next_wave() -> float:
	return maxf(_wave_timer, 0.0)


## Player-facing composition preview. The Watchtower pays off in information:
## low tiers reveal lanes, higher tiers reveal pack size and elite presence.
func preview_text() -> String:
	var tower_tier: int = RunState.building_tier("watchtower")
	if tower_tier <= 0:
		return ""
	if _preview_lanes.is_empty():
		_preview_lanes = _pick_lanes(_act_wave + 1)
	var lanes: Array[int] = _preview_lanes
	var lane_names: Array[String] = ["N", "E", "S", "W"]
	var shown: PackedStringArray = []
	for lane: int in lanes:
		shown.append(lane_names[clampi(lane, 0, lane_names.size() - 1)])
	var text: String = "Next: " + ", ".join(shown)
	if tower_tier >= 2:
		text += "  ·  about %d each" % _wave_size(_act_wave + 1,
			ContentDB.terrain(RunState.terrain_id))
	if tower_tier >= 3 and _act_wave + 1 >= 3:
		text += "  ·  elite leaders likely"
	return text


func _begin_wave() -> void:
	RunState.wave_number += 1
	var wave: int = RunState.wave_number
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	_act_wave += 1

	var interval: float = Balance.WAVE_INTERVAL
	if terrain != null:
		interval *= terrain.wave_interval_multiplier
	if RunState.horn_active:
		interval /= Balance.HORN_SPAWN_RATE_SCALE
	_wave_timer = interval

	var lanes: Array[int] = _preview_lanes if not _preview_lanes.is_empty() else _pick_lanes(_act_wave)
	_preview_lanes = []
	var per_lane: int = _wave_size(_act_wave, terrain)

	for lane: int in lanes:
		for i: int in per_lane:
			_spawn_queue.append({"lane": lane, "elite": false})

	var elite_budget: float = 0.0
	if _act_wave >= 3:
		elite_budget = Balance.WAVE_ELITE_BASE_CHANCE \
			+ RunState.act_progress() * Balance.WAVE_ELITE_PROGRESS_BONUS \
			+ float(RunState.act - 1) * Balance.WAVE_ELITE_ACT_BONUS
	var elite_count: int = int(floor(elite_budget))
	if _rng.randf() < elite_budget - float(elite_count):
		elite_count += 1
	for i: int in elite_count:
		var elite_lane: int = lanes[_rng.randi_range(0, lanes.size() - 1)]
		_spawn_queue.append({"lane": elite_lane, "elite": true})

	_spawn_queue.shuffle()
	if _spawn_queue.size() > Balance.WAVE_MAX_QUEUED:
		_spawn_queue.resize(Balance.WAVE_MAX_QUEUED)
	_spawn_timer = 0.0
	EventBus.wave_started.emit(wave, lanes)


## Waves start on one lane and open up to all four as the act progresses, so the
## triage decision arrives gradually instead of on wave one.
## Weighted lane choice. A dark lane is likelier to be attacked, which is what
## turns "keep the torches lit" into a decision rather than a chore.
func _weighted_lane(exclude: Array) -> int:
	var best: int = 0
	var best_score: float = -1.0
	for lane: int in Balance.LANE_COUNT:
		if exclude.has(lane):
			continue
		var darkness: float = battlefield.lane_darkness(lane) if battlefield != null else 0.0
		var score: float = randf() * (1.0 + darkness * Balance.TORCH_DARK_LANE_BIAS)
		if score > best_score:
			best_score = score
			best = lane
	return best


func _pick_lanes(act_wave: int) -> Array[int]:
	var count: int = clampi(
		Balance.WAVE_LANES_START + RunState.act - 1 \
			+ int(floor(float(act_wave - 1) / 2.0)),
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


func _wave_size(act_wave: int, terrain: TerrainData) -> int:
	var size: float = Balance.WAVE_BASE_COUNT + Balance.WAVE_COUNT_GROWTH * float(act_wave - 1)
	size *= Balance.WAVE_ACT_COUNT_SCALE[clampi(RunState.act - 1, 0,
		Balance.WAVE_ACT_COUNT_SCALE.size() - 1)]
	if terrain != null:
		size *= terrain.wave_size_multiplier
	# Count pressure follows the darkness too; previously night changed stats and
	# lane selection while the promised extra bodies never existed.
	size *= 1.0 + DayNight.darkness * Balance.WAVE_NIGHT_COUNT_BONUS
	if RunState.distance_to_boss() <= Balance.ACT_BOSS_RAMP_DISTANCE:
		var ramp: float = 1.0 - RunState.distance_to_boss() / Balance.ACT_BOSS_RAMP_DISTANCE
		size *= 1.0 + ramp * Balance.ACT_BOSS_RAMP_COUNT
	return maxi(int(round(size)), 1)


func _spawn_next() -> void:
	if _spawn_queue.is_empty():
		return
	if battlefield.enemy_count() >= Balance.BATTLEFIELD_MAX_ENEMIES:
		_spawn_timer = Balance.WAVE_SPAWN_SPACING
		return

	var entry: Dictionary = _spawn_queue.pop_front()
	var lane: int = int(entry.get("lane", 0))
	var data: EnemyData = _pick_enemy(bool(entry.get("elite", false)))
	if data != null:
		battlefield.spawn_enemy(data, lane, _hp_scale(lane), _damage_scale(lane), _speed_scale(lane))

	var spacing: float = Balance.WAVE_SPAWN_SPACING
	if RunState.horn_active:
		spacing /= Balance.HORN_SPAWN_RATE_SCALE
	_spawn_timer = spacing


func _pick_enemy(elite: bool) -> EnemyData:
	if elite:
		var elites: Array[EnemyData] = ContentDB.enemies_of_category(EnemyData.Category.ELITE)
		if not elites.is_empty():
			return elites[_rng.randi_range(0, elites.size() - 1)]
	# A small veteran contingent from previously crossed terrain keeps later acts
	# from collapsing into a single solved target profile.
	var invader_chance: float = Balance.WAVE_INVADER_CHANCE[clampi(RunState.act - 1,
		0, Balance.WAVE_INVADER_CHANCE.size() - 1)]
	if RunState.act > 1 and _rng.randf() < invader_chance:
		var previous: TerrainData = ContentDB.terrain_for_act(_rng.randi_range(1, RunState.act - 1))
		if previous != null:
			var veteran: EnemyData = ContentDB.enemy(previous.breed_id)
			if veteran != null:
				return veteran
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null:
		var breed: EnemyData = ContentDB.enemy(terrain.breed_id)
		if breed != null:
			return breed
	var breeds: Array[EnemyData] = ContentDB.enemies_of_category(EnemyData.Category.BREED)
	return breeds[0] if not breeds.is_empty() else null


## HP grows harder than damage. A single shared multiplier made late waves
## either paper-thin or capable of deleting the town in one telegraph.
func _hp_scale(lane: int) -> float:
	var scale: float = 1.0 + Balance.WAVE_HP_GROWTH * float(RunState.wave_number - 1)
	scale *= Balance.WAVE_ACT_HP_SCALE[clampi(RunState.act - 1, 0,
		Balance.WAVE_ACT_HP_SCALE.size() - 1)]
	scale *= _situational_scale(lane, 1.0)
	return scale


func _damage_scale(lane: int) -> float:
	var scale: float = 1.0 + Balance.WAVE_DAMAGE_GROWTH * float(RunState.wave_number - 1)
	scale *= Balance.WAVE_ACT_DAMAGE_SCALE[clampi(RunState.act - 1, 0,
		Balance.WAVE_ACT_DAMAGE_SCALE.size() - 1)]
	scale *= _situational_scale(lane, Balance.WAVE_DARK_DAMAGE_WEIGHT)
	return scale


func _speed_scale(lane: int) -> float:
	var scale: float = 1.0 + RunState.journey_ratio() * Balance.WAVE_SPEED_GROWTH
	if battlefield != null:
		scale *= 1.0 + battlefield.lane_darkness(lane) * Balance.TORCH_DARK_DIFFICULTY \
			* Balance.WAVE_DARK_SPEED_WEIGHT
	return scale


func _situational_scale(lane: int, dark_weight: float) -> float:
	var scale: float = RunState.enemy_escalation_multiplier() * DayNight.difficulty_multiplier()
	if battlefield != null:
		scale *= 1.0 + battlefield.lane_darkness(lane) \
			* Balance.TORCH_DARK_DIFFICULTY * dark_weight
	if RunState.distance_to_boss() <= Balance.ACT_BOSS_RAMP_DISTANCE:
		var ramp: float = 1.0 - RunState.distance_to_boss() / Balance.ACT_BOSS_RAMP_DISTANCE
		scale *= 1.0 + ramp * Balance.ACT_BOSS_RAMP_STATS
	return scale


func _on_act_started(_act: int, _terrain_id: String) -> void:
	_act_wave = 0
	_preview_lanes.clear()
	# Give the new terrain a breath, but never a full idle interval.
	_wave_timer = minf(_wave_timer, Balance.WAVE_INTERVAL * 0.55)
