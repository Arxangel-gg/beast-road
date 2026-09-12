shader_type canvas_item;

// The water in a pond, and the light on it.
//
// Runs on the pond's TileMapLayer, so TEXTURE is the region's Wang sheet and
// the tiles already carry the painted water and the painted bank. What the
// shader adds is the part paint cannot: the surface moves, the deep water is
// deeper, the edge is soft, and things that happened on the water leave a
// mark for a while.
//
// - **Glints**: two slow sine bands multiplied together, thresholded, laid over
//   the deep water only. A product of two sines gives drifting patches rather
//   than the scrolling stripes one sine gives, and the threshold turns the
//   patches into pixel-sized flecks rather than a smooth wash.
// - **Caustics**: a second, finer pair of bands at a different drift, added at
//   a fraction of the glint's strength and masked to the deep water, so the
//   bottom of the pond reads as lit through water rather than painted flat.
// - **Depth**: the mask's blue channel is how far from the bank a texel is.
//   The middle is tinted toward `deep_colour`, which is what makes a pond
//   read as having a middle at all - and the fishing code reads the same
//   channel to decide where the rare fish are.
// - **Shore foam**: a thin pale line that wanders along the waterline on its
//   own slow clock. The tiles' painted edge is a hard pixel step; the foam is
//   what turns that into a shore.
// - **Rings**: up to eight expanding ripples, each a position, a birth time and
//   a strength. The line going in, a nibble, a bite, a swimmer's stroke and
//   the ambient stir the pond makes on its own are all the same ring.
// - **Stains**: up to four spreading dark discs - blood on the water where
//   something in it bit a swimmer - that fade over their life. Only ever fed
//   while the blood setting is on.
// - **A feathered rim**: the mask's red channel fades the generated bank into
//   the painted field over a full tile rather than the half tile it was, so a
//   pond ends in ground rather than in a cut-out. Owner report, 2026-09-12:
//   "the outer edges of a pond should have feathered smoothing rather than a
//   sharp edge outline".
//
// **Everything is quantised to the tile's own pixels** (`pixel`), so the effect
// reads as pixel art moving rather than a smooth shader laid over pixel art -
// which is the difference between water and a screensaver.
//
// **Cheap on purpose.** No noise texture, no second pass, two short loops with
// early exits, and a `discard` on every fully transparent fragment so the
// ground band around a pond costs nothing to blend. Six ponds on a phone are
// well inside the frame.

uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec2 pond_size = vec2(256.0, 192.0);
// Fed from the pond each frame rather than TIME, so a ring's birth time and
// the clock it is measured against are the same clock.
uniform float now = 0.0;
uniform float pixel = 1.0;
uniform vec4 glint_colour : source_color = vec4(0.84, 0.94, 1.0, 1.0);
uniform vec4 deep_colour : source_color = vec4(0.10, 0.22, 0.34, 1.0);
uniform vec4 foam_colour : source_color = vec4(0.92, 0.97, 1.0, 1.0);
uniform vec4 stain_colour : source_color = vec4(0.42, 0.05, 0.06, 1.0);
uniform float glint_strength = 0.26;
uniform float caustic_strength = 0.11;
uniform float depth_tint = 0.42;
uniform float foam_strength = 0.34;
uniform float rim_softness = 0.9;
uniform float wave_scale = 0.085;
uniform float wave_speed = 1.15;
uniform float ripple_speed = 34.0;
uniform float ripple_life = 1.7;
uniform float ripple_width = 2.6;
uniform float stain_life = 9.0;
uniform vec4 ripples[8];
uniform vec4 stains[4];
// 1.0 once the pond is fished out: flatter, greyer, still.
uniform float spent = 0.0;

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

void fragment() {
	vec3 m = texture(mask, local_px / pond_size).rgb;
	if (m.r <= 0.004) {
		discard;
	}
	vec4 tex = texture(TEXTURE, UV);
	vec2 q = floor(local_px / pixel) * pixel;
	float t = now;
	float calm = 1.0 - spent * 0.75;

	// The surface light.
	float a = sin(q.x * wave_scale + q.y * wave_scale * 0.6 + t * wave_speed);
	float b = sin(q.y * wave_scale * 1.3 - q.x * wave_scale * 0.4 - t * wave_speed * 0.8);
	float glint = smoothstep(0.64, 0.93, a * b);
	// The bottom, lit through the water: finer, slower, and only where it is deep.
	float c = sin(q.x * wave_scale * 2.3 - q.y * wave_scale * 1.1 + t * wave_speed * 0.45);
	float d = sin(q.y * wave_scale * 2.7 + q.x * wave_scale * 0.9 - t * wave_speed * 0.35);
	float caustic = smoothstep(0.55, 0.9, c * d) * m.b;

	// The rings.
	float rings = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 r = ripples[i];
		if (r.w <= 0.0) {
			continue;
		}
		float age = t - r.z;
		if (age < 0.0 || age > ripple_life) {
			continue;
		}
		float radius = age * ripple_speed;
		float dist = length(q - r.xy);
		float outer = 1.0 - smoothstep(0.0, ripple_width, abs(dist - radius));
		float inner = 1.0 - smoothstep(0.0, ripple_width, abs(dist - radius * 0.58));
		rings += (outer + inner * 0.55) * (1.0 - age / ripple_life) * r.w;
	}

	// The stains.
	float stain = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 s = stains[i];
		if (s.w <= 0.0) {
			continue;
		}
		float age = t - s.z;
		if (age < 0.0 || age > stain_life) {
			continue;
		}
		float spread = 10.0 + age * 5.0;
		float dist = length(q - s.xy);
		float disc = 1.0 - smoothstep(spread * 0.55, spread, dist);
		stain += disc * (1.0 - age / stain_life) * s.w;
	}

	// The shore: a pale wandering line where the deep water meets the bank.
	float shoreline = 1.0 - smoothstep(0.0, 0.16, abs(m.g - (0.36 + 0.05 * sin(q.x * 0.05 + q.y * 0.03 + t * 0.7))));
	float foam = shoreline * (0.5 + 0.5 * sin(q.x * 0.11 + q.y * 0.07 + t * 1.6)) * foam_strength * calm;

	vec3 colour = mix(tex.rgb, deep_colour.rgb, m.b * depth_tint);
	float lift = (glint * glint_strength * calm + caustic * caustic_strength * calm
		+ min(rings, 1.0) * 0.6) * m.g;
	colour = mix(colour, glint_colour.rgb, lift);
	colour = mix(colour, foam_colour.rgb, foam);
	colour = mix(colour, stain_colour.rgb, min(stain, 0.85));
	float grey = dot(colour, vec3(0.3, 0.5, 0.2));
	colour = mix(colour, vec3(grey) * 0.92, spent * 0.55);
	// The feathered rim: the bank fades out over the whole of the mask's ramp.
	float rim = smoothstep(0.0, rim_softness, m.r);
	COLOR = vec4(colour, tex.a * rim);
}
