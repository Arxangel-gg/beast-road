class_name ShadowKit
extends RefCounted

## Shadows for everything that stands on the ground.
##
## Two kinds, because they answer different questions and one cannot do the
## other's job.
##
## A **contact shadow** is the soft pool directly beneath a thing. It is what
## stops a sprite looking pasted onto the floor, it exists in daylight, and every
## unit, tower, building and tall plant gets one. It tracks the sun: raking and
## long at dawn and dusk, tight and dark at noon, and nearly gone at night when
## the torches take over.
##
## A **cast shadow** is real occlusion: a LightOccluder2D blocking a torch and
## throwing a hard streak away from the flame. That is the one that makes a lit
## road at night look lit.
##
## The contact shadow is a single shared ShaderMaterial with no per-instance
## uniforms, which matters: the sun moves every time the beast walks, and with
## six hundred shadows on the field the difference between one uniform write and
## six hundred is the difference between free and a frame budget. Size comes from
## node scale, which costs nothing.
##
## The shape is computed in the shader rather than sampled from art, so the
## falloff is exactly smooth at any size and there is no asset to keep in sync.

const SHADER_CODE: String = """
shader_type canvas_item;
render_mode blend_mix, unshaded;

// Where the pool sits relative to its owner, in quad half-widths. Length also
// drives how far the pool stretches - a low sun throws a long shadow.
uniform vec2 sun_offset = vec2(0.0, 0.10);
uniform float strength : hint_range(0.0, 1.0) = 0.4;
// 1.0 is a circle. Higher reads as ground seen at an angle.
uniform float squash = 2.3;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	p.y *= squash;
	p -= sun_offset;

	// Stretched along the offset, so the pool elongates as it slides rather than
	// sliding out from under its owner as a rigid disc.
	float reach = 1.0 + length(sun_offset) * 0.85;
	float d = length(p) / reach;

	// Wide smoothstep: a shadow with a defined edge is a decal.
	float a = 1.0 - smoothstep(0.15, 1.0, d);
	COLOR = vec4(0.0, 0.0, 0.0, a * a * strength * COLOR.a);
}
"""

static var _material: ShaderMaterial = null
static var _quad: GradientTexture2D = null


## The single material every contact shadow shares.
static func material() -> ShaderMaterial:
	if _material != null:
		return _material
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("squash", Balance.SHADOW_SQUASH)
	# Deliberately not seeded from DayNight here. A static function can reach an
	# autoload's constants but not its properties, and the first SunSync to come
	# up corrects this within a frame anyway.
	_material.set_shader_parameter("strength", Balance.SHADOW_ALPHA_DAY)
	return _material


## Geometry only — the shader ignores what is in it and computes its own falloff.
## The gradient is explicitly solid white: a GradientTexture2D left without one
## is not reliably opaque, and an invisible quad makes an invisible shadow that
## looks exactly like a shader bug.
static func quad_texture() -> GradientTexture2D:
	if _quad != null:
		return _quad
	var solid := Gradient.new()
	solid.offsets = PackedFloat32Array([0.0, 1.0])
	solid.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	_quad = GradientTexture2D.new()
	_quad.gradient = solid
	_quad.width = 64
	_quad.height = 64
	return _quad


## Moves every contact shadow on screen at once.
##
## Phase 0 is dawn and 0.5 is dusk, so the daylight half maps to the sun crossing
## the sky: shadows point away from it, long when it is low and short at noon.
## After dusk there is no sun, and the pool becomes a small dark smudge under the
## owner while the torches do the interesting work.
static func set_sun(phase: float, darkness: float) -> void:
	if _material == null:
		return

	var daylight: float = clampf(phase / 0.5, 0.0, 1.0)
	# -1 at dawn (sun in the east, shadows west), 0 at noon, +1 at dusk.
	var lateral: float = -cos(PI * daylight)
	# Elevation: 0 on the horizon, 1 overhead.
	var elevation: float = sin(PI * daylight)
	var reach: float = lerpf(Balance.SHADOW_OFFSET_LOW, Balance.SHADOW_OFFSET_NOON, elevation)

	var offset := Vector2(lateral * reach, absf(reach) * 0.55)
	if phase > 0.5:
		# Night: no sun, so the pool sits centred and slightly forward.
		offset = Vector2(0.0, Balance.SHADOW_OFFSET_NOON * 0.6)

	_material.set_shader_parameter("sun_offset", offset)
	_material.set_shader_parameter("strength",
		lerpf(Balance.SHADOW_ALPHA_DAY, Balance.SHADOW_ALPHA_NIGHT, darkness))


## Adds a soft ground shadow under `target`, sized from `sprite`.
##
## `base_offset` is where the owner's feet are in its own frame. Sprites in this
## project are centred on the node, so the contact point is below the origin by
## most of the half-height; the default is measured from the texture rather than
## guessed per caller.
static func add_contact(target: Node2D, sprite: Sprite2D,
		width_scale: float = 1.0, base_offset: float = NAN) -> Sprite2D:
	if target == null or sprite == null or sprite.texture == null:
		return null

	if not Graphics.contact_shadows():
		return null

	var texture_size: Vector2 = sprite.texture.get_size() * sprite.scale.abs()
	var width: float = texture_size.x * Balance.SHADOW_WIDTH * width_scale
	if width <= 1.0:
		return null

	var shadow := Sprite2D.new()
	shadow.name = "ContactShadow"
	shadow.texture = quad_texture()
	shadow.material = material()
	# The quad is drawn larger than the pool inside it so the falloff and the
	# sun-driven slide both have somewhere to go without clipping at the edge.
	shadow.scale = Vector2.ONE * (width * 2.0 / float(quad_texture().width))
	shadow.position.y = (texture_size.y * 0.40) if is_nan(base_offset) else base_offset
	# Relative, so every contact shadow lands on one layer just under the sorted
	# units. A shadow must never be able to draw over somebody's boots.
	shadow.z_index = -1
	shadow.z_as_relative = true
	# Shadows are ground, not objects: they must not take part in y-sorting
	# against the thing casting them.
	shadow.y_sort_enabled = false
	target.add_child(shadow)
	return shadow


## Adds a real light blocker, so shadow-casting lights throw a streak of this
## thing across the ground.
##
## `layer` picks SHADOW_LAYER_SCENERY or SHADOW_LAYER_UNITS, which is how the
## town light shadows the people walking past it without shadowing itself.
static func add_caster(target: Node2D, half_width: float, half_height: float,
		layer: int = Balance.SHADOW_LAYER_SCENERY, base_offset: float = 0.0) -> LightOccluder2D:
	# No occluder means the shadow-casting lights have nothing to draw, which is
	# where most of the saving actually comes from - the light still runs its pass
	# either way, but an empty one is nearly free.
	if not Graphics.cast_shadows() or target == null:
		return null

	var polygon := OccluderPolygon2D.new()
	# An octagon rather than a box: a rectangular occluder throws a shadow with
	# visible corners, which on a round-ish tower looks like a bug.
	var points: PackedVector2Array = []
	for i: int in 8:
		var angle: float = TAU * float(i) / 8.0 + PI / 8.0
		points.append(Vector2(cos(angle) * half_width, sin(angle) * half_height))
	polygon.polygon = points
	polygon.cull_mode = OccluderPolygon2D.CULL_DISABLED

	var occluder := LightOccluder2D.new()
	occluder.name = "ShadowCaster"
	occluder.occluder = polygon
	occluder.occluder_light_mask = layer
	occluder.position.y = base_offset
	target.add_child(occluder)
	return occluder


## Keeps the shared material in step with the sky.
##
## A node rather than a signal wired up from a static, because a static holding a
## live connection into an autoload is the kind of thing that outlives the scene
## it was made for. Each scope that wants shadows adds one of these and it dies
## with the scope.
class SunSync extends Node:
	func _ready() -> void:
		DayNight.phase_changed.connect(_on_phase)
		_on_phase(DayNight.phase, DayNight.tint, DayNight.darkness)

	func _on_phase(phase: float, _tint: Color, darkness: float) -> void:
		ShadowKit.set_sun(phase, darkness)


## One line for a scope to opt into sun-tracking shadows.
static func attach_sun(scope: Node) -> void:
	if scope == null:
		return
	# Touching the material first means it exists before the first sync.
	material()
	var sync := SunSync.new()
	sync.name = "ShadowSun"
	scope.add_child(sync)
