shader_type canvas_item;

// Standing water over the field. `level` is the flood, 0..1: at the low end
// only the hollows hold a puddle, at the top the whole ground is a shallow
// sheet with ripples crossing it. See `Sky._build_sheen`.

uniform float level : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.36, 0.48, 0.62, 1.0);
uniform float peak_alpha : hint_range(0.0, 1.0) = 0.42;
// Puddles per quad edge. The quad spans the whole field, so this is coarse.
uniform float cells = 26.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise, so the puddles have soft banks rather than tile edges.
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
	if (level <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 p = UV * cells;
		// Two octaves of hollows. The ground's low points fill first: a pixel
		// is wet once the water has risen past its own height.
		float ground = noise(p) * 0.65 + noise(p * 2.7 + 13.1) * 0.35;
		float water = smoothstep(ground - 0.08, ground + 0.08, level * 1.15);
		// Ripples, two slow sheets crossing, faint so they read as movement
		// on water rather than as a pattern painted on it.
		float ripple = sin((UV.x + UV.y) * 140.0 + TIME * 1.6)
			* sin((UV.x - UV.y * 0.6) * 95.0 - TIME * 1.1);
		float glint = smoothstep(0.55, 0.95, ripple) * 0.35 * water;
		float a = water * peak_alpha * (0.55 + 0.45 * level);
		COLOR = vec4(tint.rgb + vec3(glint), a + glint * 0.5);
	}
}
