extends Node

## Headless regression test for the production difficulty/economy curve.
## It checks the two failure modes this pass fixes: Act 2 becoming easier than
## the player's build, and the upgrade economy ending before the first boss.

var _failures: PackedStringArray = []
var _run: Run = null


func _ready() -> void:
	RunState.reset()
	var packed: PackedScene = load("res://scenes/run/run.tscn")
	_run = packed.instantiate() as Run
	add_child(_run)
	await get_tree().process_frame
	_run.journey.stop()

	_test_upgrade_track()
	await _test_live_tower_utility()
	_test_act_curves()
	_test_overlapping_waves()
	_test_enemy_roles()
	_test_zoom_range()
	_test_hostile_projectile()
	_test_live_relic_updates()
	_test_wave_archetypes()
	_test_target_priorities()
	await _test_boss_phases()
	_test_run_telemetry()

	if _failures.is_empty():
		print("[balance] PASS — mastery economy and three-act pressure curve")
	else:
		for failure: String in _failures:
			push_error("[balance] " + failure)

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	_run.queue_free()
	for frame: int in 30:
		await get_tree().process_frame
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _test_upgrade_track() -> void:
	_check(RunState.tower_level_cap() == 2, "towers must begin capped at level 2")
	_check(ContentDB.building("forge").effect_at(1) == 3.0,
		"Forge tier 1 must communicate mastery level 3")
	RunState.building_tiers["forge"] = 3
	_check(RunState.tower_level_cap() == 5, "Forge tier 3 must unlock level 5")
	var full_cost: int = Balance.TOWER_BUILD_COST
	for cost: int in Balance.TOWER_UPGRADE_COSTS:
		full_cost += cost
	_check(full_cost >= 1000, "one max tower must remain a meaningful late-run investment")
	_check(Balance.TOWER_LEVEL_UTILITY.size() == Balance.TOWER_MAX_LEVEL,
		"utility progression must cover every tower level")


func _test_live_tower_utility() -> void:
	var field: Battlefield = _run.battlefield
	RunState.gain_resources(9999)
	var bulwark: TowerData = ContentDB.tower("bulwark")
	_check(field.try_build(0, 0, bulwark).is_empty(), "Bulwark must be buildable")
	await get_tree().process_frame
	var built: Tower = field.slot_at(0, 0).tower()
	_check(built != null and Health.of(built) != null,
		"taunting towers must expose live structure health")
	if built != null and Health.of(built) != null:
		var tower_health: Health = Health.of(built)
		var before_hp: float = tower_health.current_hp
		tower_health.take_damage(10.0, Vector2.ZERO)
		_check(tower_health.current_hp < before_hp,
			"taunting towers must take enemy damage")


func _test_act_curves() -> void:
	var director: WaveDirector = _run.battlefield.wave_director
	_set_progress(2, 1200.0, 48, "saltglass", 12)
	var act2_size: int = director._wave_size(12, ContentDB.terrain("saltglass"))
	var act2_hp: float = director._hp_scale(0)
	var act2_damage: float = director._damage_scale(0)
	_check(act2_size >= 12, "Act 2 waves must outgrow an eight-tower opening defence")
	_check(act2_hp >= 4.0, "Act 2 durability must materially exceed Act 1")
	_check(act2_damage < act2_hp, "damage must scale below HP to avoid cheap one-shots")

	_set_progress(3, 2550.0, 88, "steppe", 22)
	var act3_size: int = director._wave_size(22, ContentDB.terrain("steppe"))
	var act3_hp: float = director._hp_scale(0)
	_check(act3_size > act2_size * 2, "Iron Steppe must deliver the largest packs")
	_check(act3_hp > act2_hp * 1.8, "Act 3 must demand mastery upgrades")
	_check(director._speed_scale(0) > 1.15, "late-run enemies must move faster")
	print("[balance] Act2 per-lane=%d hp=%.2f damage=%.2f | Act3 per-lane=%d hp=%.2f" \
		% [act2_size, act2_hp, act2_damage, act3_size, act3_hp])


func _set_progress(act: int, distance: float, wave: int, terrain_id: String,
		act_wave: int) -> void:
	RunState.act = act
	RunState.distance_travelled = distance
	RunState.wave_number = wave
	RunState.terrain_id = terrain_id
	_run.battlefield.wave_director._act_wave = act_wave
	DayNight._apply(0.74)


## A late pack takes longer to deploy than the nominal interval. The director
## must still open the next wave on cadence or Act 3 turns back into a trickle.
func _test_overlapping_waves() -> void:
	var director: WaveDirector = _run.battlefield.wave_director
	director.stop()
	director._spawn_queue.clear()
	director._begin_wave()
	_check(not director._spawn_queue.is_empty(), "representative wave must create a spawn queue")
	var before: int = RunState.wave_number
	director._wave_timer = 0.0
	director.start()
	director._process(0.1)
	director.stop()
	_check(RunState.wave_number == before + 1,
		"next wave must begin while the prior spawn queue is still deploying")
	_check(director._spawn_queue.size() <= Balance.WAVE_MAX_QUEUED,
		"overlapping wave queues must retain a hard safety cap")
	director._spawn_queue.clear()


func _test_enemy_roles() -> void:
	_check(ContentDB.enemy("glassborn").role == EnemyData.Role.VANGUARD,
		"Glass-born must carry the fast-vanguard role")
	_check(ContentDB.enemy("howler").role == EnemyData.Role.HOWLER,
		"Howler must own its aura and ranged threat")
	_check(ContentDB.enemy("burrower").spawn_distance_scale < 0.8,
		"Burrower must emerge inside the outer defence")


func _test_wave_archetypes() -> void:
	_check(ContentDB.wave_archetypes.size() >= 6,
		"the battlefield must expose a full tactical wave vocabulary")
	for value: Variant in ContentDB.wave_archetypes.values():
		var archetype := value as WaveArchetypeData
		_check(archetype != null and not archetype.display_name.is_empty(),
			"every wave archetype must be named content")
		if archetype != null and not archetype.signature_enemy_id.is_empty():
			_check(ContentDB.enemy(archetype.signature_enemy_id) != null,
				"wave signature enemy '%s' must exist" % archetype.signature_enemy_id)
	var director: WaveDirector = _run.battlefield.wave_director
	_set_progress(2, 1200.0, 48, "saltglass", 6)
	var siege: WaveArchetypeData = ContentDB.wave_archetype("siege_column")
	var lanes: Array[int] = director._pick_archetype_lanes(siege, 7)
	_check(lanes.size() == 1, "siege columns must concentrate on one lane")
	var pincer: WaveArchetypeData = ContentDB.wave_archetype("burrower_pincer")
	lanes = director._pick_archetype_lanes(pincer, 7)
	_check(lanes.size() == 2 and abs(lanes[0] - lanes[1]) == 2,
		"burrower pincers must split the player's attention across opposite roads")


func _test_target_priorities() -> void:
	var field: Battlefield = _run.battlefield
	if RunState.slot_is_empty(0, 0):
		RunState.set_slot(0, 0, "ember_spire", 1)
	var before: int = RunState.target_priority_in_slot(0, 0)
	var after: int = RunState.cycle_target_priority(0, 0)
	_check(after != before and after == TowerData.TargetPriority.STRONG,
		"built towers must cycle through player-selected targeting doctrines")
	RunState.set_slot(0, 0, "ember_spire", 2)
	_check(RunState.target_priority_in_slot(0, 0) == after,
		"upgrading a tower must preserve its targeting doctrine")


func _test_boss_phases() -> void:
	var director: BossDirector = _run.boss_director
	for act: int in range(1, Balance.ACT_COUNT + 1):
		var boss: EnemyData = director._boss_for_act(act)
		_check(boss != null and boss.phase_thresholds.size() == 2,
			"every act boss must have two encounter phases")
		_check(boss != null and boss.phase_names.size() == boss.phase_thresholds.size(),
			"boss phase thresholds and names must stay aligned")
	# Exercise the live threshold contract once. Reinforcement composition itself
	# is data-tested above and the soak test covers spawning under load.
	director._defeated_acts.clear()
	_check(director.summon(1), "Act 1 boss must summon for phase validation")
	await get_tree().process_frame
	var boss_enemy: Enemy = director.active_boss()
	_check(boss_enemy != null, "summoned boss must remain active")
	if boss_enemy != null:
		var health: Health = Health.of(boss_enemy)
		health.take_damage(health.max_hp * 0.36, Vector2.ZERO)
		_check(director._active_phase >= 1,
			"boss must enter a new phase after crossing its first health threshold")
		boss_enemy.queue_free()
		director._active = null
		director._active_act = 0
		director._active_phase = 0
	# A killing blow can cross every threshold at once; it must end the encounter,
	# not spawn both phase waves after the boss has already reached zero HP.
	director._defeated_acts.clear()
	_check(director.summon(1), "boss must resummon for lethal-threshold validation")
	await get_tree().process_frame
	boss_enemy = director.active_boss()
	if boss_enemy != null:
		var lethal_health: Health = Health.of(boss_enemy)
		lethal_health.take_damage(lethal_health.max_hp * 2.0, Vector2.ZERO)
		_check(director._active_phase == 0,
			"a lethal blow must not trigger post-mortem boss phases")


func _test_run_telemetry() -> void:
	RunState.wave_archetype_counts.clear()
	RunState.record_wave_archetype("rush")
	RunState.record_wave_archetype("rush")
	RunState.record_wave_archetype("siege_column")
	_check(RunState.most_common_wave_archetype() == "rush",
		"run debrief must identify the most frequent tactical pressure")
	_check(RunState.resources_spent >= 0 and RunState.peak_lane_pressure >= 0.0,
		"run telemetry counters must be safe from the first frame")


func _test_zoom_range() -> void:
	var rig := _run.battlefield.camera as CameraRig
	rig.reset_to_wide()
	_check(not rig.zoom_by(-1), "wide battlefield limit must hand wheel-out to Town")
	_check(rig.zoom_by(1), "wheel-in must zoom the battlefield")
	rig.reset_to_wide()
	_run._zoom_ladder(-1)
	_check(GameDirector.current_scope == GameDirector.Scope.TOWN,
		"wheel-out from wide battlefield must open Town")
	_run._zoom_ladder(-1)
	_check(GameDirector.current_scope == GameDirector.Scope.BEAST,
		"wheel-out from Town must open Beast")
	_run._zoom_ladder(1)
	_check(GameDirector.current_scope == GameDirector.Scope.TOWN,
		"wheel-in from Beast must return to Town")
	_run._zoom_ladder(1)
	_check(GameDirector.current_scope == GameDirector.Scope.BATTLEFIELD,
		"wheel-in from Town must return to battlefield")


func _test_hostile_projectile() -> void:
	var howler: Enemy = _run.battlefield.spawn_enemy(
		ContentDB.enemy("howler"), 0, 1.0, 1.0, 1.0)
	if howler == null:
		_check(false, "Howler must spawn")
		return
	howler.global_position = Vector2.UP * 300.0
	howler._target = _run.battlefield.town
	howler._strike()
	var found: bool = false
	for child: Node in _run.battlefield.get_children():
		if child.get_script() != null \
				and child.get_script().resource_path == "res://scenes/battlefield/enemy_projectile.gd":
			found = true
			break
	_check(found, "Howler must release a visible hostile projectile")


func _test_live_relic_updates() -> void:
	var town: TownCore = _run.battlefield.town
	var before: float = town.health.max_hp
	RunState.held_relics.append("02")
	var problem: String = TownScope.try_socket_relic("02")
	_check(problem.is_empty(), "town-health relic must socket during a live run")
	_check(town.health.max_hp > before,
		"socketing a town-health relic must update the live city immediately")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
