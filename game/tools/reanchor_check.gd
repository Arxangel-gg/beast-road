extends Node

## A body thrown off the road walks back to the nearest part of it.
##
## The route cursor only ever advanced, so an enemy knocked hard - a finisher, a
## Tremor, a boss shove - kept aiming at the waypoint it had been walking to.
## After a big displacement that waypoint can be behind it or across a bend, and
## the body walked diagonally over ground the road does not cover. Reported from
## play.
##
## Two properties, and the second is what makes the first safe: a body thrown
## clear re-enters at the leg it is actually nearest, and a body merely walking
## wide - which every column does by design - keeps the progress it made.

var _failures: int = 0
var _run: Run = null


func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	# A battlefield needs the run around it; instantiated bare it never finishes
	# starting and this gate simply hung.
	_run = load("res://scenes/run/run.tscn").instantiate() as Run
	add_child(_run)
	await get_tree().process_frame
	_run._preparation_left = 0.0
	_run._on_ride_on_requested()
	await get_tree().process_frame
	_run.battlefield.wave_director.stop()

	var route: PackedVector2Array = _run.battlefield.lane_route(0)
	_check(route.size() >= 3, "the gate needs a route with a bend in it")
	if route.size() >= 3:
		_test_a_wide_column_keeps_its_progress(route)
		_test_a_thrown_body_rejoins_at_the_nearest_leg(route)

	GameDirector.run_active = false
	# Detached and freed rather than queued: `queue_free` lands whenever the tree
	# next gets to it, and this gate went green on Windows while leaking twelve
	# objects on the Linux runner - purely on how many frames each allowed before
	# quitting. A leaked object is an ERROR line and fails the pipeline whatever
	# the gate's own verdict was.
	remove_child(_run)
	_run.free()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 8:
		await get_tree().process_frame
	if _failures == 0:
		print("[reanchor] PASS - thrown bodies rejoin the road, wide ones keep their place")
	else:
		push_error("[reanchor] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Walking wide is normal and must not cost progress. Without this the other
## property could be satisfied by re-anchoring constantly, which would drag
## every column backwards on every corner.
func _test_a_wide_column_keeps_its_progress(route: PackedVector2Array) -> void:
	var enemy: Enemy = _spawn()
	if enemy == null:
		return
	enemy._path_index = 1
	var leg: Vector2 = route[2] - route[1]
	enemy.global_position = route[1] + leg * 0.5 \
		+ leg.normalized().orthogonal() * (Balance.ENEMY_REANCHOR_DISTANCE * 0.4)
	enemy._road_direction()
	_check(enemy._path_index >= 1,
		"a body walking wide must keep its progress, not re-anchor backwards (index %d)"
			% enemy._path_index)
	_release(enemy)


func _test_a_thrown_body_rejoins_at_the_nearest_leg(route: PackedVector2Array) -> void:
	var enemy: Enemy = _spawn()
	if enemy == null:
		return
	var last: int = route.size() - 2
	enemy._path_index = last
	enemy.global_position = route[0].lerp(route[1], 0.5)
	enemy._road_direction()
	_check(enemy._path_index == 0,
		"a body thrown back to the first leg must re-enter there, not aim at the "
			+ "waypoint it left (index %d)" % enemy._path_index)

	# And what it walks toward must lead along the road, not back across it.
	enemy._path_index = last
	enemy.global_position = route[0].lerp(route[1], 0.5)
	var heading: Vector2 = enemy._road_direction()
	var leg: Vector2 = (route[1] - route[0]).normalized()
	_check(heading.dot(leg) > 0.2,
		"after rejoining, the body must walk along the road rather than across it")
	_release(enemy)


func _spawn() -> Enemy:
	var breed: EnemyData = null
	for id: String in ContentDB.enemies:
		breed = ContentDB.enemy(id)
		break
	if breed == null:
		_check(false, "the gate needs an enemy breed")
		return null
	var enemy: Enemy = _run.battlefield.spawn_enemy(breed, 0, 1.0)
	if enemy == null:
		_check(false, "the battlefield refused to spawn a body")
	return enemy


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	print("[reanchor] %s" % why)


## Takes a body off the field immediately.
##
## The battlefield spawned it, so it is detached from whatever parent it was
## given rather than assumed to be a child of this gate.
func _release(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var parent: Node = enemy.get_parent()
	if parent != null:
		parent.remove_child(enemy)
	enemy.free()
