shader_type canvas_item;

// The Warden's look on a sprite that wears no other material: the Hold's
// figures, the Warden card's portrait. The hero on the road gets the same dye
// through `blood_stain.gdshader`, which includes the same file.
#include "res://scripts/shaders/warden_look.gdshaderinc"

void fragment() {
	if (COLOR.a > 0.001) {
		COLOR.rgb = warden_look(COLOR.rgb);
	}
}
