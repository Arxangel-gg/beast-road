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
