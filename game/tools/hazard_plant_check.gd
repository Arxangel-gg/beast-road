extends Node

## **The harmful plants** (owner, 2026-10-07; `HazardPlants`, `HazardPlant`).
##
## Authored for every act and every behaviour, painted in every state they wear;
## laid on open outskirts ground on a real road for every act and never on the
## Walk; thorns cut what wades in, slow it through the ground's one door, and
## never take a body under the floor; a pod swells and bursts once and rests; a
## mound rears and bites; a bud opens, spits where a thing stands and closes when
## nothing is left; and a Warden can cut any of them down, after which it hurts
## nothing until it grows back.

const TAG: String = "[hazard]"

var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []
var _run: Run = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_data()
	RunState.reset(false, 20261008)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	for _f: int in 12:
		await get_tree().process_frame
	_field = _run.battlefield
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and not enemy.is_camp_mob():
			enemy.queue_free()
	var animals: Wildlife = _field.wildlife()
	if animals != null:
		animals.clear()
		animals.set("_hush_left", 1.0e9)
	await get_tree().process_frame
	_check(_field.hazards() != null, "the battlefield grows no harmful plants")
	if _field.hazards() != null:
		_test_the_lay()
		await _test_thorns()
		await _test_spores()
		await _test_a_snapper()
		await _test_a_spitter()
		await _test_cutting_one_down()
		await _test_what_wakes_a_plant()
		await _test_animals_keep_out_of_thorns()
	for stage: String in ["data", "lay", "thorns", "spores", "snapper", "spitter", "cut", "wakes", "berth"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	_run.queue_free()
	GameDirector.run_active = false
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: every act grows its own, every state is painted, laid on the outskirts and never on the Walk, thorns cut and slow and spare a body, a pod bursts once, a mound bites, a bud spits and closes, and a Warden cuts them down" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_the_data() -> void:
	var behaviours: Dictionary = {}
	for act: int in range(1, Balance.ACT_COUNT + 2):
		var pool: Array[HazardPlantData] = HazardPlants.pool_for(act)
		_check(pool.size() >= 2, "Act %d grows %d harmful plants" % [act, pool.size()])
	for id: String in ContentDB.hazard_plant_ids():
		var plant: HazardPlantData = ContentDB.hazard_plant(id)
		behaviours[plant.behaviour] = true
		_check(ResourceLoader.exists(plant.get_sprite_path()), "%s has no painting" % id)
		if plant.hides():
			_check(ResourceLoader.exists(plant.hidden_path()), "%s hides and has no hidden painting" % id)
		_check(plant.hero_share > 0.0 and plant.hero_share <= 0.2, "%s takes %.2f of a Warden's pool a blow" % [id, plant.hero_share])
		_check((plant.slow < 1.0) == (plant.behaviour == HazardPlantData.Behaviour.THORNS),
			"%s slows a mover and is not thorns, or is thorns and slows nothing" % id)
		if plant.behaviour == HazardPlantData.Behaviour.SPITTER:
			_check(plant.spit_range > plant.reach * 3.0, "%s spits no further than its own splash" % id)
		elif plant.hides():
			_check(plant.trigger > 0.0 and plant.telegraph > 0.2, "%s wakes on nothing or gives no tell" % id)
	_check(behaviours.size() == HazardPlantData.Behaviour.size(), "only %d of the four ways to hurt are grown" % behaviours.size())
	_reached.append("data")


## Laid on open outskirts ground, apart, on the real road, for every act.
func _test_the_lay() -> void:
	var hazards: HazardPlants = _field.hazards()
	var held_act: int = RunState.act
	for act: int in range(1, Balance.ACT_COUNT + 2):
		RunState.act = act
		hazards.scatter()
		var laid: Array[HazardPlant] = hazards.plants()
		var wanted: int = Balance.HAZARD_PER_ACT if act > 1 else Balance.HAZARD_PER_ACT_OPENING
		_check(laid.size() >= wanted * 3 / 4, "Act %d laid %d harmful plants of %d" % [act, laid.size(), wanted])
		for plant: HazardPlant in laid:
			var tile: Vector2i = BattleGrid.world_to_tile(plant.global_position)
			_check(_field.grid.cell_at(tile) == BattleGrid.Cell.OPEN, "a %s grows on a road, the town or a camp" % plant.data.id)
			_check(BattleGrid.beyond_core(plant.global_position), "a %s grows inside the core, on build ground" % plant.data.id)
			_check(plant.data.acts.has(act), "a %s grows in Act %d, which it does not list" % [plant.data.id, act])
			# The rule stated here, not read back off `clearance_for`: a check that
			# asks the function it checks agrees with it whatever it says.
			var keep: float = Balance.HAZARD_SPACING
			if plant.data.behaviour == HazardPlantData.Behaviour.SPITTER:
				keep = plant.data.spit_range + Balance.HAZARD_SPITTER_MARGIN
			for taken: Vector2 in hazards.avoid:
				_check(plant.global_position.distance_to(taken) >= keep - 30.0,
					"a %s grows %.0f from a place of work" % [plant.data.id, plant.global_position.distance_to(taken)])
			for other: HazardPlant in laid:
				if other != plant:
					_check(plant.global_position.distance_to(other.global_position) >= Balance.HAZARD_SPACING - 1.0,
						"two plants grow %.0f apart" % plant.global_position.distance_to(other.global_position))
	RunState.walking = true
	hazards.scatter()
	_check(hazards.plants().is_empty(), "the Walk grows harmful plants")
	RunState.walking = false
	RunState.act = held_act
	hazards.scatter()
	_reached.append("lay")


## Clear ground far from everything, for a plant the test lays itself.
func _quiet_ground() -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_gap: float = -1.0
	var animals: Wildlife = _field.wildlife()
	for _try: int in 80:
		var spot: Vector2 = animals.call("_clear_point") as Vector2 if animals != null else Vector2(2400.0, 2400.0)
		if spot == Vector2.ZERO:
			continue
		var gap: float = INF
		for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
			var body := node as Node2D
			if body != null and is_instance_valid(body):
				gap = minf(gap, spot.distance_to(body.global_position))
		for plant: HazardPlant in _field.hazards().plants():
			if is_instance_valid(plant):
				gap = minf(gap, spot.distance_to(plant.global_position))
		if gap > best_gap:
			best_gap = gap
			best = spot
	return best


func _plant(behaviour: int) -> HazardPlant:
	for id: String in ContentDB.hazard_plant_ids():
		var data: HazardPlantData = ContentDB.hazard_plant(id)
		if data.behaviour == behaviour:
			return _field.hazards().plant_at(data, _quiet_ground())
	_check(false, "no plant authored for behaviour %d" % behaviour)
	return null


func _whole_warden() -> Hero:
	var hero: Hero = _field.hero
	var pool: Health = Health.of(hero)
	pool.heal(pool.max_hp)
	pool.floor_hp = pool.max_hp * 0.3
	return hero


func _stand_a_body(at: Vector2) -> Enemy:
	var ids: Array = ContentDB.enemies.keys()
	ids.sort()
	for id: String in ids:
		var data := ContentDB.enemies[id] as EnemyData
		if data == null or data.category != EnemyData.Category.BREED or data.hide != EnemyData.Hide.FLESH:
			continue
		var body := (load("res://scenes/battlefield/enemy.tscn") as PackedScene).instantiate() as Enemy
		body.setup(data, RunState.act, _field, 1.0, 1.0, 1.0)
		_field.add_child(body)
		body.global_position = at
		body.set_process(false)
		body.set_physics_process(false)
		return body
	return null


func _wait(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		left -= get_process_delta_time()
		await get_tree().process_frame


func _test_thorns() -> void:
	var plant: HazardPlant = _plant(HazardPlantData.Behaviour.THORNS)
	if plant == null:
		return
	var at: Vector2 = plant.global_position
	_check(Vfx.ground_slow(at) < 1.0, "standing in thorns slows nothing")
	_check(is_equal_approx(Vfx.ground_slow(at + Vector2(plant.data.reach * 3.0, 0.0)), 1.0), "ground beside the thorns slows a mover")
	var hero: Hero = _whole_warden()
	hero.global_position = at
	var pool: Health = Health.of(hero)
	var before: float = pool.current_hp
	await _wait(Balance.HAZARD_CONTACT_TICK * 2.5)
	_check(pool.current_hp < before - pool.max_hp * plant.data.hero_share * 0.5, "a Warden standing in thorns was not cut")
	hero.global_position = at + Vector2(0.0, 900.0)
	# A body, nearly spent, is cut and never killed.
	var body: Enemy = _stand_a_body(at + Vector2(10.0, 0.0))
	if body != null:
		var body_pool: Health = Health.of(body)
		body_pool.current_hp = body_pool.max_hp * (Balance.HAZARD_BODY_FLOOR + 0.03)
		await _wait(Balance.HAZARD_CONTACT_TICK * 6.0)
		_check(body_pool.current_hp >= body_pool.max_hp * Balance.HAZARD_BODY_FLOOR - 0.5 and body_pool.current_hp > 0.0,
			"thorns took a body under the floor (%.1f of %.1f)" % [body_pool.current_hp, body_pool.max_hp])
		_check(body_pool.current_hp < body_pool.max_hp * (Balance.HAZARD_BODY_FLOOR + 0.03) - 0.01, "thorns did not cut a body standing in them")
		body.queue_free()
	plant.queue_free()
	await get_tree().process_frame
	_reached.append("thorns")


func _test_spores() -> void:
	var plant: HazardPlant = _plant(HazardPlantData.Behaviour.SPORES)
	if plant == null:
		return
	var hero: Hero = _whole_warden()
	var pool: Health = Health.of(hero)
	_check(plant.state == HazardPlant.State.HIDDEN or plant.state == HazardPlant.State.OUT, "a pod starts %d" % plant.state)
	hero.global_position = plant.global_position + Vector2(plant.data.trigger * 0.5, 0.0)
	var before: float = pool.current_hp
	await _wait(0.1)
	_check(plant.state == HazardPlant.State.WAKING, "a pod did not swell for a Warden beside it")
	await _wait(plant.data.telegraph + 0.3)
	_check(pool.current_hp < before - pool.max_hp * plant.data.hero_share * 0.5, "a pod burst and hurt nobody beside it")
	var blows: int = plant.blows
	await _wait(1.0)
	_check(plant.blows == blows, "a spent pod burst again before it rested")
	hero.global_position = plant.global_position + Vector2(0.0, 900.0)
	plant.queue_free()
	await get_tree().process_frame
	_reached.append("spores")


func _test_a_snapper() -> void:
	var plant: HazardPlant = _plant(HazardPlantData.Behaviour.SNAPPER)
	if plant == null:
		return
	var hero: Hero = _whole_warden()
	var pool: Health = Health.of(hero)
	_check(plant.state == HazardPlant.State.HIDDEN, "a snapper does not start hidden")
	hero.global_position = plant.global_position + Vector2(plant.data.trigger * 1.5, 0.0)
	await _wait(0.4)
	_check(plant.state == HazardPlant.State.HIDDEN, "a snapper woke for a Warden out of its reach")
	hero.global_position = plant.global_position + Vector2(plant.data.reach * 0.4, 0.0)
	var before: float = pool.current_hp
	await _wait(plant.data.telegraph + 0.3)
	_check(pool.current_hp < before - pool.max_hp * plant.data.hero_share * 0.5, "a snapper did not bite a Warden standing on it")
	hero.global_position = plant.global_position + Vector2(0.0, 900.0)
	await _wait(Balance.HAZARD_SNAP_LINGER + Balance.HAZARD_CLOSE_SECONDS + 0.4)
	_check(plant.state == HazardPlant.State.HIDDEN, "a snapper did not go back under")
	plant.queue_free()
	await get_tree().process_frame
	_reached.append("snapper")


func _test_a_spitter() -> void:
	var plant: HazardPlant = _plant(HazardPlantData.Behaviour.SPITTER)
	if plant == null:
		return
	var hero: Hero = _whole_warden()
	var pool: Health = Health.of(hero)
	_check(plant.state == HazardPlant.State.HIDDEN, "a spitter does not start closed")
	hero.global_position = plant.global_position + Vector2(plant.data.spit_range * 0.6, 0.0)
	var before: float = pool.current_hp
	await _wait(Balance.HAZARD_OPEN_SECONDS + plant.data.telegraph + 0.5)
	_check(plant.blows > 0, "a spitter never spat at a Warden in its range")
	_check(pool.current_hp < before - pool.max_hp * plant.data.hero_share * 0.5, "a spit landed and hurt nobody where it was aimed")
	hero.global_position = plant.global_position + Vector2(0.0, plant.data.spit_range * 3.0)
	await _wait(plant.data.out_seconds + Balance.HAZARD_CLOSE_SECONDS + plant.data.telegraph + 0.6)
	_check(plant.state == HazardPlant.State.HIDDEN, "a spitter with nothing in range stayed open")
	plant.queue_free()
	await get_tree().process_frame
	_reached.append("spitter")


func _test_cutting_one_down() -> void:
	var plant: HazardPlant = _plant(HazardPlantData.Behaviour.THORNS)
	if plant == null:
		return
	var from: Vector2 = plant.global_position + Vector2(-40.0, 0.0)
	var swings: int = 0
	while plant.state != HazardPlant.State.CUT and swings < 40:
		EventBus.hero_swing_resolved.emit(from, Vector2.RIGHT, 80.0, 0, "", true)
		swings += 1
	_check(plant.state == HazardPlant.State.CUT, "forty swings did not cut thorns down")
	_check(plant.cut_downs == 1, "a plant cut down %d times" % plant.cut_downs)
	_check(is_equal_approx(Vfx.ground_slow(plant.global_position), 1.0), "thorns cut down still slow a mover")
	var hero: Hero = _whole_warden()
	hero.global_position = plant.global_position
	var pool: Health = Health.of(hero)
	var before: float = pool.current_hp
	await _wait(Balance.HAZARD_CONTACT_TICK * 2.5)
	_check(is_equal_approx(pool.current_hp, before), "thorns cut down still cut a Warden")
	hero.global_position = plant.global_position + Vector2(0.0, 900.0)
	plant.queue_free()
	await get_tree().process_frame
	_reached.append("cut")


## A plant wakes for a Warden and a body that has left the road, and never for
## an animal or a body walking its route.
func _test_what_wakes_a_plant() -> void:
	var plant: HazardPlant = _plant(HazardPlantData.Behaviour.SPITTER)
	if plant == null:
		return
	var animals: Wildlife = _field.wildlife()
	var kind: WildlifeData = ContentDB.wildlife_kinds.get("deer", null) as WildlifeData
	if animals != null and kind != null:
		var deer: Dictionary = animals.spawn_born(kind, plant.global_position + Vector2(plant.data.spit_range * 0.5, 0.0),
			{"stage": WildlifeFamilies.Stage.ADULT, "rarity": 0})
		if not deer.is_empty():
			deer["patience"] = 9999.0
			await _wait(Balance.HAZARD_OPEN_SECONDS + 0.5)
			_check(plant.state == HazardPlant.State.HIDDEN and plant.blows == 0, "a spitter woke for an animal")
		animals.clear()
	plant.queue_free()
	# An open outskirts tile with no road beside it but a road within four tiles:
	# the spitter stands there, a body walks the road, and another leaves it.
	var road: Vector2 = Vector2.INF
	var spot: Vector2 = Vector2.INF
	for y: int in range(2, BattleGrid.SIZE - 2):
		for x: int in range(2, BattleGrid.SIZE - 2):
			var tile := Vector2i(x, y)
			if _field.grid.cell_at(tile) != BattleGrid.Cell.OPEN or not BattleGrid.beyond_core(BattleGrid.tile_to_world(tile)):
				continue
			var near_road: bool = false
			var found: Vector2i = Vector2i(-1, -1)
			for dx: int in range(-4, 5):
				for dy: int in range(-4, 5):
					if _field.grid.cell_at(tile + Vector2i(dx, dy)) == BattleGrid.Cell.ROAD:
						if absi(dx) <= 2 and absi(dy) <= 2:
							near_road = true
						else:
							found = tile + Vector2i(dx, dy)
			if not near_road and found.x >= 0:
				spot = BattleGrid.tile_to_world(tile)
				road = BattleGrid.tile_to_world(found)
				break
		if spot != Vector2.INF:
			break
	_check(spot != Vector2.INF, "no outskirts ground near a road to test a spitter on")
	if spot == Vector2.INF:
		return
	var spitter: HazardPlant = _field.hazards().plant_at(plant.data, spot)
	_field.hero.global_position = road + Vector2(0.0, 2400.0)
	var walker: Enemy = _stand_a_body(road)
	await _wait(Balance.HAZARD_OPEN_SECONDS + 0.5)
	_check(spitter.blows == 0, "a spitter spat at a body walking its route")
	if walker != null:
		walker.global_position = spitter.global_position + Vector2(36.0, 0.0)
		await _wait(Balance.HAZARD_OPEN_SECONDS + spitter.data.telegraph + 0.6)
		_check(spitter.blows > 0, "a spitter never spat at a body that had left the road")
		walker.queue_free()
	spitter.queue_free()
	await get_tree().process_frame
	_reached.append("wakes")


## An animal never arrives into thorns and never settles in them.
func _test_animals_keep_out_of_thorns() -> void:
	var plant: HazardPlant = _plant(HazardPlantData.Behaviour.THORNS)
	var animals: Wildlife = _field.wildlife()
	if plant == null or animals == null:
		return
	_check(not bool(animals.call("_is_clear", plant.global_position)), "an animal may arrive into a thorn patch")
	var settled: Vector2 = animals.call("_settled", plant.global_position + Vector2(5.0, 0.0)) as Vector2
	_check(settled.distance_to(plant.global_position) > plant.data.reach, "an animal's goal in thorns was left in them")
	plant.queue_free()
	await get_tree().process_frame
	_reached.append("berth")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])
