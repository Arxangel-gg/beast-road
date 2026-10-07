class_name AudioBuses
extends RefCounted

## Creates the Master / Music / SFX buses, from whichever audio autoload readies
## first.
##
## This exists because of a real bug: bus creation lived in Sfx._ready(), and
## MusicPlayer is an earlier autoload. MusicPlayer therefore assigned
## `bus = "Music"` before that bus existed, silently landed on Master, and the
## music volume slider controlled nothing. Ambience, which readies *after* Sfx,
## worked fine - which is exactly why only the ambience was audible.
##
## Every audio autoload now calls `ensure()` before touching a bus name, so the
## order they are listed in project.godot stops mattering.

const MUSIC: String = "Music"
const SFX: String = "SFX"
## The ambience bed and the weather each get a bus of their own (owner brief,
## 2026-09-12: a slider for the ambience, and one for the weather separate
## from it), so a player who wants the birds and not the rain can have that.
const AMBIENCE: String = "Ambience"
const WEATHER: String = "Weather"

## **Where a sound is across the screen, and whether something stands
## between it and the ear** (owner, 2026-10-07: *"Ensure that sounds are all
## properly playing location based ... so that the player is better able to
## hear sounds spatially. If possible to make it with optimization, also
## include elements for occlusion from the environment on the audio."*).
##
## A voice is a plain `AudioStreamPlayer`, which cannot pan, and a per-voice
## low-pass is a bus effect. So placement is a handful of buses under SFX - a
## panner each, from hard left to hard right in `PAN_STEPS`, and the same
## again with a low-pass for a sound heard through a wall - and a voice is
## sent to the one its sound wants. Ten buses, built once, and nothing a frame.
const PAN_STEPS: int = 5
static var _placed: bool = false


## How much of the master fader is currently being let through, 0 to 1.
##
## **A duck on top of the player's own volumes rather than a change to them.**
## The hush after a boss falls has to be able to take the room down to almost
## nothing and hand it straight back, and it must not touch a single slider on
## the way - a player who finds their music at 12% after an act would have no
## idea why, and the settings screen would be telling them the truth about a
## value nothing was using.
static var _hush: float = 1.0

## How settled the music is, 0 (as mixed) to 1 (Preparation's calm). Rides on
## the music bus as a low-pass and a trim, never on the player's slider.
static var _calm: float = 0.0
## Where the low-pass sits on the music bus, once it has been put there.
static var _calm_effect: int = -1
## The calm last written to the bus. Kept apart from `_calm` so a frame's small
## step is always *counted* and only the bus work is skipped - skipping the step
## itself stalled the fade at a high frame rate, where every step is small.
static var _calm_applied: float = -1.0

## How near death the local Warden is, 0 (not) to 1 (nothing left): a low-pass
## closing over the world's buses (`set_near_death`). The filter each bus wears,
## by bus name, so it is found again whatever else that bus carries.
static var _near: float = 0.0
static var _near_applied: float = -1.0
static var _near_filters: Dictionary = {}


## Lets the room back in, or takes it away. 1 is the game as mixed.
static func set_hush(share: float) -> void:
	var want: float = clampf(share, 0.0, 1.0)
	if is_equal_approx(want, _hush):
		return
	_hush = want
	apply_volumes()


static func hush_share() -> float:
	return _hush


## Settles the music toward calm (1) or opens it back up (0).
static func set_calm(share: float) -> void:
	_calm = clampf(share, 0.0, 1.0)
	var ends: bool = _calm <= 0.0 or _calm >= 1.0
	if _calm_effect >= 0 and absf(_calm - _calm_applied) < 0.002 and not ends:
		return
	_calm_applied = _calm
	ensure()
	var bus: int = AudioServer.get_bus_index(MUSIC)
	if bus < 0:
		return
	if _calm_effect < 0 or _calm_effect >= AudioServer.get_bus_effect_count(bus):
		AudioServer.add_bus_effect(bus, AudioEffectLowPassFilter.new())
		_calm_effect = AudioServer.get_bus_effect_count(bus) - 1
	var filter := AudioServer.get_bus_effect(bus, _calm_effect) as AudioEffectLowPassFilter
	if filter != null:
		# Along the ear's scale rather than the number line: a linear sweep
		# spends most of its time above anything anybody can hear change.
		filter.cutoff_hz = exp(lerpf(log(20000.0), log(Balance.MUSIC_CALM_CUTOFF_HZ), _calm))
	# Off entirely when fully open, so the game as mixed is the game as mixed.
	AudioServer.set_bus_effect_enabled(bus, _calm_effect, _calm > 0.002)
	apply_volumes()


static func calm_share() -> float:
	return _calm


## **Closes the world's sound over a Warden near death** (0 open, 1 shut to
## `NEAR_DEATH_CUTOFF_HZ`). On the placed sounds, the ambience and the weather -
## never the SFX bus itself, so what is played flat stays clear: the interface,
## a telegraph's warning, the wall being struck, and the heart. Off entirely at
## 0, so the game as mixed is the game as mixed.
static func set_near_death(share: float) -> void:
	_near = clampf(share, 0.0, 1.0)
	var ends: bool = _near <= 0.0 or _near >= 1.0
	if _near_applied >= 0.0 and (is_equal_approx(_near, _near_applied)
			or (absf(_near - _near_applied) < 0.01 and not ends)):
		return
	_near_applied = _near
	ensure()
	var on: bool = _near > 0.002
	var cutoff: float = exp(lerpf(log(20000.0), log(Balance.NEAR_DEATH_CUTOFF_HZ), _near))
	for name: String in near_death_buses():
		var bus: int = AudioServer.get_bus_index(name)
		if bus < 0:
			continue
		var index: int = _near_filter_index(bus, name, on)
		if index < 0:
			continue
		(AudioServer.get_bus_effect(bus, index) as AudioEffectLowPassFilter).cutoff_hz = cutoff
		AudioServer.set_bus_effect_enabled(bus, index, on)


static func near_death_share() -> float:
	return _near


## The buses the edge of death closes over: every placement bus, the ambience
## and the weather.
static func near_death_buses() -> PackedStringArray:
	var out := PackedStringArray([AMBIENCE, WEATHER])
	for muffled: bool in [false, true]:
		for step: int in PAN_STEPS:
			out.append(placement_name(step, muffled))
	return out


## Whether a bus is closed over and how far: `{on, cutoff}`. For the gate.
static func near_death_state(name: String) -> Dictionary:
	var bus: int = AudioServer.get_bus_index(name)
	var filter := _near_filters.get(name, null) as AudioEffectLowPassFilter
	if bus < 0 or filter == null:
		return {"on": false, "cutoff": 20000.0}
	for index: int in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, index) == filter:
			return {"on": AudioServer.is_bus_effect_enabled(bus, index), "cutoff": filter.cutoff_hz}
	return {"on": false, "cutoff": 20000.0}


## Where this bus's near-death filter sits, putting one there if it is wanted
## and missing - but never adding one only to switch it off.
static func _near_filter_index(bus: int, name: String, wanted: bool) -> int:
	var filter := _near_filters.get(name, null) as AudioEffectLowPassFilter
	if filter != null:
		for index: int in AudioServer.get_bus_effect_count(bus):
			if AudioServer.get_bus_effect(bus, index) == filter:
				return index
	if not wanted:
		return -1
	filter = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(bus, filter)
	_near_filters[name] = filter
	return AudioServer.get_bus_effect_count(bus) - 1


static func ensure() -> void:
	if AudioServer.get_bus_index(WEATHER) >= 0:
		return
	AudioServer.set_bus_count(5)
	AudioServer.set_bus_name(1, MUSIC)
	AudioServer.set_bus_send(1, "Master")
	AudioServer.set_bus_name(2, SFX)
	AudioServer.set_bus_send(2, "Master")
	AudioServer.set_bus_name(3, AMBIENCE)
	AudioServer.set_bus_send(3, "Master")
	AudioServer.set_bus_name(4, WEATHER)
	AudioServer.set_bus_send(4, "Master")


## Builds the placement buses, once. Each sends to SFX, so the player's sound
## fader and the boss's hush reach a placed voice exactly as an unplaced one.
static func ensure_placement() -> void:
	if _placed and AudioServer.get_bus_index(placement_name(0, false)) >= 0:
		return
	ensure()
	for muffled: bool in [false, true]:
		for step: int in PAN_STEPS:
			var name: String = placement_name(step, muffled)
			if AudioServer.get_bus_index(name) >= 0:
				continue
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, name)
			AudioServer.set_bus_send(index, SFX)
			var panner := AudioEffectPanner.new()
			panner.pan = pan_of(step)
			AudioServer.add_bus_effect(index, panner)
			if muffled:
				var through := AudioEffectLowPassFilter.new()
				through.cutoff_hz = Balance.SFX_OCCLUDED_CUTOFF_HZ
				AudioServer.add_bus_effect(index, through)
	_placed = true
	# A bus built after the edge of death closed in has not been closed over;
	# the next call reapplies to every bus whatever it was told last.
	_near_applied = -1.0


static func placement_name(step: int, muffled: bool) -> String:
	return "SFX_P%d%s" % [step, "_M" if muffled else ""]


## The pan a placement step stands for, -1 hard left to 1 hard right, held to
## `SFX_PAN_STRENGTH` so nothing is ever only in one ear.
static func pan_of(step: int) -> float:
	return lerpf(-1.0, 1.0, float(step) / float(PAN_STEPS - 1)) * Balance.SFX_PAN_STRENGTH


## Applies the settings faders to the buses. One place, so music and sfx cannot
## disagree about what "master volume" means.
static func apply_volumes() -> void:
	ensure()
	var master: float = float(MetaState.settings.get("master_volume", 1.0))
	var music: float = float(MetaState.settings.get("music_volume", 0.8))
	var sfx: float = float(MetaState.settings.get("sfx_volume", 1.0))
	var ambience: float = float(MetaState.settings.get("ambience_volume", 0.9))
	var weather: float = float(MetaState.settings.get("weather_volume", 0.9))
	# The duck rides on the master fader, so one multiply covers the music, the
	# effects, the ambience and the weather at once - which is what "near-total
	# quiet" means and what four separate fades would fail to keep in step.
	_apply_bus(0, master * _hush)
	_apply_bus(AudioServer.get_bus_index(MUSIC), music * lerpf(1.0, Balance.MUSIC_CALM_TRIM, _calm))
	_apply_bus(AudioServer.get_bus_index(SFX), sfx)
	_apply_bus(AudioServer.get_bus_index(AMBIENCE), ambience)
	_apply_bus(AudioServer.get_bus_index(WEATHER), weather)


static func _apply_bus(index: int, linear: float) -> void:
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0001, 1.0)))
