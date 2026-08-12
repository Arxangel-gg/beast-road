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
static var _falloff: GradientTexture2D = null


## A soft round falloff, white in the centre to transparent at the edge.
static func falloff_texture() -> GradientTexture2D:
	if _falloff != null:
		return _falloff
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		# The mid stop is what stops a 2D light looking like a hard disc.
		Color(1, 1, 1, 0.35),
		Color(1, 1, 1, 0),
	])

	_falloff = GradientTexture2D.new()
	_falloff.gradient = gradient
	_falloff.fill = GradientTexture2D.FILL_RADIAL
	_falloff.fill_from = Vector2(0.5, 0.5)
	_falloff.fill_to = Vector2(1.0, 0.5)
	_falloff.width = 256
	_falloff.height = 256
	return _falloff


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
