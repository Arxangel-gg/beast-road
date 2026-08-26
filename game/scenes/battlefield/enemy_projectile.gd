class_name EnemyProjectile
extends Node2D

## A dodgeable hostile shot. It commits to the target's position at release,
## so moving during the telegraph is the answer; it never homes after the hero.

var _target: Node2D = null
var _destination: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.RIGHT
var _damage: float = 0.0
var _life: float = 0.0
var _trail: Line2D = null
var _history: PackedVector2Array = []


func configure(target: Node2D, damage: float, origin: Vector2) -> void:
	_target = target
	_damage = damage
	global_position = origin
	_destination = target.global_position if target != null and is_instance_valid(target) else origin
	_direction = (_destination - origin).normalized()


## The same shot with nothing to hit, for a guest drawing the host's decision.
##
## A puppet resolves nothing, so this carries no target and no damage - the host
## has already worked out who was hit and reports it as health in the next batch.
## What was missing was the shot itself: a ranged enemy on the guest's screen
## simply hurt people from across the field with nothing in between.
func configure_toward(destination: Vector2, origin: Vector2) -> void:
	_target = null
	_damage = 0.0
	global_position = origin
	_destination = destination
	_direction = (destination - origin).normalized() 		if destination.distance_to(origin) > 1.0 else Vector2.RIGHT


func _ready() -> void:
	z_index = Balance.VFX_Z - 1
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = Balance.ENEMY_PROJECTILE_WIDTH
	_trail.default_color = Color(Balance.ENEMY_PROJECTILE_COLOUR, 0.76)
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trail)

	var glow := Sprite2D.new()
	glow.texture = LightKit.falloff_texture()
	glow.modulate = Color(Balance.ENEMY_PROJECTILE_COLOUR, 0.72)
	glow.scale = Vector2.ONE * Balance.ENEMY_PROJECTILE_GLOW_SCALE
	add_child(glow)
	LightKit.add_light(self, Balance.ENEMY_PROJECTILE_COLOUR,
		Balance.ENEMY_PROJECTILE_LIGHT_RADIUS, Balance.ENEMY_PROJECTILE_LIGHT_ENERGY)


func _process(delta: float) -> void:
	_life += delta
	if _life >= Balance.ENEMY_PROJECTILE_MAX_LIFE:
		queue_free()
		return
	var distance_before: float = global_position.distance_to(_destination)
	global_position += _direction * Balance.ENEMY_PROJECTILE_SPEED * delta
	_history.append(global_position)
	while _history.size() > Balance.ENEMY_PROJECTILE_TRAIL_POINTS:
		_history.remove_at(0)
	_trail.points = _history
	var distance_after: float = global_position.distance_to(_destination)
	if distance_after <= Balance.ENEMY_PROJECTILE_HIT_RADIUS \
			or distance_after > distance_before:
		_impact()


func _impact() -> void:
	if _target != null and is_instance_valid(_target) \
			and global_position.distance_to(_target.global_position) <= Balance.ENEMY_PROJECTILE_BLAST_RADIUS:
		var target_health: Health = Health.of(_target)
		if target_health != null:
			target_health.take_damage(_damage, global_position)
	Vfx.spark(global_position, Balance.ENEMY_PROJECTILE_COLOUR, 8,
		-_direction, 180.0)
	Vfx.ring(global_position, Balance.ENEMY_PROJECTILE_BLAST_RADIUS,
		Color(Balance.ENEMY_PROJECTILE_COLOUR, 0.62), 0.28, 4.0)
	queue_free()
