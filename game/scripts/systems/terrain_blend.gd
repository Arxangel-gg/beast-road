class_name TerrainBlend
extends RefCounted

## De-tiles the authored terrain without blurring it. The source paintings are
## seamless at their outer edge, but each contains broad value changes near its
## own halfway lines; a conventional repeat aligns those changes into a giant
## cross over the battlefield. Four sharp, phase-shifted samples distribute
## that composition into organic mottling so no tile or quadrant owns a line.

const SHADER_CODE: String = """
shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	vec4 a = texture(TEXTURE, uv);
	vec4 b = texture(TEXTURE, vec2(uv.y, -uv.x) + vec2(0.371, 0.613));
	vec4 c = texture(TEXTURE, vec2(-uv.x, uv.y) + vec2(0.727, 0.193));
	vec4 d = texture(TEXTURE, vec2(-uv.y, uv.x) + vec2(0.149, 0.839));
	// Unequal weights avoid a visibly symmetrical average. Every sample remains
	// sharp; this is compositional de-tiling, not a blur pass.
	COLOR = (a * 0.31 + b * 0.27 + c * 0.23 + d * 0.19) * COLOR;
}
"""

static var _material: ShaderMaterial = null


static func material() -> ShaderMaterial:
	if _material != null:
		return _material
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	return _material
