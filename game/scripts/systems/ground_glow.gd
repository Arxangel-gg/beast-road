class_name GroundGlow
extends Sprite2D

## A pool of light that comes up with the dark, in the colour the light takes
## from what it falls on.
##
## Taken from Core Keeper (2026-09-23, `docs/IDEAS_REVIEW_2026-09-23.md`), whose
## bounce light "takes surface color into account": a torch on red earth throws
## a redder pool than one on snow. Real bounce light is a renderer this game does
## not have and every `PointLight2D` re-draws everything under it, so this is the
## cheap version the torches already use for their pools - an additive falloff
## sprite on the ground, one quad - with its colour multiplied by the ground
## under it (`Battlefield.ground_colour`) rather than typed in.
##
## **Presentation only.** Nothing reads a glow; it is lit by `DayNight.darkness`
## and nothing else, and it re-reads the ground when the region changes, so a
## tower that stood through Act IV does not keep Act IV's earth under it.
##
## Used by the town (a wide warm pool), every tower (its element's colour), every
## torch (its pool, tinted), and the ore and gem seams (a halo behind the stone).

## The light before the ground touches it.
var light_colour: Color = Color.WHITE
## How bright at deep night, 0 to 1.
var strength: float = 0.5
## Whether the ground under it colours it.
var bounce: bool = true
var _clock: float = 0.0
var _phase: float = 0.0


## Lays a pool under `parent`. `squash` flattens it onto the ground the camera
## looks down and along; 1 is a round halo, for a glow behind a thing rather than
## under it.
static func lay(parent: Node2D, colour: Color, radius: float, glow_strength: float,
		squash: float = Balance.TORCH_POOL_SQUASH, on_ground: bool = true) -> GroundGlow:
	var glow := GroundGlow.new()
	glow.name = "GroundGlow"
	glow.light_colour = colour
	glow.strength = glow_strength
	glow.bounce = on_ground
	glow.texture = LightKit.falloff_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	var span: float = radius * 2.0 / maxf(float(glow.texture.get_width()), 1.0)
	glow.scale = Vector2(span, span * squash)
	if on_ground:
		# Under the thing and its shadow, over the ground it stands on.
		glow.z_index = -2
	else:
		glow.show_behind_parent = true
	glow.modulate = Color(colour, 0.0)
	glow.visible = false
	parent.add_child(glow)
	return glow


func _ready() -> void:
	_phase = float(absi(get_instance_id()) % 628) / 100.0
	_tint()
	EventBus.act_started.connect(_on_act_started)


func _on_act_started(_act: int, _terrain_id: String) -> void:
	_tint()


## The light as it lands: its colour multiplied by the ground's, lifted so dark
## earth tints a pool rather than putting it out, and held at the light's own
## brightness so the tint moves the hue and never the strength.
func _tint() -> void:
	var colour: Color = light_colour
	if bounce:
		var field: Battlefield = _field()
		if field != null:
			colour = bounced(light_colour, field.ground_colour(global_position))
	modulate = Color(colour, modulate.a)


## Pure, for the pool and for the gate.
static func bounced(light: Color, ground: Color) -> Color:
	var lifted: Color = ground.lerp(Color.WHITE, Balance.GROUND_BOUNCE_LIFT)
	var landed := Color(light.r * lifted.r, light.g * lifted.g, light.b * lifted.b)
	var peak: float = maxf(maxf(landed.r, landed.g), maxf(landed.b, 0.001))
	var level: float = maxf(maxf(light.r, light.g), light.b)
	landed = Color(landed.r / peak * level, landed.g / peak * level, landed.b / peak * level)
	return light.lerp(landed, Balance.GROUND_BOUNCE_SHARE)


func _field() -> Battlefield:
	var node: Node = get_parent()
	while node != null:
		if node is Battlefield:
			return node as Battlefield
		node = node.get_parent()
	return null


func _process(delta: float) -> void:
	_clock += delta
	var lit: float = smoothstep(Balance.GROUND_GLOW_FROM, 1.0, DayNight.darkness) * strength
	var breath: float = 0.9 + 0.1 * sin(_clock * 0.9 + _phase)
	modulate.a = lit * breath
	visible = modulate.a > 0.004
