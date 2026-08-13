class_name LightKit
extends RefCounted

## Builds 2D lights without needing any light art.
##
## PointLight2D requires a texture, and the project has no VFX assets. A radial
## GradientTexture2D is exactly the falloff a point light wants, and generating
## it means the look is tunable from Balance rather than baked into a PNG.
##
## Every light returned is already scaled by the current darkness, and registers
## itself with DayNight so it brightens at dusk and fades at dawn on its own. A
## light nobody has to remember to update is a light that cannot get out of sync.

## Cached so fifty towers share one texture rather than generating fifty.
## Lights that are supposed to cast shadows, so quality can restore them.
const SHADOW_GROUP: StringName = &"shadow_lights"
const ULTRA_SHADOW_GROUP: StringName = &"ultra_shadow_lights"

static var _falloff: GradientTexture2D = null


## A soft round falloff, white in the centre to transparent at the edge.
##
## The stop list is long on purpose. Three stops leave a shoulder in the curve
## that the eye picks out as the rim of a disc — which is exactly what the
## torches looked like from a distance. Five stops on a roughly inverse-square
## curve give a bright core and a long thin tail, and the tail is what makes a
## light look like light rather than like a circle of paint.
static func falloff_texture() -> GradientTexture2D:
	if _falloff != null:
		return _falloff
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.16, 0.36, 0.62, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1.00),
		Color(1, 1, 1, 0.58),
		Color(1, 1, 1, 0.26),
		Color(1, 1, 1, 0.08),
		Color(1, 1, 1, 0.00),
	])

	_falloff = GradientTexture2D.new()
	_falloff.gradient = gradient
	_falloff.fill = GradientTexture2D.FILL_RADIAL
	_falloff.fill_from = Vector2(0.5, 0.5)
	_falloff.fill_to = Vector2(1.0, 0.5)
	_falloff.width = 256
	_falloff.height = 256
	return _falloff


## Turns a light into one that throws real shadows off LightOccluder2D nodes.
##
## Kept separate from `add_light` because most lights must NOT do this. A light
## sitting inside the sprite it belongs to would shadow itself, and fifty of them
## would each pay for a shadow pass to produce nothing. Only the torches and the
## town — lights that stand apart from what they illuminate — get it.
static func enable_shadows(light: PointLight2D,
		cull_mask: int = Balance.SHADOW_LAYER_SCENERY | Balance.SHADOW_LAYER_UNITS,
		ultra_only: bool = false) -> void:
	if light == null or not Balance.SHADOW_CAST_ENABLED:
		return
	# Grouped so turning cast shadows back on mid-run can find exactly the lights
	# that were meant to cast. Without it the only way to restore them would be to
	# switch every light on, which lights the field from inside every sprite.
	light.add_to_group(SHADOW_GROUP)
	if ultra_only:
		light.add_to_group(ULTRA_SHADOW_GROUP)
	light.shadow_filter = Graphics.shadow_filter()
	light.shadow_filter_smooth = Balance.SHADOW_FILTER_SMOOTH
	# Fully transparent, because these lights are additive: a shadow here is the
	# absence of the light, not a dark colour painted over the ground. A tinted
	# shadow_color would stamp black wedges across the field in broad daylight.
	light.shadow_color = Color(0, 0, 0, 0)
	# Callers declare the layers they support; the selected quality decides how
	# many of those layers are worth rendering right now.
	light.shadow_item_cull_mask = cull_mask & Graphics.shadow_cull_mask()
	light.shadow_enabled = Graphics.cast_shadows() \
		and (not ultra_only or Graphics.preset() == Graphics.PRESET_ULTRA)


## Creates a light and attaches it to `parent`. `radius` is in pixels;
## `flicker` above zero makes it breathe, for fire and torches.
static func add_light(parent: Node2D, colour: Color, radius: float,
		energy: float, flicker: float = 0.0) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = falloff_texture()
	light.color = colour
	light.energy = energy
	light.texture_scale = radius / 128.0
	light.shadow_enabled = false
	# Lights sit under the sprites they belong to, so a tower is lit rather than
	# washed out by its own glow.
	light.blend_mode = Light2D.BLEND_MODE_ADD
	parent.add_child(light)

	var driver := LightDriver.new()
	driver.setup(light, energy, flicker)
	parent.add_child(driver)
	return light
