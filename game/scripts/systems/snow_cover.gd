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
## Sits directly above the floor and below everything sorted, so it whitens the
## ground and never the units standing on it. A wave that cannot be read is a
## worse problem than a field that is not snowy enough.

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
		COLOR = vec4(snow.rgb, lying * max_alpha);
	}
}
"""

var _rect: ColorRect = null
var _material: ShaderMaterial = null


func _ready() -> void:
	var extent: float = maxf(Balance.LANE_SPAWN_RADIUS * 1.4,
		maxf(1920.0, 1080.0) / Balance.CAMERA_ZOOM_BATTLEFIELD)
	_rect = ColorRect.new()
	_rect.name = "Lying"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.size = Vector2(extent * 2.0, extent * 2.0)
	_rect.position = -Vector2(extent, extent)

	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material.shader = shader
	_material.set_shader_parameter("field_size", Vector2(extent * 2.0, extent * 2.0))
	_material.set_shader_parameter("max_alpha", Balance.SNOW_COVER_STRENGTH)
	_rect.material = _material
	add_child(_rect)

	EventBus.snow_cover_changed.connect(set_cover)


func set_cover(cover: float) -> void:
	if _material != null:
		_material.set_shader_parameter("cover", clampf(cover, 0.0, 1.0))
