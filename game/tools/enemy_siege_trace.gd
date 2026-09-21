extends Node

## A diagnostic, not a gate: one real body walks the road to the town and every
## state transition is printed with its position, its distance to the wall, its
## path index and what it is aiming at. Written 2026-09-21 because two confident
## readings of this code were wrong in one week and the report on v0.47.1 is
## "enemies never attack anything".

const FRAME: float = 1.0 / 60.0
const MAX_FRAMES: int = 60 * 90

var _run: Run = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.hold_saves()
	var mode: String = _mode()
	if mode == "resume":
		# The owner's own banked front, put down exactly the way `start_run`
		# puts it down: reset, then apply, then build the field.
		RunState.reset(true, 0)
		print("[trace] has_expedition=%s readable=%s" % [MetaState.has_expedition(),
			Expedition.is_readable(MetaState.expedition)])
		print("[trace] expedition: act=%s wave=%s distance=%s momentum=%s towers=%d wall=%s tier=%s"
			% [MetaState.expedition.get("act"), MetaState.expedition.get("wave"),
				MetaState.expedition.get("distance"), MetaState.expedition.get("momentum"),
				(MetaState.expedition.get("towers", []) as Array).size(),
				MetaState.expedition.get("wall"), MetaState.expedition.get("tier")])
		var applied: bool = Expedition.apply(MetaState.expedition)
		print("[trace] applied=%s act=%d wave=%d phase=%s terrain=%s tier=%s withdrawing=%s walking=%s horn=%s"
			% [applied, RunState.act, RunState.wave_number, RunState.Phase.keys()[RunState.phase],
				RunState.terrain_id, RunState.tier_id, RunState.withdrawing, RunState.walking,
				RunState.horn_active])
	else:
		RunState.reset(false, 20260921)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	if _field == null:
		print("[trace] no battlefield")
		get_tree().quit(1)
		return
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	var animals: Node = _field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.resume()
	for _frame: int in 4:
		await get_tree().process_frame

	var bounds: Rect2 = _field.city_bounds()
	print("[trace] town at %s, city_bounds %s (half %s), CITY_SANCTUARY_RADIUS %.1f"
		% [_field.town_position(), bounds, bounds.size * 0.5, Balance.CITY_SANCTUARY_RADIUS])
	print("[trace] town.radius() %.1f" % _field.town.radius())
	for lane: int in Balance.LANE_COUNT:
		var route: PackedVector2Array = _field.lane_route(lane)
		if route.size() >= 2:
			var last: Vector2 = route[route.size() - 1]
			var gap := _gap_to_rect(last, bounds)
			print("[trace] lane %d route: %d nodes, last %s (from origin %.1f, to rect edge %.1f, inside rect %s)"
				% [lane, route.size(), last, last.length(), gap, bounds.has_point(last)])

	var breeds: Array[EnemyData] = _breeds_for_this_act()
	print("[trace] act breeds: %s" % [breeds.map(func(b: EnemyData) -> String: return b.id)])

	print("[trace] mode: %s" % mode)
	match mode:
		"hand":
			await _trace_hand_driven(breeds)
		"engine":
			await _trace_engine_driven(breeds)
		"hero":
			await _trace_against_hero(breeds)
		"full", "resume":
			await _trace_full_waves()
		_:
			await _trace_hand_driven(breeds)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	_run.queue_free()
	for _frame: int in 8:
		await get_tree().process_frame
	MetaState.resume_saves()
	get_tree().quit(0)


func _mode() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			return arg.trim_prefix("--mode=")
	return "hand"


func _breeds_for_this_act() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null:
		for id: String in terrain.enemy_ids:
			var breed: EnemyData = ContentDB.enemy(id)
			if breed != null:
				out.append(breed)
	return out


func _gap_to_rect(at: Vector2, bounds: Rect2) -> float:
	var edge := Vector2(clampf(at.x, bounds.position.x, bounds.end.x),
		clampf(at.y, bounds.position.y, bounds.end.y))
	return at.distance_to(edge)


func _state_name(enemy: Enemy) -> String:
	var state: int = int(enemy.get("_state"))
	return Enemy.State.keys()[state] if state < Enemy.State.keys().size() else str(state)


func _target_name(enemy: Enemy) -> String:
	var target: Node = enemy.get("_target") as Node
	if target == null or not is_instance_valid(target):
		return "none"
	if target == _field.town:
		return "TOWN"
	if target is Hero:
		return "HERO"
	return target.name


func _line(tag: String, frame: int, enemy: Enemy, bounds: Rect2) -> String:
	var at: Vector2 = enemy.global_position
	var gap_rect: float = _gap_to_rect(at, bounds)
	var gap_town: float = float(enemy.call("_target_gap", _field.town))
	return ("[trace %s] f%04d t=%5.2fs %-8s tgt=%-6s pos=(%7.1f,%7.1f) rect_gap=%6.1f "
		+ "town_gap=%6.1f reach=%5.1f in_reach=%s path=%d/%d stun=%.2f frz=%.2f kb=%.1f grown=%s")\
		% [tag, frame, frame * FRAME, _state_name(enemy), _target_name(enemy), at.x, at.y,
			gap_rect, gap_town, enemy.attack_reach(), bool(enemy.call("_in_reach", _field.town)),
			int(enemy.get("_path_index")), (enemy.get("_route") as PackedVector2Array).size(),
			float(enemy.get("_hitstun_left")), float(enemy.get("_freeze_left")),
			(enemy.get("_knockback") as Vector2).length(),
			bounds.grow(enemy.contact_radius()).has_point(at)]


## The body's own logic alone: the run is frozen and `_process` is called by
## hand, so nothing else on the field can move it.
func _trace_hand_driven(breeds: Array[EnemyData]) -> void:
	_field.hero.global_position = Vector2(4000.0, 4000.0)
	_run.process_mode = Node.PROCESS_MODE_DISABLED
	var bounds: Rect2 = _field.city_bounds()
	for breed: EnemyData in breeds:
		var enemy: Enemy = _field.spawn_enemy(breed, 0, 1.0)
		if enemy == null:
			continue
		# Start most of the way in so the walk is short enough to read.
		var route: PackedVector2Array = enemy.get("_route")
		enemy.global_position = enemy.route_point_at(0.35)
		enemy.set("_path_index", 0)
		var town_hp_before: float = _field.town.health.current_hp
		print("[trace] === %s role=%s speed=%.1f contact_radius=%.1f reach=%.1f route=%d nodes, start %s"
			% [breed.id, EnemyData.Role.keys()[breed.role], breed.move_speed,
				enemy.contact_radius(), enemy.attack_reach(), route.size(), enemy.global_position])
		var last_state: int = -1
		var last_target: String = ""
		var last_pos: Vector2 = enemy.global_position
		var strikes: int = 0
		var stuck_frames: int = 0
		var moved_total: float = 0.0
		for frame: int in MAX_FRAMES:
			var before: Vector2 = enemy.global_position
			enemy.call("_process", FRAME)
			var moved: float = enemy.global_position.distance_to(before)
			moved_total += moved
			var state: int = int(enemy.get("_state"))
			var target: String = _target_name(enemy)
			if state != last_state or target != last_target:
				print(_line(breed.id, frame, enemy, bounds))
				if state == Enemy.State.STRIKE:
					strikes += 1
				last_state = state
				last_target = target
			elif frame % 120 == 0:
				print(_line(breed.id, frame, enemy, bounds) + " moved=%.2f/frame" % moved)
			if moved < 0.05 and state == Enemy.State.WALKING:
				stuck_frames += 1
			last_pos = enemy.global_position
			if strikes >= 3:
				break
		var town_hp_after: float = _field.town.health.current_hp
		print("[trace] --- %s: strikes=%d town_hp %.1f -> %.1f (delta %.1f), stuck-walking frames=%d, total moved=%.1f, final %s"
			% [breed.id, strikes, town_hp_before, town_hp_after, town_hp_before - town_hp_after,
				stuck_frames, moved_total, _line(breed.id, MAX_FRAMES, enemy, bounds)])
		enemy.queue_free()
		_field.town.health.revive() if _field.town.health.has_method("revive") else null
	_run.process_mode = Node.PROCESS_MODE_INHERIT


## The whole field running: crowd separation, beast steps, towers, everything.
func _trace_engine_driven(breeds: Array[EnemyData]) -> void:
	_field.hero.global_position = Vector2(4000.0, 4000.0)
	var bounds: Rect2 = _field.city_bounds()
	var breed: EnemyData = breeds[0]
	for candidate: EnemyData in breeds:
		if candidate.role != EnemyData.Role.HOWLER:
			breed = candidate
			break
	var enemy: Enemy = _field.spawn_enemy(breed, 1, 1.0)
	enemy.global_position = enemy.route_point_at(0.12)
	enemy.set("_path_index", 0)
	var town_hp_before: float = _field.town.health.current_hp
	print("[trace] === ENGINE %s start %s" % [breed.id, enemy.global_position])
	var last_state: int = -1
	var last_target: String = ""
	var strikes: int = 0
	var clock: float = 0.0
	var said_at: float = -10.0
	var frame: int = 0
	while clock < 120.0:
		await get_tree().process_frame
		clock += get_process_delta_time()
		frame += 1
		if not is_instance_valid(enemy):
			print("[trace] body freed at %.2fs" % clock)
			break
		var state: int = int(enemy.get("_state"))
		var target: String = _target_name(enemy)
		if state != last_state or target != last_target:
			print("[%.2fs] " % clock + _line("engine", frame, enemy, bounds))
			if state == Enemy.State.STRIKE:
				strikes += 1
			last_state = state
			last_target = target
		elif clock - said_at >= 2.0:
			said_at = clock
			print("[%.2fs] " % clock + _line("engine", frame, enemy, bounds))
		if strikes >= 3:
			break
	var town_hp_after: float = _field.town.health.current_hp
	print("[trace] --- ENGINE %s: strikes=%d town_hp %.1f -> %.1f" % [breed.id, strikes,
		town_hp_before, town_hp_after])


## A hero standing on the road in front of the body.
func _trace_against_hero(breeds: Array[EnemyData]) -> void:
	_run.process_mode = Node.PROCESS_MODE_DISABLED
	var bounds: Rect2 = _field.city_bounds()
	var hero: Hero = _field.hero
	for breed: EnemyData in breeds:
		var enemy: Enemy = _field.spawn_enemy(breed, 0, 1.0)
		if enemy == null:
			continue
		enemy.global_position = enemy.route_point_at(0.5)
		enemy.set("_path_index", 0)
		# Hero 150 units down the road from the body, toward the town.
		var ahead: Vector2 = enemy.route_point_at(0.5 + 0.06)
		hero.global_position = ahead
		hero.health.revive()
		var hero_hp_before: float = hero.health.current_hp
		print("[trace] === HERO %s body %s hero %s (dist %.1f, hero inside_city=%s)"
			% [breed.id, enemy.global_position, hero.global_position,
				enemy.global_position.distance_to(hero.global_position),
				_field.inside_city(hero.global_position)])
		var last_state: int = -1
		var last_target: String = ""
		var strikes: int = 0
		for frame: int in 60 * 20:
			enemy.call("_process", FRAME)
			var state: int = int(enemy.get("_state"))
			var target: String = _target_name(enemy)
			if state != last_state or target != last_target:
				var d: float = enemy.global_position.distance_to(hero.global_position)
				print(_line(breed.id, frame, enemy, bounds) + " hero_dist=%.1f foe_stands=%s"
					% [d, bool(enemy.call("_foe_stands", hero))])
				if state == Enemy.State.STRIKE:
					strikes += 1
				last_state = state
				last_target = target
			if strikes >= 2:
				break
		print("[trace] --- HERO %s: strikes=%d hero_hp %.1f -> %.1f" % [breed.id, strikes,
			hero_hp_before, hero.health.current_hp])
		enemy.queue_free()
	_run.process_mode = Node.PROCESS_MODE_INHERIT


## The real director, real waves, the hero standing at the town's edge the way
## a player defends it, for minutes of game time. A census every few seconds:
## how many bodies, what they are doing, how far the nearest is from the wall,
## and whether the town and the hero are actually losing health.
func _trace_full_waves() -> void:
	var bounds: Rect2 = _field.city_bounds()
	var hero: Hero = _field.hero
	hero.global_position = Vector2(0.0, bounds.end.y + 40.0)
	print("[trace] hero at %s inside_city=%s" % [hero.global_position,
		_field.inside_city(hero.global_position)])
	_field.wave_director.start() if _field.wave_director.has_method("start") else null
	var clock: float = 0.0
	var said_at: float = -10.0
	var town_hp_last: float = _field.town.health.current_hp
	var hero_hp_last: float = hero.health.current_hp
	var reached_wall: Dictionary = {}
	var landed_on_town: int = 0
	var landed_on_hero: int = 0
	while clock < 240.0:
		await get_tree().process_frame
		clock += get_process_delta_time()
		var town_hp: float = _field.town.health.current_hp
		var hero_hp: float = hero.health.current_hp
		if town_hp < town_hp_last - 0.01:
			landed_on_town += 1
		if hero_hp < hero_hp_last - 0.01:
			landed_on_hero += 1
		town_hp_last = town_hp
		hero_hp_last = hero_hp
		var bodies: Array = get_tree().get_nodes_in_group("enemies")
		for node: Node in bodies:
			var enemy := node as Enemy
			if enemy == null or not is_instance_valid(enemy) or enemy.is_camp_mob():
				continue
			var gap: float = float(enemy.call("_target_gap", _field.town))
			if gap <= enemy.attack_reach() + 5.0 and not reached_wall.has(enemy.get_instance_id()):
				reached_wall[enemy.get_instance_id()] = clock
				print("[%.2fs] ARRIVED " % clock + _line("full", 0, enemy, bounds))
		if clock - said_at >= 5.0:
			said_at = clock
			var census: Dictionary = {}
			var nearest: float = INF
			var nearest_line: String = ""
			var live: int = 0
			for node: Node in bodies:
				var enemy := node as Enemy
				if enemy == null or not is_instance_valid(enemy) or enemy.is_camp_mob():
					continue
				live += 1
				var key: String = _state_name(enemy) + ">" + _target_name(enemy)
				census[key] = int(census.get(key, 0)) + 1
				var gap: float = float(enemy.call("_target_gap", _field.town))
				if gap < nearest:
					nearest = gap
					nearest_line = _line("full", 0, enemy, bounds)
			print("[%.1fs] CENSUS wave=%d phase=%s bodies=%d town_hp=%.1f hero_hp=%.1f landed_town=%d landed_hero=%d arrived=%d %s"
				% [clock, RunState.wave_number, RunState.Phase.keys()[RunState.phase], live,
					town_hp, hero_hp, landed_on_town, landed_on_hero, reached_wall.size(), census])
			if nearest_line != "":
				print("[%.1fs] NEAREST " % clock + nearest_line)
	print("[trace] --- FULL: landed_town=%d landed_hero=%d town_hp=%.1f hero_hp=%.1f arrived_at_wall=%d"
		% [landed_on_town, landed_on_hero, _field.town.health.current_hp, hero.health.current_hp,
			reached_wall.size()])
	# Every body, so the ones that never arrived are accounted for too.
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		var target: Node = enemy.get("_target") as Node
		var target_gap: float = float(enemy.call("_target_gap", target)) 			if target != null and is_instance_valid(target) else -1.0
		var target_at: String = str((target as Node2D).global_position) 			if target is Node2D else "-"
		print("[trace] BODY %-16s camp=%s %s target_gap=%.1f target_at=%s route=%s"
			% [enemy.data.id, enemy.is_camp_mob(), _line("dump", 0, enemy, bounds),
				target_gap, target_at, enemy.get("_route")])
