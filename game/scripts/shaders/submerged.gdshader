shader_type canvas_item;

// A plant standing in a pond: everything under the waterline takes on the
// water's colour and loses a little contrast, with a feathered band at the
// surface so the join reads as water rather than as a cut (owner brief,
// 2026-09-12).

uniform vec4 water_colour : source_color = vec4(0.16, 0.34, 0.48, 1.0);
uniform float waterline = 0.42;
uniform float tint = 0.6;
uniform float feather = 0.12;
uniform float wobble = 0.02;
// **How far the drowned half of the plant bends**, in UV, at the bottom of the
// sprite (owner, 2026-09-16: "a wavy distortion effect ... that applies to any
// underwater assets or parts of assets that are beneath water surface").
//
// The first cut wobbled the *waterline* and left everything under it standing
// perfectly still, which reads as a rippling edge drawn on a rigid plant. The
// same two crossing sheets the fish use, so a reed and a fish in one pond agree
// about what the surface over them is doing.
uniform float bend = 0.016;
uniform float bend_scale = 13.0;

void fragment() {
	// UV.y runs 0 at the top; the line is a fraction up from the bottom.
	float line = 1.0 - waterline + sin(UV.x * 18.0 + TIME * 2.2) * wobble;
	float under = smoothstep(line - feather, line + feather, UV.y);
	// Bent below the line and not at all above it, eased in over the same
	// feather band so the plant is not sheared in half at the surface. Stronger
	// further down, where there is more water between it and the eye.
	float depth_here = clamp((UV.y - line) / max(1.0 - line, 0.001), 0.0, 1.0);
	float sway = sin(UV.y * bend_scale + TIME * 1.5) * 0.6
		+ sin(UV.y * bend_scale * 0.6 - TIME * 1.1) * 0.4;
	vec2 wet_uv = vec2(UV.x + sway * bend * under * depth_here, UV.y);
	vec4 base = texture(TEXTURE, wet_uv);
	vec3 drowned = mix(base.rgb, water_colour.rgb, tint);
	float grey = dot(drowned, vec3(0.299, 0.587, 0.114));
	drowned = mix(drowned, vec3(grey), 0.25);
	COLOR = vec4(mix(base.rgb, drowned, under), base.a * mix(1.0, 0.86, under));
}
