class_name Enemy
extends Node2D

## One enemy walking a lane (GDD §3). Everything about it comes from an
## EnemyData resource, so adding a breed is adding a `.tres`.
##
## **Enemies do not damage by touching.** They walk until something is in reach,
## stop, wind up on a visible tell, and strike. Contact damage was how the first
## prototype worked and it made attacking feel like self-harm: you had to be
## inside the thing that was hurting you in order to hit it. The wind-up is what
## gives the dash something to dodge and the melee chain a window to live in.

const GROUP: StringName = &"enemies"

enum State {
	WALKING,
	WINDUP,
	STRIKE,
	RECOVER,
	DYING,
}

@export var health: Health
@export var sprite: Sprite2D
@export var health_bar: HealthBar
@export var animator: SpriteAnimator

## Set by the spawner before the node enters the tree.
var data: EnemyData = null
var lane: int = 0

var _field: EnemyField = null
var _state: State = State.WALKING
var _state_left: float = 0.0
var _target: Node2D = null

var _knockback: Vector2 = Vector2.ZERO
var _hitstun_left: float = 0.0
var _flash_left: float = 0.0
var _death_left: float = 0.0

## Lateral offset from the lane centre line, so a wave reads as a column.
var _lane_offset: float = 0.0

## Multipliers captured at spawn: war horn escalation and per-wave scaling.
var _escalation: float = 1.0

# --- Status effects ---
var _slow_factor: float = 1.0
var _slow_left: float = 0.0
var _freeze_left: float = 0.0
var _burn_dps: float = 0.0
var _burn_left: float = 0.0


func setup(enemy_data: EnemyData, lane_index: int, field: EnemyField, stat_scale: float) -> void:
	data = enemy_data
	lane = lane_index
	_field = field
	_escalation = stat_scale


func _ready() -> void:
	add_to_group(GROUP)
	if data == null or _field == null:
		push_error("Enemy spawned without data or battlefield; setup() must run first.")
		queue_free()
		return

	health.max_hp = data.max_hp * _escalation
	health.revive()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health_bar.bind(health)

	animator.mass = _mass_for_category()
	animator.capture_home()

	var path: String = data.get_sprite_path()
	if ResourceLoader.exists(path):
		sprite.texture = load(path)

	_lane_offset = randf_range(-Balance.LANE_WIDTH, Balance.LANE_WIDTH) * 0.5
	EventBus.enemy_spawned.emit(data.id, global_position)


func _process(delta: float) -> void:
	if _state == State.DYING:
		_tick_death(delta)
		return

	_tick_status(delta)
	_hitstun_left = maxf(_hitstun_left - delta, 0.0)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_knockback = _knockback.move_toward(Vector2.ZERO, Balance.ENEMY_KNOCKBACK_DECAY * delta)

	if _freeze_left <= 0.0 and _hitstun_left <= 0.0:
		_tick_state(delta)

	global_position += _knockback * delta
	_update_sprite()


# --- State machine ----------------------------------------------------------

func _tick_state(delta: float) -> void:
	match _state:
		State.WALKING:
			_target = _pick_target()
			if _target != null and _in_reach(_target):
				_enter(State.WINDUP, Balance.ENEMY_ATTACK_WINDUP)
				# Coil before the blow: the tell the player reads.
				animator.squash(Balance.ANIM_HURT_SQUASH * 0.8)
			else:
				_walk(delta)
		State.WINDUP:
			_state_left -= delta
			if _state_left <= 0.0:
				_strike()
				_enter(State.STRIKE, Balance.ENEMY_ATTACK_STRIKE)
				var toward: Vector2 = Vector2.RIGHT
				if _target != null and is_instance_valid(_target):
					toward = (_target.global_position - global_position).normalized()
				animator.punch(toward, 1.1)
		State.STRIKE:
			_state_left -= delta
			if _state_left <= 0.0:
				_enter(State.RECOVER, Balance.ENEMY_ATTACK_RECOVERY)
		State.RECOVER:
			_state_left -= delta
			if _state_left <= 0.0:
				_enter(State.WALKING, 0.0)
		_:
			pass


func _enter(state: State, duration: float) -> void:
	_state = state
	_state_left = duration


## Walks toward the current objective, tracking the lane's centre line with a
## fixed lateral offset so a wave arrives as a column, not a single file.
func _walk(delta: float) -> void:
	var destination: Vector2 = _target.global_position if _target != null else _field.town_position()
	var to: Vector2 = destination - global_position
	if to.length() <= 1.0:
		return
	var direction: Vector2 = to.normalized()
	# Only enemies still heading for the town hold the lane line; one that has
	# broken off to fight the hero moves straight at them.
	if _target == null or _target == _field.town_node():
		var lane_dir: Vector2 = _field.lane_direction(lane)
		var desired: Vector2 = _field.town_position() + lane_dir.orthogonal() * _lane_offset
		direction = (desired - global_position).normalized() if global_position.distance_to(desired) > 4.0 else direction
	global_position += direction * current_speed() * delta


func current_speed() -> float:
	var speed: float = data.move_speed * _slow_factor
	if RunState.horn_active:
		speed *= Balance.HORN_ENEMY_SPEED_SCALE
	return speed


## Taunting towers pull first, then the hero if they have come close enough to
## be worth stopping for, then the town.
func _pick_target() -> Node2D:
	var taunt: Node2D = _field.taunting_tower_in_lane(lane)
	if taunt != null and is_instance_valid(taunt):
		return taunt
	var hero: Node2D = _field.hero_node()
	var town: Node2D = _field.town_node()
	if hero != null and is_instance_valid(hero) and _field.hero_is_alive():
		# With no town to march on — the raid arena — the hero is the only
		# objective there is, at any distance.
		if town == null or global_position.distance_to(hero.global_position) <= Balance.ENEMY_HERO_AGGRO_RANGE:
			return hero
	return town


func _in_reach(target: Node2D) -> bool:
	var reach: float = Balance.ENEMY_ATTACK_RANGE + contact_radius() + _field.target_radius(target)
	return global_position.distance_to(target.global_position) <= reach


func _strike() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	# Re-checked at the moment of the blow, slightly generously: stepping out
	# during the wind-up is supposed to work, but not by a single pixel.
	var reach: float = (Balance.ENEMY_ATTACK_RANGE + contact_radius() + _field.target_radius(_target)) * 1.15
	if global_position.distance_to(_target.global_position) > reach:
		return
	var target_health: Health = Health.of(_target)
	if target_health == null:
		return
	var damage: float = data.contact_damage * _escalation
	if RunState.enemies_are_weakened():
		damage *= Balance.WEAKENED_STAT_SCALE
	if _target == _field.town_node():
		damage *= Balance.TOWN_DAMAGE_SCALE
	target_health.take_damage(damage, global_position)


# --- Damage and status ------------------------------------------------------

func contact_radius() -> float:
	return data.body_radius if data != null else Balance.ENEMY_BODY_RADIUS


func is_dying() -> bool:
	return _state == State.DYING


## True while the wind-up tell is showing — the window the player is meant to
## react to.
func is_telegraphing() -> bool:
	return _state == State.WINDUP


func take_damage(amount: float, from: Vector2, knockback: float) -> bool:
	if _state == State.DYING or data == null:
		return false
	var incoming: float = amount
	if RunState.enemies_are_weakened():
		incoming /= Balance.WEAKENED_STAT_SCALE
	if not health.take_damage(incoming, from):
		return false
	_hitstun_left = Balance.ENEMY_HITSTUN
	# The number is the clearest signal that a hit registered at all, which
	# matters most when a swing catches six things at once.
	Vfx.number(global_position, incoming, Color("ffe3b0"), incoming >= data.max_hp * 0.4)
	Vfx.spark(global_position, Color("ffcf9a"), 4, (global_position - from).normalized(), 170.0)
	animator.recoil(from, global_position, clampf(amount / maxf(data.max_hp, 1.0) * 3.0, 0.5, 1.8))
	var away: Vector2 = global_position - from
	away = away.normalized() if away.length() > 0.001 else Vector2.RIGHT
	_knockback = away * knockback * (1.0 - data.knockback_resistance)
	# Being hit hard enough interrupts a wind-up. This is what makes attacking
	# into a telegraph a real answer rather than a trade.
	if knockback > 0.0 and _state == State.WINDUP:
		_enter(State.RECOVER, Balance.ENEMY_ATTACK_RECOVERY * 0.5)
	return true


## Chain Hook drags things in. Expressed as its own operation rather than as
## negative knockback, so knockback resistance does not accidentally make an
## enemy immune to being pulled.
func pull_toward(point: Vector2, strength: float) -> void:
	if _state == State.DYING:
		return
	var toward: Vector2 = point - global_position
	if toward.length() < 1.0:
		return
	_knockback = toward.normalized() * strength
	_hitstun_left = maxf(_hitstun_left, Balance.ENEMY_HITSTUN)


func apply_slow(factor: float, duration: float) -> void:
	if factor >= 1.0 or duration <= 0.0:
		return
	_slow_factor = minf(_slow_factor, factor)
	_slow_left = maxf(_slow_left, duration)


func apply_freeze(duration: float) -> void:
	_freeze_left = maxf(_freeze_left, duration)


func apply_burn(dps: float, duration: float) -> void:
	if dps <= 0.0 or duration <= 0.0:
		return
	_burn_dps = maxf(_burn_dps, dps)
	_burn_left = maxf(_burn_left, duration)


func _tick_status(delta: float) -> void:
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow_factor = 1.0
	if _freeze_left > 0.0:
		_freeze_left -= delta
	if _burn_left > 0.0:
		_burn_left -= delta
		health.take_damage(_burn_dps * delta, global_position)
	if data.hp_regen > 0.0:
		health.heal(data.hp_regen * delta)


func _on_damaged(_amount: float, _from: Vector2) -> void:
	_flash_left = Balance.HIT_FLASH_TIME


func _on_died(_from: Vector2) -> void:
	_enter(State.DYING, 0.0)
	_death_left = Balance.ENEMY_DEATH_FADE
	remove_from_group(GROUP)
	health_bar.visible = false
	RunState.enemies_killed += 1
	RunState.gain_resources(data.resource_value)
	EventBus.enemy_died.emit(data.id, global_position)


func _tick_death(delta: float) -> void:
	_death_left -= delta
	if _death_left <= 0.0:
		queue_free()
		return
	var t: float = _death_left / Balance.ENEMY_DEATH_FADE
	sprite.modulate = Color(1.0, 1.0, 1.0, t)


## Mass drives how heavily this thing moves. Derived rather than authored, so
## the enemy `.tres` files did not all need a new field.
func _mass_for_category() -> float:
	match data.category:
		EnemyData.Category.ELITE:
			return Balance.ANIM_MASS_ELITE
		EnemyData.Category.BOSS:
			return Balance.ANIM_MASS_BOSS
		_:
			return Balance.ANIM_MASS_BREED


func _update_sprite() -> void:
	if _target != null and is_instance_valid(_target):
		sprite.flip_h = _target.global_position.x < global_position.x

	var tint: Color = Color.WHITE
	if _freeze_left > 0.0:
		tint = Color(0.55, 0.80, 1.0)
	elif _slow_left > 0.0:
		tint = Color(0.75, 0.88, 1.0)
	if _burn_left > 0.0:
		tint = tint.lerp(Color(1.0, 0.55, 0.25), 0.5)
	# The wind-up tell overrides every other tint, because it is the one the
	# player has to read.
	if _state == State.WINDUP:
		var pulse: float = 0.5 + 0.5 * sin(_state_left * 34.0)
		tint = Color(1.0, 0.45, 0.35).lerp(Color(1.0, 0.95, 0.7), pulse)
	if _flash_left > 0.0:
		tint = Balance.HIT_FLASH_COLOUR.lerp(tint, 1.0 - _flash_left / Balance.HIT_FLASH_TIME)
	sprite.modulate = tint


