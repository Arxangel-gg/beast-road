shader_type canvas_item;

// The light spire over a drop on the ground.
//
// A drop used to wear a stretched falloff sprite, which is a soft blob: it says
// "something glows here" and nothing about what. This is a column - bright hard
// core, wide soft flare, a flared foot where it meets the ground, and motes of
// light rising through it - so a drop can be found across a field of foliage at
// a glance, and so rarity has somewhere to show itself.
//
// Everything is scaled by `richness`, which the drop feeds from its own rarity:
// a common drop is a thin quiet candle and an Oathbound one is a column with
// light climbing it. That is the whole reason this is a shader rather than a
// bigger sprite - the difference between rarities is *behaviour*, not size.

// 0 for the commonest drop, 1 for the rarest thing in the game.
uniform float richness = 0.0;
// Seconds. Fed by the node so the spire freezes with the battlefield during a
// raid, rather than running on its own clock (working rule 8).
uniform float clock = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.6, 1.0);

void fragment() {
	// UV.x across the column, UV.y from the top down.
	float across = abs(UV.x - 0.5) * 2.0;
	float up = 1.0 - UV.y;

	// **The column.** A soft body and a bright core, both narrowing with
	// height so the spire tapers rather than ending in a flat edge.
	float taper = mix(1.0, 0.34, up);
	float body = 1.0 - smoothstep(0.0, taper, across);
	float core = 1.0 - smoothstep(0.0, taper * 0.26, across);

	// It fades out toward the top, and fades *in* off the ground so the foot
	// does not cut a hard line across whatever it is standing on.
	float height_fade = 1.0 - smoothstep(0.25, 1.0, up);
	float foot = smoothstep(0.0, 0.10, up);

	// **A flared base**, which is what sells it as light landing on ground
	// rather than a rectangle pasted over it.
	float flare = (1.0 - smoothstep(0.0, 0.46, across))
		* (1.0 - smoothstep(0.0, 0.16, up));

	float glow = body * 0.55 + core * 0.85;
	glow *= height_fade * foot;
	glow += flare * 0.6;

	// **Motes climbing the column**, more of them and faster the rarer the
	// drop. This is the part a player reads as "that one is special" without
	// being told, and it costs two sines.
	float rise = fract(up * 2.4 - clock * 0.55);
	float mote = smoothstep(0.86, 1.0, rise) * body * height_fade;
	float second = fract(up * 3.7 - clock * 0.85 + 0.37);
	mote += smoothstep(0.92, 1.0, second) * body * height_fade * 0.7;
	glow += mote * (0.25 + richness * 0.95);

	// A slow breath, deeper on the rare ones.
	glow *= 0.88 + 0.12 * sin(clock * 2.3 + richness * 3.0);

	vec4 art = tint;
	// The core washes toward white so the spire has a hot centre rather than
	// being one flat colour at every brightness.
	art.rgb = mix(art.rgb, vec3(1.0), core * height_fade * (0.30 + richness * 0.35));
	art.a *= clamp(glow, 0.0, 1.0) * (0.62 + richness * 0.38);
	COLOR = art * COLOR;
}
