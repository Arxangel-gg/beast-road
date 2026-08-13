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

## Keyed tint stops. Multiplied over the whole world by a CanvasModulate, so
## these are *filters*: nothing here can brighten, only colour and darken.
const STOPS: Array[Dictionary] = [
	{"at": 0.00, "tint": Color(0.72, 0.60, 0.58), "light": 0.55},  # dawn, cold and low
	{"at": 0.12, "tint": Color(1.00, 0.97, 0.92), "light": 0.05},  # morning
	{"at": 0.28, "tint": Color(1.00, 1.00, 1.00), "light": 0.00},  # midday, unfiltered
	{"at": 0.45, "tint": Color(0.95, 0.74, 0.52), "light": 0.35},  # late afternoon gold
	{"at": 0.56, "tint": Color(0.52, 0.31, 0.34), "light": 0.74},  # dusk
	{"at": 0.70, "tint": Color(0.17, 0.21, 0.38), "light": 0.97},  # night, blue
	{"at": 0.85, "tint": Color(0.10, 0.13, 0.27), "light": 1.00},  # deep night
	{"at": 1.00, "tint": Color(0.72, 0.60, 0.58), "light": 0.55},  # back to dawn
]

## The phase changed enough to be worth reacting to.
signal phase_changed(phase: float, tint: Color, darkness: float)

## Crossed into or out of night.
signal night_changed(is_night: bool)

var phase: float = 0.18
var tint: Color = Color.WHITE

## 0 at midday, 1 at deep night. What lights are scaled by.
var darkness: float = 0.0

var _was_night: bool = false


func _ready() -> void:
	EventBus.distance_changed.connect(_on_distance)
	EventBus.run_started.connect(func() -> void: _apply(Balance.DAY_START_PHASE))
	_apply(Balance.DAY_START_PHASE)


func _on_distance(total_distance: float, _to_crossroad: float) -> void:
	_apply(fmod(Balance.DAY_START_PHASE + total_distance / DAY_LENGTH, 1.0))


## True while the night difficulty modifiers apply.
func is_night() -> bool:
	return darkness >= Balance.NIGHT_THRESHOLD


## Multiplier on enemy count and stats. Night is meant to be felt as pressure,
## not just as a colour grade.
func difficulty_multiplier() -> float:
	return 1.0 + darkness * Balance.NIGHT_DIFFICULTY_BONUS


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
	tint = (lower["tint"] as Color).lerp(upper["tint"] as Color, t)
	darkness = lerpf(float(lower["light"]), float(upper["light"]), t)

	phase_changed.emit(phase, tint, darkness)

	var night_now: bool = is_night()
	if night_now != _was_night:
		_was_night = night_now
		night_changed.emit(night_now)
