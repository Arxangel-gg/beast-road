shader_type canvas_item;

// Standing water over the field. `level` is the flood, 0..1: at the low end
// only the hollows hold a puddle, at the top the whole ground is a shallow
// sheet. See `WeatherSky._build_sheen`.
//
// Second cut (owner brief, 2026-09-14: "optimized but highly polished for
// realism"). Water is the ground seen *through* something, not a colour laid
// over it, so on machines that allow it the fragment reads the frame beneath,
// bends it by the surface's slope, darkens and cools it by depth and lays the
// light's caustic net over it; a foam line runs along the shore where the
// water meets dry ground; the light catches the slope as sparse glints; and
// rain, when it falls, rings the surface here and there. One pass, three sine
// sheets and two octaves of noise per pixel, no loops. `refracts` is the
// low-end switch: off, it is the first cut's flat sheet.

uniform float level : hint_range(0.0, 1.0) = 0.0;
// The rain falling on it, 0..1. Drives the rings.
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.36, 0.48, 0.62, 1.0);
uniform float peak_alpha : hint_range(0.0, 1.0) = 0.42;
// Puddles per quad edge. The quad spans the whole field, so this is coarse.
uniform float cells = 26.0;
// Ripples per quad edge. The quad is over seven thousand units across, so a
// ripple wants hundreds of cycles to be a ripple: at fourteen, the first cut
// drew soft ovals two hundred units apart and the field read as patched with
// snow rather than standing in water.
uniform float ripples = 420.0;
// Whether the ground beneath is read and bent. Costs a frame copy; off on Low.
uniform bool refracts = true;
// How far the surface bends what is under it, in screen UV, at full depth.
uniform float refraction = 0.011;
// The slope of the ripples, as a share of a unit normal.
uniform float wave_height = 0.0009;
// Where the light comes from, over the field. Top-left, like the shadows.
uniform vec2 light_dir = vec2(-0.55, -0.8);
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
// The climate's picture (G is wetness), spanning the same square: ground wet
// enough puddles before the flood rises, and stays puddled after it drains.
uniform sampler2D wet_tex : hint_default_black, filter_linear;
uniform float puddle_from = 0.55;
uniform float puddle_level = 0.5;
// Which way the air is going, in UV. The same `RunState.wind` the wildfire
// spreads on and the foliage leans with, so the field agrees with itself about
// the weather (owner, 2026-09-16). Zero is the old fixed diagonal.
uniform vec2 flow = vec2(0.0);
// The hour's own light. Glints, foam and caustics are the sky lying on the
// ground, so at dusk they are orange and at midnight they are nearly out.
uniform vec4 sun_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// How far the shore breathes in and out, in UV, and how fast.
uniform float lap = 0.06;
uniform float lap_rate = 0.55;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise, so the puddles have soft banks rather than tile edges.
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

// The surface as a height: two crossing sheets and a slower swell under them,
// all three carried downwind. Without `flow` the sheets travel on a fixed
// diagonal, which reads as water running the same way whatever the sky does.
float surface(vec2 uv, float t) {
	vec2 w = uv - flow * t;
	float a = sin((w.x + w.y) * ripples + t * 1.6);
	float b = sin((w.x - w.y * 0.6) * ripples * 0.71 - t * 1.1);
	float c = sin((w.x * 0.3 + w.y) * ripples * 0.23 + t * 0.5);
	return a * 0.45 + b * 0.35 + c * 0.2;
}

void fragment() {
	// The flood, or the ground's own wetness where that stands higher.
	float local = smoothstep(puddle_from, 0.98, texture(wet_tex, UV).g) * puddle_level;
	float here = max(level, local);
	if (here <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 p = UV * cells;
		// Two octaves of hollows. The ground's low points fill first: a pixel
		// is wet once the water has risen past its own height.
		float ground = vnoise(p) * 0.65 + vnoise(p * 2.7 + 13.1) * 0.35;
		float rise = here * 1.15;
		float water = smoothstep(ground - 0.08, ground + 0.08, rise);
		// How deep it stands here: the rise over the ground's own height.
		float depth = clamp((rise - ground) / 0.6, 0.0, 1.0);

		// The surface's slope, from the height either side, for the light
		// and for the bend.
		float e = 0.0008;
		float h = surface(UV, TIME);
		vec2 slope = vec2(surface(UV + vec2(e, 0.0), TIME) - h,
			surface(UV + vec2(0.0, e), TIME) - h) / e;
		vec3 n = normalize(vec3(-slope * wave_height, 1.0));
		vec3 l = normalize(vec3(light_dir, 0.9));
		// Sparse, bright: a glint is a crest catching the light, not a haze.
		float spec = pow(max(dot(n, l), 0.0), 90.0);

		// The caustic net: where two sheets cross, light gathers on the
		// bottom. Fine and broken up by noise - at a coarser scale the first
		// cut drew a diagonal lattice across the whole field - and faint,
		// because it is a hint of water and not a pattern on it.
		vec2 cw = UV - flow * TIME;
		float ca = sin((cw.x + cw.y) * ripples * 1.7 + TIME * 1.2);
		float cb = sin((cw.x - cw.y * 0.6) * ripples * 1.3 - TIME * 0.8);
		float caustic = pow(abs(ca * cb), 4.0) * vnoise(UV * cells * 3.0 + vec2(TIME * 0.08, 0.0));

		// Rain rings: an expanding ring in a few of the cells, each on its
		// own clock, fading as it widens.
		float rings = 0.0;
		if (rain > 0.01) {
			vec2 rp = UV * cells * 12.0;
			vec2 cell = floor(rp);
			vec2 f = fract(rp) - 0.5;
			float seed = hash21(cell);
			float t = fract(TIME * (0.8 + seed * 0.7) + seed * 7.0);
			vec2 centre = (vec2(hash21(cell + 3.1), hash21(cell + 7.7)) - 0.5) * 0.5;
			float d = length(f - centre);
			float r = t * 0.38;
			rings = smoothstep(0.03, 0.0, abs(d - r)) * (1.0 - t) * (1.0 - t) * step(seed, rain * 0.6);
		}
		float glint = (spec * 0.55 + rings * 0.55) * water;

		// Foam where the water meets the ground, and the shore **laps**: the
		// band it covers breathes in and out on a slow clock broken up by
		// noise, so the edge of the water moves the way an edge of water does
		// rather than sitting at a fixed width with a pattern on it.
		float tide = lap * sin(TIME * lap_rate
			+ vnoise(UV * cells * 0.7) * 6.28);
		float shore = smoothstep(0.0, 0.5 + tide, water)
			* (1.0 - smoothstep(0.5 + tide, 1.0, water));
		float foam = shore * (0.45 + 0.55 * vnoise(UV * cells * 6.0 + vec2(TIME * 0.35, -TIME * 0.2))) * 0.42;

		float a = water * peak_alpha * (0.55 + 0.45 * here);
		if (refracts) {
			// The ground seen through the water: bent by the slope, cooled
			// and darkened by depth, the caustic net laid on it, then the
			// glints and the foam on top. The ground's own colour carries
			// through, so a jungle floods brown-green and a snowfield grey.
			vec2 off = n.xy * refraction * depth;
			vec3 seen = texture(screen_tex, SCREEN_UV + off).rgb;
			vec3 cooled = seen * mix(vec3(1.0), vec3(0.74, 0.86, 1.0), 0.5 + 0.5 * depth);
			// **Two ramps rather than one.** Shallow water keeps the ground's
			// own colour and only deep water goes toward the tint; one mix
			// doing both jobs made an ankle-deep puddle the same blue as a
			// basin.
			vec3 body = mix(cooled, tint.rgb, 0.08 + 0.42 * smoothstep(0.25, 1.0, depth));
			body *= 0.94 - 0.26 * depth;
			body += sun_tint.rgb * (caustic * (0.04 + 0.08 * depth));
			COLOR = vec4(body + sun_tint.rgb * (glint + foam),
				max(a, water * (0.86 + 0.14 * depth)) + foam * 0.5);
		} else {
			// Standing water darkens the ground it lies on and catches a
			// little light on top: the tint sits under, the glint over.
			COLOR = vec4(tint.rgb * 0.7 + sun_tint.rgb * (glint + caustic * 0.08 + foam),
				a + glint + foam * 0.5);
		}
	}
}
