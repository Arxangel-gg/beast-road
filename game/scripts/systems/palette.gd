class_name Palette
extends RefCounted

## Colours that survive colourblindness (GDD §52).
##
## Two things in this game currently encode meaning in hue and nothing else:
##
## * **the four elements** — Fire red, Water blue, Earth brown, Air violet;
## * **lane pressure** — the rosette runs amber to red as a road fails.
##
## Red/green is the common deficiency, and Fire-versus-Earth is exactly a
## red-versus-brown discrimination. Under deuteranopia the default palette makes
## two of the four tower families look like the same colour, on a screen where
## the player is choosing between them under time pressure.
##
## **A shader filter over the whole screen is not the fix.** Simulating a
## deficiency and then showing it to someone who already has it changes nothing;
## it only makes the rest of the image worse. The fix is to pick hues that stay
## separable, which is what the tables below do — they trade some of the default
## palette's warmth for separation along the blue/yellow axis, which every common
## deficiency preserves.
##
## What this does **not** solve: two colours can be distinct and still be hard to
## name. That is why the element icons exist and are drawn on every tower button,
## and why the rosette also grows and pulses rather than only reddening. Colour
## is the last cue here, not the only one — this makes the last cue work too.

const KEY_MODE: String = "colourblind_mode"

const MODE_OFF: String = "off"
const MODE_PROTANOPIA: String = "protanopia"
const MODE_DEUTERANOPIA: String = "deuteranopia"
const MODE_TRITANOPIA: String = "tritanopia"

## Offered in the settings screen, in this order.
const MODES: Array[Dictionary] = [
	{"id": MODE_OFF, "label": "Off"},
	{"id": MODE_PROTANOPIA, "label": "Protanopia"},
	{"id": MODE_DEUTERANOPIA, "label": "Deuteranopia"},
	{"id": MODE_TRITANOPIA, "label": "Tritanopia"},
]

## Element order is TowerData.Element: FIRE, WATER, EARTH, AIR.
##
## Red/green deficiencies keep blue and yellow, so Fire becomes a hot orange-
## yellow and Earth a desaturated stone that no longer competes with it. Air
## moves toward cyan rather than violet, because violet reads as blue once red
## sensitivity is reduced and would collide with Water.
const ELEMENTS: Dictionary = {
	MODE_OFF: [
		Color("c4552e"), Color("7fa6bf"), Color("7a6e5c"), Color("9b8fc4"),
	],
	MODE_PROTANOPIA: [
		Color("e8a33d"), Color("3f7fb8"), Color("8d8578"), Color("6fd0d6"),
	],
	MODE_DEUTERANOPIA: [
		Color("f0b429"), Color("3d78bd"), Color("8a8175"), Color("74d4dc"),
	],
	# Blue/yellow deficiency: keep red/green separation instead, and pull Air away
	# from Water toward magenta because cyan and blue collapse together here.
	MODE_TRITANOPIA: [
		Color("d1452c"), Color("2f9ea8"), Color("8a7a5e"), Color("c46fc4"),
	],
}

## Lane pressure, calm to critical.
const PRESSURE: Dictionary = {
	MODE_OFF: [Color("d9a441"), Color("d8482c")],
	MODE_PROTANOPIA: [Color("6fd0d6"), Color("f0b429")],
	MODE_DEUTERANOPIA: [Color("74d4dc"), Color("f0b429")],
	MODE_TRITANOPIA: [Color("55b36a"), Color("d1452c")],
}


## The active mode, held here rather than read from the save.
##
## This class must not touch `MetaState`, and the reason is not style. Every
## element colour in the game comes through `TowerData.element_colour`, which the
## headless asset tools load when they parse resources — and those run under
## `run_tool.gd`, which replaces the main loop, so **no autoload exists**.
## Referencing one is a compile error there, not a runtime one, and it takes the
## whole tool down with it.
##
## So persistence lives in `UserSettings`, which is only ever reached from the
## running game. Same split as `UiMetrics`: the half the tools can see holds no
## autoload references.
static var _mode: String = MODE_OFF


static func mode() -> String:
	return _mode


## Sets the mode. Saving it is `UserSettings.set_colourblind_mode`'s job.
##
## No signal is emitted. Every reader asks at draw time, and the one thing that
## caches — the rosette, which only redraws when pressure moves — watches this
## value itself.
static func set_mode(id: String) -> void:
	_mode = id


## The colour for an element under the current mode.
static func element(which: int) -> Color:
	var table: Array = ELEMENTS.get(mode(), ELEMENTS[MODE_OFF])
	return table[clampi(which, 0, table.size() - 1)]


## Calm and critical ends of the lane pressure ramp.
static func pressure_calm() -> Color:
	return (PRESSURE.get(mode(), PRESSURE[MODE_OFF]) as Array)[0]


static func pressure_hot() -> Color:
	return (PRESSURE.get(mode(), PRESSURE[MODE_OFF]) as Array)[1]
