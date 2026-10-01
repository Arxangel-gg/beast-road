// **Blood to the height a body waded** (owner, 2026-10-01: *"Characters should
// have the bottom of their sprites that went to that depth remain bloodstained
// for the remainder of their lifespan"*). Shared by `blood_stain` and
// `actor_polish`, so a Warden, a road body, a promoted one and an animal all
// keep what they walked through.
//
// `wade_band` is the band of the body's own cell, in texels: from the highest
// the blood has ever reached (x) to the feet (y). Below `x` the body is
// stained, soaked darker toward the feet, its top edge ragged and its colour
// grained; x below zero is a body that has waded through nothing.

uniform vec2 wade_band = vec2(-1.0, -1.0);
uniform vec3 wade_colour : source_color = vec3(0.30, 0.04, 0.05);

vec3 wade_blood(vec3 rgb, float alpha, vec2 in_cell) {
	if (wade_band.x < 0.0 || alpha <= 0.001) {
		return rgb;
	}
	// A ragged top, two texels a step, so it reads as soaked cloth and fur
	// rather than a ruled line.
	float ragged = (fract(sin(floor(in_cell.x * 0.5) * 91.7) * 4375.3) - 0.5) * 3.0;
	float top = wade_band.x + ragged;
	if (in_cell.y < top) {
		return rgb;
	}
	float down = clamp((in_cell.y - top) / max(wade_band.y - wade_band.x, 1.0), 0.0, 1.0);
	float grain = fract(sin(dot(floor(in_cell), vec2(12.9898, 78.233))) * 43758.5453);
	float amount = mix(0.55, 0.9, down) * (0.82 + 0.18 * grain);
	return mix(rgb, wade_colour * (0.78 + 0.22 * grain), amount);
}
