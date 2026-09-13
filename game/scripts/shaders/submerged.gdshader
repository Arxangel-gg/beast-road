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

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	// UV.y runs 0 at the top; the line is a fraction up from the bottom.
	float line = 1.0 - waterline + sin(UV.x * 18.0 + TIME * 2.2) * wobble;
	float under = smoothstep(line - feather, line + feather, UV.y);
	vec3 drowned = mix(base.rgb, water_colour.rgb, tint);
	float grey = dot(drowned, vec3(0.299, 0.587, 0.114));
	drowned = mix(drowned, vec3(grey), 0.25);
	COLOR = vec4(mix(base.rgb, drowned, under), base.a * mix(1.0, 0.86, under));
}
