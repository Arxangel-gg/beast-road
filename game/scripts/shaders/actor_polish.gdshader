shader_type canvas_item;

uniform vec4 outline_colour : source_color = vec4(0.035, 0.045, 0.05, 0.94);
uniform float outline_strength : hint_range(0.0, 1.0) = 0.82;
uniform vec4 impact_colour : source_color = vec4(1.0, 0.82, 0.62, 1.0);
uniform vec2 impact_direction = vec2(0.0, -1.0);
uniform float impact_strength : hint_range(0.0, 1.0) = 0.0;

// --- Promoted aura -----------------------------------------------------------
//
// A living band of light around an elite or champion, instead of the flat
// coloured line they wore before. The band is the silhouette widened by a ring
// of samples and then *eaten into* by flowing noise, so it licks and breathes
// rather than sitting there - which is the whole difference between a body that
// looks dangerous and a body with a border.
//
// Zero for everything else, and guarded, so an ordinary walker pays for none of
// the noise. There are a lot of ordinary walkers.
uniform float aura_strength : hint_range(0.0, 2.0) = 0.0;
uniform vec4 aura_colour : source_color = vec4(1.0, 0.78, 0.35, 1.0);
uniform float aura_speed = 1.1;
uniform float aura_scale = 7.0;
// How far the glow reaches past the silhouette, in source pixels.
uniform float aura_width = 3.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Value noise: cheap, and smooth enough that the band reads as flame rather
// than as static.
float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Two octaves drifting at different speeds. One octave pulses uniformly and
// reads as a throb; two moving against each other read as motion.
float aura_noise(vec2 uv) {
	float t = TIME * aura_speed;
	float low = value_noise(uv * aura_scale + vec2(0.0, -t));
	float high = value_noise(uv * aura_scale * 2.3 + vec2(t * 0.7, -t * 1.6));
	return low * 0.65 + high * 0.35;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 source = COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float left_a = texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
	float right_a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	float up_a = texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float down_a = texture(TEXTURE, UV + vec2(0.0, px.y)).a;
	float around = max(max(left_a, right_a), max(up_a, down_a));
	float outline = max(around - tex.a, 0.0) * outline_strength;
	vec2 gradient = vec2(left_a - right_a, up_a - down_a);
	float edge = length(gradient) > 0.001
		? max(dot(normalize(gradient), normalize(impact_direction)), 0.0) : 0.0;
	vec3 body = mix(source.rgb, impact_colour.rgb,
		edge * impact_strength * impact_colour.a * source.a);
	vec4 composed = vec4(body, source.a);
	vec4 rim = vec4(outline_colour.rgb, outline * outline_colour.a);
	vec4 painted = mix(rim, composed, composed.a);

	if (aura_strength > 0.001) {
		// The silhouette widened by a diagonal ring as well as the cardinals -
		// four samples alone leave visible corners on a diagonal edge, which on
		// a glow reads as a sprite with notches cut out of it.
		vec2 w = px * aura_width;
		float far_a = max(
			max(texture(TEXTURE, UV - vec2(w.x, 0.0)).a,
				texture(TEXTURE, UV + vec2(w.x, 0.0)).a),
			max(texture(TEXTURE, UV - vec2(0.0, w.y)).a,
				texture(TEXTURE, UV + vec2(0.0, w.y)).a));
		vec2 d = w * 0.7071;
		far_a = max(far_a, max(
			max(texture(TEXTURE, UV - d).a, texture(TEXTURE, UV + d).a),
			max(texture(TEXTURE, UV + vec2(d.x, -d.y)).a,
				texture(TEXTURE, UV + vec2(-d.x, d.y)).a)));

		// The band outside the body, faded by how far out it sits so the glow
		// falls off instead of ending on a hard line.
		float band = max(far_a - tex.a, 0.0);
		float falloff = mix(1.0, 0.55, clamp((band - outline) * 0.9, 0.0, 1.0));
		float flame = aura_noise(UV);
		// Eaten into rather than merely brightened: subtracting the noise makes
		// the edge ragged and moving, which is what licks.
		// Contrast on the noise, not just amplitude: a band that merely
		// brightens reads as a glow, while one that is cut away in places reads
		// as flame. `smoothstep` is what turns the second into the first.
		float bite = smoothstep(0.18, 0.85, flame);
		float lick = clamp(band * (bite * 1.9 + 0.22), 0.0, 1.0) * falloff;
		float glow = lick * aura_strength * aura_colour.a * (1.0 - tex.a);
		painted = mix(painted, vec4(aura_colour.rgb, 1.0),
			clamp(glow, 0.0, 1.0) * (1.0 - painted.a * 0.35));
		painted.a = max(painted.a, clamp(glow, 0.0, 1.0));
		// A breath through the body itself, so the whole thing feels charged
		// rather than merely edged.
		painted.rgb = mix(painted.rgb, aura_colour.rgb,
			tex.a * flame * 0.16 * aura_strength);
	}

	COLOR = painted;
}
