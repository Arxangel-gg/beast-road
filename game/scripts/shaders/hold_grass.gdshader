shader_type canvas_item;

// **Grass as a shader over the ground, rather than as a thing standing on it.**
//
// Owner, 2026-09-17: *"if there's a better way that you think would work better
// for our game more aesthetically and more polished appearance then do a shader
// effect on the grass areas ... I want it to be gorgeous but still optimized"*.
//
// There is, and this is it. A tuft field is a good answer for *near* detail and
// a bad one for coverage: to carpet a yard three and a half thousand units
// across you need tens of thousands of them, and at the zoom a player actually
// sits at each one is a few pixels. A shader pays once per screen pixel instead
// of once per blade, which means the density is free - and it is continuous, so
// there is no scatter to see through.
//
// The two are not alternatives. This lays the carpet; the tufts stand in it.
//
// ## What it draws
//
// Blades are *anisotropic noise*: value noise stretched hard along Y so each
// lobe is a vertical sliver, at three scales that do not share a period. Cheap
// (a handful of hashes), continuous, and it never tiles visibly - which a blade
// drawn as geometry on a lattice always eventually does.
//
// The wind is a **domain warp**: the whole field is sampled at an offset that
// leans with the wind and ripples across it, so a gust travels rather than the
// lawn breathing in place. The offset grows toward the blade tips, because
// grass is hinged at the root - the same rule `HoldGrass` bends its quads with,
// so the carpet and the tufts lean together.
//
// ## Where it draws
//
// `cover` is one texel a map cell: 1 where grass grows, 0 where it does not.
// Sampled linearly, so the edge of the lawn is a soft boundary rather than the
// cell grid - and it means the flagstone sanctum, the water and the hillside
// get nothing without this shader knowing what any of them are.
//
// ## What it is not
//
// Nothing reads it. It is drawn between the ground and the actors, changes no
// number, and `Graphics.foliage_scale()` scales it away to nothing on a weak
// machine - the bound every decoration in this project is held to.

// One texel a cell: how much grass is here.
uniform sampler2D cover : filter_linear, repeat_disable;
// The rectangle this quad covers, in world units, so the blades stay with the
// ground when the view moves rather than swimming across it.
uniform vec2 world_origin = vec2(0.0);
uniform vec2 world_size = vec2(1.0);
// The yard's own wind. Shared with the banners, the embers and the tufts.
uniform vec2 wind = vec2(0.0);
// How big a blade is, in world units. Smaller is finer and no more expensive.
uniform float blade = 7.0;
// How far the tips are carried, and how fast the ripple crosses the field.
uniform float sway = 2.6;
uniform float ripple = 0.9;
// The two ends of the blade: what the tips catch and what sits at the root.
uniform vec4 tip : source_color = vec4(0.42, 0.52, 0.26, 1.0);
uniform vec4 root : source_color = vec4(0.13, 0.19, 0.10, 1.0);
// How strongly the whole thing is laid over the ground. `Graphics` scales this.
uniform float strength : hint_range(0.0, 1.0) = 0.85;

float hash(vec2 at) {
	return fract(sin(dot(at, vec2(127.1, 311.7))) * 43758.5453123);
}

// Value noise, with the cell stretched along Y before it is sampled - which is
// the whole trick: an isotropic noise reads as moss and the same noise squashed
// vertically reads as blades.
float blades(vec2 at) {
	vec2 cell = floor(at);
	vec2 f = fract(at);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float here = texture(cover, UV).r;
	if (here < 0.02 || strength < 0.005) {
		COLOR = vec4(0.0);
	} else {
		vec2 world = world_origin + UV * world_size;

		// **The wind, as a domain warp.** A ripple travelling along the wind's
		// own direction, so a gust crosses the field instead of the whole lawn
		// breathing at once.
		float along = dot(world, normalize(wind + vec2(0.001, 0.0))) * 0.006;
		float gust = sin(along - TIME * ripple) * 0.5
			+ 0.5 * sin(along * 2.3 - TIME * ripple * 1.7);
		vec2 lean = (wind * 0.5 + vec2(gust, 0.0)) * sway;

		// Three scales. The coarse one is the clumping, the middle one is the
		// blades and the fine one is the light catching their edges; none of
		// the three periods divides another, so nothing repeats visibly.
		// **Stretched, not squashed flat.** The first cut used 0.22, which at
		// this blade size drew streaks the height of a person across the whole
		// yard rather than grass. Under a half reads as blades; much under it
		// reads as rain.
		vec2 stretch = vec2(1.0, 0.46);
		float coarse = blades((world + lean * 0.35) / (blade * 4.1) * stretch);
		float mid = blades((world + lean) / blade * stretch);
		float fine = blades((world + lean * 1.6) / (blade * 0.43) * stretch);

		float body = mid * 0.62 + coarse * 0.26 + fine * 0.22;
		// Pushed toward its ends, so the field is blades with gaps between them
		// rather than a grey wash of noise.
		body = smoothstep(0.42, 0.88, body);

		// Tips catch the light and roots sit in their own shade. The fine
		// octave decides which is which, which is what gives a flat carpet
		// depth without a second pass.
		vec3 shade = mix(root.rgb, tip.rgb, clamp(fine * 1.25, 0.0, 1.0));
		// And the gust lifts what it is passing over, so a ripple is visible as
		// light moving rather than only as shape moving.
		shade *= 0.88 + 0.24 * gust;

		COLOR = vec4(shade, body * here * strength);
	}
}
