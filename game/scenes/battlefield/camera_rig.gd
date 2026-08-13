class_name CameraRig
extends Camera2D

## Follows the hero, leans slightly toward the mouse, shakes on impact, and can
## carry the battlefield on the beast's deliberately subtle walking rhythm.
##
## Position is driven here rather than with Camera2D's built-in smoothing
## because the lean and the shake have to compose with it, and `offset` is the
## only channel left free for shake once smoothing owns the position.
##
## Zoom is per scope: the battlefield has to show all four lanes at once or the
## triage decision is invisible, while the raid can sit close.

@export var target: Node2D

## 0 falls back to the Balance default.
@export var zoom_level: float = 0.0

## Enabled only for the battlefield. The raid is on the ground and must remain
## spatially still.
@export var beast_motion: bool = false

var _shake_magnitude: float = 0.0
var _shake_left: float = 0.0
var _shake_duration: float = 0.0
var _rng := RandomNumberGenerator.new()
var _wanted_zoom: float = 1.0
var _shake_offset: Vector2 = Vector2.ZERO
var _gait_phase: float = 0.0
var _gait_strength: float = 0.0
var _gait_pause_left: float = 0.0
var _gait_step: int = 0
var _step_sink: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_wanted_zoom = zoom_level if zoom_level > 0.0 else Balance.CAMERA_ZOOM
	zoom = Vector2.ONE * _wanted_zoom
	EventBus.camera_shake_requested.connect(_on_shake_requested)
	if target != null:
		global_position = target.global_position


func _process(delta: float) -> void:
	var zoom_t: float = 1.0 - exp(-Balance.CAMERA_ZOOM_LERP_SPEED * delta)
	zoom = zoom.lerp(Vector2.ONE * _wanted_zoom, zoom_t)
	if target != null and is_instance_valid(target):
		var desired: Vector2 = target.global_position
		# Windows may report the cursor millions of pixels outside the viewport
		# during startup, alt-tab, or a display-mode change. Unbounded look-ahead
		# turns that transient input into a camera teleport away from the game.
		var to_mouse: Vector2 = (get_global_mouse_position() - target.global_position) \
			.limit_length(Balance.CAMERA_MOUSE_LEAN_MAX)
		desired += to_mouse * Balance.CAMERA_MOUSE_LEAN
		# Frame-rate independent exponential smoothing. A plain lerp by
		# `speed * delta` changes feel with frame rate; this does not.
		var t: float = 1.0 - exp(-Balance.CAMERA_SMOOTHING_SPEED * delta)
		global_position = global_position.lerp(desired, t)

	_tick_shake(delta)
	_tick_gait(delta)


func zoom_by(steps: int) -> bool:
	if steps == 0:
		return false
	var before: float = _wanted_zoom
	_wanted_zoom = clampf(_wanted_zoom + Balance.CAMERA_ZOOM_STEP * float(steps),
		Balance.CAMERA_ZOOM_BATTLEFIELD_MIN, Balance.CAMERA_ZOOM_BATTLEFIELD_MAX)
	return not is_equal_approx(before, _wanted_zoom)


func is_fully_zoomed_out() -> bool:
	return _wanted_zoom <= Balance.CAMERA_ZOOM_BATTLEFIELD_MIN + 0.001


func reset_to_wide() -> void:
	_wanted_zoom = Balance.CAMERA_ZOOM_BATTLEFIELD_MIN


func _tick_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		_shake_offset = Vector2.ZERO
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	var falloff: float = _shake_left / _shake_duration if _shake_duration > 0.0 else 0.0
	var amount: float = _shake_magnitude * falloff
	_shake_offset = Vector2(_rng.randf_range(-amount, amount), _rng.randf_range(-amount, amount))


## Camera-only motion keeps simulation, collision and tower-click coordinates
## deterministic. The HUD is a CanvasLayer, so it stays pin-sharp while the
## world beneath it breathes with the beast's stride.
func _tick_gait(delta: float) -> void:
	if not beast_motion:
		offset = _shake_offset
		rotation = 0.0
		return
	var setting: float = UserSettings.number(UserSettings.GAIT_KEY, 0.65)
	if setting <= 0.001:
		_gait_strength = 0.0
		offset = _shake_offset
		rotation = 0.0
		return
	var speed_ratio: float = clampf(RunState.beast_speed / Balance.BEAST_BASE_SPEED, 0.0, 1.5)
	var target_strength: float = setting * speed_ratio
	if RunState.horn_active:
		target_strength *= Balance.BEAST_GAIT_HORN_SCALE
	var smooth: float = 1.0 - exp(-Balance.BEAST_GAIT_SMOOTHING * delta)
	_gait_strength = lerpf(_gait_strength, target_strength, smooth)
	if _gait_pause_left > 0.0:
		_gait_pause_left = maxf(_gait_pause_left - delta, 0.0)
	else:
		_gait_phase += delta * Balance.BEAST_GAIT_FREQUENCY * TAU * maxf(speed_ratio, 0.25)
		var step: int = int(floor(_gait_phase / PI))
		if step > _gait_step:
			_gait_step = step
			_plant_step()
	_step_sink = move_toward(_step_sink, 0.0,
		delta / maxf(Balance.BEAST_STEP_SHAKE_TIME, 0.01))

	var gait := Vector2(
		sin(_gait_phase * 0.5) * Balance.BEAST_GAIT_HORIZONTAL,
		sin(_gait_phase) * Balance.BEAST_GAIT_VERTICAL \
			+ Balance.BEAST_STEP_SINK * _step_sink) * _gait_strength
	offset = _shake_offset + gait
	rotation = deg_to_rad(sin(_gait_phase * 0.5 + 0.4) \
		* Balance.BEAST_GAIT_ROTATION_DEGREES * _gait_strength)


## Alternating pair-support footfall. The camera motion pauses at the planted
## frame, sinks under the beast's mass, and receives a brief decaying impact.
## Simulation coordinates do not move; only the presentation camera does.
func _plant_step() -> void:
	_gait_pause_left = Balance.BEAST_STEP_PAUSE
	_step_sink = 1.0
	if not is_current() or _gait_strength <= 0.02:
		return
	_on_shake_requested(Balance.BEAST_STEP_SHAKE * _gait_strength,
		Balance.BEAST_STEP_SHAKE_TIME)
	EventBus.footfall.emit(global_position, Balance.BEAST_STEP_MASS * _gait_strength)
	var side: float = -1.0 if _gait_step % 2 == 0 else 1.0
	var impulse := Vector2(side * 0.58, 1.0).normalized() \
		* Balance.BEAST_STEP_WORLD_IMPULSE
	EventBus.beast_step_landed.emit(impulse, _gait_strength)


## The strongest request wins rather than the newest, so a big hit is never
## downgraded by a small one arriving a frame later.
func _on_shake_requested(magnitude: float, duration: float) -> void:
	var scaled: float = magnitude * float(MetaState.settings.get("screen_shake", 1.0))
	if scaled <= 0.0 or duration <= 0.0:
		return
	if scaled < _shake_magnitude * (_shake_left / _shake_duration if _shake_duration > 0.0 else 0.0):
		return
	_shake_magnitude = scaled
	_shake_duration = duration
	_shake_left = duration
