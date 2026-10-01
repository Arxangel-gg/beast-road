shader_type canvas_item;

// **The ground's scars, drawn as light** (owner, 2026-10-01: the depth map and
// the normal-and-roughness he asked about). The texture is `GroundScars`' depth
// map - grey is untouched ground, darker a dent, lighter a lip - filtered
// smooth.
//
// Its slope is a normal; the normal is lit from the sun's side, so a dent's
// near wall is in shadow and its far wall catches the light, and the lip
// thrown up round it the same. The floor of a dent is rough: grit that breaks
// up its shade. Untouched ground is exactly nothing - the overlay only exists
// where the ground was broken.

uniform vec2 light_dir = vec2(-0.55, -0.8);
uniform float strength = 1.0;

float grit(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// **Read on the ground art's own pixel grid**: a depth map read smoothly
	// over pixel-art ground reads as mist, so the read is snapped to steps a
	// fraction of a texel across and the shade is banded - a dent is drawn the
	// way the ground around it is drawn.
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec2 step_px = texel / 2.5;
	vec2 at = (floor(UV / step_px) + 0.5) * step_px;
	// Inline, not a helper: TEXTURE is not reachable from a function of ours.
	float here = texture(TEXTURE, at).r * 2.0 - 1.0;
	float dx = (texture(TEXTURE, at + vec2(texel.x, 0.0)).r - texture(TEXTURE, at - vec2(texel.x, 0.0)).r) * 2.0;
	float dy = (texture(TEXTURE, at + vec2(0.0, texel.y)).r - texture(TEXTURE, at - vec2(0.0, texel.y)).r) * 2.0;
	float broken = abs(here) + abs(dx) + abs(dy);
	if (broken < 0.01) {
		discard;
	}
	vec3 normal = normalize(vec3(-dx * 3.0, -dy * 3.0, 0.35));
	vec3 light = normalize(vec3(light_dir, 0.9));
	// Lit relative to flat ground, so untouched ground is exactly neither.
	float lambert = dot(normal, light) - dot(vec3(0.0, 0.0, 1.0), light);
	float dent = clamp(-here, 0.0, 1.0);
	// Roughness: grit on the floor of a dent.
	float rough = (grit(floor(at / step_px)) - 0.5) * dent * 0.45;
	// Occlusion: the deeper the dent, the less sky reaches its floor.
	float occlusion = dent * 0.55;
	float shade = lambert * 1.5 + rough - occlusion;
	// Banded, as the art is: six steps of shade.
	shade = floor(shade * 6.0 + 0.5) / 6.0;
	if (abs(shade) < 0.01) {
		discard;
	}
	if (shade < 0.0) {
		COLOR = vec4(0.05, 0.035, 0.025, clamp(-shade, 0.0, 0.7) * strength);
	} else {
		// The lit wall or lip: a warm lift, never a haze.
		COLOR = vec4(0.95, 0.82, 0.6, clamp(shade * 0.55, 0.0, 0.22) * strength);
	}
}
