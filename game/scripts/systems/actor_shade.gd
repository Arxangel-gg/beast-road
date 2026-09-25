class_name ActorShade
extends RefCounted

## Turns a body toward the light (owner, 2026-09-25: "shaded bodies wanted").
##
## Towers have shaded with the light's direction since 2026-09-23: the relief
## is read off the painting in `actor_shade.gdshaderinc`, which both actor
## shaders include. This is the one place a *body* is given it - called by
## `BloodStain.attach` and `ActorPolish.attach`, which between them dress every
## enemy, the Warden, every animal and every companion - so a body added
## tomorrow shades without anybody remembering this file. A tower sets its own,
## stronger values after it attaches, which is why that stays in `tower.gd`.
##
## A look and never a fact: nothing reads a shade, and at strength zero the
## shader is the engine's own light, byte for byte.


## Dresses a freshly attached actor material, and lets the sun's relief reach
## the sprite wearing it. Nothing on Low or below.
static func dress(material: ShaderMaterial, sprite: CanvasItem) -> void:
	if material == null or not Graphics.polish_shaders():
		return
	material.set_shader_parameter("shade_strength", Balance.BODY_SHADE_STRENGTH)
	material.set_shader_parameter("shade_relief", Balance.BODY_SHADE_RELIEF)
	material.set_shader_parameter("shade_reach", Balance.BODY_SHADE_REACH)
	material.set_shader_parameter("shade_gain", Balance.BODY_SHADE_GAIN)
	if sprite != null:
		sprite.light_mask |= Balance.SUN_RELIEF_LAYER
