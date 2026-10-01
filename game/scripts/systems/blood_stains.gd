class_name BloodStains
extends Sprite2D

## **What a Brutal field never forgets** (owner, 2026-10-01: *"Blood stains
## should be permanent on brutal mode, never losing complete visibility and
## remaining visible on the ground as a stain of some sort of visibility for the
## rest of the game ... Brutal blood is practically forever."*).
##
## The marks a field draws are bounded (`BLOOD_MARKS_BRUTAL`), because a canvas
## of every droplet a ten-act road has spilled is a slideshow - and a busy wave
## lays hundreds a second, so the bound threw the oldest away within moments,
## which is exactly the "disappearing and quickly" the owner reported. On Brutal
## a mark the field lets go of is **baked** here instead: its blobs stamped into
## one map of coverage, `BLOOD_STAIN_TEXEL` units a texel, drawn as one quad of
## dried blood under the live marks. So nothing on Brutal is ever lost - it
## stops being a mark and becomes the ground's own stain, at the settled
## strength a Brutal mark ends at. A pool that soaks away bakes its own stain
## here too, as deep as it once stood.
##
## **A flood thins it and never takes it**: the map is washed by the field's own
## flood clock toward `BLOOD_BRUTAL_WASH_FLOOR`, the same as a live mark.
##
## A picture: nothing about pathing, placement or damage reads it. It lasts the
## road and comes home with a banked front.

const SHADER_PATH: String = "res://scripts/shaders/blood_stain_map.gdshader"

var _half: float = 0.0
var _across: int = 0
## One byte a texel: how much dried blood stands there.
var _cover: PackedByteArray = PackedByteArray()
var _image: Image = null
var _texture: ImageTexture = null
var _dirty: bool = false
var _upload_left: float = 0.0
var _material: ShaderMaterial = null
## Marks and pools baked, for the gate.
var baked: int = 0


func _init(half_extent: float = 0.0) -> void:
	_half = half_extent if half_extent > 0.0 else BattleGrid.HALF_EXTENT
	_across = maxi(int(ceil(_half * 2.0 / Balance.BLOOD_STAIN_TEXEL)), 1)
	_cover.resize(_across * _across)
	_cover.fill(0)


func _ready() -> void:
	name = "BloodStains"
	centered = false
	position = Vector2(-_half, -_half)
	scale = Vector2.ONE * Balance.BLOOD_STAIN_TEXEL
	# Under the live marks, above the ground they stain.
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if DisplayServer.get_name() != "headless":
		_image = Image.create_from_data(_across, _across, false, Image.FORMAT_L8, _cover)
		_texture = ImageTexture.create_from_image(_image)
		texture = _texture
		var shader: Shader = load(SHADER_PATH) as Shader
		if shader != null:
			_material = ShaderMaterial.new()
			_material.shader = shader
			_material.set_shader_parameter("dry_colour", Balance.BLOOD_DRY)
			_material.set_shader_parameter("dark_colour", Balance.BLOOD_POOL_DRY)
			_material.set_shader_parameter("strength", Balance.BLOOD_GROUND_ALPHA * Balance.BLOOD_BRUTAL_SETTLED)
			material = _material
	visible = false
	set_process(false)


## **A mark let go of, baked**: every blob stamped as the soft round it was
## drawn as, a streak as a run of them along its throw.
func bake(mark: Dictionary) -> void:
	var origin: Vector2 = mark.get("at", Vector2.ZERO) as Vector2
	for blob: Variant in (mark.get("blobs", []) as Array):
		var one: Dictionary = blob
		var centre: Vector2 = origin + (one.get("at", Vector2.ZERO) as Vector2)
		var radius: float = float(one.get("r", 2.0))
		var streak: Vector2 = one.get("long", Vector2.ZERO) as Vector2
		_stamp(centre, radius, 1.0)
		var steps: int = mini(int(streak.length() / maxf(radius, 1.0)), 4)
		for step: int in steps:
			var t: float = float(step + 1) / float(steps)
			_stamp(centre + streak * t, radius * (1.0 - 0.45 * t), 0.85)
	baked += 1
	_changed()


## **A pool that soaked away leaves its stain**, darker the deeper it once stood.
func stamp_pool(at: Vector2, radius: float, peak_depth: float) -> void:
	var strength: float = clampf(peak_depth / maxf(Balance.BLOOD_POOL_FULL, 0.01), 0.25, 1.0) \
		* Balance.BLOOD_POOL_STAIN
	_stamp(at, radius, strength)
	baked += 1
	_changed()


## How much stain stands at `point`, 0 to 1.
func coverage_at(point: Vector2) -> float:
	var cell: Vector2i = _cell_of(point)
	return float(_cover[cell.y * _across + cell.x]) / 255.0


## How much of the map holds any stain at all, for the gate.
func stained_texels() -> int:
	var count: int = 0
	for value: int in _cover:
		if value > 0:
			count += 1
	return count


## The flood's share of a stain that is left: 1 is untouched, the floor the
## most any flood can take it to. Set by the field from its flood clock.
func set_wash(left: float) -> void:
	if _material != null:
		_material.set_shader_parameter("wash", left)


func clear() -> void:
	_cover.fill(0)
	baked = 0
	_dirty = true
	_upload()
	visible = false


## **For a banked front**: the map as a PNG in text, or "" when nothing is
## stained. A field of mostly bare ground compresses to a few kilobytes.
func snapshot() -> String:
	if baked <= 0:
		return ""
	var picture: Image = Image.create_from_data(_across, _across, false, Image.FORMAT_L8, _cover)
	return Marshalls.raw_to_base64(picture.save_png_to_buffer())


func restore(text: String) -> void:
	if text.is_empty():
		return
	var raw: PackedByteArray = Marshalls.base64_to_raw(text)
	var picture := Image.new()
	if picture.load_png_from_buffer(raw) != OK:
		push_warning("[blood] a banked stain map could not be read; the ground starts clean")
		return
	if picture.get_format() != Image.FORMAT_L8:
		picture.convert(Image.FORMAT_L8)
	if picture.get_width() != _across or picture.get_height() != _across:
		picture.resize(_across, _across, Image.INTERPOLATE_BILINEAR)
	_cover = picture.get_data()
	baked = maxi(baked, 1)
	_changed()


func _stamp(at: Vector2, radius: float, strength: float) -> void:
	if not at.is_finite() or radius <= 0.0:
		return
	# A droplet smaller than a texel still darkens the texel it fell in.
	var reach: float = maxf(radius, Balance.BLOOD_STAIN_TEXEL * 0.6)
	var low: Vector2i = _cell_of(at - Vector2(reach, reach))
	var high: Vector2i = _cell_of(at + Vector2(reach, reach))
	var spread: float = clampf(radius / Balance.BLOOD_STAIN_TEXEL, 0.35, 1.0)
	for y: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			var centre := Vector2((float(x) + 0.5) * Balance.BLOOD_STAIN_TEXEL - _half,
				(float(y) + 0.5) * Balance.BLOOD_STAIN_TEXEL - _half)
			var r: float = centre.distance_to(at) / reach
			if r >= 1.0:
				continue
			var add: float = strength * spread * (1.0 - smoothstep(0.55, 1.0, r))
			var index: int = y * _across + x
			var now: float = float(_cover[index]) / 255.0
			_cover[index] = clampi(int(round((now + add * (1.0 - now)) * 255.0)), 0, 255)


func _changed() -> void:
	_dirty = true
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	_upload_left -= delta
	if not _dirty or _upload_left > 0.0:
		return
	_upload_left = 1.0 / Balance.BLOOD_STAIN_UPLOAD_HZ
	_upload()
	set_process(false)


func _upload() -> void:
	_dirty = false
	if _image == null or _texture == null:
		return
	_image.set_data(_across, _across, false, Image.FORMAT_L8, _cover)
	_texture.update(_image)


func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor((point.x + _half) / Balance.BLOOD_STAIN_TEXEL)), 0, _across - 1),
		clampi(int(floor((point.y + _half) / Balance.BLOOD_STAIN_TEXEL)), 0, _across - 1))
