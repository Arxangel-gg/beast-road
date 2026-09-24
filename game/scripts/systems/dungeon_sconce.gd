class_name DungeonSconce
extends Node2D

## A torch in an iron bracket on a rift's wall (2026-09-14).
##
## The deep is dark - `DayNight.set_underground` sees to that - and dark with
## nothing lit in it is a flat disc of vision on black. A sconce every few
## tiles of wall gives the maze its light: a warm pool on the floor under each
## one, a `Flame` that dances in the bracket, and on every
## `DUNGEON_SCONCE_LIGHT_EVERY`-th a real `PointLight2D`, for the same reason
## only every second lane torch carries one - a light re-draws everything
## under it.
##
## The origin is the foot of the wall under the bracket, on the floor's edge,
## so the sconce y-sorts behind a body walking the corridor beneath it. A rift's
## brackets burn violet; nothing about them is read.

const ART: String = "res://art/raid/dungeon_sconce.png"
## Where the torch head sits in the bracket art, from its centre, in its own
## pixels.
const HEAD: Vector2 = Vector2(8.0, -28.0)

var colour: Color = Balance.DUNGEON_SCONCE_COLOUR
var carries_light: bool = false

var _flame: Flame = null
var _pool: Sprite2D = null
var _clock: float = 0.0
var _seed: float = 0.0


func _ready() -> void:
	_seed = randf() * TAU
	var scale_by: float = Balance.DUNGEON_SCONCE_SCALE
	var bracket := Sprite2D.new()
	bracket.name = "Bracket"
	var height: float = 80.0
	if ResourceLoader.exists(ART):
		bracket.texture = load(ART)
		height = float(bracket.texture.get_height())
	bracket.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	bracket.add_to_group(Graphics.FILTER_GROUP)
	bracket.scale = Vector2.ONE * scale_by
	# Hung on the face above the floor: its foot a little onto the floor's edge.
	bracket.position = Vector2(0.0, -height * scale_by * 0.5 + 4.0)
	add_child(bracket)

	_pool = Sprite2D.new()
	_pool.name = "Pool"
	_pool.texture = LightKit.falloff_texture()
	var additive: CanvasItemMaterial = LightKit.additive_material()
	_pool.material = additive
	var span: float = Balance.DUNGEON_SCONCE_POOL_RADIUS * 2.0 \
		/ maxf(float(_pool.texture.get_width()), 1.0)
	_pool.scale = Vector2(span, span * 0.55)
	_pool.position = Vector2(0.0, 10.0)
	_pool.modulate = Color(colour, Balance.DUNGEON_SCONCE_POOL_ALPHA)
	_pool.z_index = -2
	_pool.z_as_relative = true
	add_child(_pool)

	_flame = Flame.new()
	_flame.name = "Fire"
	_flame.position = bracket.position + HEAD * scale_by
	add_child(_flame)
	_flame.configure(Balance.DUNGEON_SCONCE_FLAME_SIZE,
		Balance.DUNGEON_SCONCE_LIGHT_RADIUS if carries_light else 0.0,
		colour, Balance.DUNGEON_SCONCE_LIGHT_ENERGY, false)
	# The flame's own body is the torch orange; a rift's is turned toward its
	# bracket's colour, which is the one place the two kinds differ.
	_flame.modulate = Color.WHITE.lerp(colour, 0.6) if colour != Balance.DUNGEON_SCONCE_COLOUR \
		else Color.WHITE


func _process(delta: float) -> void:
	_clock += delta
	if _pool == null:
		return
	var flicker: float = 0.86 + 0.14 * sin(_clock * 9.0 + _seed) * sin(_clock * 3.7 + _seed * 0.5)
	_pool.modulate.a = Balance.DUNGEON_SCONCE_POOL_ALPHA * flicker


func light() -> PointLight2D:
	return _flame.light() if _flame != null else null
