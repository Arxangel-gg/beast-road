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

## A ribbon of recent positions. A moving dot reads as a dot; a dot with a tail
## behind it reads as speed, and costs one node and a ring buffer.
var _trail: Line2D
var _core: Polygon2D
var _glow: Polygon2D
var _light: PointLight2D
var _history: PackedVector2Array = []
var _spin: float = 0.0


func setup(target: Enemy, tower_data: TowerData, hit_damage: float, hit_knockback: float) -> void:
	_target = target
	data = tower_data
	damage = hit_damage
	knockback = hit_knockback
	colour = TowerData.element_colour(tower_data.element)
	speed = Balance.TOWER_PROJECTILE_SPEED


func _ready() -> void:
	z_index = Balance.VFX_Z - 1

	# The trail lives in world space, so it stays put as the head moves rather
	# than rotating with the projectile.
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = Balance.PROJECTILE_WIDTH
	_trail.default_color = Color(colour, 0.75)
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	# Tapers to nothing at the tail; a constant-width trail looks like a pipe.
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.05))
	taper.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = taper
	# Fades along its length as well as tapering, so the tail dissolves.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(colour, 0.0), Color(colour, 0.85)])
	_trail.gradient = ramp
	add_child(_trail)

	# Each element gets its own head shape, so a lane full of shots is readable
	# at a glance without reading the colours.
	_glow = Polygon2D.new()
	_glow.polygon = _head_shape(Balance.PROJECTILE_GLOW_SCALE)
	_glow.color = Color(colour, 0.30)
	add_child(_glow)

	_core = Polygon2D.new()
	_core.polygon = _head_shape(1.0)
	# A hot centre: the element colour lifted toward white reads as energy
	# rather than as a coloured shape.
	_core.color = colour.lerp(Color.WHITE, 0.55)
	add_child(_core)

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

	# Earth shots tumble; everything else holds its heading.
	if data != null and data.element == TowerData.Element.EARTH:
		_spin += delta * Balance.PROJECTILE_SPIN_RATE
		_core.rotation = _spin
		_glow.rotation = _spin

	_push_trail()

	if _target != null:
		var reach: float = _target.contact_radius() + Balance.PROJECTILE_HIT_RADIUS
		if global_position.distance_to(_target.global_position) <= reach:
			_impact()


## Element-specific head silhouettes. Fire is a teardrop, water a shard, earth a
## chunk, air a thin dart.
func _head_shape(scale: float) -> PackedVector2Array:
	var w: float = Balance.PROJECTILE_WIDTH * scale
	var element: int = data.element if data != null else 0
	match element:
		TowerData.Element.WATER:
			return PackedVector2Array([
				Vector2(w * 2.6, 0.0), Vector2(0.0, -w * 0.9),
				Vector2(-w * 1.6, 0.0), Vector2(0.0, w * 0.9)])
		TowerData.Element.EARTH:
			return PackedVector2Array([
				Vector2(w * 1.5, -w * 0.6), Vector2(w * 1.1, w * 1.2),
				Vector2(-w * 1.2, w * 1.0), Vector2(-w * 1.4, -w * 0.9),
				Vector2(0.0, -w * 1.4)])
		TowerData.Element.AIR:
			return PackedVector2Array([
				Vector2(w * 3.4, 0.0), Vector2(-w * 1.0, -w * 0.5),
				Vector2(-w * 0.4, 0.0), Vector2(-w * 1.0, w * 0.5)])
		_:
			return PackedVector2Array([
				Vector2(w * 2.2, 0.0), Vector2(w * 0.2, -w * 1.0),
				Vector2(-w * 1.8, 0.0), Vector2(w * 0.2, w * 1.0)])


## Keeps the last N world positions and feeds them to the trail.
func _push_trail() -> void:
	_history.append(global_position)
	while _history.size() > Balance.PROJECTILE_TRAIL_POINTS:
		_history.remove_at(0)
	_trail.points = _history


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

	# A bright flash, a burst away from the impact, and a ring for anything with
	# area. Three cues rather than one, because a single spark at this size is
	# easy to miss in a crowded lane.
	Vfx.spark(global_position, colour.lerp(Color.WHITE, 0.4),
		Balance.PROJECTILE_IMPACT_SPARKS, -_direction, 260.0)
	Vfx.ring(global_position, Balance.PROJECTILE_IMPACT_RING,
		Color(colour, 0.7), 0.22, 3.0)
	Vfx.flash_at(global_position, colour, Balance.PROJECTILE_IMPACT_FLASH)
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
