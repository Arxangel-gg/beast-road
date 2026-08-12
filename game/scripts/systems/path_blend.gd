class_name PathBlend
extends RefCounted

## The shader that stops the roads looking like stickers — without making them
## disappear, which is what the first version did.
##
## A lane is a rectangle of road texture laid over the terrain. Drawn plainly its
## edges are four hard straight lines, which reads as a decal rather than as
## ground people have worn down by walking on it. The fix is a noisy fringe: the
## road fades out near its edges, and the *threshold* of that fade is pushed
## around by noise, so the boundary wanders instead of running straight.
##
## The first version expressed the fringe as a fraction of the road's half-width
## and the number worked out at more than half of it. The fade therefore began
## just off the centre line, and at 55% tint on top the roads all but vanished
## from the map.
##
## So the geometry is now stated in pixels and in the right order:
##
##     |<-- core -->|<-- fade -->|
##     0          58px         88px      (distance from the centre line)
##
## Inside `core` the road is untouched: full opacity, no noise, nothing. That
## band is not decoration — it is what the player tracks enemies against, and it
## has to be solid at any tuning of the fringe. Only the strip between `core` and
## the edge fades, and only its threshold is noisy.
##
## Ends are faded too. A road should dissolve into the distance at the spawn
## point rather than stopping at a visible line.

## One detail here is worth spelling out, because getting it wrong deleted most
## of every road and looked like a tuning problem for a whole round.
##
## The strips use `region_enabled` with a region larger than the road texture, so
## the art tiles along the lane. Godot implements that by letting the vertex UVs
## run past 1: a 740x176 region on a 256x256 texture gives `UV.x` a range of
## 0..2.89 and `UV.y` a range of 0..0.69, and the sampler's repeat wrapping does
## the rest.
##
## So inside the shader `UV` is *not* 0..1 across the quad. Treating it as though
## it were put the road's centre line at 0.34 instead of 0.5, and made the "fade
## the ends" term negative everywhere past the first tile — which clamped the
## alpha to zero and cut every road off at 256px, a third of its length.
##
## `uv_scale` is that region-to-texture ratio. Divide by it for anything
## geometric; sample the texture with the raw `UV` so the tiling still happens.

const CODE: String = """
shader_type canvas_item;

// region_rect size divided by texture size. See the note above - without this
// every measurement in here is in the wrong space.
uniform vec2 uv_scale = vec2(1.0, 1.0);
// Half-width of the strip in pixels, so the shader can work in real distances
// instead of in UV and quietly change meaning when the road width is tuned.
uniform float half_width = 88.0;
// Distance from the centre line that stays completely solid.
uniform float core_radius = 58.0;
// Width of the soft fringe beyond the core.
uniform float edge_fade = 30.0;
// How hard the fringe is broken up. 0 is a clean linear fade.
uniform float edge_noise : hint_range(0.0, 1.0) = 0.75;
// Feature size of the fringe noise, in pixels along the road.
uniform float noise_scale = 62.0;
// Fraction of each end given over to fading out.
uniform float end_fade : hint_range(0.0, 0.5) = 0.10;
// Length of the strip in pixels, for square noise features.
uniform float strip_length = 740.0;

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
	// Sampled with the raw UV, which is what makes the art tile along the lane.
	vec4 tex = texture(TEXTURE, UV);

	// Everything below is geometry, so it uses the normalised 0..1 quad instead.
	vec2 quad = UV / max(uv_scale, vec2(0.0001));

	// Work in pixels from the centre line, not in normalised UV.
	float across = abs(quad.y - 0.5) * 2.0 * half_width;
	float along = quad.x * strip_length;

	// Two octaves so the boundary has both a wander and a crumble. Sampled in
	// pixel space so the features are square rather than smeared along the road.
	vec2 p = vec2(along, across) / max(noise_scale, 1.0);
	float n = value_noise(p);
	n += value_noise(p * 2.7) * 0.5;
	n /= 1.5;

	// The noise moves where the fade *starts*, never how opaque the interior is,
	// and it can only ever push the start outward from the core - so no amount of
	// noise can eat into the solid band.
	float start = core_radius + n * edge_noise * edge_fade;
	float finish = core_radius + edge_fade;
	float sides = 1.0 - smoothstep(start, max(finish, start + 1.0), across);

	// Fade both ends of the strip as well, so the corners are not machined.
	float ends = smoothstep(0.0, 1.0, min(quad.x, 1.0 - quad.x) / max(end_fade, 0.001));

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
## own noise scale — sharing a material would make all four lanes identical, and
## four identical silhouettes are very visible on a symmetric map.
static func material_for(lane: int, road_half_width: float, uv_scale: Vector2) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader()

	# The core is clamped below the half-width so a careless tune can shrink the
	# fringe to nothing but can never delete the road.
	var core: float = clampf(Balance.PATH_CORE_RADIUS, 4.0, road_half_width - 2.0)

	material.set_shader_parameter("uv_scale", uv_scale)
	material.set_shader_parameter("half_width", road_half_width)
	material.set_shader_parameter("core_radius", core)
	material.set_shader_parameter("edge_fade", maxf(Balance.PATH_EDGE_FADE, 1.0))
	material.set_shader_parameter("edge_noise", Balance.PATH_EDGE_NOISE)
	material.set_shader_parameter("noise_scale",
		Balance.PATH_NOISE_SCALE * (1.0 + float(lane) * 0.13))
	material.set_shader_parameter("end_fade", Balance.PATH_END_FADE)
	material.set_shader_parameter("strip_length",
		Balance.LANE_SPAWN_RADIUS - Balance.TOWN_RADIUS)
	return material
