class_name ActorPolish
extends RefCounted

## Shared four-sample silhouette and directional impact rim for sprites that do
## not already own the combined BloodStain material.

const SHADER_PATH: String = "res://scripts/shaders/actor_polish.gdshader"
static var _shader: Shader = null


static func attach(sprite: CanvasItem) -> ShaderMaterial:
	if sprite == null or sprite.material != null or not Graphics.polish_shaders():
		return null
	if _shader == null and ResourceLoader.exists(SHADER_PATH):
		_shader = load(SHADER_PATH) as Shader
	if _shader == null:
		return null
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("outline_colour", Balance.ACTOR_OUTLINE_COLOUR)
	material.set_shader_parameter("outline_strength", Balance.ACTOR_OUTLINE_STRENGTH)
	material.set_shader_parameter("impact_colour", Balance.IMPACT_RIM_COLOUR)
	material.set_shader_parameter("impact_strength", 0.0)
	sprite.material = material
	return material


static func strike(material: ShaderMaterial, direction: Vector2) -> void:
	if material == null:
		return
	var aim: Vector2 = direction.normalized() if direction.length() > 0.001 else Vector2.UP
	material.set_shader_parameter("impact_direction", aim)
	material.set_shader_parameter("impact_strength", Balance.IMPACT_RIM_STRENGTH)


static func drive(material: ShaderMaterial, left: float) -> void:
	if material != null:
		material.set_shader_parameter("impact_strength",
			clampf(left / maxf(Balance.HIT_FLASH_TIME, 0.001), 0.0, 1.0)
			* Balance.IMPACT_RIM_STRENGTH)
