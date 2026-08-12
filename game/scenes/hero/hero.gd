class_name Hero
extends CharacterBody2D

## The hero (GDD §3.1). Movement, dash, health and death; the attack chain is
## its own state machine in hero_attack.gd.
##
## CharacterBody2D rather than a plain Node2D so the town and towers can become
## solid obstacles without the movement having to be rewritten and re-tuned.
##
## Movement speed is the hero's most valuable stat: the job is reaching the lane
## that is collapsing. Nothing here should ever make the hero feel heavy.

const GROUP: StringName = &"hero"

@export var health: Health
@export var attack: HeroAttack
@export var sprite: Sprite2D
@export var health_bar: HealthBar
@export var spells: SpellCaster
@export var animator: SpriteAnimator

## How far from the origin the hero may roam. Differs per scope — the
## battlefield lane ring and the raid arena are not the same size — so the
## scene that owns the hero sets it. 0 falls back to the Balance default.
@export var bounds_radius: float = 0.0

## The scope the hero is standing in. Set by that scope on entry — the hero
## never goes looking up the tree for the thing it happens to be parented to.
var field: EnemyField = null:
	set(value):
		field = value
		if spells != null:
			spells.field = value

var _aim: Vector2 = Vector2.RIGHT

var _dash_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT

var _lunge_velocity: Vector2 = Vector2.ZERO
var _lunge_decay: float = 0.0

var _respawn_left: float = 0.0
var _flash_left: float = 0.0

## Ash Veil's movement bonus while it lasts.
var _veil_speed_bonus: float = 0.0
var _veil_left: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)

	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.changed.connect(_on_health_changed)
	attack.lunge_requested.connect(_on_lunge_requested)
	health_bar.bind(health)

	# The hero carries the light the player navigates by after dark.
	LightKit.add_light(self, Balance.HERO_LIGHT_COLOUR, Balance.HERO_LIGHT_RADIUS,
		Balance.HERO_LIGHT_ENERGY, Balance.HERO_LIGHT_FLICKER)
	animator.mass = Balance.ANIM_MASS_HERO
	animator.capture_home()
	attack.landed.connect(_on_attack_landed)

	spells.field = field
	spells.blink_requested.connect(_on_blink)
	spells.veil_requested.connect(_on_veil)
	spells.heal_requested.connect(func(amount: float) -> void: health.heal(amount))

	_apply_permanent_bonuses()


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
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		if Input.is_action_just_pressed(&"spell_%d" % (slot + 1)):
			spells.try_cast(slot, _aim, global_position)

	attack.damage_multiplier = damage_multiplier()
	attack.tick(delta, _aim, global_position)
	spells.tick(delta, _aim, global_position)

	var move_input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if _dash_left > 0.0:
		velocity = _dash_direction * (Balance.HERO_DASH_DISTANCE / Balance.HERO_DASH_DURATION)
	elif spells.is_channelling():
		velocity = Vector2.ZERO
	else:
		velocity = move_input * move_speed() * attack.move_scale()
	velocity += _lunge_velocity

	move_and_slide()

	# The playable area is a circle centred on the origin.
	global_position = global_position.limit_length(
		bounds_radius if bounds_radius > 0.0 else Balance.ARENA_RADIUS)

	animator.set_motion(velocity, move_speed(), delta)
	_update_sprite(delta)


func is_alive() -> bool:
	return not health.is_dead


func aim_direction() -> Vector2:
	return _aim


func contact_radius() -> float:
	return Balance.HERO_BODY_RADIUS


## Base speed after the Sanctum, relics and an active Ash Veil.
func move_speed() -> float:
	var sanctum: BuildingData = ContentDB.building("sanctum")
	var bonus: float = 0.0
	if sanctum != null:
		bonus += sanctum.effect_at(RunState.building_tier("sanctum"))
	bonus += Modifiers.value(Modifiers.HERO_SPEED)
	bonus += _veil_speed_bonus
	return Balance.HERO_MOVE_SPEED * (1.0 + bonus)


## Damage multiplier the attack chain applies to every swing.
func damage_multiplier() -> float:
	return Modifiers.multiplier(Modifiers.HERO_DAMAGE)


## Max HP after the Sanctum, relics and boss ascensions.
func _apply_permanent_bonuses() -> void:
	var sanctum: BuildingData = ContentDB.building("sanctum")
	var bonus: float = 0.0
	if sanctum != null:
		bonus += sanctum.effect_at(RunState.building_tier("sanctum"))
	var ascension: float = float(RunState.hero_ascension) * Balance.ASCENSION_STAT_BONUS
	health.max_hp = (Balance.HERO_MAX_HP + Modifiers.value(Modifiers.HERO_MAX_HP)) * (1.0 + bonus + ascension)
	if RunState.hero_hp >= 0.0:
		health.current_hp = clampf(RunState.hero_hp, 1.0, health.max_hp)
	else:
		health.current_hp = health.max_hp
	health.changed.emit(health.current_hp, health.max_hp)


func _on_blink(to: Vector2) -> void:
	global_position = to.limit_length(bounds_radius if bounds_radius > 0.0 else Balance.ARENA_RADIUS)
	health.add_invulnerability(Balance.BLINK_IFRAMES)


func _on_veil(duration: float, speed_bonus: float) -> void:
	health.add_invulnerability(duration)
	_veil_speed_bonus = speed_bonus
	_veil_left = duration


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
	if _veil_left > 0.0:
		_veil_left = maxf(_veil_left - delta, 0.0)
		if _veil_left <= 0.0:
			_veil_speed_bonus = 0.0
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
	animator.dash(_dash_direction, Balance.HERO_DASH_DURATION)
	_spawn_dash_ghosts()
	EventBus.hero_dashed.emit(Balance.HERO_DASH_IFRAMES)


## Sized so the lunge covers `distance` while decaying linearly to zero over
## HERO_ATTACK_LUNGE_TIME. Tuning the distance is enough; the speed follows.
func _on_attack_landed(chain_step: int, _targets: int, _at: Vector2) -> void:
	# A connecting swing squashes harder than a whiffed one.
	animator.squash(Balance.ANIM_PUNCH_SQUASH * (1.6 if chain_step == 2 else 1.0))


func _on_lunge_requested(direction: Vector2, distance: float) -> void:
	var duration: float = Balance.HERO_ATTACK_LUNGE_TIME
	if duration <= 0.0 or distance <= 0.0:
		return
	var speed: float = 2.0 * distance / duration
	_lunge_velocity = direction * speed
	_lunge_decay = speed / duration
	animator.punch(direction, clampf(distance / 110.0, 0.6, 1.5))


func _on_damaged(amount: float, from: Vector2) -> void:
	_flash_left = Balance.HIT_FLASH_TIME
	animator.recoil(from, global_position, 1.0)
	EventBus.hero_damaged.emit(amount, from)
	EventBus.camera_shake_requested.emit(4.0, 0.18)


func _on_health_changed(current: float, maximum: float) -> void:
	RunState.hero_hp = current
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
	_apply_permanent_bonuses()
	health.add_invulnerability(Balance.HERO_RESPAWN_INVULN)
	sprite.visible = true
	sprite.modulate = Color.WHITE
	health_bar.visible = true
	EventBus.hero_respawned.emit(global_position)


## Fading copies of the sprite left along the dash path. Cheap, and the single
## clearest way to make a 0.16s movement read as fast rather than as a teleport.
func _spawn_dash_ghosts() -> void:
	var parent: Node = get_parent()
	if parent == null or sprite.texture == null:
		return
	for i: int in Balance.ANIM_DASH_GHOSTS:
		var ghost := Sprite2D.new()
		ghost.texture = sprite.texture
		ghost.flip_h = sprite.flip_h
		ghost.global_position = global_position + _dash_direction * (float(i) * 22.0)
		ghost.z_index = -1
		ghost.modulate = Color(0.65, 0.85, 1.0, 0.42 - 0.08 * float(i))
		parent.add_child(ghost)

		var life: float = Balance.ANIM_DASH_GHOST_LIFE
		var tween: Tween = ghost.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ghost, "modulate:a", 0.0, life)
		tween.tween_property(ghost, "scale", Vector2.ONE * 0.86, life)
		tween.chain().tween_callback(ghost.queue_free)


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
