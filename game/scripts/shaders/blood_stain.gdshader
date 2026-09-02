shader_type canvas_item;

// Fire, ice and the wind-up tell, shared with `actor_polish`. Every enemy that
// has not been promoted wears this material rather than that one, so the state a
// player reads off a body has to live in both - see the include's header.
#include "res://scripts/shaders/actor_state.gdshaderinc"

// Blood on a character, as speckle rather than tint.
//
// A flat red wash over a wounded sprite reads as a status effect. What reads as
// blood is *some of the pixels* being blood and the rest not - so this stains
// individual texels, chosen by a hash of their own coordinates. The choice is
// stable: the same texels stain every frame, and raising `stain` adds more
// rather than reshuffling which, so a hero bleeds progressively instead of
// shimmering.
//
// `COLOR` arrives already multiplied by the node's modulate, so editing it in
// place preserves the party tint underneath. Writing a fresh value from
// `TEXTURE` would throw that away, and four Wardens would stop being four
// colours. (`MODULATE` is not available in this stage in 4.7.1 - checked.)

uniform float stain : hint_range(0.0, 1.0) = 0.0;
uniform vec3 blood_colour : source_color = vec3(0.42, 0.05, 0.06);
uniform float seed = 0.0;
uniform float cluster_pixels : hint_range(2.0, 6.0) = 3.4;
uniform float fine_scatter : hint_range(0.0, 0.5) = 0.24;
uniform vec4 outline_colour : source_color = vec4(0.035, 0.045, 0.05, 0.94);
uniform float outline_strength : hint_range(0.0, 1.0) = 0.82;
uniform vec4 impact_colour : source_color = vec4(1.0, 0.82, 0.62, 1.0);
uniform vec2 impact_direction = vec2(0.0, -1.0);
uniform float impact_strength : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float stain_field(vec2 texel) {
	vec2 shifted = texel + vec2(seed * 0.37, seed * 0.61);
	float broad = hash(floor(shifted / cluster_pixels));
	float medium = hash(floor((shifted + vec2(1.7, -2.3)) / 2.0));
	float fine = hash(shifted + vec2(seed));
	return broad * (0.62 - fine_scatter * 0.25)
		+ medium * (0.38 - fine_scatter * 0.75) + fine * fine_scatter;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float left_a = texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
	float right_a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	float up_a = texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float down_a = texture(TEXTURE, UV + vec2(0.0, px.y)).a;
	float around = max(max(left_a, right_a), max(up_a, down_a));
	float outline = max(around - COLOR.a, 0.0) * outline_strength;
	if (COLOR.a <= 0.001 && outline > 0.001) {
		COLOR = vec4(outline_colour.rgb, outline * outline_colour.a);
	}
	vec2 gradient = vec2(left_a - right_a, up_a - down_a);
	if (COLOR.a > 0.001 && length(gradient) > 0.001 && impact_strength > 0.001) {
		float rim = max(dot(normalize(gradient), normalize(impact_direction)), 0.0);
		COLOR.rgb = mix(COLOR.rgb, impact_colour.rgb,
			rim * impact_strength * impact_colour.a);
	}
	// Fire and ice before blood, so a burning enemy's embers sit under its
	// wounds rather than over them. Blood is the newest thing to have happened
	// to the body and reads as the top layer; fire is a condition it is in.
	//
	// **Weighted by the sprite's own alpha, not by `COLOR.a`.** By this point
	// `COLOR` has been overwritten with the outline on every transparent texel,
	// so its alpha is no longer "how much body is here" - and passing it would
	// set the *rim* alight. `actor_polish` reaches this with `COLOR` still the
	// sprite, so it never could, and a promoted body would have burned
	// differently at its edges from an ordinary one for no reason anybody could
	// have found later.
	float body_a = texture(TEXTURE, UV).a;
	if (body_a > 0.001 && (burn > 0.001 || frost > 0.001)) {
		float near = min(min(left_a, right_a), min(up_a, down_a));
		COLOR.rgb = state_body(COLOR.rgb, UV, px, body_a, near);
	}
	if (body_a > 0.001) {
		COLOR.rgb = state_shine(COLOR.rgb, UV, px, body_a);
	}
	if (stain > 0.001) {
		// Texel coordinates, not UV, so the speckle lands on the art's own
		// pixels and stays crisp at every zoom.
		vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
		// Broad and mid-frequency fields form readable clots rather than isolated
		// one-pixel confetti. Taking the strongest immediate neighbour thickens
		// those clots while the fine field keeps their edges scattered.
		float threshold = 0.82 - stain * 0.76;
		float n = stain_field(texel);
		n = max(n, stain_field(texel + vec2(1.0, 0.0)) - 0.035);
		n = max(n, stain_field(texel + vec2(0.0, 1.0)) - 0.035);
		float mask = step(threshold, n);
		// Multiplied by alpha so nothing stains the empty space around the
		// silhouette - blood belongs on the character, not in its bounding box.
		COLOR.rgb = mix(COLOR.rgb, blood_colour, mask * 0.88 * COLOR.a);
	}
	// Over everything, including the outline this shader may have written into
	// a transparent texel: the tell is what has to survive.
	STATE_APPLY_TELEGRAPH(COLOR, UV, px, body_a)
	// Last, so a dissolving body takes its outline and its wounds with it.
	COLOR = state_dissolve(COLOR, UV, px);
}
