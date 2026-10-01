extends Node

## **The people in the Hold find their way** (owner, 2026-10-01: *"AI in the
## hold should have smarter pathfinding so they do not go walking into stuck
## places or walking into walls and ledges instead of routing smarter with
## pathfinding"*):
##
##   godot --headless --path game res://tools/hold_path_check.tscn
##
## - **The lattice covers the yard**, and every one of its places is ground a
##   person may stand on.
## - **Across a bank, a route goes round.** Pairs of places on the yard that a
##   straight walk cannot join - a bank, the pond, the fire between them - are
##   routed, and every leg of every route is a walk the yard's own rules allow.
## - **Driven, it arrives.** The real Warden, sent by a click across a bank,
##   walks the real yard there through `_process`; and a simulated Warden sent
##   on an errand across the same bank arrives at it. Before routes, both slid
##   along the earth face and stopped.
## - **Somewhere unreachable is walked to its edge and given up**, never pressed
##   against for ever.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	var yard := HoldYard.new()
	add_child(yard)
	for station: Dictionary in HoldYard.STATIONS:
		var door: String = String(station["door"])
		if door.is_empty() or yard.bound(door):
			continue
		var button := Button.new()
		button.name = door
		add_child(button)
		yard.bind(door, button)
	await get_tree().process_frame
	yard.set_process(false)
	var paths: HoldPaths = yard.paths()
	_check(paths != null and paths.size() > 200,
		"the Hold has no lattice to route on (%d places)" % (0 if paths == null else paths.size()))
	if paths == null:
		_finish()
		return
	var blocked: Array = _blocked_pairs(yard)
	_check(blocked.size() >= 6, "found only %d pairs a bank keeps apart - nothing to route round" % blocked.size())
	_test_routes_go_round(yard, blocked)
	_test_the_warden_walks_round(yard, blocked)
	_test_a_simulated_warden_arrives(yard, blocked)
	_test_unreachable_is_given_up(yard)
	_finish()


## Pairs of places the yard keeps apart in a straight line and joins by a way
## round - which is every pair this exists for.
func _blocked_pairs(yard: HoldYard) -> Array:
	var dice := RandomNumberGenerator.new()
	dice.seed = 20261001
	var out: Array = []
	var half: Vector2 = HoldYard.YARD * 0.5 - Vector2(80.0, 80.0)
	var tries: int = 0
	while out.size() < 24 and tries < 4000:
		tries += 1
		var a := Vector2(dice.randf_range(-half.x, half.x), dice.randf_range(-half.y, half.y))
		var b := Vector2(dice.randf_range(-half.x, half.x), dice.randf_range(-half.y, half.y))
		if not yard.stands_at(a) or not yard.stands_at(b) or a.distance_to(b) < 400.0:
			continue
		if _straight_walk_reaches(yard, a, b):
			continue
		var walked: PackedVector2Array = yard.route(a, b)
		if walked.is_empty() or walked[walked.size() - 1].distance_to(b) > 4.0:
			continue
		out.append([a, b])
	return out


## What the Hold did before routes: a straight walk, slid along banks.
func _straight_walk_reaches(yard: HoldYard, from: Vector2, to: Vector2) -> bool:
	var at: Vector2 = from
	for _step: int in 2000:
		var gap: Vector2 = to - at
		if gap.length() <= 16.0:
			return true
		var next: Vector2 = yard._slide(at, at + gap.normalized() * 6.0)
		if next.distance_to(at) < 0.01:
			return false
		at = next
	return false


func _test_routes_go_round(yard: HoldYard, blocked: Array) -> void:
	for pair: Array in blocked:
		var a: Vector2 = pair[0]
		var b: Vector2 = pair[1]
		var walked: PackedVector2Array = yard.route(a, b)
		var from: Vector2 = a
		var legal: bool = true
		for point: Vector2 in walked:
			if not _leg_is_walkable(yard, from, point):
				legal = false
				break
			from = point
		_check(legal, "a route from %s to %s crosses ground the yard refuses (%s)" % [a, b, walked])


## **At a walker's own pace**: a figure takes a few units a frame, and the slope
## rule read in longer strides passes a flight entered from its side that a
## walker is refused - which is exactly the gap the first routes fell into.
func _leg_is_walkable(yard: HoldYard, from: Vector2, to: Vector2) -> bool:
	var run: float = from.distance_to(to)
	var samples: int = maxi(1, int(ceil(run / 2.0)))
	var last: Vector2 = from
	for sample: int in samples:
		var here: Vector2 = from.lerp(to, float(sample + 1) / float(samples))
		if not yard.stands_at(here) or not yard.step_is_legal(last, here):
			return false
		last = here
	return true


## The player's own click, walked by the real yard.
func _test_the_warden_walks_round(yard: HoldYard, blocked: Array) -> void:
	yard.set_driving(true)
	var arrived: int = 0
	var tried: int = 0
	for pair: Array in blocked.slice(0, 6):
		tried += 1
		var a: Vector2 = pair[0]
		var b: Vector2 = pair[1]
		yard.stand_warden(a)
		yard.walk_toward(b)
		var guard: int = 0
		while guard < 900 and yard.warden_at().distance_to(b) > 24.0:
			yard.advance(1.0 / 30.0, 1)
			guard += 1
		if yard.warden_at().distance_to(b) <= 24.0:
			arrived += 1
		else:
			push_error("[hold-path] the Warden walked from %s toward %s and stopped at %s" % [a, b, yard.warden_at()])
	_check(arrived == tried, "the Warden, sent across a bank, arrived %d times of %d" % [arrived, tried])
	yard.set_driving(false)


## A simulated Warden sent on an errand across the same bank.
func _test_a_simulated_warden_arrives(yard: HoldYard, blocked: Array) -> void:
	var seat_index: int = -1
	for index: int in range(1, yard.seats()):
		if yard.seat_kind(index) == HoldSession.Seat.SIMULATED:
			seat_index = index
			break
	_check(seat_index > 0, "the Hold has no simulated Warden to send")
	if seat_index < 0:
		return
	var seat: Dictionary = yard._seats[seat_index]
	var arrived: int = 0
	var tried: int = 0
	for pair: Array in blocked.slice(6, 12):
		tried += 1
		var a: Vector2 = pair[0]
		var b: Vector2 = pair[1]
		seat["at"] = a
		seat["route"] = yard.route(a, b)
		seat["to"] = b
		seat["left"] = 999.0
		seat["stuck"] = 0.0
		var guard: int = 0
		while guard < 1200 and (seat["at"] as Vector2).distance_to(b) > 16.0:
			yard._drift(seat, 1.0 / 30.0)
			guard += 1
		if (seat["at"] as Vector2).distance_to(b) <= 16.0:
			arrived += 1
		else:
			push_error("[hold-path] a simulated Warden from %s toward %s stopped at %s" % [a, b, seat["at"]])
	_check(arrived == tried, "a simulated Warden, sent across a bank, arrived %d times of %d" % [arrived, tried])


## Somewhere the ground cannot reach - the fire pit's middle, the sky above the
## wall - is walked to its edge and the walk ends.
func _test_unreachable_is_given_up(yard: HoldYard) -> void:
	var nowhere := Vector2(0.0, -HoldYard.YARD.y * 0.5 - 300.0)
	yard.set_driving(true)
	yard.stand_warden(Vector2.ZERO)
	yard.walk_toward(nowhere)
	for _frame: int in 900:
		yard.advance(1.0 / 30.0, 1)
	_check(yard._walk_to == Vector2.INF,
		"a walk to somewhere unreachable was never given up - the Warden stands at %s pressing on" % yard.warden_at())
	yard.set_driving(false)


func _finish() -> void:
	MetaState.resume_saves()
	if _failures == 0:
		print("[hold-path] PASS - %d checks: the Hold's lattice covers its ground, a route across a bank goes round by legal steps, the Warden and a simulated Warden sent across one arrive, and somewhere unreachable is given up" % _checks)
	else:
		push_error("[hold-path] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[hold-path] " + why)
