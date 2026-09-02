class_name ActorState
extends RefCounted

## Combat state a player reads off a body: burning, freezing, about to strike.
##
## Owner request, 2026-09-01. All three were a flat `sprite.modulate` multiply -
## orange for fire, blue for ice, a pulsing cream for the tell - and a flat wash
## over a sprite reads as a status effect rather than as the thing happening. The
## argument, and the replacement, live in `actor_state.gdshaderinc`; this is the
## thin layer that points the uniforms at the numbers the game already keeps.
##
## ## It writes to whichever material the sprite already wears
##
## An enemy wears `blood_stain`; a promoted one wears `actor_polish`, because
## whichever material is claimed first wins and promotion happens before the
## first blood tick. Both shaders include the same file, so both answer to the
## same uniform names, and this does not need to know or care which it has.
##
## ## Null is a supported answer
##
## Not on the Low preset, which is the intuitive guess and is wrong: `BloodStain`
## attaches whatever the preset, and only zeroes its outline. What actually
## produces null is a build whose shader failed to load, plus any sprite some
## other system has already dressed for its own reasons.
##
## Callers must keep a tint fallback for that case regardless. A machine losing
## the *look* of a wind-up is a downgrade; losing the wind-up itself is a
## different difficulty setting. `carried()` is how a caller asks which it got.

## Whether a sprite has a material that understands these uniforms.
##
## Asked rather than assumed, because the answer decides whether the caller still
## needs to tint. Checking the shader's own path rather than trusting that a
## material exists - something else may have dressed this sprite for its own
## reasons, and writing unknown uniforms onto it would silently do nothing.
static func carried(material: ShaderMaterial) -> bool:
	if material == null or material.shader == null:
		return false
	var path: String = material.shader.resource_path
	return path == BloodStain.SHADER_PATH or path == ActorPolish.SHADER_PATH


## Fixes the pattern fire and frost land in for this body.
##
## Per body rather than global, so two enemies burning shoulder to shoulder do
## not burn in the same places and read as one animation played twice.
static func seed_pattern(material: ShaderMaterial, source: int) -> void:
	if not carried(material):
		return
	material.set_shader_parameter("state_seed", float(absi(source) % 991))
	material.set_shader_parameter("burn_colour", Balance.STATE_BURN_COLOUR)
	material.set_shader_parameter("frost_colour", Balance.STATE_FROST_COLOUR)
	material.set_shader_parameter("telegraph_colour", Balance.STATE_TELEGRAPH_COLOUR)
	material.set_shader_parameter("telegraph_width", Balance.STATE_TELEGRAPH_WIDTH)
	material.set_shader_parameter("shine_colour", Balance.SPIRIT_SHINY_COLOUR)


## The three meters, every frame they are non-zero.
##
## Written unconditionally rather than only on change: they are three floats on a
## material that is already bound, and tracking which of them moved would cost
## more than setting them. What is *not* unconditional is the shader work each
## one triggers, which every branch in the include guards on being above zero.
static func drive(material: ShaderMaterial, burning: float, frozen: float,
		winding_up: float) -> void:
	if not carried(material):
		return
	material.set_shader_parameter("burn", clampf(burning, 0.0, 1.0))
	material.set_shader_parameter("frost", clampf(frozen, 0.0, 1.0))
	material.set_shader_parameter("telegraph", clampf(winding_up, 0.0, 1.0))


## Marks a body as a shiny variant, or stops.
##
## Separate from `drive` because it is set once when the animal is placed and
## never changes: a shiny is decided at spawn and nothing the player does can
## reroll it. Driving it per frame would be three hundred writes a second to say
## the same thing.
static func shine(material: ShaderMaterial, lit: bool) -> void:
	if not carried(material):
		return
	material.set_shader_parameter("shine_colour", Balance.SPIRIT_SHINY_COLOUR)
	material.set_shader_parameter("shine", 1.0 if lit else 0.0)


## How far a dying body has come apart, and in what colour.
##
## The colour is chosen from the condition the body was in when it died, which is
## the whole reason this takes those two numbers rather than just a fraction: a
## death that says *how* it happened is a death that taught the player something
## about the tower that caused it.
static func dissolve(material: ShaderMaterial, through: float, burning: float,
		frozen: float) -> void:
	if not carried(material):
		return
	var hue: Color = Balance.STATE_DISSOLVE_COLOUR
	# Whichever condition was stronger at the end wins, and neither wins on a
	# body that merely had a little of it - a wolf that walked through one ember
	# did not die of fire.
	if burning >= frozen and burning > 0.35:
		hue = Balance.STATE_BURN_COLOUR
	elif frozen > 0.35:
		hue = Balance.STATE_FROST_COLOUR
	material.set_shader_parameter("dissolve_colour", hue)
	material.set_shader_parameter("dissolve", clampf(through, 0.0, 1.0))


## How lit a body with this much burn left should look.
##
## Full while there is real time left and tapering over the last stretch, so a
## fire that is about to expire visibly goes out instead of switching off. The
## meter the game keeps is seconds remaining, and seconds remaining is exactly
## what a player wants to know: a target still worth leaving alone versus one
## that needs hitting again.
static func burn_level(seconds_left: float) -> float:
	if seconds_left <= 0.0:
		return 0.0
	return clampf(seconds_left / maxf(Balance.STATE_BURN_FADE_SECONDS, 0.05), 0.0, 1.0)


## How far through its wind-up a body is, as a rim that thickens toward the hit.
##
## Starts at a floor rather than at zero. A tell that fades *in* is a tell the
## player reads late, and late is the whole failure this communicates against;
## the rim appears at once and then grows, so the first frame says "something is
## coming" and every frame after says how soon.
static func telegraph_level(seconds_left: float, windup: float) -> float:
	if seconds_left <= 0.0 or windup <= 0.0:
		return 0.0
	var through: float = clampf(1.0 - seconds_left / windup, 0.0, 1.0)
	return lerpf(Balance.STATE_TELEGRAPH_FLOOR, 1.0, through)
