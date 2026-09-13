class_name CampFire
extends Sprite2D

## A fire that burns: the authored flame frames beside `camp_fire.png` on
## the structure-idle convention, and a warm light under it that breathes
## (owner brief, 2026-09-12: "fireplaces at camps should be animated and
## have lighting"). One node, so the camps and the raid's dressing light
## their fires the same way.

var _frames: Array[Texture2D] = []
var _clock: float = 0.0
var _glow: Sprite2D = null
var _light: PointLight2D = null
var _seed: float = 0.0


func _ready() -> void:
	if texture != null and texture.resource_path != "":
		_frames = GameData.load_idle_frames(texture.resource_path)
	_seed = randf() * TAU
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.texture = LightKit.falloff_texture()
	_glow.modulate = Balance.CAMP_FIRE_LIGHT
	_glow.scale = Vector2.ONE * (Balance.CAMP_FIRE_LIGHT_RADIUS
		/ maxf(float(LightKit.falloff_texture().get_width()), 1.0)) / maxf(scale.x, 0.01)
	_glow.position = Vector2(0.0, -6.0)
	_glow.z_index = -1
	_glow.z_as_relative = true
	add_child(_glow)
	_light = LightKit.add_light(self, Color(1.0, 0.62, 0.3), Balance.CAMP_FIRE_LIGHT_RADIUS * 1.4,
		0.9, 0.35)


func _process(delta: float) -> void:
	_clock += delta
	var flicker: float = 0.86 + 0.14 * sin(_clock * 9.0 + _seed) * sin(_clock * 3.7 + _seed * 0.5)
	if _glow != null:
		_glow.modulate.a = Balance.CAMP_FIRE_LIGHT.a * flicker
		_glow.scale = Vector2.ONE * (Balance.CAMP_FIRE_LIGHT_RADIUS
			/ maxf(float(LightKit.falloff_texture().get_width()), 1.0)) / maxf(scale.x, 0.01) \
			* (0.94 + 0.06 * flicker)
	if _light != null:
		_light.energy = 0.9 * flicker
	if _frames.is_empty():
		return
	var index: int = int(floor(_clock * Balance.CAMP_FIRE_FRAME_RATE)) % _frames.size()
	texture = _frames[index]
