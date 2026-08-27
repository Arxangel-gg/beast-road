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

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
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
