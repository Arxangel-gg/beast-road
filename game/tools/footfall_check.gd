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
	await _test_the_plants_answer_by_size()
	await _test_the_ground_keeps_the_prints()

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	await get_tree().create_timer(0.5).timeout
	Sfx.stop_immediately()
	if _failures == 0:
		print("[footfalls] PASS - %d checks: the stride, the mass, the cap, "
			% _checks + "the colour, the bodies that declare a tread, and plants that part by size and jiggle")
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
	# **Long enough that a build with no threshold would certainly scuff.**
	#
	# The first cut drifted for twenty frames, which at half the threshold covers
	# twelve units against a stride of forty-two - so it laid nothing whether the
	# guard was there or not, and passed with the guard deleted. Caught by
	# planting exactly that fault. The drift now covers several strides' worth of
	# ground, so the only thing that can keep it at zero is the threshold itself.
	var drift: float = 100.0 * Balance.FOOTFALL_MOVING * 0.5
	var stride: float = Balance.ENEMY_BODY_RADIUS * Balance.FOOTFALL_STRIDE
	var frames: int = int(ceil(stride * 4.0 / (drift / Balance.FOOTFALL_HZ)))
	_march(feet, body, Vector2.RIGHT, drift, frames)
	_check(feet.live_marks() == 0,
		("a body drifting under the moving threshold must lay nothing over %d "
			+ "strides of ground, laid %d")
			% [4, feet.live_marks()])
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


## **The plants answer what walks through them by its size** (owner,
## 2026-09-30). A small light body lays a narrow, gentle path and a big heavy
## one a wide, hard swathe; an animal's tread is read like anything else's;
## a body with no tread still brushes the stems; and the shader jiggles.
## Driven through the real stamp, counting the cells the field laid.
func _test_the_plants_answer_by_size() -> void:
	var field := TrampleField.new()
	field.half_extent = 2400.0
	add_child(field)
	var small: Node2D = _puppet(10.0, 0.4, 200.0)
	var large: Node2D = _puppet(60.0, 1.9, 200.0)
	small.global_position = Vector2(-1200.0, -1200.0)
	large.global_position = Vector2(1200.0, 1200.0)
	var small_reach: Vector2 = TrampleField.reach_of(small)
	var large_reach: Vector2 = TrampleField.reach_of(large)
	_check(large_reach.x > small_reach.x * 2.0 and large_reach.y > small_reach.y,
		"a big heavy body should lay wider and harder than a small light one: %s against %s" % [large_reach, small_reach])
	field._stamp(1.0 / 15.0)
	for _step: int in 6:
		small.global_position += Vector2(20.0, 0.0)
		large.global_position += Vector2(20.0, 0.0)
		field._stamp(1.0 / 15.0)
	var small_cells: int = 0
	var large_cells: int = 0
	var small_most: float = 0.0
	var large_most: float = 0.0
	for y: int in field.cells_across():
		for x: int in field.cells_across():
			var at: Vector2 = Vector2((float(x) + 0.5) * field.cell - field.half_extent,
				(float(y) + 0.5) * field.cell - field.half_extent)
			var laid: float = field.pressed_at(at)
			if laid <= 0.05:
				continue
			if at.x < 0.0:
				small_cells += 1
				small_most = maxf(small_most, laid)
			else:
				large_cells += 1
				large_most = maxf(large_most, laid)
	_check(small_cells > 0, "a small body walking through the grass laid nothing")
	_check(large_cells > small_cells * 2, "a big body laid %d cells and a small one %d - size did not widen it" % [large_cells, small_cells])
	_check(large_most > small_most, "a heavy body pressed %.2f and a light one %.2f" % [large_most, small_most])
	# An animal is a sprite with a tread and nothing else; it is read.
	var deer := Sprite2D.new()
	add_child(deer)
	var kind: WildlifeData = null
	for value: Variant in ContentDB.wildlife_kinds.values():
		var candidate := value as WildlifeData
		if candidate != null and not candidate.flies:
			kind = candidate
			break
	if kind != null:
		Footfalls.register_animal(deer, kind, 1.0)
	_check(field._movers().has(deer), "an animal walking the field is not one of the plants' movers")
	var ghost := Node2D.new()
	add_child(ghost)
	ghost.add_to_group(Enemy.GROUP)
	_check(field._movers().has(ghost) and is_equal_approx(TrampleField.reach_of(ghost).y, Balance.FOLIAGE_TRAMPLE_UNWEIGHED),
		"a body with no tread should still brush the stems, gently")
	var shader: String = Foliage.WIND_SHADER
	_check(shader.contains("trample_jiggle") and shader.contains("wobble"), "the foliage does not jiggle")
	# **Gently, and only as it springs back** (owner, 2026-10-01: the jiggle was
	# *"too extreme"*). Held flat under a body a plant is still, and the wobble
	# is bounded well under the 0.85 that flapped.
	_check(shader.contains("sin(clamp(laid.b, 0.0, 1.0) * PI)"),
		"the jiggle no longer waits for the spring-back - a held plant flaps")
	_check(Balance.FOLIAGE_TRAMPLE_JIGGLE <= 0.35 and Balance.FOLIAGE_TRAMPLE_JIGGLE_HZ <= 2.8,
		"the jiggle is %.2f at %.1f Hz - the owner called 0.85 at 3.4 Hz too extreme"
			% [Balance.FOLIAGE_TRAMPLE_JIGGLE, Balance.FOLIAGE_TRAMPLE_JIGGLE_HZ])
	_check(FileAccess.get_file_as_string("res://scripts/systems/trample_field.gd").contains("\"trample_jiggle\""),
		"the field never hands the foliage its jiggle")
	for node: Node2D in [small, large, deer, ghost]:
		node.queue_free()
	field.queue_free()
	await get_tree().process_frame


## **Footprints** (`Tracks`, 2026-09-30): one a stride, either side of the line
## walked in turn, none standing still or in water or below the effects floor,
## gone whole once they have faded, and never more than the cap holds.
func _test_the_ground_keeps_the_prints() -> void:
	var feet: Footfalls = _stand_up()
	var body: Node2D = _puppet(Balance.ENEMY_BODY_RADIUS, 1.0, 100.0)
	await get_tree().process_frame
	var tracks: Tracks = feet.tracks()
	_check(tracks != null, "the footfalls must lay prints")
	if tracks == null:
		return
	_march(feet, body, Vector2.ZERO, 0.0, 20)
	_check(tracks.showing() == 0, "standing still left %d prints" % tracks.showing())
	_march(feet, body, Vector2.RIGHT, 100.0, 30)
	var stride: float = Balance.ENEMY_BODY_RADIUS * Balance.FOOTFALL_STRIDE
	var walked: float = 100.0 * 30.0 / Balance.FOOTFALL_HZ
	var expected: int = int(walked / stride)
	_check(absi(tracks.showing() - expected) <= 1,
		"a walk of %.0f units at a %.0f stride left %d prints, not about %d" % [walked, stride,
		tracks.showing(), expected])
	var chunks: Array = tracks.get("_chunks")
	var alternates: bool = true
	var last_side: float = 0.0
	for chunk: Variant in chunks:
		for one: Dictionary in (chunk as Tracks.TrackChunk).prints:
			var side: float = signf((one["at"] as Vector2).y - body.global_position.y)
			if side == 0.0 or side == last_side:
				alternates = false
			last_side = side
	_check(alternates, "the prints must fall either side of the line walked, in turn")
	# Below the effects floor, nothing.
	var before: int = tracks.showing()
	tracks.press(Vector2(0.0, 500.0), Vector2.RIGHT, 20.0, 1.0, 1.0, Balance.TRACK_WEIGHT_FLOOR * 0.5)
	_check(tracks.showing() == before, "a print was laid below the effects floor")
	# Faded, and gone whole.
	tracks._process(Balance.TRACK_LIFE + 0.1)
	_check(tracks.showing() == 0 and tracks.chunk_count() == 0,
		"faded prints must be freed: %d showing on %d canvases" % [tracks.showing(), tracks.chunk_count()])
	# The cap.
	_march(feet, body, Vector2.RIGHT, 100.0, int(float(Balance.TRACK_MAX) * 3.0 * stride
		/ (100.0 / Balance.FOOTFALL_HZ)))
	_check(tracks.chunk_count() * Tracks.CHUNK <= Balance.TRACK_MAX + Tracks.CHUNK,
		"%d canvases of prints against a cap of %d" % [tracks.chunk_count(), Balance.TRACK_MAX])
	_check(tracks.showing() > Balance.TRACK_MAX / 2, "the cap must be reached, held %d" % tracks.showing())
	feet.get_parent().queue_free()
	body.queue_free()
	# Never in water.
	var scope := Node2D.new()
	add_child(scope)
	var wet := Footfalls.new()
	wet.ground = func(_at: Vector2) -> Color: return Color(0.5, 0.4, 0.3)
	wet.water = func(_at: Vector2) -> float: return 1.0
	scope.add_child(wet)
	var swimmer: Node2D = _puppet(Balance.ENEMY_BODY_RADIUS, 1.0, 100.0)
	await get_tree().process_frame
	_march(wet, swimmer, Vector2.RIGHT, 100.0, 30)
	_check(wet.tracks().showing() == 0, "a body in water left %d prints" % wet.tracks().showing())
	scope.queue_free()
	swimmer.queue_free()
	await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[footfalls] %s" % message)
