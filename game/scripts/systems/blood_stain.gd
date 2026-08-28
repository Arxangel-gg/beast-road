class_name BloodStain
extends RefCounted

## Blood that stays on a character, in proportion to how badly hurt they are.
##
## Driven from health rather than from hits, which is what makes it recover:
## a hero patched up between roads loses most of it, and one who is nearly down
## is visibly nearly down from across the field. That second property is the
## reason to have it at all - a health bar is a number you read, and this is a
## state you see without looking.
##
## The material is per-character, because each carries its own `seed` so two
## Wardens standing together do not bleed in identical patterns.

const SHADER_PATH: String = "res://scripts/shaders/blood_stain.gdshader"

## Loaded once for the whole game rather than looked up per character.
##
## `attach` is called from a per-frame update, and it answers `null` for any
## sprite that already has a material - so for those characters it was asked
## again every frame, and every ask ran `ResourceLoader.exists`. With a field
## full of enemies that is hundreds of filesystem checks a frame, which is how a
## 45 second measurement stopped finishing at all.
##
## Callers must also remember they have asked. See `Hero._blood_tried`.
static var _shader: Shader = null
static var _looked: bool = false


## The stain shader, or null when this build has none.
static func shader() -> Shader:
	if not _looked:
		_looked = true
		if ResourceLoader.exists(SHADER_PATH):
			_shader = load(SHADER_PATH) as Shader
	return _shader


## Gives a sprite its own stain material. Safe to call on a sprite that has one.
static func attach(sprite: CanvasItem, seed_source: int) -> ShaderMaterial:
	if sprite == null or shader() == null:
		return null
	if sprite.material is ShaderMaterial \
			and (sprite.material as ShaderMaterial).shader != null \
			and (sprite.material as ShaderMaterial).shader.resource_path == SHADER_PATH:
		return sprite.material as ShaderMaterial
	# Never over an existing material. Something else wanted that sprite drawn a
	# particular way and blood is not worth silently undoing it.
	if sprite.material != null:
		return null
	var material := ShaderMaterial.new()
	material.shader = shader()
	material.set_shader_parameter("seed", float(absi(seed_source) % 997))
	material.set_shader_parameter("blood_colour", Balance.BLOOD_FRESH)
	material.set_shader_parameter("outline_colour", Balance.ACTOR_OUTLINE_COLOUR)
	material.set_shader_parameter("outline_strength",
		Balance.ACTOR_OUTLINE_STRENGTH if Graphics.polish_shaders() else 0.0)
	material.set_shader_parameter("impact_colour", Balance.IMPACT_RIM_COLOUR)
	material.set_shader_parameter("impact_strength", 0.0)
	# Set explicitly. An unset uniform reads back as null rather than as its
	# declared default, so the first `drive` would be doing arithmetic on nothing.
	material.set_shader_parameter("stain", 0.0)
	sprite.material = material
	return material


## How stained a material currently is. Reads back as null until first set.
static func level(material: ShaderMaterial) -> float:
	if material == null:
		return 0.0
	var raw: Variant = material.get_shader_parameter("stain")
	return float(raw) if raw != null else 0.0


## Moves the stain toward what the character's health says it should be.
##
## Asymmetric on purpose. A wound shows at once; healing washes off over a few
## seconds, because a sprite that snaps clean the instant a heal lands reads as a
## rendering fault rather than as recovery.
static func drive(material: ShaderMaterial, health_fraction: float,
		delta: float) -> void:
	if material == null:
		return
	if not bool(UserSettings.value(UserSettings.BLOOD_VFX_KEY, true)):
		material.set_shader_parameter("stain", 0.0)
		return
	var wanted: float = clampf(1.0 - clampf(health_fraction, 0.0, 1.0), 0.0, 1.0) \
		* Balance.BLOOD_STAIN_MAX
	var current: float = level(material)
	var rate: float = Balance.BLOOD_STAIN_ON if wanted > current \
		else Balance.BLOOD_STAIN_OFF
	material.set_shader_parameter("stain",
		move_toward(current, wanted, rate * delta))


static func strike(material: ShaderMaterial, direction: Vector2) -> void:
	if material == null:
		return
	material.set_shader_parameter("impact_direction",
		direction.normalized() if direction.length() > 0.001 else Vector2.UP)
	material.set_shader_parameter("impact_strength", Balance.IMPACT_RIM_STRENGTH)


static func drive_impact(material: ShaderMaterial, left: float) -> void:
	if material != null:
		material.set_shader_parameter("impact_strength",
			clampf(left / maxf(Balance.HIT_FLASH_TIME, 0.001), 0.0, 1.0)
			* Balance.IMPACT_RIM_STRENGTH)
