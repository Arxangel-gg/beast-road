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
## Plates, which get the standing animation and none of the interaction.
##
## A second group rather than a flag on the first, because the two are enrolled
## by different rules and dressed differently - a plate's skin goes *under* its
## contents and a button's goes over them.
const PLATE_GROUP: StringName = &"ui_juiced_plate"
## Bars, whose fill is animated rather than their plate.
const BAR_GROUP: StringName = &"ui_juiced_bar"
const BAR_SHADER: String = "res://scripts/shaders/ui_bar.gdshader"
const BAR_SKIN: StringName = &"BarSkin"
const SHADER: String = "res://scripts/shaders/ui_hologram.gdshader"
## The overlay's name inside a control, so a second enrol finds it rather than
## stacking another one.
const SKIN: StringName = &"HoloSkin"
## What this file has put on a control, so the layout's own answer can be
## recovered from where the control currently is.
const APPLIED: StringName = &"holo_lift"
const TWEEN: StringName = &"holo_tween"
const WATCHED: StringName = &"holo_watched"

static var _shader: Shader = null
static var _bar_shader: Shader = null
## Walks the offsets so no two controls dressed in one pass share a clock.
static var _phase: float = 0.0


## Give every button under `root` its hologram. Safe to call again.
static func enrol(tree: SceneTree, root: Node) -> void:
	_gather(root)
	for node: Node in tree.get_nodes_in_group(GROUP):
		var control := node as Control
		if control != null:
			dress(control)
	for node: Node in tree.get_nodes_in_group(PLATE_GROUP):
		var plate := node as Control
		if plate != null:
			dress_plate(plate)
	for node: Node in tree.get_nodes_in_group(BAR_GROUP):
		var bar := node as ProgressBar
		if bar != null:
			dress_bar(bar)


## **The "buttons only" rule was about interaction, and it still is.**
##
## This file used to say, in as many words, that *"a panel does not respond to
## being pointed at, and a hologram over a whole panel is a tint by another
## name"*. That reasoning is correct and unchanged: a plate gets no hover, no
## focus and no press, because none of those happen to it.
##
## What the owner asked for on 2026-09-17 is a different thing - a *standing*
## animation, which is a property of the surface rather than an answer to being
## touched. So a plate is enrolled into its own group and given the ambient term
## and nothing else.
##
## **Only `Panel` and `PanelContainer`**, never a box container. A skin added to
## an `HBoxContainer` is not an overlay, it is another cell in the row - which
## would silently re-lay every screen in the game.
static func _gather(from: Node) -> void:
	for child: Node in from.get_children():
		var control := child as Control
		if control != null:
			var want: StringName = &""
			if child is BaseButton:
				want = GROUP
			elif child is PanelContainer or (child is Panel and not (child is Container)):
				want = PLATE_GROUP
			elif child is ProgressBar:
				want = BAR_GROUP
			if want != &"" and not control.is_in_group(want):
				control.add_to_group(want)
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


## A plate's standing animation: the same skin, under the contents, with the
## interaction left off.
##
## **Under rather than over, which is the whole difference from a button.** A
## `Button` draws its plate and its caption in one pass and has no child
## controls, so a skin on top of it lights the plate. A `PanelContainer` holds a
## whole screen's worth of labels, and an additive layer over those would lift
## every glyph toward white - so the skin goes in at index 0, after the panel's
## own `StyleBox` and before anything it contains.
static func dress_plate(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	if control.get_node_or_null(NodePath(SKIN)) != null:
		return
	var skin := ColorRect.new()
	skin.name = SKIN
	skin.color = Color.WHITE
	skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin.set_anchors_preset(Control.PRESET_FULL_RECT)
	skin.material = _material()
	control.add_child(skin)
	control.move_child(skin, 0)


## A bar's fill, flowing rather than standing still.
##
## Owner, 2026-09-17: *"give the progressbars on the battlefield UIs an animated
## game juicy procedural vfx shader effect so they're animated and not static"*.
##
## **The skin is told where the fill ends rather than being resized to it.** A
## `ProgressBar` draws its fill by stretching a `StyleBox`, so there is no node
## to attach anything to; a second rect resized every frame would be a layout
## write per bar per frame. One uniform is not.
static func dress_bar(bar: ProgressBar) -> void:
	if bar == null or not is_instance_valid(bar):
		return
	if bar.get_node_or_null(NodePath(BAR_SKIN)) != null:
		return
	var skin := ColorRect.new()
	skin.name = BAR_SKIN
	skin.color = Color.WHITE
	skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _bar_shader == null and ResourceLoader.exists(BAR_SHADER):
		_bar_shader = load(BAR_SHADER) as Shader
	if _bar_shader == null:
		skin.queue_free()
		return
	var material := ShaderMaterial.new()
	material.shader = _bar_shader
	material.set_shader_parameter("ceiling", Balance.UI_BAR_FLOW_CEILING)
	material.set_shader_parameter("phase", _next_phase())
	skin.material = material
	bar.add_child(skin)
	_tell_bar(bar, skin)
	# Reads the bar rather than being told by whoever moves it, so a value set
	# from any of the dozen places that move one still reaches the flow. The
	# signal fires on assignment, so there is no per-frame cost.
	if not bar.value_changed.is_connected(_on_bar_moved.bind(bar)):
		bar.value_changed.connect(_on_bar_moved.bind(bar))


static func _on_bar_moved(_value: float, bar: ProgressBar) -> void:
	if bar == null or not is_instance_valid(bar):
		return
	_tell_bar(bar, bar.get_node_or_null(NodePath(BAR_SKIN)) as ColorRect)


static func _tell_bar(bar: ProgressBar, skin: ColorRect) -> void:
	if skin == null or not is_instance_valid(skin):
		return
	var material := skin.material as ShaderMaterial
	if material == null:
		return
	var span: float = maxf(bar.max_value - bar.min_value, 0.0001)
	material.set_shader_parameter("fill",
		clampf((bar.value - bar.min_value) / span, 0.0, 1.0))
	# The fill's own colour, so a health bar flows red and a mana bar blue
	# without anybody keeping a second table of which bar is which.
	var style: StyleBox = bar.get_theme_stylebox("fill")
	var flat := style as StyleBoxFlat
	if flat != null:
		material.set_shader_parameter("tint", flat.bg_color)


## The next control's clock offset. Walked rather than rolled, because a
## random one can still deal two neighbours the same number and the failure
## this prevents is exactly two plates in step.
static func _next_phase() -> float:
	_phase = fmod(_phase + Balance.UI_HOLO_AMBIENT_SPREAD * 0.379,
		Balance.UI_HOLO_AMBIENT_SPREAD)
	return _phase


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
	# The standing animation, on every control this file dresses. Set rather than
	# left to the shader's default for the same reason `ceiling` is: the gate
	# reads it back off the material, and an unassigned uniform answers null.
	material.set_shader_parameter("idle", 1.0)
	material.set_shader_parameter("idle_ceiling", Balance.UI_HOLO_AMBIENT_CEILING)
	material.set_shader_parameter("phase", _next_phase())
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


## **One button catches the light, unasked** (owner, 2026-09-15: the buttons
## "should have some random holographic vfx randomly procedurally even when not
## hovered").
##
## A single sweep across a single button, chosen at random, every few seconds -
## never the rim, never the tear, and never two at once. That restraint is the
## whole design: a hover is an *answer* and has to stay distinguishable from
## the interface simply being alive, so the idle version borrows only the
## quietest part of it and at a fraction of the strength.
##
## Driven by whoever owns the screen rather than by a timer in here, because a
## static class with a clock is a clock that runs behind every dialog in the
## game.
static func idle_shimmer(tree: SceneTree, dice: RandomNumberGenerator) -> void:
	var lit: Array[Node] = tree.get_nodes_in_group(GROUP)
	if lit.is_empty():
		return
	var control := lit[dice.randi() % lit.size()] as Control
	if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	var material: ShaderMaterial = _material_of(control)
	if material == null:
		return
	# Already answering a player? Leave it alone: the quiet version must never
	# step on the loud one.
	if float(material.get_shader_parameter("strength")) > 0.05:
		return
	material.set_shader_parameter("sweep", -0.4)
	# Only the material, never the control - see `_tween_to`.
	var tween: Tween = control.create_tween()
	tween.tween_method(func(value: float) -> void:
		material.set_shader_parameter("sweep", value),
		-0.4, 1.4, Balance.UI_HOLO_SWEEP * Balance.UI_HOLO_IDLE_SLOW)
	# A whisper of rim under it, and gone. Never the full hover strength.
	_tween_to(control, material, Balance.UI_HOLO_IDLE_STRENGTH, Balance.UI_HOLO_RISE)
	var shimmered: int = control.get_instance_id()
	var fade: Tween = control.create_tween()
	fade.tween_interval(Balance.UI_HOLO_SWEEP * Balance.UI_HOLO_IDLE_SLOW)
	fade.tween_callback(func() -> void:
		var it: Object = instance_from_id(shimmered)
		if it == null or not is_instance_valid(it):
			return
		var again := it as Control
		if not again.has_focus():
			_tween_to(again, material, 0.0, Balance.UI_HOLO_FALL))


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
	# **Only the material is captured.** A lambda holding a freed control errors
	# at the call, before its own guard runs - see the note on `_tween_to`. A
	# `ShaderMaterial` is reference-counted and cannot go out from under it.
	var tween: Tween = control.create_tween()
	tween.tween_method(func(value: float) -> void:
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
		material.set_shader_parameter("flicker", value),
		1.0, 0.0, Balance.UI_HOLO_TEAR)
	_lift(control, -Balance.UI_HOLO_LIFT)
	# This one genuinely needs the control back, so it takes the id: an `int`
	# survives whatever happens to the thing it names.
	var id: int = control.get_instance_id()
	var back: Tween = control.create_tween()
	back.tween_interval(Balance.UI_HOLO_TEAR)
	back.tween_callback(func() -> void:
		var it: Object = instance_from_id(id)
		if it == null or not is_instance_valid(it):
			return
		var again := it as Control
		_lift(again, Balance.UI_HOLO_LIFT if again.has_focus() else 0.0))


## **Only the material is captured, never the control.**
##
## A lambda holding a freed object errors at the *call* - "Lambda capture at
## index 0 was freed" - before its own body runs, so an `is_instance_valid` guard
## inside one does nothing at all. This project has paid for that once already,
## with three scopes following the sun through a lambda.
##
## Nothing noticed here because the screens that enrol build their buttons once.
## Point it at a list that rebuilds itself and every interrupted tween errors on
## every remaining step. A `ShaderMaterial` is reference-counted, so writing to it
## is safe whatever happens to the control it was on.
static func _tween_to(control: Control, material: ShaderMaterial,
		wanted: float, seconds: float) -> void:
	var tween: Tween = control.create_tween()
	tween.tween_method(func(value: float) -> void:
		material.set_shader_parameter("strength", value),
		float(material.get_shader_parameter("strength")), wanted, seconds)


## A control's own vertical nudge.
##
## **Pivoted and offset rather than scaled.** Scaling a `Control` inside a
## container fights the container's own layout every frame, and this project
## has a `layout_check` that would rightly fail a button whose rect moved.
##
## **And home is asked for rather than remembered** (owner, 2026-09-15). This
## used to cache `position` in a meta on the first hover and tween back to that
## forever after. A container re-lays its children out whenever anything inside
## it changes size, and the Preparation card's countdown re-sorts that column
## every second - so the remembered home went stale, and hovering RIDE ON threw
## the button tens of pixels up the card, over the clock it sits under. Worse,
## it then left the cursor, so the button fell back, was entered again, and
## bounced: reported as a button that "moves way too far", is "hard to click"
## and "covers up the ui texts including countdown".
##
## Three things make it safe now. The home is *derived* - wherever the layout
## has put the button, less whatever lift is already on it - so a stale one
## cannot exist. The offset is clamped to the authored lift, so no arithmetic
## slip can move a button further than a nudge. And a container's own re-sort
## clears the applied offset, because after a sort the child is exactly where
## the layout wants it and nothing of ours is on it any more.
static func _lift(control: Control, by: float) -> void:
	if control == null or not is_instance_valid(control):
		return
	var wanted: float = clampf(by, -Balance.UI_HOLO_LIFT, Balance.UI_HOLO_LIFT)
	_follow_the_layout(control)
	var applied: float = float(control.get_meta(APPLIED, 0.0))
	var home: Vector2 = control.position + Vector2(0.0, applied)
	control.set_meta(APPLIED, wanted)
	# One tween per control. Two lifts racing each other on `position` is the
	# other half of a button that will not sit still.
	# `get_meta` with a null default still errors on a missing key, which is a
	# red gate rather than a fallback.
	if control.has_meta(TWEEN):
		var running := control.get_meta(TWEEN) as Tween
		if running != null and running.is_valid():
			running.kill()
	var tween: Tween = control.create_tween()
	control.set_meta(TWEEN, tween)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control, "position", home + Vector2(0.0, -wanted),
		Balance.UI_HOLO_RISE)


## Once per control: when its container re-sorts, whatever we had put on it is
## gone, so the bookkeeping has to agree. Connected lazily because a control can
## be re-parented between the enrol and the first hover.
static func _follow_the_layout(control: Control) -> void:
	var box := control.get_parent() as Container
	if box == null or control.has_meta(WATCHED):
		return
	control.set_meta(WATCHED, true)
	# **The id, not the control.** The container outlives its children, so this
	# connection survives every row a rebuilding list frees - and a lambda
	# holding a freed object errors at the call, before its own guard runs. That
	# is what made the stash print four of these on every refresh.
	var watched: int = control.get_instance_id()
	box.sort_children.connect(func() -> void:
		var it: Object = instance_from_id(watched)
		if it != null and is_instance_valid(it):
			(it as Control).set_meta(APPLIED, 0.0))
