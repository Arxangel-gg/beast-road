class_name GroundZone
extends Node2D

## A patch of hostile ground left by a tower (GDD §4.1).
##
## The volume is code because it is gameplay, but the *picture* is art now: a
## thin outlined circle told the player the radius and nothing else, and a ring
## drawn at the exact damage edge is the least interesting way to say it.
##
## Painted, and different every time it is cast. One sprite per element rotated
## to a random angle, scaled with a little jitter and tinted a few degrees off
## its own hue gives a pool that never looks stamped, from four files — the same
## trick the ground tiles use, where the variety lives in the placement rather
## than in the number of images.
##
## The ring survives underneath as the exact-radius telegraph. The art is ragged
## on purpose and would otherwise leave the player guessing where the damage
## actually stops, which is the one thing this must not be vague about.

var _dps: float = 0.0
var _left: float = 0.0
var _duration: float = 1.0
var _radius: float = 90.0
var _field: EnemyField = null
var _ring: Line2D = null
var _pool: Sprite2D = null
var _element: int = 0
var _spin: float = 0.0

## Element art, derived from the element name like every other path here.
const POOL_ART_FORMAT: String = "res://art/vfx/pool_%s.png"


func configure(dps: float, duration: float, radius: float, field: EnemyField,
		element: int = 0) -> void:
	_element = element
	_dps = dps
	_duration = maxf(duration, 0.01)
	_left = _duration
	_radius = radius
	_field = field


func _ready() -> void:
	_build_pool()

	_ring = Line2D.new()
	var points: PackedVector2Array = []
	for i: int in 33:
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / 32.0) * _radius)
	_ring.points = points
	_ring.closed = true
	_ring.width = 5.0
	# Dimmer with art underneath it: the ring is now a boundary marker rather
	# than the whole effect.
	_ring.default_color = Color(TowerData.element_colour(_element), 0.34)
	add_child(_ring)


## The painted pool, varied per cast so no two look stamped from the same die.
func _build_pool() -> void:
	var path: String = POOL_ART_FORMAT % TowerData.element_name(_element).to_lower()
	if not ResourceLoader.exists(path):
		return
	var rng := RunState.rng("combat")
	_pool = Sprite2D.new()
	_pool.texture = load(path)
	_pool.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_pool.add_to_group(Graphics.FILTER_GROUP)
	# Any angle, not a quarter turn: this is a stain on the ground, and the eye
	# reads four repeated orientations as a pattern almost immediately.
	_pool.rotation = rng.randf() * TAU
	_spin = rng.randf_range(-1.0, 1.0) * Balance.GROUND_ZONE_DRIFT
	var span: float = _radius * 2.0 * rng.randf_range(0.94, 1.08)
	_pool.scale = Vector2.ONE * (span / float(_pool.texture.get_width()))
	# A few degrees off its own hue, so a lane of them is a family rather than a
	# row of copies.
	_pool.modulate = TowerData.element_colour(_element).lerp(Color.WHITE, 0.55)
	_pool.modulate.h = wrapf(_pool.modulate.h + rng.randf_range(-0.03, 0.03), 0.0, 1.0)
	_pool.modulate.a = 0.0
	add_child(_pool)
	# Blooms in rather than appearing, so a cast reads as landing.
	var grow: Tween = create_tween()
	grow.set_parallel(true)
	grow.tween_property(_pool, "modulate:a", 0.92, 0.18)
	grow.tween_property(_pool, "scale", _pool.scale, 0.18).from(_pool.scale * 0.55)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 or _field == null:
		queue_free()
		return
	var fade: float = clampf(_left / _duration, 0.0, 1.0)
	_ring.modulate.a = fade
	if _pool != null:
		# Turns slowly while it burns, which keeps a long-lived pool alive to the
		# eye without another frame of art.
		_pool.rotation += _spin * delta
		_pool.modulate.a = 0.92 * fade
	for enemy: Enemy in _field.enemies_near(global_position, _radius):
		enemy.take_damage(_dps * delta, global_position, 0.0)
