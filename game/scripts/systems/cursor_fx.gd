class_name CursorFx
extends CanvasLayer

## **The cursor answers a click** (owner, 2026-09-30: *"Cursor highlight juice
## and vfx"*).
##
## A press anywhere leaves a small ring that opens and fades where it landed,
## a bright point at its middle and a few short sparks thrown out of it - gold
## for the left button, cool for the right, so the two hands of the mouse read
## as two different things. It is drawn on its own layer over every screen, in
## screen space, so it is the same size at every zoom and on every scope.
##
## **A look and never a fact.** It listens to input and hands nothing on: it
## does not consume the event, reads no game state and moves no number, and
## `Graphics.particle_scale` turns it off with the rest of the decoration. At
## most `Balance.CURSOR_FX_MAX` presses are drawn at once, the oldest giving
## way, so a player hammering the mouse costs a fixed handful of triangles.
## Nothing is drawn and nothing is redrawn while no press is in flight.

## The press colours: the left button's warm gold, the right's cool.
const LEFT_TINT: Color = Color(0.99, 0.80, 0.40)
const RIGHT_TINT: Color = Color(0.46, 0.86, 1.0)

var _canvas: Node2D = null
## Each press: where, how old, its colour and the sparks' angles.
var _presses: Array[Dictionary] = []


func _ready() -> void:
	name = "CursorFx"
	layer = 126
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Node2D.new()
	_canvas.name = "Ink"
	add_child(_canvas)
	_canvas.draw.connect(_paint)
	set_process(false)


func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index != MOUSE_BUTTON_LEFT and click.button_index != MOUSE_BUTTON_RIGHT:
		return
	press_at(click.position, click.button_index == MOUSE_BUTTON_RIGHT)


## One press at a screen point. Public so the gate can press without a mouse.
func press_at(at: Vector2, right: bool = false) -> void:
	if Graphics.particle_scale() <= 0.05:
		return
	var angles: PackedFloat32Array = PackedFloat32Array()
	var turn: float = randf() * TAU
	for index: int in Balance.CURSOR_FX_SPARKS:
		angles.append(turn + TAU * float(index) / float(Balance.CURSOR_FX_SPARKS)
			+ randf_range(-0.25, 0.25))
	_presses.append({"at": at, "age": 0.0, "tint": RIGHT_TINT if right else LEFT_TINT,
		"angles": angles})
	while _presses.size() > Balance.CURSOR_FX_MAX:
		_presses.pop_front()
	set_process(true)
	_canvas.queue_redraw()


## How many presses are being drawn, for the gate.
func live() -> int:
	return _presses.size()


func _process(delta: float) -> void:
	for press: Dictionary in _presses:
		press["age"] = float(press["age"]) + delta
	while not _presses.is_empty() and float(_presses[0]["age"]) >= Balance.CURSOR_FX_LIFE:
		_presses.pop_front()
	if _presses.is_empty():
		set_process(false)
	_canvas.queue_redraw()


func _paint() -> void:
	for press: Dictionary in _presses:
		var t: float = clampf(float(press["age"]) / Balance.CURSOR_FX_LIFE, 0.0, 1.0)
		var ease: float = 1.0 - pow(1.0 - t, 3.0)
		var at: Vector2 = press["at"] as Vector2
		var tint: Color = press["tint"] as Color
		var fade: float = 1.0 - t
		var radius: float = lerpf(Balance.CURSOR_FX_RING.x, Balance.CURSOR_FX_RING.y, ease)
		# The ring: a bright line with a soft one outside it, so it has an edge
		# of light rather than a hard stroke.
		_canvas.draw_arc(at, radius + 2.0, 0.0, TAU, 32, Color(tint, 0.22 * fade), 5.0, true)
		_canvas.draw_arc(at, radius, 0.0, TAU, 32, Color(tint, 0.85 * fade), 1.8, true)
		# The point it came from, gone by the first third.
		var flash: float = clampf(1.0 - t * 3.0, 0.0, 1.0)
		if flash > 0.0:
			_canvas.draw_circle(at, 3.5 * flash + 1.0, Color(1.0, 1.0, 1.0, 0.8 * flash))
		# The sparks: short streaks thrown out past the ring and shortening.
		for angle: float in press["angles"] as PackedFloat32Array:
			var way := Vector2.from_angle(angle)
			var inner: float = radius * 0.8 + 4.0 * ease
			var outer: float = inner + Balance.CURSOR_FX_SPARK_LENGTH * fade
			_canvas.draw_line(at + way * inner, at + way * outer,
				Color(tint.lightened(0.3), 0.9 * fade), 1.6, true)
