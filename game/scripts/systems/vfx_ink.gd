class_name VfxInk
extends Node2D

## One canvas for the short-lived light of a fight (2026-09-24).
##
## A spark was a `Line2D` with a sprite on its tip and two tweens; a ring a
## `Line2D`, a bloom sprite and two tweens; a flash a polygon and a tween; a
## shot's mote a sprite and a tween eighteen times a second; a damage number a
## `Label` and five tweens; a muzzle a polygon, a sprite and three tweens; an
## impact two sprites, a material and two tweens. On Act X's waves that was
## well over a thousand nodes allocated and freed every second, and the
## `VfxLayer` sat against `VFX_MAX_LIVE` evicting its oldest child on every
## frame. Measured: 7,151 canvas items and 2,674 draw calls on a field of
## forty-two bodies, at 90-99 ms a frame.
##
## Every one of those is a small bright shape that moves for a fraction of a
## second, and that is one `_draw`: the items are records in arrays, advanced
## once a frame, and each kind is handed to the renderer as a single triangle
## array - or, for the painted art and the numbers, one draw command each with
## no node behind it. No node is born or freed for any of them, and the count
## is capped per kind by dropping the oldest, which is what the layer did.
##
## **Two of these stand on a field.** The additive one carries what is light -
## sparks, rings, flashes, motes, rays, the forged sheets - so a spark over a
## torch pool brightens it rather than painting a flat stroke across it; the
## flat one carries what is paint - the impact and muzzle art, the numbers -
## because additive text over a bright ground disappears. Every drawn shape
## has a solid middle and a rim at zero alpha - the rule `BloodInk`, the menu
## fire and the swim sheen all ended at: one colour for the whole shape is what
## a hard edge *is*.
##
## A look, never a fact. Nothing reads this canvas; `Graphics.particle_scale`
## and `JuiceDirector` thin what reaches it at the doors in `Vfx`, and a record
## dropped for the cap changes nothing about the blow that made it.
##
## `finish_when_paused`: the canvas processes always, and while the tree is
## paused only the records flagged `always` advance - a lightning strike's
## sparks must burn out under a pause exactly as the strike's own light does
## (`lightning_lifetime_check`), and a tower's must not.

## Whether this canvas adds light or lays paint.
var additive: bool = true

## The records, one array a kind. A record is a Dictionary rather than a node:
## an allocation still, but one a few hundred bytes wide with no tree, no
## transform notification and no free at the end of it.
var _sparks: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _rays: Array[Dictionary] = []
## Painted art played once: a sheet of cells, or a list of frames, or a single
## texture that fades.
var _art: Array[Dictionary] = []
## Damage numbers.
var _numbers: Array[Dictionary] = []

## Reused every frame rather than reallocated.
var _points: PackedVector2Array = PackedVector2Array()
var _colours: PackedColorArray = PackedColorArray()
var _indices: PackedInt32Array = PackedInt32Array()

## The numbers' face: the project theme's, as the labels wore.
var _font: Font = null
var _font_size: int = 18


func _init(adds_light: bool = true) -> void:
	additive = adds_light


func _ready() -> void:
	name = "VfxInk" if additive else "VfxInkFlat"
	z_index = Balance.VFX_Z if additive else Balance.VFX_Z + 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	add_to_group(Graphics.FILTER_GROUP)
	if additive:
		var glow := CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = glow
	var theme: Theme = ThemeDB.get_project_theme()
	if theme != null and theme.default_font != null:
		_font = theme.default_font
		_font_size = theme.default_font_size
	else:
		_font = ThemeDB.fallback_font
		_font_size = ThemeDB.fallback_font_size


func clear() -> void:
	_sparks.clear()
	_rings.clear()
	_flashes.clear()
	_motes.clear()
	_rays.clear()
	_art.clear()
	_numbers.clear()
	queue_redraw()


## How many records live, for the gates.
func live() -> int:
	return _sparks.size() + _rings.size() + _flashes.size() + _motes.size() + _rays.size() \
		+ _art.size() + _numbers.size()


func live_sparks() -> int:
	return _sparks.size()


func live_rings() -> int:
	return _rings.size()


func live_art() -> int:
	return _art.size()


func live_numbers() -> int:
	return _numbers.size()


## The painted records, oldest first, for a gate that wants to read a sheet's
## turn, flip, tint and age back off what was actually laid.
func art_records() -> Array[Dictionary]:
	return _art.duplicate()


func number_records() -> Array[Dictionary]:
	return _numbers.duplicate()


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


## Painted art played once at `at`: `frames` in order over `life` (one frame
## holds for the whole life), turned by `rotation`, at `scale` (a negative
## axis mirrors), in `tint`. `grow` is the scale the picture starts from as a
## share of `scale`, easing out to it; `fade_from` is the share of the life
## after which it fades to nothing (1.0 never fades - a sheet that ends on an
## empty cell needs none). Centred on `at`, as a sprite would be.
func art(frames: Array[Texture2D], at: Vector2, rotation: float, scale: Vector2,
		tint: Color, life: float, grow: float = 1.0, fade_from: float = 0.0,
		always: bool = false) -> void:
	if frames.is_empty():
		return
	_push(_art, {
		"frames": frames,
		"sheet": 0,
		"at": at,
		"rot": rotation,
		"scale": scale,
		"tint": tint,
		"life": maxf(life, 0.02),
		"grow": grow,
		"fade_from": fade_from,
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_ART_MAX)


## A forged sheet: one texture holding `cells` square cells in a row, played
## end to end over `life`.
func sheet(texture: Texture2D, cells: int, at: Vector2, rotation: float, scale: Vector2,
		tint: Color, life: float, always: bool = false) -> void:
	if texture == null or cells < 1:
		return
	var frames: Array[Texture2D] = [texture]
	_push(_art, {
		"frames": frames,
		"sheet": cells,
		"at": at,
		"rot": rotation,
		"scale": scale,
		"tint": tint,
		"life": maxf(life, 0.02),
		"grow": 1.0,
		"fade_from": 1.0,
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_ART_MAX)


## A damage number: pops, rises and hangs, then falls back a little and fades.
## `big` is a critical or a finisher - larger, tilted, longer.
func number(at: Vector2, text: String, colour: Color, big: bool) -> void:
	var rise: float = Balance.VFX_NUMBER_RISE \
		* (1.0 + (Balance.VFX_NUMBER_BIG_RISE_BONUS if big else 0.0))
	_push(_numbers, {
		"at": at + Vector2(randf_range(-14.0, 14.0), -20.0),
		"text": text,
		"colour": colour,
		"big": big,
		"tilt": deg_to_rad(randf_range(-Balance.VFX_NUMBER_TILT_DEGREES,
			Balance.VFX_NUMBER_TILT_DEGREES)) if big else 0.0,
		"side": randf_range(-26.0, 26.0),
		"rise": rise,
		"life": Balance.VFX_NUMBER_LIFE * (1.25 if big else 1.0),
		"age": 0.0,
		"always": false,
	}, Balance.VFX_INK_NUMBERS_MAX)


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
	moved = _age(_art, delta, paused) or moved
	moved = _age(_numbers, delta, paused) or moved
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
	_draw_art(inverse)
	_draw_numbers(inverse)


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


## Painted art: a transform per record and one draw command, centred on its
## point as a sprite is. A sheet reads its cell off its age; a frame list
## plays end to end; a single texture holds and fades.
func _draw_art(inverse: Transform2D) -> void:
	if _art.is_empty():
		return
	for record: Dictionary in _art:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var frames: Array[Texture2D] = record["frames"]
		var cells: int = int(record["sheet"])
		var tint: Color = record["tint"] as Color
		var fade_from: float = float(record["fade_from"])
		if fade_from < 1.0 and t > fade_from:
			tint.a *= 1.0 - (t - fade_from) / maxf(1.0 - fade_from, 0.001)
		var grow: float = float(record["grow"])
		var scale: Vector2 = record["scale"] as Vector2
		if grow < 1.0:
			scale *= lerpf(grow, 1.0, 1.0 - pow(1.0 - minf(t / 0.35, 1.0), 2.0))
		draw_set_transform(inverse * (record["at"] as Vector2), float(record["rot"]), scale)
		if cells > 1:
			var texture: Texture2D = frames[0]
			var tall: float = float(texture.get_height())
			var cell: int = clampi(int(t * float(cells)), 0, cells - 1)
			draw_texture_rect_region(texture, Rect2(-tall * 0.5, -tall * 0.5, tall, tall),
				Rect2(float(cell) * tall, 0.0, tall, tall), tint)
		else:
			var frame: Texture2D = frames[clampi(int(t * float(frames.size())), 0, frames.size() - 1)]
			draw_texture(frame, -frame.get_size() * 0.5, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Damage numbers: a pop (scale from a third to `VFX_NUMBER_POP` and back to
## one), a rise that eases out then sinks back a little, a fade over the
## second half - the motion the labels had, on one canvas.
func _draw_numbers(inverse: Transform2D) -> void:
	if _numbers.is_empty() or _font == null:
		return
	for record: Dictionary in _numbers:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var big: bool = bool(record["big"])
		var pop: float = Balance.VFX_NUMBER_POP * (1.15 if big else 1.0)
		var scale: float
		if t < 0.16:
			var u: float = t / 0.16
			scale = lerpf(0.35, pop, 1.0 - pow(1.0 - u, 3.0))
		elif t < 0.40:
			var u: float = (t - 0.16) / 0.24
			scale = lerpf(pop, 1.0, u * u * (3.0 - 2.0 * u))
		else:
			scale = 1.0
		var rise: float = float(record["rise"])
		var side: float = float(record["side"])
		var offset: Vector2
		if t < 0.55:
			var u: float = t / 0.55
			offset = Vector2(side * 0.7, -rise) * (1.0 - pow(1.0 - u, 3.0))
		else:
			var u: float = (t - 0.55) / 0.45
			offset = Vector2(side * 0.7, -rise).lerp(Vector2(side, -rise * 0.82),
				1.0 - cos(u * PI * 0.5))
		var colour: Color = record["colour"] as Color
		if t > 0.5:
			colour.a *= 1.0 - (t - 0.5) / 0.5
		var size: int = Balance.VFX_NUMBER_SIZE_BIG if big else Balance.VFX_NUMBER_SIZE
		var text: String = String(record["text"])
		var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at: Vector2 = inverse * ((record["at"] as Vector2) + offset)
		draw_set_transform(at, float(record["tilt"]), Vector2.ONE * scale)
		var pen := Vector2(-width * 0.5, float(size) * 0.35)
		draw_string_outline(_font, pen, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			8 if big else 6, Color(0.02, 0.04, 0.05, 0.9 * colour.a))
		draw_string(_font, pen, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
