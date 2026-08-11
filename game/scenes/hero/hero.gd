class_name Hero
extends CharacterBody2D

## The hero (GDD §3.1). Movement, dash, health and death; the attack chain is
## its own state machine in hero_attack.gd.
##
## CharacterBody2D rather than a plain Node2D because Stage 2 puts the city and
## four towers in the arena as solid obstacles, and swapping the movement out
## then would mean re-tuning everything below.
##
## Movement speed is the hero's most valuable stat: the job is reaching the lane
## that is collapsing. Nothing here should ever make the hero feel heavy.

const GROUP: StringName = &"hero"

@export var health: Health
@export var attack: HeroAttack
@export var sprite: Sprite2D
@export var health_bar: HealthBar

var _aim: Vector2 = Vector2.RIGHT

var _dash_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT

var _lunge_velocity: Vector2 = Vector2.ZERO
var _lunge_decay: float = 0.0

var _respawn_left: float = 0.0
var _flash_left: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)

	# Balance owns the number, not the scene file, so a designer changes it in
	# one place. revive() resyncs current HP, which Health already set from the
	# scene's default during its own _ready.
	health.max_hp = Balance.HERO_MAX_HP
	health.revive()

	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.changed.connect(_on_health_changed)
	attack.lunge_requested.connect(_on_lunge_requested)
	health_bar.bind(health)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	if health.is_dead:
		_tick_respawn(delta)
		return

	_aim = _compute_aim()

	if Input.is_action_just_pressed(&"attack"):
		attack.request()
	if Input.is_action_just_pressed(&"dash"):
		_try_dash()

	attack.tick(delta, _aim, global_position)

	var move_input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if _dash_left > 0.0:
		velocity = _dash_direction * (Balance.HERO_DASH_DISTANCE / Balance.HERO_DASH_DURATION)
	else:
		velocity = move_input * Balance.HERO_MOVE_SPEED * attack.move_scale()
	velocity += _lunge_velocity

	move_and_slide()

	# The arena is a circle centred on the origin and the hero is clamped to the
	# same ring the enemies spawn on, so there is nowhere to stand that nothing
	# comes from.
	global_position = global_position.limit_length(Balance.ARENA_RADIUS)

	_update_sprite(delta)


func is_alive() -> bool:
	return not health.is_dead


func aim_direction() -> Vector2:
	return _aim


func contact_radius() -> float:
	return Balance.HERO_BODY_RADIUS


## 0..1, for a cooldown readout in a later stage.
func dash_cooldown_ratio() -> float:
	if Balance.HERO_DASH_COOLDOWN <= 0.0:
		return 0.0
	return _dash_cooldown_left / Balance.HERO_DASH_COOLDOWN


func _compute_aim() -> Vector2:
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	return to_mouse.normalized() if to_mouse.length() > 1.0 else _aim


func _tick_timers(delta: float) -> void:
	_dash_left = maxf(_dash_left - delta, 0.0)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _lunge_velocity != Vector2.ZERO:
		_lunge_velocity = _lunge_velocity.move_toward(Vector2.ZERO, _lunge_decay * delta)


func _try_dash() -> void:
	if _dash_cooldown_left > 0.0 or _dash_left > 0.0:
		return
	# Dash where you are steering; fall back to where you are looking, so a
	# standing dash still goes somewhere deliberate.
	var move_input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_dash_direction = move_input.normalized() if move_input.length() > 0.1 else _aim
	_dash_left = Balance.HERO_DASH_DURATION
	_dash_cooldown_left = Balance.HERO_DASH_COOLDOWN
	health.add_invulnerability(Balance.HERO_DASH_IFRAMES)
	EventBus.hero_dashed.emit(Balance.HERO_DASH_IFRAMES)


## Sized so the lunge covers `distance` while decaying linearly to zero over
## HERO_ATTACK_LUNGE_TIME. Tuning the distance is enough; the speed follows.
func _on_lunge_requested(direction: Vector2, distance: float) -> void:
	var duration: float = Balance.HERO_ATTACK_LUNGE_TIME
	if duration <= 0.0 or distance <= 0.0:
		return
	var speed: float = 2.0 * distance / duration
	_lunge_velocity = direction * speed
	_lunge_decay = speed / duration


func _on_damaged(amount: float, from: Vector2) -> void:
	_flash_left = Balance.HIT_FLASH_TIME
	EventBus.hero_damaged.emit(amount, from)
	EventBus.camera_shake_requested.emit(4.0, 0.18)


func _on_health_changed(current: float, maximum: float) -> void:
	EventBus.hero_health_changed.emit(current, maximum)


func _on_died(at: Vector2) -> void:
	_respawn_left = Balance.HERO_RESPAWN_DELAY
	_dash_left = 0.0
	_lunge_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	attack.cancel()
	sprite.visible = false
	health_bar.visible = false
	RunState.hero_deaths += 1
	EventBus.hero_died.emit(at)


func _tick_respawn(delta: float) -> void:
	_respawn_left -= delta
	if _respawn_left > 0.0:
		return
	global_position = Vector2.ZERO
	health.revive()
	health.add_invulnerability(Balance.HERO_RESPAWN_INVULN)
	sprite.visible = true
	sprite.modulate = Color.WHITE
	health_bar.visible = true
	EventBus.hero_respawned.emit(global_position)


func _update_sprite(_delta: float) -> void:
	sprite.flip_h = _aim.x < 0.0

	var tint: Color = Color.WHITE
	if _flash_left > 0.0:
		tint = Balance.HIT_FLASH_COLOUR.lerp(Color.WHITE, 1.0 - _flash_left / Balance.HIT_FLASH_TIME)
	# Blinking is the only cue that i-frames are active, and the dash is the
	# hero's whole defensive game — it has to be unmissable.
	if health.is_invulnerable():
		var phase: float = Time.get_ticks_msec() / 1000.0 * Balance.INVULN_BLINK_RATE
		tint.a = 0.35 + 0.4 * (0.5 + 0.5 * sin(phase * TAU))
	sprite.modulate = tint
