class_name PathBlend
extends RefCounted

## Regional material and weather polish for the battlefield's baked road mask.
##
## Roads used to be four rectangular strips, so the old material also had to
## hide their edges. They are now composited into one transparent pixel-art
## mask in `Battlefield._build_lanes()`: the alpha already owns every bend, fork
## and shoulder. One seamless regional painting is mapped through that mask in
## canvas space, then the optional wet sheen is added in the same pass.

const CODE: String = """
shader_type canvas_item;

uniform sampler2D surface_texture : repeat_enable, filter_nearest;
uniform vec2 surface_repeat = vec2(1.0);
uniform vec3 surface_tint = vec3(1.0);
uniform float surface_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float use_surface : hint_range(0.0, 1.0) = 0.0;
uniform float wet_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// The baked path art owns geometry only. One seamless regional material is
	// sampled in canvas space, so bends and junctions cannot create texture seams
	// and path detail can never spill onto the surrounding terrain.
	vec4 mask = texture(TEXTURE, UV);
	vec3 painted = texture(surface_texture, UV * surface_repeat).rgb;
	vec3 base = mix(mask.rgb, painted, use_surface) * surface_tint;
	vec4 source = vec4(base, mask.a * surface_alpha);
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


static func material_for_surface(terrain_id: String = "",
		canvas_size: Vector2 = Vector2.ONE) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader()
	material.set_shader_parameter("surface_tint", Vector3.ONE * Balance.PATH_DARKEN)
	material.set_shader_parameter("surface_alpha", Balance.PATH_TINT_ALPHA)
	var path: String = "res://art/battlefield/road_surface_%s.png" % terrain_id
	if not terrain_id.is_empty() and ResourceLoader.exists(path):
		var texture: Texture2D = load(path) as Texture2D
		if texture != null:
			var source_size: Vector2 = texture.get_size()
			material.set_shader_parameter("surface_texture", texture)
			material.set_shader_parameter("surface_repeat", Vector2(
				canvas_size.x / maxf(source_size.x, 1.0),
				canvas_size.y / maxf(source_size.y, 1.0)))
			material.set_shader_parameter("use_surface", 1.0)
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
