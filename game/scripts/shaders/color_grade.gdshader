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

// Mipmapped, for the bloom: the screen's own mip chain is a blur the renderer
// has already paid for. The picture itself is read at level 0, exactly as the
// plain linear read did.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float lift = 0.0;
uniform float vignette = 0.28;
uniform float night = 0.0;
uniform vec4 night_tint : source_color = vec4(0.62, 0.72, 1.0, 1.0);
uniform float grain = 0.018;
uniform float now = 0.0;

// --- Bloom (2026-09-24) --------------------------------------------------------
//
// What bleeds light into the dark around it: a torch, a flame, a spell, a
// glowing seam. Read off three levels of the screen's mip chain - measured
// working on the Compatibility renderer by `tools/bloom_probe.gd` - and kept to
// what is brighter than `bloom_threshold`, which falls as the night rises so a
// sunlit field never hazes. Zero is no bloom and costs three taps, not a pass.
uniform float bloom = 0.0;
uniform float bloom_threshold = 0.8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 colour = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	vec3 glow = vec3(0.0);
	if (bloom > 0.001) {
		// Three widths, narrow first: the tight one keeps a flame's core hot and
		// the wide one is the light it throws into the air.
		vec3 near = textureLod(screen_tex, SCREEN_UV, 2.0).rgb;
		vec3 mid = textureLod(screen_tex, SCREEN_UV, 3.5).rgb;
		vec3 far = textureLod(screen_tex, SCREEN_UV, 5.0).rgb;
		vec3 spread = near * 0.55 + mid * 0.3 + far * 0.15;
		float bright = max(spread.r, max(spread.g, spread.b));
		// Soft knee: what clears the threshold blooms by how far it clears it,
		// so a light crossing the line fades in rather than switching on.
		float over = smoothstep(bloom_threshold, bloom_threshold + 0.3, bright);
		glow = spread * over * bloom;
	}
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
	// After the grade and the vignette: light bleeding from a torch is light,
	// not something the region's tint or the corner's shade should dim. Added
	// as a screen blend so it brightens toward white rather than past it.
	colour = 1.0 - (1.0 - colour) * (1.0 - clamp(glow, 0.0, 1.0));
	// A breath of grain, so flat gradients do not band.
	colour += (hash(SCREEN_UV * 1013.0 + fract(now)) - 0.5) * grain;
	COLOR = vec4(clamp(colour, 0.0, 1.0), 1.0);
}
