shader_type canvas_item;

// A thing you have not got yet, drawn as its own shape and nothing more.
//
// Owner, 2026-09-17: *"If a mount is locked it should just be the silhouette,
// still idle animated and properly disabled buttons and dimmed."*
//
// **The shape is the information.** A locked mount greyed out is a mount you can
// see and cannot have, which reads as a bug the first time and as a tease every
// time after; a locked mount as a silhouette is a *shape* - you can tell a heavy
// draught horse from a light courser, and nothing else. That is what makes the
// stable read as a place with things still to earn rather than a shop with items
// switched off.
//
// **Alpha is untouched, which is the whole reason this is a shader and not a
// modulate.** Multiplying `modulate` toward black darkens the transparent pixels
// too - which is invisible against a dark plate and wrong against a light one -
// and it cannot lift the edge. Here the colour is replaced and the coverage is
// kept exactly, so the silhouette has the sprite's own outline, its own gaps,
// and its own animation: a locked horse still walks, because nothing about the
// frames changed.
//
// **A rim, because a flat shape on a dark plate disappears.** The interface this
// sits on is near-black, and a near-black silhouette on it is nothing at all. So
// the edge is lifted - measured from the alpha around each texel rather than
// from a second texture - which is what makes the shape read at all.

// The body of the shape.
uniform vec4 ink : source_color = vec4(0.10, 0.09, 0.12, 1.0);
// The light along its edge.
uniform vec4 edge : source_color = vec4(0.42, 0.45, 0.55, 1.0);
// How far in from the edge the rim reaches, in texels.
uniform float rim = 1.5;
// 0 draws the sprite exactly as it is, 1 draws the silhouette. A uniform rather
// than two materials so a thing can be unlocked in front of the player without
// the node being rebuilt.
uniform float locked : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 own = texture(TEXTURE, UV);
	if (locked <= 0.001) {
		COLOR = own;
	} else {
		// How much of the neighbourhood is solid. Four taps rather than eight:
		// this runs on a handful of icons in a menu, and the difference between
		// a four-tap and an eight-tap rim is not visible at this size.
		vec2 step_by = TEXTURE_PIXEL_SIZE * rim;
		float around =
			  texture(TEXTURE, UV + vec2(step_by.x, 0.0)).a
			+ texture(TEXTURE, UV - vec2(step_by.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, step_by.y)).a
			+ texture(TEXTURE, UV - vec2(0.0, step_by.y)).a;
		// Solid in the middle, 0 at a fully-enclosed texel, rising toward the
		// outline where the neighbours start running out.
		float lip = clamp(own.a * 4.0 - around, 0.0, 1.0);
		vec3 shape = mix(ink.rgb, edge.rgb, lip);
		COLOR = vec4(mix(own.rgb, shape, locked), own.a);
	}
}
