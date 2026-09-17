shader_type canvas_item;

// **The mount's own body, drawn a second time over its rider's legs.**
//
// Owner, 2026-09-17: *"make it so the leg in the back is faded out from a proper
// anchor aesthetically"*. A rider straddles, so one leg hangs on the far side of
// the barrel and should be behind it - but the rig draws the whole animal under
// the whole Warden, which puts both legs in front of the horse and reads as
// somebody standing against it rather than sitting on it.
//
// The fix is the one `SwimCover` uses for the waterline rather than a second
// painting: the *same frame* of the *same sprite* drawn again above the rider,
// with its alpha ramped in from the saddle. Above the anchor it contributes
// nothing and the torso is untouched; below it the animal closes over the legs.
// So the near leg is still lost as well, which is correct at this camera - a
// low top-down view of a rider shows the boot and the stirrup at most, and the
// art has no separate near-side layer to preserve one.
//
// **Anchored in the sprite's own rect, never in world space.** The saddle sits
// at a share of the animal's height and the animal is a different height in
// every cell of every sheet, so an anchor in pixels would drift between a walk
// and a gallop. `MountRig` hands in the share it already computes for the seat,
// which is the same number the rider was lifted by - so the fade cannot
// disagree with where the rider is sitting.

// Where the animal closes over the rider, as a fraction down the sprite's rect.
uniform float anchor : hint_range(0.0, 1.0) = 0.55;
// How far it takes to close. A hard edge is a line across the Warden's thigh;
// this is the difference between a leg going behind something and a leg being
// cut off.
uniform float feather : hint_range(0.01, 0.5) = 0.10;

void fragment() {
	vec4 own = texture(TEXTURE, UV);
	// Smooth rather than linear, so the near edge of the fade has no visible
	// start - the same reason every soft edge in this project is a ramp with
	// zero alpha at its outer vertex rather than one flat colour.
	own.a *= smoothstep(anchor, anchor + feather, UV.y);
	COLOR = own;
}
