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
	# **Every breed, not whichever one the dictionary happens to hand over
	# first.** The first cut took `values()[0]` and asserted it could still
	# reach the wall - and passed only because that breed was a ranged one with
	# 210 units of reach. Every melee breed in the game was standing 136 units
	# out and swinging at nothing, which is the fault the owner photographed.
	# A guarantee is a property of every breed or it is not a guarantee.
	var shortest: float = 0.0
	var narrowest: String = ""
	var probed: int = 0
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null:
			continue
		var enemy: Enemy = field.spawn_enemy(breed, 0, 1.0)
		if enemy == null:
			continue
		probed += 1
		# Dropped on the middle of the base, which is the one position no body
		# may hold: it is the repair, not the walk, that is being measured.
		enemy.global_position = bounds.get_center()
		enemy.call("_process", 0.01)
		_check(not bounds.has_point(enemy.global_position),
			"%s stayed inside the base" % breed.id)
		# **The feet, never the painting.** The owner's rule of 2026-09-20 is
		# that a body walks up to the point of colliding with the base's sprite
		# and deflects off it, so its art may overlap the base exactly as a
		# soldier standing at a wall overlaps the wall. Holding the *sprite*
		# clear instead is what pushed every breed out beyond its own arm.
		_check(not bounds.grow(enemy.contact_radius() * 0.5).has_point(
			enemy.global_position),
			"%s put its feet inside the base" % breed.id)
		# And the whole point of standing there: it can hit what it came for.
		var gap: float = float(enemy.call("_target_gap", field.town))
		var reach: float = enemy.attack_reach()
		if narrowest == "" or reach - gap < shortest:
			shortest = reach - gap
			narrowest = "%s (gap %0.1f, reach %0.1f)" % [breed.id, gap, reach]
		_check(bool(enemy.call("_in_reach", field.town)),
			"%s is turned away further than it can swing: gap %0.1f against a reach of %0.1f"
				% [breed.id, gap, reach])
		enemy.queue_free()
	_check(probed > 20, "the harness must walk the roster (%d breeds)" % probed)
	print("[release-repair] tightest breed at the wall: %s" % narrowest)
	var lone: Enemy = field.spawn_enemy(ContentDB.enemies.values()[0] as EnemyData, 0, 1.0)
	if lone != null:
		lone.global_position = bounds.get_center()
		lone.call("_process", 0.01)
		hero.global_position = bounds.get_center()
		_check(not bool(lone.call("_foe_stands", hero)), "enemy can target a sheltered hero")
		lone.queue_free()
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
		MetaState.stash.append(Stash.make(kind.id, 1, 1))
		MetaState.equip(kind.slot, MetaState.stash.size() - 1)
	for slot: Variant in MetaState.equipped:
		var piece: Dictionary = MetaState.equipped_piece(int(slot))
		_check(ContentDB.gear(String(piece["kind"])).slot == int(slot), "comparison selected the wrong slot")
	var slots: Array = MetaState.equipped.keys()
	if slots.size() >= 2:
		var first: Variant = MetaState.equipped[slots[0]]
		MetaState.equipped[slots[0]] = MetaState.equipped[slots[1]]
		MetaState.equipped[slots[1]] = first
		# **A slot holding another slot's piece shows nothing rather than a
		# stranger**, and that is an amendment recorded rather than quiet.
		# Before 2026-09-22 `equipped` held stash *positions* and
		# `equipped_piece` searched the other worn entries for something of the
		# right kind, so a scrambled map recovered and this asked that it did.
		# Keyed by uid it refuses instead, which answers the same question -
		# "can a scrambled map dress the Warden in the wrong slot's gear" -
		# more strongly than recovery ever did.
		_check(MetaState.equipped_piece(int(slots[0])).is_empty(),
			"a slot holding another slot's piece must show nothing at all")


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
