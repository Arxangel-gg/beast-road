shader_type canvas_item;

// A grave marker coming apart when its player stands back up (2026-09-14).
//
// The stone does not fade: it crumbles, from a noise field, each grain going
// in its own moment, with a thin lit edge on the grains about to go so the
// dissolve reads as the stone burning away rather than as a sprite turning
// transparent. `progress` runs 0 (whole) to 1 (gone) and is driven by a tween
// on the stone; nothing here reads the clock.

// 0 is the stone untouched, 1 is fully gone.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// The lit edge on the grains about to go.
uniform vec4 edge_tint : source_color = vec4(0.72, 0.92, 0.78, 1.0);
uniform float edge_width : hint_range(0.0, 0.3) = 0.08;
// Grain size in texture space; larger is coarser crumbs.
uniform float grain = 14.0;

// A cheap hash for a noise the stone owns; no texture to load or ship.
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
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
	vec4 tex = texture(TEXTURE, UV);
	// Two octaves: grains, and a slower drift so the crumbling has a shape
	// rather than being static all over at once. The top goes first, a little,
	// because a stone that crumbles from its crown reads as falling away.
	float n = noise(UV * grain) * 0.7 + noise(UV * grain * 0.37 + 3.1) * 0.3;
	n = n * 0.85 + (1.0 - UV.y) * 0.15;
	float threshold = progress * 1.15;
	if (n < threshold) {
		discard;
	}
	float edge = smoothstep(threshold + edge_width, threshold, n) * step(0.001, progress);
	vec3 colour = mix(tex.rgb, edge_tint.rgb, edge * 0.85);
	COLOR = vec4(colour, tex.a) * COLOR;
}
