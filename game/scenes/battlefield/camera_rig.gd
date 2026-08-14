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

## Which way the blow shoved. A shake with no direction cannot tell the player
## where it came from, which is the whole point of shaking on a footfall.
var _shake_direction: Vector2 = Vector2.RIGHT
## Re-rolled per impact so two steps never tremble in exactly the same pattern.
var _rumble_seed: float = 0.0


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


## Two overlapping decays: the blow, and the ringing it leaves behind.
##
## Every term is a function of how long the shake has been running, so the same
## impact reaches the same offset at the same moment on every machine. The
## previous version drew a fresh random offset per frame, which meant the shake
## vibrated at whatever the frame rate happened to be - a different effect at 60
## and at 144, and nothing anyone could tune. See the SHAKE_ block in Balance.
func _tick_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		_shake_offset = Vector2.ZERO
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	var remaining: float = _shake_left / _shake_duration if _shake_duration > 0.0 else 0.0
	var elapsed: float = _shake_duration - _shake_left

	# Thunder. `cos` rather than `sin` so the first frame is already at full
	# displacement: the shove is the impact, and easing into it would read as the
	# camera drifting rather than as being hit.
	var thunder_phase: float = TAU * Balance.SHAKE_THUNDER_HZ * elapsed
	var thunder: Vector2 = _shake_direction \
		* cos(thunder_phase) \
		* _shake_magnitude * pow(remaining, Balance.SHAKE_THUNDER_DECAY)

	# Rumble. Quieter, finer, climbing in pitch as the energy leaves it - a
	# struck mass rings low while it still has amplitude and finer as it settles,
	# and that climb is most of what makes an impact feel like weight rather than
	# like static.
	#
	# Phase is the integral of a linearly rising frequency, in closed form. A
	# running `phase += delta * pitch` would be a Riemann sum of the same
	# integral, and lands on a visibly different phase at 50fps than at 250 -
	# which is the exact frame-rate dependence this rewrite exists to remove.
	var climb: float = Balance.SHAKE_RUMBLE_HZ_END - Balance.SHAKE_RUMBLE_HZ_START
	var rumble_phase: float = TAU * (Balance.SHAKE_RUMBLE_HZ_START * elapsed \
		+ climb * elapsed * elapsed / (2.0 * maxf(_shake_duration, 0.0001)))

	# The axes run at slightly different rates so it trembles rather than sliding
	# back and forth along one line.
	var rumble_amount: float = _shake_magnitude * Balance.SHAKE_RUMBLE_SCALE \
		* pow(remaining, Balance.SHAKE_RUMBLE_DECAY)
	var rumble := Vector2(
		sin(rumble_phase + _rumble_seed),
		sin(rumble_phase * 1.37 + _rumble_seed * 2.1)) * rumble_amount

	_shake_offset = thunder + rumble


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

	var presentation_phase: float = _lumbered_phase(_gait_phase)
	var gait := Vector2(
		sin(presentation_phase * 0.5) * Balance.BEAST_GAIT_HORIZONTAL,
		sin(presentation_phase) * Balance.BEAST_GAIT_VERTICAL \
			+ Balance.BEAST_STEP_SINK * _step_sink) * _gait_strength
	offset = _shake_offset + gait
	rotation = deg_to_rad(sin(presentation_phase * 0.5 + 0.4) \
		* Balance.BEAST_GAIT_ROTATION_DEGREES * _gait_strength)


## Most of a support transfer is a slow, burdened lift. The final third gains
## speed into the plant, where the pause, sink and impact take over. The raw
## phase still owns step timing, so this shaping cannot skip a footfall.
func _lumbered_phase(raw_phase: float) -> float:
	var half_step: float = floor(raw_phase / PI)
	var progress: float = fmod(raw_phase, PI) / PI
	var eased: float = pow(clampf(progress, 0.0, 1.0), Balance.BEAST_GAIT_WINDUP_POWER)
	return (half_step + eased) * PI


## Which way the given footfall throws everything standing on the beast.
##
## A four-beat walk, which is how an animal this heavy actually moves: it never
## has fewer than three feet down, and the supports come round one at a time
## rather than in diagonal pairs. Each plant therefore tips the shell a different
## way, and taking those four as the four cardinals means a step lurches the deck
## north, then east, then south, then west instead of rocking on one axis.
##
## The city's own geography is cardinal - four lanes, four gates - so a step that
## shoves everyone west is legible in a way a diagonal is not: the player can see
## which side just took the weight.
static func step_cardinal(step: int) -> Vector2:
	const ORDER: Array[Vector2] = [Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT, Vector2.UP]
	return ORDER[posmod(step, ORDER.size())]


## Alternating pair-support footfall. The camera motion pauses at the planted
## frame, sinks under the beast's mass, and receives a brief decaying impact.
## Simulation coordinates do not move; only the presentation camera does.
func _plant_step() -> void:
	_gait_pause_left = Balance.BEAST_STEP_PAUSE
	_step_sink = 1.0
	if not is_current() or _gait_strength <= 0.02:
		return
	var cardinal: Vector2 = step_cardinal(_gait_step)
	_on_shake_requested(Balance.BEAST_STEP_SHAKE * _gait_strength,
		Balance.BEAST_STEP_SHAKE_TIME, cardinal)
	EventBus.footfall.emit(global_position, Balance.BEAST_STEP_MASS * _gait_strength)
	EventBus.beast_step_landed.emit(cardinal * Balance.BEAST_STEP_WORLD_IMPULSE,
		_gait_strength)


## The strongest request wins rather than the newest, so a big hit is never
## downgraded by a small one arriving a frame later.
##
## `direction` is optional because most callers arrive over `camera_shake_requested`,
## which carries only a magnitude and a duration and is used by a dozen unrelated
## systems. Those get a random direction, which is what they had before. The
## beast's footfall calls this directly and does know which way it shoved.
func _on_shake_requested(magnitude: float, duration: float,
		direction: Vector2 = Vector2.ZERO) -> void:
	var scaled: float = magnitude * float(MetaState.settings.get("screen_shake", 1.0))
	if scaled <= 0.0 or duration <= 0.0:
		return
	if scaled < _shake_magnitude * (_shake_left / _shake_duration if _shake_duration > 0.0 else 0.0):
		return
	_shake_magnitude = scaled
	_shake_duration = duration
	_shake_left = duration
	_shake_direction = direction.normalized() if direction != Vector2.ZERO \
		else Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
	_rumble_seed = _rng.randf_range(0.0, TAU)
