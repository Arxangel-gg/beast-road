shader_type canvas_item;

// **The stain a Brutal field never forgets** (`BloodStains`): one channel of
// coverage a texel, drawn as dried blood under the live marks. Darker where it
// stands thickest, broken a little by grain so a stained clearing reads as
// soaked earth rather than as a flat decal. `wash` is what a heavy flood has
// left of it - never below the floor the field holds it to.

uniform vec4 dry_colour : source_color = vec4(0.24, 0.07, 0.08, 1.0);
uniform vec4 dark_colour : source_color = vec4(0.16, 0.035, 0.04, 1.0);
uniform float strength = 0.42;
uniform float wash = 1.0;

float grain(vec2 p) {
	return fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float cover = texture(TEXTURE, UV).r;
	float texels = float(textureSize(TEXTURE, 0).x);
	float speck = grain(UV * texels * 3.0);
	vec3 colour = mix(dry_colour.rgb, dark_colour.rgb, clamp(cover * 1.2 + (speck - 0.5) * 0.25, 0.0, 1.0));
	float alpha = smoothstep(0.02, 0.6, cover) * strength * wash * (0.85 + 0.15 * speck);
	COLOR = vec4(colour, alpha);
}
