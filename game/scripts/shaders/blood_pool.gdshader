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

float depth_of(vec2 uv) {
	return texture(TEXTURE, uv).r * depth_range;
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
	float alpha = smoothstep(0.03, 0.2, shown) * alpha_max;
	if (alpha <= 0.001) {
		discard;
	}
	vec3 base = mix(dry_colour, fresh_colour, clamp(fresh, 0.0, 1.0));
	// Deeper is darker, as a pool is.
	base *= mix(1.0, 0.62, smoothstep(0.1, 1.2, depth));
	// Wet: a highlight off the pool's own slope, and a slow sheen.
	vec2 px = TEXTURE_PIXEL_SIZE;
	float dx = depth_of(UV + vec2(px.x, 0.0)) - depth_of(UV - vec2(px.x, 0.0));
	float dy = depth_of(UV + vec2(0.0, px.y)) - depth_of(UV - vec2(0.0, px.y));
	vec3 normal = normalize(vec3(-dx * 2.5, -dy * 2.5, 1.0));
	vec3 light = normalize(vec3(-0.45, -0.7, 0.55));
	vec3 half_v = normalize(light + vec3(0.0, 0.0, 1.0));
	float gloss = pow(max(dot(normal, half_v), 0.0), 36.0) * fresh * smoothstep(0.05, 0.3, depth);
	float sheen = 0.05 * fresh * smoothstep(0.08, 0.4, depth)
		* (0.5 + 0.5 * sin(TIME * 1.3 + UV.x * 140.0 + UV.y * 95.0));
	COLOR = vec4(base + vec3(0.9, 0.55, 0.5) * gloss * 0.55 + vec3(sheen), alpha);
}
