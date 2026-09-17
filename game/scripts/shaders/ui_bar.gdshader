shader_type canvas_item;
render_mode blend_add, unshaded;

// The light inside a bar's fill.
//
// Owner, 2026-09-17: *"give the progressbars on the battlefield UIs an animated
// game juicy procedural vfx shader effect so they're animated and not static and
// super polished and aesthetically appealing. Should also include xp bar at the
// bottom too, as well as the act distance traveled bar at top center."*
//
// **Additive, like everything else this project puts over the interface.** The
// bound is `UiTint`'s and it is inherited rather than restated: an additive
// layer can only ever add light, so no reading on a bar can be made harder to
// see by it. A multiply could, and is not used.
//
// **The fill is a uniform, not a rectangle.** A `ProgressBar` draws its fill by
// stretching a `StyleBox`; there is no node on the fill to attach anything to,
// and a second `ColorRect` resized to match would be a layout write per bar per
// frame with a dozen bars on screen. So the skin covers the whole bar and the
// shader is told where the fill ends - one uniform, written when the value
// changes and not otherwise.
//
// **What it draws is a current rather than a shine.** Three things:
//
//  - **flow**, a slow travelling brightening along the fill, so the bar reads as
//    something held rather than something painted;
//  - **a head**, brightest just behind the fill's leading edge, which is the
//    part a player actually watches - it is where the number is;
//  - **a floor sheen**, a faint constant lift across the fill so an empty-ish
//    bar still reads as lit rather than as a dead stripe.
//
// The empty part of the trough is left completely alone. Lighting it would say
// the bar is fuller than it is, and a readout that lies about its own value is
// worse than a readout that does not move.

// How far along the bar the fill reaches, 0 to 1.
uniform float fill : hint_range(0.0, 1.0) = 1.0;
// The fill's own colour, read off the bar's `StyleBoxFlat` so a health bar flows
// red and a mana bar blue with no second table saying which is which.
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// The most light this may add anywhere. `ui_juice_check` reads it back off the
// material: the effect may be tuned, it may not become a flood over a reading.
uniform float ceiling : hint_range(0.0, 0.5) = 0.22;
// This bar's own clock offset, so a column of bars is a column of clocks. Every
// pool on the HUD sits in one stack, and in unison they read as one flashing
// block rather than as three readings.
uniform float phase = 0.0;

void fragment() {
	// Nothing at all outside the fill. `step` rather than a branch: the whole
	// shader is a handful of instructions and a branch here would cost more than
	// the arithmetic it skips.
	float inside = step(UV.x, fill);

	float t = TIME + phase;

	// The current. Travels along the bar and wraps; the exponent keeps it a
	// band rather than a gradient, so it reads as something moving through.
	float along = UV.x - fract(t * 0.23);
	along -= floor(along + 0.5);
	float flow = exp(-pow(along / 0.11, 2.0));

	// The head. Pinned just behind the fill's edge, so it marks the value
	// rather than sliding about, and it breathes so a bar that is not changing
	// is still alive.
	float to_edge = fill - UV.x;
	float head = exp(-pow(max(to_edge, 0.0) / 0.055, 2.0));
	head *= 0.7 + 0.3 * sin(t * 2.1);

	// A faint constant lift, so a nearly-empty bar is still lit.
	float sheen = 0.18 + 0.10 * sin(UV.y * 3.14159 + t * 0.7);

	float lit = (flow * 0.55 + head * 0.9 + sheen * 0.35) * ceiling * inside;
	// Toward white at the head rather than only brighter in the fill's own
	// hue - a crest is where the light is strongest and hue washes out there.
	vec3 shade = mix(tint.rgb, vec3(1.0), head * 0.55) * lit;
	COLOR = vec4(shade, lit);
}
