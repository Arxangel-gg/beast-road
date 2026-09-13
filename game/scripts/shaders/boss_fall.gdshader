shader_type canvas_item;

// The wipe that carries the act away, over the frame the boss fell on.
//
// Owner brief, 2026-09-13: "Defeating an act boss should have a bunch of game
// juice! And then transition with shaders to a screen showing the fallen act
// boss." This is the transition: the field desaturates and darkens from the
// edges inward while a band of light sweeps across it, and by the time the
// sweep has passed the picture underneath is gone and the card is what is
// left. Running it backwards fades the card off and the road back in.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
// 0 is the field untouched, 1 is fully taken.
uniform float progress = 0.0;
uniform vec4 ink : source_color = vec4(0.03, 0.02, 0.04, 1.0);
uniform vec4 sweep_tint : source_color = vec4(1.0, 0.82, 0.5, 1.0);

void fragment() {
	vec3 scene = texture(screen_tex, SCREEN_UV).rgb;

	// Colour drains first: the moment reads as an ending before it reads as a
	// wipe, which is the difference between a transition and a curtain.
	float luma = dot(scene, vec3(0.299, 0.587, 0.114));
	scene = mix(scene, vec3(luma), clamp(progress * 1.6, 0.0, 1.0));

	// The sweep: a band crossing on the diagonal, slightly ahead of the ink.
	float along = (SCREEN_UV.x * 0.72 + SCREEN_UV.y * 0.28);
	float head = progress * 1.5 - 0.2;
	float band = smoothstep(0.09, 0.0, abs(along - head));
	scene += sweep_tint.rgb * band * 0.7 * (1.0 - progress * 0.5);

	// And the ink behind it, plus a vignette closing from the edges.
	float taken = smoothstep(head - 0.02, head - 0.14, along);
	vec2 centred = SCREEN_UV - 0.5;
	float edge = smoothstep(0.16, 0.62, length(centred)) * progress;
	float cover = clamp(max(taken * progress * 1.35, edge), 0.0, 1.0);
	COLOR = vec4(mix(scene, ink.rgb, cover), 1.0);
}
