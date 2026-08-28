class_name PathBlend
extends RefCounted

## Weather polish for the battlefield's baked road surface.
##
## Roads used to be four rectangular strips, so the old material also had to
## hide their edges. They are now composited into one transparent pixel-art
## surface in `Battlefield._build_lanes()`: the alpha already owns every bend,
## fork and shoulder. One material on that existing surface is both cheaper and
## more accurate than trying to reconstruct lane geometry in the shader.

const CODE: String = """
shader_type canvas_item;

uniform float wet_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// COLOR already contains the baked texture and the road's CanvasItem tint.
	// Sampling TEXTURE again would square the art and make the road go black.
	vec4 source = COLOR;
	vec2 texel = UV / max(TEXTURE_PIXEL_SIZE, vec2(0.0001));

	// Two sparse travelling bands. Their intersection glints on raised stones,
	// while dark ruts stay dark; the alpha mask confines everything to road art.
	float long_band = pow(max(sin((texel.x + texel.y) * 0.035
		- TIME * 2.1) * 0.5 + 0.5, 0.0), 14.0);
	float cross_band = pow(max(sin((texel.x - texel.y) * 0.061
		+ TIME * 1.3) * 0.5 + 0.5, 0.0), 20.0);
	float raised = 0.28 + dot(source.rgb, vec3(0.24, 0.52, 0.24));
	float wet = (long_band * 0.72 + cross_band * 0.28)
		* wet_strength * raised * source.a;
	COLOR = vec4(source.rgb + vec3(0.14, 0.21, 0.27) * wet, source.a);
}
"""

static var _shader: Shader = null
static var _materials: Array[WeakRef] = []
static var _wet: float = 0.0


static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE
	return _shader


static func material_for_surface() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader()
	material.set_shader_parameter("wet_strength", _wet)
	_materials.append(weakref(material))
	return material


static func set_weather(weather_id: String) -> void:
	_wet = Balance.PATH_WET_SHEEN if weather_id == "downpour" \
		and Graphics.polish_shaders() else 0.0
	for index: int in range(_materials.size() - 1, -1, -1):
		var material := _materials[index].get_ref() as ShaderMaterial
		if material == null:
			_materials.remove_at(index)
		else:
			material.set_shader_parameter("wet_strength", _wet)
