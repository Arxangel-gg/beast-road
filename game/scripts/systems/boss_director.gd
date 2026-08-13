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


func _ready() -> void:
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

	var lane: int = randi() % Balance.LANE_COUNT
	# Bosses ignore the live-enemy cap: the cap exists to stop a death spiral of
	# trash, and the boss *is* the encounter.
	_active = battlefield.spawn_enemy(data, lane, _boss_scale(act))
	if _active == null:
		return false
	_active_act = act

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
	var all: Array[EnemyData] = ContentDB.enemies_of_category(EnemyData.Category.BOSS)
	return all[clampi(act - 1, 0, all.size() - 1)] if not all.is_empty() else null


## Act to boss id. The mapping is in the GDD's act table; keeping it here rather
## than on TerrainData avoids a field that only ever has three values.
func _expected_boss_id(act: int) -> String:
	match act:
		1:
			return "drowned_choir"
		2:
			return "mirrorfang"
		_:
			return "rust_crown"


func _on_enemy_died(enemy_id: String, _at: Vector2) -> void:
	if _active == null or not is_instance_valid(_active):
		return
	if _active.data == null or _active.data.id != enemy_id:
		return

	var act: int = _active_act
	_active = null
	_active_act = 0
	_defeated_acts.append(act)

	_grant_rewards(act)
	EventBus.camera_shake_requested.emit(22.0, 1.2)
	EventBus.boss_defeated.emit(enemy_id, act)


## The boss reward package, all three parts, every act (GDD §9).
func _grant_rewards(act: int) -> void:
	# 1. Hero ascension — a stat tier, and a spell slot in acts 1 and 2.
	RunState.hero_ascension += 1
	if act < Balance.ACT_COUNT and RunState.equipped_spells.size() < Balance.HERO_MAX_SPELL_SLOTS:
		var spare: String = _unequipped_spell()
		if not spare.is_empty():
			RunState.equipped_spells.append(spare)
			EventBus.spells_changed.emit()

	# 2. Boss core — permanent, always active, never socketed.
	var core_id: String = "core_" + _expected_boss_id(act)
	if ContentDB.relics.has(core_id) and not RunState.boss_cores.has(core_id):
		RunState.boss_cores.append(core_id)

	# 3. The next act's terrain, which the journey switches to at the boundary.
	RunState.gain_resources(Balance.BOSS_RESOURCE_REWARD)


func _unequipped_spell() -> String:
	for id: Variant in ContentDB.spells:
		var spell_id: String = String(id)
		if not RunState.equipped_spells.has(spell_id):
			return spell_id
	return ""
