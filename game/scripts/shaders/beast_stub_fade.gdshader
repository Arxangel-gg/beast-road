shader_type canvas_item;

// The beast's own tail stub, dissolved at its outer end.
//
// **The join belongs on the body, not on the tail.** The body frame carries the
// first stretch of tail and ends it hard at the canvas edge; the rest is a
// separate sprite drawn behind. Feathering the *tail* sprite's root - which is
// what this project did first - fades away the very thing that is supposed to
// be continuous, so the tail ends short of the flank in mid-air and reads as
// detached. Owner's correction, 2026-09-13: the asset that is part of the beast
// is the one whose tail end should fade, and the separate tail must stay whole
// and simply sit where it belongs.
//
// So the stub's last `fade_px` dissolve, and the opaque tail sprite behind
// shows through them. The result is a cross-fade from body to tail with no
// seam, and nothing anywhere is scaled to make it meet.
//
// Only the stub lives out there: in every body frame the leftmost 42 columns
// hold one painted run - the tail - and the hind leg does not appear until
// x=44. A fade well inside that touches nothing else.

// How many of the texture's own pixels dissolve, measured from the left edge.
uniform float fade_px = 22.0;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	// Pixels from the left edge, in the texture's own scale. Derived from
	// TEXTURE_PIXEL_SIZE rather than from UV alone so that a regioned sprite -
	// the menu cuts the frame at its ground line - measures the same as a whole
	// one.
	float from_edge = UV.x / max(TEXTURE_PIXEL_SIZE.x, 0.000001);
	art.a *= clamp(from_edge / max(fade_px, 0.001), 0.0, 1.0);
	// Multiplied by the colour handed in, never assigned over it: that is how
	// the scene's tint reaches the sprite. Measured in Godot 4.7.1 - with a
	// white texture and a modulate of (0.25, 0.50, 0.75), `COLOR = art` renders
	// white while this renders the modulate exactly, and there is no `MODULATE`
	// built-in in this version to ask instead.
	COLOR = art * COLOR;
}
