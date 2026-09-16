class_name FallingRock
extends Node2D

## A chunk of the ceiling coming down (2026-09-14).
##
## The collapse used to be dust puffs; a place that is coming down sheds
## *rock*, and a rock is a thing with a shadow that grows before it lands.
## So: a chunk from the sheet, starting high and large, falling on an ease-in
## with its shadow spreading under it, and on landing a puff of dust, a stone
## knock, and a shake weighted by distance through `camera_impact` - the one
## door every blow's shake goes through. It lies where it fell for a while,
## then fades.
##
## Never a blow: the collapse bites through `Health.take_damage` on its own
## clock, and this is what that bite looks like. Nothing reads it.

const ART: String = "res://art/raid/dungeon_rocks.png"
const CHUNKS: int = 3

static var _texture: Texture2D = null
static var _looked: bool = false

## How big a chunk this is, as a scale on the art; and how hard it lands.
var size: float = Balance.DUNGEON_ROCK_SIZE
var power: float = Balance.DUNGEON_ROCK_IMPACT

var _sprite: Sprite2D = null
var _shadow: Sprite2D = null
var _t: float = 0.0
var _landed: bool = false
var _linger: float = 0.0
var _spin: float = 0.0


static func texture() -> Texture2D:
	if not _looked:
		_looked = true
		if ResourceLoader.exists(ART):
			_texture = load(ART) as Texture2D
	return _texture


func _ready() -> void:
	var art: Texture2D = texture()
	if art == null:
		queue_free()
		return
	y_sort_enabled = false
	_shadow = Sprite2D.new()
	_shadow.name = "Shadow"
	_shadow.texture = LightKit.falloff_texture()
	_shadow.modulate = Color(0.0, 0.0, 0.0, 0.15)
	_shadow.scale = Vector2(0.12, 0.07) * size * 1.4
	_shadow.z_index = -1
	_shadow.z_as_relative = true
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.name = "Rock"
	_sprite.texture = art
	_sprite.region_enabled = true
	@warning_ignore("integer_division")
	var wide: int = art.get_width() / CHUNKS
	_sprite.region_rect = Rect2(float(randi_range(0, CHUNKS - 1) * wide), 0.0, float(wide),
		float(art.get_height()))
	_sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_sprite.add_to_group(Graphics.FILTER_GROUP)
	_sprite.rotation = randf() * TAU
	_sprite.position.y = -Balance.DUNGEON_ROCK_FALL_HEIGHT
	_sprite.scale = Vector2.ONE * size * 1.35
	_spin = randf_range(-2.5, 2.5)
	add_child(_sprite)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	if not _landed:
		_t += delta
		var u: float = clampf(_t / Balance.DUNGEON_ROCK_FALL_SECONDS, 0.0, 1.0)
		var eased: float = u * u
		_sprite.position.y = lerpf(-Balance.DUNGEON_ROCK_FALL_HEIGHT, 0.0, eased)
		_sprite.scale = Vector2.ONE * size * lerpf(1.35, 1.0, eased)
		_sprite.rotation += _spin * delta
		_shadow.modulate.a = 0.15 + 0.4 * eased
		_shadow.scale = Vector2(0.12, 0.07) * size * lerpf(1.4, 2.6, eased)
		if u >= 1.0:
			_land()
		return
	_linger -= delta
	if _linger < 1.0:
		_sprite.modulate.a = maxf(_linger, 0.0)
		_shadow.modulate.a = maxf(_linger, 0.0) * 0.55
	if _linger <= 0.0:
		queue_free()


func _land() -> void:
	_landed = true
	_linger = Balance.DUNGEON_ROCK_LINGER
	_sprite.position.y = 0.0
	_sprite.scale = Vector2.ONE * size
	Vfx.dust(global_position, Color(0.5, 0.46, 0.42, 0.85), 4 + int(size * 3.0), 30.0 + 20.0 * size)
	EventBus.camera_impact.emit(global_position, power)
	Sfx.play_at("sfx_hit_stone", global_position, -9.0 + 4.0 * size)


func landed() -> bool:
	return _landed
