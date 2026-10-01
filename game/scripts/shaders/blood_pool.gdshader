shader_type canvas_item;

// **Pools of blood** (owner, 2026-10-01, Brutal blood). The texture is the pool
// sheet `BloodPools` keeps: depth in red, freshness in green, a texel a cell,
// filtered smooth so nothing shows the square.
//
// Fresh blood is red and wet - glossy where it is deep, a slow sheen moving on
// it - and old blood is dark and dull. Thin fresh blood gathers in the dents of
// the scarred ground first (the depth map `GroundScars` keeps), and only until
// it is deep enough to cover them; dried blood does not move into anything.

uniform vec3 fresh_colour : source_color = vec3(0.48, 0.06, 0.07);
uniform vec3 dry_colour : source_color = vec3(0.24, 0.07, 0.08);
uniform float depth_range = 2.0;
uniform float alpha_max = 0.9;
uniform sampler2D scars : filter_linear;
uniform float scar_enabled = 0.0;
uniform float scar_extent = 1.0;
uniform float pool_extent = 1.0;

// Value noise for the pool's edge: blood has an irregular meniscus, not the
// round edge of a filtered texel.
float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec4 sheet = texture(TEXTURE, UV);
	float depth = sheet.r * depth_range;
	float fresh = sheet.g;
	// The ground under it: positive in a dent. The two sheets are centred on
	// the field and may differ in reach, so a pool texel is mapped onto the
	// scars' own.
	float dent = 0.0;
	if (scar_enabled > 0.5) {
		vec2 world = (UV * 2.0 - 1.0) * pool_extent;
		vec2 scar_uv = world / (2.0 * scar_extent) + 0.5;
		dent = max(-(texture(scars, scar_uv).r * 2.0 - 1.0), 0.0);
	}
	// Thin, fresh blood runs into the dents; deep or dry blood does not care.
	float conform = fresh * (1.0 - smoothstep(0.06, 0.4, depth));
	float shown = depth + dent * conform * 0.35;
	// An irregular meniscus: the edge wanders by a little noise, then is cut
	// sharply - blood stands on the ground, it does not fade into it.
	vec2 grain_uv = UV / TEXTURE_PIXEL_SIZE;
	shown += (value_noise(grain_uv * 1.7) - 0.5) * 0.09 + (value_noise(grain_uv * 5.3) - 0.5) * 0.03;
	float alpha = smoothstep(0.07, 0.11, shown) * alpha_max;
	if (alpha <= 0.001) {
		discard;
	}
	// A darker rim where the meniscus thins, as dried blood rings a pool.
	float rim = smoothstep(0.07, 0.11, shown) - smoothstep(0.11, 0.2, shown);
	vec3 base = mix(dry_colour, fresh_colour, clamp(fresh, 0.0, 1.0));
	// Deeper is darker, as a pool is, and the rim darker again.
	base *= mix(1.0, 0.5, smoothstep(0.1, 1.2, depth));
	base *= 1.0 - rim * 0.35;
	// Wet: a highlight off the pool's own slope, and a slow sheen.
	vec2 px = TEXTURE_PIXEL_SIZE;
	// Inline, not a helper: TEXTURE is not reachable from a function of ours.
	float dx = (texture(TEXTURE, UV + vec2(px.x, 0.0)).r - texture(TEXTURE, UV - vec2(px.x, 0.0)).r) * depth_range;
	float dy = (texture(TEXTURE, UV + vec2(0.0, px.y)).r - texture(TEXTURE, UV - vec2(0.0, px.y)).r) * depth_range;
	vec3 normal = normalize(vec3(-dx * 2.5, -dy * 2.5, 1.0));
	vec3 light = normalize(vec3(-0.45, -0.7, 0.55));
	vec3 half_v = normalize(light + vec3(0.0, 0.0, 1.0));
	float wet = fresh * smoothstep(0.08, 0.35, depth);
	float gloss = pow(max(dot(normal, half_v), 0.0), 28.0) * wet;
	// The sky in it: a pale streak where the surface faces the light, moving
	// slowly with the ripple a still pool still has.
	float ripple = value_noise(grain_uv * 0.9 + vec2(TIME * 0.12, TIME * 0.07));
	float sky = smoothstep(0.62, 0.95, dot(normal, normalize(vec3(-0.3, -0.85, 0.45))) + ripple * 0.18) * wet;
	COLOR = vec4(base + vec3(1.0, 0.72, 0.68) * gloss * 0.9 + vec3(0.42, 0.3, 0.3) * sky * 0.35, alpha);
}
