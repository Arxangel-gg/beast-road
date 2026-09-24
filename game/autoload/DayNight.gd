extends Node

## The day/night cycle: the light, the mood, and how hard the night is.
##
## Time of day is driven by **distance travelled**, not by a wall clock. The
## beast walking is the game's only real clock, and tying the sky to it means a
## slow, punished run genuinely spends longer in the dark — which is the version
## where the cycle is a consequence of play rather than a timer running beside it.
##
## Phase 0.0 is dawn, 0.25 midday, 0.5 dusk, 0.75 midnight.

## One full day per this many distance units. [TUNE]
const DAY_LENGTH: float = 420.0

## Keyed tint stops, deliberately wide apart.
##
## The ramp used to bottom out around 0.30 grey-blue, which is dim but not dark,
## and a dim field has no contrast in it: everything is a little grey and nothing
## reads as lit. Deep night now lands near 0.15 and the torches were widened and
## brightened to match, so the night is genuinely dark and the lit ground is
## genuinely lit. Midday is untouched - the arc is what carries the day, and
## flattening the top would cost the contrast the bottom just gained.
##
## Multiplied over the whole world by a CanvasModulate, so
## these are *filters*: nothing here can brighten, only colour and darken.
const STOPS: Array[Dictionary] = [
	{"at": 0.00, "tint": Color(0.62, 0.55, 0.58), "light": 0.62},  # dawn, cold and low
	{"at": 0.12, "tint": Color(0.98, 0.94, 0.88), "light": 0.08},  # morning
	{"at": 0.28, "tint": Color(1.00, 1.00, 1.00), "light": 0.00},  # midday, unfiltered
	{"at": 0.45, "tint": Color(0.98, 0.74, 0.52), "light": 0.40},  # late afternoon gold
	{"at": 0.56, "tint": Color(0.55, 0.35, 0.42), "light": 0.82},  # dusk
	{"at": 0.70, "tint": Color(0.22, 0.27, 0.44), "light": 0.99},  # blue night
	{"at": 0.85, "tint": Color(0.13, 0.17, 0.33), "light": 1.00},  # deep night
	{"at": 1.00, "tint": Color(0.62, 0.55, 0.58), "light": 0.62},  # back to dawn
]

## The phase changed enough to be worth reacting to.
signal phase_changed(phase: float, tint: Color, darkness: float)

## Crossed into or out of night.
signal night_changed(is_night: bool)

var phase: float = 0.18
var tint: Color = Color.WHITE

## 0 at midday, 1 at deep night. What lights are scaled by.
var darkness: float = 0.0

## Underground, the sun is somewhere else (2026-09-14). A rift publishes deep
## night to every light and tint - `darkness` 1, a tint of its own - while
## the sun's own reading is kept for `is_night()` and the difficulty, so the
## night's teeth stay on the road rather than following the player down.
var underground: bool = false
var _sun_tint: Color = Color.WHITE
var _sun_darkness: float = 0.0
var _deep_tint: Color = Color(0.3, 0.31, 0.4)

var _was_night: bool = false


func _ready() -> void:
	EventBus.distance_changed.connect(_on_distance)
	EventBus.run_started.connect(func() -> void: _apply(Balance.DAY_START_PHASE))
	_apply(Balance.DAY_START_PHASE)


func _on_distance(total_distance: float, _to_crossroad: float) -> void:
	var wanted: float = fmod(Balance.DAY_START_PHASE + total_distance / DAY_LENGTH, 1.0)
	# Applied on a phase step rather than every frame (`DAYNIGHT_PHASE_STEP`).
	if absf(wanted - phase) < Balance.DAYNIGHT_PHASE_STEP:
		return
	_apply(wanted)


## True while the night difficulty modifiers apply. The sun's, never the deep's.
func is_night() -> bool:
	return _sun_darkness >= Balance.NIGHT_THRESHOLD


## Multiplier on enemy count and stats. Night is meant to be felt as pressure,
## not just as a colour grade. The sun's, never the deep's.
func difficulty_multiplier() -> float:
	return 1.0 + _sun_darkness * Balance.NIGHT_DIFFICULTY_BONUS


## The sun's own darkness, whatever is published: what the road's weather and
## its waves read while a player is underground.
func sun_darkness() -> float:
	return _sun_darkness


## Down into the deep, or back up. Publishes the change at once.
func set_underground(on: bool, deep_tint: Color = Color(0.3, 0.31, 0.4)) -> void:
	# There is no weather down here. One flag beside the light, because the two
	# are the same fact - the sky cannot reach this place - and keeping them in
	# one call is what stops a future arena from remembering the dark and
	# forgetting the air.
	RunState.wind_sheltered = on
	underground = on
	_deep_tint = deep_tint
	_publish()


## What every light and tint reads: the deep's dark underground, the sun's
## otherwise.
func _publish() -> void:
	tint = _deep_tint if underground else _sun_tint
	darkness = 1.0 if underground else _sun_darkness
	phase_changed.emit(phase, tint, darkness)


## Human-readable, for the HUD.
func clock_text() -> String:
	# Phase 0 is dawn, so 06:00 is the anchor.
	var hours: float = fmod(phase * 24.0 + 6.0, 24.0)
	return "%02d:%02d" % [int(hours), int(fmod(hours, 1.0) * 60.0)]


func label() -> String:
	if phase < 0.10:
		return "Dawn"
	if phase < 0.40:
		return "Day"
	if phase < 0.52:
		return "Afternoon"
	if phase < 0.66:
		return "Dusk"
	return "Night"


func _apply(new_phase: float) -> void:
	phase = fmod(maxf(new_phase, 0.0), 1.0)

	# Find the two stops we sit between and blend.
	var lower: Dictionary = STOPS[0]
	var upper: Dictionary = STOPS[STOPS.size() - 1]
	for i: int in STOPS.size() - 1:
		if phase >= float(STOPS[i]["at"]) and phase <= float(STOPS[i + 1]["at"]):
			lower = STOPS[i]
			upper = STOPS[i + 1]
			break

	var span: float = maxf(float(upper["at"]) - float(lower["at"]), 0.0001)
	var t: float = clampf((phase - float(lower["at"])) / span, 0.0, 1.0)
	_sun_tint = (lower["tint"] as Color).lerp(upper["tint"] as Color, t)
	_sun_darkness = lerpf(float(lower["light"]), float(upper["light"]), t)
	_publish()

	var night_now: bool = is_night()
	if night_now != _was_night:
		_was_night = night_now
		night_changed.emit(night_now)
