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
## True from the first spawn of a formation until its queue and every surviving
## enemy are gone. A wave is a complete encounter: the next Preparation may not
## begin just because a clock expired while stragglers are still fighting.
var _wave_active: bool = false

## How long this formation has been unable to clear. Reset whenever a wave
## begins or ends, so it measures one wave rather than the run.
var _stuck_for: float = 0.0

## Closest any living enemy has come to the town during this wave.
##
## The stall watchdog counts time, and time alone cannot tell a wave that is
## stuck from a wave that is merely long. Progress can: an enemy walking the far
## route is still closing on the town every second, and one wedged in geometry is
## not.
var _closest_approach: float = INF
var _act_wave: int = 0
var _preview_lanes: Array[int] = []
var _preview_archetype: WaveArchetypeData = null
var _last_archetype_id: String = ""


func _ready() -> void:
	_rng = RunState.rng("waves")
	_wave_timer = Balance.WAVE_FIRST_PREPARATION
	EventBus.act_started.connect(_on_act_started)


func start() -> void:
	_running = true


func stop() -> void:
	_running = false


## True while a wave's pack is still walking on. The run uses this to tell "the
## road is clear" apart from "the road is clear because the next wave has not
## started spawning yet", which look identical if you only count enemies.
func is_deploying() -> bool:
	return not _spawn_queue.is_empty()


## Brings the next wave forward after a between-wave breather.
##
## Without this the wave timer keeps whatever it had left when the field cleared,
## and a ten second breather that began with twelve seconds on the clock becomes
## a twenty-two second gap - which reads as the game having stalled.
func resume_after_breather() -> void:
	_wave_timer = minf(_wave_timer, Balance.WAVE_BREATHER_RESUME_SECONDS)


func _process(delta: float) -> void:
	if not _running:
		return

	if not _spawn_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_next()

	# Every member of this formation must be deployed and resolved before the road
	# is declared clear. Clock-driven overlap used to open Preparation on top of
	# living enemies, freeze them in place, and then stack another formation.
	if _wave_active:
		if _spawn_queue.is_empty() and (battlefield == null or battlefield.enemy_count() <= 0):
			_close_wave()
			return

		# A wave that cannot end is a run that cannot continue.
		#
		# Waiting for the road to clear is right, but it made "clear" a condition
		# with no way out: one enemy that cannot die, cannot reach anything, or is
		# left somewhere unreachable by a suspend and resume stops the wave, the
		# next Preparation, and the whole run - silently, with nothing spawning and
		# nothing to fight. That is what happened around wave 19.
		#
		# So the wait is bounded. The watchdog names what was holding it, because a
		# stall that resolves itself and says nothing is a bug that gets reported
		# once a week forever.
		#
		# Progress resets that clock, and has to: time alone cannot tell a wave
		# that is stuck from a wave that is merely long. The watchdog fired on an
		# enemy that had simply taken the long way round - the authored map's far
		# route is nearly twice the direct one - and Preparation opened while it
		# was still walking, which is the exact failure the wait exists to
		# prevent. An enemy closing on the town is not a stall.
		var nearest: float = INF
		if battlefield != null:
			nearest = battlefield.nearest_enemy_distance()
		if nearest < _closest_approach - Balance.WAVE_PROGRESS_EPSILON:
			_closest_approach = nearest
			_stuck_for = 0.0
		_stuck_for += delta
		if _stuck_for >= Balance.WAVE_STALL_TIMEOUT:
			push_warning("Wave %d could not clear after %.0fs; still standing: %s"
				% [RunState.wave_number, _stuck_for,
					battlefield.living_enemy_summary() if battlefield != null else "?"])
			_close_wave()
		return

	_wave_timer -= delta
	if _wave_timer <= 0.0 and _road_waves_allowed():
		_begin_wave()


## Road formations belong to the road. The boss is its own encounter and brings
## its own reinforcements through BossDirector.
##
## Without this the ordinary wave clock kept running through a boss fight and
## started a formation underneath it. That left `_wave_active` true when the boss
## died, so `_on_boss_defeated` opened Act 2's Preparation on a live pack - the
## player watched their town being eaten during the phase that exists to be safe,
## and the wave it belonged to could never close because Preparation had stopped
## the director that owns closing it.
func _road_waves_allowed() -> bool:
	return RunState.phase == RunState.Phase.ROAD_BATTLE \
		or RunState.phase == RunState.Phase.FINAL_ASCENT


## Seconds until the next wave, for the HUD.
func time_to_next_wave() -> float:
	return maxf(_wave_timer, 0.0)


## The Watchtower pays off in progressively richer information: tier one names
## the formation and roads, tier two reveals scale and intent, and tier three
## identifies the signature threat.
func preview_text() -> String:
	var tower_tier: int = RunState.foresight_tier()
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
		var signature: EnemyData = _signature_enemy(_preview_archetype)
		if signature != null:
			text += "  ·  %s leaders" % signature.display_name
		elif _act_wave + 1 >= 3:
			text += "  ·  elite presence likely"
	return text


## Ends the formation and hands back to the run.
func _close_wave() -> void:
	_wave_active = false
	_running = false
	_stuck_for = 0.0
	_closest_approach = INF
	EventBus.wave_cleared.emit(RunState.wave_number)


func _begin_wave() -> void:
	if _wave_active:
		return
	_stuck_for = 0.0
	_closest_approach = INF
	RunState.wave_number += 1
	RunState.count_endless_wave()
	var wave: int = RunState.wave_number
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	_act_wave += 1
	_prepare_preview(_act_wave)

	var interval: float = Balance.WAVE_INTERVAL
	if terrain != null:
		interval *= terrain.wave_interval_multiplier
	if RunState.horn_active:
		interval /= Balance.HORN_SPAWN_RATE_SCALE
	if RunState.act == 1 and _act_wave <= Balance.WAVE_OPENING_INTERVAL_BONUS.size():
		interval += Balance.WAVE_OPENING_INTERVAL_BONUS[_act_wave - 1]
	_wave_timer = interval

	# A small, visible logistics pulse lets a new defence react to each newly
	# opened road. It ends before the full curve arrives and cannot inflate the
	# late mastery economy.
	if RunState.act == 1 and _act_wave <= Balance.WAVE_OPENING_SUPPLIES.size():
		RunState.gain_currency(RunState.GOLD, Balance.WAVE_OPENING_SUPPLIES[_act_wave - 1])

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
	var road: RoadData = RunState.active_road()
	var difficulty: RoadDifficultyData = RunState.active_road_difficulty()
	if road != null:
		per_lane = maxi(int(round(float(per_lane) * road.count_scale)), 1)
		hp_multiplier *= road.hp_scale
		damage_multiplier *= road.damage_scale
		speed_multiplier *= road.speed_scale
		spacing_multiplier *= road.spawn_spacing_scale
	if difficulty != null:
		per_lane = maxi(int(round(float(per_lane) * difficulty.count_scale)), 1)
		hp_multiplier *= difficulty.stat_scale
		damage_multiplier *= difficulty.stat_scale
		speed_multiplier *= difficulty.speed_scale
		spacing_multiplier *= difficulty.spawn_spacing_scale
	spacing_multiplier = maxf(spacing_multiplier, Balance.WAVE_ARCHETYPE_MIN_SPACING_SCALE)
	var signature: EnemyData = _signature_enemy(archetype)

	if archetype != null and archetype.delayed_adjacent_surge and lanes.size() >= 2:
		_build_delayed_surge(archetype, lanes, per_lane, hp_multiplier,
			damage_multiplier, speed_multiplier, spacing_multiplier)
	else:
		for lane: int in lanes:
			for _i: int in per_lane:
				_spawn_queue.append(_spawn_entry(lane, false, "", hp_multiplier,
					damage_multiplier, speed_multiplier, spacing_multiplier))
			if archetype != null and signature != null:
				for _i: int in archetype.signature_count_per_lane:
					_spawn_queue.append(_spawn_entry(lane, false,
						signature.id, hp_multiplier, damage_multiplier,
						speed_multiplier, spacing_multiplier))

	var elite_budget: float = 0.0
	if _act_wave >= 3:
		elite_budget = Balance.WAVE_ELITE_BASE_CHANCE \
			+ RunState.act_progress() * Balance.WAVE_ELITE_PROGRESS_BONUS \
			+ float(RunState.act - 1) * Balance.WAVE_ELITE_ACT_BONUS
	if road != null:
		elite_budget += road.elite_budget_bonus
	if difficulty != null:
		elite_budget += difficulty.elite_budget_bonus
	var elite_count: int = int(floor(elite_budget))
	if _rng.randf() < elite_budget - float(elite_count):
		elite_count += 1
	if archetype != null:
		elite_count += archetype.extra_elites
	for _i: int in elite_count:
		var elite_lane: int = lanes[_rng.randi_range(0, lanes.size() - 1)]
		_spawn_queue.append(_spawn_entry(elite_lane, true, "", hp_multiplier,
			damage_multiplier, speed_multiplier, spacing_multiplier))

	# A False Front is authored through its ordering; shuffling would place the
	# reveal before the bait. All ordinary formations retain systemic variety.
	if archetype == null or not archetype.delayed_adjacent_surge:
		_shuffle_queue()
	if _spawn_queue.size() > Balance.WAVE_MAX_QUEUED:
		_spawn_queue.resize(Balance.WAVE_MAX_QUEUED)
	_spawn_timer = 0.0
	_wave_active = true
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


## Builds a bounded two-beat formation: a readable minority on the first road,
## a silent hold, then the remaining threat on an adjacent road. The total body
## budget remains identical to two ordinary lanes.
func _build_delayed_surge(archetype: WaveArchetypeData, lanes: Array[int],
		per_lane: int, hp_scale: float, damage_scale: float, speed_scale: float,
		spacing_scale: float) -> void:
	var total: int = per_lane * 2
	var bait_count: int = clampi(int(round(float(total) * archetype.false_front_fraction)),
		1, maxi(total - 1, 1))
	for _i: int in bait_count:
		_spawn_queue.append(_spawn_entry(lanes[0], false, "", hp_scale,
			damage_scale, speed_scale, spacing_scale))
	_spawn_queue.append({"delay": maxf(archetype.surge_delay, 0.1)})
	for _i: int in total - bait_count:
		_spawn_queue.append(_spawn_entry(lanes[1], false, "", hp_scale,
			damage_scale, speed_scale, spacing_scale))


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
	if archetype.delayed_adjacent_surge:
		var first: int = _weighted_lane([])
		var direction: int = -1 if _rng.randi() % 2 == 0 else 1
		return [first, posmod(first + direction, Balance.LANE_COUNT)]
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
	if RunState.act == 1:
		# One road at a time, and for longer than it used to be.
		#
		# The measured curve (tools/curve_report.tscn) had all four roads live by
		# wave 7 of an act that runs to about 19, so two thirds of the opening act
		# was played at maximum width. Each new road multiplies the bodies on the
		# field, so those were the four sharpest increases in the whole run: +82%,
		# +63%, +42%, +21% in five waves. That is the "scales too difficult too
		# early" report, and it is a lane-count curve rather than a stat curve.
		#
		# Spread over ten waves instead of seven, so a road is added roughly every
		# third wave and the player gets two or three goes at each width.
		if act_wave <= Balance.WAVE_OPENING_SINGLE_LANE_WAVES:
			return 1
		if act_wave <= 6:
			return 2
		if act_wave <= 9:
			return 3
	# A new region re-teaches, but only briefly. Starting a fresh act back at two
	# roads made the first wave of Act 2 measure 77% *easier* than the last wave
	# of Act 1 - arriving somewhere new and more dangerous made the game go quiet
	# for four waves. Each act now opens two roads wider than the last, so Act 2
	# starts at three and Act 3 at full width.
	var count: int = clampi(
		Balance.WAVE_LANES_START + (RunState.act - 1) * Balance.WAVE_LANES_PER_ACT \
			+ int(floor(float(act_wave - 1) / 2.0)),
		1, Balance.WAVE_LANES_MAX)
	if DayNight.is_night():
		count = clampi(count + 1, 1, Balance.WAVE_LANES_MAX)
	return count


func _wave_size(act_wave: int, terrain: TerrainData) -> int:
	var size: float = Balance.WAVE_BASE_COUNT + Balance.WAVE_COUNT_GROWTH * float(act_wave - 1)
	size *= Balance.WAVE_ACT_COUNT_SCALE[clampi(RunState.act - 1, 0,
		Balance.WAVE_ACT_COUNT_SCALE.size() - 1)]
	size *= RunState.endless_scale(Balance.ENDLESS_COUNT_GROWTH)
	if terrain != null:
		size *= terrain.wave_size_multiplier
	size *= _opening_scale(Balance.WAVE_OPENING_COUNT_SCALE, act_wave)
	size *= _act_opening_scale(act_wave)
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
	if entry.has("delay"):
		_spawn_timer = float(entry["delay"])
		return
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
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if elite:
		if terrain != null:
			var regional_elites: Array[EnemyData] = _enemy_pool(terrain.elite_ids)
			if not regional_elites.is_empty():
				return regional_elites[_rng.randi_range(0, regional_elites.size() - 1)]
		var elites: Array[EnemyData] = ContentDB.enemies_of_category(EnemyData.Category.ELITE)
		if not elites.is_empty():
			return elites[_rng.randi_range(0, elites.size() - 1)]
	var invader_chance: float = Balance.WAVE_INVADER_CHANCE[clampi(RunState.act - 1,
		0, Balance.WAVE_INVADER_CHANCE.size() - 1)]
	if RunState.act > 1 and _rng.randf() < invader_chance:
		var previous: TerrainData = ContentDB.terrain_for_act(_rng.randi_range(1, RunState.act - 1))
		if previous != null:
			var veterans: Array[EnemyData] = _enemy_pool(previous.enemy_ids)
			if not veterans.is_empty():
				return veterans[_rng.randi_range(0, veterans.size() - 1)]
	if terrain != null:
		var regional: Array[EnemyData] = _enemy_pool(terrain.enemy_ids)
		if not regional.is_empty():
			return regional[_rng.randi_range(0, regional.size() - 1)]
		var breed: EnemyData = ContentDB.enemy(terrain.breed_id)
		if breed != null:
			return breed
	var breeds: Array[EnemyData] = ContentDB.enemies_of_category(EnemyData.Category.BREED)
	return breeds[0] if not breeds.is_empty() else null


func _enemy_pool(ids: Array[String]) -> Array[EnemyData]:
	var pool: Array[EnemyData] = []
	for id: String in ids:
		var data: EnemyData = ContentDB.enemy(id)
		if data != null:
			pool.append(data)
	return pool


func _shuffle_queue() -> void:
	for index: int in range(_spawn_queue.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var swap: Dictionary = _spawn_queue[index]
		_spawn_queue[index] = _spawn_queue[other]
		_spawn_queue[other] = swap


func _signature_enemy(archetype: WaveArchetypeData) -> EnemyData:
	if archetype == null:
		return null
	if archetype.signature_role >= 0:
		var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
		if terrain != null:
			# Elites first: a formation's named leader should read above its escort.
			for id: String in terrain.elite_ids + terrain.enemy_ids:
				var regional: EnemyData = ContentDB.enemy(id)
				if regional != null and int(regional.role) == archetype.signature_role:
					return regional
	return ContentDB.enemy(archetype.signature_enemy_id)


func _hp_scale(lane: int) -> float:
	var tier: CampaignTierData = RunState.tier()
	var scale: float = 1.0 + Balance.WAVE_HP_GROWTH * float(RunState.wave_number - 1)
	scale *= Balance.WAVE_ACT_HP_SCALE[clampi(RunState.act - 1, 0,
		Balance.WAVE_ACT_HP_SCALE.size() - 1)]
	scale *= RunState.endless_scale(Balance.ENDLESS_HP_GROWTH)
	scale *= _situational_scale(lane, 1.0)
	scale *= _opening_scale(Balance.WAVE_OPENING_HP_SCALE, _act_wave)
	if tier != null:
		scale *= tier.hp_scale
	return scale


func _damage_scale(lane: int) -> float:
	var tier: CampaignTierData = RunState.tier()
	var scale: float = 1.0 + Balance.WAVE_DAMAGE_GROWTH * float(RunState.wave_number - 1)
	scale *= Balance.WAVE_ACT_DAMAGE_SCALE[clampi(RunState.act - 1, 0,
		Balance.WAVE_ACT_DAMAGE_SCALE.size() - 1)]
	scale *= RunState.endless_scale(Balance.ENDLESS_DAMAGE_GROWTH)
	scale *= _situational_scale(lane, Balance.WAVE_DARK_DAMAGE_WEIGHT)
	scale *= _opening_scale(Balance.WAVE_OPENING_DAMAGE_SCALE, _act_wave)
	if tier != null:
		scale *= tier.damage_scale
	return scale


func _speed_scale(lane: int) -> float:
	var tier: CampaignTierData = RunState.tier()
	var scale: float = 1.0 + RunState.journey_ratio() * Balance.WAVE_SPEED_GROWTH
	if battlefield != null:
		scale *= 1.0 + battlefield.lane_darkness(lane) * Balance.TORCH_DARK_DIFFICULTY \
			* Balance.WAVE_DARK_SPEED_WEIGHT
	scale *= _opening_scale(Balance.WAVE_OPENING_SPEED_SCALE, _act_wave)
	if tier != null:
		scale *= tier.speed_scale
	return scale


## The breath at the top of Acts 2 and 3.
##
## Act 1 is excluded because it has its own, longer authored envelope and adding
## a second one on top would compound into an opening that barely fights back.
## Neutral everywhere else, so late balance is untouched.
func _act_opening_scale(act_wave: int) -> float:
	var curve: Array[float] = Balance.WAVE_ACT_OPENING_COUNT_SCALE
	if RunState.act <= 1 or curve.is_empty() or act_wave > curve.size():
		return 1.0
	return curve[clampi(act_wave - 1, 0, curve.size() - 1)]


## Samples one of the opening curves. Outside Act 1 and after the authored
## envelope the result is exactly neutral, which is what protects late balance.
func _opening_scale(curve: Array[float], act_wave: int) -> float:
	if RunState.act != 1 or curve.is_empty() or act_wave > curve.size():
		return 1.0
	return curve[clampi(act_wave - 1, 0, curve.size() - 1)]


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
	# Journey emits act_started for Act 1 during scene startup. Treating that as
	# a terrain transition used to clamp the authored 18-second preparation back
	# to 11 seconds before the player ever saw the field.
	if RunState.act == 1 and RunState.wave_number == 0:
		_wave_timer = Balance.WAVE_FIRST_PREPARATION
		return
	# Give the new terrain a breath, but never a full idle interval.
	_wave_timer = minf(_wave_timer, Balance.WAVE_INTERVAL * 0.55)
