shader_type canvas_item;

// The carved border, lit from inside.
//
// **Owner, 2026-09-15: "make the frame also holographic".** The obvious reading
// of that word - a cyan tint and hard scanlines - would put a science-fiction
// interface around a grimdark fantasy game, and `title_hologram.gdshader` made
// the same call about the wordmark a day earlier: what a hologram lends is its
// *behaviour*, not its palette. So the stone keeps its own colour and gains
// three things it does not have: a faint scan that drifts across it, a rim that
// catches light along the carving's edges, and a slow instability in both.
//
// **Additive over the art, never a replacement for it.** `COLOR` arrives
// carrying the per-piece tint `MenuFrame.light_at` computed - the scene's own
// light plus whatever the sheen and the press-wave are adding there - and this
// multiplies the art by it exactly as an unshaded draw would, then adds. So no
// value of any uniform here can darken a pixel of the border, which is the
// bound `UiJuice`, `MenuFrame` and `MenuArcs` are all held to. Checked by
// `menu_frame_check`, which reads the blend out of this file.

// How strong the holographic pass is over the stone.
uniform float strength : hint_range(0.0, 1.0) = 0.5;
// How many scan bands cross the screen, and how fast they drift.
uniform float lines : hint_range(4.0, 400.0) = 120.0;
uniform float drift : hint_range(0.0, 2.0) = 0.06;
// The light the hologram is made of, before the scene's own colour.
uniform vec3 glow = vec3(0.55, 0.80, 1.0);
// The most light this may add anywhere. Above this the carving washes out and
// the border stops reading as stone.
uniform float ceiling : hint_range(0.0, 0.5) = 0.14;
uniform float clock = 0.0;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	// Multiplied by the colour handed in, never assigned over it: that is how
	// the per-piece tint reaches the pixel. See `beast_stub_fade.gdshader` for
	// the same note and the measurement behind it.
	vec4 lit = art * COLOR;

	// The scan drifts rather than sitting still, so the border reads as a
	// projection being refreshed rather than as a striped texture.
	float scan = 0.5 + 0.5 * sin((SCREEN_UV.y + clock * drift) * lines);
	// And it breathes: two rates, so there is no beat to catch.
	float unsteady = 0.82 + 0.12 * sin(clock * 1.7) + 0.06 * sin(clock * 4.3);

	// The rim: the carving's own alpha edge, found by how fast alpha falls off
	// rather than by an authored mask, so it follows whatever art is in the
	// frame. Cheap: four taps.
	vec2 step_uv = TEXTURE_PIXEL_SIZE;
	float around =
		texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a +
		texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a +
		texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a +
		texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a;
	float rim = clamp(art.a * 4.0 - around, 0.0, 1.0);

	float add = strength * unsteady * (0.35 * scan + 0.65 * rim) * ceiling;
	lit.rgb += glow * add * art.a;
	COLOR = lit;
}
