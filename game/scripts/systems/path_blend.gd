class_name PathBlend
extends RefCounted

## The shader that stops the roads looking like stickers.
##
## A lane is a rectangle of road texture laid over the terrain. Drawn plainly its
## edges are four hard straight lines, which reads as a decal rather than as
## ground people have worn down by walking on it.
##
## The fix is a noisy fringe: the road fades out over the outer band of its own
## width, and the *threshold* of that fade is pushed around by noise, so the
## boundary wanders instead of running straight. The centre strip is deliberately
## left untouched — noise across the whole road makes the road itself look dirty
## and hurts readability, and the road is where the player needs to track enemies.
##
## Ends are faded too. The road should dissolve into the distance at the spawn
## point rather than stopping at a visible line.

const CODE: String = """
shader_type canvas_item;

// Width of the soft fringe as a fraction of the road's half-width.
uniform float edge_fade : hint_range(0.0, 1.0) = 0.35;
// How hard the fringe is broken up. 0 is a clean linear fade.
uniform float edge_noise : hint_range(0.0, 1.0) = 0.55;
// Feature size of the fringe noise, in UV space along the road.
uniform float noise_scale = 18.0;
// Fraction of each end given over to fading out.
uniform float end_fade : hint_range(0.0, 0.5) = 0.12;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Distance from the road's centre line, 0 in the middle, 1 at either edge.
	float across = abs(UV.y - 0.5) * 2.0;

	// Two octaves so the boundary has both a wander and a crumble.
	float n = value_noise(vec2(UV.x * noise_scale, UV.y * noise_scale * 0.35));
	n += value_noise(vec2(UV.x * noise_scale * 2.7, UV.y * noise_scale)) * 0.5;
	n /= 1.5;

	// The noise moves where the fade *starts*, not how opaque the road is, so
	// the centre stays perfectly clean and only the boundary wanders.
	float start = 1.0 - edge_fade + (n - 0.5) * edge_noise * edge_fade;
	float sides = 1.0 - smoothstep(start, 1.0, across);

	// Fade both ends of the strip as well, with the same noise so the corners
	// do not look machined.
	float along = min(UV.x, 1.0 - UV.x) / max(end_fade, 0.001);
	float ends = smoothstep(0.0, 1.0, along);

	COLOR = vec4(tex.rgb, tex.a * sides * ends * COLOR.a);
}
"""

static var _shader: Shader = null


static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE
	return _shader


## A material configured from Balance. One per strip, because each carries its
## own noise offset — sharing a material would make all four lanes identical.
static func material_for(lane: int, road_half_width: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader()
	# Expressed as a fraction of the half-width so tuning the road width does
	# not silently change how wide the fringe looks.
	material.set_shader_parameter("edge_fade",
		clampf(Balance.PATH_EDGE_FADE / maxf(road_half_width, 1.0), 0.05, 0.9))
	material.set_shader_parameter("edge_noise", Balance.PATH_EDGE_NOISE)
	# Rotating the scale slightly per lane stops the four roads sharing an
	# identical silhouette, which is very visible on a symmetric map.
	material.set_shader_parameter("noise_scale",
		Balance.PATH_NOISE_SCALE * (1.0 + float(lane) * 0.13))
	material.set_shader_parameter("end_fade", Balance.PATH_END_FADE)
	return material
