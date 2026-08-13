class_name Graphics
extends RefCounted

## What a player can turn down to get their frames back.
##
## The options here are not a generic graphics menu copied from somewhere. They
## are the six things that actually cost this game frames, measured from what a
## soak reports on a populated battlefield:
##
##   24 shadow-casting lights   each torch runs a PCF13 shadow pass
##   ~290 contact shadows       one shader quad under every unit and plant
##   ~50 particle systems       embers and smoke on every flame
##   420 foliage clumps         polygons, each rotating every frame
##   1 cloud shadow layer       a full-field scrolling noise shader
##   uncapped frame rate        a laptop rendering 300 fps to cook itself
##
## In roughly that order. Cast shadows are first because twenty-four lights each
## rendering occluders is the single largest item, and it is also the one whose
## absence costs the least: the game looks flatter at night and plays identically.
##
## **Nothing here changes gameplay.** Foliage is decoration, shadows are
## decoration, particles are decoration. A player on Low sees the same enemies at
## the same speeds in the same places as a player on High. That is a rule, not an
## accident — the moment a quality setting changes what is reachable or readable,
## it stops being a quality setting and becomes difficulty.
##
## Tier values live here rather than in `Balance.gd` on purpose. Balance is
## gameplay tuning, surfaced in the Update Manager and argued about in playtests;
## these are presentation budgets and belong with the code that spends them.

const KEY_PRESET: String = "graphics_preset"
const KEY_CAST_SHADOWS: String = "graphics_cast_shadows"
const KEY_CONTACT_SHADOWS: String = "graphics_contact_shadows"
const KEY_PARTICLES: String = "graphics_particles"
const KEY_FOLIAGE: String = "graphics_foliage"
const KEY_CLOUDS: String = "graphics_clouds"
const KEY_FPS_CAP: String = "graphics_fps_cap"

const PRESET_LOW: String = "low"
const PRESET_MEDIUM: String = "medium"
const PRESET_HIGH: String = "high"
const PRESET_CUSTOM: String = "custom"

## What each preset sets. `custom` is absent on purpose: it is not a preset, it
## is the label the UI shows once a player has touched an individual switch.
const PRESETS: Dictionary = {
	PRESET_LOW: {
		KEY_CAST_SHADOWS: false,
		KEY_CONTACT_SHADOWS: false,
		KEY_PARTICLES: 0.35,
		KEY_FOLIAGE: 0.25,
		KEY_CLOUDS: false,
	},
	PRESET_MEDIUM: {
		KEY_CAST_SHADOWS: false,
		KEY_CONTACT_SHADOWS: true,
		KEY_PARTICLES: 0.7,
		KEY_FOLIAGE: 0.6,
		KEY_CLOUDS: true,
	},
	PRESET_HIGH: {
		KEY_CAST_SHADOWS: true,
		KEY_CONTACT_SHADOWS: true,
		KEY_PARTICLES: 1.0,
		KEY_FOLIAGE: 1.0,
		KEY_CLOUDS: true,
	},
}

## Frame cap choices. 0 is uncapped.
##
## A cap is not only for weak machines. An uncapped 2D game on a strong one will
## happily render several hundred frames a second into a laptop's thermal limit
## and then stutter, which reads to the player as the game being badly optimised.
const FPS_CHOICES: Array[int] = [0, 30, 60, 120, 144]

## Applied when the save has nothing. High, because the machine that cannot
## handle it will tell its owner within a minute and the option is one screen
## away — whereas a player who never discovers the settings should not be
## quietly given the worst-looking version of the game.
const DEFAULT_PRESET: String = PRESET_HIGH


## The live settings, held here rather than read from the save.
##
## This class must not touch `MetaState`. It is reached from `ShadowKit`,
## `Flame` and `Foliage`, and anything those are reachable from is also loaded by
## the headless tools — which run under `run_tool.gd`, replacing the main loop,
## where no autoload exists and naming one is a compile error. `UserSettings`
## owns persistence; this owns the values.
static var _chosen: Dictionary = {}


static func preset() -> String:
	return String(_chosen.get(KEY_PRESET, DEFAULT_PRESET))


## Reads one switch, falling back through the current preset to High.
static func _value(key: String) -> Variant:
	if _chosen.has(key):
		return _chosen[key]
	var from: Dictionary = PRESETS.get(preset(), PRESETS[PRESET_HIGH])
	return from.get(key, (PRESETS[PRESET_HIGH] as Dictionary).get(key))


## Everything worth saving, for UserSettings to write.
static func to_dictionary() -> Dictionary:
	return _chosen.duplicate()


static func from_dictionary(values: Dictionary) -> void:
	_chosen = values.duplicate()
	apply_runtime()


# --- What the systems ask ----------------------------------------------------

## Real cast shadows from torches. The most expensive thing in the renderer and
## the cheapest to lose.
static func cast_shadows() -> bool:
	return bool(_value(KEY_CAST_SHADOWS)) and Balance.SHADOW_CAST_ENABLED


## The soft pool under every unit. Cheaper than cast shadows, and worth more:
## without it sprites read as stickers sliding over the floor.
static func contact_shadows() -> bool:
	return bool(_value(KEY_CONTACT_SHADOWS))


## Multiplier on every particle emitter's amount.
static func particle_scale() -> float:
	return clampf(float(_value(KEY_PARTICLES)), 0.0, 1.0)


## Multiplier on the foliage scatter count.
static func foliage_scale() -> float:
	return clampf(float(_value(KEY_FOLIAGE)), 0.0, 1.0)


static func cloud_shadows() -> bool:
	return bool(_value(KEY_CLOUDS))


## Scales a count and never returns zero for a non-zero request — a system that
## asks for particles and gets none looks broken rather than economical.
static func scaled(amount: int, scale: float) -> int:
	if amount <= 0:
		return 0
	return maxi(int(round(float(amount) * scale)), 1)


# --- Applying ----------------------------------------------------------------

## Writes a whole preset. Individual switches are cleared rather than
## overwritten, so a later preset change is not silently ignored because a stale
## explicit value is still sitting in the save.
static func apply_preset(name: String) -> void:
	_chosen[KEY_PRESET] = name
	for key: String in [KEY_CAST_SHADOWS, KEY_CONTACT_SHADOWS,
			KEY_PARTICLES, KEY_FOLIAGE, KEY_CLOUDS]:
		_chosen.erase(key)
	apply_runtime()


## Sets one switch and marks the preset custom, because it no longer is one.
static func set_switch(key: String, value: Variant) -> void:
	_chosen[key] = value
	_chosen[KEY_PRESET] = PRESET_CUSTOM
	apply_runtime()


## The settings that take effect immediately without rebuilding anything.
##
## Shadows, foliage and particle counts are read when a scope is built, so they
## apply on the next battlefield rather than mid-wave. That is deliberate:
## deleting six hundred nodes underneath a running fight to save four frames is
## not a trade worth making.
static func apply_runtime() -> void:
	Engine.max_fps = fps_cap()


static func fps_cap() -> int:
	return int(_chosen.get(KEY_FPS_CAP, 0))


static func set_fps_cap(value: int) -> void:
	_chosen[KEY_FPS_CAP] = value
	apply_runtime()


static func fps_label(value: int) -> String:
	return "Uncapped" if value <= 0 else "%d" % value
