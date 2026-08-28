shader_type canvas_item;

uniform vec4 rarity_colour : source_color = vec4(1.0, 0.82, 0.38, 1.0);
uniform float shimmer_strength : hint_range(0.0, 1.0) = 0.34;
uniform float pickup : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 source = COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float neighbours = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a,
		texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, px.y)).a,
		texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float outline = max(neighbours - tex.a, 0.0);
	float band = pow(max(sin((UV.x + UV.y) * 18.0 - TIME * 4.4) * 0.5 + 0.5, 0.0), 8.0);
	vec3 lit = mix(source.rgb, rarity_colour.rgb,
		band * shimmer_strength * source.a);
	float grain = hash(floor(UV / max(px, vec2(0.0001))) + vec2(seed));
	float survives = step(pickup, grain);
	vec4 body = vec4(lit, source.a * survives);
	vec4 rim = vec4(rarity_colour.rgb, outline * rarity_colour.a * (1.0 - pickup));
	COLOR = mix(rim, body, body.a);
}
