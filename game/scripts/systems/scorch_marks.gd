class_name ScorchMarks
extends Sprite2D

## The ground remembers what the earth did to it.
##
## Owner brief, 2026-09-14: wildfires and impacts should leave "scorched earth
## marks ... a historic trace of the map's activity". One image over the whole
## field, a texel every `SCORCH_TEXEL` units, stamped with feathered discs
## wherever something burned or fell, and drawn once as a sprite over the
## ground and the roads. The feathering is in the texels and the sprite is
## read bilinearly, so a mark has soft edges without a shader - which is what
## lets this be looked at headless, unlike the flood's sheen.
##
## Marks never fade within an act. `refresh_terrain` clears them when the road
## changes region, which is the same moment the foliage regrows.

var half_extent: float = 0.0
var _across: int = 2
var _image: Image = null
var _texture: ImageTexture = null
var _bytes: PackedByteArray = PackedByteArray()
var _dirty: bool = false
var _stamps: int = 0


func _ready() -> void:
	name = "ScorchMarks"
	z_as_relative = false
	_across = maxi(int(ceil(half_extent * 2.0 / Balance.SCORCH_TEXEL)), 2)
	_bytes.resize(_across * _across * 4)
	_bytes.fill(0)
	_image = Image.create_from_data(_across, _across, false, Image.FORMAT_RGBA8, _bytes)
	_texture = ImageTexture.create_from_image(_image)
	texture = _texture
	centered = true
	scale = Vector2.ONE * (half_extent * 2.0 / float(_across))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	modulate = Balance.SCORCH_TINT


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_image.set_data(_across, _across, false, Image.FORMAT_RGBA8, _bytes)
		_texture.update(_image)


## Burns a disc into the ground: full at the centre, feathered to nothing at
## `radius`. Darker marks win over lighter ones and never lighten.
func stamp(at: Vector2, radius: float, strength: float = 1.0) -> void:
	if _across < 2 or radius <= 0.0:
		return
	var centre: Vector2 = (at + Vector2.ONE * half_extent) / Balance.SCORCH_TEXEL
	var reach: float = radius / Balance.SCORCH_TEXEL
	var x0: int = maxi(int(floor(centre.x - reach)), 0)
	var x1: int = mini(int(ceil(centre.x + reach)), _across - 1)
	var y0: int = maxi(int(floor(centre.y - reach)), 0)
	var y1: int = mini(int(ceil(centre.y + reach)), _across - 1)
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var away: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(centre) / maxf(reach, 0.001)
			if away >= 1.0:
				continue
			# Soft at the rim and a little uneven inside, so a mark reads as
			# burnt ground rather than as a stencil.
			var grain: float = 0.85 + 0.15 * sin(float(x) * 12.9898 + float(y) * 78.233)
			var value: int = int(clampf(strength * (1.0 - away * away) * grain, 0.0, 1.0) * 255.0)
			var index: int = (y * _across + x) * 4
			if value > _bytes[index + 3]:
				_bytes[index] = 0
				_bytes[index + 1] = 0
				_bytes[index + 2] = 0
				_bytes[index + 3] = value
	_stamps += 1
	_dirty = true


## Whether the ground here carries a mark. For the gate.
func marked_at(at: Vector2) -> bool:
	var texel: Vector2i = Vector2i(((at + Vector2.ONE * half_extent) / Balance.SCORCH_TEXEL).floor())
	if texel.x < 0 or texel.y < 0 or texel.x >= _across or texel.y >= _across:
		return false
	return _bytes[(texel.y * _across + texel.x) * 4 + 3] > 24


func stamp_count() -> int:
	return _stamps


## A new region is new ground.
func clear() -> void:
	_bytes.fill(0)
	_stamps = 0
	_dirty = true
