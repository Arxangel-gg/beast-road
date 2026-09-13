shader_type canvas_item;

// The fog of war's veil (2026-09-12). The texture is `FogOfWar`'s own image:
// luminance is how well a cell has ever been seen, alpha is how well it is
// seen now. Drawn stretched over the field with a bilinear read, so a cell
// edge is a soft gradient rather than a tile, and smoothed once more here.

uniform float unexplored = 0.93;
uniform float explored = 0.5;
uniform vec4 tint : source_color = vec4(0.02, 0.03, 0.06, 1.0);

void fragment() {
	vec4 fog = texture(TEXTURE, UV);
	float seen = smoothstep(0.12, 0.85, fog.a);
	float known = smoothstep(0.08, 0.9, fog.r);
	float dark = mix(unexplored, explored, known) * (1.0 - seen);
	COLOR = vec4(tint.rgb, dark);
}
