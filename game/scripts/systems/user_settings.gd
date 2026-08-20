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
const VOLUME_KEYS: Array[String] = ["master_volume", "music_volume", "sfx_volume"]

const DISPLAY_KEY: String = "display_mode"
const SHAKE_KEY: String = "screen_shake"

## One key holding the whole graphics dictionary, rather than seven loose ones.
const GRAPHICS_KEY: String = "graphics"
const GAIT_KEY: String = "beast_gait"

## Display modes, as stored. Strings rather than the DisplayServer enum, because
## this ends up in a JSON save file that a human may well open, and a 3 there
## means nothing to anybody.
const DISPLAY_FULLSCREEN: String = "fullscreen"
const DISPLAY_WINDOWED: String = "windowed"


static func value(key: String, fallback: Variant = null) -> Variant:
	return MetaState.settings.get(key, fallback)


static func number(key: String, fallback: float) -> float:
	return float(MetaState.settings.get(key, fallback))


## Writes a setting and makes it take effect immediately. Saving is left to the
## caller: a slider being dragged fires this on every frame of the drag, and
## rewriting the save file sixty times a second is how you corrupt one.
static func set_value(key: String, new_value: Variant) -> void:
	MetaState.settings[key] = new_value
	if VOLUME_KEYS.has(key):
		AudioBuses.apply_volumes()
	elif key == DISPLAY_KEY:
		apply_display()


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


static func apply_display() -> void:
	# The browser owns the window. A canvas cannot be moved, cannot be resized by
	# the page it sits in, and cannot enter fullscreen except from inside a user
	# gesture - so on load this would ask for fullscreen, be refused, and then set
	# a size and a position for a window that does not exist. The export sizes the
	# canvas to the page instead (html/canvas_resize_policy).
	if OS.has_feature("web"):
		return
	var wanted: String = String(MetaState.settings.get(DISPLAY_KEY, DISPLAY_FULLSCREEN))
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
