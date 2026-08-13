class_name GroundZone
extends Node2D

## A patch of burning ground left by a Magma tower (GDD §4.1).
##
## Created in code because it is a gameplay volume rather than an asset. The
## fading ring is an intentional, exact-radius telegraph for its damage area.

var _dps: float = 0.0
var _left: float = 0.0
var _duration: float = 1.0
var _radius: float = 90.0
var _field: EnemyField = null
var _ring: Line2D = null


func configure(dps: float, duration: float, radius: float, field: EnemyField) -> void:
	_dps = dps
	_duration = maxf(duration, 0.01)
	_left = _duration
	_radius = radius
	_field = field


func _ready() -> void:
	_ring = Line2D.new()
	var points: PackedVector2Array = []
	for i: int in 33:
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / 32.0) * _radius)
	_ring.points = points
	_ring.closed = true
	_ring.width = 5.0
	_ring.default_color = Color(0.85, 0.35, 0.15, 0.55)
	add_child(_ring)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 or _field == null:
		queue_free()
		return
	_ring.modulate.a = clampf(_left / _duration, 0.0, 1.0)
	for enemy: Enemy in _field.enemies_near(global_position, _radius):
		enemy.take_damage(_dps * delta, global_position, 0.0)
