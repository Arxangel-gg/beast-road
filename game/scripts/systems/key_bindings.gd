class_name KeyBindings
extends RefCounted

## Lets the player choose their own keys (GDD §52).
##
## Not a nicety. WASD assumes a right-handed player on a QWERTY board with two
## working hands, and the game currently hard-codes it — so anyone who plays
## left-handed, uses AZERTY, or cannot comfortably reach those keys is simply
## excluded. It is also the single cheapest accessibility feature there is,
## because `InputMap` is already runtime-mutable; nothing here touches
## `project.godot`.
##
## Defaults are captured once, before anything is overridden, so "reset" restores
## what the project shipped rather than whatever the last session happened to
## leave behind.

const SAVE_KEY: String = "key_bindings"

## The actions a player may rebind, in the order the settings screen shows them.
##
## Explicit rather than "everything in the InputMap": that list also contains
## Godot's own `ui_*` actions, and letting someone rebind `ui_accept` is how a
## player locks themselves out of the menu that would let them fix it.
const REBINDABLE: Array[Dictionary] = [
	{"action": &"move_up", "label": "Move up"},
	{"action": &"move_down", "label": "Move down"},
	{"action": &"move_left", "label": "Move left"},
	{"action": &"move_right", "label": "Move right"},
	{"action": &"attack", "label": "Attack"},
	{"action": &"dash", "label": "Dash"},
	{"action": &"war_horn", "label": "War horn"},
	{"action": &"scope_battlefield", "label": "Battlefield"},
	{"action": &"scope_town", "label": "Town"},
	{"action": &"scope_beast", "label": "Beast"},
	{"action": &"spell_1", "label": "Ability 1"},
	{"action": &"spell_2", "label": "Ability 2"},
	{"action": &"spell_3", "label": "Ability 3"},
	{"action": &"spell_4", "label": "Ability 4"},
	{"action": &"pause", "label": "Pause"},
]

## The project's own bindings, captured before any override is applied.
static var _defaults: Dictionary = {}


## The player's overrides, held here rather than read from the save.
##
## Same rule as `Palette` and `Graphics`: nothing in `scripts/systems` that the
## headless tools might load may name an autoload, because `run_tool.gd` replaces
## the main loop and there are none. `UserSettings` owns persistence.
static var _overrides: Dictionary = {}


## Lays the player's choices over the shipped bindings.
static func apply_saved(saved: Dictionary) -> void:
	_overrides = saved.duplicate()
	_capture_defaults()
	for entry: Dictionary in REBINDABLE:
		var action: StringName = entry["action"]
		if not saved.has(String(action)):
			continue
		var event: InputEvent = _from_text(String(saved[String(action)]))
		if event != null:
			_assign(action, event)


static func _capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for entry: Dictionary in REBINDABLE:
		var action: StringName = entry["action"]
		if InputMap.has_action(action):
			_defaults[String(action)] = InputMap.action_get_events(action).duplicate()


## Replaces every event on an action with one.
##
## Replaces rather than appends on purpose. Several actions ship with two
## bindings (WASD and the arrow keys); if rebinding only added a third, the key
## the player was trying to get rid of would still work and the change would look
## like it had failed.
static func rebind(action: StringName, event: InputEvent) -> void:
	_capture_defaults()
	_assign(action, event)
	_overrides[String(action)] = _to_text(event)


static func reset_all() -> void:
	_capture_defaults()
	for action_name: Variant in _defaults:
		var action := StringName(action_name)
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for event: InputEvent in _defaults[action_name]:
			InputMap.action_add_event(action, event)
	_overrides.clear()


## What UserSettings writes to the save.
static func to_dictionary() -> Dictionary:
	return _overrides.duplicate()


static func _assign(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)


## What the player currently presses for this action, for the settings screen.
static func label_for(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	return describe(events[0])


## A human name for an event. `as_text()` alone produces things like
## "W (Physical)" and "Left Mouse Button (Physical)", which is not what anybody
## wants to read in a list of fifteen.
const MOUSE_NAMES: Dictionary = {
	MOUSE_BUTTON_LEFT: "Left click",
	MOUSE_BUTTON_RIGHT: "Right click",
	MOUSE_BUTTON_MIDDLE: "Middle click",
	MOUSE_BUTTON_WHEEL_UP: "Wheel up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel down",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}


static func describe(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key != null:
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return OS.get_keycode_string(code)
	var button := event as InputEventMouseButton
	if button != null:
		return String(MOUSE_NAMES.get(button.button_index, "Mouse %d" % int(button.button_index)))
	return event.as_text()


## Whether an event is something a player may bind at all.
##
## Escape is excluded because it is how the rebinding prompt itself is cancelled,
## and a player who binds Escape to "Move up" has no way back out of the dialog
## that would let them undo it.
static func is_bindable(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo:
			return false
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return code != KEY_ESCAPE
	var button := event as InputEventMouseButton
	return button != null and button.pressed


## Which other actions already use this event, so the screen can warn instead of
## silently creating a key that does two things.
static func conflicts(event: InputEvent, ignoring: StringName) -> Array[String]:
	var found: Array[String] = []
	for entry: Dictionary in REBINDABLE:
		var action: StringName = entry["action"]
		if action == ignoring or not InputMap.has_action(action):
			continue
		if InputMap.action_has_event(action, event):
			found.append(String(entry["label"]))
	return found


# --- Persistence -------------------------------------------------------------
#
# Stored as text rather than a serialised InputEvent: the save file is JSON a
# human may well open, and a physical keycode is stable across keyboard layouts
# in a way a character is not.

static func _to_text(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key != null:
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "key:%d" % int(code)
	var button := event as InputEventMouseButton
	if button != null:
		return "mouse:%d" % int(button.button_index)
	return ""


static func _from_text(text: String) -> InputEvent:
	var parts: PackedStringArray = text.split(":")
	if parts.size() != 2:
		return null
	if parts[0] == "key":
		var key := InputEventKey.new()
		key.physical_keycode = int(parts[1]) as Key
		return key
	if parts[0] == "mouse":
		var button := InputEventMouseButton.new()
		button.button_index = int(parts[1]) as MouseButton
		return button
	return null
