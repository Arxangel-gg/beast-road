class_name BloodMotes
extends Node2D

## **Every drop of blood in the air, on one canvas** (2026-09-24).
##
## A blow used to stand up a `BloodBurst` node of its own: five to nine motes
## on short ballistic arcs, each rebuilt as a lobed blob in GDScript every
## frame for half a second, and freed when the last one landed. That is the
## right picture and the wrong owner. Traced on Act X with forty level-8
## towers, a heavy stretch lands several hundred blows a second, so five
## hundred of those nodes were alive at once, each drawing seven blobs a
## frame - three and a half thousand blob builds a frame, in script, on top
## of a node born and freed per blow. Every frame of that stretch was 25-36
## ms against a 9 ms road either side of it, and the ledger could not say why
## because a node that lives half a second is gone before anything counts it.
##
## So a mote is a record here, exactly as a spark is on `VfxInk`: `burst`
## appends the drops, `_process` flies and lands them, `_draw` paints them.
## A landed drop still tells the `BloodField` where it fell, so the mark on
## the ground is still the consequence of the spray. The cap
## (`VFX_BLOOD_MOTES_MAX`) drops the oldest, which is what `VFX_MAX_LIVE` did
## to the node it replaces, and what bounds the frame under a fight no player
## can see the whole of anyway.
##
## **A mote in flight is a soft dot, not a lobed fan.** The first cut kept
## `BloodInk.blob` for the air and profiled at 4.6 ms a frame with the cap
## full: seventeen vertices and eight hashes built in script for a drop three
## pixels across, which no eye can tell from a soft disc. The ground keeps the
## lobed blob, where a mark is large, still and looked at; the air draws the
## same soft dot the flames use, stretched along its own velocity, which is
## the streak. The records are parallel packed arrays rather than a dictionary
## a drop, because a dictionary read per field per drop per frame was most of
## what was left.
##
## Presentation only: nothing reads a mote, and `Vfx.blood` is still the one
## door every blow bleeds through.

var _origin: PackedVector2Array = PackedVector2Array()
var _start: PackedVector2Array = PackedVector2Array()
var _end: PackedVector2Array = PackedVector2Array()
var _arc: PackedFloat32Array = PackedFloat32Array()
var _age: PackedFloat32Array = PackedFloat32Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _radius: PackedFloat32Array = PackedFloat32Array()
var _ground: BloodField = null
var _was_live: bool = false
## How many times the canvas has drawn, for the gate: a burst that is thrown
## and never painted is exactly the fault a count of records cannot see.
var draws: int = 0
## The landings' own dice: a droplet's size on the ground was rolled by the
## burst node that carried it, and the canvas rolls it for all of them now.
var _rng := RandomNumberGenerator.new()


func configure(ground: BloodField, seed_value: int) -> void:
	_ground = ground
	_rng.seed = seed_value
	z_index = Balance.VFX_Z


## One blow's spray. The drops are kept in world space, because the canvas
## sits at the world's origin and a blow's origin is not a node any more.
func burst(body_at: Vector2, ground_at: Vector2, direction: Vector2,
		size: float, rng: RandomNumberGenerator) -> void:
	var along: Vector2 = direction.normalized() if direction.length_squared() > 0.001 \
		else Vector2.from_angle(rng.randf() * TAU)
	var count: int = rng.randi_range(Balance.VFX_BLOOD_DROPS_MIN,
		Balance.VFX_BLOOD_DROPS_MAX)
	for index: int in count:
		var spread: float = rng.randf_range(-Balance.VFX_BLOOD_LAND_SPREAD,
			Balance.VFX_BLOOD_LAND_SPREAD)
		var throw: float = size * rng.randf_range(0.28, 0.92)
		var land: Vector2 = ground_at + along.rotated(spread) * throw \
			+ Vector2.from_angle(rng.randf() * TAU) * size * rng.randf_range(0.04, 0.18)
		_origin.append(body_at)
		_start.append(body_at + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0)))
		_end.append(land)
		_arc.append(rng.randf_range(Balance.VFX_BLOOD_ARC.x, Balance.VFX_BLOOD_ARC.y))
		_age.append(-float(index) * 0.012)
		_life.append(Balance.VFX_BLOOD_LIFE * rng.randf_range(0.72, 1.18))
		_radius.append(size * rng.randf_range(0.055, 0.105))
	# The oldest give way.
	var over: int = _origin.size() - Balance.VFX_BLOOD_MOTES_MAX
	if over > 0:
		_drop_first(over)


func _drop_first(count: int) -> void:
	_origin = _origin.slice(count)
	_start = _start.slice(count)
	_end = _end.slice(count)
	_arc = _arc.slice(count)
	_age = _age.slice(count)
	_life = _life.slice(count)
	_radius = _radius.slice(count)


## Drops still in the air, and those thrown from within `within` of `at` - for
## the gates, which used to count burst nodes.
func live() -> int:
	return _origin.size()


func live_near(at: Vector2, within: float) -> int:
	var count: int = 0
	for origin: Vector2 in _origin:
		if origin.distance_to(at) <= within:
			count += 1
	return count


func clear() -> void:
	_drop_first(_origin.size())
	queue_redraw()


func _process(delta: float) -> void:
	var count: int = _origin.size()
	if count == 0:
		if _was_live:
			# One empty redraw, so the last frame's motes do not hang.
			queue_redraw()
			_was_live = false
		return
	# Compacted in place: a landed drop's slot is taken by the next one flying.
	var kept: int = 0
	for index: int in count:
		var age: float = _age[index] + delta
		if age >= _life[index]:
			if _ground != null and is_instance_valid(_ground):
				_ground.droplet(_end[index], _radius[index] * 1.35, _rng)
			continue
		if kept != index:
			_origin[kept] = _origin[index]
			_start[kept] = _start[index]
			_end[kept] = _end[index]
			_arc[kept] = _arc[index]
			_life[kept] = _life[index]
			_radius[kept] = _radius[index]
		_age[kept] = age
		kept += 1
	if kept != count:
		_origin.resize(kept)
		_start.resize(kept)
		_end.resize(kept)
		_arc.resize(kept)
		_age.resize(kept)
		_life.resize(kept)
		_radius.resize(kept)
	_was_live = true
	queue_redraw()


## A mote is a streak, not a circle: the soft dot is drawn out along its own
## velocity, so the streak shortens on its own as the arc flattens and the
## drop slows. `BloodInk.MAX_LONG` bounds the stretch here as it does on the
## ground, because past it a drop reads as a slash.
func _draw_measured() -> void:
	draws += 1
	var dot: Texture2D = Flame.dot_texture()
	var count: int = _origin.size()
	for index: int in count:
		var age: float = _age[index]
		if age < 0.0:
			continue
		var life: float = maxf(_life[index], 0.001)
		var t: float = clampf(age / life, 0.0, 1.0)
		var point: Vector2 = _at(index, t)
		# Where it was a moment ago, so the streak follows the *arc* rather than
		# the straight line between the ends.
		var before: Vector2 = _at(index, maxf(t - 0.06, 0.0))
		var velocity: Vector2 = (point - before) / maxf(minf(0.06, t) * life, 0.001)
		var radius: float = _radius[index] * lerpf(1.0, 0.62, t)
		var stretch: Vector2 = velocity * Balance.BLOOD_MOTE_STREAK
		var long: float = 1.0
		var angle: float = 0.0
		if stretch.length_squared() > 0.0001:
			long = minf(1.0 + stretch.length() / maxf(radius, 0.01), BloodInk.MAX_LONG)
			angle = stretch.angle()
		draw_set_transform(point, angle, Vector2(long, 1.0))
		draw_texture_rect(dot, Rect2(-radius, -radius, radius * 2.0, radius * 2.0), false,
			Color(0.53, 0.055, 0.065, lerpf(0.96, 0.72, t)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _at(index: int, t: float) -> Vector2:
	var point: Vector2 = _start[index].lerp(_end[index], t)
	point.y -= sin(t * PI) * _arc[index]
	return point


## `FrameProfile` bucket "blood_air": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"blood_air", started)
