extends Node

## A body thrown off the road walks back to the nearest part of it.
##
## The route cursor only ever advanced, so an enemy knocked hard - a finisher, a
## Tremor, a boss shove - kept aiming at the waypoint it had been walking to.
## After a big displacement that waypoint can be behind it or across a bend, and
## the body walked diagonally over ground the road does not cover. Reported from
## play.
##
## **Tested as arithmetic, not as a battlefield.** The first version of this gate
## built a whole `Run` - a battlefield, a wave director, a hero - to ask one
## question about a polyline, and leaked twelve objects doing it. That passed on
## Windows and failed the Linux runner twice, once inside the release pipeline
## where it blocked a build the owner was waiting on. `Enemy.reanchor_index` is
## static for that reason: the rule is the part worth checking, and it needs no
## nodes, no scene and no teardown.

## A road with a right-angle bend in it: two legs out, then two across. Enough
## shape that "nearest leg" and "leg I am following" can disagree, which is the
## whole point of the rule.
var _route: PackedVector2Array = PackedVector2Array([
	Vector2(0.0, 0.0),
	Vector2(0.0, -1000.0),
	Vector2(0.0, -2000.0),
	Vector2(1000.0, -2000.0),
	Vector2(2000.0, -2000.0),
])

const EXPECTED_TESTS: int = 5

var _failures: int = 0
var _ran: int = 0


func _ready() -> void:
	_test_a_wide_column_keeps_its_progress()
	_test_a_thrown_body_rejoins_at_the_nearest_leg()
	_test_a_body_on_its_own_leg_is_left_alone()
	_test_a_degenerate_route_is_survived()
	_test_the_threshold_is_wider_than_a_lane()

	if _ran != EXPECTED_TESTS:
		_failures += 1
		push_error("[reanchor] only %d of %d tests ran" % [_ran, EXPECTED_TESTS])
	if _failures == 0:
		print("[reanchor] PASS - %d tests; thrown bodies rejoin the road, wide ones keep their place"
			% _ran)
	else:
		push_error("[reanchor] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Walking wide is normal and must not cost progress. Without this the other
## property could be satisfied by re-anchoring constantly, which would drag every
## column backwards on every corner.
func _test_a_wide_column_keeps_its_progress() -> void:
	var wide: Vector2 = Vector2(Balance.ENEMY_REANCHOR_DISTANCE * 0.4, -1500.0)
	_check(Enemy.reanchor_index(_route, wide, 1) == 1,
		"a body walking wide of its leg must keep its progress")
	_ran += 1


func _test_a_thrown_body_rejoins_at_the_nearest_leg() -> void:
	# Standing on the first leg while the cursor still says the last.
	var thrown: Vector2 = Vector2(0.0, -500.0)
	_check(Enemy.reanchor_index(_route, thrown, 3) == 0,
		"a body thrown back to the first leg must re-enter there")
	# And across the bend, where the nearest leg is neither the first nor the one
	# it was following.
	var across: Vector2 = Vector2(1500.0, -2000.0 - Balance.ENEMY_REANCHOR_DISTANCE * 2.0)
	_check(Enemy.reanchor_index(_route, across, 0) == 3,
		"a body thrown past a bend must rejoin at the leg it is nearest")
	_ran += 1


## The common case, and the one that must cost nothing: already on the road.
func _test_a_body_on_its_own_leg_is_left_alone() -> void:
	for leg: int in _route.size() - 1:
		var middle: Vector2 = _route[leg].lerp(_route[leg + 1], 0.5)
		_check(Enemy.reanchor_index(_route, middle, leg) == leg,
			"a body standing on leg %d must stay on it" % leg)
	_ran += 1


## A route can be one point, or none, while a body is still asking where to go.
func _test_a_degenerate_route_is_survived() -> void:
	_check(Enemy.reanchor_index(PackedVector2Array(), Vector2.ZERO, 2) == 2,
		"an empty route must leave the cursor alone rather than crash")
	_check(Enemy.reanchor_index(PackedVector2Array([Vector2.ZERO]), Vector2.ONE, 0) == 0,
		"a single-point route must leave the cursor alone")
	# A cursor past the end, which happens as a body finishes the road.
	_check(Enemy.reanchor_index(_route, _route[0], 99) >= 0,
		"a cursor past the end must be clamped rather than indexed with")
	_ran += 1


## The threshold separates "walking wide", which every column does, from
## "thrown", which is what this rule answers. Too small and formations fight it
## every corner; too large and nothing ever rejoins.
func _test_the_threshold_is_wider_than_a_lane() -> void:
	_check(Balance.ENEMY_REANCHOR_DISTANCE > Balance.LANE_WIDTH,
		"the re-anchor distance (%.0f) must exceed a lane's width (%.0f), or a "
			% [Balance.ENEMY_REANCHOR_DISTANCE, Balance.LANE_WIDTH]
			+ "column's own spread would trigger it")
	_ran += 1


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	print("[reanchor] %s" % why)
