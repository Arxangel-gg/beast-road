class_name PingWheel
extends Control

## **The ping wheel** (triage of 2026-10-07, item 63): eight spokes round the
## point the key went down on, the one the pointer leans toward lit, its word in
## the middle. Letting go in the middle sends nothing, so a wheel opened by
## mistake costs nothing.
##
## A picture and a reading: it decides which spoke is meant and nothing else.
## Sending is `PingField`'s, so the key, the touch square and a gate all go
## through one door.

var _centre: Vector2 = Vector2.ZERO
var _selected: int = -1
var _pings: Array[PingData] = []
var _life: float = 0.0
## Where the pointer is, in this control's coordinates. Read off the viewport
## every frame by default; a gate or the touch square hands a point in instead.
var pointer: Callable = func() -> Vector2: return get_local_mouse_position()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Opens round `at`, pulled in from the edges so every spoke is on the screen.
func open(at: Vector2) -> void:
	_pings = ContentDB.ping_list()
	var screen: Rect2 = get_viewport_rect()
	var room: float = Balance.PING_WHEEL_RADIUS + 24.0
	_centre = Vector2(clampf(at.x, room, maxf(room, screen.size.x - room)),
		clampf(at.y, room, maxf(room, screen.size.y - room)))
	_selected = -1
	_life = 0.0
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	_selected = -1


func is_open() -> bool:
	return visible


func centre() -> Vector2:
	return _centre


## The ping the pointer leans toward, or "" in the middle.
func chosen() -> String:
	for data: PingData in _pings:
		if data.slot == _selected:
			return data.id
	return ""


## Which spoke an offset from the middle leans toward: 0 straight up, counted
## clockwise, -1 inside the dead middle.
static func spoke_for(offset: Vector2, dead: float = Balance.PING_WHEEL_DEAD) -> int:
	if offset.length() < dead:
		return -1
	var angle: float = atan2(offset.x, -offset.y)
	return posmod(int(round(angle / (TAU / 8.0))), 8)


func _process(delta: float) -> void:
	if not visible:
		return
	_life += delta
	var lean: int = spoke_for(pointer.call() - _centre)
	if lean != _selected:
		_selected = lean
		if lean >= 0:
			Sfx.play("sfx_ui_hover")
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var grow: float = clampf(_life / 0.09, 0.0, 1.0)
	var outer: float = Balance.PING_WHEEL_RADIUS * (0.7 + 0.3 * grow)
	var inner: float = Balance.PING_WHEEL_DEAD + 6.0
	draw_circle(_centre, outer + 10.0, Color(0.02, 0.03, 0.03, 0.42 * grow))
	var step: float = TAU / 8.0
	for data: PingData in _pings:
		var middle: float = float(data.slot) * step - PI * 0.5
		var lit: bool = data.slot == _selected
		var points := PackedVector2Array()
		for index: int in 9:
			var angle: float = middle - step * 0.46 + step * 0.92 * float(index) / 8.0
			points.append(_centre + Vector2.from_angle(angle) * outer)
		for index: int in range(8, -1, -1):
			var angle: float = middle - step * 0.46 + step * 0.92 * float(index) / 8.0
			points.append(_centre + Vector2.from_angle(angle) * inner)
		var fill: Color = Color(data.colour, 0.62) if lit else Color(0.06, 0.08, 0.08, 0.72)
		draw_colored_polygon(points, Color(fill, fill.a * grow))
		var rim: Color = Color(data.colour, (0.95 if lit else 0.45) * grow)
		draw_polyline(points + PackedVector2Array([points[0]]), rim, 1.5, true)
		var icon: Texture2D = IconKit.ui(data.icon)
		if icon != null:
			var size: float = 34.0 if lit else 28.0
			var at: Vector2 = _centre + Vector2.from_angle(middle) * (inner + outer) * 0.5
			draw_texture_rect(icon, Rect2(at - Vector2.ONE * size * 0.5, Vector2.ONE * size),
				false, Color(1.0, 1.0, 1.0, grow))
	# The middle says what letting go will send.
	var word: String = ""
	var tint: Color = Color(0.85, 0.82, 0.74)
	for data: PingData in _pings:
		if data.slot == _selected:
			word = data.display_name
			tint = data.colour
	draw_circle(_centre, inner - 2.0, Color(0.03, 0.04, 0.04, 0.85 * grow))
	var font: Font = UiFonts.face(UiFonts.Role.BUTTON)
	if font != null and not word.is_empty():
		var width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var at: Vector2 = _centre + Vector2(-width * 0.5, -outer - 18.0)
		draw_string_outline(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6,
			Color(0.02, 0.03, 0.03, 0.9 * grow))
		draw_string(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, tint)
