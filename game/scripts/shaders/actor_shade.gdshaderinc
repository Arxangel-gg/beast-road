// Light direction on a painted body, shared by every actor shader (2026-09-25).
//
// Core Keeper's things shade with the light: a torch on the left lights the
// left of a tower and leaves its right in shadow. Real normal maps would be
// every frame of every sprite drawn a second time; this reads the relief off
// the painting itself - how its brightness and its silhouette climb and fall
// across a few pixels - which is what the auto-normal tools do, and it follows
// every frame for free because it reads the frame being drawn.
//
// It lived inside `actor_polish` for the tower pilot (2026-09-23). The owner
// asked for bodies too, and a body wears `blood_stain` - so the code moved here
// and both shaders include it, because two copies of one light would drift the
// first time either was tuned.
//
// **At zero it is the engine's own formula**, measured byte-identical by
// `tools/shade_probe.gd`, so a material that is never dressed looks exactly as
// it did. `ActorShade.dress` is the one place that turns it up.
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
// became a ridge and the tower came out embossed rather than lit.
float relief_of(vec4 c) {
	return c.a * (0.8 + 0.2 * dot(c.rgb, vec3(0.299, 0.587, 0.114)));
}

// A macro rather than a function, because `TEXTURE` cannot be handed to a
// function in this shading language - it asserts and "continues", and the
// shader then loads and draws wrong. `tex` is the texel being drawn.
#define SHADE_NORMAL(tex, uv, px) \
	if (shade_strength > 0.001) { \
		vec2 shade_slope = vec2(0.0); \
		for (int shade_step = 1; shade_step <= 2; shade_step++) { \
			vec2 shade_w = (px) * shade_reach * float(shade_step) * 0.5; \
			shade_slope.x += relief_of(texture(TEXTURE, (uv) - vec2(shade_w.x, 0.0))) \
				- relief_of(texture(TEXTURE, (uv) + vec2(shade_w.x, 0.0))); \
			shade_slope.y += relief_of(texture(TEXTURE, (uv) - vec2(0.0, shade_w.y))) \
				- relief_of(texture(TEXTURE, (uv) + vec2(0.0, shade_w.y))); \
		} \
		float shade_hot = max((tex).r, max((tex).g, (tex).b)); \
		float shade_spread = shade_hot - min((tex).r, min((tex).g, (tex).b)); \
		float shade_glow = smoothstep(0.6, 0.85, shade_hot) * smoothstep(0.25, 0.5, shade_spread); \
		NORMAL = vec3(normalize(vec3(shade_slope * 0.5 * shade_relief, 1.0)).xy \
			* (1.0 - shade_glow), 1.0); \
	}

// The engine's own light, times how squarely a facet faces it. A light's
// direction is mostly across the canvas unless it stands high: a torch at the
// roadside leans hard, and a tower's own light - raised to stand above it
// (`TOWER_LIGHT_HEIGHT`) - lights it nearly flat. A directional light is the
// sun's relief and nothing else: it lights no flat surface at all and only
// brightens what faces it and darkens what faces away.
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
