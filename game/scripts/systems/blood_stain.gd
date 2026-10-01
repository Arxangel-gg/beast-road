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
	material.set_shader_parameter("cluster_pixels", Balance.BLOOD_STAIN_CLUSTER_PIXELS)
	material.set_shader_parameter("fine_scatter", Balance.BLOOD_STAIN_FINE_SCATTER)
	material.set_shader_parameter("outline_colour", Balance.ACTOR_OUTLINE_COLOUR)
	material.set_shader_parameter("outline_strength",
		Balance.ACTOR_OUTLINE_STRENGTH if Graphics.polish_shaders() else 0.0)
	material.set_shader_parameter("impact_colour", Balance.IMPACT_RIM_COLOUR)
	material.set_shader_parameter("impact_strength", 0.0)
	# Set explicitly. An unset uniform reads back as null rather than as its
	# declared default, so the first `drive` would be doing arithmetic on nothing.
	material.set_shader_parameter("stain", 0.0)
	material.set_shader_parameter("wound_elsewhere", Balance.BLOOD_WOUND_ELSEWHERE)
	sprite.material = material
	# A body turned to the light (2026-09-25). See `ActorShade`.
	ActorShade.dress(material, sprite)
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
	fade_wounds(material, wanted <= 0.0001 and current <= 0.0001, delta)
	var rate: float = Balance.BLOOD_STAIN_ON if wanted > current \
		else Balance.BLOOD_STAIN_OFF
	var next: float = move_toward(current, wanted, rate * delta)
	if is_equal_approx(next, current):
		return
	material.set_shader_parameter("stain", next)


## **A wound where the blow struck** (2026-10-01). The point is turned into a
## texel of the body's own cell - centred or not, flipped or not, a sheet's
## region or a whole frame - and kept with the last few, each a spot the stain
## gathers round, wider and fresher by the share of the pool the blow took.
static func wound(material: ShaderMaterial, sprite: Sprite2D, at: Vector2, share: float) -> void:
	if material == null or sprite == null or sprite.texture == null:
		return
	if not bool(UserSettings.value(UserSettings.BLOOD_VFX_KEY, true)):
		return
	var texel: Vector2 = texel_of(sprite, at)
	var amount: float = sqrt(clampf(share, 0.0, 1.0))
	var wounds: Array = material.get_meta(&"wounds", []) as Array
	wounds.append(Vector4(texel.x, texel.y,
		lerpf(Balance.BLOOD_WOUND_RADIUS_TEXELS.x, Balance.BLOOD_WOUND_RADIUS_TEXELS.y, amount),
		lerpf(Balance.BLOOD_WOUND_FRESH.x, Balance.BLOOD_WOUND_FRESH.y, amount)))
	while wounds.size() > Balance.BLOOD_WOUNDS:
		wounds.pop_front()
	material.set_meta(&"wounds", wounds)
	follow_cell(material, sprite)
	_send(material, wounds)


## **Blood to the height a body waded** (owner, 2026-10-01): the band of the
## sprite's own cell from `units` above its feet down to them, written to
## whichever body material it wears - `blood_stain` and `actor_polish` both
## read it. The caller keeps the highest it has reached; it never comes down.
##
## `feet_texel` names the row of the cell the painted feet stand on, when the
## caller knows it better than the node's position does - the dressed Warden's
## sheets carry it per facing, and its node stands a little below the paint.
static func wade(material: ShaderMaterial, sprite: Sprite2D, feet: Vector2, units: float,
		feet_texel: float = -1.0) -> void:
	if material == null or sprite == null or sprite.texture == null or units <= 0.0:
		return
	var bottom: float = texel_of(sprite, feet).y
	var top: float = texel_of(sprite, feet - Vector2(0.0, units)).y
	if feet_texel >= 0.0:
		top = feet_texel - absf(bottom - top)
		bottom = feet_texel
	material.set_shader_parameter("wade_band", Vector2(minf(top, bottom), maxf(top, bottom) + 2.0))


## Where a world point falls on a sprite's own cell, in texels of that cell.
static func texel_of(sprite: Sprite2D, at: Vector2) -> Vector2:
	var cell: Vector2 = cell_size(sprite)
	var local: Vector2 = sprite.to_local(at) - sprite.offset
	var texel: Vector2 = local + (cell * 0.5 if sprite.centered else Vector2.ZERO)
	if sprite.flip_h:
		texel.x = cell.x - texel.x
	if sprite.flip_v:
		texel.y = cell.y - texel.y
	return texel


static func cell_size(sprite: Sprite2D) -> Vector2:
	var whole: Vector2 = sprite.region_rect.size if sprite.region_enabled \
		else sprite.texture.get_size()
	return whole / Vector2(maxi(sprite.hframes, 1), maxi(sprite.vframes, 1))


## Where the sprite's current cell starts on its texture, so a wound kept in
## cell texels stays on the body as a sheet steps through its frames. Written
## only when it moves.
static func follow_cell(material: ShaderMaterial, sprite: Sprite2D) -> void:
	if material == null or sprite == null or sprite.texture == null:
		return
	var origin: Vector2 = Vector2.ZERO
	if sprite.region_enabled:
		origin = sprite.region_rect.position
	if sprite.hframes > 1 or sprite.vframes > 1:
		origin += Vector2(sprite.frame_coords) * cell_size(sprite)
	if material.get_meta(&"cell_origin", Vector2(-1.0, -1.0)) == origin:
		return
	material.set_meta(&"cell_origin", origin)
	material.set_shader_parameter("cell_origin", origin)


## The wounds the shader reads: always `BLOOD_WOUNDS` of them, empty ones zero.
static func _send(material: ShaderMaterial, wounds: Array) -> void:
	var out := PackedVector4Array()
	for wound_at: Variant in wounds:
		out.append(wound_at as Vector4)
	while out.size() < Balance.BLOOD_WOUNDS:
		out.append(Vector4.ZERO)
	material.set_shader_parameter("wounds", out)


## The wounds kept on a material, for the gate.
static func wounds_of(material: ShaderMaterial) -> Array:
	return material.get_meta(&"wounds", []) as Array if material != null else []


## Fades the wounds kept on a body, a few times a second rather than every
## frame - an array written to a shader is not free - and lets them all go once
## the body has healed clean.
static func fade_wounds(material: ShaderMaterial, healed: bool, delta: float) -> void:
	if material == null:
		return
	var wounds: Array = material.get_meta(&"wounds", []) as Array
	if wounds.is_empty():
		return
	if healed:
		material.set_meta(&"wounds", [])
		_send(material, [])
		return
	var bank: float = float(material.get_meta(&"wound_clock", 0.0)) + delta
	if bank < 0.25:
		material.set_meta(&"wound_clock", bank)
		return
	material.set_meta(&"wound_clock", 0.0)
	var kept: Array = []
	for wound_at: Variant in wounds:
		var w: Vector4 = wound_at as Vector4
		w.w -= bank / Balance.BLOOD_WOUND_FADE_SECONDS
		if w.w > 0.01:
			kept.append(w)
	material.set_meta(&"wounds", kept)
	_send(material, kept)


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
