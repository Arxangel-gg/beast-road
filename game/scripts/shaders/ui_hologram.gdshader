shader_type canvas_item;
render_mode blend_add, unshaded;

// The holographic skin over an interface control.
//
// **Owner brief, 2026-09-15:** "holographic vfx for when players hover or tap
// on UI buttons as well and more game juice to UI interactions".
//
// **Additive, always, and that is the safety rule rather than a look.** The
// interface tint (`UiTint`) is allowed to move frames and forbidden to touch
// text, for the reason that adaptive interfaces usually end up unreadable. The
// same reasoning binds this: an additive layer can only ever add light, so over
// this game's dark plates and pale lettering it cannot reduce the contrast of a
// single glyph. A multiply or an alpha blend could, and neither is used.
//
// Four things, all of them cheap and none of them a texture:
//
//  - **scanlines**, fine and faint and crawling slowly upward, which is the
//    whole of what reads as "hologram" and costs one sine;
//  - **a sweep**, a soft diagonal band driven from outside so a hover can push
//    it across once rather than looping - a looping shimmer is a screensaver;
//  - **a rim**, brightest at the control's edge, which is what makes the thing
//    look lit from within rather than painted on;
//  - **interference**, a brief horizontal tear on a press, because a hologram
//    that reacts to being touched is the difference between an effect and a
//    response.
//
// Everything is multiplied by `strength`, so a control with the effect off
// costs a handful of instructions and writes nothing.

// How much of the effect is showing at all. 0 is invisible.
uniform float strength : hint_range(0.0, 1.0) = 0.0;
// Where the sweep band is, from -0.4 (off the left) to 1.4 (gone). Driven by a
// tween rather than by TIME: a hover is an event and the sweep is its answer.
uniform float sweep = -1.0;
// A press. Tears the scanlines sideways for a moment.
uniform float flicker : hint_range(0.0, 1.0) = 0.0;
// The colour of the light. Set from the interface's own tint so the hologram
// belongs to the scene the buttons already belong to.
uniform vec4 glow : source_color = vec4(0.55, 0.82, 1.0, 1.0);
// How many scanlines across the control's height.
uniform float lines = 42.0;
// The ceiling on everything below, which `ui_juice_check` reads back. The
// effect may be tuned; it may not be turned into a flood.
uniform float ceiling : hint_range(0.0, 0.5) = 0.16;

void fragment() {
	if (strength <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 uv = UV;
		// The tear. A press shoves a few bands sideways for a fraction of a
		// second; the step keeps it to bands rather than a smear.
		float band = floor(uv.y * 9.0);
		uv.x += flicker * 0.05 * (fract(sin(band * 91.7 + TIME * 30.0) * 4371.0) - 0.5);

		// Scanlines: fine, faint, crawling up. Half the amplitude of anything
		// else here, because this is texture and not an event.
		float scan = 0.5 + 0.5 * sin((uv.y * lines) - TIME * 1.6);
		float body = 0.18 + 0.22 * scan;

		// The sweep. A soft band on a diagonal, and nothing at all once it has
		// passed - `sweep` is parked outside [0,1] when the control is idle.
		float along = uv.x * 0.78 + uv.y * 0.22;
		float pass_by = exp(-pow((along - sweep) / 0.16, 2.0));
		pass_by *= step(-0.399, sweep);

		// The rim. Distance to the nearest edge, in UV, so a wide button and a
		// square one get the same thickness of light.
		vec2 edge = min(uv, vec2(1.0) - uv);
		float rim = 1.0 - smoothstep(0.0, 0.055, min(edge.x, edge.y));

		float lit = (body * 0.5 + pass_by * 0.85 + rim * 0.55) * strength * ceiling;
		// Chromatic fringe on the rim only. A whole-surface split reads as a
		// broken monitor; on the edge it reads as glass.
		vec3 shade = glow.rgb * lit;
		shade.b += rim * lit * 0.35;
		shade.r += pass_by * lit * 0.2;
		COLOR = vec4(shade, lit);
	}
}
