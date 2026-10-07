shader_type canvas_item;

// **Legendary gear gleams** (owner, 2026-10-07: "Legendary gear should have
// animations and game juicy vfx"). One pass over a piece's own painting - its
// icon in the stash, the Market, the comparison card and the paper doll, and the
// weapon in the Warden's hand - and nothing else: a rim in the rarity's colour
// that breathes, a sheen that sweeps the piece diagonally, and points of light
// that twinkle on it. `tier` (0..1, `LegendaryGleam.tier`) sets how often and
// how hard, so a Runed piece glints now and then and an Unchained one burns;
// `prismatic` turns the top rung's sheen through the spectrum.
//
// Everything is read off the piece's own UV, so a weapon drawn as several
// region strips (`DressLayers`) sweeps as one picture; `seed` keeps two pieces
// from sweeping in step. Additive to the painting where the painting is, and a
// rim only where it is not: nothing is hidden and nothing is moved.

uniform vec4 rarity_colour : source_color = vec4(1.0, 0.82, 0.38, 1.0);
uniform float tier : hint_range(0.0, 1.0) = 0.5;
uniform float prismatic : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float sweep_seconds = 3.0;

varying float tint_alpha;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	tint_alpha = COLOR.a;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 painted = COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE;
	// The rim: transparent pixels beside the painting, one and two texels out.
	float near = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float far = max(max(texture(TEXTURE, UV + vec2(px.x * 2.0, 0.0)).a, texture(TEXTURE, UV - vec2(px.x * 2.0, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, px.y * 2.0)).a, texture(TEXTURE, UV - vec2(0.0, px.y * 2.0)).a));
	float rim = max(near - tex.a, 0.0) + max(far - tex.a, 0.0) * 0.4;
	float breath = 0.6 + 0.4 * sin(TIME * (1.4 + tier * 1.6) + seed * 6.2831);
	// The sheen: a narrow band crossing the piece corner to corner, then a rest.
	float across = (UV.x + (1.0 - UV.y)) * 0.5;
	float t = fract(TIME / max(sweep_seconds, 0.2) + seed);
	float band = 1.0 - smoothstep(0.0, 0.06 + tier * 0.03, abs(across - (t * 1.8 - 0.4)));
	vec3 sheen = rarity_colour.rgb;
	if (prismatic > 0.0) {
		vec3 spectrum = 0.5 + 0.5 * cos(6.2831 * (across * 1.5 + TIME * 0.25 + vec3(0.0, 0.33, 0.67)));
		sheen = mix(sheen, spectrum, prismatic);
	}
	vec3 lit = painted.rgb + sheen * band * tex.a * (0.3 + 0.7 * tier);
	// Twinkles: a few cells of the painting flare white and fade, on a clock of
	// their own, as a cross of light.
	vec2 grid = UV / (px * 3.0);
	vec2 cell = floor(grid);
	float rate = 1.5 + tier * 3.0;
	float life = fract(TIME * rate * 0.25 + hash(cell + seed));
	float era = floor(TIME * rate * 0.25 + hash(cell + seed));
	float chosen = step(1.0 - (0.02 + 0.06 * tier), hash(cell * 1.7 + era + seed * 13.0));
	vec2 local = fract(grid) - 0.5;
	float star = max(1.0 - abs(local.x) * 7.0, 0.0) * max(1.0 - abs(local.y) * 1.6, 0.0)
		+ max(1.0 - abs(local.y) * 7.0, 0.0) * max(1.0 - abs(local.x) * 1.6, 0.0);
	float twinkle = chosen * sin(life * 3.14159) * clamp(star, 0.0, 1.0) * tex.a;
	lit = mix(lit, vec3(1.0), clamp(twinkle * (0.6 + 0.4 * tier), 0.0, 1.0));
	vec4 body = vec4(lit, painted.a);
	vec4 ring = vec4(mix(rarity_colour.rgb, sheen, band), clamp(rim * (0.3 + 0.55 * tier) * breath, 0.0, 1.0) * tint_alpha);
	COLOR = mix(ring, body, body.a);
}
