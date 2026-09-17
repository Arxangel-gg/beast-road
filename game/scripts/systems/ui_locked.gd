class_name UiLocked

## One answer to "you have not got this yet", used everywhere.
##
## Owner, 2026-09-17: *"If a mount is locked it should just be the silhouette,
## still idle animated and properly disabled buttons and dimmed. Disabled buttons
## and dimming the selection for any locked materials should be applied all
## throughout our game where applicable perfectly and polished."*
##
## **Three things happen together or the state reads wrong**, and that is the
## whole argument for one function rather than each screen doing its own:
##
## - the **picture** becomes a silhouette, so the shape is still information -
##   a heavy draught horse and a light courser are still told apart - while the
##   detail is not;
## - the **plate** dims, so the row reads as inactive at a glance rather than on
##   inspection;
## - the **button** is genuinely `disabled`, not merely dark. A button that looks
##   dead and still answers a press is the worse of the two failures, because a
##   player who finds it once stops trusting the rest of the screen.
##
## Screens that did two of the three shipped a mount you could dim-buy and a
## material you could select and then be refused by a message. One door.
##
## **Nothing here is a rule about what *is* locked.** That is each screen's
## question - Marks held, a level reached, a blueprint known - and this only
## draws the answer. So turning a locked thing unlocked is one call with `false`
## and no node is rebuilt, which is what lets a purchase land in front of the
## player rather than after a reload.

const SHADER: String = "res://scripts/shaders/ui_silhouette.gdshader"

## What this file put on a control, so the release is exact rather than a guess
## at what the modulate used to be - the same ledger rule `CrispText` releases a
## muted caption under.
const HELD: StringName = &"ui_locked_was"

static var _shader: Shader = null


## Locks or unlocks a whole row: its plate, its picture and its button.
##
## `picture` may be null for a row that has none, and `button` may be null for a
## row that is not pressable. Both are separate arguments rather than found by
## walking, because a row often holds more than one image - an icon and a rarity
## pip - and only one of them is the thing being earned.
static func set_locked(row: Control, locked: bool, picture: CanvasItem = null,
		button: BaseButton = null) -> void:
	if row != null and is_instance_valid(row):
		_dim(row, locked)
	if picture != null and is_instance_valid(picture):
		silhouette(picture, locked)
	if button != null and is_instance_valid(button):
		button.disabled = locked
		# **The pointer says so before the press does.** A disabled button that
		# still shows a hand is an invitation, and the refusal then reads as the
		# screen being broken rather than as the thing being locked.
		button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if locked \
			else Control.CURSOR_POINTING_HAND


## Draws one picture as its own shape, or puts it back.
##
## **The material is kept and the uniform moved**, rather than assigned and
## cleared: a `MountRig` or an `AnimatedSprite2D` under this keeps animating
## either way, which is the owner's *"still idle animated"* - the frames never
## learn about it.
static func silhouette(picture: CanvasItem, locked: bool) -> void:
	if picture == null or not is_instance_valid(picture):
		return
	var material := picture.material as ShaderMaterial
	if material == null or material.shader != _load():
		if not locked:
			return
		material = ShaderMaterial.new()
		material.shader = _load()
		if material.shader == null:
			return
		material.set_shader_parameter("ink", Balance.UI_LOCKED_INK)
		material.set_shader_parameter("edge", Balance.UI_LOCKED_EDGE)
		picture.material = material
	material.set_shader_parameter("locked", 1.0 if locked else 0.0)


## Whether a picture is currently drawn as a silhouette. For the gate, and for a
## screen that rebuilds a row and wants to know what it was.
static func is_silhouetted(picture: CanvasItem) -> bool:
	if picture == null or not is_instance_valid(picture):
		return false
	var material := picture.material as ShaderMaterial
	if material == null or material.shader != _load():
		return false
	return float(material.get_shader_parameter("locked")) > 0.5


## Dims a row, remembering what it was.
##
## Recorded rather than assumed, because a row may already carry a modulate of
## its own - a rarity tint, a co-op ally colour - and putting back a flat white
## would quietly repaint it.
static func _dim(row: Control, locked: bool) -> void:
	if locked:
		if not row.has_meta(HELD):
			row.set_meta(HELD, row.modulate)
		row.modulate = (row.get_meta(HELD) as Color) * Balance.UI_LOCKED_DIM
		return
	if row.has_meta(HELD):
		row.modulate = row.get_meta(HELD) as Color
		row.remove_meta(HELD)


static func _load() -> Shader:
	if _shader == null and ResourceLoader.exists(SHADER):
		_shader = load(SHADER) as Shader
	return _shader
