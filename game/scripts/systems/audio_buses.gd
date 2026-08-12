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


static func ensure() -> void:
	if AudioServer.get_bus_index(SFX) >= 0:
		return
	AudioServer.set_bus_count(3)
	AudioServer.set_bus_name(1, MUSIC)
	AudioServer.set_bus_send(1, "Master")
	AudioServer.set_bus_name(2, SFX)
	AudioServer.set_bus_send(2, "Master")


## Applies the settings faders to the buses. One place, so music and sfx cannot
## disagree about what "master volume" means.
static func apply_volumes() -> void:
	ensure()
	var master: float = float(MetaState.settings.get("master_volume", 1.0))
	var music: float = float(MetaState.settings.get("music_volume", 0.8))
	var sfx: float = float(MetaState.settings.get("sfx_volume", 1.0))
	_apply_bus(0, master)
	_apply_bus(AudioServer.get_bus_index(MUSIC), music)
	_apply_bus(AudioServer.get_bus_index(SFX), sfx)


static func _apply_bus(index: int, linear: float) -> void:
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0001, 1.0)))
