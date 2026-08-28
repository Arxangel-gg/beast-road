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
## Held, not tapped, so a thumb drives the same three-second hold a keyboard
## does. Shown only while somebody is down: a button that does nothing for an
## entire solo run is a button standing in front of the field.
var _revive: TouchButton = null
var _down_count: int = 0


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
		ScreenFit._fit()
		return
	_showing = wanted
	# `_controls_live`, not `wanted`: the setting can enable the controls while
	# the player is still on the menu, and turning them on there is what put the
	# dash button on the front door. `_process` raises them when a run starts.
	visible = _controls_live()
	UiMetrics.apply_touch_tree(get_tree().root, wanted)
	if not wanted:
		_release_all()
	shown_changed.emit(wanted)
	ScreenFit._fit()


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

	# **There was no way to revive on a phone at all.** The hold is read from
	# `Input.is_action_pressed("revive")`, which on a desktop is a key held down
	# and on a phone is nothing - so a fallen partner could not be helped up,
	# and in a two-player run that is the end of it.
	_revive = TouchButton.new()
	_revive.name = "ReviveButton"
	_revive.label = "REVIVE"
	_revive.visible = false
	add_child(_revive)
	EventBus.coop_hero_down.connect(func(_slot: int, _at: Vector2) -> void:
		_down_count += 1)
	EventBus.coop_hero_revived.connect(func(_slot: int, _at: Vector2) -> void:
		_down_count = maxi(_down_count - 1, 0))


## Whether the on-screen controls should be up *right now*.
##
## Two questions, deliberately kept apart. `_showing` answers "does this player
## drive with thumbs at all" - a device and settings question, and the HUD's
## mobile metrics follow it everywhere, the menu included. This answers "is there
## anything to drive": the sticks and the dash button move the hero, and outside
## a run there is no hero.
##
## Left as one question, the dash button drew its ring over the main menu. The
## visible ring was the smaller half of the problem. Because the controls read
## `_unhandled_input`, the button kept *consuming taps* on the front door - and
## an invisible button eats a press exactly as well as a visible one does.
func _controls_live() -> bool:
	return _showing and GameDirector.run_active and (
		GameDirector.current_scope == GameDirector.Scope.BATTLEFIELD
		or GameDirector.current_scope == GameDirector.Scope.RAID)


## Releases are watched here, and *only* releases.
##
## `_unhandled_input` never sees an event some Control consumed first. A thumb
## that went down on a stick and then lifted while a panel was open - or lifted
## onto the Close button that dismissed the panel - had its touch-up eaten, so
## the stick went on believing it still held that finger. Godot emulates the
## mouse from finger 0 only, so `owns_pointer()` stayed true forever, and
## `placement_cursor.gd` refused every later tap on a tile as "that is a thumb,
## not a click". The build panel could be opened, closed once, and never opened
## again.
##
## Acquiring a finger stays in `_unhandled_input`, where a press has to lose to
## any UI above it. Letting go is not a contest: nothing else wants the release,
## and the worst case of acting on it here is releasing something already
## released, which is free.
func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or touch.pressed:
		return
	for stick: TouchStick in _sticks:
		stick.release_finger(touch.index)
	if _dash != null:
		_dash.release_finger(touch.index)
	if _revive != null:
		_revive.release_finger(touch.index)


func _unhandled_input(event: InputEvent) -> void:
	if not _controls_live():
		return

	# The dash button is checked first: it sits inside the right stick's corner,
	# and a thumb on it must be a dash rather than an aim.
	if _dash.consume(event, dash_rect()):
		get_viewport().set_input_as_handled()
		return
	if _revive.visible and _revive.consume(event, revive_rect()):
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
	var side: float = button_side()
	# **Inside the scope rail, not under it.** The right edge at half height was
	# the one part of the frame the interface never claimed - and then the scope
	# column moved there, six squares from a little below the top bar to well
	# past the middle. A button drawn beneath a HUD panel is not merely hidden:
	# the sticks read `_unhandled_input`, so the panel eats the tap.
	var reserved: float = HUD.nav_column_width()
	return Rect2(span.x - reserved - side * 1.25, span.y * 0.5 - side * 0.5,
		side, side)


## Where the revive hold sits: directly under the dash, on the same edge.
##
## Beside the thumb already there rather than somewhere tidier - reviving means
## standing still beside a fallen partner for three seconds, so the hand
## holding this one is not the one steering.
func revive_rect() -> Rect2:
	var dash: Rect2 = dash_rect()
	return Rect2(dash.position + Vector2(0.0, dash.size.y * 1.25), dash.size)


## Whether a thumb is on the revive button right now.
func revive_held() -> bool:
	return _revive != null and _revive.visible and _revive.is_held()


## How big a persistent touch button is. Sized from the shorter screen axis, so
## a tall viewport does not produce a button a quarter of the screen across.
func button_side() -> float:
	var span: Vector2 = get_viewport().get_visible_rect().size
	return minf(span.x, span.y) * 0.11


func _process(_delta: float) -> void:
	# Watched here rather than signalled from GameDirector: the run starts and
	# ends through several paths - menu, victory, defeat, quit-to-menu - and a
	# gate that has to be remembered at each of them is a gate that will be
	# forgotten at one of them.
	var live: bool = _controls_live()
	if visible != live:
		visible = live
		# A thumb still down when the run ends would otherwise leave its action
		# held forever, since the release event arrives after the controls stop
		# listening for it.
		if not live:
			_release_all()
	if not live:
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

	_revive.visible = _down_count > 0
	if _revive.visible:
		var spot: Rect2 = revive_rect()
		_revive.position = spot.position
		_revive.size = spot.size
	elif _revive.is_held():
		_revive.forget()


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
	# The dash button too. It was left out, and a button still holding finger 0
	# when the controls were hidden kept `owns_pointer()` true against a set of
	# controls that no longer existed.
	if _dash != null:
		_dash.forget()


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


	## Lets go of `index`, if this stick was the one holding it.
	##
	## Safe to call for a finger it never had, which is what lets the release be
	## broadcast to every stick without asking which one owns it first.
	func release_finger(index: int) -> void:
		if _finger >= 0 and index == _finger:
			forget()


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


	## Still down. `take_press` is the one-shot a dash wants; a revive is a hold.
	func is_held() -> bool:
		return _finger >= 0


	## As `TouchStick.release_finger`. The press has already been recorded by the
	## time a thumb lifts, so letting go here cannot lose a dash.
	func release_finger(index: int) -> void:
		if _finger >= 0 and index == _finger:
			forget()


	## Unconditional. Mirrors `TouchStick.forget` so `_release_all` can clear the
	## button without reaching into it.
	func forget() -> void:
		if _finger < 0:
			return
		_finger = -1
		queue_redraw()


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
