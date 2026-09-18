extends Node

## **What every moving thing leaves on the ground, measured rather than read
## back.**
##
## `Footfalls` is a picture, and a picture is the easiest kind of feature to ship
## broken: nothing errors when it lays nothing, and nothing errors when it lays a
## thousand. So this drives the real node with real bodies and counts what comes
## out of the painter, rather than asserting the constants it was given.
##
## Five things can go wrong here, and all five have precedent in this project:
##
##  - **Standing still lays dust.** A body nudged a unit by the crowd grid or
##    breathing on the spot is not walking, and a yard that smokes while nobody
##    moves is the first thing anybody would report.
##  - **A spirit leaves footprints.** `FOOTFALL_MASS_BY_HIDE` gives one a mass of
##    zero, which is the whole of how a summoned companion leaves nothing without
##    the driver knowing what a spirit is. A table read but not honoured is the
##    `DisciplineEffects` lie in a third place.
##  - **Mass and effort do not reach the dust.** The owner's brief is that this
##    is *"tuned for each character's size and mass and speed"*; a heavy body and
##    a light one throwing identical clouds is the feature not existing.
##  - **The cap is a hope rather than a cap.** Every live mark is drawn every
##    frame, so an unbounded list is the frame going away in the middle of a
##    wave.
##  - **It changes a number.** Nothing here may touch health, position or the
##    run. Turn the whole thing off and the game is identical.
##
## Driven with a puppet `Node2D` rather than with real `Enemy` bodies on purpose:
## the thing under test is the *driver*, and a real body brings a route, a crowd
## grid and a wave director that would move it for reasons this gate has no
## opinion about. The registrations themselves are checked separately, by reading
## what each body actually declares.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	await get_tree().process_frame

	await _test_standing_still_lays_nothing()
	await _test_walking_lays_marks()
	await _test_a_body_with_no_mass_never_registers()
	await _test_mass_and_effort_reach_the_dust()
	await _test_the_marks_are_capped()
	await _test_the_ground_decides_the_colour()
	_test_every_body_that_walks_declares_a_tread()

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	await get_tree().create_timer(0.5).timeout
	Sfx.stop_immediately()
	if _failures == 0:
		print("[footfalls] PASS - %d checks: the stride, the mass, the cap, "
			% _checks + "the colour and the bodies that declare a tread")
	else:
		push_error("[footfalls] FAIL - %d problem(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


## A driver over a fresh scope, with a known ground colour and no cull.
func _stand_up() -> Footfalls:
	var scope := Node2D.new()
	add_child(scope)
	var feet := Footfalls.new()
	feet.ground = func(_at: Vector2) -> Color: return Color(0.5, 0.4, 0.3)
	scope.add_child(feet)
	return feet


## A body that declares a tread and can be moved by hand.
func _puppet(size: float, mass: float, top: float) -> Node2D:
	var body := Node2D.new()
	add_child(body)
	Footfalls.register(body, size, mass, top)
	return body


## Walks a puppet `distance` units, in `frames` steps, driving the real tick.
##
## **The driver's own clock is honoured rather than bypassed.** `_walk` is what
## counts strides, and calling it directly with a hand-made elapsed time is the
## only way to test a 15 Hz pass without waiting real seconds - but it is still
## the shipped function, not a copy of its arithmetic.
func _march(feet: Footfalls, body: Node2D, way: Vector2, speed: float,
		frames: int) -> void:
	var step: float = 1.0 / Balance.FOOTFALL_HZ
	for _frame: int in frames:
		body.global_position += way.normalized() * speed * step
		feet._walk(step)


func _test_standing_still_lays_nothing() -> void:
	var feet: Footfalls = _stand_up()
	var body: Node2D = _puppet(Balance.ENEMY_BODY_RADIUS, 1.0, 100.0)
	await get_tree().process_frame
	# Dead still, then nudged a unit a frame - which is what a body being shoved
	# out of another body's space looks like.
	_march(feet, body, Vector2.ZERO, 0.0, 20)
	_check(feet.live_marks() == 0,
		"a body standing still must lay nothing, laid %d" % feet.live_marks())
	_march(feet, body, Vector2.RIGHT, 100.0 * Balance.FOOTFALL_MOVING * 0.5, 20)
	_check(feet.live_marks() == 0,
		("a body drifting under the moving threshold must lay nothing, laid %d")
			% feet.live_marks())
	feet.get_parent().queue_free()
	body.queue_free()


func _test_walking_lays_marks() -> void:
	var feet: Footfalls = _stand_up()
	var body: Node2D = _puppet(Balance.ENEMY_BODY_RADIUS, 1.0, 100.0)
	await get_tree().process_frame
	_march(feet, body, Vector2.RIGHT, 100.0, 30)
	_check(feet.live_marks() > 0,
		"a body at its own top speed must scuff the ground, laid nothing")
	feet.get_parent().queue_free()
	body.queue_free()


## **Zero mass is the door a spirit leaves nothing through.**
##
## Checked at the registration rather than at the mark, because a body that
## registers and is then skipped every tick is a per-frame test of something that
## should have been decided once.
func _test_a_body_with_no_mass_never_registers() -> void:
	var ghost := Node2D.new()
	add_child(ghost)
	Footfalls.register(ghost, Balance.ENEMY_BODY_RADIUS,
		Balance.FOOTFALL_MASS_BY_HIDE[EnemyData.Hide.SPIRIT], 100.0)
	await get_tree().process_frame
	_check(not ghost.is_in_group(Footfalls.GROUP),
		"a body of no mass must not join the tread group")
	_check(Balance.FOOTFALL_MASS_BY_HIDE[EnemyData.Hide.SPIRIT] == 0.0,
		"a spirit's hide must weigh nothing, or it leaves prints")
	# And the hide table must cover every hide there is, or a new one silently
	# reads as whatever the clamp hands back.
	_check(Balance.FOOTFALL_MASS_BY_HIDE.size() == EnemyData.Hide.size(),
		("the hide weights must name every hide: %d weights for %d hides")
			% [Balance.FOOTFALL_MASS_BY_HIDE.size(), EnemyData.Hide.size()])
	ghost.queue_free()


## **Heavier throws more, and faster throws more.** The owner's brief is that the
## dust is tuned to each character; two bodies of different mass covering the
## same ground with the same cloud is the tuning not being there.
func _test_mass_and_effort_reach_the_dust() -> void:
	var light: int = await _count_a_walk(1.0, 1.0)
	var heavy: int = await _count_a_walk(Balance.FOOTFALL_MASS_MOUNT, 1.0)
	_check(heavy > light,
		"a heavier body must throw more than a light one, %d against %d"
			% [heavy, light])
	var strolling: int = await _count_a_walk(1.0,
		Balance.FOOTFALL_MOVING * 1.5)
	_check(light > strolling,
		"a body at a run must throw more than one barely moving, %d against %d"
			% [light, strolling])


## Walks one puppet at `share` of its top speed and counts what it laid.
func _count_a_walk(mass: float, share: float) -> int:
	var feet: Footfalls = _stand_up()
	var body: Node2D = _puppet(Balance.ENEMY_BODY_RADIUS, mass, 100.0)
	await get_tree().process_frame
	# The same ground covered either way, so what is being compared is the dust
	# a stride throws rather than how many strides were taken.
	_march(feet, body, Vector2.RIGHT, 100.0 * share,
		int(round(30.0 / maxf(share, 0.01))))
	var laid: int = feet.live_marks()
	feet.get_parent().queue_free()
	body.queue_free()
	return laid


func _test_the_marks_are_capped() -> void:
	var feet: Footfalls = _stand_up()
	var crowd: Array[Node2D] = []
	for _index: int in 60:
		crowd.append(_puppet(Balance.ENEMY_BODY_RADIUS,
			Balance.FOOTFALL_MASS_MOUNT, 100.0))
	await get_tree().process_frame
	for _frame: int in 120:
		var step: float = 1.0 / Balance.FOOTFALL_HZ
		for body: Node2D in crowd:
			body.global_position += Vector2.RIGHT * 100.0 * step
		feet._walk(step)
	_check(feet.live_marks() <= Balance.FOOTFALL_MAX_MARKS,
		("sixty bodies at a run must stay inside the cap: %d live against %d")
			% [feet.live_marks(), Balance.FOOTFALL_MAX_MARKS])
	# And the cap must not be so generous that it never engages, which would make
	# the check above true of a build with no cap at all.
	_check(feet.live_marks() >= Balance.FOOTFALL_MAX_MARKS / 2,
		("this probe must actually reach the cap or it proves nothing: %d live")
			% feet.live_marks())
	feet.get_parent().queue_free()
	for body: Node2D in crowd:
		body.queue_free()


## **The dust is the colour of the ground, and the ground is read.**
##
## `GroundTone` is the one reading, so two sheets of different colours must give
## two different answers - and a place with nothing laid must give the fallback
## rather than black, because a caller is promised it never has to check.
func _test_the_ground_decides_the_colour() -> void:
	_check(GroundTone.of(null) == Balance.GROUND_TONE_FALLBACK,
		"a missing sheet must read as plain earth")
	_check(GroundTone.at_path("res://art/does_not_exist.png")
			== Balance.GROUND_TONE_FALLBACK,
		"a path with no sheet must read as plain earth")
	var seen: Dictionary = {}
	var read: int = 0
	for value: Variant in ContentDB.terrains.values():
		var terrain := value as TerrainData
		if terrain == null:
			continue
		var path: String = terrain.get_sprite_path()
		if not ResourceLoader.exists(path):
			continue
		var tone: Color = GroundTone.at_path(path)
		read += 1
		_check(tone.r > 0.0 or tone.g > 0.0 or tone.b > 0.0,
			"%s must read as some colour rather than black" % terrain.id)
		seen[Vector3i(int(tone.r * 255.0), int(tone.g * 255.0),
			int(tone.b * 255.0))] = true
	_check(read >= 3, "this check must read several regions, read %d" % read)
	# Ten regions painted ten ways cannot honestly share one colour. Three is a
	# floor rather than a target: what it refuses is a reader that hands the same
	# answer back whatever it is given, which is what a cached-wrong or
	# constant-returning implementation looks like from outside.
	_check(seen.size() >= 3,
		("the regions must not all read as one colour: %d distinct over %d "
			+ "sheets") % [seen.size(), read])
	await get_tree().process_frame


## **Every kind of body that walks must declare a tread.**
##
## The driver has no branch in it, so a body that never registers is silently
## dustless for ever - which is exactly what "the feature is not built for
## wildlife" would look like, with every other check on this page green. A grep
## rather than a drive, because the failure is an *omission* and an omission is
## what a source walk sees. The same reasoning `debrief_check` walks its three
## deaths under.
func _test_every_body_that_walks_declares_a_tread() -> void:
	var owed: Dictionary = {
		"res://scenes/hero/hero.gd": "the Warden",
		"res://scenes/battlefield/enemy.gd": "a road body",
		"res://scenes/battlefield/companion.gd": "a raised companion",
		"res://scripts/systems/wildlife.gd": "an animal arriving",
		"res://scripts/systems/wildlife_families.gd": "an animal growing up",
	}
	for path: String in owed:
		var source: String = FileAccess.get_file_as_string(path)
		_check(source.contains("Footfalls.register"),
			"%s must declare a tread (%s names no registration)"
				% [owed[path], path])
	# And the Hold, which has no nodes to register because its people are
	# records - so it lays its own, and a build where it stopped would be a hub
	# whose Wardens walk without disturbing anything.
	var hold: String = FileAccess.get_file_as_string(
		"res://scripts/systems/hold_yard.gd")
	_check(hold.contains("_tick_treads"),
		"the Hold must scuff its own ground, having no nodes to register")
	# The scopes that paint. A body registers into a tree-wide group, so a scope
	# with no painter has bodies that leave nothing at all.
	for path: String in ["res://scenes/battlefield/battlefield.gd",
			"res://scenes/raid/raid_arena.gd"]:
		var source: String = FileAccess.get_file_as_string(path)
		_check(source.contains("Footfalls.new()"),
			"%s must stand up a painter or its bodies leave nothing" % path)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[footfalls] %s" % message)
