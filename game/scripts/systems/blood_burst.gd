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
			"radius": size * _rng.randf_range(0.035, 0.075),
			"landed": false,
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


func _draw() -> void:
	for drop: Dictionary in _drops:
		if bool(drop["landed"]) or float(drop["age"]) < 0.0:
			continue
		var t: float = clampf(float(drop["age"]) / maxf(float(drop["life"]), 0.001),
			0.0, 1.0)
		var point: Vector2 = (drop["start"] as Vector2).lerp(drop["end"] as Vector2, t)
		point.y -= sin(t * PI) * float(drop["arc"])
		var radius: float = float(drop["radius"]) * lerpf(1.0, 0.62, t)
		var colour := Color(0.53, 0.055, 0.065, lerpf(0.96, 0.72, t))
		draw_circle(point, radius, colour)
		if t > 0.12:
			var trail: Vector2 = ((drop["end"] as Vector2) \
				- (drop["start"] as Vector2)).normalized()
			draw_line(point - trail * radius * 1.8, point, Color(colour, colour.a * 0.5),
				maxf(radius * 0.7, 1.0), true)
