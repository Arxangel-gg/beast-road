class_name RankSheen
extends Sprite2D

## The light that says a creature is not an ordinary one.
##
## **Owner brief, 2026-09-15:** "Elite and Champion enemies should have a hint of
## holographic-esque vfx juice as well, and rarer wildlife should have it as well
## slightly as well as a slight colour tint to indicate their rarity as well as
## having an outline aura too. Shinys should be super holographic and high
## contrast with awesome glorious vfx, especially legendary shinies."
##
## **An overlay rather than a material on the creature**, and that is the whole
## reason this is a node. A sprite has one material slot, and on a promoted body
## `ActorState` already owns it - the polish that carries burning, chill, wet and
## the rest. A second shader there would have to be merged into the first and
## the two would drift the first time either was tuned. So the sheen is a second
## sprite over the first, additive, wearing the same texture.
##
## **It follows rather than duplicates.** Every frame it copies whatever the
## creature is drawing - the frame, the flip, the offset, the region - so an
## animal that walks, an enemy that swings and a body that dies all carry it
## without any of them knowing it exists. The shader emits only the *added*
## light, never the art, so what shows through underneath is the creature and
## whatever `ActorState` is doing to it.
##
## **It is a look and never a number.** Nothing reads it: not targeting, not
## aggro, not loot, not the collection. `Graphics.KEY_RANK_SHEEN` turns every
## one of them off and no number in the game moves - the same bound the fog is
## held to, and the reason both can be switched off on a weak machine.

const SHADER: String = "res://scripts/shaders/creature_rank.gdshader"
const NAME: StringName = &"RankSheen"

static var _shader: Shader = null

var _worn: Sprite2D = null
var _clock: float = 0.0


## Put a sheen on a creature's sprite, or move an existing one to a new rank.
##
## `rank` is the amplitude and nothing else: a champion is a hint, a rare animal
## is a tint and a rim, a shiny is all of it. Zero takes the sheen off, which is
## what a body that stops being special would want - nothing does that today,
## and the door is here rather than being added under pressure later.
static func dress(sprite: Sprite2D, rank: float, colour: Color,
		shiny: bool = false) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var worn := sprite.get_node_or_null(NodePath(NAME)) as RankSheen
	if rank <= 0.0 or not Graphics.rank_sheen():
		if worn != null:
			worn.queue_free()
		return
	if worn == null:
		worn = RankSheen.new()
		worn.name = NAME
		worn.centered = sprite.centered
		worn.texture_filter = sprite.texture_filter
		# **The blend lives in the shader's `render_mode`**, not in a
		# CanvasItemMaterial: the two share one slot, and a sprite that needs
		# both an additive blend and a shader has to get the blend from the
		# shader. `ui_hologram.gdshader` is the same pair.
		worn._worn = sprite
		sprite.add_child(worn)
		worn.material = _paint()
	var paint := worn.material as ShaderMaterial
	if paint != null:
		paint.set_shader_parameter("rank", clampf(rank, 0.0, 1.0))
		paint.set_shader_parameter("rarity", colour)
		paint.set_shader_parameter("shine", 1.0 if shiny else 0.0)


## The sheen on a sprite, or null. For the gate, and for anything that wants to
## ask rather than guess at a node path.
static func worn_by(sprite: Sprite2D) -> RankSheen:
	if sprite == null or not is_instance_valid(sprite):
		return null
	return sprite.get_node_or_null(NodePath(NAME)) as RankSheen


static func _paint() -> ShaderMaterial:
	if _shader == null:
		_shader = load(SHADER) as Shader
	var paint := ShaderMaterial.new()
	paint.shader = _shader
	paint.set_shader_parameter("rank", 0.0)
	paint.set_shader_parameter("shine", 0.0)
	# Set rather than left to the shader's defaults: `get_shader_parameter`
	# answers null for a uniform nothing has assigned, and the gate reads these.
	paint.set_shader_parameter("tint_share", Balance.RANK_SHEEN_TINT)
	paint.set_shader_parameter("rim_strength", Balance.RANK_SHEEN_RIM)
	paint.set_shader_parameter("scan_strength", Balance.RANK_SHEEN_SCAN)
	paint.set_shader_parameter("scan_lines", Balance.RANK_SHEEN_LINES)
	return paint


func _ready() -> void:
	if _worn == null:
		_worn = get_parent() as Sprite2D
	set_process(true)


func _process(delta: float) -> void:
	if _worn == null or not is_instance_valid(_worn):
		queue_free()
		return
	_clock += delta
	# Whatever the creature is drawing this frame. Assignments rather than a
	# copy: a texture is a reference and this runs on the handful of bodies that
	# are actually ranked, never on the roster.
	if texture != _worn.texture:
		texture = _worn.texture
	flip_h = _worn.flip_h
	flip_v = _worn.flip_v
	offset = _worn.offset
	region_enabled = _worn.region_enabled
	if region_enabled:
		region_rect = _worn.region_rect
	var paint := material as ShaderMaterial
	if paint != null:
		paint.set_shader_parameter("clock", _clock)


## How lit this sheen is, and what colour. For the gate.
func amplitude() -> float:
	var paint := material as ShaderMaterial
	return float(paint.get_shader_parameter("rank")) if paint != null else 0.0
