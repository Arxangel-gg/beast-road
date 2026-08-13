class_name WaveDirector
extends Node

## Decides what arrives, where, and when (GDD §3).
##
## Continuous stat/count curves determine how hard a wave is. WaveArchetypeData
## determines why it is hard: a rush, a siege column, an infiltration pincer,
## an escorted Howler pack, or pressure on every road. The vocabulary is content
## in /data/waves rather than a switch statement in this director.

@export var battlefield: Battlefield

var _wave_timer: float = 0.0
var _spawn_queue: Array[Dictionary] = []
var _spawn_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _running: bool = false
var _act_wave: int = 0
var _preview_lanes: Array[int] = []
var _preview_archetype: WaveArchetypeData = null
var _last_archetype_id: String = ""


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

	# Cadence belongs to waves, not to the tail of the previous queue. Late packs
	# deliberately overlap so Act 3 never decays into a single-file trickle.
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_begin_wave()


## Seconds until the next wave, for the HUD.
func time_to_next_wave() -> float:
	return maxf(_wave_timer, 0.0)


## The Watchtower pays off in progressively richer information: tier one names
## the formation and roads, tier two reveals scale and intent, and tier three
## identifies the signature threat.
func preview_text() -> String:
	var tower_tier: int = RunState.building_tier("watchtower")
	if tower_tier <= 0:
		return ""
	_prepare_preview(_act_wave + 1)

	var lane_names: Array[String] = ["N", "E", "S", "W"]
	var shown: PackedStringArray = []
	for lane: int in _preview_lanes:
		shown.append(lane_names[clampi(lane, 0, lane_names.size() - 1)])
	var archetype_name: String = _preview_archetype.display_name \
		if _preview_archetype != null else "Advance"
	var text: String = "Next: %s  ·  %s" % [archetype_name.to_upper(), ", ".join(shown)]

	if tower_tier >= 2:
		text += "  ·  about %d each" % _archetype_wave_size(
			_act_wave + 1, ContentDB.terrain(RunState.terrain_id),
			_preview_archetype, _preview_lanes.size())
		if _preview_archetype != null:
			text += "  ·  " + _preview_archetype.description
	if tower_tier >= 3 and _preview_archetype != null:
		var signature: EnemyData = ContentDB.enemy(_preview_archetype.signature_enemy_id)
		if signature != null:
			text += "  ·  %s leaders" % signature.display_name
		elif _act_wave + 1 >= 3:
			text += "  ·  elite presence likely"
	return text


func _begin_wave() -> void:
	RunState.wave_number += 1
	var wave: int = RunState.wave_number
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	_act_wave += 1
	_prepare_preview(_act_wave)

	var interval: float = Balance.WAVE_INTERVAL
	if terrain != null:
		interval *= terrain.wave_interval_multiplier
	if RunState.horn_active:
		interval /= Balance.HORN_SPAWN_RATE_SCALE
	_wave_timer = interval

	var archetype: WaveArchetypeData = _preview_archetype
	var lanes: Array[int] = _preview_lanes.duplicate()
	_preview_lanes.clear()
	_preview_archetype = null

	var per_lane: int = _archetype_wave_size(_act_wave, terrain, archetype, lanes.size())
	var hp_multiplier: float = archetype.hp_scale if archetype != null else 1.0
	var damage_multiplier: float = archetype.damage_scale if archetype != null else 1.0
	var speed_multiplier: float = archetype.speed_scale if archetype != null else 1.0
	var spacing_multiplier: float = maxf(
		archetype.spawn_spacing_scale if archetype != null else 1.0,
		Balance.WAVE_ARCHETYPE_MIN_SPACING_SCALE)

	for lane: int in lanes:
		for _i: int in per_lane:
			_spawn_queue.append(_spawn_entry(lane, false, "", hp_multiplier,
				damage_multiplier, speed_multiplier, spacing_multiplier))
		if archetype != null:
			for _i: int in archetype.signature_count_per_lane:
				_spawn_queue.append(_spawn_entry(lane, false,
					archetype.signature_enemy_id, hp_multiplier, damage_multiplier,
					speed_multiplier, spacing_multiplier))

	var elite_budget: float = 0.0
	if _act_wave >= 3:
		elite_budget = Balance.WAVE_ELITE_BASE_CHANCE \
			+ RunState.act_progress() * Balance.WAVE_ELITE_PROGRESS_BONUS \
			+ float(RunState.act - 1) * Balance.WAVE_ELITE_ACT_BONUS
	var elite_count: int = int(floor(elite_budget))
	if _rng.randf() < elite_budget - float(elite_count):
		elite_count += 1
	if archetype != null:
		elite_count += archetype.extra_elites
	for _i: int in elite_count:
		var elite_lane: int = lanes[_rng.randi_range(0, lanes.size() - 1)]
		_spawn_queue.append(_spawn_entry(elite_lane, true, "", hp_multiplier,
			damage_multiplier, speed_multiplier, spacing_multiplier))

	_spawn_queue.shuffle()
	if _spawn_queue.size() > Balance.WAVE_MAX_QUEUED:
		_spawn_queue.resize(Balance.WAVE_MAX_QUEUED)
	_spawn_timer = 0.0
	EventBus.wave_started.emit(wave, lanes)
	if archetype != null:
		_last_archetype_id = archetype.id
		RunState.record_wave_archetype(archetype.id)
		EventBus.wave_archetype_started.emit(wave, archetype.id)


func _spawn_entry(lane: int, elite: bool, enemy_id: String, hp_scale: float,
		damage_scale: float, speed_scale: float, spacing_scale: float) -> Dictionary:
	return {
		"lane": lane,
		"elite": elite,
		"enemy_id": enemy_id,
		"hp_scale": hp_scale,
		"damage_scale": damage_scale,
		"speed_scale": speed_scale,
		"spacing_scale": spacing_scale,
	}


func _prepare_preview(act_wave: int) -> void:
	if _preview_archetype == null:
		_preview_archetype = _pick_archetype(act_wave)
	if _preview_lanes.is_empty():
		_preview_lanes = _pick_archetype_lanes(_preview_archetype, act_wave)


func _pick_archetype(act_wave: int) -> WaveArchetypeData:
	var available: Array[WaveArchetypeData] = ContentDB.available_wave_archetypes(
		RunState.act, act_wave)
	if available.is_empty():
		return null
	var total: float = 0.0
	var weights: Array[float] = []
	for archetype: WaveArchetypeData in available:
		var weight: float = maxf(archetype.selection_weight, 0.0)
		if DayNight.is_night():
			weight *= archetype.night_weight_multiplier
		# Variety is systemic rather than purely lucky: immediate repeats become
		# possible but deliberately uncommon when another formation is legal.
		if archetype.id == _last_archetype_id and available.size() > 1:
			weight *= 0.18
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return available[0]
	var roll: float = _rng.randf() * total
	for i: int in available.size():
		roll -= weights[i]
		if roll <= 0.0:
			return available[i]
	return available.back()


func _pick_archetype_lanes(archetype: WaveArchetypeData, act_wave: int) -> Array[int]:
	if archetype == null:
		return _pick_lanes(act_wave)
	match archetype.lane_pattern:
		WaveArchetypeData.LanePattern.FOCUSED:
			return [_weighted_lane([])]
		WaveArchetypeData.LanePattern.OPPOSITES:
			var first: int = _weighted_lane([])
			return [first, (first + 2) % Balance.LANE_COUNT]
		WaveArchetypeData.LanePattern.ALL:
			var all: Array[int] = []
			for lane: int in Balance.LANE_COUNT:
				all.append(lane)
			return all
		_:
			return _pick_lanes(act_wave)


## A dark lane is likelier to be attacked, turning torch maintenance into a
## decision. The same weighted picker is used by authored formations.
func _weighted_lane(exclude: Array) -> int:
	var best: int = 0
	var best_score: float = -1.0
	for lane: int in Balance.LANE_COUNT:
		if exclude.has(lane):
			continue
		var darkness: float = battlefield.lane_darkness(lane) if battlefield != null else 0.0
		var score: float = _rng.randf() * (1.0 + darkness * Balance.TORCH_DARK_LANE_BIAS)
		if score > best_score:
			best_score = score
			best = lane
	return best


func _pick_lanes(act_wave: int) -> Array[int]:
	var picked: Array[int] = []
	for _i: int in _progressive_lane_count(act_wave):
		picked.append(_weighted_lane(picked))
	return picked


## Waves start on one lane and open to all four as the act progresses. Night
## adds another road, even when the formation itself is the neutral advance.
func _progressive_lane_count(act_wave: int) -> int:
	var count: int = clampi(
		Balance.WAVE_LANES_START + RunState.act - 1 \
			+ int(floor(float(act_wave - 1) / 2.0)),
		1, Balance.WAVE_LANES_MAX)
	if DayNight.is_night():
		count = clampi(count + 1, 1, Balance.WAVE_LANES_MAX)
	return count


func _wave_size(act_wave: int, terrain: TerrainData) -> int:
	var size: float = Balance.WAVE_BASE_COUNT + Balance.WAVE_COUNT_GROWTH * float(act_wave - 1)
	size *= Balance.WAVE_ACT_COUNT_SCALE[clampi(RunState.act - 1, 0,
		Balance.WAVE_ACT_COUNT_SCALE.size() - 1)]
	if terrain != null:
		size *= terrain.wave_size_multiplier
	size *= 1.0 + DayNight.darkness * Balance.WAVE_NIGHT_COUNT_BONUS
	if RunState.distance_to_boss() <= Balance.ACT_BOSS_RAMP_DISTANCE:
		var ramp: float = 1.0 - RunState.distance_to_boss() / Balance.ACT_BOSS_RAMP_DISTANCE
		size *= 1.0 + ramp * Balance.ACT_BOSS_RAMP_COUNT
	return maxi(int(round(size)), 1)


## Keeps each formation near the continuous curve's total body budget. Focused
## assaults become dense columns; all-lane assaults spread that threat instead
## of accidentally multiplying the difficulty by four.
func _archetype_wave_size(act_wave: int, terrain: TerrainData,
		archetype: WaveArchetypeData, lane_count: int) -> int:
	var scale: float = archetype.count_scale if archetype != null else 1.0
	scale = maxf(scale, Balance.WAVE_ARCHETYPE_MIN_COUNT_SCALE)
	scale *= float(_progressive_lane_count(act_wave)) / float(maxi(lane_count, 1))
	return maxi(int(round(float(_wave_size(act_wave, terrain)) * scale)), 1)


func _spawn_next() -> void:
	if _spawn_queue.is_empty():
		return
	if battlefield.enemy_count() >= Balance.BATTLEFIELD_MAX_ENEMIES:
		_spawn_timer = Balance.WAVE_SPAWN_SPACING
		return

	var entry: Dictionary = _spawn_queue.pop_front()
	var lane: int = int(entry.get("lane", 0))
	var enemy_id: String = String(entry.get("enemy_id", ""))
	var data: EnemyData = ContentDB.enemy(enemy_id) if not enemy_id.is_empty() \
		else _pick_enemy(bool(entry.get("elite", false)))
	if data != null:
		battlefield.spawn_enemy(data, lane,
			_hp_scale(lane) * float(entry.get("hp_scale", 1.0)),
			_damage_scale(lane) * float(entry.get("damage_scale", 1.0)),
			_speed_scale(lane) * float(entry.get("speed_scale", 1.0)))

	var spacing: float = Balance.WAVE_SPAWN_SPACING * float(entry.get("spacing_scale", 1.0))
	if RunState.horn_active:
		spacing /= Balance.HORN_SPAWN_RATE_SCALE
	_spawn_timer = spacing


func _pick_enemy(elite: bool) -> EnemyData:
	if elite:
		var elites: Array[EnemyData] = ContentDB.enemies_of_category(EnemyData.Category.ELITE)
		if not elites.is_empty():
			return elites[_rng.randi_range(0, elites.size() - 1)]
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
	_preview_archetype = null
	_last_archetype_id = ""
	# Give the new terrain a breath, but never a full idle interval.
	_wave_timer = minf(_wave_timer, Balance.WAVE_INTERVAL * 0.55)
