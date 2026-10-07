class_name PathBlend
extends RefCounted

## Regional material and weather polish for the battlefield's baked road mask.
##
## Roads used to be four rectangular strips, so the old material also had to
## hide their edges. They are now composited into one transparent pixel-art
## mask in `Battlefield._build_lanes()`: the alpha already owns every bend, fork
## and shoulder. One seamless regional painting is mapped through that mask in
## canvas space, then the optional wet sheen is added in the same pass.
##
## **The road fades into the ground again** (owner, 2026-10-07: *"Fix the path
## to ground transition to restore the smooth fade it had again"*). The strips
## faded their last `PATH_EDGE_FADE` units into the terrain with a threshold
## the noise pushed about, so the edge wandered like worn ground. The baked
## mask replaced the strips and its edge became the path tiles' own alpha,
## which is binary - every shoulder was a staircase of three-texel steps cut
## out of the ground, and `PATH_EDGE_FADE` was left on the unread list.
##
## The mask is read a second time, as a soft field: one deep inside the road, a
## half on the painted edge, nothing a fringe outside. **A copy of it, a
## quarter the size and mipmapped** - the first cut read the very texture the
## sprite draws, and the Compatibility renderer keeps one filter per texture,
## so the nearest the road is drawn with won and the field read as hard as the
## mask. Nothing failed; the photograph was the same staircase.
## The fade runs across that field and the noise moves where it *starts*, never
## how opaque the interior is - the strips' rule, unchanged. One coarse read
## decides the far field first, so nearly every pixel of the screen is one tap.

const CODE: String = """
shader_type canvas_item;

uniform sampler2D surface_texture : repeat_enable, filter_nearest;
uniform vec2 surface_repeat = vec2(1.0);
uniform vec3 surface_tint = vec3(1.0);
uniform float surface_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float use_surface : hint_range(0.0, 1.0) = 0.0;
uniform float wet_strength : hint_range(0.0, 1.0) = 0.0;
// The same baked mask, a quarter the size and mipmapped, read as a soft field.
uniform sampler2D mask_soft : filter_linear_mipmap;
// How many of the mask's texels one of the soft copy's stands for.
uniform float soft_scale = 4.0;
uniform float use_fade : hint_range(0.0, 1.0) = 0.0;
// Half the fringe, in mask texels: it runs this far into the road and as far
// out over the ground.
uniform float fade_texels = 10.0;
// How hard the fringe is broken up. 0 is a clean fade.
uniform float edge_noise : hint_range(0.0, 1.0) = 0.68;
// Feature size of the fringe noise, in mask texels.
uniform float noise_texels = 37.0;

float road_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float road_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(road_hash(i), road_hash(i + vec2(1.0, 0.0)), u.x),
		mix(road_hash(i + vec2(0.0, 1.0)), road_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	// The baked path art owns geometry only. One seamless regional material is
	// sampled in canvas space, so bends and junctions cannot create texture seams
	// and path detail can never spill onto the surrounding terrain.
	vec4 mask = texture(TEXTURE, UV);
	vec2 texel = UV / max(TEXTURE_PIXEL_SIZE, vec2(0.0001));
	float road_alpha = mask.a;
	vec3 mask_rgb = mask.rgb;
	if (use_fade > 0.5) {
		float reach = max(fade_texels, 1.0);
		// Far from any edge the field is all road or all ground, and one coarse
		// read says which: every pixel of open ground costs a single tap.
		float wide = textureLod(mask_soft, UV, max(log2(reach * 2.0 / soft_scale) + 0.6, 0.0)).a;
		if (wide > 0.003 && wide < 0.997) {
			float lod = max(log2(reach / soft_scale) - 1.0, 0.0);
			vec2 step = TEXTURE_PIXEL_SIZE * reach;
			vec4 sum = textureLod(mask_soft, UV, lod) * 0.2;
			for (int i = 0; i < 6; i++) {
				float a = float(i) * 1.0471976;
				sum += textureLod(mask_soft, UV + vec2(cos(a), sin(a)) * step * 0.55, lod) * 0.08;
				sum += textureLod(mask_soft, UV + vec2(cos(a + 0.5235988),
					sin(a + 0.5235988)) * step, lod) * 0.05333333;
			}
			// 0 deep inside the road, 0.5 on the painted edge, 1 a fringe out.
			float out_of_road = 1.0 - clamp(sum.a, 0.0, 1.0);
			// Two octaves, a wander and a crumble, in the mask's own texels.
			vec2 p = texel / max(noise_texels, 1.0);
			float n = (road_noise(p) + road_noise(p * 2.7 + vec2(17.3, 5.1)) * 0.5) / 1.5;
			// The noise moves where the edge falls and never how opaque the
			// inside is: the edge wanders a share of the fringe either way of the
			// painted one, and its softness is the rest of the fringe - so the
			// boundary reads as worn ground rather than as a blur, and the
			// lowest it can ever start is still out past the solid core.
			float edge = 0.5 + (n - 0.5) * edge_noise * 0.7;
			road_alpha = 1.0 - smoothstep(edge - 0.22, edge + 0.22, out_of_road);
			// Over the ground the binary mask has no colour of its own; the
			// soft field's average is the road's colour at that edge.
			if (mask.a < 0.5) {
				mask_rgb = sum.rgb / max(sum.a, 0.001);
			}
		} else {
			road_alpha = wide >= 0.997 ? 1.0 : 0.0;
		}
	}
	vec3 painted = texture(surface_texture, UV * surface_repeat).rgb;
	vec3 base = mix(mask_rgb, painted, use_surface) * surface_tint;
	vec4 source = vec4(base, road_alpha * surface_alpha);

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


## `mask` is a mipmapped copy of the baked road `soft_scale` times smaller,
## and `ppu` the baked road's texels per world unit: handed them, the road
## fades into the ground over `PATH_EDGE_FADE` world units; handed none, its
## edge is the mask's own.
static func material_for_surface(terrain_id: String = "",
		canvas_size: Vector2 = Vector2.ONE, mask: Texture2D = null,
		ppu: float = 1.0, soft_scale: float = 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader()
	material.set_shader_parameter("surface_tint", Vector3.ONE * Balance.PATH_DARKEN)
	material.set_shader_parameter("surface_alpha", Balance.PATH_TINT_ALPHA)
	if mask != null:
		material.set_shader_parameter("mask_soft", mask)
		material.set_shader_parameter("use_fade", 1.0)
		material.set_shader_parameter("soft_scale", maxf(soft_scale, 1.0))
		material.set_shader_parameter("fade_texels", Balance.PATH_EDGE_FADE * 0.5 * ppu)
		material.set_shader_parameter("edge_noise", Balance.PATH_EDGE_NOISE)
		material.set_shader_parameter("noise_texels", Balance.PATH_NOISE_SCALE * ppu)
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
