// What is happening to a body, as material rather than as tint.
//
// Owner request, 2026-09-01: "Every shader must either improve atmosphere,
// communicate gameplay, or make progression feel more powerful." Burning,
// freezing and winding up to strike are the three pieces of combat state a
// player has to read off an enemy, and until now all three were a flat
// `sprite.modulate` multiply - orange for fire, blue for ice, a pulsing cream
// for the tell.
//
// `blood_stain.gdshader` already made the argument against that language for
// blood: a flat wash over a sprite reads as a status effect, and what reads as
// blood is *some of the pixels* being blood and the rest not. The argument is
// exactly as true for fire and for ice, and it is the reason this file exists.
//
// ## Why an include rather than a copy
//
// Every enemy wears `blood_stain`; elites wear `actor_polish` instead, because
// whichever material is claimed first wins. So state that only lived in one of
// them would be state that vanished the moment an enemy was promoted - or that
// only ever appeared on elites. Both shaders need all of it.
//
// They already duplicate the outline and impact uniforms between them, and that
// pair has drifted once. Three copies of a thing nobody can diff is how the
// fourth copy gets written, so this is shared text included by both.
//
// ## Why the sampling half is a macro
//
// Godot's shader compiler will not accept the built-in `TEXTURE` as a function
// argument - it asserts on `custom_samplers` in `shader_compiler.cpp` and then
// carries on, so the shader *loads*, logs an error per call site, and quietly
// samples the wrong thing. Everything here that does not touch the sprite is an
// ordinary function; the one piece that must is a macro, which the preprocessor
// pastes into each caller with its own `TEXTURE` in scope.
//
// ## The bound
//
// Every effect here is zero by default and every one is guarded by its own
// branch, so an ordinary walker with nothing wrong with it pays for none of it.
// There are a lot of ordinary walkers and the min-spec frame budget is still an
// open conformance row. The eight-sample widen in particular runs only while a
// body is actually winding up, which is well under a second at a time.

uniform float burn : hint_range(0.0, 1.0) = 0.0;
uniform vec4 burn_colour : source_color = vec4(1.0, 0.54, 0.16, 1.0);
uniform float frost : hint_range(0.0, 1.0) = 0.0;
uniform vec4 frost_colour : source_color = vec4(0.72, 0.90, 1.0, 1.0);
uniform float telegraph : hint_range(0.0, 1.0) = 0.0;
uniform vec4 telegraph_colour : source_color = vec4(1.0, 0.88, 0.58, 1.0);
uniform float telegraph_width = 2.6;
// Per body, so two enemies burning shoulder to shoulder do not burn in the
// same places and read as one animation played twice.
uniform float state_seed = 0.0;

// A shiny variant. Zero for every ordinary body, which is almost all of them -
// the rarest shiny rolls at one animal in ten and the commonest at one in fifty.
uniform float shine : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shine_colour : source_color = vec4(0.44, 0.91, 0.88, 1.0);

// Coming apart. Zero while alive, one when gone.
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_colour : source_color = vec4(1.0, 0.72, 0.42, 1.0);


// The silhouette's alpha pushed out by `w`, sampled on the diagonals as well as
// the cardinals. Four samples alone leave visible corners on a diagonal edge,
// which on a glow reads as a sprite with notches cut out of it.
#define STATE_WIDENED_ALPHA(uv, w) max( \
	max( \
		max(texture(TEXTURE, (uv) - vec2((w).x, 0.0)).a, \
			texture(TEXTURE, (uv) + vec2((w).x, 0.0)).a), \
		max(texture(TEXTURE, (uv) - vec2(0.0, (w).y)).a, \
			texture(TEXTURE, (uv) + vec2(0.0, (w).y)).a)), \
	max( \
		max(texture(TEXTURE, (uv) - (w) * 0.7071).a, \
			texture(TEXTURE, (uv) + (w) * 0.7071).a), \
		max(texture(TEXTURE, (uv) + vec2((w).x, -(w).y) * 0.7071).a, \
			texture(TEXTURE, (uv) + vec2(-(w).x, (w).y) * 0.7071).a)))


float state_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


// Fire and ice on the body itself.
//
// `near` is the *minimum* alpha of the four neighbours, so it falls only where a
// texel touches open air. Both shaders already sample those four for their
// outline, which wants the maximum - the same samples answer both questions and
// neither pays for the other.
vec3 state_body(vec3 body, vec2 uv, vec2 px, float body_alpha, float near) {
	// One hash per source texel, shared by both effects. Stable across frames on
	// purpose: raising `burn` must set *more* of the body alight rather than
	// reshuffle which parts of it are alight, or a burning enemy shimmers
	// instead of burning. Same reasoning as the blood stain's speckle.
	float grain = state_hash(floor(uv / max(px, vec2(0.0001))) + vec2(state_seed));

	if (burn > 0.001) {
		// Heat gathers upward. `1.0 - uv.y` is the top of the sprite, and the
		// ceiling is deliberately under one: at full burn a little over half the
		// top texels are ember and the rest is still the enemy. A body entirely
		// replaced by fire is a fireball, and the player has lost the silhouette
		// they were reading.
		float lift = 1.0 - uv.y;
		float reach = burn * (0.20 + 0.34 * lift);
		float ember = step(grain, reach);
		// Not every ember at once: each breathes on its own phase, so the fire
		// moves without any texel ever changing which texel it is.
		float flicker = 0.62 + 0.38 * sin(TIME * 8.5 + grain * 27.0);
		body = mix(body, burn_colour.rgb * flicker,
			ember * burn_colour.a * body_alpha);
	}

	if (frost > 0.001) {
		// Ice arrives at the edges and works inward, which is both what frost
		// does and what makes a half-frozen enemy readable: the silhouette rimes
		// first, so the shape is what changes colour rather than the middle.
		float rim_in = 1.0 - near;
		float ice = step(grain, frost * (0.34 + 0.92 * rim_in));
		body = mix(body, frost_colour.rgb, ice * frost_colour.a * body_alpha);
		// And the whole body cools a little. That is the part that says
		// "this one is slowed" at a glance rather than on inspection, and it is
		// deliberately weak - the speckle is the effect, this is the hint.
		body = mix(body, frost_colour.rgb, frost * 0.16 * body_alpha);
	}
	return body;
}


// A shiny variant, as metal rather than as tint.
//
// The Spirit Companion system asks the player to find these, and a flat colour
// wash was what marked them until 2026-09-01 - which is the same wrong language
// this whole file exists to replace, and worse here than anywhere: a shiny is a
// thing the player is *hunting*, so it has to be recognisable across a field at
// a glance and unmistakable once it is close.
//
// Two effects, and both are quantised to source texels so nothing here softens
// a pixel edge:
//
//   - a hard-edged band that travels the body on the diagonal, hue-rotated
//     along its width so it reads as iridescence rather than as a highlight;
//   - a scattering of single-texel glints, each on its own phase.
//
// The prism is mixed *toward* the variant's own colour rather than used raw. A
// full rainbow is a sticker; a rainbow pulled most of the way to one hue is a
// surface that catches light, which is what a shiny is meant to look like.
vec3 state_shine(vec3 body, vec2 uv, vec2 px, float body_alpha) {
	if (shine <= 0.001) {
		return body;
	}
	vec2 texel = floor(uv / max(px, vec2(0.0001)));
	// Texel coordinates rather than UV, so the band has hard edges on the art's
	// own pixels and does not resample into a gradient at any zoom.
	float phase = fract((texel.x + texel.y) * 0.055 - TIME * 0.42);
	float band = step(phase, 0.14);
	// The classic cosine palette, offset by where in the band this texel sits.
	vec3 prism = 0.5 + 0.5 * cos(6.28318
		* (vec3(0.0, 0.33, 0.67) + vec3(phase * 3.4)));
	vec3 lit = mix(shine_colour.rgb, prism, 0.45);

	float glint_hash = state_hash(texel + vec2(7.7, 13.1));
	float glint = step(0.986, glint_hash)
		* max(sin(TIME * 3.1 + glint_hash * 44.0), 0.0);

	float lift = clamp(band * 0.62 + glint * 0.95, 0.0, 1.0);
	return mix(body, lit, lift * shine * shine_colour.a * body_alpha);
}


// A body coming apart, rather than a body becoming see-through.
//
// Death was `modulate.a` counting down, which is the flattest thing a death can
// be: the enemy turns into a ghost of itself and then is not there. What reads
// as *destroyed* is the body losing pieces - and pixel art is already made of
// pieces, so the material only has to decide which ones go and in what order.
//
// Three decisions, and each is doing a job:
//
//   - **Bottom first.** A thing that is falling comes apart from underneath. It
//     also keeps the head - the readable part - longest, so the player can still
//     tell what died while it is dying.
//   - **The texels about to go flare** before they leave. Without that, texels
//     simply stop existing, which reads as a rendering fault rather than as an
//     end. The flare is what makes it look burned away.
//   - **The colour is what killed it.** `dissolve_colour` is set from the body's
//     own last condition - embers if it was alight, rime if it was frozen - so a
//     death says how it happened without a single extra effect.
//
// Uses the same texel hash as fire and frost, offset. Reusing it means a burning
// body's embers and its dissolve pick the same pixels in the same order, which
// looks like one thing finishing rather than two effects overlapping.
vec4 state_dissolve(vec4 painted, vec2 uv, vec2 px) {
	if (dissolve <= 0.001) {
		return painted;
	}
	vec2 texel = floor(uv / max(px, vec2(0.0001)));
	float grain = state_hash(texel + vec2(state_seed + 3.0));
	float lift = 1.0 - uv.y;
	// Above one at the bottom so the feet are fully gone well before the end,
	// and exactly one at the top so nothing is left behind at full dissolve.
	float threshold = clamp(dissolve * (1.45 - 0.45 * lift), 0.0, 1.0);
	float gone = step(grain, threshold);
	float about_to = step(grain, threshold + 0.13) * (1.0 - gone);
	painted.rgb = mix(painted.rgb, dissolve_colour.rgb,
		about_to * dissolve_colour.a);
	painted.a *= 1.0 - gone;
	return painted;
}


// The wind-up tell, on the rim.
//
// **On the rim rather than on the body, and that is the whole design.** A body
// tint on the third enemy back is invisible behind the two in front, and the
// tell is the one thing in either of these shaders that a player has to read in
// time rather than merely notice. A silhouette survives a crowd.
//
// It also *charges*: the ring widens and brightens as the wind-up runs, so how
// long is left is legible from how thick the edge is. That is a timer the player
// never has to look away from the fight to read.
vec4 state_telegraph(vec4 painted, float widened_alpha, float body_alpha) {
	float ring = max(widened_alpha - body_alpha, 0.0);
	// Fast enough to read as urgency, slow enough not to strobe. A body that
	// flashes at the frame rate is a body a player stops looking at - and one
	// that spends half its pulse nearly invisible is a tell that is missable on
	// exactly the frames it is trying to warn about, so the trough is shallow.
	float beat = 0.82 + 0.18 * sin(TIME * 24.0);

	// **`telegraph` sets the width, not the brightness.** It was doing both, and
	// with `beat` on top that made three sub-one factors multiplied together: a
	// tell at its floor rendered at 0.19 opacity - measured off a sheet - which
	// is a faint smudge rather than a warning. What thickens says *how long is
	// left*; what the player has to see at once is that a rim is there at all.
	float charge = clamp(ring * mix(0.65, 1.0, telegraph) * beat, 0.0, 1.0)
		* telegraph_colour.a;

	// **Composited, not mixed.** `mix(painted, vec4(colour, 1.0), charge)` looks
	// right and is wrong wherever `painted` is transparent black, which is
	// exactly where a rim lives: it lerps the *colour* toward black by the same
	// factor it lerps the alpha, so the rim comes out at charge squared. At a
	// charge of 0.6 that is a third of the intended brightness, and the tell
	// rendered as a dim brown smudge nobody would read as urgent.
	//
	// Straight-alpha source-over instead: the new alpha is the larger of the
	// two, and the colour is weighted by how much of that alpha this rim
	// contributes. Over open air that is all of it, so the rim is its own full
	// colour; over the body's own edge it tints rather than replaces.
	float shown = max(painted.a, charge);
	painted.rgb = mix(painted.rgb, telegraph_colour.rgb,
		charge / max(shown, 0.0001));
	painted.a = shown;
	return painted;
}


// The guard lives here rather than at each call site, so the eight samples are
// paid for only while something is actually winding up - and so neither shader
// can forget the guard and quietly cost every walker eight taps a frame.
#define STATE_APPLY_TELEGRAPH(painted, uv, px, body_alpha) \
	if (telegraph > 0.001) { \
		painted = state_telegraph(painted, \
			STATE_WIDENED_ALPHA(uv, (px) * telegraph_width * telegraph), \
			body_alpha); \
	}
