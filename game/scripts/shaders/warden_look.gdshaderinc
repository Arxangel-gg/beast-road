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
uniform float look_leather : hint_range(-0.5, 0.5) = 0.0;
// The skin tone (owner, 2026-09-26). The body sheets carry a mask beside them
// - `<state>_skin.png`, white where the painting is skin, written by
// `tools/warden_rig/pack.py` from the frame's colour *and* its bones, because
// the boots and the belt are painted in the skin's own hue - and the skin is
// turned so the painted skin's mean (`skin_from`) lands on the chosen tone
// (`skin_to`): multiplied where the tone is darker, multiplied in the inverted
// space where it is lighter, so a highlight compresses toward white rather than
// clipping to it. A turn rather than a ramp, so the painting's own shading
// survives at every tone; a ramp tried beside it turned every tone grey.
// `WardenLook.turn_skin_channel` is the same rule for the gate. No mask (the
// painted Warden, the Hold's figures) samples black, and nothing turns.
uniform sampler2D skin_mask : filter_nearest, hint_default_black;
uniform vec3 skin_from = vec3(0.5);
uniform vec3 skin_to = vec3(0.5);

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

// `art` is the painting; `rgb` is what has already been done to it.
//
// **The bands are read off the art and the turn is applied to the colour**, and
// keeping those two apart is the whole of this function being correct in
// company. `Hero._apply_party_colour` sets `sprite.modulate` to a 46% lerp
// toward the seat colour in co-op, `COLOR` already carries modulate when
// `fragment()` opens, and these bands select by *hue* - so read off the tinted
// colour, seat 1 (Red) lost its cloak band entirely and grew its sash band by
// 364%, which smears the sash dye across the steel and makes the cloak dye do
// nothing at all. Measured over the real south idle frame; only seat 2 (Blue)
// survived. Solo was never affected, because the tint only shows with a party.
//
// It is the same separation `blood_stain.gdshader` already insists on for the
// blood: what a pixel *is* comes from the art, what is done to it comes from
// the state.
//
// `uv` reads the skin mask, which shares the sheet's layout texel for texel.
vec3 warden_look(vec3 rgb, vec3 art, vec2 uv) {
	float skin = 0.0;
	if (distance(skin_to, skin_from) > 0.0005 || abs(look_leather) > 0.0005) {
		skin = texture(skin_mask, uv).a;
		vec3 darker = rgb * skin_to / max(skin_from, vec3(0.001));
		vec3 lighter = vec3(1.0) - (vec3(1.0) - rgb) * (vec3(1.0) - skin_to)
			/ max(vec3(1.0) - skin_from, vec3(0.001));
		vec3 turned = clamp(mix(darker, lighter, step(skin_from, skin_to)), 0.0, 1.0);
		rgb = mix(rgb, turned, skin);
	}
	if (abs(look_cloak) < 0.0005 && abs(look_sash) < 0.0005 && abs(look_leather) < 0.0005) {
		return rgb;
	}
	vec3 mask = look_to_hsv(art);
	vec3 hsv = look_to_hsv(rgb);
	// The teal-steel band: hue 160 to 225 degrees, anything with a little colour
	// in it. Bone and the plain greys have none and stay bone and grey.
	float cloak = smoothstep(0.43, 0.47, mask.x) * (1.0 - smoothstep(0.60, 0.64, mask.x))
		* smoothstep(0.10, 0.18, mask.y);
	// The red band: within a few degrees of zero, either side of the wrap, and
	// saturated. The lantern's orange (hue 20 to 40) and the leather (hue 20,
	// less saturated) are outside it.
	float red = 1.0 - smoothstep(0.035, 0.055, mask.x);
	float wrapped = smoothstep(0.94, 0.96, mask.x);
	float sash = max(red, wrapped) * smoothstep(0.45, 0.60, mask.y);
	// The leather band (2026-09-23): hue 21 to 32 degrees, saturated, and dark.
	// Measured on the idle sheet at s 0.78, v 0.39; the lantern's orange sits in
	// the same hues but bright (v 0.63 and up), so the value edge keeps it lit.
	// Never on skin: the skin's own shadows sit in the leather's hue, and a
	// dyed shin of shadow under the jaw is the dye leaking onto the Warden.
	float leather = smoothstep(0.052, 0.062, mask.x) * (1.0 - smoothstep(0.088, 0.098, mask.x))
		* smoothstep(0.45, 0.58, mask.y) * (1.0 - smoothstep(0.46, 0.56, mask.z)) * (1.0 - skin);
	hsv.x = fract(hsv.x + look_cloak * cloak + look_sash * sash + look_leather * leather);
	return look_to_rgb(hsv);
}
