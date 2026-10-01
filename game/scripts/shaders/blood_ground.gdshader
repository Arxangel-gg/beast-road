shader_type canvas_item;

// **Ground blood fades in the shader** (owner, 2026-09-25: "shader fade for
// ground blood"). `BloodField` used to recompute every mark's alpha and colour
// and hand the renderer a fresh triangle array ten times a second for as long
// as any mark was fading - and in the Compatibility renderer a triangle array
// is a new buffer on every redraw. Now the mesh is rebuilt only when the set of
// marks changes, and the fading is this: each vertex carries its mark's birth
// and life in `UV` and its shade and shape in `COLOR`, and the field's own
// clock arrives as one uniform.
//
// The arithmetic is the one `BloodField._draw_measured` did per mark, moved
// here unchanged: it holds, then goes, and darkens as it dries.

// The field's own clock, advanced by the frame's delta times the rain's wash -
// so a mark laid in the rain still ages faster, and a frozen field stays still.
uniform float clock = 0.0;
uniform float hold = 0.45;
uniform float ground_alpha = 0.68;
uniform vec4 fresh : source_color = vec4(0.48, 0.06, 0.07, 1.0);
uniform vec4 dry : source_color = vec4(0.24, 0.07, 0.08, 1.0);
// Seconds of the field's clock a mark takes to dry dark (2026-09-30). It was a
// share of the life, and a High mark lasts until extraction, so it would never
// have dried.
uniform float dry_seconds = 428.0;
// **Brutal** (owner, 2026-10-01: "Brutal blood is practically forever"). A
// Brutal mark never fades out: it settles from fresh to `settled` of its
// strength over `settle_seconds` and stays there, and on Brutal UV.y is the
// field's flood clock when the mark was laid rather than a life - a heavy flood
// thins it toward `wash_floor` over `wash_tau` of deep water and never further.
uniform float brutal = 0.0;
uniform float settled = 0.62;
uniform float settle_seconds = 900.0;
uniform float wash_clock = 0.0;
uniform float wash_tau = 900.0;
uniform float wash_floor = 0.5;

void fragment() {
	// UV: x is when the mark was laid on the field's clock, y how long it lasts
	// (on Brutal, the flood clock it was laid at).
	// COLOR: r is the mark's own shade roll, a is how solid this part of the
	// blob is (the core, the feather, the rim at nothing).
	float life = max(UV.y, 0.01);
	float t = clamp((clock - UV.x) / life, 0.0, 1.0);
	float alpha = ground_alpha * (1.0 - smoothstep(hold, 1.0, t)) * COLOR.a;
	if (brutal > 0.5) {
		float age = max(clock - UV.x, 0.0);
		float washed = clamp(1.0 - exp(-max(wash_clock - UV.y, 0.0) / max(wash_tau, 1.0)), 0.0, 1.0);
		alpha = ground_alpha * mix(1.0, settled, smoothstep(0.0, settle_seconds, age))
			* mix(1.0, wash_floor, washed) * COLOR.a;
	}
	float drying = clamp((clock - UV.x) / max(dry_seconds, 1.0), 0.0, 1.0) * 0.85 + COLOR.r * 0.15;
	COLOR = vec4(mix(fresh.rgb, dry.rgb, drying), alpha);
}
