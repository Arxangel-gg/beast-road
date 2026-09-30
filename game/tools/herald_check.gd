extends Node

## **The Herald** (2026-09-30, `Heralds`): the one body on the road only a
## Warden can stop.
##
##   godot --headless --path game res://tools/herald_check.tscn
##
## Driven on the real field, through the real doors:
##
## - **The roll**: never before `HERALD_FIRST_ACT`, never on the Walk, about as
##   often as authored, into the first half of the queue, on a breed of the
##   region that runs for the gate - and drawn from the Herald's own stream, so
##   the waves and the ranks deal what they always dealt.
## - **The board looks away**: a real tower firing for real at a body beside a
##   Herald leaves the Herald whole, splash and all; a tower's or a trap's blow
##   is refused at the funnel; the ground a tower's shot leaves does not burn
##   it; the board's Arsenal does not see it and the Warden's does.
## - **The call**: a Herald left to walk reaches the wall and calls, the board
##   may shoot it from then on, and the next wave the director deals is larger.
## - **The bounty**: run down before the wall, it drops exactly what `bounty`
##   says; run down after its call, it drops no bounty.
## - **The arrow**: the edge of the screen points at a Herald until it calls.

const TAG: String = "[herald]"

var _run: Run = null
var _field: Battlefield = null
var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []
var _rose: int = 0
var _called: int = 0
var _fell: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260930)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	var animals: Node = _field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	# Nothing may end the run while bodies stand at the wall.
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	RunState.gain_every_currency(20000)
	EventBus.herald_rose.connect(_on_rose)
	EventBus.herald_called.connect(_on_called)
	EventBus.herald_fell.connect(_on_fell)
	# The Warden stands inside the walls, where no road body can see them, so
	# nothing here is decided by a fight with the Warden.
	_field.hero.global_position = _field.town_position()

	_test_the_roll()
	await _test_the_call_reinforces()
	await _test_the_board_looks_away()
	await _test_the_bounty()
	await _test_the_call()
	await _test_the_arrow()
	_test_the_wiring()
	for stage: String in ["roll", "reinforce", "board", "bounty", "call", "arrow", "wiring"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)

	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	_run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: the board cannot touch a Herald, the wall hears its call, and the Warden is paid for stopping it" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d problem(s)" % [TAG, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	printerr("%s FAIL: %s" % [TAG, why])


func _on_rose(_at: Vector2) -> void:
	_rose += 1


func _on_called(_at: Vector2) -> void:
	_called += 1


func _on_fell(_at: Vector2) -> void:
	_fell += 1


## A breed of the region that runs for the gate.
func _runner() -> EnemyData:
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	for id: String in terrain.enemy_ids:
		var breed: EnemyData = ContentDB.enemy(id)
		if breed != null and not breed.targets_towers and breed.category == EnemyData.Category.BREED:
			return breed
	return null


## A body that stands where it is put: a pool nothing here can empty by
## accident, and a speed too small to walk off its mark.
func _stand(breed: EnemyData, at: Vector2, herald: bool) -> Enemy:
	var body: Enemy = _field.spawn_enemy(breed, 0, 60.0, -1.0, 0.001)
	if body == null:
		return null
	body.global_position = at
	if herald:
		body.make_herald()
	return body


func _clear_bodies() -> void:
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		if node is Enemy:
			node.queue_free()
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		if node is Node2D and (node as Node2D).is_inside_tree() and (node as Node2D).visible:
			node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _test_the_roll() -> void:
	var director: WaveDirector = _field.wave_director
	RunState.walking = false
	for act: int in range(1, Balance.HERALD_FIRST_ACT):
		_check(not Heralds.may_rise(act), "a Herald may not rise in Act %d" % act)
	_check(Heralds.may_rise(Balance.HERALD_FIRST_ACT), "a Herald may rise from Act %d" % Balance.HERALD_FIRST_ACT)
	RunState.walking = true
	_check(not Heralds.may_rise(Balance.HERALD_FIRST_ACT + 2), "a Herald never rises on the Walk")
	RunState.walking = false

	var act_was: int = RunState.act
	RunState.act = Balance.HERALD_FIRST_ACT
	var waves_before: int = RunState.rng("waves").state
	var rank_before: int = RunState.rng("rank").state
	var lanes: Array[int] = [0, 1, 2, 3]
	var rolls: int = 600
	var risen: int = 0
	var early: bool = true
	var runs: bool = true
	var scaled: bool = true
	for _roll: int in rolls:
		var queue: Array[Dictionary] = []
		for _i: int in 20:
			queue.append(director.call("_spawn_entry", 0, false, "", 1.0, 1.0, 1.0, 1.0))
		director.set("_spawn_queue", queue)
		director.call("_raise_a_herald", lanes, 1.0, 1.0, 1.0, 1.0)
		var after: Array = director.get("_spawn_queue")
		if after.size() == 21:
			risen += 1
			var index: int = -1
			for i: int in after.size():
				if bool((after[i] as Dictionary).get("herald", false)):
					index = i
			var entry: Dictionary = after[index] if index >= 0 else {}
			if index < 0 or index > 10:
				early = false
			var breed: EnemyData = ContentDB.enemy(String(entry.get("enemy_id", "")))
			if breed == null or breed.targets_towers or breed.category != EnemyData.Category.BREED:
				runs = false
			if not is_equal_approx(float(entry.get("hp_scale", 0.0)), Balance.HERALD_HEALTH_SCALE) \
					or not is_equal_approx(float(entry.get("speed_scale", 0.0)), Balance.HERALD_SPEED_SCALE):
				scaled = false
		elif after.size() != 20:
			_check(false, "a Herald roll changed the queue by %d entries" % (after.size() - 20))
	director.set("_spawn_queue", [] as Array[Dictionary])
	var share: float = float(risen) / float(rolls)
	_check(share > Balance.HERALD_WAVE_CHANCE * 0.5 and share < Balance.HERALD_WAVE_CHANCE * 1.6,
		"Heralds rose on %.1f%% of %d waves against %.0f%% authored" % [share * 100.0, rolls,
		Balance.HERALD_WAVE_CHANCE * 100.0])
	_check(early, "a Herald must walk on among the first half of its wave")
	_check(runs, "a Herald must be a breed of the region that runs for the gate")
	_check(scaled, "a Herald carries its own health and speed on its entry")
	_check(RunState.rng("waves").state == waves_before, "raising a Herald moved the waves stream")
	_check(RunState.rng("rank").state == rank_before, "raising a Herald moved the rank stream")
	for n: int in [1, 2, 5, 12, 40]:
		_check(Heralds.reinforced(n) > n and Heralds.reinforced(n) <= n + ceili(float(n) * 0.5) + 1,
			"a call reinforces %d bodies a road to %d" % [n, Heralds.reinforced(n)])
	var bounty: Dictionary = Heralds.bounty(Balance.HERALD_FIRST_ACT)
	var total: int = 0
	for id: Variant in bounty:
		total += int(bounty[id])
	_check(int(bounty.get(RunState.GOLD, 0)) > 0, "a Herald's purse carries Gold")
	_check(absf(float(total) - float(Balance.HERALD_BOUNTY) * Balance.kill_act_scale(
		Balance.HERALD_FIRST_ACT)) <= 4.0, "a Herald's purse is its authored size, found %d" % total)
	RunState.act = act_was
	_reached.append("roll")


## The next wave after a call is larger, and only the next one: the same wave
## is dealt twice from the same dice, once owed and once not.
func _test_the_call_reinforces() -> void:
	var director: WaveDirector = _field.wave_director
	var archetype: WaveArchetypeData = null
	var ids: Array = ContentDB.wave_archetypes.keys()
	ids.sort()
	for id: Variant in ids:
		var candidate: WaveArchetypeData = ContentDB.wave_archetypes[id] as WaveArchetypeData
		if candidate != null and not candidate.calm and not candidate.delayed_adjacent_surge:
			archetype = candidate
			break
	_check(archetype != null, "the harness needs an ordinary formation")
	if archetype == null:
		_reached.append("reinforce")
		return
	var lanes: Array[int] = [0]
	var waves_state: int = RunState.rng("waves").state
	var wave_was: int = RunState.wave_number
	var act_wave: int = int(director.get("_act_wave"))
	var sizes: Array[int] = []
	for owed: bool in [false, true]:
		RunState.rng("waves").state = waves_state
		RunState.wave_number = wave_was
		director.set("_act_wave", act_wave)
		director.set("_wave_active", false)
		director.set("_spawn_queue", [] as Array[Dictionary])
		director.set("_preview_archetype", archetype)
		director.set("_preview_lanes", lanes.duplicate())
		director.set("_herald_owed", owed)
		director.call("_begin_wave")
		var bodies: int = 0
		for entry: Dictionary in director.get("_spawn_queue"):
			if not entry.has("delay"):
				bodies += 1
		sizes.append(bodies)
		_check(not director.herald_owed(), "a call is spent by the wave it reinforces")
	_check(sizes[1] > sizes[0], "a wave after a call must be larger: %d against %d" % [sizes[1], sizes[0]])
	director.set("_wave_active", false)
	director.set("_spawn_queue", [] as Array[Dictionary])
	RunState.wave_number = wave_was
	director.set("_act_wave", act_wave)
	_reached.append("reinforce")


## A real tower firing for real, at a body standing beside a Herald.
func _test_the_board_looks_away() -> void:
	await _clear_bodies()
	var breed: EnemyData = _runner()
	_check(breed != null, "the harness needs a breed of the region that runs")
	if breed == null:
		_reached.append("board")
		return
	var tower_data: TowerData = null
	var ids: Array = ContentDB.towers.keys()
	ids.sort()
	for id: Variant in ids:
		var data: TowerData = ContentDB.towers[id] as TowerData
		if data != null and data.damage > 0.0 and data.aoe_at(1) > 0.0 \
				and not data.is_support() and not data.is_well():
			tower_data = data
			break
	RunState.set_phase(RunState.Phase.PREPARATION)
	var anchor: Vector2i = _field.free_anchor_near(0, 8)
	var problem: String = _field.try_build(anchor, tower_data)
	_check(problem.is_empty(), "the harness must build %s (%s)" % [tower_data.id if tower_data != null else "?", problem])
	await get_tree().process_frame
	var tower: Tower = _field.tower_at_anchor(anchor)
	if tower == null:
		_reached.append("board")
		return
	var spot: Vector2 = tower.origin() + Vector2(tower.effective_range() * 0.6, 0.0)
	var mark: Enemy = _stand(breed, spot, false)
	var herald: Enemy = _stand(breed, spot + Vector2(0.0, 40.0), true)
	_check(herald.is_herald() and herald.is_uncalled_herald(), "make_herald makes a Herald that has not called")
	_check(herald.hidden_from_the_board(), "the board may not see a Herald that has not called")
	_check(not mark.hidden_from_the_board(), "the board sees an ordinary body")
	_check(herald.promoted_name().begins_with("Herald"), "a Herald is named one, found '%s'" % herald.promoted_name())
	_check(_rose >= 1, "a Herald rising is said")
	await get_tree().process_frame
	var chosen: Array = tower.call("_acquire_targets_now")
	_check(not chosen.has(herald), "a tower may not choose a Herald that has not called")
	_check(chosen.has(mark), "a tower chooses the ordinary body beside it")

	# The funnel: a tower's blow and a trap's blow are refused, a Warden's lands.
	var whole: float = herald.health.current_hp
	DamageLedger.credit_as(DamageLedger.TOWER_PREFIX + tower_data.id)
	herald.take_damage(50.0, tower.origin(), 0.0)
	DamageLedger.credit_as(DamageLedger.TRAP_PREFIX + "caltrops")
	herald.take_damage(50.0, tower.origin(), 0.0)
	_check(is_equal_approx(herald.health.current_hp, whole), "a tower's or a trap's blow reached a Herald")
	_check(herald.glances_tower_shots(), "a tower's shot glances off a Herald, status and all")

	# The Arsenals: the board's looks away, the Warden's does not.
	var board: Arsenal = _field.board_arsenal()
	if board != null:
		_check(not board.bodies().has(herald), "the board's Arsenal may not reach a Herald")
		_check(board.bodies().has(mark), "the board's Arsenal reaches an ordinary body")
	var own: Arsenal = _field.hero.arsenal
	if own != null:
		_check(own.bodies().has(herald), "the Warden's Arsenal reaches a Herald")

	# A tower's ground does not burn it.
	_field.effect_root.process_mode = Node.PROCESS_MODE_INHERIT
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.effect_root.process_mode = Node.PROCESS_MODE_INHERIT
	_field.spawn_ground_zone(herald.global_position, 400.0, 1.0, 120.0)
	var mark_before: float = mark.health.current_hp
	# And the tower itself, firing for real at the body beside it, with its
	# splash reaching the Herald.
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	_check(mark.health.current_hp < mark_before, "the tower must fire on the ordinary body (%.0f -> %.0f)" % [mark_before, mark.health.current_hp])
	_check(is_equal_approx(herald.health.current_hp, whole),
		"the board touched a Herald that had not called: %.0f of %.0f left" % [herald.health.current_hp, whole])

	# The Warden's blow lands.
	DamageLedger.credit_as(DamageLedger.WARDEN)
	herald.take_damage(40.0, _field.hero.global_position, 0.0, true)
	_check(herald.health.current_hp < whole, "a Warden's blow must reach a Herald")
	RunState.set_phase(RunState.Phase.PREPARATION)
	await _clear_bodies()
	_reached.append("board")


func _loot_near(at: Vector2) -> Dictionary:
	var out: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		var piece := node as LootDrop
		if piece == null or not piece.visible or piece.global_position.distance_to(at) > 500.0:
			continue
		out[piece.currency] = int(out.get(piece.currency, 0)) + piece.amount
	return out


## Run down before the wall, the purse; after its call, none.
func _test_the_bounty() -> void:
	var breed: EnemyData = _runner()
	if breed == null:
		_reached.append("bounty")
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	var spot: Vector2 = _field.town_position() + Vector2(0.0, 1400.0)
	var herald: Enemy = _stand(breed, spot, true)
	await get_tree().process_frame
	var fell_before: int = _fell
	DamageLedger.credit_as(DamageLedger.WARDEN)
	herald.take_damage(herald.health.current_hp * 10.0, _field.hero.global_position, 0.0, true)
	for _f: int in 4:
		await get_tree().process_frame
	_check(_fell == fell_before + 1, "a Herald run down before the wall must say so once")
	var paid: Dictionary = _loot_near(spot)
	var owed: Dictionary = Heralds.bounty(RunState.act)
	for id: Variant in owed:
		_check(int(paid.get(id, 0)) >= int(owed[id]),
			"a Herald's purse owed %d %s and left %d" % [int(owed[id]), String(id), int(paid.get(id, 0))])
	await _clear_bodies()

	# After the call: no bounty.
	var called: Enemy = _stand(breed, spot, true)
	called.call("_sound_the_call")
	_check(not called.is_uncalled_herald() and not called.hidden_from_the_board(),
		"a Herald that has called is the board's to shoot")
	fell_before = _fell
	DamageLedger.credit_as(DamageLedger.WARDEN)
	called.take_damage(called.health.current_hp * 10.0, _field.hero.global_position, 0.0, true)
	for _f: int in 4:
		await get_tree().process_frame
	_check(_fell == fell_before, "a Herald killed after its call paid a bounty")
	RunState.set_phase(RunState.Phase.PREPARATION)
	_field.wave_director.set("_herald_owed", false)
	await _clear_bodies()
	_reached.append("bounty")


## Left to walk, a Herald reaches the wall and calls, on the real tick.
func _test_the_call() -> void:
	var breed: EnemyData = _runner()
	if breed == null:
		_reached.append("call")
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	var herald: Enemy = _field.spawn_enemy(breed, 0, 60.0, -1.0, 1.0)
	herald.global_position = herald.route_point_at(0.9)
	herald.make_herald()
	var called_before: int = _called
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 45000 and _called == called_before:
		await get_tree().process_frame
	_check(_called == called_before + 1, "a Herald left to walk must reach the wall and call, once (%.0f from the town)"
		% herald.global_position.distance_to(_field.town_position()))
	_check(not herald.is_uncalled_herald(), "a Herald that called is no longer hidden")
	_check(_field.wave_director.herald_owed(), "a call must owe the next wave its reinforcement")
	var further: int = 0
	start = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1500:
		await get_tree().process_frame
	further = _called - called_before
	_check(further == 1, "a Herald calls once, found %d" % further)
	_field.wave_director.set("_herald_owed", false)
	RunState.set_phase(RunState.Phase.PREPARATION)
	await _clear_bodies()
	_reached.append("call")


## The edge of the screen points at a Herald until it calls.
func _test_the_arrow() -> void:
	var breed: EnemyData = _runner()
	if breed == null:
		_reached.append("arrow")
		return
	var pointers := ThreatPointers.new()
	pointers.field = _field
	add_child(pointers)
	var herald: Enemy = _stand(breed, _field.town_position() + Vector2(1800.0, 0.0), true)
	await get_tree().process_frame
	pointers.call("_gather")
	var kinds: Array[int] = []
	for target: Dictionary in pointers.get("_targets"):
		if target["node"] == herald:
			kinds.append(int(target["kind"]))
	_check(kinds == [ThreatPointers.Kind.HERALD], "the edge points at a Herald, found kinds %s" % str(kinds))
	_check(Balance.THREAT_POINTER_COLOURS.size() > ThreatPointers.Kind.HERALD,
		"a Herald's arrow has a colour of its own")
	herald.call("_sound_the_call")
	pointers.call("_gather")
	var still: bool = false
	for target: Dictionary in pointers.get("_targets"):
		if target["node"] == herald:
			still = true
	_check(not still, "the edge stops pointing at a Herald once it has called")
	_field.wave_director.set("_herald_owed", false)
	pointers.queue_free()
	await _clear_bodies()
	_reached.append("arrow")


## Omissions a driven test cannot see: a door that stops asking.
func _test_the_wiring() -> void:
	var trap: String = FileAccess.get_file_as_string("res://scenes/battlefield/trap.gd")
	_check(trap.count("is_uncalled_herald()") >= 2, "a trap must neither spring on nor bite a Herald")
	var zone: String = FileAccess.get_file_as_string("res://scripts/systems/ground_zone.gd")
	_check(zone.contains("is_uncalled_herald()"), "a tower's ground must not burn a Herald")
	var tower: String = FileAccess.get_file_as_string("res://scenes/battlefield/tower.gd")
	_check(tower.contains("hidden_from_the_board()"), "a tower asks what the board may not see")
	var heralds: String = FileAccess.get_file_as_string("res://scripts/systems/heralds.gd")
	_check(heralds.contains("Coop.is_networked()") and heralds.contains("RunState.walking"),
		"a Herald is solo only and never on the Walk")
	var director: String = FileAccess.get_file_as_string("res://scripts/systems/wave_director.gd")
	var body: String = director.get_slice("func _raise_a_herald", 1).get_slice("\nfunc ", 0)
	_check(not body.contains("_rng") and body.contains("RunState.rng(\"heralds\")"),
		"a Herald is rolled on its own stream and never the waves'")
	var hud: String = FileAccess.get_file_as_string("res://scenes/ui/hud.gd")
	for line: String in ["ROSE_LINE", "CALLED_LINE", "FELL_LINE"]:
		_check(hud.contains("Heralds." + line), "the HUD says %s" % line)
	_reached.append("wiring")
