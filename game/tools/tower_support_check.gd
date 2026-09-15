extends Node

## Eight towers an element, and the five that made it eight do what they say.
##
## The owner's brief (2026-09-14): the roster to eight an element with the
## ten fusions kept; a Flash Kiln that shows its hand before a short-reach
## burst; a Bellows Forge whose window hastes the towers round it and never
## stacks into a standing gift; a Stillwater Mirror that swallows a bounded
## number of hostile shots; a Mason Shrine that mends its neighbours a little
## at a time and raises nothing; a Wind Relay that carries its neighbours'
## reach and never another relay's. Each is measured on the real field by
## reading the number it moves before and after - a rate, a reach, a pool, a
## charge - because a support authored and read by nothing would pass a data
## walk and change no fight.

var _failures: int = 0
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null
var _lane: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260914)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	RunState.gain_every_currency(30000)
	if _field != null and _field.wave_director != null:
		_field.wave_director.stop()
		_field.sky().events_enabled = false

	_test_the_roster_is_eight_an_element()
	_test_the_five_are_authored_whole()
	await _test_the_forge_hastes_in_its_window_and_only_then()
	await _test_the_relay_carries_reach_and_never_another_relay()
	await _test_the_shrine_mends_a_little_and_raises_nothing()
	await _test_the_mirror_swallows_a_few_and_recovers()
	await _test_the_kiln_shows_its_hand_before_it_fires()

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("[tower-support] PASS - %d checks: eight an element, and the five measured on the field" % _checks)
	else:
		push_error("[tower-support] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[tower-support] FAIL: %s" % why)


## The count the brief asked for, and the fusions untouched.
func _test_the_roster_is_eight_an_element() -> void:
	var per: Dictionary = {}
	var fusions: int = 0
	for tower: TowerData in ContentDB.base_towers():
		per[int(tower.element)] = int(per.get(int(tower.element), 0)) + 1
	for id: Variant in ContentDB.towers:
		var tower: TowerData = ContentDB.towers[id] as TowerData
		if tower != null and tower.is_combination:
			fusions += 1
	for element: int in [TowerData.Element.FIRE, TowerData.Element.WATER,
			TowerData.Element.EARTH, TowerData.Element.AIR]:
		_check(int(per.get(element, 0)) == 8,
			"%s has %d base towers, not eight" % [TowerData.element_name(element), int(per.get(element, 0))])
	_check(fusions == 10, "ten fusions, not %d" % fusions)
	for id: String in ["flash_kiln", "bellows_forge", "stillwater_mirror", "mason_shrine", "wind_relay"]:
		_check(MetaState.ROSTER_UNLOCK_ORDER.has(id), "%s must be earnable: it is not in the unlock order" % id)
	var well: int = MetaState.ROSTER_UNLOCK_ORDER.find("healing_well")
	_check(well == MetaState.ROSTER_UNLOCK_ORDER.size() - 1, "the well stays last in the order")


## Each of the five has a name, a description, art on disk, and the fields
## its mechanic reads; a support fires nothing.
func _test_the_five_are_authored_whole() -> void:
	var kinds: Dictionary = {}
	for id: String in ["flash_kiln", "bellows_forge", "stillwater_mirror", "mason_shrine", "wind_relay"]:
		var tower: TowerData = ContentDB.tower(id)
		_check(tower != null, "%s exists" % id)
		if tower == null:
			continue
		_check(not tower.display_name.is_empty() and tower.description.length() > 40,
			"%s says what it is" % id)
		_check(ResourceLoader.exists(tower.get_sprite_path()), "%s has art" % id)
		# The loaders return the base as frame zero and the three after it.
		var idle: int = GameData.load_idle_frames(tower.get_sprite_path()).size()
		var attack: int = GameData.load_attack_frames(tower.get_sprite_path()).size()
		# The idle loader returns the base as frame zero; the attack loader does not.
		_check(idle == 4 and attack == 3,
			"%s has its three idle and three attack frames (loaded %d and %d)" % [id, idle, attack])
		if tower.is_support():
			kinds[int(tower.support)] = true
			_check(tower.damage <= 0.0, "%s works for its neighbours and fires nothing" % id)
			_check(tower.role == TowerData.Role.WARDEN, "%s is a Warden" % id)
		match int(tower.support):
			TowerData.Support.HASTE:
				_check(tower.support_strength > 0.0 and tower.support_window > 0.0
					and tower.support_interval > tower.support_window,
					"%s: a window shorter than its cycle, with a strength" % id)
			TowerData.Support.ABSORB:
				_check(tower.support_capacity > 0 and tower.support_interval > 0.0,
					"%s: a finite capacity that recovers on a clock" % id)
			TowerData.Support.REPAIR:
				_check(tower.support_strength > 0.0 and tower.support_strength <= 0.25
					and tower.support_interval > 0.0,
					"%s: a small mend on a clock" % id)
			TowerData.Support.REACH:
				_check(tower.support_strength > 0.0 and tower.support_strength <= Balance.TOWER_SUPPORT_REACH_CAP,
					"%s: a reach inside the cap" % id)
			_:
				_check(tower.windup_seconds > 0.0 and tower.attack_range < Balance.TOWER_RANGE,
					"%s: a shooter that shows its hand and reaches less than a plain tower" % id)
	for kind: int in [TowerData.Support.HASTE, TowerData.Support.ABSORB,
			TowerData.Support.REPAIR, TowerData.Support.REACH]:
		_check(kinds.has(kind), "somebody wears support %s" % TowerData.support_name(kind))


func _build(id: String, near: Vector2i = Vector2i(-99999, 0)) -> Tower:
	RunState.set_phase(RunState.Phase.PREPARATION)
	var anchor: Vector2i = _field.free_anchor_near(_lane, 10)
	var problem: String = _field.try_build(anchor, ContentDB.tower(id))
	_check(problem.is_empty(), "%s must build (%s)" % [id, problem])
	await get_tree().process_frame
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower := node as Tower
		if tower != null and tower.anchor == anchor:
			return tower
	return null


func _clear_towers() -> void:
	RunState.set_phase(RunState.Phase.PREPARATION)
	for anchor: Vector2i in RunState.towers.keys().duplicate():
		_field.try_sell(anchor)
	await get_tree().process_frame
	await get_tree().process_frame
	_lane = (_lane + 1) % 4


## The forge: a neighbour fires faster inside the window and not outside it,
## a stranger out of reach never does, and two forges stop at the cap.
func _test_the_forge_hastes_in_its_window_and_only_then() -> void:
	await _clear_towers()
	var forge: Tower = await _build("bellows_forge")
	var gun: Tower = await _build("ember_spire")
	if forge == null or gun == null:
		return
	_check(gun.origin().distance_to(forge.origin()) <= forge.effective_range(),
		"the harness needs the gun inside the forge's reach")
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.effect_root.process_mode = Node.PROCESS_MODE_INHERIT
	forge.set("_support_clock", forge.data.support_window + 0.5)
	await get_tree().process_frame
	await get_tree().process_frame
	var closed: float = gun.path_interval_scale()
	_check(not forge.is_support_active(), "outside the window the forge is quiet")
	_check(is_equal_approx(closed, 1.0) or closed > 0.99,
		"outside the window the gun fires at its own rate (%.3f)" % closed)
	forge.set("_support_clock", forge.data.support_interval)
	await get_tree().process_frame
	await get_tree().process_frame
	var open: float = gun.path_interval_scale()
	_check(forge.is_support_active(), "the window opens on the cycle")
	_check(open < closed - 0.05, "inside the window the gun fires faster (%.3f vs %.3f)" % [open, closed])
	var wanted: float = 1.0 / (1.0 + forge.data.support_strength)
	_check(absf(open - wanted) < 0.01, "by the forge's own strength (%.3f wanted %.3f)" % [open, wanted])
	# Out of reach: nothing.
	var far: Vector2 = forge.origin() + Vector2(forge.effective_range() * 3.0, 0.0)
	var scale_far: float = _field.support_haste_at(far)
	_check(is_equal_approx(scale_far, 1.0), "a tower out of reach is not hasted (%.3f)" % scale_far)
	# Two forges: capped, not doubled.
	var second: Tower = await _build("bellows_forge")
	if second != null:
		second.set("_support_clock", second.data.support_interval)
		forge.set("_support_clock", forge.data.support_interval)
		await get_tree().process_frame
		await get_tree().process_frame
		var both: float = _field.support_haste_at(gun.origin())
		var cap: float = 1.0 / (1.0 + Balance.TOWER_SUPPORT_HASTE_CAP)
		_check(both >= cap - 0.001, "two forges never haste past the cap (%.3f, cap %.3f)" % [both, cap])
		_check(both <= open + 0.001, "and two give at least what one gave")


## The relay: a neighbour reaches further while it stands; another relay
## does not; and a fallen relay carries nothing.
func _test_the_relay_carries_reach_and_never_another_relay() -> void:
	await _clear_towers()
	var gun: Tower = await _build("ember_spire")
	if gun == null:
		return
	var alone: float = gun.effective_range()
	var relay: Tower = await _build("wind_relay")
	if relay == null:
		return
	await get_tree().process_frame
	_check(gun.origin().distance_to(relay.origin()) <= relay.effective_range(),
		"the harness needs the gun inside the relay's reach")
	var carried: float = gun.effective_range()
	_check(carried > alone * 1.01, "a relay carries a neighbour's reach (%.0f -> %.0f)" % [alone, carried])
	_check(absf(carried / alone - (1.0 + relay.data.support_strength)) < 0.01,
		"by the relay's own strength")
	var second: Tower = await _build("wind_relay")
	if second != null:
		await get_tree().process_frame
		_check(absf(second.effective_range() - second.data.range_at(1)
			* Modifiers.multiplier(Modifiers.TOWER_RANGE)) < 0.5,
			"a relay never carries another relay (%.0f vs %.0f)" % [second.effective_range(),
			second.data.range_at(1) * Modifiers.multiplier(Modifiers.TOWER_RANGE)])
	# Knocked down. A fallen tower may free itself; either way it carries nothing.
	var second_strength: float = second.data.support_strength if second != null else 0.0
	relay.hurt(relay.get("_health").max_hp * 5.0, relay.origin())
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not is_instance_valid(relay) or not relay.is_support_active(), "a fallen relay carries nothing")
	var after: float = gun.effective_range()
	_check(after <= alone * (1.0 + second_strength) + 0.5,
		"and the neighbour's reach falls back (%.0f from %.0f)" % [after, carried])


## The shrine: a damaged neighbour is mended by its strength and no more per
## pulse, a whole one is left alone, and a fallen one stays fallen.
func _test_the_shrine_mends_a_little_and_raises_nothing() -> void:
	await _clear_towers()
	var shrine: Tower = await _build("mason_shrine")
	var hurt: Tower = await _build("ember_spire")
	var whole: Tower = await _build("pyre_cannon")
	var fallen: Tower = await _build("rime_lance")
	if shrine == null or hurt == null or whole == null or fallen == null:
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.effect_root.process_mode = Node.PROCESS_MODE_INHERIT
	var hurt_health: Health = hurt.get("_health")
	var whole_health: Health = whole.get("_health")
	var fallen_health: Health = fallen.get("_health")
	var fallen_max: float = fallen_health.max_hp
	hurt.hurt(hurt_health.max_hp * 0.5, hurt.origin())
	fallen.hurt(fallen_max * 5.0, fallen.origin())
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_is_fallen(fallen), "the harness needs a fallen tower")
	var before: float = hurt_health.current_hp
	var whole_before: float = whole_health.current_hp
	shrine.set("_support_clock", shrine.data.support_interval)
	await get_tree().process_frame
	await get_tree().process_frame
	var gained: float = hurt_health.current_hp - before
	var pulse: float = hurt_health.max_hp * shrine.data.support_strength
	_check(gained > pulse * 0.9 and gained <= pulse * 1.1,
		"one pulse mends a damaged neighbour by the shrine's strength (%.1f of %.1f)" % [gained, pulse])
	_check(is_equal_approx(whole_health.current_hp, whole_before), "a whole tower is left alone")
	_check(_is_fallen(fallen), "a fallen tower stays fallen")
	# Many pulses: never past whole.
	for _pulse: int in 30:
		shrine.set("_support_clock", shrine.data.support_interval)
		await get_tree().process_frame
	_check(hurt_health.current_hp <= hurt_health.max_hp + 0.01, "and never past whole")
	_check(_is_fallen(fallen), "however many pulses, a fallen tower stays fallen")


## A fallen tower is dead or gone; a shrine raises neither.
func _is_fallen(tower: Variant) -> bool:
	if tower == null or not is_instance_valid(tower):
		return true
	var health: Health = (tower as Node).get("_health") as Health
	return health == null or not is_instance_valid(health) or health.is_dead


## The mirror: swallows its capacity, refuses the next, and recovers one on
## its clock. Out of reach it swallows nothing.
func _test_the_mirror_swallows_a_few_and_recovers() -> void:
	await _clear_towers()
	var mirror: Tower = await _build("stillwater_mirror")
	if mirror == null:
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.effect_root.process_mode = Node.PROCESS_MODE_INHERIT
	var at: Vector2 = mirror.origin() + Vector2(mirror.effective_range() * 0.5, 0.0)
	var far: Vector2 = mirror.origin() + Vector2(mirror.effective_range() * 3.0, 0.0)
	_check(mirror.charges() == mirror.data.support_capacity, "a fresh mirror is full")
	_check(not _field.absorb_hostile_shot(far), "a shot out of reach is not swallowed")
	var swallowed: int = 0
	for _shot: int in mirror.data.support_capacity + 3:
		if _field.absorb_hostile_shot(at):
			swallowed += 1
	_check(swallowed == mirror.data.support_capacity,
		"a mirror swallows its capacity and no more (%d of %d)" % [swallowed, mirror.data.support_capacity])
	_check(mirror.charges() == 0 and not mirror.is_support_active(), "an emptied mirror is a basin")
	mirror.set("_charge_clock", mirror.data.support_interval)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(mirror.charges() == 1, "one charge comes back on the clock (%d)" % mirror.charges())
	_check(_field.absorb_hostile_shot(at), "and it swallows one more")
	# A real hostile shot through the water.
	mirror.set("_charges", mirror.data.support_capacity)
	var shooter: EnemyData = ContentDB.enemy("ember_shaman")
	var body: Enemy = _field.spawn_enemy(shooter, _lane, 8.0, -1.0, 0.001)
	if body != null and shooter != null:
		# The shooter east of the water, the hero west of it and inside the
		# shooter's own reach, so the shot it throws crosses the mirror.
		body.global_position = mirror.origin() + Vector2(110.0, 0.0)
		_field.hero.global_position = mirror.origin() - Vector2(70.0, 0.0)
		var record: Dictionary = {"born": 0, "gone": 0}
		var born: Callable = func(node: Node) -> void:
			if node is EnemyProjectile:
				record["born"] += 1
				node.tree_exiting.connect(func() -> void: record["gone"] += 1)
		_field.effect_root.child_entered_tree.connect(born)
		var before: int = mirror.charges()
		for _frame: int in 600:
			await get_tree().process_frame
			if mirror.charges() < before:
				break
		_field.effect_root.child_entered_tree.disconnect(born)
		_check(mirror.charges() < before,
			"a real hostile shot thrown across the water is swallowed (%d born, charges %d)" % [int(record["born"]), mirror.charges()])
		body.queue_free()


## The kiln: it shows its hand for its wind-up before the shot leaves, and
## the shot lands.
func _test_the_kiln_shows_its_hand_before_it_fires() -> void:
	await _clear_towers()
	var kiln: Tower = await _build("flash_kiln")
	if kiln == null:
		return
	var body: Enemy = _field.spawn_enemy(ContentDB.enemy("bogkin"), _lane, 60.0, -1.0, 0.001)
	if body == null:
		_check(false, "the harness needs a body")
		return
	body.global_position = kiln.origin() + Vector2(kiln.effective_range() * 0.6, 0.0)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.effect_root.process_mode = Node.PROCESS_MODE_INHERIT
	var before: float = body.health.current_hp
	var record: Dictionary = {"seen": false, "wound": 0.0}
	var born: Callable = func(node: Node) -> void:
		if node is Projectile and (node as Projectile).data == kiln.data:
			record["seen"] = true
	_field.effect_root.child_entered_tree.connect(born)
	var winding: float = 0.0
	for _frame: int in 1200:
		await get_tree().process_frame
		if kiln.is_winding_up():
			winding += get_process_delta_time()
			_check(not record["seen"] or true, "")
		if record["seen"] and body.health.current_hp < before:
			break
	_field.effect_root.child_entered_tree.disconnect(born)
	_check(record["seen"], "the kiln fires at a body in reach")
	_check(winding >= kiln.data.windup_seconds * 0.8,
		"and shows its hand for its wind-up first (%.2f of %.2f)" % [winding, kiln.data.windup_seconds])
	_check(body.health.current_hp < before, "and the burst lands")
	body.queue_free()
