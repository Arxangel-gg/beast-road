class_name Enemy
extends Node2D

## One enemy. Everything about it comes from an EnemyData resource, so adding a
## breed is adding a `.tres` and never editing this file (CLAUDE.md §3).
##
## Deliberately not a physics body. Enemies do not block the hero — in a game
## whose whole point is reaching the lane that is collapsing, being body-blocked
## by the horde is the single most frustrating thing that could happen. They
## overlap freely, push each other apart cosmetically, and threaten by dealing
## contact damage instead.
##
## `_target` is whatever this enemy walks at. In Stage 1 that is the hero; from
## Stage 2 it is the city. Nothing here needs to know the difference.

const GROUP: StringName = &"enemies"

@export var health: Health
@export var sprite: Sprite2D
@export var health_bar: HealthBar

var data: EnemyData = null

var _target: Node2D = null
var _target_radius: float = 0.0
var _target_health: Health = null

var _knockback: Vector2 = Vector2.ZERO
var _hitstun_left: float = 0.0
var _contact_left: float = 0.0
var _flash_left: float = 0.0

var _dying: bool = false
var _death_left: float = 0.0

## War horn escalation is captured at spawn, so blowing the horn does not
## retroactively buff enemies already on the field.
var _escalation: float = 1.0


## Must be called before the enemy enters the tree does anything useful.
func setup(enemy_data: EnemyData, target: Node2D, target_radius: float) -> void:
	data = enemy_data
	_target = target
	_target_radius = target_radius
	_target_health = Health.of(target)


func _ready() -> void:
	add_to_group(GROUP)
	if data == null:
		push_error("Enemy spawned without EnemyData; setup() must be called first.")
		queue_free()
		return

	_escalation = RunState.enemy_escalation_multiplier()
	health.max_hp = data.max_hp * _escalation
	health.revive()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health_bar.bind(health)

	var sprite_path: String = data.get_sprite_path()
	if ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)
	else:
		push_warning("Enemy '%s' has no sprite at %s" % [data.id, sprite_path])

	EventBus.enemy_spawned.emit(data.id, global_position)


func _process(delta: float) -> void:
	if _dying:
		_tick_death(delta)
		return

	_hitstun_left = maxf(_hitstun_left - delta, 0.0)
	_contact_left = maxf(_contact_left - delta, 0.0)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_knockback = _knockback.move_toward(Vector2.ZERO, Balance.ENEMY_KNOCKBACK_DECAY * delta)

	var step: Vector2 = _walk_velocity() + _separation() + _knockback
	global_position += step * delta

	# Knockback may push an enemy past the spawn ring; it should not be able to
	# fling one into empty space it then has to walk all the way back from.
	global_position = global_position.limit_length(Balance.ARENA_RADIUS * 1.15)

	_try_contact()
	_update_sprite()


func contact_radius() -> float:
	return data.body_radius if data != null else Balance.ENEMY_BODY_RADIUS


func is_dying() -> bool:
	return _dying


## Returns true if the damage landed. `from` sets the knockback direction.
func take_damage(amount: float, from: Vector2, knockback: float) -> bool:
	if _dying or data == null:
		return false
	if not health.take_damage(amount, from):
		return false
	_hitstun_left = Balance.ENEMY_HITSTUN
	var away: Vector2 = global_position - from
	away = away.normalized() if away.length() > 0.001 else Vector2.RIGHT
	_knockback = away * knockback * (1.0 - data.knockback_resistance)
	return true


func _walk_velocity() -> Vector2:
	if _hitstun_left > 0.0 or _target == null or not is_instance_valid(_target):
		return Vector2.ZERO
	var to: Vector2 = _target.global_position - global_position
	if to.length() <= 1.0:
		return Vector2.ZERO
	return to.normalized() * data.move_speed


## Cosmetic crowd separation, so a pack does not collapse into one stacked
## point. O(n^2) over at most SPAWN_MAX_ALIVE enemies, which is cheap at this
## scale; Stage 2's larger waves will want a spatial hash instead.
func _separation() -> Vector2:
	var push: Vector2 = Vector2.ZERO
	var span: float = contact_radius() * 2.0
	if span <= 0.0:
		return push
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Enemy
		if other == null or other == self or other.is_dying():
			continue
		var away: Vector2 = global_position - other.global_position
		var distance: float = away.length()
		if distance < 0.001 or distance >= span:
			continue
		push += (away / distance) * (1.0 - distance / span)
	if push.length() < 0.001:
		return Vector2.ZERO
	return push.normalized() * Balance.ENEMY_SEPARATION_SPEED


func _try_contact() -> void:
	if _contact_left > 0.0 or _target_health == null or _target == null or not is_instance_valid(_target):
		return
	if global_position.distance_to(_target.global_position) > contact_radius() + _target_radius:
		return
	# The cooldown starts whether or not the blow landed, so an enemy that
	# swings into i-frames has genuinely wasted it. Otherwise dashing through a
	# crowd would just defer every hit to the frame the i-frames end.
	_contact_left = data.contact_interval
	_target_health.take_damage(data.contact_damage * _escalation, global_position)


func _on_damaged(_amount: float, _from: Vector2) -> void:
	_flash_left = Balance.HIT_FLASH_TIME


func _on_died(_from: Vector2) -> void:
	_dying = true
	_death_left = Balance.ENEMY_DEATH_FADE
	# Out of the group immediately: a corpse must not be swingable, must not
	# push the living around, and must not be counted as pressure.
	remove_from_group(GROUP)
	health_bar.visible = false
	RunState.enemies_killed += 1
	EventBus.enemy_died.emit(data.id, global_position)


func _tick_death(delta: float) -> void:
	_death_left -= delta
	if _death_left <= 0.0:
		queue_free()
		return
	var t: float = _death_left / Balance.ENEMY_DEATH_FADE
	sprite.modulate = Color(1.0, 1.0, 1.0, t)
	sprite.scale = Vector2.ONE * (0.75 + 0.25 * t)


func _update_sprite() -> void:
	if _target != null and is_instance_valid(_target):
		sprite.flip_h = _target.global_position.x < global_position.x
	if _flash_left > 0.0:
		sprite.modulate = Balance.HIT_FLASH_COLOUR.lerp(Color.WHITE, 1.0 - _flash_left / Balance.HIT_FLASH_TIME)
	else:
		sprite.modulate = Color.WHITE
