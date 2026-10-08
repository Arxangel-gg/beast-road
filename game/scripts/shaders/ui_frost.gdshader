shader_type canvas_item;

// **Frosted glass behind a screen** (owner, 2026-10-07: "Elevate the Hold's UIs
// to have semi-transparency ... with polish and game juice perfection").
//
// Drawn in place of a screen's dark scrim: the world behind it, read off the
// screen at a blurred mip and washed with the scrim's own colour, so a panel
// that lets the world through lets a soft, dimmed, recognisable world through
// rather than a busy one that fights its words. A faint band of light drifts
// across it - the glass catching the room's light - and the edges fall darker
// so the eye settles in the middle, where the panel is.
//
// Two mips mixed rather than one, because a single mip shows its texels as
// blocks when the screen is large; the pair reads as a blur.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 6.0) = 2.6;
uniform vec4 wash : source_color = vec4(0.02, 0.03, 0.05, 0.62);
uniform float sheen : hint_range(0.0, 0.3) = 0.05;
uniform float edge_dark : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec3 near = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	vec3 far = textureLod(screen_tex, SCREEN_UV, blur_lod + 1.3).rgb;
	vec3 world = mix(near, far, 0.45);
	vec3 colour = mix(world, wash.rgb, wash.a);
	// The light drifting over the glass: a soft diagonal band, slow enough to
	// read as the room's light and never as an animation to watch.
	float along = fract(UV.x * 0.55 + UV.y * 0.25 - TIME * 0.03);
	float band = smoothstep(0.16, 0.0, abs(along - 0.5));
	colour += vec3(1.0, 0.92, 0.78) * band * sheen;
	// Darker toward the edges, so the middle is where the eye rests.
	vec2 from_middle = UV - vec2(0.5);
	float fall = clamp(dot(from_middle, from_middle) * 2.2, 0.0, 1.0);
	colour *= 1.0 - fall * edge_dark;
	COLOR = vec4(colour, 1.0);
}
