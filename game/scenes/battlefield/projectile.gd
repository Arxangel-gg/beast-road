class_name Projectile
extends Node2D

## A tower's shot, in flight.
##
## Replaces an instant tracer line. The difference is not cosmetic: a shot that
## takes time to arrive means a tower can miss a fast enemy, a slow heavy shell
## reads differently from a rapid one, and the player can see which lane is
## actually under fire. It makes the towers legible.
##
## Homing rather than ballistic. A tower that fires at where something *was* is
## technically more honest and practically just frustrating at this scale.

## Set by the tower before it enters the tree.
var damage: float = 0.0
var knockback: float = 0.0
var speed: float = 600.0
var colour: Color = Color.WHITE
var data: TowerData = null

var _target: Enemy = null
var _direction: Vector2 = Vector2.RIGHT
var _life: float = 0.0

var _sprite: Line2D
var _light: PointLight2D


func setup(target: Enemy, tower_data: TowerData, hit_damage: float, hit_knockback: float) -> void:
	_target = target
	data = tower_data
	damage = hit_damage
	knockback = hit_knockback
	colour = TowerData.element_colour(tower_data.element)
	speed = Balance.TOWER_PROJECTILE_SPEED


func _ready() -> void:
	z_index = Balance.VFX_Z - 1

	# A short streak rather than a dot: it reads as travelling even in a still
	# frame, and costs one node.
	_sprite = Line2D.new()
	_sprite.points = PackedVector2Array([Vector2.ZERO, Vector2(-Balance.PROJECTILE_LENGTH, 0.0)])
	_sprite.width = Balance.PROJECTILE_WIDTH
	_sprite.default_color = colour
	add_child(_sprite)

	# Every shot carries its own small light, which is most of why a night
	# battlefield reads at all.
	_light = LightKit.add_light(self, colour, Balance.PROJECTILE_LIGHT_RADIUS,
		Balance.PROJECTILE_LIGHT_ENERGY)

	if _target != null and is_instance_valid(_target):
		_direction = (_target.global_position - global_position).normalized()
	rotation = _direction.angle()


func _process(delta: float) -> void:
	_life += delta
	if _life > Balance.PROJECTILE_MAX_LIFE:
		_expire()
		return

	# Lost the target: keep flying so the shot does not vanish mid-air.
	if _target == null or not is_instance_valid(_target) or _target.is_dying():
		_target = null
	else:
		var wanted: Vector2 = (_target.global_position - global_position).normalized()
		_direction = _direction.lerp(wanted, clampf(Balance.PROJECTILE_TURN_RATE * delta, 0.0, 1.0)).normalized()

	global_position += _direction * speed * delta
	rotation = _direction.angle()

	if _target != null:
		var reach: float = _target.contact_radius() + Balance.PROJECTILE_HIT_RADIUS
		if global_position.distance_to(_target.global_position) <= reach:
			_impact()


func _impact() -> void:
	var field: Battlefield = _find_field()
	if field != null and data.aoe_radius > 0.0:
		for enemy: Enemy in field.enemies_near(global_position, data.aoe_radius):
			_apply(enemy)
		Vfx.ring(global_position, data.aoe_radius, Color(colour, 0.55), 0.3, 4.0)
	elif _target != null and is_instance_valid(_target):
		_apply(_target)

	if data.ground_zone_dps > 0.0 and field != null:
		field.spawn_ground_zone(global_position, data.ground_zone_dps,
			data.ground_zone_duration, maxf(data.aoe_radius, 90.0))

	Vfx.spark(global_position, colour, 5, _direction, 200.0)
	queue_free()


## Reached the end of its life without connecting. Fizzles rather than
## disappearing, so a miss is visible.
func _expire() -> void:
	Vfx.spark(global_position, Color(colour, 0.5), 3, _direction, 90.0)
	queue_free()


func _apply(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
		return
	if damage > 0.0:
		enemy.take_damage(damage, global_position, knockback)
	if data.slow_factor < 1.0:
		enemy.apply_slow(maxf(data.slow_factor - Modifiers.value(Modifiers.SLOW_STRENGTH), 0.1),
			data.slow_duration)
	if data.burn_dps > 0.0:
		enemy.apply_burn(data.burn_dps * Modifiers.multiplier(Modifiers.BURN_DAMAGE),
			data.burn_duration)
	if data.freeze_chance > 0.0 and randf() < data.freeze_chance:
		enemy.apply_freeze(1.2)


func _find_field() -> Battlefield:
	var node: Node = get_parent()
	while node != null:
		var field := node as Battlefield
		if field != null:
			return field
		node = node.get_parent()
	return null
