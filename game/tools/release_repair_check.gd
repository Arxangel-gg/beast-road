extends Node

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 7192026)
	_test_patterns()
	_test_slots()
	var run := (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for frame: int in 12:
		await get_tree().process_frame
	run.process_mode = Node.PROCESS_MODE_DISABLED
	var field: Battlefield = run.battlefield
	var hero: Hero = field.hero
	var bounds: Rect2 = field.city_bounds()
	for point: Vector2 in [bounds.get_center(), bounds.position + Vector2.ONE,
			bounds.end - Vector2.ONE]:
		hero.global_position = point
		hero.health.revive()
		var before: float = hero.health.current_hp
		_check(not hero.health.take_damage(100000.0, point), "base admitted direct damage")
		hero.health.kill(point)
		_check(not hero.health.is_dead and hero.health.current_hp == before,
			"base admitted forced death")
		hero.health.set("_deferred", 100000.0)
		_check(hero.health.settle_deferred() == 0.0 and not hero.health.is_dead,
			"base admitted deferred damage")
	var outer: Vector2 = bounds.end + Vector2(180.0, 180.0)
	hero.global_position = outer
	_check(hero.health.take_damage(1.0, outer), "sanctuary leaked outside the base")
	var enemy: Enemy = field.spawn_enemy(ContentDB.enemies.values()[0] as EnemyData, 0, 1.0)
	if enemy != null:
		enemy.global_position = bounds.get_center()
		enemy.call("_process", 0.01)
		_check(not bounds.has_point(enemy.global_position), "enemy stayed inside the base")
		_check(not bounds.intersects(enemy.sprite.global_transform * enemy.sprite.get_rect()),
			"enemy artwork overlaps the base despite legal feet")
		_check(bool(enemy.call("_in_reach", field.town)), "excluded enemy cannot attack the city edge")
		hero.global_position = bounds.get_center()
		_check(not bool(enemy.call("_foe_stands", hero)), "enemy can target a sheltered hero")
	var wildlife: Wildlife = field.wildlife()
	if wildlife != null:
		var kind: WildlifeData = null
		for candidate: WildlifeData in ContentDB.wildlife():
			if candidate != null and not candidate.mythic and not candidate.is_hostile():
				kind = candidate
				break
		var animal: Dictionary = wildlife.spawn_born(kind, outer,
			{"stage": WildlifeFamilies.Stage.ADULT}) if kind != null else {}
		_check(not animal.is_empty(), "wildlife clearance probe could not spawn")
		if not animal.is_empty():
			var body := animal["sprite"] as Node2D
			body.global_position = bounds.get_center()
			wildlife.call("_walk_step", body, Vector2.ZERO)
			_check(not bounds.has_point(body.global_position), "idle wildlife stayed inside the base")
			var animal_visual := body as Sprite2D
			_check(not bounds.intersects(animal_visual.global_transform * animal_visual.get_rect()),
				"wildlife artwork overlaps the base despite legal feet")
			_check(not bounds.has_point(animal["goal"] as Vector2), "wildlife kept a goal inside the base")

	_test_hazard(field, hero, outer)
	_test_dragon(field)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for frame: int in 8:
		await get_tree().process_frame
	MetaState.resume_saves()
	print("[release-repair] %s - %d checks, %d failures" % [
		"PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_patterns() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 821
	var low: Array[int] = [0, 0, 0]
	var high: Array[int] = [0, 0, 0]
	for index: int in 10000:
		low[WeatherSky.earth_patterns(random, 0.0).size() - 1] += 1
		high[WeatherSky.earth_patterns(random, Balance.WRATH_CAP).size() - 1] += 1
	_check(low[0] > low[1] and low[1] > low[2] and low[2] > 0,
		"earth patterns do not favor single, then double, then triple events")
	_check(high[1] > low[1] and high[2] > low[2], "wrath does not increase combinations")
	_check(high[0] > high[1] and high[1] > high[2], "high wrath makes combinations too common")


func _test_slots() -> void:
	MetaState.stash.clear()
	MetaState.equipped.clear()
	var seen: Dictionary = {}
	for value: Variant in ContentDB.gear_kinds.values():
		var kind := value as GearData
		if kind == null or seen.has(kind.slot):
			continue
		seen[kind.slot] = true
		MetaState.equipped[kind.slot] = MetaState.stash.size()
		MetaState.stash.append(Stash.make(kind.id, 1, 1))
	for slot: Variant in MetaState.equipped:
		var piece: Dictionary = MetaState.equipped_piece(int(slot))
		_check(ContentDB.gear(String(piece["kind"])).slot == int(slot), "comparison selected the wrong slot")
	var slots: Array = MetaState.equipped.keys()
	if slots.size() >= 2:
		var first: int = int(MetaState.equipped[slots[0]])
		MetaState.equipped[slots[0]] = MetaState.equipped[slots[1]]
		MetaState.equipped[slots[1]] = first
		var recovered: Dictionary = MetaState.equipped_piece(int(slots[0]))
		_check(ContentDB.gear(String(recovered["kind"])).slot == int(slots[0]),
			"legacy shuffled equipment displayed another slot")


func _test_hazard(field: Battlefield, hero: Hero, at: Vector2) -> void:
	hero.global_position = at
	hero.health.revive()
	var plan: Dictionary = {"mode": "trail", "from": at - Vector2(100, 0),
		"to": at + Vector2(100, 0), "width": 24.0, "warning": 1.0,
		"travel": 2.0, "share": 0.1, "tower_damage": 0.0,
		"tint": Color.ORANGE, "blame": "earthquake"}
	var hazard := GroundHazard.new()
	hazard.plan = plan
	hazard.field = field
	field.add_child(hazard)
	var before: float = hero.health.current_hp
	hazard.call("_process", 0.5)
	_check(hero.health.current_hp == before, "hazard dealt damage before its warning ended")
	for frame: int in 25:
		hazard.call("_process", 0.1)
	_check(is_equal_approx(before - hero.health.current_hp, hero.health.max_hp * 0.1),
		"traveling ground hazard tunneled past or repeatedly damaged the hero")
	hazard.queue_free()


func _test_dragon(field: Battlefield) -> void:
	var dragon: DragonPass = field.sky().send_dragon(Vector2(-1800, 800), Vector2(1800, 800))
	_check(dragon != null, "dragon event could not spawn")
	if dragon == null:
		return
	dragon.set("_will_land", true)
	dragon.advance(Balance.DRAGON_WARNING_SECONDS + Balance.DRAGON_PASS_SECONDS * 0.55, 120)
	_check(bool(dragon.get("_landed")), "dragon never entered its landing state")
	_check(not field.inside_city(dragon.global_position), "dragon landed inside the city")
	dragon.advance(Balance.DRAGON_LAND_SECONDS + Balance.DRAGON_PASS_SECONDS, 120)
	_check(dragon.is_queued_for_deletion(), "dragon failed to depart after landing")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("[release-repair] " + message)
