shader_type canvas_item;

// The tail's root end, faded so it disappears under the beast's flank.
//
// The tail is a separate sprite drawn behind the body, and however carefully
// its root is placed there is a hard edge where the painting stops. Feathering
// the last fraction of the root end turns a butt-joint into a join: the body
// covers most of it, and what shows past the flank is already transparent.
// Reported 2026-09-13 as the tail not being anchored to the beast.

uniform float feather = 0.24;
// Which end is the root, as a UV x. 1.0 is the right edge.
uniform float root_at = 1.0;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float toward_root = 1.0 - abs(root_at - UV.x) / max(feather, 0.001);
	art.a *= 1.0 - clamp(toward_root, 0.0, 1.0);
	COLOR = art;
}
