class_name SnowCover
extends Node2D

## Snow lying on the field, gathering while it falls and going slowly afterwards.
##
## **Not a modulate**, which was the first attempt and cannot work. A modulate
## multiplies, and multiplying a dark jungle floor by anything brighter than
## white still leaves a dark jungle floor — Compatibility clamps the overbright
## besides. Snow is something added *on top of* the ground, so it is drawn on
## top of the ground.
##
## **Patchy rather than a flat wash.** An even white sheet at any strength reads
## as fog or as a bug in the tint; real cover gathers in some places before
## others, and the ragged edge is most of what makes it look like snow rather
## than like opacity. The threshold moves with `cover`, so the field goes from
## bare, through drifts in the hollows, to nearly covered - which is the same
## progression a player watching it happen expects.
##
## **Two layers, because the roads sit between them.**
##
## The roads draw above the bare ground, so a single snow layer under them left
## the paths perfectly clear with a hard cut where the white stopped - snow that
## respected the road edge to the pixel, which is not how snow works.
##
## So there is a second, much fainter layer *above* the roads. It dusts
## everything, which on the road is the only snow there is and off the road is a
## marginal addition to what is already lying. Both layers sample the same noise
## at the same world position, so a drift that is deep on the verge continues
## across the path as a dusting instead of stopping at the kerb - which is the
## feathered transition, and it costs nothing because the field is shared.
##
## Neither layer is in the sorted band, so the ground whitens and the units
## standing on it never do. A wave that cannot be read is a worse problem than a
## field that is not snowy enough.

const SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded;

// 0 = bare ground, 1 = as covered as this ever gets.
uniform float cover : hint_range(0.0, 1.0) = 0.0;

// Ceiling on opacity. The region's own floor art has to stay legible.
uniform float max_alpha : hint_range(0.0, 1.0) = 0.72;

// World size of this quad, so the patch scale is in world units and does not
// change when the quad does. Same reasoning as CloudShadows: a ColorRect has no
// texture, so TEXTURE_PIXEL_SIZE is useless here.
uniform vec2 field_size = vec2(4000.0);
uniform float patch_scale = 420.0;

uniform vec4 snow : source_color = vec4(0.93, 0.96, 1.0, 1.0);
uniform float sparkle_strength : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	if (cover <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 world = (vec2(UV) - vec2(0.5)) * field_size;
		// Two octaves: one for where the drifts are, one for the ragged edge.
		float n = value_noise(world / patch_scale) * 0.68
			+ value_noise(world / (patch_scale * 0.34)) * 0.32;

		// The threshold falls as cover rises, so ground is claimed gradually
		// rather than the whole field fading up together. Widened at both ends
		// so full cover really is full and bare really is bare.
		float threshold = mix(1.05, -0.05, cover);
		float lying = smoothstep(threshold, threshold + 0.22, n);
		vec2 crystal = floor(world / 7.0);
		float rare = step(0.986, hash(crystal));
		float twinkle = pow(max(sin(TIME * 2.7 + hash(crystal + 19.0) * 6.283), 0.0), 10.0);
		float sparkle = rare * twinkle * sparkle_strength * lying;
		COLOR = vec4(snow.rgb + vec3(sparkle), lying * max_alpha);
	}
}
"""

## Where each layer sits and how strong it is. Assigned by the battlefield, which
## is the thing that knows its own z ordering.
var ground_z: int = 0
var path_z: int = 0

var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	var extent: float = maxf(Balance.LANE_SPAWN_RADIUS * 1.4,
		maxf(1920.0, 1080.0) / Balance.CAMERA_ZOOM_BATTLEFIELD)
	_build_layer("Lying", ground_z, Balance.SNOW_COVER_STRENGTH, extent)
	_build_layer("OnPaths", path_z, Balance.SNOW_PATH_STRENGTH, extent)
	EventBus.snow_cover_changed.connect(set_cover)
	set_cover(RunState.snow_cover)


func _build_layer(layer_name: String, z: int, alpha: float, extent: float) -> void:
	var rect := ColorRect.new()
	rect.name = layer_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = Vector2(extent * 2.0, extent * 2.0)
	rect.position = -Vector2(extent, extent)
	# Absolute, because the two layers straddle the roads and must not inherit a
	# single parent depth.
	rect.z_as_relative = false
	rect.z_index = z

	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER_CODE
	material.shader = shader
	material.set_shader_parameter("field_size", Vector2(extent * 2.0, extent * 2.0))
	material.set_shader_parameter("max_alpha", alpha)
	material.set_shader_parameter("sparkle_strength",
		Balance.SNOW_SPARKLE_STRENGTH if Graphics.polish_shaders() else 0.0)
	rect.material = material
	add_child(rect)
	_materials.append(material)


func set_cover(cover: float) -> void:
	var lying: float = clampf(cover, 0.0, 1.0)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("cover", lying)
	# Hidden outright at zero rather than left drawing nothing. A full-screen
	# fragment shader that returns a transparent pixel still runs for every pixel
	# on the screen, and most of a run has no snow in it at all - so this is two
	# whole-screen passes saved for the price of a boolean.
	for child: Node in get_children():
		var canvas := child as CanvasItem
		if canvas != null:
			canvas.visible = lying > 0.001
