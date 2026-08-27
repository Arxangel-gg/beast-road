class_name BossDirector
extends Node

## The act bosses (GDD §9).
##
## An act does not end at a crossroad — it ends because something enormous walks
## up one of the lanes. The boss spawns, the ordinary waves keep coming, and the
## act is over when it dies. Killing the Act 3 boss ends the run in victory,
## which is the only win condition the game has.

@export var battlefield: Battlefield

var _active: Enemy = null
var _active_act: int = 0
var _defeated_acts: Array[int] = []
var _active_phase: int = 0
var _rng: RandomNumberGenerator


func _ready() -> void:
	_rng = RunState.rng("bosses")
	EventBus.enemy_died.connect(_on_enemy_died)


func boss_is_out() -> bool:
	return _active != null and is_instance_valid(_active) and not _active.is_dying()


func active_boss() -> Enemy:
	return _active if boss_is_out() else null


## True once this act's boss is dead, which is what lets the journey continue.
func act_is_cleared(act: int) -> bool:
	return _defeated_acts.has(act)


## Spawns the boss for `act`. Refused if one is already out or that act is done.
func summon(act: int) -> bool:
	if boss_is_out() or act_is_cleared(act):
		return false
	var data: EnemyData = _boss_for_act(act)
	if data == null:
		push_warning("BossDirector: no boss defined for act %d" % act)
		return false

	var lane: int = _rng.randi_range(0, Balance.LANE_COUNT - 1)
	# Bosses ignore the live-enemy cap: the cap exists to stop a death spiral of
	# trash, and the boss *is* the encounter.
	_active = battlefield.spawn_enemy(data, lane, _boss_scale(act))
	if _active == null:
		return false
	_active_act = act
	_active_phase = 0
	var health: Health = Health.of(_active)
	if health != null:
		health.changed.connect(_on_boss_health_changed)

	EventBus.boss_spawned.emit(data.id, act)
	EventBus.camera_shake_requested.emit(18.0, 0.9)
	return true


## Bosses scale with accumulated horn use like everything else, so a run that
## leaned on the horn meets a harder boss.
func _boss_scale(act: int) -> float:
	return RunState.enemy_escalation_multiplier() * Balance.BOSS_ACT_SCALE[
		clampi(act - 1, 0, Balance.BOSS_ACT_SCALE.size() - 1)]


func _boss_for_act(act: int) -> EnemyData:
	for boss: EnemyData in ContentDB.enemies_of_category(EnemyData.Category.BOSS):
		var terrain: TerrainData = ContentDB.terrain_for_act(act)
		if terrain != null and boss.id.begins_with(_expected_boss_id(act)):
			return boss
	# Fall back by id rather than by index: indexing a directory listing hands
	# the Final Ascent whichever boss happens to sort fourth.
	var wanted: String = _expected_boss_id(act)
	for boss: EnemyData in ContentDB.enemies_of_category(EnemyData.Category.BOSS):
		if boss.id == wanted:
			return boss
	return null


## Act to boss id. The mapping is in the GDD's act table; keeping it here rather
## than on TerrainData avoids a field that only ever has three values.
func _expected_boss_id(act: int) -> String:
	match act:
		1:
			return "drowned_choir"
		2:
			return "mirrorfang"
		3:
			return "rust_crown"
		_:
			# The Final Ascent reports one act past ACT_COUNT, and the summit is
			# the only thing out there.
			return "chainmaker"


func _on_boss_health_changed(current: float, maximum: float) -> void:
	if current <= 0.0 or not boss_is_out() or _active.data == null or maximum <= 0.0:
		return
	var thresholds: Array[float] = _active.data.phase_thresholds
	while _active_phase < thresholds.size() \
			and current / maximum <= thresholds[_active_phase]:
		_active_phase += 1
		_enter_phase(_active_phase)


func _enter_phase(phase: int) -> void:
	if not boss_is_out() or _active.data == null:
		return
	_active.apply_boss_phase(phase)
	var phase_name: String = _active.data.phase_names[phase - 1] \
		if phase - 1 < _active.data.phase_names.size() else "Phase %d" % (phase + 1)
	_spawn_phase_reinforcements(phase)
	EventBus.boss_phase_changed.emit(_active.data.id, phase, phase_name)
	EventBus.camera_shake_requested.emit(15.0 + float(phase) * 3.0, 0.8)


## Reinforcements arrive on lanes other than the boss's own. The player's
## choice becomes burn the boss or leave it and triage the roads—a boss phase,
## not merely a stat change.
func _spawn_phase_reinforcements(phase: int) -> void:
	var data: EnemyData = ContentDB.enemy(_active.data.phase_reinforcement_enemy_id)
	if data == null:
		var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
		data = ContentDB.enemy(terrain.breed_id) if terrain != null else null
	if data == null:
		return

	var lanes: Array[int] = []
	for lane: int in Balance.LANE_COUNT:
		if lane != _active.lane:
			lanes.append(lane)
	for index: int in range(lanes.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var swap: int = lanes[index]
		lanes[index] = lanes[other]
		lanes[other] = swap
	var lane_count: int = mini(_active.data.phase_reinforcement_lanes + phase - 1,
		lanes.size())
	var per_lane: int = mini(_active.data.phase_reinforcements_per_lane + phase - 1,
		Balance.BOSS_PHASE_MAX_REINFORCEMENTS)
	for index: int in lane_count:
		var lane: int = lanes[index]
		for _i: int in per_lane:
			var summoned: Enemy = battlefield.spawn_enemy(data, lane,
				battlefield.wave_director._hp_scale(lane) \
					* Balance.BOSS_PHASE_REINFORCEMENT_HP_SCALE,
				battlefield.wave_director._damage_scale(lane) \
					* Balance.BOSS_PHASE_REINFORCEMENT_DAMAGE_SCALE,
				battlefield.wave_director._speed_scale(lane))
			# Marked at the point of summoning, which is the only place that
			# knows these are the boss's rather than the road's. An identical
			# breed walking up from a formation is a real enemy and keeps its
			# payout; this one only exists while its summoner does.
			if summoned != null:
				summoned.add_to_group(Enemy.SUMMON_GROUP)


func _on_enemy_died(enemy_id: String, _at: Vector2) -> void:
	if _active == null or not is_instance_valid(_active):
		return
	if _active.data == null or _active.data.id != enemy_id:
		return

	var act: int = _active_act
	_active = null
	_active_act = 0
	_active_phase = 0
	_defeated_acts.append(act)

	# Before the rewards and before the signal. Everything downstream of
	# `boss_defeated` - closing the wave, ending the act, opening the next
	# Preparation - is entitled to assume the boss encounter is actually over,
	# and it is not over while the boss's pack is still walking.
	_dismiss_summons()

	_grant_rewards(act)
	EventBus.camera_shake_requested.emit(22.0, 1.2)
	EventBus.boss_defeated.emit(enemy_id, act)


## Clears the pack the boss called, now that the boss is gone.
##
## They leave without paying out anything - see `Enemy.dismiss` for why that is
## the point rather than an oversight. Iterating the group rather than a tracked
## list means summons that already died, or were never spawned because the act
## ended in phase one, cost nothing to handle.
func _dismiss_summons() -> void:
	if battlefield == null or not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(Enemy.SUMMON_GROUP):
		var summoned := node as Enemy
		if summoned != null and is_instance_valid(summoned):
			summoned.dismiss()


## The boss reward package, all three parts, every act (GDD §9).
func _grant_rewards(act: int) -> void:
	# 1. Hero ascension — a stat tier. Power and Ultimate discipline slots read
	# the act gate directly; the Mansion chooses what occupies them.
	RunState.hero_ascension += 1
	RunState._sync_discipline_spells()

	# 2. Boss core — permanent, always active, never socketed.
	var core_id: String = "core_" + _expected_boss_id(act)
	if ContentDB.relics.has(core_id) and not RunState.boss_cores.has(core_id):
		RunState.boss_cores.append(core_id)

	# 3. The next act's terrain, which the journey switches to at the boundary.
	RunState.gain_resources(Balance.BOSS_RESOURCE_REWARD)
	RunState.gain_currency(RunState.STONE, Balance.BOSS_STONE_REWARD)


func _unequipped_spell() -> String:
	for id: Variant in ContentDB.spells:
		var spell_id: String = String(id)
		if not RunState.equipped_spells.has(spell_id):
			return spell_id
	return ""
