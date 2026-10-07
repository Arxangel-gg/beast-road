shader_type canvas_item;

// Fire, ice and the wind-up tell, shared with `actor_polish`. Every enemy that
// has not been promoted wears this material rather than that one, so the state a
// player reads off a body has to live in both - see the include's header.
#include "res://scripts/shaders/actor_state.gdshaderinc"
#include "res://scripts/shaders/warden_look.gdshaderinc"
#include "res://scripts/shaders/actor_shade.gdshaderinc"
#include "res://scripts/shaders/wade_stain.gdshaderinc"

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
// How many texels out the rim reaches: one, as painted, unless the cursor lights
// the body (`ClickMove._light`).
uniform float outline_width : hint_range(1.0, 4.0) = 1.0;
// A breed variant's coat (2026-10-07): the same three numbers, and the same
// names, `actor_polish` wears for a wild animal's coat, so one door dresses
// either material. Zero is the painting.
uniform float coat_hue = 0.0;
uniform float coat_saturation = 0.0;
uniform float coat_light = 0.0;
uniform vec4 impact_colour : source_color = vec4(1.0, 0.82, 0.62, 1.0);
uniform vec2 impact_direction = vec2(0.0, -1.0);
uniform float impact_strength : hint_range(0.0, 1.0) = 0.0;
// **Where the blows landed** (2026-10-01): the last few wounds, each a texel of
// the body's own cell (x, y), how far the stain gathers round it (z) and how
// fresh it is (w); and where the current cell starts on the texture, so a
// wound stays on the body as a sheet steps through its frames.
uniform vec4 wounds[4];
uniform vec2 cell_origin = vec2(0.0);
// How thin the stain runs away from every wound, once there is one.
uniform float wound_elsewhere = 0.35;

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
	// **A wider rim when asked** (2026-10-07): the hover's gold one texel wide
	// read as a hairline at play zoom. Only a lit body pays the eight reads -
	// the four at the width and the four diagonals that close its corners.
	if (outline_width > 1.01) {
		vec2 wide = px * outline_width;
		around = max(around, max(
			max(texture(TEXTURE, UV - vec2(wide.x, 0.0)).a, texture(TEXTURE, UV + vec2(wide.x, 0.0)).a),
			max(texture(TEXTURE, UV - vec2(0.0, wide.y)).a, texture(TEXTURE, UV + vec2(0.0, wide.y)).a)));
		around = max(around, max(
			max(texture(TEXTURE, UV + px).a, texture(TEXTURE, UV - px).a),
			max(texture(TEXTURE, UV + vec2(px.x, -px.y)).a, texture(TEXTURE, UV + vec2(-px.x, px.y)).a)));
	}
	float outline = max(around - COLOR.a, 0.0) * outline_strength;
	if (COLOR.a <= 0.001 && outline > 0.001) {
		COLOR = vec4(outline_colour.rgb, outline * outline_colour.a);
	}
	// The Warden's dye, on the body and before anything that happens to it -
	// a rim, a burn, a stain - so those read over the dyed cloth as they read
	// over the painted cloth. A body with no dye is untouched in one branch.
	if (COLOR.a > 0.001) {
		COLOR.rgb = warden_look(COLOR.rgb, texture(TEXTURE, UV).rgb, UV);
	}
	// The variant's coat, before anything that happens to the body.
	if (COLOR.a > 0.001 && (abs(coat_hue) > 0.0005 || abs(coat_saturation) > 0.0005
			|| abs(coat_light) > 0.0005)) {
		vec3 coat = look_to_hsv(COLOR.rgb);
		coat.x = fract(coat.x + coat_hue);
		coat.y = clamp(coat.y * (1.0 + coat_saturation), 0.0, 1.0);
		coat.z = clamp(coat.z * (1.0 + coat_light), 0.0, 1.0);
		COLOR.rgb = look_to_rgb(coat);
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
	// The wounds first: how near this texel is to where a blow landed, and how
	// fresh the nearest is. With any wound kept, the health's stain gathers
	// round them and thins elsewhere; each wound also bleeds a spot of its own.
	vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
	vec2 in_cell = texel - cell_origin;
	float near_wound = 0.0;
	float fresh = 0.0;
	float any_wound = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 w = wounds[i];
		if (w.w <= 0.0) {
			continue;
		}
		any_wound = 1.0;
		float reach = 1.0 - smoothstep(w.z * 0.3, max(w.z, 1.0), distance(in_cell, w.xy));
		near_wound = max(near_wound, reach);
		fresh = max(fresh, reach * w.w);
	}
	float weight = mix(1.0, wound_elsewhere + 1.4 * near_wound, any_wound);
	float bled = clamp(stain * weight + fresh * 0.6, 0.0, 1.0);
	if (bled > 0.001) {
		// Texel coordinates, not UV, so the speckle lands on the art's own
		// pixels and stays crisp at every zoom.
		// Broad and mid-frequency fields form readable clots rather than isolated
		// one-pixel confetti. Taking the strongest immediate neighbour thickens
		// those clots while the fine field keeps their edges scattered.
		float threshold = 0.82 - bled * 0.76;
		float n = stain_field(texel);
		n = max(n, stain_field(texel + vec2(1.0, 0.0)) - 0.035);
		n = max(n, stain_field(texel + vec2(0.0, 1.0)) - 0.035);
		float mask = step(threshold, n);
		// Multiplied by alpha so nothing stains the empty space around the
		// silhouette - blood belongs on the character, not in its bounding box.
		COLOR.rgb = mix(COLOR.rgb, blood_colour, mask * 0.88 * COLOR.a);
	}
	// What it waded through, up to the height it waded.
	if (body_a > 0.001) {
		COLOR.rgb = wade_blood(COLOR.rgb, body_a, in_cell);
	}
	// The body turned to the light (2026-09-25): the same relief towers read,
	// off the painting rather than off the stained, dyed colour above.
	vec4 shade_texel = texture(TEXTURE, UV);
	SHADE_NORMAL(shade_texel, UV, px)
	// Over everything, including the outline this shader may have written into
	// a transparent texel: the tell is what has to survive.
	STATE_APPLY_TELEGRAPH(COLOR, UV, px, body_a)
	// Last, so a dissolving body takes its outline and its wounds with it.
	COLOR = state_dissolve(COLOR, UV, px);
}
