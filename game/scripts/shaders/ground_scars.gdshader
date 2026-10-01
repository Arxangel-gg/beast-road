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

float height_of(vec2 uv) {
	return texture(TEXTURE, uv).r * 2.0 - 1.0;
}

float grit(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float here = height_of(UV);
	float dx = height_of(UV + vec2(px.x, 0.0)) - height_of(UV - vec2(px.x, 0.0));
	float dy = height_of(UV + vec2(0.0, px.y)) - height_of(UV - vec2(0.0, px.y));
	float broken = abs(here) + abs(dx) + abs(dy);
	if (broken < 0.004) {
		discard;
	}
	vec3 normal = normalize(vec3(-dx * 3.0, -dy * 3.0, 0.35));
	vec3 light = normalize(vec3(light_dir, 0.9));
	// Lit relative to flat ground, so untouched ground is exactly neither.
	float lambert = dot(normal, light) - dot(vec3(0.0, 0.0, 1.0), light);
	float dent = clamp(-here, 0.0, 1.0);
	// Roughness: grit on the floor of a dent, on a finer grid than the map.
	float rough = (grit(floor(UV / px * 6.0)) - 0.5) * dent * 0.5;
	// Occlusion: the deeper the dent, the less sky reaches its floor.
	float occlusion = dent * 0.45;
	float shade = lambert * 1.4 + rough - occlusion;
	float alpha = clamp(abs(shade), 0.0, 0.8) * strength;
	vec3 colour = shade < 0.0 ? vec3(0.06, 0.045, 0.035) : vec3(1.0, 0.95, 0.85);
	COLOR = vec4(colour, alpha * (shade < 0.0 ? 1.0 : 0.5));
}
