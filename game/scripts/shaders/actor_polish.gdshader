shader_type canvas_item;

uniform vec4 outline_colour : source_color = vec4(0.035, 0.045, 0.05, 0.94);
uniform float outline_strength : hint_range(0.0, 1.0) = 0.82;
uniform vec4 impact_colour : source_color = vec4(1.0, 0.82, 0.62, 1.0);
uniform vec2 impact_direction = vec2(0.0, -1.0);
uniform float impact_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 source = COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float left_a = texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
	float right_a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	float up_a = texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float down_a = texture(TEXTURE, UV + vec2(0.0, px.y)).a;
	float around = max(max(left_a, right_a), max(up_a, down_a));
	float outline = max(around - tex.a, 0.0) * outline_strength;
	vec2 gradient = vec2(left_a - right_a, up_a - down_a);
	float edge = length(gradient) > 0.001
		? max(dot(normalize(gradient), normalize(impact_direction)), 0.0) : 0.0;
	vec3 body = mix(source.rgb, impact_colour.rgb,
		edge * impact_strength * impact_colour.a * source.a);
	vec4 composed = vec4(body, source.a);
	vec4 rim = vec4(outline_colour.rgb, outline * outline_colour.a);
	COLOR = mix(rim, composed, composed.a);
}
