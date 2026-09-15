extends Node

## The wind: where it blows, what it costs to walk into, and how little of it
## has to cross the wire.
##
## Owner brief, 2026-09-15: "an aesthetically appealing wind system that can
## blow in any cardinal direction and can change its strength. The wind can
## affect movement speed for all characters slowing them against the wind or
## speeding them up in its direction. Wind direction should have optimized coop
## replication but foliage animation etc is not replicated of course but
## simulated on each client from the replicated wind updates they receive."
##
## **This is the one addition in a long line that is allowed to move a gameplay
## number**, so the bulk of this file is the four properties that keep it from
## becoming a difficulty setting nobody chose. They are stated on
## `Balance.WIND_PUSH_MAX` and driven here:
##
## - symmetric - the same dot product and the same cap for every mover;
## - capped - no combination of gust and weather exceeds `WIND_PUSH_MAX`;
## - it averages to nothing - the heading reaches every quarter of the compass,
##   so over a run and across four roads there is no free ride in it;
## - never felt indoors.
##
## And the wire: a message only when the wind has actually moved, never on a
## clock, and nothing about foliage in it at all.

var _failures: int = 0
var _checks: int = 0
var _sky: WeatherSky = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260915)
	_sky = WeatherSky.new()
	add_child(_sky)
	await get_tree().process_frame
	_test_the_push_is_bounded_and_symmetric()
	_test_nothing_blows_indoors()
	_test_the_heading_reaches_every_quarter()
	_test_a_turn_is_a_turn_and_not_a_switch()
	_test_the_wire_carries_the_wind_and_nothing_it_moves()
	_finish()


## The whole of the bound, read off the one function that owns it.
func _test_the_push_is_bounded_and_symmetric() -> void:
	RunState.wind_sheltered = false
	RunState.wind = Vector2.RIGHT
	var with_it: float = RunState.wind_push(Vector2.RIGHT)
	var into_it: float = RunState.wind_push(Vector2.LEFT)
	var across: float = RunState.wind_push(Vector2.DOWN)
	_check(is_equal_approx(with_it, 1.0 + Balance.WIND_PUSH_MAX),
		"walking with a full wind must gain exactly the cap (%0.4f)" % with_it)
	_check(is_equal_approx(into_it, 1.0 - Balance.WIND_PUSH_MAX),
		"and walking into it must cost exactly the cap (%0.4f)" % into_it)
	_check(is_equal_approx(across, 1.0),
		"a crosswind must cost nothing (%0.4f)" % across)
	_check(is_equal_approx((with_it - 1.0) + (into_it - 1.0), 0.0),
		"the two must cancel: %0.4f and %0.4f" % [with_it, into_it])
	# **No gust may exceed the cap.** The wind is a gusting vector and nothing
	# clamps its length before this, so an overlong one has to be clamped here
	# or the cap is a suggestion.
	RunState.wind = Vector2.RIGHT * 9.0
	_check(RunState.wind_push(Vector2.RIGHT) <= 1.0 + Balance.WIND_PUSH_MAX + 0.0001,
		"a gust nine times full must still not exceed the cap (%0.4f)"
			% RunState.wind_push(Vector2.RIGHT))
	_check(RunState.wind_push(Vector2.LEFT) >= 1.0 - Balance.WIND_PUSH_MAX - 0.0001,
		"nor below it (%0.4f)" % RunState.wind_push(Vector2.LEFT))
	# Still air, and a mover going nowhere.
	RunState.wind = Vector2.ZERO
	_check(is_equal_approx(RunState.wind_push(Vector2.RIGHT), 1.0),
		"still air must cost nothing")
	RunState.wind = Vector2.RIGHT
	_check(is_equal_approx(RunState.wind_push(Vector2.ZERO), 1.0),
		"and something standing still must not be pushed")
	# Small enough to be weather rather than a build.
	_check(Balance.WIND_PUSH_MAX <= 0.15,
		("the wind may take at most a seventh of a character's speed: %0.3f is a "
			+ "power scale nobody is tuning") % Balance.WIND_PUSH_MAX)


## A raid camp under a cliff and a maze under a rift have no weather, and the
## flag that says so is the same one that takes the sun away.
func _test_nothing_blows_indoors() -> void:
	RunState.wind = Vector2.RIGHT
	DayNight.set_underground(true)
	_check(RunState.wind_sheltered, "going underground must shelter the party")
	_check(is_equal_approx(RunState.wind_push(Vector2.RIGHT), 1.0),
		"and nothing may be pushed down there (%0.4f)"
			% RunState.wind_push(Vector2.RIGHT))
	DayNight.set_underground(false)
	_check(not RunState.wind_sheltered, "and coming back up must unshelter it")
	_check(RunState.wind_push(Vector2.RIGHT) > 1.0,
		"and the wind must be felt again")


## **Every quarter of the compass, which is what makes it fair.** A wind that
## only ever blew along one axis would hurry two of the four roads and hold two
## back for the whole run - which is exactly what the east-west wind this
## replaced did, and the reason the brief asks for any cardinal direction.
func _test_the_heading_reaches_every_quarter() -> void:
	_sky.set("_weather", ContentDB.weather("clear"))
	var seen: Dictionary = {}
	var strongest: float = 0.0
	for step: int in 4000:
		_sky.set("_clock", float(step) * 3.0)
		var heading: float = _sky.wind_heading()
		seen[int(floor(wrapf(heading + PI * 0.25, 0.0, TAU) / (PI * 0.5)))] = true
		strongest = maxf(strongest, _sky.wind().length())
	_check(seen.size() == 4,
		"the wind must reach all four quarters over a run, not %d" % seen.size())
	# And it must actually blow: a heading with no strength behind it is a
	# compass needle rather than weather.
	# Against the weather's own authored strength rather than a number written
	# here: "clear" blows at 0.18 and a duststorm at 0.95, and a threshold
	# chosen by hand would either pass on a dead calm or fail on a fair day.
	var authored: float = absf((ContentDB.weather("clear") as WeatherData).wind)
	_check(strongest >= authored * 0.99,
		"the wind must actually reach what its weather authors (%0.3f of %0.3f)"
			% [strongest, authored])


## A turn takes time. A heading that snapped through ninety degrees between one
## frame and the next would shove every character on the field sideways, which
## is a state change wearing weather's clothes.
func _test_a_turn_is_a_turn_and_not_a_switch() -> void:
	_sky.set("_weather", ContentDB.weather("clear"))
	var worst: float = 0.0
	var previous: float = 0.0
	for step: int in 6000:
		_sky.set("_clock", float(step) * 0.1)
		var heading: float = _sky.wind_heading()
		if step > 0:
			worst = maxf(worst, absf(wrapf(heading - previous, -PI, PI)))
		previous = heading
	# A tenth of a second of the fastest legal turn, with room for the wander
	# riding on top of it. The rate is the same for a quarter and a reversal -
	# see `wind_heading`, where the duration scales with the swing - so this is
	# one number and not two.
	var allowed: float = PI * 0.5 / maxf(Balance.WIND_TURN_SECONDS, 0.001) * 0.1 * 3.0
	_check(worst <= allowed,
		"the heading jumped %0.3f rad in a tenth of a second, against %0.3f allowed"
			% [worst, allowed])


## **The wire carries two numbers and nothing else.**
##
## Driven rather than read: the host's own publisher is run over a stretch of
## clock and every message it emits is counted. A test that read the constants
## would pass with the threshold ignored.
func _test_the_wire_carries_the_wind_and_nothing_it_moves() -> void:
	_sky.set("_weather", ContentDB.weather("duststorm"))
	_sky.set("_wind_told", Vector2.ZERO)
	_sky.set("_wind_told_at", -1000.0)
	var sent: Array[Vector2] = []
	var watch := func(blowing: Vector2) -> void: sent.append(blowing)
	EventBus.wind_changed.connect(watch)
	var seconds: float = 600.0
	var step: float = 0.05
	for index: int in int(seconds / step):
		_sky.set("_clock", float(index) * step)
		_sky.call("_set_wind", _sky.wind())
	EventBus.wind_changed.disconnect(watch)
	var rate: float = float(sent.size()) / seconds
	_check(not sent.is_empty(), "the host must tell the guests the wind at all")
	# On a clock this would be 1/WIND_RELAY_INTERVAL a second for ten minutes.
	# On a threshold it is silent through a settled quarter and talks through a
	# turn, so the rate has to be well under that ceiling to mean anything.
	var ceiling: float = 1.0 / maxf(Balance.WIND_RELAY_INTERVAL, 0.001)
	_check(rate < ceiling * 0.5,
		("the wind must be sent on a threshold, not a clock: %0.2f messages a "
			+ "second against a clock's %0.2f") % [rate, ceiling])
	# And never faster than the floor allows, whatever the sky does.
	_check(rate <= ceiling + 0.01,
		"%0.2f messages a second exceeds the interval's own ceiling" % rate)

	# A guest eases rather than snaps, and hears the first one outright so a
	# rejoining player is not walking through still air.
	var guest := WeatherSky.new()
	add_child(guest)
	guest.set("_weather", ContentDB.weather("storm"))
	RunState.wind = Vector2.ZERO
	guest.hear_wind(Vector2(0.8, 0.0))
	_check(RunState.wind.is_equal_approx(Vector2(0.8, 0.0)),
		"the first wind a guest hears must land outright (%s)" % str(RunState.wind))
	guest.hear_wind(Vector2(-0.8, 0.0))
	_check(RunState.wind.is_equal_approx(Vector2(0.8, 0.0)),
		"and the next must not snap: the guest is still at %s" % str(RunState.wind))
	guest.queue_free()

	# The one thing that must never appear on the wire.
	var relay := FileAccess.open("res://scripts/systems/coop_relay.gd", FileAccess.READ)
	if relay != null:
		var code: String = relay.get_as_text()
		_check(not code.contains("Foliage."),
			("no foliage state may cross the wire: it is simulated on each "
				+ "machine from the two numbers the wind is"))


func _finish() -> void:
	RunState.wind_sheltered = false
	if _sky != null:
		_sky.queue_free()
	for _frame: int in 6:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("[wind] PASS - %d checks: bounded and symmetric, nothing indoors, every quarter of the compass, and two numbers on the wire" % _checks)
	else:
		push_error("[wind] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[wind] FAIL: %s" % why)
