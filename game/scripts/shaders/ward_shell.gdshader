shader_type canvas_item;
render_mode blend_add, unshaded;

// **The ward as a shell of light round the Warden** (owner, 2026-10-01: "a
// shield visualizer that is juicy and aesthetically appealing and affected by
// amount of shield visually"). Drawn on a quad by `WardShell`; the unit disc of
// that quad is the shell.
//
// Everything that reads as *how much* rides `strength` - the ward's share of
// the most a Warden may hold: a thin rim and faint seams at a sliver, a thick
// bright rim, lit cells and a sweeping band at the top. `integrity` is what is
// left of the ward the shell last rose to, and the cells go dark one by one as
// it falls, so a shell being worn through looks worn through. `flash` and
// `hit_dir` are a blow landing on it; `rise` is a ward just granted. Additive,
// so it can only add light and never hides the body it stands round.

uniform vec4 tint : source_color = vec4(0.5, 0.82, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float presence : hint_range(0.0, 1.0) = 0.0;
uniform float integrity : hint_range(0.0, 1.0) = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 hit_dir = vec2(0.0, 0.0);
uniform float rise : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The nearest hex cell: its local offset in xy and its id in zw.
vec4 hex_cell(vec2 p) {
	const vec2 s = vec2(1.0, 1.7320508);
	vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h = vec4(p - hc.xy * s, p - (hc.zw + 0.5) * s);
	return dot(h.xy, h.xy) < dot(h.zw, h.zw) ? vec4(h.xy, hc.xy) : vec4(h.zw, hc.zw + 0.5);
}

// 0 at a cell's middle, 0.5 on its edge.
float hex_edge(vec2 p) {
	const vec2 s = vec2(1.0, 1.7320508);
	p = abs(p);
	return max(dot(p, s * 0.5), p.x);
}

// The quad is drawn `HALO` times the shell, so a glow can stand outside it.
const float HALO = 1.16;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * HALO;
	float d = length(p);
	float inside = 1.0 - smoothstep(0.95, 1.0, d);
	float z = sqrt(max(1.0 - d * d, 0.0));
	float fresnel = pow(1.0 - z, 2.4);

	// The seams curve round the dome rather than lying flat on the screen, and
	// are finer the more ward there is.
	vec2 q = p / (0.42 + z) * (3.0 + strength * 2.2) + vec2(seed, TIME * 0.11);
	vec4 cell = hex_cell(q);
	float edge = hex_edge(cell.xy);
	float seam = smoothstep(0.41, 0.49, edge);
	float r = hash(cell.zw + seed);
	float alive = smoothstep(r - 0.06, r + 0.06, integrity * 1.06);
	float twinkle = 0.55 + 0.45 * sin(TIME * 2.3 + r * 6.2832);
	float glint = smoothstep(0.86, 1.0, sin(TIME * 0.9 + r * 31.0)) * strength;

	// A band of light climbing the shell, brighter the more there is.
	float band_y = p.y + 1.25 - fract(TIME * 0.32 + seed) * 2.5;
	float sweep = exp(-band_y * band_y * 18.0) * (0.25 + 0.75 * strength);

	// A blow: a bright core where it landed and a ripple running away from it.
	vec2 struck = hit_dir * 0.92;
	float from_hit = length(p - struck);
	float ring_gap = (from_hit - (1.0 - flash) * 1.7) * 7.0;
	float ripple = exp(-ring_gap * ring_gap) * flash;
	float core = exp(-from_hit * 4.5) * flash * flash;

	// A gain: a rim running in from the edge.
	float pulse_gap = (d - (1.0 - rise)) * 8.0;
	float pulse = exp(-pulse_gap * pulse_gap) * rise;

	// Sparks riding the rim: one at a sliver, up to five at the ceiling.
	float motes = 0.0;
	for (int k = 0; k < 5; k++) {
		float on = smoothstep(float(k) * 0.2 - 0.05, float(k) * 0.2 + 0.05, strength);
		float angle = TIME * (0.9 + 0.17 * float(k)) * (k % 2 == 0 ? 1.0 : -1.0)
			+ float(k) * 1.2566 + seed;
		vec2 at = vec2(cos(angle), sin(angle)) * 0.97;
		float gap = length(p - at);
		motes += on * (exp(-gap * gap * 900.0) + 0.35 * exp(-gap * gap * 90.0));
	}

	// The glow outside the shell, and where it stands on the ground.
	float outside = max(d - 1.0, 0.0);
	float halo = exp(-outside * outside * 260.0) * (1.0 - inside) * (0.25 + 0.75 * strength);
	float foot_y = (p.y - 0.97) * 13.0;
	float footing = exp(-foot_y * foot_y - p.x * p.x * 2.4) * (0.15 + 0.45 * strength);
	// Nothing reaches the quad's own edge, which would draw as a straight cut.
	float frame = (1.0 - smoothstep(HALO - 0.1, HALO, abs(p.x))) * (1.0 - smoothstep(HALO - 0.1, HALO, abs(p.y)));

	float fill = 0.03 + 0.07 * strength;
	float rim = fresnel * (0.45 + 1.25 * strength);
	float cells = seam * alive * (0.15 + 0.85 * strength) * (0.18 + 0.82 * fresnel + 0.25 * twinkle);
	float lit_cell = (1.0 - seam) * alive * glint * 0.3 * fresnel;
	float alpha = (fill + rim + cells * 0.65 + lit_cell + sweep * 0.2
		+ ripple * 1.1 + core * 0.7 + pulse * 0.9) * inside
		+ halo * 0.55 + footing + motes * (0.6 + 0.4 * presence);
	alpha *= presence * frame;

	float white = clamp(rim * 0.35 + ripple + core + pulse * 0.6 + glint * 0.4 + motes, 0.0, 1.0);
	vec3 colour = mix(tint.rgb, vec3(1.0), white * 0.65);
	COLOR = vec4(colour, clamp(alpha, 0.0, 1.0));
}
