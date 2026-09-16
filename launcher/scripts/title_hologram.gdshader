shader_type canvas_item;

// The wordmark, lit from inside.
//
// Owner brief, 2026-09-14: the title should read as holographic. The trap in
// that word is the obvious reading - scanlines and a cyan tint - which would
// put a science-fiction interface on the front of a grimdark fantasy game and
// fight everything behind it.
//
// So what is taken from a hologram is its *behaviour* and not its palette: a
// sheen that travels across the letters, a colour that separates slightly at
// the edges as though the image were refracting, and a faint instability. The
// colours stay the wordmark's own. It should look like gold leaf catching a
// light that is moving, not like a computer.
//
// Everything is driven by `clock`, fed from the menu, so it stops when the menu
// does rather than running on a clock of its own.

uniform float clock = 0.0;
// 0 turns the whole effect off and returns the art untouched, which is what a
// player who dislikes it gets from the settings.
uniform float strength : hint_range(0.0, 1.0) = 1.0;
// How wide the travelling sheen is, as a fraction of the wordmark.
uniform float sheen_width : hint_range(0.02, 0.6) = 0.17;
// How far the channels separate at the edges, in UV.
uniform float split : hint_range(0.0, 0.02) = 0.0035;
uniform vec4 sheen_tint : source_color = vec4(1.0, 0.96, 0.82, 1.0);

void fragment() {
	vec4 art = texture(TEXTURE, UV);

	// **Refraction, not chromatic aberration for its own sake.** The channels
	// are pulled apart along the diagonal and only where the art already has an
	// edge, so the middle of a stroke stays solid gold and only its rim shows
	// the separation.
	vec2 drift = vec2(split, split * 0.6) * strength;
	float red = texture(TEXTURE, UV + drift).r;
	float blue = texture(TEXTURE, UV - drift).b;
	float edge = clamp(abs(red - art.r) + abs(blue - art.b), 0.0, 1.0);
	art.r = mix(art.r, red, 0.55 * strength);
	art.b = mix(art.b, blue, 0.55 * strength);

	// **The sheen.** A band travelling along the diagonal, wrapping with a long
	// dwell between passes - a sheen that sweeps constantly reads as a loading
	// bar rather than as light.
	float along = UV.x * 0.75 + UV.y * 0.25;
	float cycle = fract(clock * 0.11);
	// Most of the cycle is spent off the left edge, so the pass is an event.
	float head = cycle * 2.2 - 0.6;
	float band = 1.0 - smoothstep(0.0, sheen_width, abs(along - head));
	band *= band;

	// A slow breath under it, so the letters are never completely static even
	// between passes.
	float breath = 0.5 + 0.5 * sin(clock * 0.7);

	vec3 lit = art.rgb;
	lit += sheen_tint.rgb * band * 0.65 * strength;
	lit += sheen_tint.rgb * edge * (0.10 + 0.10 * breath) * strength;
	// The sheen lifts the alpha very slightly at the rim, which is what gives
	// the letters a hot edge as the light crosses them.
	art.a = clamp(art.a + band * edge * 0.35 * strength, 0.0, 1.0);

	art.rgb = mix(art.rgb, lit, strength);
	COLOR = art * COLOR;
}
