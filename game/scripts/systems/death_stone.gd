class_name DeathStone
extends Node2D

## The stone that marks where a player collapsed (owner brief, 2026-09-14).
##
## It falls from above onto the death position, lands with a restrained knock,
## a puff of dust and a settle, and stands there for as long as the player
## needs recovering. When they stand - a partner's revive, the solo clock, a
## team wipe's return - it dissolves through `stone_dissolve.gdshader` and is
## gone. A stone revived *during* its fall dissolves where it is rather than
## finishing the drop over somebody already on their feet.
##
## Presentation and nothing else: it reads the hero through `DeathMarkers`
## and is never read by anything. In the water there is no dust and no bones:
## the stone lands with a splash on the surface and the river keeps the body.

const ART: String = "res://art/vfx/death_stone.png"
const DISSOLVE_SHADER: String = "res://scripts/shaders/stone_dissolve.gdshader"
const SPLASH_ART: String = "res://art/vfx/splash.png"

var drowned: bool = false

var _sprite: Sprite2D = null
var _shadow: Sprite2D = null
var _material: ShaderMaterial = null
var _fall: Tween = null
var _landed: bool = false
var _dissolving: bool = false
var _height: float = 0.0


func _ready() -> void:
	name = "DeathStone"
	_sprite = Sprite2D.new()
	if ResourceLoader.exists(ART):
		_sprite.texture = load(ART) as Texture2D
	_sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_sprite.add_to_group(Graphics.FILTER_GROUP)
	# The node's origin is the ground the stone stands on, so it y-sorts with
	# the bodies walking round it.
	_sprite.centered = false
	_sprite.scale = Vector2.ONE * Balance.DEATH_STONE_SCALE
	if _sprite.texture != null:
		_sprite.offset = Vector2(-_sprite.texture.get_width() * 0.5,
			-float(_sprite.texture.get_height()) + 6.0)
	add_child(_sprite)
	var width: float = 40.0
	if _sprite.texture != null:
		width = float(_sprite.texture.get_width()) * 0.9 * Balance.DEATH_STONE_SCALE
	_shadow = ShadowKit.add_contact_sized(self, width, 0.0)
	_begin_fall()


## From above, accelerating, the shadow growing under it as it nears.
func _begin_fall() -> void:
	_height = Balance.DEATH_STONE_FALL_HEIGHT
	_sprite.position.y = -_height
	if _shadow != null:
		_shadow.scale *= 0.35
		_shadow.modulate.a = 0.3
	_fall = create_tween()
	_fall.set_parallel(true)
	_fall.tween_property(_sprite, "position:y", 0.0, Balance.DEATH_STONE_FALL_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _shadow != null:
		_fall.tween_property(_shadow, "scale", _shadow.scale / 0.35, Balance.DEATH_STONE_FALL_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_fall.tween_property(_shadow, "modulate:a", 1.0, Balance.DEATH_STONE_FALL_SECONDS)
	_fall.chain().tween_callback(_land)


## Down. A knock, dust or a splash, a tremor weighted by distance from the
## camera, and a settle - the squash of a heavy thing arriving.
func _land() -> void:
	_landed = true
	_fall = null
	if drowned:
		Vfx.sheet_burst(global_position, SPLASH_ART, 64.0, Color(0.9, 0.97, 1.0, 0.9))
		Sfx.play("sfx_drown", Balance.DEATH_STONE_SOUND_DB)
	else:
		Vfx.dust(global_position, Color(0.5, 0.45, 0.38), 9, 52.0)
		Sfx.play("sfx_hit_stone_1", Balance.DEATH_STONE_SOUND_DB)
	EventBus.camera_impact.emit(global_position, Balance.DEATH_STONE_IMPACT)
	var settle: Tween = create_tween()
	var stood: Vector2 = Vector2.ONE * Balance.DEATH_STONE_SCALE
	_sprite.scale = stood * Vector2(1.1, 0.88)
	settle.tween_property(_sprite, "scale", stood, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The player is up. The stone comes apart where it is - mid-air if it must -
## and frees itself when it is gone.
func dissolve() -> void:
	if _dissolving:
		return
	_dissolving = true
	if _fall != null and _fall.is_valid():
		_fall.kill()
		_fall = null
	if ResourceLoader.exists(DISSOLVE_SHADER):
		_material = ShaderMaterial.new()
		_material.shader = load(DISSOLVE_SHADER) as Shader
		_material.set_shader_parameter("progress", 0.0)
		_sprite.material = _material
	var away: Tween = create_tween()
	away.set_parallel(true)
	if _material != null:
		away.tween_method(func(value: float) -> void:
			if _material != null:
				_material.set_shader_parameter("progress", value),
			0.0, 1.0, Balance.DEATH_STONE_DISSOLVE_SECONDS)
	else:
		away.tween_property(_sprite, "modulate:a", 0.0, Balance.DEATH_STONE_DISSOLVE_SECONDS)
	if _shadow != null:
		away.tween_property(_shadow, "modulate:a", 0.0, Balance.DEATH_STONE_DISSOLVE_SECONDS)
	away.chain().tween_callback(queue_free)
	# A few grains drifting up as it goes.
	Vfx.spark(global_position + Vector2(0.0, -30.0), Color(0.72, 0.92, 0.78, 0.8), 6,
		Vector2.UP, 60.0)


func is_falling() -> bool:
	return not _landed and not _dissolving


func has_landed() -> bool:
	return _landed


func is_dissolving() -> bool:
	return _dissolving


## How far off the ground the stone is drawn right now. For the gate.
func height() -> float:
	return -_sprite.position.y if _sprite != null else 0.0
