class_name UserSettings
extends RefCounted

## One place that knows what a setting means and what changing it does.
##
## The values already lived in `MetaState.settings` and were already written to
## the save file — but three of the four had no control anywhere in the game.
## `master_volume`, `music_volume` and `sfx_volume` were read on boot, applied to
## the buses, persisted faithfully, and could never be changed by a player. The
## only slider that existed was screen shake.
##
## So this is not a new feature so much as the missing half of one. It gives the
## settings a single definition — key, label, default, range — that both the UI
## and the boot path read, which is what stops the two drifting apart again.

## Keys, in the order they should be presented.
const VOLUME_KEYS: Array[String] = ["master_volume", "music_volume", "sfx_volume",
	"ambience_volume", "weather_volume"]

const DISPLAY_KEY: String = "display_mode"
const SHAKE_KEY: String = "screen_shake"
const BLOOD_VFX_KEY: String = "blood_vfx"

## Two more comfort scales, added 2026-09-16 out of the forwarded accessibility
## notes (#182-#195), and put here rather than in `Graphics` because the shake
## slider they belong beside already lives here.
##
## **Scales rather than switches**, which is the part that was missing. The
## graphics options can turn the fog off and the phenotypes off, and there was
## nothing at all to say to a player who wants *half* the flashing rather than
## none of it - so the only honest answer available to somebody made ill by it
## was to stop playing.
##
## Both run 0 to 1 and default to 1, so the shipped game is exactly what it was
## and a save written before today reads as untouched. Read through
## `JuiceDirector` and nowhere else, so a second place cannot honour one while a
## third forgets it - the failure an Arcane node shipped with when its reach was
## applied at four of five call sites.
const FLASH_KEY: String = "screen_flash"
const NUMBER_DENSITY_KEY: String = "damage_number_density"

## The three comfort scales, as one table, in the order to present them.
##
## **One definition, because there are two screens that draw them now**: the
## settings panel and the first-run card. A player made ill by flashing should
## not have to already know that a Game tab exists, and the moment a second
## screen restates a key, a range and a step is the moment the two can
## disagree - the failure an Arcane node shipped with when its reach was
## applied at four of five call sites, and the shake slider shipped with when
## the beast scope read it raw and unclamped past 1.0.
##
## The shake reaches 1.5 and the other two stop at 1. The flashes are authored
## at what the art was graded for, so a control that let a player make them
## *brighter* is a control that can hurt somebody who reached for it to be
## helped.
const COMFORT_ROWS: Array[Dictionary] = [
	{"key": SHAKE_KEY, "label": "Screen shake", "minimum": 0.0,
		"maximum": 1.5, "step": 0.05, "default": 1.0,
		"note": "How much a blow moves the camera."},
	{"key": FLASH_KEY, "label": "Screen flashes", "minimum": 0.0,
		"maximum": 1.0, "step": 0.05, "default": 1.0,
		"note": "How bright the game is allowed to go, all at once."},
	{"key": NUMBER_DENSITY_KEY, "label": "Damage numbers", "minimum": 0.0,
		"maximum": 1.0, "step": 0.05, "default": 1.0,
		"note": "Turned down, the small ones thin out and the big ones stay."},
]

## How big the interface is drawn, as a multiplier on `ScreenFit`'s own fit
## (2026-09-21). Bounded, because a scale of three on a desktop is a screen
## with one button on it and a scale of a half is a screen nobody can read.
const UI_SCALE_KEY: String = "ui_scale"
const UI_SCALE_MIN: float = 0.8
const UI_SCALE_MAX: float = 1.5

## One key holding the whole graphics dictionary, rather than seven loose ones.
const GRAPHICS_KEY: String = "graphics"
const GAIT_KEY: String = "beast_gait"

## Display modes, as stored. Strings rather than the DisplayServer enum, because
## this ends up in a JSON save file that a human may well open, and a 3 there
## means nothing to anybody.
const DISPLAY_FULLSCREEN: String = "fullscreen"
const DISPLAY_WINDOWED: String = "windowed"


## The battlefield layout the next *new* road is laid on (`MapModes`). A banked
## road keeps its own, and a guest walks the host's.
const MAP_MODE_KEY: String = "map_mode"


## The layout chosen for new roads - a layout or Random - sanitised, because a
## save may hold anything.
static func map_mode() -> String:
	return MapModes.sanitise_choice(value(MAP_MODE_KEY, MapModes.CLASSIC))


static func value(key: String, fallback: Variant = null) -> Variant:
	return MetaState.settings.get(key, fallback)


static func number(key: String, fallback: float) -> float:
	return float(MetaState.settings.get(key, fallback))


## The interface size, clamped - a save may hold anything.
static func ui_scale() -> float:
	return clampf(number(UI_SCALE_KEY, 1.0), UI_SCALE_MIN, UI_SCALE_MAX)


## Writes a setting and makes it take effect immediately. Saving is left to the
## caller: a slider being dragged fires this on every frame of the drag, and
## rewriting the save file sixty times a second is how you corrupt one.
static func set_value(key: String, new_value: Variant) -> void:
	MetaState.settings[key] = new_value
	if VOLUME_KEYS.has(key):
		AudioBuses.apply_volumes()
	elif key == DISPLAY_KEY:
		# Reached only from the settings buttons, so there is a live user gesture
		# to spend - which is what the web needs in order to go fullscreen at all.
		apply_display(true)
	elif key == UI_SCALE_KEY:
		ScreenFit.refit()


## Everything the settings control, applied at once. Called after the save file
## is read so a returning player gets the game they left, not the defaults.
static func apply_all() -> void:
	AudioBuses.apply_volumes()
	apply_display()
	load_presentation()


## Pushes the saved graphics, colourblind and key choices into the classes that
## own them.
##
## Those three deliberately hold no reference to `MetaState`. They are reachable
## from `TowerData`, `ShadowKit` and `Foliage`, which the headless asset tools
## load — and those run under `run_tool.gd`, which replaces the main loop, so
## naming an autoload there is a compile error that takes the whole tool down.
## This class only ever runs inside the game, so it is the safe place to bridge.
static func load_presentation() -> void:
	Graphics.from_dictionary(MetaState.settings.get(GRAPHICS_KEY, {}) as Dictionary)
	Palette.set_mode(String(MetaState.settings.get(Palette.KEY_MODE, Palette.MODE_OFF)))
	KeyBindings.apply_saved(MetaState.settings.get(KeyBindings.SAVE_KEY, {}) as Dictionary)


## Copies them back out again, for the caller to save.
static func store_presentation() -> void:
	MetaState.settings[GRAPHICS_KEY] = Graphics.to_dictionary()
	MetaState.settings[Palette.KEY_MODE] = Palette.mode()
	MetaState.settings[KeyBindings.SAVE_KEY] = KeyBindings.to_dictionary()


## Applies the display setting.
##
## `from_gesture` is true only when a player just clicked one of the display
## buttons, and it exists for the web: a browser grants fullscreen from inside a
## user gesture and refuses it everywhere else. Blocking the web outright was the
## first fix and it went too far - it stopped the boot-time request, which was
## the bug, and also killed the settings button, which was not.
static func apply_display(from_gesture: bool = false) -> void:
	var wanted: String = String(MetaState.settings.get(DISPLAY_KEY, DISPLAY_FULLSCREEN))

	if OS.has_feature("web"):
		# A canvas has no position and no size of its own to set - the page and
		# `html/canvas_resize_policy` decide those - so only the mode is touched,
		# and only when there is a gesture to spend on it.
		if from_gesture:
			var canvas_mode := DisplayServer.WINDOW_MODE_WINDOWED
			if wanted == DISPLAY_FULLSCREEN:
				canvas_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(canvas_mode)
		return

	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN \
		if wanted == DISPLAY_FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() == mode:
		return
	DisplayServer.window_set_mode(mode)
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		# Coming out of fullscreen leaves the window at whatever size the mode
		# switch decided on, which on a high-DPI display is often larger than the
		# screen. Setting it explicitly and re-centring is the difference between
		# "windowed" and "the title bar is off the top of the monitor".
		var screen: int = DisplayServer.window_get_current_screen()
		var area: Rect2i = DisplayServer.screen_get_usable_rect(screen)
		var size: Vector2i = _windowed_size(area)
		DisplayServer.window_set_size(size)
		# Centred on the screen the game was already on, not on screen 0 - on a
		# multi-monitor desk those are usually not the same one.
		DisplayServer.window_set_position(area.position + (area.size - size) / 2)


## A window sized against the monitor rather than a fixed pair of numbers.
##
## 1600x900 is comfortable on a 1080p panel and postage-stamp sized on a 4K one.
## Taking a fraction of the usable height and holding 16:9 gives a window that is
## the same *apparent* size everywhere, and the clamp keeps it both readable on
## small displays and inside the desktop on large ones.
static func _windowed_size(area: Rect2i) -> Vector2i:
	var height: int = clampi(int(float(area.size.y) * 0.78), 720, area.size.y - 60)
	var width: int = int(round(float(height) * 16.0 / 9.0))
	if width > area.size.x - 40:
		width = area.size.x - 40
		height = int(round(float(width) * 9.0 / 16.0))
	return Vector2i(maxi(width, 1280), maxi(height, 720))


static func is_fullscreen() -> bool:
	return String(MetaState.settings.get(DISPLAY_KEY, DISPLAY_FULLSCREEN)) == DISPLAY_FULLSCREEN
