class_name HeroArrow
extends Node2D

## What the hero's bow puts in the air (owner decision, 2026-08-31).
##
## Its own script rather than `Projectile`, which is built around `TowerData` and
## a tower's tier. Forcing a bow through that would have meant inventing a fake
## tower for every arrow; the two shots share the world, not their reasons.
##
## Drawn rather than textured, like the rest of the hero's effects: a shaft, a
## head, and a short trail tinted by whatever the ammunition is. Elemental
## ammunition reads by colour at a glance, which is the whole point of having it.

const TRAIL_POINTS: int = 7

var damage: float = 0.0
var knockback: float = 0.0
var speed: float = 900.0
var pierce: int = 1
var travel: float = 700.0
var ammo: AmmoData = null

var _heading: Vector2 = Vector2.RIGHT
var _flown: float = 0.0
var _hit: Dictionary = {}

## The animals in this scope, or null where there are none (a raid camp).
## Resolved once at launch rather than searched every frame.
var _wildlife: Wildlife = null
var _tint: Color = Color("e8d9b0")
var _trail: Line2D = null
var _field: EnemyField = null


func launch(field: EnemyField, from: Vector2, heading: Vector2,
		weapon: RangedWeaponData, kind: AmmoData) -> void:
	_field = field
	# The animals live beside the enemies in the same scope, under a known name.
	# Null in a raid camp, which has no wildlife, and that is a supported state
	# rather than a missing reference.
	if field != null:
		_wildlife = field.get_node_or_null("Wildlife") as Wildlife
	ammo = kind
	_heading = heading.normalized() if heading.length() > 0.001 else Vector2.RIGHT
	damage = weapon.damage * kind.damage_scale
	knockback = weapon.knockback
	speed = weapon.projectile_speed
	pierce = weapon.pierce
	travel = weapon.effective_range
	global_position = from
	rotation = _heading.angle()
	# Elemental shots borrow the tower palette, so a Rime Arrow and a Rime Lance
	# read as the same idea rather than as two unrelated blue things.
	_tint = TowerData.element_colour(kind.element) if kind.element >= 0 \
		else Color("e8d9b0")


func _ready() -> void:
	z_index = Balance.VFX_Z
	_trail = Line2D.new()
	_trail.width = 3.0
	_trail.default_color = Color(_tint, 0.5)
	_trail.top_level = true
	add_child(_trail)
	LightKit.add_light(self, _tint, 90.0, 0.5)


func _process(delta: float) -> void:
	var step: Vector2 = _heading * speed * delta
	global_position += step
	_flown += step.length()

	_trail.add_point(global_position)
	while _trail.get_point_count() > TRAIL_POINTS:
		_trail.remove_point(0)

	# Animals are not enemies and live in their own system, so a shot has to ask
	# them separately - a wolf in the open used to let arrows pass straight
	# through while a sword killed it. Resolved once per frame like the enemy
	# sweep above, and it counts against pierce for the same reason: a bolt that
	# passes through three bodies has passed through three bodies.
	if _wildlife != null and is_instance_valid(_wildlife):
		if _wildlife.wound_near(global_position, Balance.HERO_ARROW_HIT_RADIUS, damage):
			Vfx.spark(global_position, _tint, 5, -_heading, 220.0)
			_hit[_wildlife.get_instance_id() + _hit.size()] = true
			if _hit.size() >= pierce:
				_land()
				return

	if _field != null:
		for enemy: Enemy in _field.enemies_near(global_position, Balance.HERO_ARROW_HIT_RADIUS):
			var id: int = enemy.get_instance_id()
			if enemy.is_dying() or _hit.has(id):
				continue
			_hit[id] = true
			_strike(enemy)
			if _hit.size() >= pierce:
				_land()
				return

	if _flown >= travel:
		_land()


func _strike(enemy: Enemy) -> void:
	enemy.take_damage(damage, global_position, knockback, false)
	if ammo == null:
		return
	# Status comes from the ammunition, applied through the same calls a tower
	# uses. A new effect is a field on the `.tres`, never a branch here.
	if ammo.burn_duration > 0.0:
		enemy.apply_burn(ammo.burn_damage, ammo.burn_duration)
	if ammo.slow_duration > 0.0:
		enemy.apply_slow(ammo.slow_factor, ammo.slow_duration)
	Vfx.spark(global_position, _tint, 5, -_heading, 220.0)


func _land() -> void:
	if ammo != null and ammo.blast_radius > 0.0 and _field != null:
		for enemy: Enemy in _field.enemies_near(global_position, ammo.blast_radius):
			if not enemy.is_dying():
				enemy.take_damage(damage * 0.7, global_position, knockback * 0.5, false)
		Vfx.ring(global_position, ammo.blast_radius, Color(_tint, 0.6), 0.28, 5.0)
	Vfx.flash_at(global_position, _tint, 26.0)
	# The trail is `top_level`, so it does not follow this node out of the world
	# and has to be released with it.
	if _trail != null:
		_trail.queue_free()
	queue_free()
