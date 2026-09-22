shader_type canvas_item;

// **The ground itself bends as the wave passes over it.**
//
// Owner, 2026-09-22: the earth's ground wave was *"a low quality and
// unaesthetically appealing and low game juice starting solution"*. It was:
// the whole field took one number on one frame and the only picture was a
// camera shake and three dust puffs. Nothing on the ground moved.
//
// This is `flood_sheen`'s technique put to the other use - it reads the frame
// beneath it (`hint_screen_texture`) and displaces it. Where the flood bends
// the picture by a surface's slope, this bends it by a travelling ring: the
// ground swells in front of the crest and dips behind it, which is what a
// seismic wave does and what no amount of shaking the camera can say.
//
// Up to three rings at once, because a strong quake sends aftershocks and
// they overlap. Each is `vec3(x, y, radius)` in the same aspect-corrected
// screen space this shader works in, handed over every frame by `GroundWave`
// so the picture and the blow cannot disagree about where the front is.
//
// **Never headless**, where there is no frame to copy - the same rule every
// screen-reading shader in this project lives under. `Graphics.KEY_WATER_REFRACTION`
// is the low-end switch that turns it off, because it is the same cost.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// x, y, radius. A radius at or below zero is a ring that is not running.
uniform vec3 ring_a = vec3(0.0, 0.0, -1.0);
uniform vec3 ring_b = vec3(0.0, 0.0, -1.0);
uniform vec3 ring_c = vec3(0.0, 0.0, -1.0);
// How much of each ring is left, 0..1, so a wave fades rather than switching off.
uniform vec3 ring_life = vec3(0.0);

// How wide the crest is and how far it moves the ground under it.
uniform float crest = 0.06;
uniform float strength = 0.012;
// The screen's aspect, so a ring is round rather than an ellipse.
uniform float aspect = 1.777;
// Light on the swell and shadow in the trough. Small: this is earth moving,
// not water.
uniform float relief = 0.22;
uniform vec4 dust_tint : source_color = vec4(0.72, 0.60, 0.44, 1.0);


// How far this point is in front of (positive) or behind (negative) a ring's
// crest, in crest widths, and which way is outward.
vec3 read_ring(vec3 ring, vec2 p) {
	if (ring.z <= 0.0) {
		return vec3(0.0);
	}
	vec2 away = p - ring.xy;
	float far = length(away);
	if (far < 0.00001) {
		return vec3(0.0);
	}
	float across = (far - ring.z) / crest;
	if (abs(across) > 1.0) {
		return vec3(0.0);
	}
	// A full sine over the crest: the ground rises ahead of the front and
	// falls behind it, and returns to exactly where it was at either edge.
	float lift = sin(across * 3.14159265);
	vec2 dir = away / far;
	return vec3(dir * lift, lift);
}


void fragment() {
	// Aspect-corrected, so a ring is a circle on a wide screen.
	vec2 p = vec2(SCREEN_UV.x * aspect, SCREEN_UV.y);

	vec3 a = read_ring(ring_a, p) * ring_life.x;
	vec3 b = read_ring(ring_b, p) * ring_life.y;
	vec3 c = read_ring(ring_c, p) * ring_life.z;
	vec2 push = (a.xy + b.xy + c.xy) * strength;
	float swell = a.z + b.z + c.z;

	if (abs(swell) < 0.0005) {
		// Nothing here is moving, so hand the frame back untouched rather
		// than resampling it: a full-screen quad that copies itself is a
		// blur nobody asked for.
		COLOR = vec4(0.0);
	} else {
		vec2 at = SCREEN_UV + vec2(push.x / aspect, push.y);
		vec3 frame = texture(screen_tex, at).rgb;
		// The swell catches light and the trough holds shadow, and the dust
		// the wave throws warms the whole of it a little.
		frame *= 1.0 + swell * relief;
		frame = mix(frame, frame * dust_tint.rgb, clamp(abs(swell) * 0.5, 0.0, 0.5));
		COLOR = vec4(frame, clamp(abs(swell) * 2.2, 0.0, 1.0));
	}
}
