shader_type canvas_item;

// A fish seen from above, through water.
//
// Owner brief, 2026-09-16: "ensure all fish have an underwater shader and color
// grading and tint applied to them making them mostly a dark faded silhouette".
//
// The first cut graded them with `modulate`, which can only multiply - so a fish
// went *dimmer* and kept every one of its own colours, and a bright orange perch
// in deep water read as a bright orange perch behind gauze. Water does not work
// like that. What reaches the surface from something a foot down is a shape, a
// suggestion of its colour, and the light moving over it.
//
// Four things, all driven by `depth`:
//
//  - **Toward a silhouette.** The body is crushed toward a dark version of the
//    water's own colour, keeping only a fraction of its own hue - so a fish is
//    mostly a dark shape with a hint of what it is, which is the whole brief.
//  - **Thinner.** It fades with depth as well as darkening; two fish at two
//    depths read as two distances rather than two brightnesses.
//  - **Caustics over it.** The same crossing sheets the flood's sheen uses, at
//    the fish's own scale, so the light on its back moves with the surface
//    instead of the fish being a decal.
//  - **And it wobbles.** A slow lateral bend on the sample, stronger deeper
//    down, which is refraction - the single cheapest thing that says "this is
//    being seen through something".
//
// `phase` is per fish, so a school does not shimmer in unison.

// How deep this fish is swimming, 0 at the surface and 1 in the deep.
uniform float depth : hint_range(0.0, 1.0) = 0.5;
// The water's own colour, read off the region's tile sheet.
uniform vec4 water_colour : source_color = vec4(0.16, 0.34, 0.48, 1.0);
// How far toward a flat silhouette a fish is taken at full depth. At 1 it is a
// shape and nothing else; a little under keeps a suggestion of the species,
// which is what makes watching the water worth doing.
uniform float silhouette : hint_range(0.0, 1.0) = 0.82;
// How dark the silhouette is against the water it is in.
uniform float shade : hint_range(0.0, 1.0) = 0.42;
// How much of the fish is left at full depth.
uniform float fade : hint_range(0.0, 1.0) = 0.62;
// The light moving over it, and how fast the surface above is running.
uniform float caustic : hint_range(0.0, 1.0) = 0.3;
uniform float caustic_scale = 9.0;
// Refraction: how far the body bends, in UV, at full depth.
uniform float wobble = 0.018;
uniform float phase = 0.0;

void fragment() {
	// **Seen through a moving surface.** Sampled off a bent UV rather than
	// drawn and then distorted, so the silhouette itself ripples.
	// The same two crossing sheets `submerged.gdshader` bends a reed on, so a
	// fish and a plant in one pond agree about what the surface is doing.
	float sway = sin(UV.y * 11.0 + TIME * 1.7 + phase) * 0.6
		+ sin(UV.y * 6.6 - TIME * 1.1 + phase) * 0.4;
	vec4 src = texture(TEXTURE, vec2(UV.x + sway * wobble * depth, UV.y));
	if (src.a < 0.004) {
		COLOR = vec4(0.0);
	} else {
		// The water's colour at the depth this fish is at: darker further down,
		// which is what the silhouette is made of.
		vec3 body = water_colour.rgb * mix(1.0, shade, depth);
		// Its own colour, kept in part - a fish is a dark shape with a hint of
		// what it is rather than a hole in the water.
		vec3 seen = mix(src.rgb, body, silhouette * depth);
		// Light off the surface playing over its back. Two sheets crossing, the
		// same trick the flood's sheen uses, at the fish's own scale.
		float a = sin((UV.x + UV.y) * caustic_scale + TIME * 1.1 + phase);
		float b = sin((UV.x - UV.y * 0.7) * caustic_scale * 0.8 - TIME * 0.8 + phase);
		float light = pow(max(a * b, 0.0), 3.0) * caustic * (1.0 - 0.45 * depth);
		seen += water_colour.rgb * light;
		COLOR = vec4(seen, src.a * mix(1.0, fade, depth));
	}
}
