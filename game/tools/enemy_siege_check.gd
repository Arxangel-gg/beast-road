extends Node

## Every body that reaches the wall hits the wall.
##
## Written 2026-09-21 for the report on v0.47.1 that "enemies never attack
## anything - not the base, not the player". Traced on the owner's own banked
## front before a line was changed: the ordinary breeds walked up and struck,
## and every Dune Burrower in the wave stood at the wall for three minutes in
## WALKING, thirty-one units from the base, aimed at a tower in its lane it had
## walked past and could never reach - the road is not optional, so a body never
## leaves it for a tower. `_pick_target`'s tower branch had no reach condition
## since the day it was written, and no gate had ever asked a siege breed what
## it did *after* it preferred the tower.
##
## Three things, each driven through the real field with the run frozen and
## `_process` called by hand, so nothing but the body's own logic moves it:
##
## - **Every breed walks the road and lands a blow on the town.** The whole
##   roster, never a sample: the previous gate asked whichever breed the
##   dictionary handed over first and passed because it was a ranged one.
## - **A siege breed at the gate hits the gate.** With a tower standing in its
##   lane beyond its arm, it swings at the wall rather than at the tower.
## - **And it still prefers the tower where it can reach it**, and from the
##   spawn, which is `structure_check`'s invariant and the reason siege breeds
##   exist. A fix that made them ignore towers would pass the second test and
##   quietly delete the role.

## A thirtieth rather than a sixtieth: the body's logic is delta-driven, a
## thirtieth is a frame this game legitimately runs at, and it halves the cost
## of walking sixty-odd breeds up the road by hand.
const FRAME: float = 1.0 / 30.0
## How far up the road from the wall each body starts, and how long it gets.
## Six hundred units is under half a minute for the slowest boss on the roster
## walking into the wind; the budget is four times that, so a body that runs
## out of it was stuck rather than slow.
const WALK_DISTANCE: float = 600.0
const WALK_FRAMES: int = 30 * 120
const GATE_FRAMES: int = 30 * 20

var _failures: int = 0
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null
var _shots: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260921)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	if _field == null:
		_check(false, "the harness needs a battlefield")
		_finish()
		return
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	var animals: Node = _field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	# A tower for the siege tests, built while building is still allowed.
	RunState.gain_every_currency(9999)
	# A tower stands off its anchor's tile centre - ninety-six units toward the
	# town on this map - so where a tower *will* stand is read off one that is
	# standing rather than computed: the first is built at the pocket, the
	# offset measured, and if the pocket is inside some arm the tower the tests
	# use is built further out and the first is felled.
	var pocket: Vector2i = _field.free_anchor_near(0)
	var built: String = _field.try_build(pocket, ContentDB.tower("ember_spire"))
	_check(built.is_empty(), "the lane tower could not be built: %s" % built)
	await get_tree().process_frame
	var tower: Tower = _field.tower_at_anchor(pocket)
	_check(tower != null, "the lane tower is not standing")
	if tower != null:
		var stands_off: Vector2 = tower.global_position - BattleGrid.tile_to_world(pocket)
		var anchor: Vector2i = _anchor_beyond_every_arm(0, stands_off)
		if anchor != pocket:
			var second: String = _field.try_build(anchor, ContentDB.tower("ember_spire"))
			_check(second.is_empty(), "the far lane tower could not be built: %s" % second)
			await get_tree().process_frame
			var far: Tower = _field.tower_at_anchor(anchor)
			if far != null:
				Health.of(tower).kill(Vector2.ZERO)
				tower = far
		print("[siege] lane tower stands at %s (anchor %s, off its tile by %s)"
			% [tower.global_position, anchor, stands_off])
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.resume()
	for _frame: int in 4:
		await get_tree().process_frame
	_field.hero.global_position = Vector2(4000.0, 4000.0)
	# Shots are parented to the field itself, not to the entity root.
	_field.child_entered_tree.connect(_on_field_child)
	# **The town may not die under a probe.** A boss's blow takes a fifth of the
	# wall, `TownCore._on_died` ends the run, and every breed after that is
	# measured on a run that has ended - which reads as forty bodies aiming at
	# nothing. `floor_hp` is the door the homecoming withdrawal already uses.
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	_run.process_mode = Node.PROCESS_MODE_DISABLED

	if tower != null:
		_test_a_siege_breed_prefers_a_tower_it_can_reach(tower)
		await _test_a_siege_breed_at_the_gate_hits_the_gate(tower)
		# Out of the way of the roster walk: a body that noticed it would have
		# a reason to stop that this test is not about.
		var tower_health: Health = Health.of(tower)
		if tower_health != null:
			tower_health.kill(Vector2.ZERO)
		for _frame: int in 2:
			_run.process_mode = Node.PROCESS_MODE_INHERIT
			await get_tree().process_frame
			_run.process_mode = Node.PROCESS_MODE_DISABLED
	await _test_every_breed_lands_a_blow_on_the_town()
	_finish()


## A legal anchor in the lane that no breed can reach from the wall.
##
## `free_anchor_near` answers the pocket by the road's bend, and for lane 0 that
## pocket is inside the White Maw Giant's arm from the wall - so the probe that
## stands a giant at the gate with "an unreachable tower" was standing it beside
## a reachable one. Searched outward from the pocket until the tower is further
## from the road's end than the longest reach on the roster.
func _anchor_beyond_every_arm(lane: int, stands_off: Vector2) -> Vector2i:
	# What each siege breed can reach, and from where it measures: a body's gap
	# to a tower is taken from its *combat origin*, which sits `_depth_lift`
	# above its feet - a hundred units on the White Maw Giant - so a tower that
	# is out of reach of the feet can be inside reach of the body.
	var arms: Array[Vector3] = []
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null or not breed.targets_towers:
			continue
		var probe: Enemy = _field.spawn_enemy(breed, lane, 1.0)
		if probe == null:
			continue
		# The lift is applied when the sprite is dressed, after the spawn, so
		# it is read off `combat_origin()` after one tick rather than off the
		# field - the first cut read zero for every breed and passed the giant.
		probe.call("_process", 0.0)
		arms.append(Vector3(probe.attack_reach(), probe.contact_radius(),
			probe.global_position.y - probe.combat_origin().y))
		probe.free()
	# Every gate a lane's routes may end at: a lane is a spawn side, and its
	# routes wrap to whichever gate the lattice found, so the probe may stand at
	# any of the four.
	var bounds: Rect2 = _field.city_bounds()
	var gates: Array[Vector2] = [Vector2(bounds.position.x, 0.0), Vector2(bounds.end.x, 0.0),
		Vector2(0.0, bounds.position.y), Vector2(0.0, bounds.end.y)]
	var origin: Vector2i = BattleGrid.world_to_tile(_field.grid.lane_pocket_centre(lane))
	for ring: int in 20:
		for dx: int in range(-ring, ring + 1):
			for dy: int in range(-ring, ring + 1):
				if absi(dx) != ring and absi(dy) != ring:
					continue
				var candidate: Vector2i = origin + Vector2i(dx, dy) * BattleGrid.FOOTPRINT
				if not _field.placement_problem(candidate).is_empty():
					continue
				if RunState.tower_lane(candidate) != lane:
					continue
				var at: Vector2 = BattleGrid.tile_to_world(candidate) + stands_off
				var clear: bool = true
				for arm: Vector3 in arms:
					for gate: Vector2 in gates:
						var feet: Vector2 = gate + gate.normalized() * (arm.y + 2.0)
						var body: Vector2 = feet + Vector2(0.0, -arm.z)
						var gap: float = body.distance_to(at) - _field.target_radius(null)
						if gap <= arm.x * 1.3 + 20.0:
							clear = false
							break
					if not clear:
						break
				if clear:
					return candidate
	_check(false, "no anchor in lane %d clears every siege arm; arms %s" % [lane, arms])
	return _field.free_anchor_near(lane)


func _on_field_child(node: Node) -> void:
	if node is EnemyProjectile:
		_shots += 1


## A point on the body's own route, measured back from the wall end, and the
## leg it sits on. Measured from the end rather than as a share of the whole,
## because the routes differ in length by a factor of three and a share puts a
## marcher on one road a minute further out than on another.
func _stand_up_the_road(enemy: Enemy, back: float) -> void:
	var route: PackedVector2Array = enemy.get("_route")
	if route.size() < 2:
		return
	var left: float = back
	for index: int in range(route.size() - 1, 0, -1):
		var leg: float = route[index].distance_to(route[index - 1])
		if left <= leg or index == 1:
			enemy.global_position = route[index].lerp(route[index - 1],
				clampf(left / maxf(leg, 0.001), 0.0, 1.0))
			enemy.set("_path_index", index - 1)
			return
		left -= leg


## Lets the tree drop the bodies queued for freeing, with the field ticking
## once so nothing that was disabled is left half-torn-down.
func _let_the_tree_settle() -> void:
	_run.process_mode = Node.PROCESS_MODE_INHERIT
	await get_tree().process_frame
	_run.process_mode = Node.PROCESS_MODE_DISABLED


## Walks one body from a share of the way along lane 0 until it strikes,
## returning what it was aiming at when it did, or null if it never struck.
func _walk_to_the_first_blow(enemy: Enemy, frames: int) -> Node:
	for _frame: int in frames:
		enemy.call("_process", FRAME)
		if int(enemy.get("_state")) == Enemy.State.STRIKE:
			return enemy.get("_target") as Node
		if int(enemy.get("_state")) == Enemy.State.DYING:
			return null
	return null


func _test_every_breed_lands_a_blow_on_the_town() -> void:
	# (awaits inside: one settling frame per body)
	var town: Node2D = _field.town
	var probed: int = 0
	var ids: Array = ContentDB.enemies.keys()
	ids.sort()
	for id: Variant in ids:
		var breed := ContentDB.enemies[id] as EnemyData
		if breed == null:
			continue
		var enemy: Enemy = _field.spawn_enemy(breed, 0, 1.0)
		if enemy == null:
			continue
		probed += 1
		_stand_up_the_road(enemy, WALK_DISTANCE)
		var hp_before: float = town.health.current_hp
		var shots_before: int = _shots
		var struck: Node = _walk_to_the_first_blow(enemy, WALK_FRAMES)
		var gap: float = float(enemy.call("_target_gap", town))
		_check(struck == town,
			"%s never struck the town: ended %s aiming at %s, %0.1f from the wall against a reach of %0.1f (phase %s)"
				% [breed.id, Enemy.State.keys()[int(enemy.get("_state"))],
					_name_of(enemy.get("_target") as Node), gap, enemy.attack_reach(),
					RunState.Phase.keys()[RunState.phase]])
		if struck == town:
			# The blow is real: a melee body takes health, a ranged one looses
			# a shot. Either is the wall being besieged rather than posed at.
			enemy.call("_process", FRAME)
			var landed: bool = town.health.current_hp < hp_before - 0.01
			var loosed: bool = _shots > shots_before
			_check(landed or loosed,
				"%s reached its strike and neither took health nor loosed a shot" % breed.id)
			_check(gap <= enemy.attack_reach() * 1.15,
				"%s struck from %0.1f, beyond its own reach of %0.1f" % [breed.id, gap,
					enemy.attack_reach()])
		enemy.queue_free()
		town.health.revive()
		await _let_the_tree_settle()
	_check(probed >= 40, "the roster walk covered only %d breeds" % probed)
	print("[siege] %d breeds walked the road" % probed)


## The traced fault, for every siege breed: at the wall with a tower in its
## lane beyond its arm, it swings at the wall.
func _test_a_siege_breed_at_the_gate_hits_the_gate(tower: Tower) -> void:
	var town: Node2D = _field.town
	var siege: int = 0
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null or not breed.targets_towers:
			continue
		siege += 1
		var enemy: Enemy = _field.spawn_enemy(breed, 0, 1.0)
		if enemy == null:
			continue
		# Stood exactly where the trace found the burrowers: at the end of the
		# road, one body-length off the base.
		var route: PackedVector2Array = enemy.get("_route")
		var last: Vector2 = route[route.size() - 1]
		var outward: Vector2 = (last - town.global_position).normalized()
		enemy.global_position = last + outward * (enemy.contact_radius() + 2.0)
		enemy.set("_path_index", route.size() - 1)
		var tower_gap: float = float(enemy.call("_target_gap", tower))
		print("[siege] %s stands at %s (route end %s, %d nodes), tower at %s, gap %0.1f, reach %0.1f"
			% [breed.id, enemy.global_position, last, route.size(), tower.global_position,
				tower_gap, enemy.attack_reach()])
		_check(tower_gap > enemy.attack_reach(),
			"%s can reach the lane tower from the wall (%0.1f against %0.1f), so this probe measures nothing"
				% [breed.id, tower_gap, enemy.attack_reach()])
		_check(bool(enemy.call("_in_reach", town)),
			"%s stood at the wall is not in reach of it" % breed.id)
		var hp_before: float = town.health.current_hp
		var struck: Node = _walk_to_the_first_blow(enemy, GATE_FRAMES)
		_check(struck == town,
			"%s at the gate with an unreachable tower in its lane %s"
				% [breed.id, ("struck %s instead of the wall" % _name_of(struck)) if struck != null
					else ("stood in %s aiming at %s and never swung" % [
						Enemy.State.keys()[int(enemy.get("_state"))],
						_name_of(enemy.get("_target") as Node)])])
		enemy.call("_process", FRAME)
		_check(town.health.current_hp < hp_before - 0.01 or _shots > 0,
			"%s swung at the wall and the wall lost nothing" % breed.id)
		enemy.queue_free()
		town.health.revive()
		await _let_the_tree_settle()
	_check(siege >= 3, "only %d siege breeds to probe" % siege)


## The role survives the fix: from the spawn the tower is the target, and a
## tower inside the arm is struck rather than the wall behind it.
func _test_a_siege_breed_prefers_a_tower_it_can_reach(tower: Tower) -> void:
	var town: Node2D = _field.town
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null or not breed.targets_towers:
			continue
		var enemy: Enemy = _field.spawn_enemy(breed, 0, 1.0)
		if enemy == null:
			continue
		_check(enemy.call("_pick_target") == tower,
			"%s at its spawn does not prefer the tower in its lane" % breed.id)
		# Beside the tower, and at the wall's edge too if that is where the
		# tower stands - the rule is that a target in reach is kept.
		enemy.global_position = tower.global_position + Vector2(enemy.attack_reach() * 0.5, 0.0)
		_check(enemy.call("_pick_target") == tower,
			"%s beside the tower in its lane looked past it (to %s)"
				% [breed.id, _name_of(enemy.call("_pick_target") as Node)])
		enemy.queue_free()
	# And the rule never fires for a body that is not at the gate: a marcher
	# halfway down the road keeps its town target rather than losing it.
	var marcher: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed != null and breed.category == EnemyData.Category.BREED \
				and not breed.targets_towers and breed.role == EnemyData.Role.MARCHER:
			marcher = breed
			break
	if marcher != null:
		var enemy: Enemy = _field.spawn_enemy(marcher, 0, 1.0)
		if enemy != null:
			enemy.global_position = enemy.route_point_at(0.5)
			_check(enemy.call("_pick_target") == town,
				"%s halfway down the road aims at %s rather than the town"
					% [marcher.id, _name_of(enemy.call("_pick_target") as Node)])
			enemy.queue_free()


func _name_of(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return "nothing"
	if node == _field.town:
		return "the town"
	if node is Tower:
		return "a tower"
	if node is Hero:
		return "the hero"
	return node.name


func _finish() -> void:
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	if _run != null:
		_run.process_mode = Node.PROCESS_MODE_INHERIT
		_run.queue_free()
	for _frame: int in 10:
		await get_tree().process_frame
	MetaState.resume_saves()
	print("[siege] %s - %d checks, %d failures" % [
		"PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("[siege] " + message)
