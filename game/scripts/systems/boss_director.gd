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
## The Gatekeeper, when a tier's summit owes one. Held so it can be cleaned up
## with the boss rather than left standing on a road nobody is defending.
var _escort: Enemy = null
## The Gatekeeper's own breed. Named once rather than at three call sites.
const GATEKEEPER_ID: String = "gatekeeper"
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
	_summon_the_gatekeeper_if_owed(act, lane)
	return true


## **A difficulty whose Gatekeeper is unbeaten fights him here.**
##
## The owner's own addition of 2026-09-17, and the thing that makes the ladder
## a decision rather than a side quest: the Gatekeeper is paid for once on Act
## 9 at a time the player chose, or once at the summit standing next to Kharok.
## Beating him on a tier takes him off that tier's summit for good.
##
## **He arrives on a different road.** Both bodies walk at the town and neither
## is a second health bar on the first: the fight is harder because the party
## has to answer two lanes at once, which is the thing this defence is built
## to be unable to do everywhere.
##
## Scaled as an Act 9 boss rather than a summit one. He is the encounter the
## player declined, at the strength they declined it - not a second Chainmaker,
## which would be a difficulty setting nobody chose.
func _summon_the_gatekeeper_if_owed(act: int, boss_lane: int) -> void:
	if act < Balance.FINAL_ASCENT_ACT:
		return
	if not GatekeeperTrials.guards_the_summit(RunState.tier_id):
		return
	var keeper: EnemyData = null
	for boss: EnemyData in ContentDB.enemies_of_category(EnemyData.Category.BOSS):
		if boss.id == GATEKEEPER_ID:
			keeper = boss
			break
	if keeper == null:
		push_warning("BossDirector: the summit owes a Gatekeeper and none is authored")
		return
	var lane: int = (boss_lane + 1 + _rng.randi_range(0, Balance.LANE_COUNT - 2)) 		% Balance.LANE_COUNT
	var trial_act: int = GatekeeperTrials.STAGE_ACTS[GatekeeperTrials.STAGES - 1]
	_escort = battlefield.spawn_enemy(keeper, lane, _boss_scale(trial_act))
	if _escort == null:
		return
	EventBus.boss_spawned.emit(keeper.id, act)
	EventBus.preparation_warning.emit(
		"THE GATE CAME WITH HIM  ·  the trial you did not take is standing on another road.")


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


## Act to boss id, read off the region that act is played in.
##
## **It used to be a match statement here**, on the argument that a field on
## `TerrainData` "would only ever have three values". Ten acts is that argument
## failing: adding a region now means adding files, not editing this function,
## which is working rule 3 in its ordinary form.
##
## The Final Ascent reports one act past `ACT_COUNT` and has no region, so it
## falls through to the summit - which is the only thing out there.
func _expected_boss_id(act: int) -> String:
	var region: TerrainData = ContentDB.terrain_for_act(act)
	if region != null and not region.boss_id.is_empty():
		return region.boss_id
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
	# **And then the room goes quiet.** Before the signal, so the hush is already
	# falling while everything downstream - the card, the sting, the act ending -
	# arrives into it rather than over it.
	MusicPlayer.hush(Balance.BOSS_HUSH_SECONDS, Balance.BOSS_HUSH_DEPTH)
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
	RunState.bosses_felled += 1
	RunState._sync_discipline_spells()

	# 2. Boss core — permanent, always active, never socketed.
	#
	# By act rather than by the boss's name. The id was assembled as
	# `"core_" + boss_id` and awarded only `if ContentDB.relics.has(core_id)`,
	# so an act whose core had never been authored paid nothing and said
	# nothing - which was true of acts IV to X, seven tenths of the campaign,
	# against a comment above promising all three parts every act.
	var core: RelicData = ContentDB.boss_core_for_act(act)
	if core != null and not RunState.boss_cores.has(core.id):
		RunState.boss_cores.append(core.id)

	# 3. The next act's terrain, which the journey switches to at the boundary.
	RunState.gain_resources(Balance.BOSS_RESOURCE_REWARD)
	RunState.gain_currency(RunState.STONE, Balance.BOSS_STONE_REWARD)


func _unequipped_spell() -> String:
	for id: Variant in ContentDB.spells:
		var spell_id: String = String(id)
		if not RunState.equipped_spells.has(spell_id):
			return spell_id
	return ""
