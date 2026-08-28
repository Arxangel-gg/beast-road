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
	# Bound since they were written, and reachable from the keyboard, but absent
	# from this list - so the settings panel offered no way to move them. Command
	# orders sit on Z/X/C, which is exactly the corner of the keyboard a
	# left-handed or non-QWERTY player most needs to change.
	{"action": &"command_overdrive", "label": "Command: Overdrive"},
	{"action": &"command_rally", "label": "Command: Rally Road"},
	{"action": &"command_last_stand", "label": "Command: Last Stand"},
	{"action": &"ride_on", "label": "Ride on"},
	{"action": &"tend", "label": "Tend / field ration"},
	{"action": &"pause", "label": "Pause"},
]

## Controller bindings, added on top of the shipped keyboard ones.
##
## Held here rather than in `project.godot` for two reasons. The project file
## stores an input event as a serialised `Object(...)` line, which is unpleasant
## to hand-edit and easy to corrupt; and adding them here means the pad layer is
## applied *before* `_capture_defaults`, so a controller binding is part of the
## defaults and "reset to default" restores it like anything else.
##
## Left stick moves, right stick aims - neither is an action, so both are read
## directly by the hero. Everything else is a button, laid out the way an Xbox
## pad expects: face buttons for the things done constantly, shoulders for the
## abilities, d-pad for the scopes.
const PAD_BUTTONS: Dictionary = {
	&"attack": JOY_BUTTON_X,
	&"dash": JOY_BUTTON_A,
	&"ride_on": JOY_BUTTON_Y,
	&"tend": JOY_BUTTON_BACK,
	&"war_horn": JOY_BUTTON_B,
	&"pause": JOY_BUTTON_START,
	&"spell_1": JOY_BUTTON_LEFT_SHOULDER,
	&"spell_2": JOY_BUTTON_RIGHT_SHOULDER,
	&"scope_battlefield": JOY_BUTTON_DPAD_LEFT,
	&"scope_town": JOY_BUTTON_DPAD_UP,
	&"scope_beast": JOY_BUTTON_DPAD_RIGHT,
	&"command_overdrive": JOY_BUTTON_DPAD_DOWN,
	&"command_rally": JOY_BUTTON_LEFT_STICK,
	&"command_last_stand": JOY_BUTTON_RIGHT_STICK,
}

## The left stick, bound to the four movement actions as well as read directly.
##
## Both, on purpose. Binding the actions means `Input.get_vector` works on a pad
## with no special case, and anything else that reads movement — a menu, a future
## system — gets the stick for free. Reading the stick directly on top of that
## buys a radial deadzone and a rescale from its edge, which `get_vector` cannot
## do because it treats each axis separately and turns a diagonal push into a
## square corner.
const PAD_MOVE: Dictionary = {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}

## Triggers, for the two abilities the face and shoulder buttons ran out of room
## for. An axis, so they need a threshold rather than a button index.
const PAD_AXES: Dictionary = {
	&"spell_3": JOY_AXIS_TRIGGER_LEFT,
	&"spell_4": JOY_AXIS_TRIGGER_RIGHT,
}

## Menus have to be usable without a mouse or the pad is only half supported.
## Godot drives focus from these, so binding them is the whole of UI navigation.
const PAD_UI: Dictionary = {
	&"ui_accept": JOY_BUTTON_A,
	&"ui_cancel": JOY_BUTTON_B,
	&"ui_up": JOY_BUTTON_DPAD_UP,
	&"ui_down": JOY_BUTTON_DPAD_DOWN,
	&"ui_left": JOY_BUTTON_DPAD_LEFT,
	&"ui_right": JOY_BUTTON_DPAD_RIGHT,
}

## Movement and aim sticks. Read directly rather than through actions, because a
## stick carries a direction and an action carries a bool.
const PAD_MOVE_AXES: Array[int] = [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]
const PAD_AIM_AXES: Array[int] = [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]

## Below this a stick is at rest. Generous: a worn pad does not centre exactly,
## and a hero that drifts because the stick reads 0.04 is worse than one that
## needs a firmer push.
const PAD_DEADZONE: float = 0.24


## Adds the controller layer. Idempotent, and safe to call before defaults are
## captured - which is the point.
static func apply_pad_bindings() -> void:
	for action: StringName in PAD_BUTTONS:
		_add_pad_event(action, _button_event(int(PAD_BUTTONS[action])))
	for action: StringName in PAD_AXES:
		_add_pad_event(action, _axis_event(int(PAD_AXES[action]), 1.0))
	for action: StringName in PAD_MOVE:
		var spec: Array = PAD_MOVE[action]
		_add_pad_event(action, _axis_event(int(spec[0]), float(spec[1])))
	for action: StringName in PAD_UI:
		_add_pad_event(action, _button_event(int(PAD_UI[action])))


static func _axis_event(axis: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


static func _button_event(index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	return event


## Adds an event only if nothing equivalent is already bound, so calling this
## twice does not give an action two identical bindings.
static func _add_pad_event(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing.is_match(event):
			return
	InputMap.action_add_event(action, event)


## The left stick, as a direction. Zero when at rest.
static func pad_move() -> Vector2:
	return _stick(PAD_MOVE_AXES)


## The right stick, as a direction. Zero when at rest.
static func pad_aim() -> Vector2:
	return _stick(PAD_AIM_AXES)


static func _stick(axes: Array[int]) -> Vector2:
	var raw := Vector2(Input.get_joy_axis(0, axes[0]), Input.get_joy_axis(0, axes[1]))
	if raw.length() < PAD_DEADZONE:
		return Vector2.ZERO
	# Rescaled from the deadzone edge, so the first usable push is a small
	# movement rather than a jump to a quarter speed.
	return raw.normalized() * clampf(
		(raw.length() - PAD_DEADZONE) / (1.0 - PAD_DEADZONE), 0.0, 1.0)


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
	# Before the capture, so the pad is part of the defaults and a reset restores
	# it rather than stripping the controller out of the game.
	apply_pad_bindings()
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
