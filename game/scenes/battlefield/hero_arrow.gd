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
	if is_queued_for_deletion():
		return
	var start: Vector2 = global_position
	var distance: float = minf(maxf(speed * delta, 0.0), maxf(travel - _flown, 0.0))
	var middle: Vector2 = start + _heading * distance * 0.5
	var radius: float = Balance.HERO_ARROW_HIT_RADIUS
	var candidates: Array[Dictionary] = []
	if is_instance_valid(_wildlife):
		candidates.append_array(_wildlife.projectile_bodies(middle, distance * 0.5 + radius))
	if is_instance_valid(_field):
		for enemy: Enemy in _field.enemies_near(middle, distance * 0.5 + radius):
			if not enemy.is_dying():
				candidates.append({"body": enemy, "at": enemy.combat_origin()})
	var impacts: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		var body := candidate["body"] as Node2D
		if not is_instance_valid(body) or _hit.has(body.get_instance_id()):
			continue
		var along: float = contact_distance(start, _heading, distance, candidate["at"], radius)
		if along >= 0.0:
			impacts.append({"body": body, "distance": along})
	# One ordered sweep for both populations: a wolf in front of an enemy must
	# stop the same arrow, regardless of which system supplied its candidate.
	impacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"]))
	for impact: Dictionary in impacts:
		var body := impact["body"] as Node2D
		if not is_instance_valid(body):
			continue
		global_position = start + _heading * float(impact["distance"])
		if body is Enemy:
			if (body as Enemy).is_dying():
				continue
			_strike(body as Enemy)
		else:
			var accepted: bool = _wildlife.wound_sprite(body, damage)
			if not accepted and not Coop.is_guest():
				continue
			Vfx.spark(global_position, _tint, 5, -_heading, 220.0)
		_hit[body.get_instance_id()] = true
		if _hit.size() >= pierce:
			_flown += float(impact["distance"])
			_land()
			return
	global_position = start + _heading * distance
	_flown += distance
	_trail.add_point(global_position)
	while _trail.get_point_count() > TRAIL_POINTS:
		_trail.remove_point(0)
	if _flown >= travel:
		_land()


## Entry into a body's hit circle along a finite flight segment, or -1. This
## cannot skip a target on a slow frame or extend flight beyond weapon range.
static func contact_distance(start: Vector2, heading: Vector2, distance: float,
		body: Vector2, radius: float) -> float:
	var relative: Vector2 = body - start
	var along: float = relative.dot(heading)
	var perpendicular_squared: float = maxf(relative.length_squared() - along * along, 0.0)
	if perpendicular_squared > radius * radius:
		return -1.0
	var half_chord: float = sqrt(maxf(radius * radius - perpendicular_squared, 0.0))
	if along + half_chord < 0.0:
		return -1.0
	var entry: float = maxf(along - half_chord, 0.0)
	return entry if entry <= distance else -1.0


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
