shader_type canvas_item;

// The water in a pond, and the light on it.
//
// Runs on the pond's TileMapLayer, so TEXTURE is the region's Wang sheet and
// the tiles already carry the painted water and the painted bank. What the
// shader adds is the part paint cannot: the surface moves. Two things move it.
//
// - **Glints**: two slow sine bands multiplied together, thresholded, laid over
//   the deep water only. A product of two sines gives drifting patches rather
//   than the scrolling stripes one sine gives, and the threshold turns the
//   patches into pixel-sized flecks rather than a smooth wash.
// - **Rings**: up to eight expanding ripples, each a position, a birth time and
//   a strength. The line going in, a nibble, a bite and the ambient stir the
//   pond makes on its own are all the same ring at different strengths.
//
// **Everything is quantised to the tile's own pixels** (`pixel`), so the effect
// reads as pixel art moving rather than a smooth shader laid over pixel art -
// which is the difference between water and a screensaver.
//
// **The mask is the whole trick of blending a tileset into a painted field.**
// The sheet's "upper" terrain is a generated bank that will never match the
// battlefield's own ground; the red channel fades it to nothing a tile out from
// the water so the pond ends in its bank and the field shows through. Green is
// the deep water, so the light never lands on the mud.
//
// **Cheap on purpose.** No noise texture, no second pass, a loop of eight with
// an early exit, and a `discard` on every fully transparent fragment so the
// ground band around a pond costs nothing to blend. Six ponds on a phone are
// well inside the frame.

uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec2 pond_size = vec2(256.0, 192.0);
// Fed from the pond each frame rather than TIME, so a ring's birth time and
// the clock it is measured against are the same clock.
uniform float now = 0.0;
uniform float pixel = 1.0;
uniform vec4 glint_colour : source_color = vec4(0.84, 0.94, 1.0, 1.0);
uniform float glint_strength = 0.26;
uniform float wave_scale = 0.085;
uniform float wave_speed = 1.15;
uniform float ripple_speed = 34.0;
uniform float ripple_life = 1.7;
uniform float ripple_width = 2.6;
uniform vec4 ripples[8];
// 1.0 once the pond is fished out: flatter, greyer, still.
uniform float spent = 0.0;

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

void fragment() {
	vec2 m = texture(mask, local_px / pond_size).rg;
	if (m.r <= 0.004) {
		discard;
	}
	vec4 tex = texture(TEXTURE, UV);
	vec2 q = floor(local_px / pixel) * pixel;
	float t = now;
	float a = sin(q.x * wave_scale + q.y * wave_scale * 0.6 + t * wave_speed);
	float b = sin(q.y * wave_scale * 1.3 - q.x * wave_scale * 0.4 - t * wave_speed * 0.8);
	float glint = smoothstep(0.64, 0.93, a * b);

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
		float d = length(q - r.xy);
		float outer = 1.0 - smoothstep(0.0, ripple_width, abs(d - radius));
		float inner = 1.0 - smoothstep(0.0, ripple_width, abs(d - radius * 0.58));
		rings += (outer + inner * 0.55) * (1.0 - age / ripple_life) * r.w;
	}

	float calm = 1.0 - spent * 0.75;
	float lift = (glint * glint_strength * calm + min(rings, 1.0) * 0.6) * m.g;
	vec3 colour = mix(tex.rgb, glint_colour.rgb, lift);
	float grey = dot(colour, vec3(0.3, 0.5, 0.2));
	colour = mix(colour, vec3(grey) * 0.92, spent * 0.55);
	COLOR = vec4(colour, tex.a * m.r);
}
