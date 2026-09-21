// The Warden's look: two dyes, keyed on the bands the art is painted in.
//
// Owner ruling, 2026-09-21: character customization is approved, and its bound
// is that it may change *nothing but how the Warden looks* - no attribute, no
// stat, no unlock, no currency. So it is a shader over the painted sprite and
// nothing else: the same body, the same frames, the same numbers, dyed.
//
// Two dyes rather than a paper doll, and that is a budget decision recorded in
// `docs/NEXT_SESSION_PLAN.md`: the Warden is eight directions of idle, walk,
// sprint, dash, death and four attack sheets, and the PixelLab character they
// came from no longer exists, so every *drawn* option is every sheet again. A
// dye reaches every frame of every sheet for free, and the Hold, the portraits
// and a co-op partner all wear it through the same include.
//
// **Keyed on hue bands, not on masks.** The steel and the cloak are painted in
// one teal-grey band and the sash and banner in one saturated red; bone, the
// lantern's orange and the gold trim sit outside both. Soft edges on every band
// so a dyed pixel never sits beside an undyed one of the same cloth.
//
// ## Why an include rather than a copy
//
// The hero sprite already wears `blood_stain.gdshader`, and a sprite has one
// material, so the dye has to live inside that shader; the Hold's figures and
// the portraits wear nothing, so they need a shader of their own. Two copies of
// one recolour would drift the first time either was tuned, which is the rule
// `actor_state.gdshaderinc` was written under.

uniform float look_cloak : hint_range(-0.5, 0.5) = 0.0;
uniform float look_sash : hint_range(-0.5, 0.5) = 0.0;

vec3 look_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 look_to_rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

vec3 warden_look(vec3 rgb) {
	if (abs(look_cloak) < 0.0005 && abs(look_sash) < 0.0005) {
		return rgb;
	}
	vec3 hsv = look_to_hsv(rgb);
	// The teal-steel band: hue 160 to 225 degrees, anything with a little colour
	// in it. Bone and the plain greys have none and stay bone and grey.
	float cloak = smoothstep(0.43, 0.47, hsv.x) * (1.0 - smoothstep(0.60, 0.64, hsv.x))
		* smoothstep(0.10, 0.18, hsv.y);
	// The red band: within a few degrees of zero, either side of the wrap, and
	// saturated. The lantern's orange (hue 20 to 40) and the leather (hue 20,
	// less saturated) are outside it.
	float red = 1.0 - smoothstep(0.035, 0.055, hsv.x);
	float wrapped = smoothstep(0.94, 0.96, hsv.x);
	float sash = max(red, wrapped) * smoothstep(0.45, 0.60, hsv.y);
	hsv.x = fract(hsv.x + look_cloak * cloak + look_sash * sash);
	return look_to_rgb(hsv);
}
