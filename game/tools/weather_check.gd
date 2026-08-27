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

	for act: int in [1, 2, 3]:
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

	if _failures == 0:
		print("[weather] PASS - every sky reachable everywhere, each act still "
			+ "led by its own")
	else:
		printerr("[weather] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


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
