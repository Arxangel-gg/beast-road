shader_type canvas_item;

uniform vec4 crack_colour : source_color = vec4(1.0, 0.44, 0.22, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float pulses = 3.0;

float hash(float p) {
	return fract(sin(p * 91.73) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float sector = floor((angle + 3.14159) / 6.28318 * 11.0);
	float centre = (sector + 0.5 + (hash(sector) - 0.5) * 0.55) / 11.0 * 6.28318 - 3.14159;
	float angle_distance = abs(atan(sin(angle - centre), cos(angle - centre)));
	float crooked = sin(radius * (31.0 + hash(sector) * 18.0) + sector) * 0.018;
	float crack = 1.0 - smoothstep(0.012, 0.038, angle_distance + crooked);
	crack *= smoothstep(0.04, 0.16, radius) * (1.0 - smoothstep(0.72, 1.0, radius));
	float edge = 1.0 - smoothstep(0.018, 0.055, abs(radius - mix(0.18, 0.94, progress)));
	float pulse = max(sin(progress * pulses * 6.28318), 0.0);
	float alpha = crack * (1.0 - progress) + edge * pulse * 0.78;
	COLOR = vec4(crack_colour.rgb, alpha * crack_colour.a) * COLOR;
}
