shader_type canvas_item;
render_mode unshaded;

// **One grid for the whole picture** (owner, 2026-09-17: *"can you apply a pixel
// art shader to the whole screen ... in hopes that this will give a more
// cohesive look to the whole game"*).
//
// The incoherence it answers is real and is not the sprites' fault. This game's
// art is pixel art at 192 and 384 drawn at whatever scale the camera happens to
// be at, next to geometry the engine draws at device resolution - blood fans,
// flame cones, bar fills, rings, the fog's soft edge. The sprites sit on one
// grid and nothing else sits on any grid at all, so the eye reads two different
// materials in one frame. Snapping the finished frame to a single grid puts all
// of it on the same one.
//
// **It is one texture read and two floors.** No loops, no branches, no second
// pass: the expensive half of a screen effect is the copy, and the node that
// owns this shader disables that copy outright when the setting is off. A
// fragment that snapped in UV space would have been cheaper still and wrong -
// the grid has to be square in *pixels*, and UV is not square on any window
// that is not.
//
// `filter_nearest` on the screen sample is what makes a block a block. With a
// linear filter the snap still happens and every block comes out smeared with
// its neighbours, which reads as a blur rather than as pixel art.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

// The size of one block, in the same pixels `viewport` is measured in. A whole
// number - a grid of 2.5 puts one block edge on a half pixel, and the row of
// blocks either side of it comes out a different width.
uniform float grid = 3.0;
// The viewport, in pixels. Handed in rather than derived, because the fragment
// has no honest way to ask: `SCREEN_PIXEL_SIZE` is the *texture's* texel and a
// stretched canvas makes the two disagree.
uniform vec2 viewport = vec2(1920.0, 1080.0);
// How far toward the grid the picture is pulled, 0 to 1. The setting is a
// switch, but the fade is what lets it be turned on without a jump cut.
uniform float strength : hint_range(0.0, 1.0) = 1.0;

// Rectangles the grid is not applied to, in the same pixels `viewport` is in,
// as (x, y, width, height).
//
// **For the things that cannot be redrawn sharp on top.** `CrispText` mutes a
// string where it was authored and draws it again above this filter, which
// works for anything `draw_string` can draw. A `RichTextLabel` is marked-up
// text with its own layout engine - wrapping, inline colour, tables - and
// `draw_string` is not that engine, so those are left out of the grid here
// instead. The plate behind one is left sharp with it; that is the honest cost
// and it is invisible in practice, because a rich label fills its own panel.
//
// Walked rather than branched on: at eight the loop is shorter than the
// texture read it guards, and a bound small enough to walk is what keeps this
// pass cheap. `exclusions` says how many of the array are real.
uniform vec4 exclude[8];
uniform int exclusions = 0;

void fragment() {
	vec2 at = SCREEN_UV * viewport;
	// Inside any exempt rectangle the picture passes through untouched.
	bool keep = false;
	for (int i = 0; i < exclusions; i++) {
		vec4 r = exclude[i];
		if (at.x >= r.x && at.y >= r.y && at.x < r.x + r.z && at.y < r.y + r.w) {
			keep = true;
		}
	}
	if (keep) {
		COLOR = texture(screen_tex, SCREEN_UV);
	} else {
		// The centre of the block this fragment falls in. Sampling the centre
		// rather than the corner is what stops the grid drifting half a block
		// when the viewport is an odd number of blocks wide.
		vec2 block = (floor(at / grid) + 0.5) * grid;
		vec2 uv = mix(at, block, strength) / viewport;
		COLOR = texture(screen_tex, uv);
	}
}
