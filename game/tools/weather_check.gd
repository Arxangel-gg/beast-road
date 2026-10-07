extends Node

## Every sky is possible everywhere, and the local one is still the likely one.
##
## Weather used to be gated by act: `acts` decided eligibility, so Act III could
## produce exactly two skies and - with `clear` weighted 3.0 and admitted
## everywhere - better than half of all roads were clear. The region read as
## itself by having nothing else to offer, which is not the same as having
## character.
##
## The gate is a preference now, and this asserts both halves of that: nothing is
## excluded from anywhere, and the weather that belongs to an act still leads it.
## Measured by rolling, not by reading the weights, because `roll_weather` also
## refuses to repeat itself and that changes the distribution it actually
## produces.

const ROLLS: int = 4000

## No sky may be rarer than this anywhere. Low on purpose - snow in the jungle
## should be a surprise, not a regular occurrence - but never zero.
const FLOOR: float = 0.02

## The weather an act owns must be at least this likely.
const LOCAL_FLOOR: float = 0.20

var _failures: int = 0


func _ready() -> void:
	var owners: Dictionary = {}
	for value: Variant in ContentDB.weathers.values():
		var weather := value as WeatherData
		if weather == null:
			continue
		for act: int in weather.acts:
			owners[act] = String(weather.id) if not owners.has(act) else owners[act]

	# **Every act on the road, the summit included** (2026-09-30). This walked
	# `[1, 2, 3]` on a road of eleven - the seventh hardcoded three-act range
	# this project has found - so no act past III had a sky of its own and
	# nothing said so.
	for act: int in range(1, Balance.FINAL_ASCENT_ACT + 1):
		var share: Dictionary = _sample(act)
		var line: PackedStringArray = []
		var ids: Array = share.keys()
		ids.sort()
		for id: Variant in ids:
			line.append("%s %.0f%%" % [String(id), 100.0 * float(share[id])])
		print("[weather] Act %d: %s" % [act, "  ".join(line)])

		_check(share.size() == ContentDB.weathers.size(),
			"every sky must be possible in act %d, saw %d of %d"
				% [act, share.size(), ContentDB.weathers.size()])
		for id: Variant in share.keys():
			_check(float(share[id]) >= FLOOR,
				"%s is %.1f%% in act %d, below the %.0f%% floor"
					% [String(id), 100.0 * float(share[id]), act, 100.0 * FLOOR])
		if owners.has(act):
			var local: String = String(owners[act])
			_check(float(share.get(local, 0.0)) >= LOCAL_FLOOR,
				"act %d should feel like %s, but it is only %.0f%% of roads"
					% [act, local, 100.0 * float(share.get(local, 0.0))])

	_test_a_front_comes_in()
	if _failures == 0:
		print("[weather] PASS - every sky reachable everywhere, each act still "
			+ "led by its own, and rain on a clear sky comes in as a front")
	else:
		printerr("[weather] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	for _f: int in 10:
		await get_tree().process_frame
	Sfx.stop_immediately()
	get_tree().quit(1 if _failures > 0 else 0)


## **A front** (triage of 2026-10-07): falling weather on a clear sky starts as
## a front from the side the wind blows from, walks at its speed in world units,
## and finishes; one falling weather turning into another starts no front.
func _test_a_front_comes_in() -> void:
	var veil := WeatherVeil.new()
	add_child(veil)
	var wind_was: Vector2 = RunState.wind
	var rain: String = ""
	var snow: String = ""
	for value: Variant in ContentDB.weathers.values():
		var weather := value as WeatherData
		if weather == null:
			continue
		if weather.precipitation == WeatherData.Precipitation.RAIN and rain.is_empty():
			rain = weather.id
		if weather.precipitation == WeatherData.Precipitation.SNOW and snow.is_empty():
			snow = weather.id
	_check(not rain.is_empty() and not snow.is_empty(), "no rain or no snow to bring in")
	RunState.wind = Vector2(-1.0, 0.0)
	veil.call("_on_weather_changed", "clear")
	veil.call("_process_measured", 10.0)
	veil.call("_on_weather_changed", rain)
	_check(veil.front() < 0.9, "rain on a clear sky fell everywhere at once (front %.2f)" % veil.front())
	_check(veil.front_from().is_equal_approx(Vector2(1.0, 0.0)),
		"a wind blowing west brought the front from %s, not the east" % veil.front_from())
	# Its rate is its speed over the sky's length along it, in world units.
	var length: float = veil.get("_rect").size.x
	_check(is_equal_approx(veil.front_rate(), Balance.WEATHER_FRONT_SPEED / length),
		"the front walks %.4f of the sky a second against %.4f" % [veil.front_rate(),
			Balance.WEATHER_FRONT_SPEED / length])
	var was: float = veil.front()
	veil.call("_process_measured", 1.0)
	_check(is_equal_approx(veil.front() - was, minf(veil.front_rate(), 1.0 - was)),
		"a second moved the front %.3f, not its rate" % (veil.front() - was))
	veil.call("_process_measured", 1.0 / maxf(veil.front_rate(), 0.001))
	_check(is_equal_approx(veil.front(), 1.0), "the front never finished crossing (%.2f)" % veil.front())
	veil.call("_process_measured", 10.0)
	veil.call("_on_weather_changed", snow)
	_check(is_equal_approx(veil.front(), 1.0), "rain turning to snow started a front (%.2f)" % veil.front())
	RunState.wind = wind_was
	veil.queue_free()


## What `roll_weather` actually produces over a long stretch of roads.
func _sample(act: int) -> Dictionary:
	var was_act: int = RunState.act
	var was_weather: String = RunState.weather_id
	RunState.act = act
	var seen: Dictionary = {}
	for i: int in ROLLS:
		RunState.roll_weather()
		seen[RunState.weather_id] = int(seen.get(RunState.weather_id, 0)) + 1
	RunState.act = was_act
	RunState.weather_id = was_weather
	var share: Dictionary = {}
	for id: Variant in seen.keys():
		share[id] = float(seen[id]) / float(ROLLS)
	return share


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[weather] FAIL: %s" % why)
