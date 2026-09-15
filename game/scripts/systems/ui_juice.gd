class_name UiJuice
extends RefCounted

## Holographic light on the interface, and the small motions that go with it.
##
## **Owner brief, 2026-09-15:** "holographic vfx for when players hover or tap
## on UI buttons as well and more game juice to UI interactions".
##
## **The bound is `UiTint`'s, and it is inherited rather than restated.** That
## file is allowed to move frames and forbidden to touch text, because an
## adaptive interface that gets it wrong is an unreadable one. The same
## reasoning binds this in a stronger form: the hologram is **additive**, so it
## can only ever add light, and over this game's dark plates and pale lettering
## it cannot reduce the contrast of a single glyph. `ui_juice_check` reads the
## shader's own ceiling back rather than trusting the number here.
##
## **It answers the pad and the thumb as well as the mouse.** A hover effect
## wired only to `mouse_entered` is a hover effect for one of the three ways
## this game is played, and the controller path is the one that always gets
## forgotten - so focus drives the same code, and a touch press drives the same
## press. That is also why the sweep is *driven* rather than looping: a hover is
## an event and the sweep is its answer, while a shimmer that loops forever is a
## screensaver behind a button.
##
## Opt-in by group, the way `UiTint` does it, because the HUD rebuilds parts of
## itself and a cached list of controls goes stale.

const GROUP: StringName = &"ui_juiced"
const SHADER: String = "res://scripts/shaders/ui_hologram.gdshader"
## The overlay's name inside a control, so a second enrol finds it rather than
## stacking another one.
const SKIN: StringName = &"HoloSkin"

static var _shader: Shader = null


## Give every button under `root` its hologram. Safe to call again.
static func enrol(tree: SceneTree, root: Node) -> void:
	_gather(root)
	for node: Node in tree.get_nodes_in_group(GROUP):
		var control := node as Control
		if control != null:
			dress(control)


static func _gather(from: Node) -> void:
	for child: Node in from.get_children():
		# Buttons only. A panel does not respond to being pointed at, and a
		# hologram over a whole panel is a tint by another name - which is
		# `UiTint`'s job and is bounded there.
		if child is BaseButton:
			var control := child as Control
			if not control.is_in_group(GROUP):
				control.add_to_group(GROUP)
		_gather(child)


## Put the skin on one control and wire it to the ways a player can touch it.
static func dress(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var button := control as BaseButton
	if button == null:
		return
	if control.get_node_or_null(NodePath(SKIN)) != null:
		return
	var skin := ColorRect.new()
	skin.name = SKIN
	skin.color = Color.WHITE
	skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin.set_anchors_preset(Control.PRESET_FULL_RECT)
	skin.material = _material()
	# **Above the plate and below nothing.** It has to be above, because the
	# button art is opaque and an additive layer behind it would never be seen;
	# it is safe above because it only adds light. See the note at the top.
	control.add_child(skin)
	if not button.mouse_entered.is_connected(_on_noticed.bind(control)):
		button.mouse_entered.connect(_on_noticed.bind(control))
		button.mouse_exited.connect(_on_left.bind(control))
		button.focus_entered.connect(_on_noticed.bind(control))
		button.focus_exited.connect(_on_left.bind(control))
		button.button_down.connect(_on_pressed.bind(control))


static func _material() -> ShaderMaterial:
	if _shader == null:
		_shader = load(SHADER) as Shader
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("strength", 0.0)
	material.set_shader_parameter("sweep", -1.0)
	material.set_shader_parameter("flicker", 0.0)
	material.set_shader_parameter("glow", Balance.UI_HOLO_GLOW)
	# Set rather than left to the shader's own default: `get_shader_parameter`
	# answers null for a uniform nothing has assigned, and the one reader of
	# this is the gate that holds the ceiling.
	material.set_shader_parameter("ceiling", Balance.UI_HOLO_CEILING)
	material.set_shader_parameter("lines", Balance.UI_HOLO_LINES)
	return material


## The skin on a control, or null. For the gate, and for anything that wants to
## drive one by hand.
static func skin_of(control: Control) -> ColorRect:
	if control == null or not is_instance_valid(control):
		return null
	return control.get_node_or_null(NodePath(SKIN)) as ColorRect


## How lit a control's skin is right now, from 0 to 1. For the gate.
static func strength_of(control: Control) -> float:
	var skin: ColorRect = skin_of(control)
	if skin == null:
		return 0.0
	var material := skin.material as ShaderMaterial
	if material == null:
		return 0.0
	return float(material.get_shader_parameter("strength"))


## Set the light the holograms are made of, from the interface's own tint.
## Called beside `UiTint.apply`, so the two never disagree about what the scene
## is lit by.
static func set_glow(tree: SceneTree, light: Color) -> void:
	# Pulled toward the authored cyan rather than replaced by the scene: a
	# hologram that is exactly the colour of the sunset behind it stops reading
	# as light of its own.
	var glow: Color = Balance.UI_HOLO_GLOW.lerp(light, Balance.UI_HOLO_SCENE_SHARE)
	for node: Node in tree.get_nodes_in_group(GROUP):
		var material := _material_of(node as Control)
		if material != null:
			material.set_shader_parameter("glow", glow)


static func _material_of(control: Control) -> ShaderMaterial:
	var skin: ColorRect = skin_of(control)
	return skin.material as ShaderMaterial if skin != null else null


## Pointed at, or focused. One sweep across, and the rim comes up and stays.
static func _on_noticed(control: Control) -> void:
	var material: ShaderMaterial = _material_of(control)
	if material == null:
		return
	_tween_to(control, material, 1.0, Balance.UI_HOLO_RISE)
	# The sweep is a one-shot from off the left edge to off the right, never a
	# loop. A second hover before the first has finished restarts it, which is
	# what a player flicking along a row of buttons should see.
	material.set_shader_parameter("sweep", -0.4)
	var tween: Tween = control.create_tween()
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(control):
			material.set_shader_parameter("sweep", value),
		-0.4, 1.4, Balance.UI_HOLO_SWEEP)
	# **And the button moves.** A hologram with a dead button under it is a
	# decal; a pixel of lift is what makes it feel picked up.
	_lift(control, Balance.UI_HOLO_LIFT)


static func _on_left(control: Control) -> void:
	var material: ShaderMaterial = _material_of(control)
	if material == null:
		return
	_tween_to(control, material, 0.0, Balance.UI_HOLO_FALL)
	_lift(control, 0.0)


## Pressed, tapped or clicked. The light jumps, the hologram tears for a
## moment, and the button dips under the thumb.
static func _on_pressed(control: Control) -> void:
	var material: ShaderMaterial = _material_of(control)
	if material == null:
		return
	material.set_shader_parameter("strength", 1.0)
	material.set_shader_parameter("flicker", 1.0)
	var tween: Tween = control.create_tween()
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(control):
			material.set_shader_parameter("flicker", value),
		1.0, 0.0, Balance.UI_HOLO_TEAR)
	_lift(control, -Balance.UI_HOLO_LIFT)
	var back: Tween = control.create_tween()
	back.tween_interval(Balance.UI_HOLO_TEAR)
	back.tween_callback(func() -> void:
		if is_instance_valid(control):
			_lift(control, Balance.UI_HOLO_LIFT if control.has_focus() else 0.0))


static func _tween_to(control: Control, material: ShaderMaterial,
		wanted: float, seconds: float) -> void:
	var tween: Tween = control.create_tween()
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(control):
			material.set_shader_parameter("strength", value),
		float(material.get_shader_parameter("strength")), wanted, seconds)


## A control's own vertical nudge.
##
## **Pivoted and offset rather than scaled.** Scaling a `Control` inside a
## container fights the container's own layout every frame, and this project
## has a `layout_check` that would rightly fail a button whose rect moved. An
## offset on the *skin's* parent is not available either, so the nudge lives on
## `position` and is put back exactly - the containers here lay out on resize
## rather than continuously, which is what makes that safe.
static func _lift(control: Control, by: float) -> void:
	if control == null or not is_instance_valid(control):
		return
	if not control.has_meta(&"holo_home"):
		control.set_meta(&"holo_home", control.position)
	var home: Vector2 = control.get_meta(&"holo_home")
	var tween: Tween = control.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control, "position", home + Vector2(0.0, -by),
		Balance.UI_HOLO_RISE)
