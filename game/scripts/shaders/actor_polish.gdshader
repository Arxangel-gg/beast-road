shader_type canvas_item;

// Fire, ice and the wind-up tell. Shared with `blood_stain`, which every
// unpromoted enemy wears - see the include's header for why neither shader may
// own that state alone.
#include "res://scripts/shaders/actor_state.gdshaderinc"

uniform vec4 outline_colour : source_color = vec4(0.035, 0.045, 0.05, 0.94);
uniform float outline_strength : hint_range(0.0, 1.0) = 0.82;
uniform vec4 impact_colour : source_color = vec4(1.0, 0.82, 0.62, 1.0);
uniform vec2 impact_direction = vec2(0.0, -1.0);
uniform float impact_strength : hint_range(0.0, 1.0) = 0.0;

// --- Promoted aura -----------------------------------------------------------
//
// A living band of light around an elite or champion, instead of the flat
// coloured line they wore before. The band is the silhouette widened by a ring
// of samples and then *eaten into* by flowing noise, so it licks and breathes
// rather than sitting there - which is the whole difference between a body that
// looks dangerous and a body with a border.
//
// Zero for everything else, and guarded, so an ordinary walker pays for none of
// the noise. There are a lot of ordinary walkers.
uniform float aura_strength : hint_range(0.0, 2.0) = 0.0;
uniform vec4 aura_colour : source_color = vec4(1.0, 0.78, 0.35, 1.0);
uniform float aura_speed = 1.1;
uniform float aura_scale = 7.0;
// How far the glow reaches past the silhouette, in source pixels.
uniform float aura_width = 3.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Value noise: cheap, and smooth enough that the band reads as flame rather
// than as static.
float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Two octaves drifting at different speeds. One octave pulses uniformly and
// reads as a throb; two moving against each other read as motion.
float aura_noise(vec2 uv) {
	float t = TIME * aura_speed;
	float low = value_noise(uv * aura_scale + vec2(0.0, -t));
	float high = value_noise(uv * aura_scale * 2.3 + vec2(t * 0.7, -t * 1.6));
	return low * 0.65 + high * 0.35;
}

// --- Light direction (2026-09-23) ---------------------------------------------
//
// Core Keeper's things shade with the light: a torch on the left lights the
// left of a tower and leaves its right in shadow. Real normal maps would be
// every frame of every tower drawn a second time; this reads the relief off the
// painting itself - how its brightness and its silhouette climb and fall across
// two pixels - which is what the auto-normal tools do, and it follows every
// frame for free because it reads the frame being drawn.
//
// **Zero for everything but a tower**, and at zero `light()` below is the
// engine's own formula, so nothing else that wears this shader looks any
// different. The pilot is towers first (owner, 2026-09-23).
uniform float shade_strength : hint_range(0.0, 1.0) = 0.0;
// How steep the relief reads as a surface, and how far in from the silhouette
// it reaches, in source pixels. Measured at two reaches and averaged, so the
// turn from the lit side to the dark one is a gradient rather than a band.
uniform float shade_relief = 2.2;
uniform float shade_reach = 6.0;
// How far a facet turned to a point light is lit past the plain additive light.
uniform float shade_gain = 1.4;

// **The form, not the bricks.** Mostly the silhouette with a little of the
// painting's brightness: read off the brightness alone, every mortar line
// became a ridge and the tower came out embossed rather than lit - the first
// photograph of this (2026-09-23) looked like a filter, not like light.
float relief_of(vec4 c) {
	return c.a * (0.8 + 0.2 * dot(c.rgb, vec3(0.299, 0.587, 0.114)));
}

// --- Coat --------------------------------------------------------------------
//
// No two deer are the same deer. See `Phenotype` for the design and the bounds;
// what matters here is that every one of these defaults to *nothing*, so an
// enemy - which wears this same shader - is pixel-identical to what it was.
uniform float coat_hue = 0.0;
uniform float coat_light = 0.0;
uniform float coat_saturation = 0.0;
uniform int coat_pattern = 0;
uniform float coat_pattern_strength : hint_range(0.0, 1.0) = 0.0;
uniform float coat_pattern_scale = 6.0;
uniform vec4 coat_pattern_tint : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec2 coat_offset = vec2(0.0, 0.0);

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-10)),
		d / (q.x + 1.0e-10), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

// **Markings are laid out in source pixels, not in UV.** The art is pixel art;
// a pattern computed in smooth UV space is an airbrush over hard pixels and
// reads as a smudge at every zoom the camera has. Snapping to the texture's own
// grid is what makes a dapple look painted on rather than projected onto.
float coat_mark(vec2 uv, vec2 px) {
	vec2 grid = floor(uv / px) + coat_offset;
	float scale = max(coat_pattern_scale, 1.0);
	if (coat_pattern == 1) {
		return step(0.72, hash21(floor(grid / scale)));
	}
	if (coat_pattern == 2) {
		return step(fract((grid.x + grid.y * 0.35) / scale), 0.34);
	}
	if (coat_pattern == 3) {
		return step(0.58, value_noise(grid / (scale * 2.0)));
	}
	if (coat_pattern == 4) {
		// Darker toward the ground: socks, and the shading under a belly.
		return smoothstep(0.62, 0.94, uv.y);
	}
	if (coat_pattern == 5) {
		// DAPPLE: mottling that fades at its edges rather than stepping. A fawn,
		// a young boar, light through leaves on anything.
		return smoothstep(0.42, 0.78, value_noise(grid / max(scale, 1.0)));
	}
	if (coat_pattern == 6) {
		// BANDS: rings across the body rather than along it - a ringed tail, a
		// banded back. Softened at the edges so they read as fur and not as a
		// barcode.
		float band = fract(grid.y / max(scale, 1.0));
		return smoothstep(0.30, 0.40, band) - smoothstep(0.60, 0.70, band);
	}
	if (coat_pattern == 7) {
		// MASK: the leading end and the chest darker than the rest. A raccoon, a
		// fox, a badger. Read off the sprite's own box, so it lands on the face
		// whichever way the animal is drawn.
		return smoothstep(0.42, 0.10, uv.x) * smoothstep(0.86, 0.38, uv.y);
	}
	if (coat_pattern == 8) {
		// SPECKLE: fine dense flecking at close to pixel scale, for the birds,
		// the frogs and the insects, where a spot the size of a spot would be
		// most of the animal.
		return step(0.80, hash21(floor(grid * 1.7)));
	}
	if (coat_pattern == 9) {
		// COUNTERSHADE: back dark, belly light. The commonest pattern there is
		// and the one that still reads when the sprite is forty pixels tall,
		// which makes it the right answer for the small species.
		return smoothstep(0.55, 0.05, uv.y);
	}
	return 0.0;
}

vec3 coat_apply(vec3 body, vec2 uv, vec2 px, float alpha) {
	if (coat_pattern == 0 && abs(coat_hue) < 0.0005
			&& abs(coat_light) < 0.0005 && abs(coat_saturation) < 0.0005) {
		return body;
	}
	vec3 hsv = rgb_to_hsv(body);
	hsv.x = fract(hsv.x + coat_hue);
	hsv.y = clamp(hsv.y * (1.0 + coat_saturation), 0.0, 1.0);
	hsv.z = clamp(hsv.z * (1.0 + coat_light), 0.0, 1.0);
	vec3 coated = hsv_to_rgb(hsv);
	float mark = coat_mark(uv, px) * coat_pattern_strength
		* coat_pattern_tint.a * alpha;
	return mix(coated, coat_pattern_tint.rgb, clamp(mark, 0.0, 1.0));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 source = COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float left_a = texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
	float right_a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	float up_a = texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float down_a = texture(TEXTURE, UV + vec2(0.0, px.y)).a;
	float around = max(max(left_a, right_a), max(up_a, down_a));
	float outline = max(around - tex.a, 0.0) * outline_strength;
	vec2 gradient = vec2(left_a - right_a, up_a - down_a);
	float edge = length(gradient) > 0.001
		? max(dot(normalize(gradient), normalize(impact_direction)), 0.0) : 0.0;
	// The coat first, so everything after it - the impact flash, the burning,
	// the chill, the wet, the dissolve - happens to *this* animal rather than
	// to the roster's one painting.
	vec3 coated = coat_apply(source.rgb, UV, px, source.a);
	vec3 body = mix(coated, impact_colour.rgb,
		edge * impact_strength * impact_colour.a * source.a);
	float near = min(min(left_a, right_a), min(up_a, down_a));
	body = state_body(body, UV, px, source.a, near);
	body = state_shine(body, UV, px, source.a);
	vec4 composed = vec4(body, source.a);
	vec4 rim = vec4(outline_colour.rgb, outline * outline_colour.a);
	vec4 painted = mix(rim, composed, composed.a);

	if (aura_strength > 0.001) {
		vec2 w = px * aura_width;
		float far_a = STATE_WIDENED_ALPHA(UV, w);

		// The band outside the body, faded by how far out it sits so the glow
		// falls off instead of ending on a hard line.
		float band = max(far_a - tex.a, 0.0);
		float falloff = mix(1.0, 0.55, clamp((band - outline) * 0.9, 0.0, 1.0));
		float flame = aura_noise(UV);
		// Eaten into rather than merely brightened: subtracting the noise makes
		// the edge ragged and moving, which is what licks.
		// Contrast on the noise, not just amplitude: a band that merely
		// brightens reads as a glow, while one that is cut away in places reads
		// as flame. `smoothstep` is what turns the second into the first.
		float bite = smoothstep(0.18, 0.85, flame);
		float lick = clamp(band * (bite * 1.9 + 0.22), 0.0, 1.0) * falloff;
		float glow = lick * aura_strength * aura_colour.a * (1.0 - tex.a);
		painted = mix(painted, vec4(aura_colour.rgb, 1.0),
			clamp(glow, 0.0, 1.0) * (1.0 - painted.a * 0.35));
		painted.a = max(painted.a, clamp(glow, 0.0, 1.0));
		// A breath through the body itself, so the whole thing feels charged
		// rather than merely edged.
		painted.rgb = mix(painted.rgb, aura_colour.rgb,
			tex.a * flame * 0.16 * aura_strength);
	}

	if (shade_strength > 0.001) {
		// A normal in the canvas's own axes, y down: a facet that falls away to
		// the right faces right.
		vec2 slope = vec2(0.0);
		for (int step = 1; step <= 2; step++) {
			vec2 w = px * shade_reach * float(step) * 0.5;
			slope.x += relief_of(texture(TEXTURE, UV - vec2(w.x, 0.0)))
				- relief_of(texture(TEXTURE, UV + vec2(w.x, 0.0)));
			slope.y += relief_of(texture(TEXTURE, UV - vec2(0.0, w.y)))
				- relief_of(texture(TEXTURE, UV + vec2(0.0, w.y)));
		}
		// What glows is not shaded: a flame, a crystal, an ember is its own
		// light, and a dark streak across one reads as soot rather than as form.
		float hottest = max(tex.r, max(tex.g, tex.b));
		float spread = hottest - min(tex.r, min(tex.g, tex.b));
		float glowing = smoothstep(0.6, 0.85, hottest) * smoothstep(0.25, 0.5, spread);
		NORMAL = vec3(normalize(vec3(slope * 0.5 * shade_relief, 1.0)).xy * (1.0 - glowing), 1.0);
	}

	STATE_APPLY_TELEGRAPH(painted, UV, px, tex.a)
	// Last: a body that is coming apart takes its outline, its aura and its
	// wind-up with it. Anything applied after this would survive the death.
	COLOR = state_dissolve(painted, UV, px);
}


// The engine's own light, times how squarely a facet faces it. A light's
// direction is mostly across the canvas unless it stands high: a torch at the
// roadside leans hard, and a tower's own light - raised to stand above it
// (`TOWER_LIGHT_HEIGHT`) - lights it nearly flat, so a tower is not shaded from
// inside its own foot. A directional light is the sun's relief and nothing else:
// it lights no flat surface at all and only brightens what faces it and darkens
// what faces away, so it cannot wash a tower out by day.
void light() {
	float lean = 0.0;
	if (shade_strength > 0.001) {
		lean = dot(NORMAL.xy, LIGHT_DIRECTION.xy) * shade_strength;
	}
	// The side turned away is darkened less than the side turned toward is lit:
	// a shaded side still reads as the same stone, and the sun darkening a whole
	// face to black read as a burnt tower.
	float turned = lean > 0.0 ? lean : lean * 0.45;
	if (LIGHT_IS_DIRECTIONAL && shade_strength > 0.001) {
		LIGHT = vec4(COLOR.rgb * LIGHT_COLOR.rgb * LIGHT_ENERGY * turned, LIGHT_COLOR.a);
	} else {
		LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY
			* max(1.0 + turned * shade_gain, 0.0), LIGHT_COLOR.a);
	}
}

