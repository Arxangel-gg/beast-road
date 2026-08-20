class_name CloudShadows
extends Node2D

## Cloud shadows drifting across the battlefield.
##
## Two layers of scrolling value noise, multiplied over everything beneath them,
## so a shadow darkens the ground *and* the units standing on it — a shadow that
## only touched the floor would read as a decal painted on the terrain rather than
## as something passing overhead.
##
## Procedural rather than a texture: it tiles forever with no visible repeat, it
## costs no asset, and the cloud size, coverage and speed are all tunable from
## Balance instead of baked into a PNG.
##
## Multiply blend means this can only ever darken. It cannot brighten, cannot
## wash colour out, and cannot make anything invisible — which matters after the
## y-sorting incident.

const SHADER_CODE: String = """
shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform vec2 offset_near = vec2(0.0);
uniform vec2 offset_far = vec2(0.0);
uniform float scale_near = 900.0;
uniform float scale_far = 1500.0;

// 0 = no shadows at all, 1 = full strength. Driven by daylight.
uniform float strength : hint_range(0.0, 1.0) = 0.0;
// Fraction of the noise range that becomes shadow.
uniform float coverage : hint_range(0.0, 1.0) = 0.46;

// World size of this quad, in units. Passed in rather than derived: a ColorRect
// has no texture, so TEXTURE_PIXEL_SIZE is (1,1) and the obvious reconstruction
// collapses the whole field into a half-unit square. Divided by a 900-unit cloud
// scale that samples one point of noise for the entire battlefield, which is why
// this read as a flat wash rather than as cloud.
uniform vec2 field_size = vec2(4000.0);

// Cheap hash-based value noise. A NoiseTexture2D would work too, but this keeps
// the whole effect in one file with nothing to import or keep in sync.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Smoothstep the interpolation or the result looks like a grid of squares.
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Two octaves is enough for cloud cover: one gives the mass, one gives an edge.
float clouds(vec2 world) {
	float near = value_noise(world / scale_near + offset_near);
	near += value_noise(world / (scale_near * 0.45) + offset_near * 1.7) * 0.5;
	near /= 1.5;
	float far = value_noise(world / scale_far + offset_far);
	return mix(near, far, 0.35);
}

void fragment() {
	// UV is across this quad; scaled by the quad's own world size so the pattern
	// is anchored to the battlefield and does not slide when the camera moves.
	vec2 world = (vec2(UV) - vec2(0.5)) * field_size;
	float n = clouds(world);

	// Remap so `coverage` sets how much of the field is in shade, with a soft
	// edge. A hard threshold makes clouds look like spilled ink.
	float shade = smoothstep(coverage, coverage + 0.34, n);
	float darkness = shade * strength;

	// blend_mul: 1.0 leaves the pixel untouched, lower darkens it.
	vec3 tint = mix(vec3(1.0), SHADOW_TINT, darkness);
	COLOR = vec4(tint, 1.0);
}
"""

## Slightly blue rather than grey — a shadow is lit by sky, not by nothing.
const SHADOW_TINT: Color = Color(0.62, 0.66, 0.78)

var _rect: ColorRect
var _material: ShaderMaterial
var _near: Vector2 = Vector2.ZERO
var _far: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Sized against the same visible area the floor uses, so the clouds cover
	# exactly the ground they are supposed to be passing over. Three times the
	# spawn radius happened to be enough at the old zoom and is not a rule.
	var visible_half: float = maxf(1920.0, 1080.0) / Balance.CAMERA_ZOOM_BATTLEFIELD
	var extent: float = maxf(Balance.LANE_SPAWN_RADIUS * 1.4, visible_half) * 1.35

	_rect = ColorRect.new()
	_rect.color = Color.WHITE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.size = Vector2(extent * 2.0, extent * 2.0)
	_rect.position = -Vector2(extent, extent)

	var shader := Shader.new()
	shader.code = SHADER_CODE.replace("SHADOW_TINT",
		"vec3(%.3f, %.3f, %.3f)" % [SHADOW_TINT.r, SHADOW_TINT.g, SHADOW_TINT.b])

	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("scale_near", Balance.CLOUD_SCALE)
	_material.set_shader_parameter("scale_far", Balance.CLOUD_SCALE_FAR)
	_material.set_shader_parameter("coverage", Balance.CLOUD_COVERAGE)
	_material.set_shader_parameter("strength", 0.0)
	_material.set_shader_parameter("field_size", Vector2(extent * 2.0, extent * 2.0))
	_rect.material = _material
	add_child(_rect)

	DayNight.phase_changed.connect(_on_phase)
	_on_phase(DayNight.phase, DayNight.tint, DayNight.darkness)


func _process(delta: float) -> void:
	# Scrolled in noise space, so speed is independent of the cloud scale.
	_near += Balance.CLOUD_SPEED * delta / Balance.CLOUD_SCALE
	_far += Balance.CLOUD_SPEED_FAR * delta / Balance.CLOUD_SCALE_FAR
	_material.set_shader_parameter("offset_near", _near)
	_material.set_shader_parameter("offset_far", _far)


## Shadows need a sun. They fade out as night falls and vanish in the dark,
## rather than lingering as unexplained dark patches.
func _on_phase(_phase: float, _tint: Color, darkness: float) -> void:
	var daylight: float = clampf(1.0 - darkness, 0.0, 1.0)
	_material.set_shader_parameter("strength", Balance.CLOUD_DARKNESS * daylight)
	_rect.visible = daylight > 0.02
