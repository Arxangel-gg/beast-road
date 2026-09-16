class_name BloodBurst
extends Node2D

## A bitmap-free blood burst whose motes follow short ballistic arcs. Each mote
## tells the shared BloodField exactly where it landed, so the persistent mark
## is the consequence of the visible spray instead of an unrelated stamp at the
## actor's feet.

var _drops: Array[Dictionary] = []
var _ground: BloodField = null
var _rng := RandomNumberGenerator.new()


func configure(body_at: Vector2, ground_at: Vector2, direction: Vector2,
		size: float, ground: BloodField, source_rng: RandomNumberGenerator) -> void:
	_ground = ground
	_rng.seed = source_rng.randi()
	var along: Vector2 = direction.normalized() if direction.length_squared() > 0.001 \
		else Vector2.from_angle(_rng.randf() * TAU)
	var count: int = _rng.randi_range(Balance.VFX_BLOOD_DROPS_MIN,
		Balance.VFX_BLOOD_DROPS_MAX)
	for index: int in count:
		var spread: float = _rng.randf_range(-Balance.VFX_BLOOD_LAND_SPREAD,
			Balance.VFX_BLOOD_LAND_SPREAD)
		var throw: float = size * _rng.randf_range(0.28, 0.92)
		var land: Vector2 = ground_at + along.rotated(spread) * throw \
			+ Vector2.from_angle(_rng.randf() * TAU) * size * _rng.randf_range(0.04, 0.18)
		var life: float = Balance.VFX_BLOOD_LIFE * _rng.randf_range(0.72, 1.18)
		_drops.append({
			"start": Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0)),
			"end": land - body_at,
			"land": land,
			"arc": _rng.randf_range(Balance.VFX_BLOOD_ARC.x, Balance.VFX_BLOOD_ARC.y),
			"age": -float(index) * 0.012,
			"life": life,
			"radius": size * _rng.randf_range(0.055, 0.105),
			"landed": false,
			# Its own outline, rolled once, so a mote in flight keeps its shape
			# for its whole arc rather than being re-lobed every frame.
			"seed": _rng.randf() * 1000.0,
		})
	z_index = Balance.VFX_Z
	queue_redraw()


func _process(delta: float) -> void:
	var all_landed: bool = true
	for drop: Dictionary in _drops:
		if bool(drop["landed"]):
			continue
		all_landed = false
		drop["age"] = float(drop["age"]) + delta
		if float(drop["age"]) < float(drop["life"]):
			continue
		drop["landed"] = true
		if _ground != null and is_instance_valid(_ground):
			_ground.droplet(drop["land"] as Vector2, float(drop["radius"]) * 1.35, _rng)
	queue_redraw()
	if all_landed or _all_landed():
		queue_free()


func _all_landed() -> bool:
	for drop: Dictionary in _drops:
		if not bool(drop["landed"]):
			return false
	return true


## **A mote is a streak, not a circle.**
##
## It used to be a `draw_circle` with a hard `draw_line` behind it - a perfectly
## round bead in one flat colour, which is the same finding the ground pools, the
## swim sheen and the menu campfire each paid for: one colour for the whole shape
## *is* a hard edge, and nothing wet has one.
##
## Every mote is now a soft lobed blob drawn out along **its own velocity**, so
## the streak shortens on its own as the arc flattens and the drop slows - one
## number doing what a bead plus a trail were doing with two. The whole burst is
## one `canvas_item_add_triangle_array`, which is fewer draw calls than the pair
## it replaced rather than more.
func _draw() -> void:
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	for drop: Dictionary in _drops:
		if bool(drop["landed"]) or float(drop["age"]) < 0.0:
			continue
		var life: float = maxf(float(drop["life"]), 0.001)
		var t: float = clampf(float(drop["age"]) / life, 0.0, 1.0)
		var point: Vector2 = _at(drop, t)
		# Where it was a moment ago, so the streak follows the *arc* rather than
		# the straight line between the ends - a mote at the top of its throw is
		# travelling sideways while its start and end are far below it.
		var before: Vector2 = _at(drop, maxf(t - 0.06, 0.0))
		var velocity: Vector2 = (point - before) / maxf(minf(0.06, t) * life, 0.001)
		var radius: float = float(drop["radius"]) * lerpf(1.0, 0.62, t)
		var colour := Color(0.53, 0.055, 0.065, lerpf(0.96, 0.72, t))
		BloodInk.blob(points, colours, indices, point, radius, colour,
			float(drop.get("seed", 0.0)), velocity * Balance.BLOOD_MOTE_STREAK)
	BloodInk.paint(self, points, colours, indices)


## Where a mote is at `t` of its life: along its throw, lifted by its arc.
func _at(drop: Dictionary, t: float) -> Vector2:
	var point: Vector2 = (drop["start"] as Vector2).lerp(drop["end"] as Vector2, t)
	point.y -= sin(t * PI) * float(drop["arc"])
	return point
