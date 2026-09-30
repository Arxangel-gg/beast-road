shader_type canvas_item;

// **Footprints fade in the shader** (2026-09-30), the way the ground blood
// does: `Tracks` rebuilds a chunk only when a print is laid into it, each
// vertex carries its print's birth and life in `UV`, and the field's clock
// arrives as one uniform. A print holds, then goes.

uniform float clock = 0.0;
uniform float hold = 0.4;

void fragment() {
	// UV: x is when the print was laid on the field's clock, y how long it lasts.
	float life = max(UV.y, 0.01);
	float t = clamp((clock - UV.x) / life, 0.0, 1.0);
	COLOR = vec4(COLOR.rgb, COLOR.a * (1.0 - smoothstep(hold, 1.0, t)));
}
