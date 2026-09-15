shader_type canvas_item;

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
// **It is a look and never a number.** Nothing about damage, targeting, aggro,
// drops or collection reads any of this; turn every uniform to zero and the
// fight is identical. That is the same bound the fog, the tower styles, the
// hides and the menu's holograms are all held to.
//
// **Additive over the art, never a replacement.** `COLOR` arrives carrying the
// day tint, the fog's dimming and whatever else has graded this sprite, and the
// art is multiplied by it exactly as an unshaded draw would before anything is
// added. So no value here can darken a creature or take its grading off - the
// mistake this project has paid for twice, once on Yuri's tail and once on the
// menu's frame.

// How strongly this creature is marked, 0 to 1. A champion sits near 0.25, a
// rare animal near 0.4, a shiny near 0.85 and a legendary shiny at 1.
uniform float rank : hint_range(0.0, 1.0) = 0.0;
// The rarity's own colour. The rim and the tint are both made of it.
uniform vec4 rarity : source_color = vec4(0.6, 0.8, 1.0, 1.0);
// How much of the rarity colour washes into the art. Deliberately small: a
// creature the player cannot recognise is worse than one they cannot rank.
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
	// Multiplied by the colour handed in, never assigned over it: that is how
	// the scene's own grading reaches the pixel.
	vec4 lit = art * COLOR;
	if (rank <= 0.001 || art.a <= 0.003) {
		COLOR = lit;
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
		// second slower wave keeps it off a single beat.
		float scan = 0.5 + 0.5 * sin((UV.y - clock * (0.25 + 0.55 * shine)) * scan_lines);
		float breath = 0.78 + 0.22 * sin(clock * (1.6 + 2.4 * shine));

		// The tint is a wash toward the rarity's colour, strongest where the
		// art is already bright - so a dark animal stays dark and a highlight
		// carries the colour, which is what keeps the creature recognisable.
		float brightness = dot(lit.rgb, vec3(0.2126, 0.7152, 0.0722));
		lit.rgb = mix(lit.rgb, rarity.rgb * max(brightness, 0.12),
			tint_share * rank * art.a);

		float glow = rank * breath * (
			rim * rim_strength * (1.0 + shine)
			+ scan * scan_strength * (0.35 + 0.65 * shine) * art.a);
		lit.rgb += rarity.rgb * glow;
		COLOR = lit;
	}
}
