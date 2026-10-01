class_name ClickMove
extends Node2D

## **Click to move, League's way** (owner, 2026-10-01: *"Clicking on the
## battlefield should move to the location, similar to the click to move setup
## in the Hold, and only attack the clicked target if and when the attack is in
## range of doing the attack on the enemy, whether it's a melee or ranged
## attack, and if the click was on a valid target to then automatically pursue
## that target until it is in range of the attack, inspired by league of
## legends"*).
##
## This node reads where a click landed and turns it into an order on the
## Warden's own input (`LocalHeroInput`), which turns the order into the walk,
## the aim and the swing a stick and a button would have produced. So the hero
## learns nothing, a guest's orders cross the wire as the walk and the swing
## they become, and an order can never do a thing a hand could not.
##
## - **A click on the ground walks there**; holding the button steers, the
##   destination following the cursor.
## - **A click on a body chases it** and swings once the swing reaches it, and
##   keeps swinging until it falls or another order is given. **F on a body**
##   does the same with the bow, to the bow's own reach, and falls back to the
##   swing when the quiver is empty.
## - **Ctrl and a click swings where it points**, as every click did before;
##   a key or a stick takes any order away; the setting turns all of it off.
## - **A click the builder wants is the builder's.** While building is open, a
##   click on ground a sheet would open for opens the sheet and the Warden stays
##   where they are; a click on a body is still an order.
##
## On the field only through `_unhandled_input`, so a click on the interface is
## never an order. A mouse only: a thumb has its sticks.

## Whether the last left press on the field was taken as an order on a body, so
## the placement cursor does not also open a sheet on its release.
static var press_was_order: bool = false

## How far from the cursor a body is looked for at all: a tall body's head is a
## long way above its feet.
const PICK_REACH: float = 260.0
## Ground is seen from above and a little along, so a ring on it is flattened.
const FLATTEN: float = 0.5

var _field: EnemyField = null
## Markers left by clicks: `{at, age, target}`.
var _marks: Array[Dictionary] = []
var _hover: Node2D = null
var _hover_left: float = 0.0
var _dragging: bool = false
var _drag_left: float = 0.0
var _clock: float = 0.0
## The cursor this node last asked for, so it is set only when it changes.
var _shape_set: int = -1
var _drew_something: bool = false


func setup(field: EnemyField) -> void:
	_field = field
	EventBus.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(_from: int, _to: int) -> void:
	# The field sets its own cursor on a phase change; say ours again next tick.
	_shape_set = -1


func _warden() -> Hero:
	if _field == null or not _field.has_method("hero_node"):
		return null
	return _field.call("hero_node") as Hero


func _orders() -> LocalHeroInput:
	var warden: Hero = _warden()
	return warden.input as LocalHeroInput if warden != null else null


func _wildlife() -> Wildlife:
	if _field == null or not _field.has_method("wildlife"):
		return null
	return _field.call("wildlife") as Wildlife


## Whether a click on the field is an order right now.
func live() -> bool:
	if _field == null or not _field.is_visible_in_tree():
		return false
	if not UserSettings.click_to_move() or TouchInput.is_showing():
		return false
	var warden: Hero = _warden()
	return warden != null and warden.is_alive() and _orders() != null


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		if not click.pressed:
			_dragging = false
			return
		press_was_order = false
		if live():
			_on_press(get_global_mouse_position(), click.ctrl_pressed)
		return
	if event.is_action_pressed(&"ranged") and live():
		_on_bow(get_global_mouse_position())


## A left press at `at` on the field.
func _on_press(at: Vector2, ctrl: bool) -> void:
	var orders: LocalHeroInput = _orders()
	if ctrl:
		# A swing where it points; the order it interrupts is over.
		orders.clear_order()
		return
	# The prompt's own offer is used by the click, as it always was.
	if EventBus.lands_on_prompt(at):
		return
	var body: Node2D = body_at(at)
	if body != null:
		orders.order_attack(body, false)
		press_was_order = true
		_mark(Hitbox.feet_of(body), true)
		return
	var placement := _field.get("placement") as PlacementCursor
	if placement != null and placement.takes_click(at):
		return
	orders.order_move(at)
	_mark(at, false)
	_dragging = true
	_drag_left = 1.0 / Balance.CLICK_MOVE_DRAG_HZ


## F with the cursor on a body: chase it to the bow's reach. F on nothing
## looses where it points, and ends a bow order rather than being swallowed by it.
func _on_bow(at: Vector2) -> void:
	var orders: LocalHeroInput = _orders()
	var body: Node2D = body_at(at)
	if body != null:
		orders.order_attack(body, true)
		_mark(Hitbox.feet_of(body), true)
	elif orders.order == LocalHeroInput.Order.SHOOT:
		orders.clear_order()


## **The body a click at `at` lands on**, or null: the nearest a click could
## mean - within its own outline and `CLICK_MOVE_PICK_SLOP` of it - of the road's
## bodies and the field's animals, by the rule the order keeps it by.
func body_at(at: Vector2) -> Node2D:
	if _field == null:
		return null
	var best: Node2D = null
	var best_gap: float = INF
	var wildlife: Wildlife = _wildlife()
	for enemy: Enemy in _field.enemies_near(at, PICK_REACH):
		if not LocalHeroInput.can_target(enemy, wildlife):
			continue
		var gap: float = Hitbox.gap(enemy, at) - enemy.contact_radius()
		if gap <= Balance.CLICK_MOVE_PICK_SLOP and gap < best_gap:
			best = enemy
			best_gap = gap
	if wildlife != null:
		for sprite: Node2D in wildlife.living_sprites():
			if sprite.global_position.distance_squared_to(at) > PICK_REACH * PICK_REACH:
				continue
			if not LocalHeroInput.can_target(sprite, wildlife):
				continue
			var gap: float = Hitbox.gap(sprite, at) - Balance.ENEMY_BODY_RADIUS
			if gap <= Balance.CLICK_MOVE_PICK_SLOP and gap < best_gap:
				best = sprite
				best_gap = gap
	return best


func _mark(at: Vector2, target: bool) -> void:
	_marks.append({"at": at, "age": 0.0, "target": target})
	if _marks.size() > 6:
		_marks.pop_front()


func _process(delta: float) -> void:
	_clock += delta
	for index: int in range(_marks.size() - 1, -1, -1):
		_marks[index]["age"] = float(_marks[index]["age"]) + delta
		if float(_marks[index]["age"]) >= Balance.CLICK_MOVE_MARK_SECONDS:
			_marks.remove_at(index)
	var on: bool = live()
	if not on:
		_dragging = false
		_hover = null
		# Hand the cursor back to the field's own choice, once.
		if _shape_set != -1 and _field != null and _field.is_visible_in_tree():
			if RunState.is_preparation():
				CursorKit.use_build()
			else:
				CursorKit.use_attack()
		_shape_set = -1
	else:
		_tick_hover(delta)
		_tick_drag(delta)
	var drawing: bool = not _marks.is_empty() or (on and (_hover != null or _ordered_body() != null))
	if drawing or _drew_something:
		queue_redraw()
	_drew_something = drawing


## What the cursor is over, a few times a second, and the cursor to match: the
## crossed swords over something a click would chase, the plain arrow over
## ground in a fight - League's - and the builder's own while building is open.
func _tick_hover(delta: float) -> void:
	_hover_left -= delta
	if _hover_left > 0.0:
		return
	_hover_left = 1.0 / Balance.CLICK_MOVE_HOVER_HZ
	_hover = body_at(get_global_mouse_position())
	var want: int = Input.CURSOR_CROSS
	if _hover == null:
		want = Input.CURSOR_MOVE if RunState.is_preparation() and GameDirector.build_mode \
			else Input.CURSOR_ARROW
	if want != _shape_set:
		_shape_set = want
		Input.set_default_cursor_shape(want as Input.CursorShape)


## The button held after a ground click steers.
func _tick_drag(delta: float) -> void:
	if not _dragging:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = false
		return
	var orders: LocalHeroInput = _orders()
	if orders.order != LocalHeroInput.Order.MOVE:
		_dragging = false
		return
	_drag_left -= delta
	if _drag_left > 0.0:
		return
	_drag_left = 1.0 / Balance.CLICK_MOVE_DRAG_HZ
	orders.order_move(get_global_mouse_position())


func _ordered_body() -> Node2D:
	var orders: LocalHeroInput = _orders()
	if orders == null or orders.order == LocalHeroInput.Order.NONE \
			or orders.order == LocalHeroInput.Order.MOVE:
		return null
	return orders.order_target()


func _draw() -> void:
	if not _drew_something and _marks.is_empty():
		return
	var chased: Node2D = _ordered_body()
	if chased != null:
		_ring_under(chased, Balance.CLICK_MOVE_TARGET_COLOUR, 1.0)
	if _hover != null and _hover != chased:
		_ring_under(_hover, Balance.CLICK_MOVE_TARGET_COLOUR, 0.45)
	for mark: Dictionary in _marks:
		var share: float = float(mark["age"]) / Balance.CLICK_MOVE_MARK_SECONDS
		var at: Vector2 = to_local(mark["at"] as Vector2)
		if bool(mark["target"]):
			_click_burst(at, Balance.CLICK_MOVE_TARGET_COLOUR, share, 40.0)
		else:
			_click_burst(at, Balance.CLICK_MOVE_GROUND_COLOUR, share, 30.0)


## A ring on the ground under a body, sized to it and breathing.
func _ring_under(body: Node2D, colour: Color, strength: float) -> void:
	if not is_instance_valid(body):
		return
	var enemy := body as Enemy
	var radius: float = (enemy.contact_radius() if enemy != null else Balance.ENEMY_BODY_RADIUS) * 1.35
	radius *= 1.0 + 0.06 * sin(_clock * 6.0)
	var at: Vector2 = to_local(Hitbox.feet_of(body))
	_ellipse(at, radius, Color(colour, 0.85 * strength), 2.5)
	_ellipse(at, radius + 5.0, Color(colour, 0.25 * strength), 5.0)


## League's click marker: a ring closing on the point and four chevrons
## falling into it, fading as they arrive.
func _click_burst(at: Vector2, colour: Color, share: float, size: float) -> void:
	var fade: float = 1.0 - share
	var radius: float = lerpf(size, size * 0.3, ease(share, 0.6))
	_ellipse(at, radius, Color(colour, 0.9 * fade), 2.5)
	draw_circle(at, 3.0 * fade + 1.0, Color(colour, 0.8 * fade))
	for quarter: int in 4:
		var angle: float = TAU * 0.25 * quarter + PI * 0.25
		var out: Vector2 = Vector2(cos(angle), sin(angle) * FLATTEN)
		var tip: Vector2 = at + out * (radius + 4.0)
		var back: Vector2 = at + out * (radius + 14.0)
		var side: Vector2 = Vector2(-out.y, out.x).normalized() * 6.0
		draw_polyline(PackedVector2Array([back + side, tip, back - side]),
			Color(colour, fade), 2.5, true)


func _ellipse(at: Vector2, radius: float, colour: Color, width: float) -> void:
	var points := PackedVector2Array()
	for step: int in 33:
		var angle: float = TAU * float(step) / 32.0
		points.append(at + Vector2(cos(angle), sin(angle) * FLATTEN) * radius)
	draw_polyline(points, colour, width, true)
