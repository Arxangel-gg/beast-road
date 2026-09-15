shader_type canvas_item;
render_mode blend_add;

// What rank a creature is, said in light rather than in a label.
//
// **Owner brief, 2026-09-15:** "Elite and Champion enemies should have a hint of
// holographic-esque vfx juice as well, and rarer wildlife should have it as well
// slightly as well as a slight colour tint to indicate their rarity as well as
// having an outline aura too. Shinys should be super holographic and high
// contrast with awesome glorious vfx, especially legendary shinies."
//
// **One shader for all of it, at three amplitudes.** An elite, a rare animal and
// a legendary shiny are the same statement - *this one is not ordinary* - and
// two separate effects would drift apart the first time either was tuned. What
// changes between them is `rank`: a hint on a champion, a tint and a rim on a
// rare animal, and everything at once on a shiny.
//
// **This draws the light and never the creature**, which is the correction that
// makes the whole thing safe. `RankSheen` hangs a second sprite over the first
// wearing the same texture, and the first cut had this shader output the art
// itself plus a glow - which, over the creature, is an opaque copy of it. That
// hides whatever `ActorState`'s polish is doing underneath: the burning, the
// chill, the wet. The overlay is `blend_add` now and emits *only* the addition,
// so the creature and every status on it show through untouched.
//
// A tint therefore has to be made of added light rather than of a wash toward a
// colour - a wash can take a channel down and nothing here may darken a pixel.
// On this game's dark hides, adding the rarity's colour in proportion to the
// art's own brightness reads as exactly the tint the brief asks for.

// How strongly this creature is marked, 0 to 1. A champion sits near 0.26, a
// rare animal near 0.34, a shiny near 0.8 and a legendary shiny at 1.
uniform float rank : hint_range(0.0, 1.0) = 0.0;
// The rarity's own colour. Everything here is made of it.
uniform vec4 rarity : source_color = vec4(0.6, 0.8, 1.0, 1.0);
// The even wash over the body, strongest where the art is already bright, so a
// dark animal stays dark and its highlights carry the colour.
uniform float tint_share : hint_range(0.0, 0.5) = 0.16;
// The aura on the silhouette's edge.
uniform float rim_strength : hint_range(0.0, 2.0) = 0.9;
// The holographic scan, and how many bands cross the sprite.
uniform float scan_strength : hint_range(0.0, 1.0) = 0.35;
uniform float scan_lines : hint_range(4.0, 200.0) = 46.0;
// Set for a shiny: the scan doubles, the rim sharpens and the whole thing
// breathes faster. This is the "super holographic, high contrast" half.
uniform float shine : hint_range(0.0, 1.0) = 0.0;
uniform float clock = 0.0;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	if (rank <= 0.001 || art.a <= 0.003) {
		// Nothing added at all. An ordinary creature must be pixel-identical to
		// one with no sheen on it, or the signal stops meaning anything.
		COLOR = vec4(0.0);
	} else {
		// The rim: found from how fast alpha falls away rather than from an
		// authored mask, so it follows whatever sprite it is put on. Four taps.
		vec2 step_uv = TEXTURE_PIXEL_SIZE * (1.0 + shine);
		float around =
			texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a +
			texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a +
			texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a +
			texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a;
		float rim = clamp(art.a * 4.0 - around, 0.0, 1.0);

		// The scan travels up the sprite rather than sitting on it, and a
		// second slower breath keeps it off a single beat.
		float scan = 0.5 + 0.5 * sin((UV.y - clock * (0.25 + 0.55 * shine)) * scan_lines);
		float breath = 0.78 + 0.22 * sin(clock * (1.6 + 2.4 * shine));

		// The wash rides the art's own brightness, so the creature's shape
		// survives being marked.
		float bright = dot(art.rgb, vec3(0.2126, 0.7152, 0.0722));

		float amount = rank * breath * art.a * (
			rim * rim_strength * (1.0 + shine)
			+ scan * scan_strength * (0.35 + 0.65 * shine)
			+ bright * tint_share);
		// Dimmed with whatever has dimmed the creature - the fog, the night,
		// a fade - because a glow that outlives its body is a light with
		// nothing under it. `COLOR` carries the inherited modulate.
		COLOR = vec4(rarity.rgb * amount * COLOR.a, art.a * COLOR.a);
	}
}
