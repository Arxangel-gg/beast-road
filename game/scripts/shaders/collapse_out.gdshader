shader_type canvas_item;

// The dungeon coming down over the picture: cracks spreading from the
// edges, dust rolling in, the frame shaking to black (owner brief,
// 2026-09-12: "a collapsing animation and fade out with shader effects").

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float progress = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// A shudder in the sample, growing with the fall.
	vec2 shake = vec2(noise(vec2(TIME * 40.0, 1.0)) - 0.5, noise(vec2(3.0, TIME * 37.0)) - 0.5)
		* 0.012 * progress;
	vec3 scene = texture(screen_tex, SCREEN_UV + shake).rgb;
	// Dust rolling in from the edges.
	vec2 centred = SCREEN_UV - 0.5;
	float edge = length(centred) * 1.5;
	float dust = noise(SCREEN_UV * 6.0 + vec2(TIME * 0.7, -TIME * 0.4)) * 0.6 + 0.4;
	float roll = smoothstep(1.2 - progress * 1.6, 1.3 - progress * 0.9, edge + dust * 0.35);
	vec3 dusty = mix(scene, vec3(0.32, 0.27, 0.23) * dust, roll * 0.9);
	// Cracks: thin dark lines along noise ridges, spreading with progress.
	float ridge = abs(noise(SCREEN_UV * 9.0) - 0.5);
	float crack = smoothstep(0.02, 0.0, ridge) * smoothstep(0.15, 0.55, progress);
	dusty = mix(dusty, vec3(0.02), crack * 0.85);
	// And to black.
	float fade = smoothstep(0.55, 1.0, progress);
	COLOR = vec4(mix(dusty, vec3(0.0), fade), 1.0);
}
