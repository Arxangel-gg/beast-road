class_name MenuButtonFx
extends Control

## **A front-door button that is never quite still** (owner, 2026-10-07: *"Make
## main menu buttons semitransparent and have game juicy vfx animations as they
## idle as well, and affect those also when hovered"*).
##
## One drawn child of the button, over its plate and taking no press. At rest a
## rim breathes, a glint walks the frame and the odd ember rises off the bottom
## edge; under the pointer or the pad's focus the rim brightens, the glint runs
## and embers burst off it; a press flashes. Drawn additively, so it can only
## add light - over a dark plate and pale lettering no word loses contrast.
##
## **It belongs to the front door and nowhere else.** `HubScreen.adopt` moves a
## menu button into the Hold with its children; a door that leaves `column`
## draws nothing and ticks nothing, so the Hold's grid is the Hold's.
##
## A look and never a fact: nothing reads it, it rolls its own dice, and
## `Graphics.particle_scale` takes its embers to nothing.

## The column whose buttons this lights; a button anywhere else is left alone.
var column: Control = null
## The colour it lights in, chosen by the button's kind.
var tint: Color = Color(1.0, 0.84, 0.5)

var _button: Button = null
var _clock: float = 0.0
var _phase: float = 0.0
var _hover: float = 0.0
var _hovered: bool = false
var _flash: float = 0.0
var _redraw_left: float = 0.0
var _spawn_debt: float = 0.0
var _dice := RandomNumberGenerator.new()
## Embers in flight: x, y, drift, life, age - five floats each.
var _motes: PackedFloat32Array = PackedFloat32Array()

const STRIDE: int = 5


## Dresses `button` with its glow. Returns the glow, or the one it already wore.
static func dress(button: Button, front_column: Control, seed_name: String) -> MenuButtonFx:
	if button == null:
		return null
	for child: Node in button.get_children(true):
		if child is MenuButtonFx:
			(child as MenuButtonFx).column = front_column
			return child as MenuButtonFx
	var fx := MenuButtonFx.new()
	fx.name = "MenuButtonFx"
	fx.column = front_column
	fx._button = button
	fx._dice.seed = hash("menu_button_fx:" + seed_name)
	fx._phase = fx._dice.randf() * TAU
	fx.tint = tint_for(button)
	button.add_child(fx, false, Node.INTERNAL_MODE_BACK)
	return fx


## The glow a button wears, if any.
static func of(button: Button) -> MenuButtonFx:
	if button == null:
		return null
	for child: Node in button.get_children(true):
		if child is MenuButtonFx:
			return child as MenuButtonFx
	return null


## The kit's ember for the road, its red for a door that throws something away,
## and warm gold for every other.
static func tint_for(button: Button) -> Color:
	match button.theme_type_variation:
		&"PrimaryButton":
			return Color(1.0, 0.6, 0.26)
		&"DangerButton":
			return Color(1.0, 0.34, 0.3)
	return Color(1.0, 0.84, 0.5)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	if _button == null:
		_button = get_parent() as Button
	if _button != null:
		_button.mouse_entered.connect(_notice)
		_button.focus_entered.connect(_notice)
		_button.mouse_exited.connect(_leave)
		_button.focus_exited.connect(_leave)
		_button.button_down.connect(_pressed)
		# The menu hands the pad's focus to its first door before this is
		# dressed; a focused door is under the player already.
		_hovered = _button.has_focus() and not _button.disabled
	# Headless nothing is drawn, so nothing ticks; a gate drives `advance`.
	set_process(DisplayServer.get_name() != "headless")


## Whether this button is a front door at this moment.
func lit() -> bool:
	if _button == null or column == null or not is_instance_valid(column):
		return false
	return column.is_ancestor_of(_button) and _button.is_visible_in_tree()


func motes_aloft() -> int:
	return _motes.size() / STRIDE


func hover_share() -> float:
	return _hover


func flash_share() -> float:
	return _flash


func _notice() -> void:
	if _button == null or _button.disabled or _hovered:
		return
	_hovered = true
	_burst(Balance.MENU_BUTTON_FX_BURST)


func _leave() -> void:
	# Focus and the pointer are two ways of being under it; one leaving while
	# the other still holds keeps it lit.
	if _button != null and (_button.has_focus() or _button.is_hovered()):
		return
	_hovered = false


func _pressed() -> void:
	_flash = 1.0
	_burst(Balance.MENU_BUTTON_FX_BURST * 2)


func _process(delta: float) -> void:
	advance(delta)
	_redraw_left -= delta
	if _redraw_left <= 0.0:
		_redraw_left = 1.0 / Balance.MENU_BUTTON_FX_HZ
		queue_redraw()


## One step of the glow's clocks. The game calls it every frame; a gate calls
## it with a clock of its own.
func advance(delta: float) -> void:
	if not lit():
		if not _motes.is_empty():
			_motes.clear()
		visible = false
		return
	visible = true
	_clock += delta
	var want: float = 1.0 if (_hovered and not _button.disabled) else 0.0
	_hover = move_toward(_hover, want, delta / Balance.MENU_BUTTON_FX_EASE)
	_flash = maxf(0.0, _flash - delta / Balance.MENU_BUTTON_FX_FLASH)
	var rate: float = lerpf(Balance.MENU_BUTTON_FX_IDLE_RATE, Balance.MENU_BUTTON_FX_HOVER_RATE, _hover)
	if _button.disabled:
		rate *= 0.25
	_spawn_debt += rate * delta * Graphics.particle_scale()
	while _spawn_debt >= 1.0:
		_spawn_debt -= 1.0
		_spawn(false)
	var index: int = 0
	while index < _motes.size():
		var age: float = _motes[index + 4] + delta
		var life: float = _motes[index + 3]
		if age >= life:
			for _i: int in STRIDE:
				_motes.remove_at(index)
			continue
		_motes[index + 4] = age
		# Rising, swaying, slowing as it cools.
		_motes[index] += _motes[index + 2] * delta + sin(age * 5.0 + float(index)) * 6.0 * delta
		_motes[index + 1] -= Balance.MENU_BUTTON_FX_RISE * (1.0 - age / life * 0.5) * delta
		index += STRIDE


func _burst(count: int) -> void:
	var scaled: int = int(round(float(count) * Graphics.particle_scale()))
	for _i: int in scaled:
		_spawn(true)


func _spawn(burst: bool) -> void:
	if _motes.size() / STRIDE >= Balance.MENU_BUTTON_FX_MAX:
		return
	var box: Vector2 = size
	if box.x <= 1.0 or box.y <= 1.0:
		return
	var x: float = _dice.randf_range(box.x * 0.06, box.x * 0.94)
	var y: float = box.y * _dice.randf_range(0.72, 0.98)
	if burst:
		y = box.y * _dice.randf_range(0.2, 0.95)
	var drift: float = _dice.randf_range(-14.0, 14.0) * (2.4 if burst else 1.0)
	var life: float = _dice.randf_range(0.9, 1.7) * (0.75 if burst else 1.0)
	_motes.append_array(PackedFloat32Array([x, y, drift, life, 0.0]))


func _draw() -> void:
	if not lit():
		return
	var box := Rect2(Vector2.ZERO, size)
	var breath: float = 0.5 + 0.5 * sin(_clock * 1.35 + _phase)
	var dim: float = 0.4 if _button.disabled else 1.0
	# A band of light along the bottom of the plate, as though lit from below.
	var band: float = (0.035 + 0.025 * breath + 0.12 * _hover + 0.3 * _flash) * dim
	var low := Color(tint, band)
	var clear := Color(tint, 0.0)
	var band_top: float = box.size.y * 0.42
	draw_polygon(PackedVector2Array([Vector2(0.0, band_top), Vector2(box.size.x, band_top),
		Vector2(box.size.x, box.size.y), Vector2(0.0, box.size.y)]),
		PackedColorArray([clear, clear, low, low]))
	# The rim breathes, and burns under the pointer.
	var rim: float = (0.08 + 0.06 * breath + 0.42 * _hover + 0.5 * _flash) * dim
	draw_rect(box.grow(-2.0), Color(tint, rim), false, 1.5)
	if _hover > 0.01:
		draw_rect(box.grow(1.0), Color(tint, rim * 0.35), false, 3.0)
	# The glint walks the frame; under the pointer it runs, and a second runs
	# opposite.
	var period: float = lerpf(Balance.MENU_BUTTON_FX_GLINT_SECONDS,
		Balance.MENU_BUTTON_FX_GLINT_HOVER_SECONDS, _hover)
	var along: float = fposmod(_clock / period + _phase / TAU, 1.0)
	_draw_glint(box.grow(-2.0), along, dim * (0.55 + 0.45 * _hover))
	if _hover > 0.2:
		_draw_glint(box.grow(-2.0), fposmod(along + 0.5, 1.0), dim * _hover * 0.8)
	# Embers.
	var index: int = 0
	while index < _motes.size():
		var age: float = _motes[index + 4]
		var life: float = _motes[index + 3]
		var share: float = age / life
		var fade: float = (1.0 - share) * minf(1.0, age * 8.0)
		var at := Vector2(_motes[index], _motes[index + 1])
		var radius: float = 1.6 + 1.2 * (1.0 - share)
		draw_circle(at, radius * 2.6, Color(tint, 0.10 * fade * dim))
		draw_circle(at, radius, Color(tint.lerp(Color.WHITE, 0.45), 0.85 * fade * dim))
		index += STRIDE
	# A press is a flash over the whole plate.
	if _flash > 0.0:
		draw_rect(box, Color(tint, 0.22 * _flash * _flash * dim))


## A bright point and its trail at `along` (0..1) of the way round `frame`.
func _draw_glint(frame: Rect2, along: float, strength: float) -> void:
	var trail: int = 9
	var step: float = 0.012
	var previous: Vector2 = around(frame, along)
	for index: int in range(1, trail + 1):
		var point: Vector2 = around(frame, fposmod(along - step * float(index), 1.0))
		var fade: float = 1.0 - float(index) / float(trail + 1)
		if previous.distance_to(point) < frame.size.length() * 0.2:
			draw_line(previous, point, Color(tint.lerp(Color.WHITE, 0.3), 0.6 * fade * strength), 2.0)
		previous = point
	var head: Vector2 = around(frame, along)
	draw_circle(head, 7.0, Color(tint, 0.14 * strength))
	draw_circle(head, 2.6, Color(tint.lerp(Color.WHITE, 0.6), 0.9 * strength))


## The point `along` (0..1) of the way round a rectangle, by length.
static func around(frame: Rect2, along: float) -> Vector2:
	var w: float = frame.size.x
	var h: float = frame.size.y
	var total: float = (w + h) * 2.0
	var d: float = clampf(along, 0.0, 1.0) * total
	if d < w:
		return frame.position + Vector2(d, 0.0)
	d -= w
	if d < h:
		return frame.position + Vector2(w, d)
	d -= h
	if d < w:
		return frame.position + Vector2(w - d, h)
	d -= w
	return frame.position + Vector2(0.0, h - d)
