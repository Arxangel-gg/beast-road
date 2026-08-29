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
var _filament: Line2D = null
var _history: PackedVector2Array = []
var _mote_left: float = 0.0


func configure(target: Node2D, damage: float, origin: Vector2) -> void:
	_target = target
	_damage = damage
	global_position = origin
	_destination = _combat_origin(target) if target != null and is_instance_valid(target) else origin
	_direction = (_destination - origin).normalized()
	rotation = _direction.angle()


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
	rotation = _direction.angle()


func _ready() -> void:
	z_index = Balance.VFX_Z - 1
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = Balance.ENEMY_PROJECTILE_WIDTH
	_trail.default_color = Color(Balance.ENEMY_PROJECTILE_SHELL_COLOUR, 0.90)
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.width_curve = _trail_taper()
	add_child(_trail)

	_filament = Line2D.new()
	_filament.top_level = true
	_filament.width = Balance.ENEMY_PROJECTILE_FILAMENT_WIDTH
	_filament.default_color = Color(Balance.ENEMY_PROJECTILE_CORE_COLOUR, 0.88)
	_filament.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_filament.end_cap_mode = Line2D.LINE_CAP_ROUND
	_filament.width_curve = _trail_taper()
	add_child(_filament)

	var glow := Sprite2D.new()
	glow.texture = LightKit.falloff_texture()
	glow.modulate = Color(Balance.ENEMY_PROJECTILE_COLOUR, 0.72)
	glow.scale = Vector2.ONE * Balance.ENEMY_PROJECTILE_GLOW_SCALE
	add_child(glow)
	LightKit.add_light(self, Balance.ENEMY_PROJECTILE_COLOUR,
		Balance.ENEMY_PROJECTILE_LIGHT_RADIUS, Balance.ENEMY_PROJECTILE_LIGHT_ENERGY)
	_mote_left = Balance.ENEMY_PROJECTILE_MOTE_INTERVAL
	queue_redraw()


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
	_filament.points = _history
	_mote_left -= delta
	if _mote_left <= 0.0:
		_mote_left += Balance.ENEMY_PROJECTILE_MOTE_INTERVAL
		Vfx.spark(global_position - _direction * Balance.ENEMY_PROJECTILE_HEAD_RADIUS,
			Balance.ENEMY_PROJECTILE_CORE_COLOUR, 1, -_direction,
			Balance.ENEMY_PROJECTILE_MOTE_SPEED)
	queue_redraw()
	var distance_after: float = global_position.distance_to(_destination)
	if distance_after <= Balance.ENEMY_PROJECTILE_HIT_RADIUS \
			or distance_after > distance_before:
		_impact()


func _impact() -> void:
	if _target != null and is_instance_valid(_target) \
			and global_position.distance_to(_combat_origin(_target)) <= Balance.ENEMY_PROJECTILE_BLAST_RADIUS:
		var target_health: Health = Health.of(_target)
		if target_health != null:
			target_health.take_damage(_damage, global_position)
	Vfx.spark(global_position, Balance.ENEMY_PROJECTILE_CORE_COLOUR,
		Balance.ENEMY_PROJECTILE_IMPACT_SPARKS,
		-_direction, 180.0)
	Vfx.ring(global_position, Balance.ENEMY_PROJECTILE_BLAST_RADIUS * 0.58,
		Color(Balance.ENEMY_PROJECTILE_CORE_COLOUR, 0.82), 0.20, 2.5)
	Vfx.ring(global_position, Balance.ENEMY_PROJECTILE_BLAST_RADIUS,
		Color(Balance.ENEMY_PROJECTILE_COLOUR, 0.66), 0.34, 5.0)
	Vfx.flash_at(global_position, Color(Balance.ENEMY_PROJECTILE_CORE_COLOUR, 0.72),
		Balance.ENEMY_PROJECTILE_HEAD_RADIUS * 2.2)
	queue_free()


func _draw() -> void:
	var pulse: float = sin(_life * Balance.ENEMY_PROJECTILE_PULSE_SPEED) * 0.5 + 0.5
	var head: float = Balance.ENEMY_PROJECTILE_HEAD_RADIUS
	draw_circle(Vector2.ZERO, head * (1.55 + pulse * 0.16),
		Color(Balance.ENEMY_PROJECTILE_COLOUR, 0.12 + pulse * 0.08))
	var shell := PackedVector2Array([
		Vector2(head * 1.35, 0.0), Vector2(0.0, -head),
		Vector2(-head * 1.05, 0.0), Vector2(0.0, head)])
	draw_colored_polygon(shell, Balance.ENEMY_PROJECTILE_SHELL_COLOUR)
	var edge := PackedVector2Array([shell[0], shell[1], shell[2], shell[3], shell[0]])
	draw_polyline(edge, Color(Balance.ENEMY_PROJECTILE_COLOUR, 0.92), 1.8, true)
	draw_circle(Vector2(head * 0.12, 0.0), head * (0.42 + pulse * 0.08),
		Balance.ENEMY_PROJECTILE_CORE_COLOUR)
	var spin: float = _life * Balance.ENEMY_PROJECTILE_PULSE_SPEED * 0.55
	draw_arc(Vector2.ZERO, Balance.ENEMY_PROJECTILE_RUNE_RADIUS, spin,
		spin + PI * 0.72, 12, Color(Balance.ENEMY_PROJECTILE_CORE_COLOUR, 0.78),
		Balance.ENEMY_PROJECTILE_RUNE_WIDTH, true)
	draw_arc(Vector2.ZERO, Balance.ENEMY_PROJECTILE_RUNE_RADIUS, spin + PI,
		spin + PI * 1.72, 12, Color(Balance.ENEMY_PROJECTILE_COLOUR, 0.68),
		Balance.ENEMY_PROJECTILE_RUNE_WIDTH, true)


static func _trail_taper() -> Curve:
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.05))
	taper.add_point(Vector2(0.70, 0.58))
	taper.add_point(Vector2(1.0, 1.0))
	return taper


static func _combat_origin(node: Node2D) -> Vector2:
	if node.has_method("combat_origin"):
		var origin: Variant = node.call("combat_origin")
		if origin is Vector2:
			return origin as Vector2
	return node.global_position
