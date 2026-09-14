shader_type canvas_item;

// The ground's own weather, seen: warm ground glows faintly, cold ground
// blues, wet ground darkens and frost whitens where it is both cold and wet.
// The texture is one texel a climate cell (R heat about 0.5, G wet, B soil),
// read through a linear filter so a cell's edge is a slope, and broken up by
// noise so nothing reads as a square. See `Climate._refresh_picture`.

// How far the tints go at their strongest. Small: this is a hint on the
// ground, under the water and the marks, not a heat map.
uniform float strength : hint_range(0.0, 1.0) = 0.16;
// Degrees of heat across the red channel, the same figure the picture writes.
uniform float degrees = 40.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 cell = texture(TEXTURE, UV);
	float heat = (cell.r - 0.5) * degrees;
	float wet = cell.g;
	// Organic breakup, slow, so the edge of a warm patch wanders rather
	// than following the cell.
	float grain = 0.55 + 0.45 * vnoise(UV * 90.0 + vec2(TIME * 0.03, -TIME * 0.02));
	// A few degrees already reads; the tint saturates by a hot band's worth.
	float warm = clamp(heat / 12.0, 0.0, 1.0);
	float cold = clamp(-heat / 10.0, 0.0, 1.0);
	float damp = clamp((wet - 0.45) / 0.45, 0.0, 1.0);
	float frost = cold * clamp((wet - 0.5) / 0.4, 0.0, 1.0);
	vec3 colour = vec3(0.0);
	float alpha = 0.0;
	// Warm: an ember-orange glow. Cold: a blue cast. Wet: the ground darkens
	// toward the water's own colour. Frost: white over the blue.
	colour += vec3(1.0, 0.55, 0.22) * warm;
	alpha += warm * 1.0;
	colour += vec3(0.5, 0.68, 1.0) * cold;
	alpha += cold * 0.8;
	colour += vec3(0.08, 0.14, 0.2) * damp;
	alpha += damp * 1.1;
	colour += vec3(0.92, 0.96, 1.0) * frost;
	alpha += frost * 1.4;
	alpha = clamp(alpha, 0.0, 1.0);
	COLOR = vec4(colour / max(alpha, 0.001) * min(alpha, 1.0), alpha * strength * grain);
}
