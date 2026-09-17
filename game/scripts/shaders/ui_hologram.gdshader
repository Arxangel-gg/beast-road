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

// --- the standing animation (owner, 2026-09-17) ----------------------------
//
// *"I'd like the UI panels to not just be static but to have some sort of
// shader over the panel that's aesthetically appealing and game juicy and tasty
// and perfectly procedurally animated. A similar procedural animated shader
// should also be applied to buttons."*
//
// **This is a second effect in the same pass rather than a second shader**,
// because it is the same light on the same surface and two skins over one
// button is two draw calls to say one thing. It is deliberately *not* scaled
// by `strength`: `strength` is what a hover answers with and is zero at rest,
// which is exactly when this is supposed to be visible.
//
// **Its own ceiling, well under the interactive one.** A plate that is always
// moving has to be quieter than one that has just been touched, or the answer
// to being touched says nothing. `ui_juice_check` reads both back.
uniform float idle : hint_range(0.0, 1.0) = 0.0;
uniform float idle_ceiling : hint_range(0.0, 0.5) = 0.05;
// A per-control offset, so a screen of eight panels is eight clocks rather than
// one. Unison reads as the whole screen pulsing; this project has paid for that
// twice, in the town's idle buildings and in the pen's animals.
uniform float phase = 0.0;

// The standing light: a slow sheen crossing the plate, a breath on the rim, and
// a fine drifting grain. Three periods with no common multiple, so the surface
// never repeats in a way a player can catch.
vec3 ambient_light(vec2 uv, float t) {
	// The sheen. Travels out of one side and back in the other over about nine
	// seconds, on a diagonal so it reads as light moving across a surface rather
	// than a bar sliding along one.
	float along = uv.x * 0.62 + uv.y * 0.38;
	float where = fract(t * 0.109) * 1.7 - 0.35;
	float sheen = exp(-pow((along - where) / 0.23, 2.0));

	// The breath, on the rim only - the same reason the interactive rim exists:
	// edge light reads as lit from within, surface light reads as fog over it.
	vec2 edge = min(uv, vec2(1.0) - uv);
	float rim = 1.0 - smoothstep(0.0, 0.07, min(edge.x, edge.y));
	float breath = 0.55 + 0.45 * sin(t * 0.61);

	// The grain. Two sines crossed rather than a noise texture, because this
	// runs on every panel on screen and a texture read is the one thing here
	// that would cost anything.
	float grain = sin(uv.x * 37.0 + t * 0.37) * sin(uv.y * 23.0 - t * 0.29);
	grain = 0.5 + 0.5 * grain;

	// **A light that travels round the edge**, which is the one thing here a
	// player actually notices. Owner, 2026-09-17: the panels and buttons were
	// *"not seeing enough of it if any"* - and the reason is that a sheen
	// crossing a dark plate at five percent additive is, correctly, almost
	// nothing. An edge is where a control's shape is, so light moving along one
	// reads at a fraction of the brightness a surface wash would need.
	//
	// The perimeter as one coordinate: along the top, down the right, back
	// along the bottom, up the left. `fract` closes the loop, so the light
	// leaves one corner and arrives at the next without a seam.
	float around = uv.x * 0.25;
	if (uv.y > uv.x && uv.y > 1.0 - uv.x) {
		around = 0.5 + (1.0 - uv.x) * 0.25;   // the bottom, right to left
	} else if (uv.x > uv.y && uv.x > 1.0 - uv.y) {
		around = 0.25 + uv.y * 0.25;          // the right, top to bottom
	} else if (uv.x < uv.y) {
		around = 0.75 + (1.0 - uv.y) * 0.25;  // the left, bottom to top
	}
	float runner = fract(t * 0.077);
	float gap = abs(fract(around - runner + 0.5) - 0.5);
	float travel = exp(-pow(gap / 0.085, 2.0)) * rim;

	return vec3(sheen * 0.55 + rim * breath * 0.7 + grain * 0.10
		+ travel * 1.35);
}

void fragment() {
	// **The ambient term is why this is not an early-out any more.** A control
	// at rest has `strength` 0 and still has a standing animation, so returning
	// nothing here would switch the owner's whole request off at rest - which is
	// the only time it is meant to be seen.
	vec3 shade = vec3(0.0);
	float lit = 0.0;

	if (idle > 0.001) {
		vec3 own = ambient_light(UV, TIME + phase) * idle * idle_ceiling;
		shade += glow.rgb * own;
		lit += own.r;
	}

	if (strength > 0.001) {
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

		float hot = (body * 0.5 + pass_by * 0.85 + rim * 0.55) * strength * ceiling;
		// Chromatic fringe on the rim only. A whole-surface split reads as a
		// broken monitor; on the edge it reads as glass.
		vec3 touch = glow.rgb * hot;
		touch.b += rim * hot * 0.35;
		touch.r += pass_by * hot * 0.2;
		shade += touch;
		lit += hot;
	}
	COLOR = vec4(shade, lit);
}
