extends CanvasLayer

## Twin sticks and a dash button, for playing in a phone browser.
##
## ## Why this exists at all
##
## The web build is embedded in a page, and a large share of anyone who opens a
## page is on a phone. Without this they get a game that draws perfectly and
## cannot be played: every other control in the game already has an on-screen
## button — spells, commands, the horn, raid, repair, ride-on — and the four that
## did not were movement, aim, attack and dash, which are the whole of combat.
##
## ## Where it joins
##
## Movement is fed back into the **input map**, not into the hero:
## `Input.action_press(&"move_left", strength)` and friends. `Hero._move_input()`
## already reads `Input.get_vector` over those four actions and respects
## strength, so a thumb on glass arrives by the same road as a key, and the hero
## needed no change for it.
##
## Aim is the exception, because there is no action to press: a direction is not
## a button. `Hero._compute_aim()` gains one branch, in the same shape as the
## gamepad branch that was already beside it.
##
## ## Only the touches nobody else wanted
##
## The sticks read `_unhandled_input`, which runs *after* Controls have taken
## what they want. A thumb on a spell button is consumed by the button and never
## reaches here; a thumb on bare ground does. That is the whole conflict
## resolution, and it needs no geometry: the alternative was asking "is this
## touch over a Control" at every event, which is fragile in a way this is not.
##
## Each stick still claims only its own corner, so a tap in the middle of the
## field — placing a tower, picking a crossroad — is nobody's stick.
##
## ## Dynamic, not fixed
##
## A stick appears where the thumb lands rather than sitting in one spot. Fixed
## sticks make a player look down to find them; a dynamic one is under the thumb
## by definition. The ring is only drawn once a touch is down, which is also why
## the screen is clean when nobody is playing.

## Emitted when touch controls appear or disappear, so anything that lays itself
## out around them can move.
signal shown_changed(showing: bool)

## Which corner of the screen each stick owns, and how far up it reaches.
const ZONE_HEIGHT: float = 0.62
const ZONE_WIDTH: float = 0.42

var _showing: bool = false
var _move := Vector2.ZERO
var _aim := Vector2.ZERO
var _attacking: bool = false

var _sticks: Array = []
var _dash: TouchButton = null


func _ready() -> void:
	layer = 48
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_tree().node_added.connect(_on_node_added)
	refresh()


## Whether the on-screen controls are up.
func is_showing() -> bool:
	return _showing


## The left stick, or zero. Same contract as `KeyBindings.pad_move()`.
func move() -> Vector2:
	return _move


## The right stick as a direction, or zero. Same contract as `pad_aim()`.
func aim() -> Vector2:
	return _aim


## Whether the right stick is pushed far enough to be asking for an attack.
func attacking() -> bool:
	return _attacking


## Whether a stick or the dash button is holding the finger the mouse is
## emulated from.
##
## Godot emulates a mouse from touch, and it emulates **only finger 0**. So one
## thumb on the movement stick also produces a stream of mouse events walking
## across the battlefield - which, left alone, places towers while you walk.
##
## Anything that acts on a world click asks this first. It is an ownership
## question rather than a geometric one on purpose: asking "is this point inside
## a stick zone" would make two whole corners of the field permanently untappable
## whether or not a thumb was actually there.
func owns_pointer() -> bool:
	if not _showing:
		return false
	for stick: TouchStick in _sticks:
		if stick.holds_emulated_finger():
			return true
	return _dash.holds_emulated_finger()


## Decides whether to show, and does.
##
## Shown when the device reports a touchscreen, which covers phones and tablets
## in a browser and leaves a desktop alone. The setting can force it either way,
## because `is_touchscreen_available()` is a hint rather than a promise — a
## Windows laptop with a touch display reports true and is played with a mouse.
func refresh() -> void:
	var forced: Variant = MetaState.settings.get(TOUCH_KEY, null)
	var wanted: bool = DisplayServer.is_touchscreen_available() if forced == null \
		else bool(forced)
	if wanted == _showing:
		# A new scene may have arrived since the last refresh.
		UiMetrics.apply_touch_tree(get_tree().root, wanted)
		return
	_showing = wanted
	visible = wanted
	UiMetrics.apply_touch_tree(get_tree().root, wanted)
	if not wanted:
		_release_all()
	shown_changed.emit(wanted)


## New modal screens and rebuilt stash/build rows inherit the same mobile
## metrics as the HUD. Deferred so the creator has assigned its authored desktop
## size and font before those values are captured for a reversible touch pass.
func _on_node_added(node: Node) -> void:
	if _showing:
		_apply_touch_later.call_deferred(node)


func _apply_touch_later(node: Node) -> void:
	if is_instance_valid(node) and _showing:
		UiMetrics.apply_touch_tree(node, true)


## The setting key, so Settings can offer an override.
const TOUCH_KEY: String = "touch_controls"


func _build() -> void:
	var left := TouchStick.new()
	left.name = "MoveStick"
	left.tint = Color("9fd0ff")
	_sticks.append(left)
	add_child(left)

	var right := TouchStick.new()
	right.name = "AimStick"
	right.tint = Color("ffb27a")
	_sticks.append(right)
	add_child(right)

	_dash = TouchButton.new()
	_dash.name = "DashButton"
	_dash.label = "DASH"
	add_child(_dash)


func _unhandled_input(event: InputEvent) -> void:
	if not _showing:
		return

	# The dash button is checked first: it sits inside the right stick's corner,
	# and a thumb on it must be a dash rather than an aim.
	if _dash.consume(event, dash_rect()):
		get_viewport().set_input_as_handled()
		return

	var claimed: bool = _sticks[0].consume(event, zone(false)) \
		or _sticks[1].consume(event, zone(true))
	if claimed:
		get_viewport().set_input_as_handled()


## The corner one stick owns. `right` picks which.
##
## Public, and the only place this geometry is written down. It was duplicated
## into the check that exercises it, which meant the check agreed with a copy of
## the layout rather than with the layout — and passed a thumb position straight
## into the dash button without noticing.
func zone(right: bool) -> Rect2:
	var span: Vector2 = get_viewport().get_visible_rect().size
	return Rect2(span.x * (1.0 - ZONE_WIDTH) if right else 0.0,
		span.y * (1.0 - ZONE_HEIGHT), span.x * ZONE_WIDTH, span.y * ZONE_HEIGHT)


## Where the dash button sits.
##
## Sized from the *shorter* screen axis, not the height. Height alone made the
## button a quarter of the screen across on a tall viewport, which put it under
## the resting position of the aiming thumb — so aiming dashed instead.
##
## On the right edge at half height, which looks like an odd place until you put
## the HUD next to it. The bottom right is the Command panel, the bottom centre
## is the ability bar and the bottom left is where tutorial cards appear — and
## because the sticks read `_unhandled_input`, a HUD panel over this button does
## not merely hide it, it *eats the tap*. Half height on the right edge is the
## one part of the frame the interface never claims.
func dash_rect() -> Rect2:
	var span: Vector2 = get_viewport().get_visible_rect().size
	var side: float = minf(span.x, span.y) * 0.11
	return Rect2(span.x - side * 1.35, span.y * 0.5 - side * 0.5, side, side)


func _process(_delta: float) -> void:
	if not _showing:
		return
	_move = (_sticks[0] as TouchStick).value()
	var right: Vector2 = (_sticks[1] as TouchStick).value()

	# Aim holds its last direction once pushed, so releasing the stick does not
	# snap the hero back to facing east. The same reasoning the pad branch gives.
	if right != Vector2.ZERO:
		_aim = right.normalized()
	_attacking = right.length() >= Balance.TOUCH_ATTACK_THRESHOLD

	_drive_actions()
	var where: Rect2 = dash_rect()
	_dash.position = where.position
	_dash.size = where.size


## Presses the same actions a keyboard would.
##
## Held rather than pulsed, and released when the stick centres, so anything
## reading `is_action_pressed` sees exactly what a held key looks like.
func _drive_actions() -> void:
	_axis(&"move_left", maxf(-_move.x, 0.0))
	_axis(&"move_right", maxf(_move.x, 0.0))
	_axis(&"move_up", maxf(-_move.y, 0.0))
	_axis(&"move_down", maxf(_move.y, 0.0))

	if _attacking and not Input.is_action_pressed(&"attack"):
		Input.action_press(&"attack")
	elif not _attacking and Input.is_action_pressed(&"attack"):
		Input.action_release(&"attack")

	if _dash.take_press():
		Input.action_press(&"dash")
	elif Input.is_action_pressed(&"dash"):
		Input.action_release(&"dash")


func _axis(action: StringName, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


## Lets go of everything.
##
## Called when the controls are hidden, and it matters: an action left pressed
## by a stick that no longer exists is a hero that walks into a wall forever.
func _release_all() -> void:
	_move = Vector2.ZERO
	_attacking = false
	for action: StringName in [&"move_left", &"move_right", &"move_up",
			&"move_down", &"attack", &"dash"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)
	for stick: TouchStick in _sticks:
		stick.forget()


## One thumb stick: a ring where the thumb landed and a knob where it is now.
class TouchStick extends Control:
	var tint: Color = Color.WHITE

	## Which finger this stick is following. -1 when idle.
	##
	## Tracked by index rather than by "the last touch", because two thumbs are
	## down at once and the drag events for both arrive interleaved.
	var _finger: int = -1
	var _origin := Vector2.ZERO
	var _at := Vector2.ZERO

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE


	## The stick as a vector in [0,1], or zero when nobody is touching it.
	func value() -> Vector2:
		if _finger < 0:
			return Vector2.ZERO
		var reach: float = Balance.TOUCH_STICK_REACH
		var away: Vector2 = _at - _origin
		if away.length() < Balance.TOUCH_STICK_DEADZONE:
			return Vector2.ZERO
		return away.limit_length(reach) / reach


	func forget() -> void:
		_finger = -1
		queue_redraw()


	## Whether this stick holds finger 0, which is the one a mouse is emulated
	## from. Any other finger produces no mouse events and cannot mis-click.
	func holds_emulated_finger() -> bool:
		return _finger == 0


	## Takes the event if it belongs to this stick. Returns whether it did.
	func consume(event: InputEvent, zone: Rect2) -> bool:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed:
				if _finger >= 0 or not zone.has_point(touch.position):
					return false
				_finger = touch.index
				_origin = touch.position
				_at = touch.position
				queue_redraw()
				return true
			if touch.index == _finger:
				forget()
				return true
			return false

		if event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if drag.index != _finger:
				return false
			_at = drag.position
			queue_redraw()
			return true

		return false


	func _draw() -> void:
		if _finger < 0:
			return
		var reach: float = Balance.TOUCH_STICK_REACH
		var faint := Color(tint.r, tint.g, tint.b, Balance.TOUCH_OPACITY * 0.5)
		var solid := Color(tint.r, tint.g, tint.b, Balance.TOUCH_OPACITY)
		draw_circle(_origin, reach, Color(0.0, 0.0, 0.0, Balance.TOUCH_OPACITY * 0.35))
		draw_arc(_origin, reach, 0.0, TAU, 48, faint, 3.0, true)
		var knob: Vector2 = _origin + (_at - _origin).limit_length(reach)
		draw_circle(knob, reach * 0.34, solid)


## A round button that reports a press once.
class TouchButton extends Control:
	var label: String = ""

	var _finger: int = -1
	var _fired: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


	## True once per press. Consumed by reading, so the action is pressed for a
	## single frame however long the thumb stays down - which is what a dash is.
	func take_press() -> bool:
		var was: bool = _fired
		_fired = false
		return was


	func holds_emulated_finger() -> bool:
		return _finger == 0


	func consume(event: InputEvent, rect: Rect2) -> bool:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed and _finger < 0 and rect.has_point(touch.position):
				_finger = touch.index
				_fired = true
				queue_redraw()
				return true
			if not touch.pressed and touch.index == _finger:
				_finger = -1
				queue_redraw()
				return true
		return false


	func _draw() -> void:
		var side: float = size.x
		if side <= 0.0:
			return
		var centre := Vector2(side, side) * 0.5

		# Brighter than a stick, and labelled. A stick is drawn only while a thumb
		# is already on it, so it never has to be found; this is on screen the
		# whole time and has to be found exactly once. At stick opacity it was a
		# faint ring on a textured battlefield - present, and invisible.
		var alpha: float = Balance.TOUCH_BUTTON_OPACITY * (1.5 if _finger >= 0 else 1.0)
		draw_circle(centre, side * 0.5, Color(0.0, 0.0, 0.0, alpha * 0.55))
		draw_arc(centre, side * 0.5, 0.0, TAU, 40,
			Color(1.0, 0.85, 0.55, minf(alpha, 1.0)), 3.0, true)

		if label.is_empty():
			return
		var font: Font = ThemeDB.fallback_font
		var size_px: int = int(side * 0.24)
		var extent: Vector2 = font.get_string_size(label,
			HORIZONTAL_ALIGNMENT_CENTER, -1.0, size_px)
		font.draw_string(get_canvas_item(),
			centre - Vector2(extent.x * 0.5, -extent.y * 0.26), label,
			HORIZONTAL_ALIGNMENT_CENTER, -1.0, size_px,
			Color(1.0, 0.90, 0.70, minf(alpha * 1.2, 1.0)))
