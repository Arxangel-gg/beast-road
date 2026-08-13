extends Node

var _failures: PackedStringArray = []
var _run: Run


func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	_run = load("res://scenes/run/run.tscn").instantiate() as Run
	add_child(_run)
	await get_tree().process_frame
	RunState.gain_currency(RunState.GOLD, 9999)
	RunState.gain_currency(RunState.WOOD, 9999)

	for data: TowerData in ContentDB.base_towers():
		_check(data.max_hp > 0.0, "%s has no structure durability" % data.id)

	var tower_data: TowerData = ContentDB.tower("ember_spire")
	_check(_run.battlefield.try_build(0, 0, tower_data).is_empty(),
		"test tower could not be built")
	await get_tree().process_frame
	var built_slot: TowerSlot = _run.battlefield.slot_at(0, 0)
	var tower: Tower = built_slot.tower()
	var health: Health = Health.of(tower)
	_check(health != null and health.max_hp > 0.0,
		"ordinary towers must expose Health")
	_check(tower.get("_damage_flames").size() >= 2,
		"tower silhouette did not produce smart damage-fire anchors")

	health.take_damage(health.max_hp * 0.58, Vector2.ZERO)
	await get_tree().process_frame
	_check(tower.needs_repair(), "damaged tower did not become repairable")
	var burning: int = 0
	for flame: Flame in tower.get("_damage_flames"):
		if flame.is_lit():
			burning += 1
	_check(burning >= 2, "heavily damaged tower did not ignite staged damage fires")
	var before: float = health.current_hp
	_check(_run.battlefield.try_repair_tower(0, 0).is_empty() \
			and health.current_hp > before,
		"Preparation repair did not restore tower durability")

	var burrower: Enemy = _run.battlefield.spawn_enemy(ContentDB.enemy("burrower"), 0, 1.0)
	await get_tree().process_frame
	_check(burrower._pick_target() == tower,
		"tower-targeting enemy did not prefer the structure in its lane")

	# A support-foot plant is one authored event shared by camera, hero, enemies
	# and structures. Test its physical recipients here; CameraRig owns its
	# deterministic timing assertion in balance_test.
	EventBus.beast_step_landed.emit(Vector2(14.0, 5.0), 1.0)
	_check((_run.battlefield.hero.get("_beast_impulse") as Vector2).length() > 0.0,
		"beast step did not nudge the hero")
	_check((burrower.get("_knockback") as Vector2).length() > 0.0,
		"beast step did not disturb enemies")
	_check(absf(float(tower.get("_step_wobble"))) > 0.0,
		"beast step did not wobble towers")

	if _failures.is_empty():
		print("[structure] PASS — durability, repair, siege targeting, damage fires and step impulse")
	else:
		for failure: String in _failures:
			push_error("[structure] " + failure)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)
