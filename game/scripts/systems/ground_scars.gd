class_name GroundScars
extends Sprite2D

## **What the ground remembers of what struck it** (owner, 2026-10-01:
## *"Ground damage surface imperfections accumulating from the damages it takes
## from things that can damage the ground surface, underneath the blood ...
## unless it's a crater from bigger impacts such as meteors etc. Earthquake
## events should also leave some procedural effects naturally on what they
## affect. Maybe depth maps would help"*).
##
## A depth map: one height a texel, `SCAR_TEXEL` units across, nothing at
## untouched ground, below it in a dent and above it on the lip thrown up
## round one. Everything that breaks the ground stamps it - a slam, a mortar, a
## lob landing, a meteor, a quake's crests and the cracks they leave, a fissure,
## a dragon touching down - and the stamps add, so a fought-over clearing is
## pocked and trodden where a quiet one is smooth.
##
## **Drawn as light, not paint** (`ground_scars.gdshader`): the slope of the
## depth map is a normal, the normal is lit from the sun's side, dents are
## shadowed inside and lit on the far lip, and the floor of a dent is rough with
## grit. That is the normal-and-roughness the owner asked about, on the one
## surface the camera sees most of, for one texture and one quad.
##
## **Read by the blood**: thin fresh blood gathers in the dents first
## (`BloodPools`), and only until it is deep enough to cover them.
##
## **A picture.** Nothing about pathing, placement, building or damage asks the
## depth map. It lasts the whole road - every act of it - and comes home with a
## banked front (owner, 2026-10-01: "permanent for the entire continuation of
## all of the runs that journey continues").

var _half: float = 0.0
var _across: int = 0
var _heights: PackedFloat32Array = PackedFloat32Array()
var _image: Image = null
var _texture: ImageTexture = null
var _dirty: bool = false
## The texels changed since the last upload, so an upload touches those alone.
var _dirty_rect: Rect2i = Rect2i()
var _upload_left: float = 0.0
var _dice := RandomNumberGenerator.new()
## Stamps laid, for the gate.
var stamps: int = 0


func _init(half_extent: float = 0.0) -> void:
	_half = half_extent if half_extent > 0.0 else BattleGrid.HALF_EXTENT
	_across = maxi(int(ceil(_half * 2.0 / Balance.SCAR_TEXEL)), 1)
	_heights.resize(_across * _across)
	_heights.fill(0.0)
	_dice.seed = hash("ground_scars") ^ RunState.run_seed


func _ready() -> void:
	name = "GroundScars"
	centered = false
	position = Vector2(-_half, -_half)
	scale = Vector2.ONE * Balance.SCAR_TEXEL
	z_as_relative = false
	z_index = Balance.SCAR_Z
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if DisplayServer.get_name() != "headless":
		_image = Image.create(_across, _across, false, Image.FORMAT_L8)
		_image.fill(Color(0.5, 0.5, 0.5, 1.0))
		_texture = ImageTexture.create_from_image(_image)
		texture = _texture
		var shader: Shader = load("res://scripts/shaders/ground_scars.gdshader") as Shader
		if shader != null:
			var made := ShaderMaterial.new()
			made.shader = shader
			material = made
	visible = false
	set_process(false)


## The depth map, for the blood that gathers in it. Null headless.
func heights() -> Texture2D:
	return _texture


func half_extent() -> float:
	return _half


## How high the ground stands at `at`: 0 untouched, below in a dent, above on
## a lip.
func height_at(point: Vector2) -> float:
	var fx: float = (point.x + _half) / Balance.SCAR_TEXEL - 0.5
	var fy: float = (point.y + _half) / Balance.SCAR_TEXEL - 0.5
	var x0: int = clampi(int(floor(fx)), 0, _across - 1)
	var y0: int = clampi(int(floor(fy)), 0, _across - 1)
	var x1: int = mini(x0 + 1, _across - 1)
	var y1: int = mini(y0 + 1, _across - 1)
	var tx: float = clampf(fx - float(x0), 0.0, 1.0)
	var ty: float = clampf(fy - float(y0), 0.0, 1.0)
	return lerpf(lerpf(_heights[y0 * _across + x0], _heights[y0 * _across + x1], tx),
		lerpf(_heights[y1 * _across + x0], _heights[y1 * _across + x1], tx), ty)


## **A dent**: a bowl `depth` deep across `radius`, the earth it pushed out
## heaped in a lip `rim` of the depth high just outside it. Adds to what is
## there, never past the floor.
func dent(at: Vector2, radius: float, depth: float, rim: float = 0.35) -> void:
	if radius <= 1.0 or depth <= 0.0 or not at.is_finite():
		return
	var reach: float = radius * 1.45
	var low: Vector2i = _cell_of(at - Vector2(reach, reach))
	var high: Vector2i = _cell_of(at + Vector2(reach, reach))
	var touched := Rect2i(low, high - low + Vector2i.ONE)
	_dirty_rect = touched if _dirty_rect.size == Vector2i.ZERO else _dirty_rect.merge(touched)
	for y: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			var centre: Vector2 = Vector2((float(x) + 0.5) * Balance.SCAR_TEXEL - _half,
				(float(y) + 0.5) * Balance.SCAR_TEXEL - _half)
			var r: float = centre.distance_to(at) / radius
			var change: float = 0.0
			if r < 1.0:
				# A bowl: deepest at the middle, its wall rising to the lip.
				change = -depth * (1.0 - r * r)
			elif r < 1.45:
				# The lip, heaped and falling away outside.
				var t: float = (r - 1.0) / 0.45
				change = depth * rim * sin(t * PI) * (1.0 - t * 0.3)
			if change == 0.0:
				continue
			var index: int = y * _across + x
			_heights[index] = clampf(_heights[index] + change, -1.0, 0.6)
	stamps += 1
	_changed()


## **A crack**: a jagged line from `from` to `to`, `width` across, gouged
## `depth` deep, with a little thrown up along its edges. Jagged by the field's
## own dice, so two quakes never crack the ground the same way.
func crack(from: Vector2, to: Vector2, width: float, depth: float) -> void:
	var along: Vector2 = to - from
	var length: float = along.length()
	if length < 1.0:
		return
	var steps: int = maxi(int(length / maxf(width * 0.8, 6.0)), 2)
	var side: Vector2 = along.normalized().orthogonal()
	var drift: float = 0.0
	for index: int in steps + 1:
		var t: float = float(index) / float(steps)
		drift = clampf(drift + _dice.randf_range(-0.6, 0.6) * width, -width * 2.5, width * 2.5)
		var point: Vector2 = from + along * t + side * drift
		var taper: float = sin(t * PI) * 0.6 + 0.4
		dent(point, width * taper, depth * taper, 0.25)
		stamps -= 1
	stamps += 1


## **A crater**: the meteor's own, deep with a high lip, and ringed with the
## small dents of what it threw out.
func crater(at: Vector2, radius: float) -> void:
	dent(at, radius, 0.9, 0.55)
	var throws: int = 7
	for index: int in throws:
		var out: Vector2 = at + Vector2.from_angle(_dice.randf() * TAU) * radius * _dice.randf_range(1.5, 2.2)
		dent(out, radius * _dice.randf_range(0.08, 0.16), 0.25, 0.3)
		stamps -= 1


## **A quake's mark on the ground** (2026-10-01): cracks running out from the
## epicentre along no two lines alike, and the ground slumped in patches where
## the crests broke hardest.
func quake(epicentre: Vector2, reach: float, magnitude: float) -> void:
	var cracks: int = 3 + int(round(magnitude * 4.0))
	for index: int in cracks:
		var heading: float = _dice.randf() * TAU
		var start: Vector2 = epicentre + Vector2.from_angle(heading) * _dice.randf_range(20.0, 90.0)
		var length: float = reach * _dice.randf_range(0.3, 0.7) * (0.6 + magnitude * 0.4)
		crack(start, start + Vector2.from_angle(heading + _dice.randf_range(-0.3, 0.3)) * length,
			_dice.randf_range(10.0, 18.0) * (0.7 + magnitude * 0.5), 0.35 + magnitude * 0.35)
		stamps -= 1
	var slumps: int = 4 + int(round(magnitude * 6.0))
	for index: int in slumps:
		var spot: Vector2 = epicentre + Vector2.from_angle(_dice.randf() * TAU) * _dice.randf_range(80.0, reach * 0.8)
		dent(spot, _dice.randf_range(30.0, 64.0), 0.06 + magnitude * 0.1, 0.25)
		stamps -= 1
	stamps += 1


func clear() -> void:
	_heights.fill(0.0)
	_dirty_rect = Rect2i()
	if _image != null and _texture != null:
		_image.fill(Color(0.5, 0.5, 0.5, 1.0))
		_texture.update(_image)
	visible = false


func _changed() -> void:
	_dirty = true
	visible = true
	set_process(true)


## **For a banked front**: the depth map as an 8-bit PNG in text - a height a
## byte, half-way untouched - or "" when nothing was ever struck.
func snapshot() -> String:
	if stamps <= 0:
		return ""
	var bytes := PackedByteArray()
	bytes.resize(_across * _across)
	for index: int in _heights.size():
		bytes[index] = clampi(int(round((clampf(_heights[index], -1.0, 1.0) * 0.5 + 0.5) * 255.0)), 0, 255)
	var picture: Image = Image.create_from_data(_across, _across, false, Image.FORMAT_L8, bytes)
	return Marshalls.raw_to_base64(picture.save_png_to_buffer())


func restore(text: String) -> void:
	if text.is_empty():
		return
	var picture := Image.new()
	if picture.load_png_from_buffer(Marshalls.base64_to_raw(text)) != OK:
		push_warning("[ground] banked scars could not be read; the ground starts whole")
		return
	if picture.get_format() != Image.FORMAT_L8:
		picture.convert(Image.FORMAT_L8)
	if picture.get_width() != _across or picture.get_height() != _across:
		picture.resize(_across, _across, Image.INTERPOLATE_BILINEAR)
	var bytes: PackedByteArray = picture.get_data()
	for index: int in mini(bytes.size(), _heights.size()):
		# A byte either side of the middle is the quantisation of nothing.
		var height: float = float(bytes[index]) / 255.0 * 2.0 - 1.0
		_heights[index] = 0.0 if absf(height) < 0.006 else height
	stamps = maxi(stamps, 1)
	_dirty_rect = Rect2i(Vector2i.ZERO, Vector2i(_across, _across))
	_changed()


func _process(delta: float) -> void:
	_upload_left -= delta
	if not _dirty or _upload_left > 0.0:
		return
	_upload_left = 1.0 / Balance.SCAR_UPLOAD_HZ
	_dirty = false
	if _image == null or _texture == null:
		set_process(false)
		return
	var rect: Rect2i = _dirty_rect
	_dirty_rect = Rect2i()
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var height: float = _heights[y * _across + x]
			_image.set_pixel(x, y, Color(clampf(height * 0.5 + 0.5, 0.0, 1.0), 0.0, 0.0, 1.0))
	_texture.update(_image)
	set_process(false)


func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor((point.x + _half) / Balance.SCAR_TEXEL)), 0, _across - 1),
		clampi(int(floor((point.y + _half) / Balance.SCAR_TEXEL)), 0, _across - 1))
