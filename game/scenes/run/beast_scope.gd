class_name BeastScope
extends Node2D

## The walk (GDD §7). The beast crossing the land with the town on its back —
## References/Scope3(Beast).png — plus how far there is left to go.
##
## This scope shows state and changes nothing. Its job is to make distance feel
## like a place rather than a number in the corner of a HUD.

## How far the parallax layers scroll per distance unit.
const BACKDROP_SCROLL: float = 2.4
const FOREGROUND_SCROLL: float = 6.0

@export var backdrop: Sprite2D
@export var beast: Sprite2D
@export var route_line: Line2D
@export var route_marker: Sprite2D

## Each scope owns its camera; the run makes the right one current when the
## scope changes, so switching does not leave the view sitting in another scope.
@export var camera: Camera2D


func activate() -> void:
	if camera != null:
		camera.make_current()

var _backdrop_clone: Sprite2D = null
var _zoomed_out: bool = false
var _bob: float = 0.0
var _gait_pause_left: float = 0.0
var _gait_step: int = 0
var _step_sink: float = 0.0
var _step_shake_left: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_setup_route()
	_setup_backdrop()
	EventBus.act_started.connect(func(_a: int, _t: String) -> void: _apply_act_backdrop())


## The backdrop was a single sprite whose x was decremented forever. Once it had
## travelled its own width there was nothing behind it, so the view went blank -
## and the texture never changed, so every act looked like Ashfen.
##
## A second copy sits one width to the right and the pair wrap around each other,
## which tiles an arbitrary distance from two nodes.
func _setup_backdrop() -> void:
	if backdrop == null:
		return
	# The scope camera is centred at world origin. An uncentred 1920x1080 sprite
	# therefore began at that origin and covered only the lower-right quarter of
	# the screen, leaving the rest as the project's grey clear colour.
	backdrop.centered = true
	_backdrop_clone = Sprite2D.new()
	_backdrop_clone.centered = true
	_backdrop_clone.z_index = backdrop.z_index
	backdrop.add_sibling(_backdrop_clone)
	_apply_act_backdrop()


## Each act has its own sky. Falls back to act 1 rather than going blank if a
## backdrop is missing.
func _apply_act_backdrop() -> void:
	if backdrop == null:
		return
	var path: String = "res://art/bg/macro_act%d.png" % clampi(RunState.act, 1, Balance.ACT_COUNT)
	if not ResourceLoader.exists(path):
		path = "res://art/bg/macro_act1.png"
	if not ResourceLoader.exists(path):
		return
	var texture: Texture2D = load(path)
	backdrop.texture = texture
	if _backdrop_clone != null:
		_backdrop_clone.texture = texture
		_backdrop_clone.modulate = backdrop.modulate


## Two sprites leapfrogging: whichever has scrolled fully off the left is moved
## one width to the right of the other.
func _scroll_backdrop() -> void:
	if backdrop == null or backdrop.texture == null or _backdrop_clone == null:
		return
	var width: float = backdrop.texture.get_width() * backdrop.scale.x
	if width <= 0.0:
		return
	var offset: float = fmod(RunState.distance_travelled * BACKDROP_SCROLL, width)
	backdrop.position.x = -offset
	_backdrop_clone.position.x = -offset + width
	_backdrop_clone.position.y = backdrop.position.y


func _process(delta: float) -> void:
	# The beast uses the same paired-support cadence as the battlefield camera.
	# Each alternating plant holds for a beat, then the full body settles under
	# its weight; at least one support pair is always in stance.
	var speed_ratio: float = clampf(RunState.beast_speed / Balance.BEAST_BASE_SPEED, 0.0, 1.5)
	if _gait_pause_left > 0.0:
		_gait_pause_left = maxf(_gait_pause_left - delta, 0.0)
	else:
		_bob += delta * Balance.BEAST_GAIT_FREQUENCY * TAU * maxf(speed_ratio, 0.25)
		var step: int = int(floor(_bob / PI))
		if step > _gait_step:
			_gait_step = step
			_gait_pause_left = Balance.BEAST_STEP_PAUSE
			_step_sink = 1.0
			_step_shake_left = Balance.BEAST_STEP_SHAKE_TIME
			if camera != null and camera.is_current():
				EventBus.footfall.emit(beast.global_position if beast != null else Vector2.ZERO,
					Balance.BEAST_STEP_MASS * speed_ratio)
	_step_sink = move_toward(_step_sink, 0.0,
		delta / maxf(Balance.BEAST_STEP_SHAKE_TIME, 0.01))
	if beast != null:
		beast.position.y = sin(_bob) * 6.0 + Balance.BEAST_STEP_SINK * _step_sink
		beast.position.x = -20.0 + sin(_bob * 0.5) * 8.0
	_update_step_shake(delta, speed_ratio)

	_scroll_backdrop()

	_update_route()


func _update_step_shake(delta: float, strength: float) -> void:
	if camera == null:
		return
	if _step_shake_left <= 0.0 or not camera.is_current():
		camera.offset = Vector2.ZERO
		return
	_step_shake_left = maxf(_step_shake_left - delta, 0.0)
	var falloff: float = _step_shake_left / maxf(Balance.BEAST_STEP_SHAKE_TIME, 0.01)
	var setting: float = UserSettings.number(UserSettings.GAIT_KEY, 0.65) \
		* float(MetaState.settings.get(UserSettings.SHAKE_KEY, 1.0))
	var amount: float = Balance.BEAST_STEP_SHAKE * falloff * setting * strength
	camera.offset = Vector2(_rng.randf_range(-amount, amount),
		_rng.randf_range(-amount, amount))


## Toggled from the HUD. Zooming out swaps the walking view for the whole route,
## which is where "how far to the next crossroad" actually reads.
func set_zoomed_out(value: bool) -> void:
	_zoomed_out = value
	if route_line != null:
		route_line.visible = value
	if route_marker != null:
		route_marker.visible = value
	if beast != null:
		beast.scale = Vector2.ONE * (0.45 if value else 1.0)
	var tint: Color = Color(0.55, 0.55, 0.6) if value else Color.WHITE
	if backdrop != null:
		backdrop.modulate = tint
	if _backdrop_clone != null:
		_backdrop_clone.modulate = tint


func is_zoomed_out() -> bool:
	return _zoomed_out


func toggle_zoom() -> void:
	set_zoomed_out(not _zoomed_out)


## The whole journey as one line, with a tick at every crossroad and act
## boundary so the shape of the run is legible at a glance.
func _setup_route() -> void:
	if route_line == null:
		return
	var left: float = -820.0
	var right: float = 820.0
	route_line.points = PackedVector2Array([Vector2(left, 220.0), Vector2(right, 220.0)])
	route_line.width = 6.0
	route_line.default_color = Color(0.85, 0.80, 0.72, 0.5)
	route_line.visible = false

	var segments: int = int(Balance.JOURNEY_TOTAL_DISTANCE / Balance.SEGMENT_DISTANCE)
	for i: int in range(1, segments):
		var t: float = float(i) / float(segments)
		var tick := Line2D.new()
		var x: float = lerpf(left, right, t)
		var is_act_boundary: bool = int(round(t * Balance.JOURNEY_TOTAL_DISTANCE)) % int(Balance.ACT_DISTANCE) == 0
		var height: float = 34.0 if is_act_boundary else 18.0
		tick.points = PackedVector2Array([Vector2(x, 220.0 - height), Vector2(x, 220.0 + height)])
		tick.width = 5.0 if is_act_boundary else 3.0
		tick.default_color = Color(0.91, 0.64, 0.24, 0.9) if is_act_boundary else Color(0.85, 0.80, 0.72, 0.6)
		route_line.add_child(tick)

	if route_marker != null:
		route_marker.visible = false


func _update_route() -> void:
	if route_marker == null or not _zoomed_out:
		return
	route_marker.position = Vector2(lerpf(-820.0, 820.0, RunState.journey_ratio()), 220.0)
