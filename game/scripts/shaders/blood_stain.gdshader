shader_type canvas_item;

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
uniform vec4 outline_colour : source_color = vec4(0.035, 0.045, 0.05, 0.94);
uniform float outline_strength : hint_range(0.0, 1.0) = 0.82;
uniform vec4 impact_colour : source_color = vec4(1.0, 0.82, 0.62, 1.0);
uniform vec2 impact_direction = vec2(0.0, -1.0);
uniform float impact_strength : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
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
	if (stain > 0.001) {
		// Texel coordinates, not UV, so the speckle lands on the art's own
		// pixels and stays crisp at every zoom.
		vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
		float n = hash(texel + vec2(seed));
		float mask = step(1.0 - stain, n);
		// Multiplied by alpha so nothing stains the empty space around the
		// silhouette - blood belongs on the character, not in its bounding box.
		COLOR.rgb = mix(COLOR.rgb, blood_colour, mask * 0.88 * COLOR.a);
	}
}
