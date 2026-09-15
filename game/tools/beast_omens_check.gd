extends Node

## The road can see what the earth is doing to the town.
##
## Owner brief, 2026-09-15: the beast scope should indicate the battlefield's
## disasters - a funnel over the base, fire for a wildfire, water pouring off
## the platform when it floods, a world shake for a quake that moves Yuri too,
## and lightning.
##
## **The bound is that a readout reads.** Not one line of `BeastOmens` may
## change a number, roll a die or send a message: the two scopes are one run and
## the walk must not be able to alter the fight it is a view of. That is the
## same rule the fog of war is held to - it hides and never helps - and it is
## the first thing checked here, by snapshotting the run and driving every event
## the earth can publish.
##
## The rest is the failures a picture cannot show: an indication that never
## arrives, one that never leaves, and a quiet road that still costs something.

const WATCHED: Array[String] = [
	"flood", "rain_intensity", "storm_charge", "wrath", "ember", "gale",
	"tide", "tremor", "temperature", "beast_speed", "wave", "act",
]

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260915)
	await get_tree().process_frame
	await _test_every_disaster_reaches_the_road()
	await _test_a_readout_changes_nothing()
	await _test_nothing_stays_on_screen_for_ever()
	await _test_a_quake_moves_the_world_and_the_beast()
	_test_a_quiet_road_draws_nothing()
	_finish()


## Each thing the earth does has to arrive out here. A signal connected to
## nothing is the whole failure this guards: the field would carry on exactly as
## it does, and the road would carry on showing an evening stroll.
func _test_every_disaster_reaches_the_road() -> void:
	var omens: BeastOmens = _omens()
	_check(not omens.anything(), "a fresh road must be quiet")

	EventBus.tornado_spawned.emit(Vector2.ZERO, Vector2.ONE, 12.0)
	_check(omens.anything(), "a funnel must reach the road")
	await _quiet(omens)

	EventBus.wildfire_lit.emit(Vector2.ZERO)
	_check(omens.anything(), "a wildfire must reach the road")
	await _quiet(omens)

	EventBus.earthquake.emit(0.7, 4.0)
	_check(omens.anything(), "a quake must reach the road")
	_check(omens.quake_shake() > 0.0, "and it must shake something")
	await _quiet(omens)

	EventBus.lightning_struck.emit(Vector2.ZERO, 100.0)
	_check(omens.anything(), "a strike must reach the road")
	await _quiet(omens)

	EventBus.meteor_incoming.emit(Vector2.ZERO)
	_check(omens.anything(), "a meteor must reach the road")
	await _quiet(omens)

	# The flood is a standing condition rather than an event, so it is read
	# rather than heard - and reading it is the only way the water on the
	# platform can agree with the water on the field.
	RunState.flood = Balance.FLOOD_KNEE
	_check(omens.anything(), "standing water must reach the road")
	RunState.flood = 0.0
	omens.queue_free()


## **The one thing that must never happen.** Every event, one after another,
## against a snapshot of everything the run knows.
func _test_a_readout_changes_nothing() -> void:
	var omens: BeastOmens = _omens()
	var before: Dictionary = {}
	for key: String in WATCHED:
		before[key] = RunState.get(key)
	var seed_before: int = RunState.run_seed

	EventBus.tornado_spawned.emit(Vector2(10.0, 10.0), Vector2(20.0, 20.0), 9.0)
	EventBus.tornado_moved.emit(Vector2(12.0, 12.0), true)
	for _lit: int in 12:
		EventBus.wildfire_lit.emit(Vector2(5.0, 5.0))
	EventBus.earthquake.emit(1.0, 6.0)
	EventBus.lightning_struck.emit(Vector2(3.0, 3.0), 90.0)
	EventBus.meteor_incoming.emit(Vector2(4.0, 4.0))
	for _frame: int in 20:
		omens.call("_process", 0.05)
	await get_tree().process_frame

	for key: String in WATCHED:
		_check(is_same(RunState.get(key), before[key]),
			"the road's readout moved RunState.%s from %s to %s"
				% [key, str(before[key]), str(RunState.get(key))])
	_check(RunState.run_seed == seed_before,
		"and it must not have touched the run's seed")
	omens.queue_free()


## An indication that never leaves is worse than none: the player learns to
## ignore it. Every one of these decays on its own clock.
func _test_nothing_stays_on_screen_for_ever() -> void:
	var omens: BeastOmens = _omens()
	EventBus.tornado_spawned.emit(Vector2.ZERO, Vector2.ONE, 2.0)
	EventBus.earthquake.emit(0.9, 1.0)
	EventBus.lightning_struck.emit(Vector2.ZERO, 50.0)
	EventBus.meteor_incoming.emit(Vector2.ZERO)
	for _lit: int in int(Balance.BEAST_OMEN_FIRE_MAX) + 4:
		EventBus.wildfire_lit.emit(Vector2.ZERO)
	_check(omens.anything(), "everything at once must show")
	# Long enough for the slowest of them - the fires, which fade rather than
	# being counted out.
	for _frame: int in 1200:
		omens.call("_process", 0.1)
	_check(not omens.anything(),
		"and two minutes later the road must be quiet again")
	_check(is_zero_approx(omens.quake_shake()),
		"the ground must have stopped moving (%0.3f)" % omens.quake_shake())
	await get_tree().process_frame
	omens.queue_free()


## **A quake moves Yuri, not only the camera.** Moving the camera alone reads as
## the operator flinching; the beast is standing on the ground that is moving.
func _test_a_quake_moves_the_world_and_the_beast() -> void:
	var omens: BeastOmens = _omens()
	EventBus.earthquake.emit(1.0, 5.0)
	_check(omens.quake_shake() > 0.5,
		"a full quake must read as a full shake (%0.3f)" % omens.quake_shake())
	_check(omens.quake_shake() <= 1.0,
		"and never more than one, whatever the magnitude (%0.3f)" % omens.quake_shake())
	EventBus.earthquake.emit(9.0, 5.0)
	_check(omens.quake_shake() <= 1.0,
		"a magnitude of nine must still clamp (%0.3f)" % omens.quake_shake())
	# The scope reads this and applies it to both; the constant is what bounds
	# how far either may move.
	_check(Balance.BEAST_QUAKE_SHAKE > 0.0 and Balance.BEAST_QUAKE_SHAKE <= 24.0,
		("the world shake is %0.1f px: past a couple of dozen it stops being an "
			+ "earthquake and becomes a broken camera") % Balance.BEAST_QUAKE_SHAKE)
	var scope := FileAccess.open("res://scenes/run/beast_scope.gd", FileAccess.READ)
	if scope != null:
		var code: String = scope.get_as_text()
		_check(code.contains("beast.position += _quake_offset"),
			"the beast itself must take the quake, not only the camera")
	for _frame: int in 200:
		omens.call("_process", 0.1)
	await get_tree().process_frame
	omens.queue_free()


## A quiet road must cost nothing: `anything()` is what lets the scope skip it.
func _test_a_quiet_road_draws_nothing() -> void:
	RunState.flood = 0.0
	var omens: BeastOmens = _omens()
	for _frame: int in 40:
		omens.call("_process", 0.1)
	_check(not omens.anything(),
		"a road with nothing happening on it must report nothing")
	omens.queue_free()


func _omens() -> BeastOmens:
	var node := BeastOmens.new()
	add_child(node)
	return node


## Run one down to nothing again, so the next assertion starts from quiet.
func _quiet(omens: BeastOmens) -> void:
	for _frame: int in 900:
		omens.call("_process", 0.1)
	await get_tree().process_frame


func _finish() -> void:
	RunState.flood = 0.0
	for _frame: int in 4:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("[beast-omens] PASS - %d checks: every disaster reaches the road, the readout changes nothing, nothing stays for ever, and a quake moves Yuri" % _checks)
	else:
		push_error("[beast-omens] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[beast-omens] FAIL: %s" % why)
