extends Node

const CommandSystemScript = preload("res://scripts/systems/command_system.gd")

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
	_run._preparation_left = 0.0
	_run._on_ride_on_requested()
	_run._on_ride_on_requested()
	await get_tree().process_frame
	_run.journey.stop()

	_test_upgrade_track()
	_test_four_currency_economy()
	await _test_live_tower_utility()
	_test_opening_envelope()
	_test_act_curves()
	_test_sequential_waves()
	_test_enemy_roles()
	_test_zoom_range()
	_test_beast_gait()
	_test_hostile_projectile()
	_test_live_relic_updates()
	_test_wave_archetypes()
	_test_target_priorities()
	await _test_preparation_and_command()
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


func _test_four_currency_economy() -> void:
	_check(RunState.currencies.size() == 4,
		"the run must have exactly four role-specific economy wallets")
	_check(RunState.currency(RunState.GOLD) >= Balance.LANE_COUNT * Balance.TOWER_BUILD_COST,
		"starting Gold must cover one base tower per road")
	_check(RunState.currency(RunState.STONE) >= Balance.TOWER_COMBO_STONE_COST,
		"starting Stone must leave one opening Fusion choice")
	_check(ContentDB.buildings.size() == 9,
		"the town must expose all nine launch plots")
	_check(RunState.building_tier("woodcutter") == 1 \
		and RunState.building_tier("granary") == 1,
		"Woodcutter and Wheat Farm must begin at tier one")
	var total_before: int = 0
	for id: String in RunState.CURRENCIES:
		total_before += RunState.currency(id)
	RunState.building_tiers["market"] = 1
	var prior_phase: RunState.Phase = RunState.phase
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.begin_preparation_market()
	var source: String = RunState.GOLD
	var target: String = RunState.FOOD
	var market_problem: String = TownScope.try_market_trade(source, target)
	_check(market_problem.is_empty(),
		"a funded Market exchange must resolve during Preparation (%s)" % market_problem)
	var total_after: int = 0
	for id: String in RunState.CURRENCIES:
		total_after += RunState.currency(id)
	_check(total_after < total_before,
		"Market exchange must destroy value rather than permit a profit loop")
	TownScope.try_market_trade(source, target)
	_check(not TownScope.try_market_trade(source, target).is_empty(),
		"Market exchanges must stop at the per-Preparation cap")
	RunState.set_phase(prior_phase)


func _test_live_tower_utility() -> void:
	var field: Battlefield = _run.battlefield
	RunState.set_phase(RunState.Phase.PREPARATION)
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
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)


func _test_act_curves() -> void:
	var director: WaveDirector = _run.battlefield.wave_director
	_set_progress(2, 1200.0, 48, "saltglass", 12)
	var act2_size: int = director._wave_size(12, ContentDB.terrain("saltglass"))
	var act2_hp: float = director._hp_scale(0)
	var act2_damage: float = director._damage_scale(0)
	_check(act2_size >= 10, "Act 2 waves must outgrow the compact opening formations")
	_check(act2_hp >= 4.0, "Act 2 durability must materially exceed Act 1")
	_check(act2_damage < act2_hp, "damage must scale below HP to avoid cheap one-shots")

	_set_progress(3, 2550.0, 88, "steppe", 22)
	var act3_size: int = director._wave_size(22, ContentDB.terrain("steppe"))
	var act3_hp: float = director._hp_scale(0)
	_check(act3_size > act2_size * 2, "Iron Steppe must deliver the largest packs")
	_check(act3_hp > act2_hp * 1.8, "Act 3 must demand mastery upgrades")
	_check(director._speed_scale(0) > 1.15, "late-run enemies must move faster")

	# Crossing into Saltglass should reveal new tactics, not erase the player's
	# progress with a seventy-percent stat jump on the very first formation.
	DayNight._apply(0.18)
	_set_progress(1, 790.0, 18, "ashfen", 18)
	var act1_exit_hp: float = director._hp_scale(0)
	_set_progress(2, 910.0, 19, "saltglass", 1)
	var act2_entry_hp: float = director._hp_scale(0)
	_check(act2_entry_hp <= act1_exit_hp * 1.40,
		"Act 2 entry must rise smoothly instead of becoming an early stat wall")
	_set_progress(3, 2550.0, 88, "steppe", 22)
	DayNight._apply(0.74)
	print("[balance] Act2 per-lane=%d hp=%.2f damage=%.2f | Act3 per-lane=%d hp=%.2f" \
		% [act2_size, act2_hp, act2_damage, act3_size, act3_hp])


## New players can establish a four-road baseline and learn one pressure at a
## time, while every modifier is neutral before the midgame begins.
func _test_opening_envelope() -> void:
	var director: WaveDirector = _run.battlefield.wave_director
	_set_progress(1, 0.0, 1, "ashfen", 1)
	DayNight._apply(0.18)
	var terrain: TerrainData = ContentDB.terrain("ashfen")
	var first_size: int = director._wave_size(1, terrain)
	var first_hp: float = director._hp_scale(0)
	var first_damage: float = director._damage_scale(0)
	_check(Balance.STARTING_GOLD >= Balance.LANE_COUNT * Balance.TOWER_BUILD_COST \
		+ Balance.TOWER_BUILD_COST,
		"opening Gold must cover all four roads plus one flex purchase")
	director._wave_timer = 1.0
	RunState.wave_number = 0
	director._on_act_started(1, "ashfen")
	_check(director.time_to_next_wave() >= 15.0,
		"live first-wave timer must leave a meaningful planning window")
	RunState.wave_number = 1
	_check(first_size <= 5, "first wave must teach with a compact pack")
	_check(first_hp <= 0.8 and first_damage <= 0.75,
		"first enemies must be forgiving in both durability and contact threat")
	_check(director._progressive_lane_count(2) == 1,
		"the first two waves must teach one road at a time")
	_check(director._progressive_lane_count(3) == 2 \
		and director._progressive_lane_count(5) == 3,
		"lane pressure must open one road at a time instead of jumping from one to three")
	_check(director._opening_scale(Balance.WAVE_OPENING_COUNT_SCALE, 8) == 1.0 \
		and director._opening_scale(Balance.WAVE_OPENING_DAMAGE_SCALE, 9) == 1.0,
		"opening protection must taper smoothly and be neutral after wave eight")
	var early_formations: Array[WaveArchetypeData] = ContentDB.available_wave_archetypes(1, 3)
	_check(early_formations.size() == 1 and early_formations[0].id == "measured_advance",
		"specialist formations must wait until the core loop is established")
	var supply_total: int = 0
	for amount: int in Balance.WAVE_OPENING_SUPPLIES:
		supply_total += amount
	_check(supply_total >= Balance.TOWER_BUILD_COST,
		"opening supply pulses must finance at least one reactive defence")
	print("[balance] Opening pack=%d hp=%.2f damage=%.2f prep=%.0fs gold=%d supplies=%d" \
		% [first_size, first_hp, first_damage, Balance.WAVE_FIRST_PREPARATION,
			Balance.STARTING_GOLD, supply_total])


func _set_progress(act: int, distance: float, wave: int, terrain_id: String,
		act_wave: int) -> void:
	RunState.act = act
	RunState.distance_travelled = distance
	RunState.wave_number = wave
	RunState.terrain_id = terrain_id
	_run.battlefield.wave_director._act_wave = act_wave
	DayNight._apply(0.74)


## A wave owns its complete formation. A zero timer may not stack another queue
## on top of it; dense late formations preserve endgame pressure within a wave.
func _test_sequential_waves() -> void:
	var director: WaveDirector = _run.battlefield.wave_director
	director.stop()
	director._spawn_queue.clear()
	var before: int = RunState.wave_number
	director._wave_active = true
	director._spawn_queue.append({})
	director._spawn_timer = 99.0
	director._wave_timer = 0.0
	director.start()
	director._process(0.1)
	director.stop()
	_check(RunState.wave_number == before,
		"next wave must wait while the current formation is still deploying")
	director._spawn_queue.clear()
	director._wave_active = false


func _test_enemy_roles() -> void:
	_check(ContentDB.enemy("glassborn").role == EnemyData.Role.VANGUARD,
		"Glass-born must carry the fast-vanguard role")
	_check(ContentDB.enemy("howler").role == EnemyData.Role.HOWLER,
		"Howler must own its aura and ranged threat")
	_check(ContentDB.enemy("burrower").spawn_distance_scale < 0.8,
		"Burrower must emerge inside the outer defence")
	var regular_ids: Dictionary = {}
	var elite_ids: Dictionary = {}
	for terrain: TerrainData in [ContentDB.terrain("ashfen"),
			ContentDB.terrain("saltglass"), ContentDB.terrain("steppe")]:
		_check(terrain != null and terrain.enemy_ids.size() == 4,
			"every region must ship four regular enemy roles")
		_check(terrain != null and terrain.elite_ids.size() == 2,
			"every region must ship two regional elites")
		if terrain == null:
			continue
		for id: String in terrain.enemy_ids:
			var enemy: EnemyData = ContentDB.enemy(id)
			regular_ids[id] = true
			_check(enemy != null and ResourceLoader.exists(enemy.get_sprite_path()),
				"regional enemy '%s' needs data and production art" % id)
		for id: String in terrain.elite_ids:
			var elite: EnemyData = ContentDB.enemy(id)
			elite_ids[id] = true
			_check(elite != null and elite.category == EnemyData.Category.ELITE \
					and ResourceLoader.exists(elite.get_sprite_path()),
				"regional elite '%s' needs elite data and production art" % id)
	_check(regular_ids.size() == 12 and elite_ids.size() == 6,
		"launch roster must contain twelve unique regulars and six unique elites")


func _test_wave_archetypes() -> void:
	_check(ContentDB.wave_archetypes.size() >= 10,
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
	RunState.terrain_id = "saltglass"
	_check(director._signature_enemy(siege).id == "siege_lizard",
		"signature roles must resolve to the active regional faction")
	var pincer: WaveArchetypeData = ContentDB.wave_archetype("burrower_pincer")
	lanes = director._pick_archetype_lanes(pincer, 7)
	_check(lanes.size() == 2 and abs(lanes[0] - lanes[1]) == 2,
		"burrower pincers must split the player's attention across opposite roads")
	var false_front: WaveArchetypeData = ContentDB.wave_archetype("false_front")
	lanes = director._pick_archetype_lanes(false_front, 7)
	_check(lanes.size() == 2 and (abs(lanes[0] - lanes[1]) == 1 \
			or abs(lanes[0] - lanes[1]) == Balance.LANE_COUNT - 1),
		"false fronts must reveal on an adjacent road")
	director._spawn_queue.clear()
	director._build_delayed_surge(false_front, lanes, 5, 1.0, 1.0, 1.0, 1.0)
	var delay_entries: int = 0
	for entry: Dictionary in director._spawn_queue:
		if entry.has("delay"):
			delay_entries += 1
	_check(director._spawn_queue.size() == 11 and delay_entries == 1,
		"false front must preserve its body budget around one authored reveal hold")
	director._spawn_queue.clear()


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


func _test_preparation_and_command() -> void:
	var field: Battlefield = _run.battlefield
	RunState.set_phase(RunState.Phase.PREPARATION)
	_check(field.try_build(1, 0, ContentDB.tower("ember_spire")).is_empty(),
		"tower construction must be legal during Preparation")
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_check(not field.try_upgrade(1, 0).is_empty(),
		"tower upgrades must be locked during road combat")
	_check(not TownScope.try_start_construction("forge").is_empty(),
		"town construction must be locked during road combat")

	RunState.begin_command_battle()
	field._pressure[1] = 0.72
	EventBus.hero_enemy_hit.emit("howler", 1, true, true, Vector2.RIGHT * 300.0)
	_check(RunState.command >= Balance.COMMAND_HERO_HIT_GAIN \
			+ Balance.COMMAND_PRIORITY_HIT_GAIN + Balance.COMMAND_INTERRUPT_GAIN,
		"active hero hits on a pressured road must generate tactical Command")
	RunState.gain_command(Balance.COMMAND_MAX)
	var command: Node = _run.command_system
	var tower: Tower = field.slot_at(1, 0).tower()
	_check(command.use_order(CommandSystemScript.OVERDRIVE, 1, 0).is_empty(),
		"Overdrive must resolve on a built tower")
	_check(tower != null and tower._command_overdrive_left > 0.0,
		"Overdrive must apply a live tower effect")
	RunState.gain_command(Balance.COMMAND_MAX)
	_check(command.use_order(CommandSystemScript.RALLY_ROAD, 1, -1).is_empty(),
		"Rally Road must resolve on a selected road")
	RunState.gain_command(Balance.COMMAND_MAX)
	_check(command.use_order(CommandSystemScript.LAST_STAND, -1, -1).is_empty(),
		"Last Stand must resolve at full Command")
	_check(RunState.last_stand_used and field.town.health.is_invulnerable(),
		"Last Stand must protect the Town Hall and enforce once-per-battle use")
	RunState.horn_used_this_battle = false
	_check(_run.war_horn.blow(), "the war horn must be available once in a road battle")
	_run.war_horn._horn_left = 0.01
	_run.war_horn._process(0.02)
	_check(not _run.war_horn.blow(), "the war horn must not be reusable in the same road battle")
	RunState.begin_command_battle()
	_check(not RunState.horn_used_this_battle, "a new battle must restore its one horn opportunity")

	var hero: Hero = field.hero
	RunState.hero_wounds = 0
	RunState.hero_hp = -1.0
	hero.sync_from_run_state()
	var unwounded_max: float = hero.health.max_hp
	RunState.add_wound()
	hero.sync_from_run_state()
	_check(is_equal_approx(hero.health.max_hp, unwounded_max * 0.9),
		"one Wound must reduce maximum hero HP by exactly 10 percent")
	RunState.town_hp = RunState.town_max_hp * 0.5
	RunState.hearthmend()
	hero.apply_hearthmend()
	_check(RunState.hero_wounds == 0 and is_equal_approx(hero.health.current_hp, hero.health.max_hp),
		"Hearthmend must clear Wounds and fully restore the hero")
	_check(RunState.town_hp > RunState.town_max_hp * 0.5,
		"Hearthmend must provide its bounded Town Hall repair")
	RunState.has_resurrection_draught = true
	var deaths_before: int = RunState.hero_deaths
	hero.health.take_damage(hero.health.max_hp * 2.0, Vector2.ZERO)
	_check(hero.is_alive() and not RunState.has_resurrection_draught \
			and RunState.hero_deaths == deaths_before,
		"Resurrection Draught must prevent, not merely delay, the next lethal down")


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
	_check(Balance.CAMERA_MOUSE_LEAN_MAX < Balance.LANE_SPAWN_RADIUS,
		"camera look-ahead must be bounded inside the battlefield")
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


func _test_beast_gait() -> void:
	var rig := _run.battlefield.camera as CameraRig
	_check(rig.beast_motion, "battlefield camera must carry the beast gait")
	_check(Balance.BEAST_GAIT_HORIZONTAL <= 6.0 \
		and Balance.BEAST_GAIT_ROTATION_DEGREES <= 0.2,
		"beast gait must remain below gameplay-disrupting amplitude")
	var previous: float = UserSettings.number(UserSettings.GAIT_KEY, 0.65)
	UserSettings.set_value(UserSettings.GAIT_KEY, 1.0)
	RunState.beast_speed = Balance.BEAST_BASE_SPEED
	rig._tick_gait(0.25)
	_check(rig.offset.length() > 0.1, "enabled beast gait must visibly move the battlefield")
	# Force a support-pair transfer and prove it creates the planted pause, body
	# sink and impact shake that make Yuri read as a massive walker rather than a
	# smoothly floating camera sine.
	rig._gait_pause_left = 0.0
	rig._gait_phase = PI - 0.01
	rig._gait_step = 0
	rig._tick_gait(0.03)
	_check(rig._gait_pause_left > 0.0 and rig._step_sink > 0.0,
		"each alternating support plant must pause and settle under Yuri's mass")
	_check(rig._shake_left > 0.0,
		"a planted beast step must produce a brief impact shake")
	UserSettings.set_value(UserSettings.GAIT_KEY, 0.0)
	rig._tick_gait(0.016)
	_check(rig.offset == rig._shake_offset and is_zero_approx(rig.rotation),
		"turning beast motion off must stop it immediately")
	UserSettings.set_value(UserSettings.GAIT_KEY, previous)


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
	RunState.set_phase(RunState.Phase.PREPARATION)
	var problem: String = TownScope.try_socket_relic("02")
	_check(problem.is_empty(), "town-health relic must socket during a live run")
	_check(town.health.max_hp > before,
		"socketing a town-health relic must update the live city immediately")
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
