shader_type canvas_item;
render_mode blend_add;

// The burning parts of a thing, lit from inside.
//
// **Owner brief, 2026-09-15:** "the firehorse should also have holographic
// shaders around its fire areas with perfect polished aesthetics."
//
// **It finds the fire rather than being told where it is.** A mask painted by
// hand would be a second asset to keep in step with the first, and it would be
// wrong the moment the horse is redrawn. Fire in this game's palette is
// red-dominant and blue-starved, so `r - b` is the heat, and everything here is
// multiplied by it: the mane and the hooves light up and the hide, the saddle
// and the rider do not.
//
// **Additive and nothing else.** The horse is drawn once, graded to the scene
// like everything else on that ledge; this is a second pass over the same art
// that can only add. So no value of any uniform can take the horse's own
// colour off it, which is the bound every overlay in this project is held to.
//
// The holographic part is behaviour rather than palette, as with the wordmark
// and the frame: a scan drifting up through the flame, a slow instability, and
// a rim where the fire meets the air.

// How hot a pixel has to be before it counts as fire, and how strongly the
// pass lights what it finds.
uniform float heat_floor : hint_range(0.0, 1.0) = 0.10;
uniform float strength : hint_range(0.0, 2.0) = 0.85;
// The scan across the flame, and how many bands.
uniform float scan_lines : hint_range(4.0, 200.0) = 38.0;
uniform float scan_share : hint_range(0.0, 1.0) = 0.45;
// The light the pass is made of. Warm by default; a frost mount would pass its
// own and the same shader would serve it.
uniform vec3 glow = vec3(1.0, 0.66, 0.28);
uniform float clock = 0.0;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	// Heat: red over blue, which is fire in this palette and is not skin, not
	// stone and not cloth.
	float heat = clamp((art.r - art.b) - heat_floor, 0.0, 1.0) * art.a;
	if (heat <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		// The rim where flame meets air, found from the alpha falloff the way
		// every other rim in this project is.
		vec2 step_uv = TEXTURE_PIXEL_SIZE;
		float around =
			texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a +
			texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a +
			texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a +
			texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a;
		float rim = clamp(art.a * 4.0 - around, 0.0, 1.0);

		// Drifting up through the flame rather than sitting on it.
		float scan = 0.5 + 0.5 * sin((UV.y * 2.0 - clock * 0.9) * scan_lines);
		// Two rates, so the flame never settles into a beat.
		float unsteady = 0.74 + 0.18 * sin(clock * 5.3) + 0.08 * sin(clock * 11.7);

		float amount = strength * heat * unsteady
			* (1.0 - scan_share + scan_share * scan + rim * 0.6);
		COLOR = vec4(glow * amount * COLOR.a, art.a * COLOR.a);
	}
}
