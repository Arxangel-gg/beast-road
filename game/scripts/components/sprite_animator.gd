class_name SpriteAnimator
extends Node

## Procedural animation for a single sprite: walk bounce, tilt, squash, recoil,
## attack punch, dash stretch.
##
## Every asset in this game is one static PNG. There are no frames, no rigs and
## no spritesheets — so all motion has to come from what can be done to a
## transform. That turns out to be most of it: bounce, lean, squash on footfall
## and a recoil on impact read as *alive* far more than an idle cycle does.
##
## The design rule here is that every effect writes to its **own** channel and
## the channels are summed once, at the end of the frame. Nothing assigns
## `sprite.position` directly. Two systems both writing a position is how you
## get an attack that cancels a walk cycle and a limp-looking character.
##
## `mass` scales everything: a Warden lands heavier and slower than a Glass-born,
## from one number rather than from a second set of constants.

@export var sprite: Sprite2D

## 1.0 is a human. Higher is heavier: slower bounce, deeper landing, more shake.
@export var mass: float = 1.0

## Where the sprite sits at rest. Captured on ready so the offsets are relative.
var _home: Vector2 = Vector2.ZERO
var _home_scale: Vector2 = Vector2.ONE

## Walk cycle phase, in radians. Advanced by distance travelled rather than by
## time, so a slowed enemy takes visibly slower steps instead of moon-walking.
var _stride: float = 0.0
var _moving: bool = false
var _speed_ratio: float = 0.0

## Footfall detection: the stride crossing a bottom of its arc.
var _last_stride_sin: float = 0.0

# --- Channels, each decaying independently ---
var _recoil: Vector2 = Vector2.ZERO
var _punch: Vector2 = Vector2.ZERO
var _squash: float = 0.0
var _lean: float = 0.0
var _spin: float = 0.0
var _stretch_dir: Vector2 = Vector2.ZERO
var _stretch: float = 0.0
var _balance_wobble: float = 0.0
var _impact_hold_left: float = 0.0

## Set while dashing so the sprite streaks along the movement direction.
var _dash_left: float = 0.0
var _dash_total: float = 0.0


func _ready() -> void:
	capture_home()


## Re-reads the sprite's rest transform. A child's _ready() runs before its
## parent's, so an owner that sets sprite.scale in its own _ready must call this
## afterwards - otherwise the animator composes against a stale rest pose and
## silently undoes the change on the next frame.
func capture_home() -> void:
	if sprite == null:
		return
	_home = sprite.position
	_home_scale = sprite.scale


## Called every frame by the owner with its current velocity.
func set_motion(velocity: Vector2, max_speed: float, delta: float) -> void:
	var speed: float = velocity.length()
	_moving = speed > 4.0
	_speed_ratio = clampf(speed / maxf(max_speed, 1.0), 0.0, 1.6)

	if _moving:
		# Phase advances with distance, not time. Two units at different speeds
		# then share a stride *length* rather than a stride *rate*, which is what
		# stops slowed enemies looking like they are skating.
		var stride_rate: float = Balance.ANIM_STRIDE_PER_PIXEL / maxf(_mass_scale(), 0.4)
		_stride += speed * delta * stride_rate * TAU
	else:
		# Settle the cycle back to neutral rather than freezing mid-step.
		_stride = fmod(_stride, TAU)
		var target: float = 0.0 if _stride < PI else TAU
		_stride = lerpf(_stride, target, 1.0 - exp(-Balance.ANIM_SETTLE_SPEED * delta))

	_detect_footfall()


## A blow landed on this unit: knock the sprite away from the source.
func recoil(from: Vector2, world_position: Vector2, strength: float = 1.0) -> void:
	var away: Vector2 = world_position - from
	away = away.normalized() if away.length() > 0.001 else Vector2.UP
	_recoil = away * Balance.ANIM_RECOIL_DISTANCE * strength / _mass_scale()
	_squash = maxf(_squash, Balance.ANIM_HURT_SQUASH * strength)


## This unit swung: throw the sprite into the swing and back.
func punch(direction: Vector2, strength: float = 1.0) -> void:
	_punch = direction.normalized() * Balance.ANIM_PUNCH_DISTANCE * strength
	_lean = signf(direction.x) * Balance.ANIM_PUNCH_LEAN * strength
	_squash = maxf(_squash, Balance.ANIM_PUNCH_SQUASH * strength)


## Stretch along the dash for its duration, then snap back.
func dash(direction: Vector2, duration: float) -> void:
	_stretch_dir = direction.normalized()
	_dash_total = maxf(duration, 0.01)
	_dash_left = _dash_total
	_stretch = Balance.ANIM_DASH_STRETCH


## A one-off vertical compress, for landings and heavy footfalls.
func squash(amount: float) -> void:
	_squash = maxf(_squash, amount)


## A local impact frame: only the struck silhouette holds, never the whole game.
## This keeps rapid tower volleys juicy without turning them into global stutter.
func impact_frame(duration: float = Balance.IMPACT_FRAME_TIME) -> void:
	_impact_hold_left = maxf(_impact_hold_left, duration)


## The city shell lurched under a colossal step. Units compress and counter-lean
## for a beat as though fighting for balance.
func beast_step(direction: Vector2, strength: float) -> void:
	_squash = maxf(_squash, 0.055 * strength)
	_balance_wobble = -signf(direction.x) * Balance.BEAST_STEP_WOBBLE_DEGREES * strength


## Death: fall over and shrink. Owner still controls the fade.
func topple(direction: float) -> void:
	_spin = signf(direction) * Balance.ANIM_DEATH_SPIN
	_squash = maxf(_squash, Balance.ANIM_DEATH_SQUASH)


func _process(delta: float) -> void:
	if sprite == null:
		return

	if _impact_hold_left > 0.0:
		_impact_hold_left = maxf(_impact_hold_left - delta, 0.0)
	else:
		_decay(delta)

	# --- Compose. Every channel contributes; none of them assign. ---
	var offset: Vector2 = Vector2.ZERO
	var rotation_now: float = 0.0
	var scale_now: Vector2 = Vector2.ONE

	if _moving or absf(sin(_stride)) > 0.01:
		# The bounce is a *rectified* sine: the body rises on each step rather
		# than dipping below the ground on alternate ones.
		var bounce: float = absf(sin(_stride)) * Balance.ANIM_BOUNCE_HEIGHT
		bounce *= _speed_ratio * _mass_scale()
		offset.y -= bounce

		# The lean runs at half the stride rate, so the body sways once per two
		# steps instead of twitching on every one.
		rotation_now += sin(_stride * Balance.ANIM_TILT_RATE) * deg_to_rad(Balance.ANIM_WALK_TILT) * _speed_ratio

		# Slight horizontal drift with the sway sells weight shifting between feet.
		offset.x += cos(_stride * Balance.ANIM_TILT_RATE) * Balance.ANIM_WALK_SWAY * _speed_ratio

	offset += _recoil + _punch

	if _squash > 0.001:
		# Volume-preserving: what is lost in height is gained in width, which is
		# what makes squash read as physical rather than as a scale glitch.
		scale_now.y *= 1.0 - _squash
		scale_now.x *= 1.0 + _squash * Balance.ANIM_SQUASH_WIDEN

	if _stretch > 0.001:
		# Directional stretch, applied along the dash axis by rotating into it,
		# scaling, and rotating back.
		var along: float = 1.0 + _stretch
		var across: float = 1.0 / maxf(along, 0.01)
		var axis: float = _stretch_dir.angle()
		rotation_now += axis
		scale_now *= Vector2(along, across)
		rotation_now -= axis
		# The net rotation cancels; the scale does not. Godot has no shear on
		# Node2D, so this is the honest approximation and it reads fine in motion.

	rotation_now += deg_to_rad(_lean) + deg_to_rad(_spin) + deg_to_rad(_balance_wobble)

	sprite.position = _home + offset
	sprite.rotation = rotation_now
	sprite.scale = _home_scale * scale_now


func _decay(delta: float) -> void:
	_recoil = _recoil.move_toward(Vector2.ZERO, Balance.ANIM_RECOIL_DECAY * delta)
	_punch = _punch.move_toward(Vector2.ZERO, Balance.ANIM_PUNCH_DECAY * delta)
	_squash = move_toward(_squash, 0.0, Balance.ANIM_SQUASH_DECAY * delta)
	_lean = move_toward(_lean, 0.0, Balance.ANIM_LEAN_DECAY * delta)
	_spin = move_toward(_spin, 0.0, Balance.ANIM_SPIN_DECAY * delta * 0.15)
	_balance_wobble = move_toward(_balance_wobble, 0.0,
		Balance.BEAST_STEP_WOBBLE_DEGREES * 7.0 * delta)

	if _dash_left > 0.0:
		_dash_left = maxf(_dash_left - delta, 0.0)
		_stretch = Balance.ANIM_DASH_STRETCH * (_dash_left / _dash_total)
	else:
		_stretch = move_toward(_stretch, 0.0, Balance.ANIM_STRETCH_DECAY * delta)


## Fires a small squash each time a foot lands, and asks for a screen shake when
## the unit is heavy enough to deserve one.
func _detect_footfall() -> void:
	if not _moving:
		_last_stride_sin = 0.0
		return
	var now: float = sin(_stride)
	# Crossing zero downward is the bottom of the arc: a foot just landed.
	var landed: bool = _last_stride_sin > 0.0 and now <= 0.0
	_last_stride_sin = now
	if not landed:
		return

	_squash = maxf(_squash, Balance.ANIM_STEP_SQUASH * _mass_scale() * _speed_ratio)

	# The animator already knows exactly when a foot lands; nothing else does.
	# Without this there is no event a footstep sound could hang off.
	var owner_2d: Node2D = sprite.get_parent() as Node2D
	if owner_2d != null:
		EventBus.footfall.emit(owner_2d.global_position, mass)

	# Only things with real weight shake the screen, and only when moving with
	# intent — otherwise a crowd of walkers would shake it continuously.
	if mass >= Balance.ANIM_SHAKE_MASS_THRESHOLD and _speed_ratio > 0.4:
		var strength: float = (mass - Balance.ANIM_SHAKE_MASS_THRESHOLD + 1.0) * Balance.ANIM_STEP_SHAKE
		EventBus.camera_shake_requested.emit(strength, Balance.ANIM_STEP_SHAKE_TIME)


## Heavier units bounce less and land harder. Clamped so a boss does not become
## completely static.
func _mass_scale() -> float:
	return clampf(1.0 / sqrt(maxf(mass, 0.1)), 0.35, 1.8)
