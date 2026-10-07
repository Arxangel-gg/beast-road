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

// --- The cinematic half (owner, 2026-10-07: "cinematic atmospheric
// post-processing, dynamic where needed") ------------------------------------
//
// All in this one pass, so it costs taps rather than a pass. A filmic shoulder
// rolls the highlights off instead of clipping them flat; split toning cools
// the shadows and warms the lights so a frame has depth of colour; a haze off
// the weather lifts the darks toward the sky's own colour, more at the top of
// the screen, which is further away from a camera looking down and along; a
// shimmer bends the air in a heatwave; and two moments move it - a boss
// tightens the frame, and a heavy blow kicks a lens fringe at the edges.
uniform float shoulder = 0.0;
uniform vec4 split_shadow : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 split_highlight : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float split = 0.0;
uniform float haze = 0.0;
uniform vec4 haze_colour : source_color = vec4(0.7, 0.72, 0.76, 1.0);
uniform float heat = 0.0;
uniform float fringe = 0.0;
uniform float boss = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// The filmic shoulder: straight below the knee, rolling toward white above it.
vec3 roll_off(vec3 c, float strength) {
	float knee = 0.78;
	vec3 over = max(c - knee, vec3(0.0));
	vec3 rolled = knee + (1.0 - knee) * (1.0 - exp(-over / (1.0 - knee)));
	return mix(c, mix(c, rolled, step(vec3(knee), c)), strength);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// Heat: the air bends, most toward the top of the screen where the light
	// has crossed the most of it. Never the interface: the grade sits under it.
	if (heat > 0.000001) {
		float far = smoothstep(0.15, 1.0, 1.0 - uv.y);
		uv.x += sin(uv.y * 150.0 + now * 3.3) * heat * far;
		uv.y += sin(uv.x * 90.0 + now * 2.1) * heat * 0.4 * far;
	}
	vec3 colour = textureLod(screen_tex, uv, 0.0).rgb;
	// The lens fringe: red and blue part toward the corners, nothing in the
	// middle where the player is looking.
	if (fringe > 0.000001) {
		vec2 dir = uv - 0.5;
		vec2 off = dir * fringe * dot(dir, dir) * 4.0;
		colour.r = textureLod(screen_tex, uv + off, 0.0).r;
		colour.b = textureLod(screen_tex, uv - off, 0.0).b;
	}
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
	colour = (colour - 0.5) * (contrast + boss * 0.07) + 0.5;
	colour = colour + lift * (1.0 - colour);
	colour = roll_off(max(colour, vec3(0.0)), shoulder);
	// Split toning: a chroma shift only - the grey of each colour is taken out,
	// so the shadows cool and the lights warm without the frame moving in
	// brightness.
	float tone = dot(colour, vec3(0.299, 0.587, 0.114));
	float shade = 1.0 - smoothstep(0.0, 0.55, tone);
	float light = smoothstep(0.45, 1.0, tone);
	colour += (split_shadow.rgb - dot(split_shadow.rgb, vec3(0.3333))) * shade * split;
	colour += (split_highlight.rgb - dot(split_highlight.rgb, vec3(0.3333))) * light * split;
	// Haze: the darks lifted toward the sky's colour, more the further up.
	if (haze > 0.0001) {
		float far = 0.45 + 0.55 * (1.0 - SCREEN_UV.y);
		colour = mix(colour, haze_colour.rgb, haze * far * (1.0 - tone * 0.5));
	}
	// Night: cooled and dimmed, more so at the edges.
	colour = mix(colour, colour * night_tint.rgb, night * 0.55);
	// Vignette.
	vec2 centred = SCREEN_UV - 0.5;
	float edge = dot(centred, centred) * 2.6;
	colour *= 1.0 - vignette * smoothstep(0.25, 1.15, edge) * (1.0 + night * 0.4 + boss * 0.6);
	// After the grade and the vignette: light bleeding from a torch is light,
	// not something the region's tint or the corner's shade should dim. Added
	// as a screen blend so it brightens toward white rather than past it.
	colour = 1.0 - (1.0 - colour) * (1.0 - clamp(glow, 0.0, 1.0));
	// A breath of grain, so flat gradients do not band.
	colour += (hash(SCREEN_UV * 1013.0 + fract(now)) - 0.5) * grain;
	COLOR = vec4(clamp(colour, 0.0, 1.0), 1.0);
}
