shader_type canvas_item;
render_mode blend_disabled, unshaded;

// The grade over the whole picture (owner brief, 2026-09-12: "some sort of
// color grading for all assets ... tuned to accommodate time of day").
//
// One full-screen pass over the finished frame: a per-region tint, saturation
// and contrast, lifted shadows, a vignette, and a night blend that cools and
// mutes the lot as the sun goes. Every asset in the game is drawn in its own
// palette; this is what makes them one picture in every region and at every
// hour without repainting any of them.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float lift = 0.0;
uniform float vignette = 0.28;
uniform float night = 0.0;
uniform vec4 night_tint : source_color = vec4(0.62, 0.72, 1.0, 1.0);
uniform float grain = 0.018;
uniform float now = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 colour = texture(screen_tex, SCREEN_UV).rgb;
	// The region's tint, as a multiply that keeps whites white-ish.
	colour *= mix(vec3(1.0), tint.rgb, 0.85);
	// Saturation about luminance.
	float luma = dot(colour, vec3(0.299, 0.587, 0.114));
	float sat = mix(saturation, saturation * 0.8, night);
	colour = mix(vec3(luma), colour, sat);
	// Contrast about mid grey, and a shadow lift so the darks keep detail.
	colour = (colour - 0.5) * contrast + 0.5;
	colour = colour + lift * (1.0 - colour);
	// Night: cooled and dimmed, more so at the edges.
	colour = mix(colour, colour * night_tint.rgb, night * 0.55);
	// Vignette.
	vec2 centred = SCREEN_UV - 0.5;
	float edge = dot(centred, centred) * 2.6;
	colour *= 1.0 - vignette * smoothstep(0.25, 1.15, edge) * (1.0 + night * 0.4);
	// A breath of grain, so flat gradients do not band.
	colour += (hash(SCREEN_UV * 1013.0 + fract(now)) - 0.5) * grain;
	COLOR = vec4(clamp(colour, 0.0, 1.0), 1.0);
}
