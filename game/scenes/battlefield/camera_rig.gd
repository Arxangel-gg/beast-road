class_name CameraRig
extends Camera2D

## Follows the hero, leans slightly toward the mouse, and shakes on impact.
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

var _shake_magnitude: float = 0.0
var _shake_left: float = 0.0
var _shake_duration: float = 0.0
var _rng := RandomNumberGenerator.new()
var _wanted_zoom: float = 1.0


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
		var to_mouse: Vector2 = get_global_mouse_position() - target.global_position
		desired += to_mouse * Balance.CAMERA_MOUSE_LEAN
		# Frame-rate independent exponential smoothing. A plain lerp by
		# `speed * delta` changes feel with frame rate; this does not.
		var t: float = 1.0 - exp(-Balance.CAMERA_SMOOTHING_SPEED * delta)
		global_position = global_position.lerp(desired, t)

	_tick_shake(delta)


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
		offset = Vector2.ZERO
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	var falloff: float = _shake_left / _shake_duration if _shake_duration > 0.0 else 0.0
	var amount: float = _shake_magnitude * falloff
	offset = Vector2(_rng.randf_range(-amount, amount), _rng.randf_range(-amount, amount))


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
