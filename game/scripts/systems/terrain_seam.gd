class_name TerrainSeam
extends RefCounted

## Samples a repeating terrain from texel centres. Linear filtering otherwise
## reaches across a repeat boundary at exact tile edges and can expose a thin
## one-pixel grid even when the authored opposite edges match. This is a single
## texture sample, so it keeps the original painting, contrast and colour intact.

const SHADER_CODE: String = """
shader_type canvas_item;

void fragment() {
	vec2 tile_uv = fract(UV);
	vec2 half_texel = TEXTURE_PIXEL_SIZE * 0.5;
	vec2 safe_uv = mix(half_texel, vec2(1.0) - half_texel, tile_uv);
	COLOR = texture(TEXTURE, safe_uv) * COLOR;
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
