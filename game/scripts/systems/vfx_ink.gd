class_name VfxInk
extends Node2D

## One canvas for the short-lived light of a fight (2026-09-24).
##
## A spark was a `Line2D` with a sprite on its tip and two tweens; a ring a
## `Line2D`, a bloom sprite and two tweens; a flash a polygon and a tween; a
## shot's mote a sprite and a tween eighteen times a second. On Act X's waves
## that was about a thousand nodes allocated and freed every second, and the
## `VfxLayer` sat against `VFX_MAX_LIVE` evicting its oldest child on every
## frame. Measured: 7,151 canvas items and 2,674 draw calls on a field of
## forty-two bodies, at 90-99 ms a frame.
##
## Every one of those is a small bright shape that moves for a fraction of a
## second, and that is one `_draw`: the items are records in arrays, advanced
## once a frame, and each kind is handed to the renderer as a single triangle
## array. No node is born or freed for any of them, and the count is capped
## per kind by dropping the oldest, which is what the layer did anyway.
##
## **And they are drawn as light rather than as lines.** Every shape here has a
## solid middle and a rim at zero alpha - the rule `BloodInk`, the menu fire
## and the swim sheen all ended at: one colour for the whole shape is what a
## hard edge *is* - and the whole canvas blends additively, so a spark over a
## torch pool brightens it rather than painting a flat stroke across it.
##
## A look, never a fact. Nothing reads this canvas; `Graphics.particle_scale`
## and `JuiceDirector` thin what reaches it at the doors in `Vfx`, and a record
## dropped for the cap changes nothing about the blow that made it.
##
## `finish_when_paused`: the canvas processes always, and while the tree is
## paused only the records flagged `always` advance - a lightning strike's
## sparks must burn out under a pause exactly as the strike's own light does
## (`lightning_lifetime_check`), and a tower's must not.

## The records, one array a kind. A record is a Dictionary rather than a node:
## an allocation still, but one a few hundred bytes wide with no tree, no
## transform notification and no free at the end of it.
var _sparks: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _rays: Array[Dictionary] = []

## Reused every frame rather than reallocated.
var _points: PackedVector2Array = PackedVector2Array()
var _colours: PackedColorArray = PackedColorArray()
var _indices: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	name = "VfxInk"
	z_index = Balance.VFX_Z
	process_mode = Node.PROCESS_MODE_ALWAYS
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material


func clear() -> void:
	_sparks.clear()
	_rings.clear()
	_flashes.clear()
	_motes.clear()
	_rays.clear()
	queue_redraw()


## How many records live, for the gates.
func live() -> int:
	return _sparks.size() + _rings.size() + _flashes.size() + _motes.size() + _rays.size()


func live_sparks() -> int:
	return _sparks.size()


func live_rings() -> int:
	return _rings.size()


# --- Doors ----------------------------------------------------------------------

## A shard flying from `at` along `direction` (random when zero), fading as it
## goes, with a soft mote on its tip. `speed` is the reach it covers over its
## life, eased out.
func spark(at: Vector2, direction: Vector2, colour: Color, speed: float,
		always: bool = false) -> void:
	var angle: float
	if direction == Vector2.ZERO:
		angle = randf() * TAU
	else:
		angle = direction.angle() + randf_range(-Balance.VFX_SPARK_SPREAD, Balance.VFX_SPARK_SPREAD)
	_push(_sparks, {
		"at": at,
		"dir": Vector2.RIGHT.rotated(angle),
		"travel": speed * randf_range(0.5, 1.2),
		"length": randf_range(6.0, 16.0),
		"width": randf_range(2.0, 4.0),
		"colour": colour,
		"life": Balance.VFX_SPARK_LIFE * randf_range(0.7, 1.3),
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_SPARKS_MAX)


## A ring growing from nothing to `to_radius` over `life`, `width` thick, with
## a faint wider halo, fading as it grows.
func ring(at: Vector2, to_radius: float, colour: Color, life: float, width: float,
		always: bool = false) -> void:
	_push(_rings, {
		"at": at,
		"radius": maxf(to_radius, 1.0),
		"width": maxf(width, 1.0),
		"colour": colour,
		"life": maxf(life, 0.02),
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_RINGS_MAX)


## A soft disc that swells to nearly twice its size and is gone in a sixth of
## a second - the light of a blow landing.
func flash(at: Vector2, colour: Color, radius: float, always: bool = false) -> void:
	_push(_flashes, {
		"at": at,
		"radius": maxf(radius, 1.0),
		"colour": Color(colour.lerp(Color.WHITE, 0.6), 0.85),
		"life": Balance.VFX_FLASH_LIFE,
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_FLASHES_MAX)


## A soft dot that drifts by `drift` over `life`, shrinking and fading - what a
## shot sheds behind it, what a spray throws, what a mote is.
func mote(at: Vector2, drift: Vector2, colour: Color, size: float, life: float,
		always: bool = false) -> void:
	_push(_motes, {
		"at": at,
		"drift": drift,
		"colour": colour,
		"size": maxf(size, 0.5),
		"life": maxf(life, 0.02),
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_MOTES_MAX)


## A ray out from `at`: a shard that grows from a third of its reach to the
## whole of it and fades - the burst round a build or an upgrade.
func ray(at: Vector2, direction: Vector2, colour: Color, inner: float, outer: float,
		life: float, always: bool = false) -> void:
	_push(_rays, {
		"at": at,
		"dir": direction,
		"inner": inner,
		"outer": outer,
		"width": randf_range(2.0, 4.5),
		"colour": colour,
		"life": maxf(life, 0.02),
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_RAYS_MAX)


func _push(into: Array[Dictionary], record: Dictionary, cap: int) -> void:
	into.append(record)
	# The oldest give way, which is what the node layer did with its cap.
	while into.size() > cap:
		into.remove_at(0)


# --- The clock --------------------------------------------------------------------

func _process(delta: float) -> void:
	var paused: bool = get_tree() != null and get_tree().paused
	var moved: bool = false
	moved = _age(_sparks, delta, paused) or moved
	moved = _age(_rings, delta, paused) or moved
	moved = _age(_flashes, delta, paused) or moved
	moved = _age(_motes, delta, paused) or moved
	moved = _age(_rays, delta, paused) or moved
	if moved:
		queue_redraw()


## Ages every record that may move now and drops the ones that are done.
## Returns whether anything is alive to draw.
func _age(records: Array[Dictionary], delta: float, paused: bool) -> bool:
	if records.is_empty():
		return false
	var index: int = records.size() - 1
	while index >= 0:
		var record: Dictionary = records[index]
		if not paused or bool(record["always"]):
			var age: float = float(record["age"]) + delta
			if age >= float(record["life"]):
				records.remove_at(index)
			else:
				record["age"] = age
		index -= 1
	return not records.is_empty()


# --- The picture ------------------------------------------------------------------

func _draw() -> void:
	var inverse: Transform2D = global_transform.affine_inverse()
	_draw_sparks(inverse)
	_draw_rays(inverse)
	_draw_rings(inverse)
	_draw_flashes(inverse)
	_draw_motes(inverse)


func _begin() -> void:
	_points.clear()
	_colours.clear()
	_indices.clear()


func _flush() -> void:
	if _indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _indices, _points, _colours)


## A feathered strip: a spine from `head` to `tail` with `width` either side,
## solid along the spine and clear at the edges, the alpha falling from `lit`
## at the head to `lit * tail_share` at the tail. Nine vertices, eight
## triangles, no hard edge anywhere.
func _strip(head: Vector2, tail: Vector2, width: float, colour: Color, lit: float,
		tail_share: float) -> void:
	var along: Vector2 = tail - head
	if along.length_squared() < 0.01:
		return
	var side: Vector2 = along.normalized().orthogonal() * width
	var clear := Color(colour.r, colour.g, colour.b, 0.0)
	var base: int = _points.size()
	for step: int in 3:
		var t: float = float(step) * 0.5
		var centre: Vector2 = head + along * t
		var mid := Color(colour.r, colour.g, colour.b, lit * lerpf(1.0, tail_share, t))
		_points.append(centre - side)
		_colours.append(clear)
		_points.append(centre)
		_colours.append(mid)
		_points.append(centre + side)
		_colours.append(clear)
	for step: int in 2:
		var row: int = base + step * 3
		for column: int in 2:
			var a: int = row + column
			_indices.append(a)
			_indices.append(a + 1)
			_indices.append(a + 3)
			_indices.append(a + 1)
			_indices.append(a + 4)
			_indices.append(a + 3)


## A soft disc: solid in the middle, clear at the rim, `segments` wide.
func _disc(centre: Vector2, radius: float, colour: Color, lit: float, segments: int) -> void:
	var base: int = _points.size()
	_points.append(centre)
	_colours.append(Color(colour.r, colour.g, colour.b, lit))
	var clear := Color(colour.r, colour.g, colour.b, 0.0)
	for step: int in segments:
		var angle: float = TAU * float(step) / float(segments)
		_points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
		_colours.append(clear)
	for step: int in segments:
		_indices.append(base)
		_indices.append(base + 1 + step)
		_indices.append(base + 1 + (step + 1) % segments)


## A soft annulus: clear inside, solid on the ring, clear outside.
func _annulus(centre: Vector2, radius: float, width: float, colour: Color, lit: float,
		segments: int) -> void:
	var base: int = _points.size()
	var clear := Color(colour.r, colour.g, colour.b, 0.0)
	var mid := Color(colour.r, colour.g, colour.b, lit)
	for step: int in segments + 1:
		var angle: float = TAU * float(step) / float(segments)
		var out := Vector2(cos(angle), sin(angle))
		_points.append(centre + out * maxf(radius - width, 0.0))
		_colours.append(clear)
		_points.append(centre + out * radius)
		_colours.append(mid)
		_points.append(centre + out * (radius + width))
		_colours.append(clear)
	for step: int in segments:
		var row: int = base + step * 3
		for column: int in 2:
			var a: int = row + column
			_indices.append(a)
			_indices.append(a + 1)
			_indices.append(a + 3)
			_indices.append(a + 1)
			_indices.append(a + 4)
			_indices.append(a + 3)


func _draw_sparks(inverse: Transform2D) -> void:
	if _sparks.is_empty():
		return
	_begin()
	for record: Dictionary in _sparks:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - t, 3.0)
		var dir: Vector2 = record["dir"] as Vector2
		var head: Vector2 = (record["at"] as Vector2) + dir * float(record["travel"]) * eased
		var colour: Color = record["colour"] as Color
		var lit: float = colour.a * (1.0 - t)
		var length: float = float(record["length"]) * (1.0 - 0.4 * t)
		_strip(inverse * head, inverse * (head - dir * length),
			float(record["width"]) * (1.0 - 0.3 * t), colour, lit, 0.25)
		# The mote on the tip: what made a shard read as hot rather than as a
		# dash. It shrinks as the shard cools.
		_disc(inverse * head, float(record["width"]) * 1.8 * lerpf(1.0, 0.35, t),
			colour, lit * 0.9, 6)
	_flush()


func _draw_rays(inverse: Transform2D) -> void:
	if _rays.is_empty():
		return
	_begin()
	for record: Dictionary in _rays:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var grown: float = lerpf(0.35, 1.0, 1.0 - pow(1.0 - t, 4.0))
		var lit: float = 1.0 if t < 0.18 else 1.0 - (t - 0.18) / 0.82
		var at: Vector2 = record["at"] as Vector2
		var dir: Vector2 = record["dir"] as Vector2
		var colour: Color = record["colour"] as Color
		_strip(inverse * (at + dir * float(record["outer"]) * grown),
			inverse * (at + dir * float(record["inner"]) * grown),
			float(record["width"]) * 0.5, colour, colour.a * lit, 0.6)
	_flush()


func _draw_rings(inverse: Transform2D) -> void:
	if _rings.is_empty():
		return
	_begin()
	for record: Dictionary in _rings:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var grown: float = 1.0 - pow(1.0 - t, 2.0)
		var radius: float = lerpf(4.0, float(record["radius"]), grown)
		var colour: Color = record["colour"] as Color
		var lit: float = colour.a * (1.0 - t)
		var at: Vector2 = inverse * (record["at"] as Vector2)
		var width: float = float(record["width"])
		# The bloom: the same ring, wide and faint, so the edge reads as a
		# wave leaving a point rather than a drawn circle.
		_annulus(at, radius, width * 3.5, colour, lit * 0.22, 32)
		_annulus(at, radius, width, colour, lit, 32)
	_flush()


func _draw_flashes(inverse: Transform2D) -> void:
	if _flashes.is_empty():
		return
	_begin()
	for record: Dictionary in _flashes:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var grown: float = lerpf(1.0, 1.9, 1.0 - pow(1.0 - t, 2.0))
		var colour: Color = record["colour"] as Color
		_disc(inverse * (record["at"] as Vector2), float(record["radius"]) * grown, colour,
			colour.a * (1.0 - t), 12)
	_flush()


func _draw_motes(inverse: Transform2D) -> void:
	if _motes.is_empty():
		return
	_begin()
	for record: Dictionary in _motes:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var at: Vector2 = (record["at"] as Vector2) + (record["drift"] as Vector2) * t
		var colour: Color = record["colour"] as Color
		_disc(inverse * at, float(record["size"]) * lerpf(1.0, 0.35, t), colour,
			colour.a * (1.0 - t), 8)
	_flush()
