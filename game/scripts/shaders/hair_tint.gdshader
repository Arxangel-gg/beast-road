shader_type canvas_item;

// A head dressing - hair or a beard - coloured at runtime (owner, 2026-09-26:
// eight hairstyles a body, beards, one face). Every style is drawn once, in
// chroma-key green, and `tools/warden_rig/heads.py` keys it out to a grey
// sheet: its light and dark, nothing else. This maps that grey onto the chosen
// colour - dark, the colour, then the colour lit - so every style comes in every
// colour without a generation more, black and white included, which a hue turn
// cannot reach. `heads.colour` is the same ramp for the pictures a style is
// judged on, so a preview and the game agree about what a colour looks like.

uniform vec4 hair_colour : source_color = vec4(0.227, 0.149, 0.102, 1.0);

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	if (art.a > 0.001) {
		float v = art.r;
		vec3 t = hair_colour.rgb;
		vec3 dark = t * 0.22;
		vec3 lit = t + (vec3(1.0) - t) * 0.35;
		vec3 rgb = v < 0.55
			? mix(dark, t, clamp(v / 0.55, 0.0, 1.0))
			: mix(t, lit, clamp((v - 0.55) / 0.45, 0.0, 1.0));
		// COLOR arrives as the grey times whatever tints the hero - the day,
		// the party colour - so that tint is the ratio of the two, and the
		// hair takes it exactly as the body under it does.
		vec3 tint = v > 0.02 ? COLOR.rgb / v : vec3(1.0);
		COLOR.rgb = rgb * tint;
	}
}
