shader_type canvas_item;

// The city's own health, drawn as a ring above it.
//
// A shader rather than a ProgressBar because this sits *in the world*, over a
// building that sways with the beast's gait - a Control would have to be
// re-placed every frame against a moving target, and would draw in screen space
// while everything around it draws in world space.
//
// It is only ever asked to draw when the town is hurt; `TownCore` hides the
// whole node at full health, so there is no cost and no clutter while the walls
// are whole.

// 0..1 of the ring that is still filled.
uniform float fill = 1.0;
// How thick the band is, as a fraction of the radius.
uniform float thickness = 0.18;
// Filled, empty, and the glow that rides the leading edge.
uniform vec4 full_tint : source_color = vec4(0.85, 0.72, 0.35, 1.0);
uniform vec4 hurt_tint : source_color = vec4(0.86, 0.28, 0.22, 1.0);
uniform vec4 track_tint : source_color = vec4(0.05, 0.04, 0.06, 0.55);
// Seconds, for the pulse. Fed by the node rather than TIME so it stops with
// the battlefield when a raid freezes it (working rule 8).
uniform float clock = 0.0;

const float TAU = 6.28318530718;

void fragment() {
	vec2 from_middle = UV - vec2(0.5);
	float radius = length(from_middle) * 2.0;

	// The band itself, antialiased on both edges so it does not crawl as the
	// city sways underneath it.
	float inner = 1.0 - thickness;
	float edge = fwidth(radius) * 1.5;
	float band = smoothstep(inner - edge, inner + edge, radius)
		* (1.0 - smoothstep(1.0 - edge, 1.0 + edge, radius));
	if (band <= 0.001) {
		discard;
	}

	// Twelve o'clock, running clockwise, which is how every dial a player has
	// ever read runs.
	float turn = atan(from_middle.x, -from_middle.y) / TAU;
	turn = fract(turn + 1.0);

	float lit = step(turn, fill);
	vec4 paint = mix(hurt_tint, full_tint, smoothstep(0.25, 0.75, fill));

	// A soft head on the leading edge, so the eye finds where the ring ends.
	float head = 1.0 - smoothstep(0.0, 0.035, abs(turn - fill));
	paint.rgb += head * 0.55;

	// And a slow breath while the town is badly hurt - it is the one thing on
	// the field that ends the run, so at a quarter left it asks to be looked at.
	float urgency = 1.0 - smoothstep(0.0, 0.35, fill);
	paint.a *= 0.82 + 0.18 * sin(clock * 4.2) * urgency;

	vec4 art = mix(track_tint, paint, lit);
	art.a *= band;
	COLOR = art * COLOR;
}
