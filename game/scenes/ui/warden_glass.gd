class_name WardenGlass
extends CanvasLayer

## The Warden's Glass: where a Warden is made to look like themselves.
##
## Owner, 2026-09-26: *"make sure players can also properly select their
## skintones also in character customization, the whole character customization
## should be highly polished and aesthetic and juicy"*. Before this a look was
## three dye sliders on the Hold's Warden card, over a portrait of the old
## painted Warden that none of the new choices could reach.
##
## **The screen decides nothing about how a Warden is drawn.** The preview is a
## sprite dressed by the real `HeroAnimator` from `WardenDress.outfit` - the one
## function the hero, the Hold and a partner's copy ask - and worn through
## `WardenLook.dress`, so what the glass shows and what the road draws cannot
## disagree. Every choice goes through `MetaState.set_look`, where the clamps
## live, and the page re-reads the save rather than keeping its own copy.
##
## **It moves no number.** A look is a picture: `warden_glass_check` presses
## every control through its own door and reads the hero's attributes back.
##
## **It writes nothing it was not asked to.** Opened and closed untouched, the
## save is byte for byte what it was - the rule the comfort card was built
## under, and the reason it can be offered to every new Warden.

signal closed

## One cell of a hairstyle or beard picker, and the stretch of art around the
## head it shows, in the art's own pixels: the body's own head wearing the
## style, in the chosen colour and skin.
const THUMB: Vector2 = Vector2(72.0, 84.0)
const THUMB_WINDOW: Vector2 = Vector2(48.0, 56.0)
const THUMB_HEAD_ABOVE: float = 20.0
const SWATCH: float = 34.0
## The preview is the sprite at this many screen pixels to one of art.
const STAGE_SCALE: float = 2.0
## Where the Warden's feet stand, as a share of the preview's height.
const STAGE_FEET: float = 0.86
## The turntable: a facing this often, and this long before it resumes after a
## hand turned it.
const TURN_SECONDS: float = 1.5
const TURN_RESUME_SECONDS: float = 4.0
## The pop a change gives the preview.
const POP_SCALE: float = 1.07
const POP_SECONDS: float = 0.22
## The rig's facing order - east, south-east, south ... - and the south view.
const SOUTH_VIEW: int = 2
const GOLD: Color = Color("e8a33d")
const INK: Color = Color("f2e6d0")
const QUIET: Color = Color("8f9b98")
## The painted skin a body falls back to before its sheets carry a measure.
const PAINTED_SKIN_FALLBACK: Color = Color8(180, 128, 93)
const HAIR_TINT_SHADER: String = "res://scripts/shaders/hair_tint.gdshader"
const POSES: Array[String] = ["idle", "walk", "attack_1a"]
const POSE_NAMES: Array[String] = ["Stand", "Walk", "Strike"]

var _panel: PanelContainer
var _split: BoxContainer
var _preview_holder: SubViewportContainer
var _viewport: SubViewport
var _stage: Node2D
var _sprite: Sprite2D
var _animator: HeroAnimator
var _pedestal: Pedestal
var _sparkles: CPUParticles2D
var _close_button: Button
var _body_buttons: Array[Button] = []
var _choices: Dictionary = {}
var _hair_grid: GridContainer
var _beard_grid: GridContainer
var _beard_section: VBoxContainer
var _style_name: Label
var _beard_name: Label
var _skin_name: Label
var _colour_name: Label
var _dye_sliders: Dictionary = {}
var _hair_materials: Array[ShaderMaterial] = []
var _face_materials: Array[ShaderMaterial] = []
var _pose_buttons: Array[Button] = []
var _gear_toggle: CheckButton

var _facing: int = SOUTH_VIEW
var _turn_left: float = TURN_SECONDS
var _resume_left: float = 0.0
var _pose: String = "idle"
var _show_gear: bool = true
var _touched: bool = false
var _pop: Tween = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Deferred for the reason every screen gives: enrolled now, the hologram
	# would dress a screen whose buttons this function has not built yet.
	UiJuice.enrol.call_deferred(get_tree(), self)
	layer = 93
	visible = false
	_rng.randomize()
	_build()
	get_viewport().size_changed.connect(_refit)


## Whether a Warden who has never taken a road should be asked who they are.
##
## **Derived, never stored** - `ComfortCard`'s reasoning, word for word: a flag
## would be a new save key every existing account gains for a screen its owner
## will never see. A Warden who already chose a look is not asked again, and
## neither is one who closed it untouched earlier in this sitting.
static var _offered_this_sitting: bool = false


static func should_offer() -> bool:
	return MetaState.runs_started <= 0 and WardenLook.is_plain(WardenLook.mine()) \
		and not _offered_this_sitting


static func mark_offered() -> void:
	_offered_this_sitting = true


# --- Building ------------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.03, 0.03, 0.84)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.name = "WardenGlass"
	_panel.set_meta(UiMetrics.SELF_SIZED, true)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	var heading := Label.new()
	heading.text = "THE WARDEN'S GLASS"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", GOLD)
	column.add_child(heading)
	var sub := Label.new()
	sub.text = "Who walks the road? Nothing here changes a number - only who the road sees."
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", QUIET)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(sub)

	_split = BoxContainer.new()
	_split.name = "Split"
	_split.add_theme_constant_override("separation", 14)
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_split)
	_split.add_child(_build_preview())

	var scroll := ScrollContainer.new()
	scroll.name = "Choices"
	UiMetrics.prepare_scroll(scroll, TouchInput.is_showing())
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	_build_choices(body)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	var surprise := Button.new()
	surprise.name = "Surprise"
	surprise.text = "Surprise me"
	surprise.tooltip_text = "A new hairstyle, hair colour, beard, skin and dye - the same body"
	surprise.custom_minimum_size = Vector2(0.0, 44.0)
	surprise.pressed.connect(_surprise)
	actions.add_child(surprise)
	var plain := Button.new()
	plain.name = "Plain"
	plain.text = "As painted"
	plain.tooltip_text = "Bald, clean-shaven, the painted skin and cloth - the same body"
	plain.custom_minimum_size = Vector2(0.0, 44.0)
	plain.pressed.connect(_as_painted)
	actions.add_child(plain)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(gap)
	_close_button = Button.new()
	_close_button.name = "Done"
	_close_button.text = "Done"
	_close_button.custom_minimum_size = Vector2(140.0, 44.0)
	_close_button.pressed.connect(close)
	actions.add_child(_close_button)
	_refit()


func _build_preview() -> Control:
	var frame := PanelContainer.new()
	frame.name = "Preview"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	frame.add_child(column)

	_preview_holder = SubViewportContainer.new()
	_preview_holder.name = "Stage"
	_preview_holder.stretch = true
	_preview_holder.custom_minimum_size = Vector2(300.0, 340.0)
	_preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_preview_holder)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	# Two enums for one idea: the canvas filter is a CanvasItem's, a viewport's
	# default is its own, and their numbers do not line up.
	if Graphics.canvas_filter() == CanvasItem.TEXTURE_FILTER_NEAREST:
		_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	else:
		_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	_preview_holder.add_child(_viewport)

	_stage = Node2D.new()
	_stage.name = "Stage"
	_stage.scale = Vector2(STAGE_SCALE, STAGE_SCALE)
	_viewport.add_child(_stage)
	_pedestal = Pedestal.new()
	_stage.add_child(_pedestal)
	_sprite = Sprite2D.new()
	_sprite.name = "Warden"
	var material := ShaderMaterial.new()
	material.shader = WardenLook.shader()
	_sprite.material = material
	_stage.add_child(_sprite)
	_animator = HeroAnimator.new()
	_animator.name = "Frames"
	_animator.sprite = _sprite
	_stage.add_child(_animator)
	_animator.finished.connect(_on_pose_finished)
	_sparkles = CPUParticles2D.new()
	_sparkles.name = "Sparkles"
	_sparkles.emitting = false
	_sparkles.one_shot = true
	_sparkles.amount = int(roundf(24.0 * Graphics.particle_scale()))
	_sparkles.lifetime = 0.7
	_sparkles.explosiveness = 0.9
	_sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_sparkles.emission_sphere_radius = 26.0
	_sparkles.direction = Vector2(0.0, -1.0)
	_sparkles.spread = 180.0
	_sparkles.initial_velocity_min = 20.0
	_sparkles.initial_velocity_max = 60.0
	_sparkles.gravity = Vector2(0.0, -30.0)
	_sparkles.scale_amount_min = 1.0
	_sparkles.scale_amount_max = 2.5
	_sparkles.position = Vector2(0.0, -40.0)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sparkles.material = additive
	_stage.add_child(_sparkles)

	# Turning and posing, under the stage.
	var turns := HBoxContainer.new()
	turns.name = "Turns"
	turns.alignment = BoxContainer.ALIGNMENT_CENTER
	turns.add_theme_constant_override("separation", 6)
	column.add_child(turns)
	var left := Button.new()
	left.name = "TurnLeft"
	left.text = "‹"
	left.tooltip_text = "Turn the Warden"
	left.custom_minimum_size = Vector2(44.0, 36.0)
	left.pressed.connect(_turn.bind(-1))
	turns.add_child(left)
	for index: int in POSES.size():
		var pose := Button.new()
		pose.name = "Pose%s" % POSE_NAMES[index]
		pose.text = POSE_NAMES[index]
		pose.toggle_mode = index < 2
		pose.custom_minimum_size = Vector2(0.0, 36.0)
		pose.pressed.connect(_set_pose.bind(POSES[index]))
		turns.add_child(pose)
		_pose_buttons.append(pose)
	var right := Button.new()
	right.name = "TurnRight"
	right.text = "›"
	right.tooltip_text = "Turn the Warden"
	right.custom_minimum_size = Vector2(44.0, 36.0)
	right.pressed.connect(_turn.bind(1))
	turns.add_child(right)
	_gear_toggle = CheckButton.new()
	_gear_toggle.name = "ShowGear"
	_gear_toggle.text = "Wearing my gear"
	_gear_toggle.button_pressed = true
	_gear_toggle.toggled.connect(func(on: bool) -> void:
		_show_gear = on
		_refresh_preview())
	column.add_child(_gear_toggle)
	return frame


func _build_choices(body: VBoxContainer) -> void:
	# The body.
	var bodies := _section(body, "BODY")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bodies.add_child(row)
	var group := ButtonGroup.new()
	for index: int in WardenDress.BODIES.size():
		var button := Button.new()
		button.name = "Body%d" % index
		button.text = WardenDress.BODIES[index].capitalize()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(120.0, 40.0)
		button.pressed.connect(_choose.bind(WardenLook.KEY_BODY, index))
		row.add_child(button)
		_body_buttons.append(button)

	# The skin.
	var skins := _section(body, "SKIN")
	_skin_name = _caption(skins)
	skins.add_child(_swatch_row(WardenLook.KEY_SKIN, WardenLook.SKIN_TONES.size(), _skin_swatch_colour,
		func(index: int) -> String: return WardenLook.SKIN_NAMES[index]))

	# The hair.
	var hair := _section(body, "HAIR")
	_style_name = _caption(hair)
	_hair_grid = GridContainer.new()
	_hair_grid.name = "HairGrid"
	_hair_grid.columns = 6
	_hair_grid.add_theme_constant_override("h_separation", 6)
	_hair_grid.add_theme_constant_override("v_separation", 6)
	hair.add_child(_hair_grid)

	var colours := _section(body, "HAIR COLOUR")
	_colour_name = _caption(colours)
	colours.add_child(_swatch_row(WardenLook.KEY_HAIR_COLOUR, WardenLook.HAIR_COLOURS.size(),
		func(index: int) -> Color: return WardenLook.HAIR_COLOURS[index],
		func(index: int) -> String: return WardenLook.HAIR_COLOUR_NAMES[index]))

	_beard_section = _section(body, "BEARD")
	_beard_name = _caption(_beard_section)
	_beard_grid = GridContainer.new()
	_beard_grid.name = "BeardGrid"
	_beard_grid.columns = 7
	_beard_grid.add_theme_constant_override("h_separation", 6)
	_beard_grid.add_theme_constant_override("v_separation", 6)
	_beard_section.add_child(_beard_grid)

	# The cloth: the three dyes and their presets, as the Hold's card had them.
	var cloth := _section(body, "CLOTH")
	for pair: Array in [["Cloak", WardenLook.KEY_CLOAK], ["Sash", WardenLook.KEY_SASH],
			["Leather", WardenLook.KEY_LEATHER]]:
		cloth.add_child(_dye_row(String(pair[0]), String(pair[1])))
	var presets := HFlowContainer.new()
	presets.name = "Presets"
	presets.add_theme_constant_override("h_separation", 6)
	presets.add_theme_constant_override("v_separation", 6)
	for index: int in WardenLook.PRESETS.size():
		var preset := Button.new()
		preset.name = "Preset%d" % index
		preset.text = String(WardenLook.PRESETS[index]["label"])
		preset.custom_minimum_size = Vector2(0.0, 32.0)
		preset.pressed.connect(func() -> void:
			MetaState.dye_as_preset(index)
			_changed(Color.from_hsv(float(index) / float(WardenLook.PRESETS.size()), 0.5, 1.0)))
		presets.add_child(preset)
	cloth.add_child(presets)


func _section(parent: VBoxContainer, title: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = title.capitalize().replace(" ", "")
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", GOLD)
	section.add_child(label)
	return section


func _caption(parent: VBoxContainer) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", INK)
	parent.add_child(label)
	return label


func _swatch_row(key: String, count: int, colour_of: Callable, name_of: Callable) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.name = "%sSwatches" % key.capitalize().replace(" ", "")
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	var group := ButtonGroup.new()
	var buttons: Array[Button] = []
	for index: int in count:
		var button := Button.new()
		button.name = "%s%d" % [key.capitalize().replace(" ", ""), index]
		button.toggle_mode = true
		button.button_group = group
		button.tooltip_text = String(name_of.call(index))
		button.custom_minimum_size = Vector2(SWATCH, SWATCH)
		_paint_swatch(button, colour_of.call(index) as Color)
		button.pressed.connect(_choose.bind(key, index))
		row.add_child(button)
		buttons.append(button)
	_choices[key] = buttons
	return row


## A round swatch: the colour, a thin rim, and a gold ring when chosen.
func _paint_swatch(button: Button, colour: Color) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = colour if state != "focus" else Color(0, 0, 0, 0)
		box.set_corner_radius_all(int(SWATCH * 0.5))
		var chosen: bool = state == "pressed" or state == "hover_pressed"
		var ring: Color = GOLD if chosen else (INK if state == "hover" or state == "focus" else Color(0, 0, 0, 0.55))
		box.border_color = ring
		box.set_border_width_all(3 if chosen or state == "focus" else 1)
		if chosen:
			box.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
			box.shadow_size = 6
		button.add_theme_stylebox_override(state, box)


func _skin_swatch_colour(index: int) -> Color:
	if index > 0:
		return WardenLook.SKIN_TONES[index]
	var painted: Color = WardenDress.skin_painted(WardenDress.body_name(WardenLook.mine()))
	return painted if painted.a > 0.0 else PAINTED_SKIN_FALLBACK


func _dye_row(text: String, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(64.0, 0.0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", QUIET)
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = "Dye%s" % key.capitalize()
	slider.min_value = -WardenLook.RANGE
	slider.max_value = WardenLook.RANGE
	slider.step = 0.02
	slider.custom_minimum_size = Vector2(180.0, 24.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void:
		MetaState.set_look(key, v)
		_touched = true
		_refresh_preview())
	_dye_sliders[key] = slider
	row.add_child(slider)
	return row


## One picker cell: the body's own head, wearing the style, in the chosen hair
## colour and skin. Nought is the head alone - bald, or clean-shaven.
func _head_thumb(kind: String, index: int) -> Control:
	var box := Control.new()
	box.custom_minimum_size = THUMB
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look: Dictionary = WardenLook.mine()
	var body: String = WardenDress.body_name(look)
	var layer: String = WardenDress.body_layer(body, null)
	var meta: Dictionary = WardenDress.meta(body, "idle")
	var sheet_path: String = WardenDress.art_root + layer + "/idle.png"
	var sockets: Dictionary = meta.get("sockets", {})
	var rows: Array = sockets.get(HeroAnimator.FACING_NAMES[SOUTH_VIEW], [])
	var view: int = SOUTH_VIEW
	if not rows.is_empty() and WardenDress.exists(sheet_path) and (rows[0] as Array).size() >= 13:
		var cell: Array = meta.get("cell", [0, 0])
		var socket: Array = rows[0]
		view = int(socket[12])
		var face := TextureRect.new()
		face.name = "Face"
		var atlas := AtlasTexture.new()
		atlas.atlas = WardenDress.texture(sheet_path)
		atlas.region = Rect2(float(socket[10]) - THUMB_WINDOW.x * 0.5,
			float(SOUTH_VIEW * int(cell[1])) + float(socket[11]) - THUMB_HEAD_ABOVE,
			THUMB_WINDOW.x, THUMB_WINDOW.y)
		face.texture = atlas
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_SCALE
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = WardenLook.shader()
		var mask_path: String = WardenDress.skin_mask_path(layer, "idle")
		material.set_shader_parameter("skin_mask", WardenDress.texture(mask_path) if WardenDress.exists(mask_path) else null)
		face.material = material
		_face_materials.append(material)
		box.add_child(face)
	if index > 0:
		var option: Dictionary = WardenDress.head_option(body, kind, index)
		if not option.is_empty():
			var table: Dictionary = WardenDress.heads()
			var cell: Array = table.get("cell", [80, 128])
			var anchor: Array = table.get("anchor", [40, 30])
			var hair := TextureRect.new()
			hair.name = "Dressing"
			var atlas := AtlasTexture.new()
			atlas.atlas = WardenDress.texture(String(option.get("path", "")))
			atlas.region = Rect2(float(view * int(cell[0])) + float(anchor[0]) - THUMB_WINDOW.x * 0.5,
				float(anchor[1]) - THUMB_HEAD_ABOVE, THUMB_WINDOW.x, THUMB_WINDOW.y)
			hair.texture = atlas
			hair.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			hair.stretch_mode = TextureRect.STRETCH_SCALE
			hair.set_anchors_preset(Control.PRESET_FULL_RECT)
			hair.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if ResourceLoader.exists(HAIR_TINT_SHADER):
				var tint := ShaderMaterial.new()
				tint.shader = load(HAIR_TINT_SHADER) as Shader
				hair.material = tint
				_hair_materials.append(tint)
			box.add_child(hair)
	return box


## The hairstyle and beard pickers, rebuilt for whichever body is chosen: the
## two bodies wear the same styles in the same places, drawn for each.
func _rebuild_heads() -> void:
	_hair_materials.clear()
	_face_materials.clear()
	for grid: GridContainer in [_hair_grid, _beard_grid]:
		for child: Node in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	_choices[WardenLook.KEY_HAIR] = _fill_grid(_hair_grid, "hair", WardenLook.KEY_HAIR)
	_choices[WardenLook.KEY_BEARD] = _fill_grid(_beard_grid, "beard", WardenLook.KEY_BEARD)
	UiJuice.enrol.call_deferred(get_tree(), self)


func _fill_grid(grid: GridContainer, kind: String, key: String) -> Array[Button]:
	var group := ButtonGroup.new()
	var buttons: Array[Button] = []
	for index: int in int(WardenLook.CHOICES[key]):
		var button := Button.new()
		button.name = "%s%d" % [key.capitalize(), index]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = THUMB + Vector2(8.0, 8.0)
		button.tooltip_text = _head_name(kind, index)
		var thumb := _head_thumb(kind, index)
		thumb.position = Vector2(4.0, 4.0)
		button.add_child(thumb)
		button.pressed.connect(_choose.bind(key, index))
		grid.add_child(button)
		buttons.append(button)
	return buttons


func _head_name(kind: String, index: int) -> String:
	if index <= 0:
		return "Bald" if kind == "hair" else "Clean-shaven"
	var body: String = WardenDress.body_name(WardenLook.mine())
	var option: Dictionary = WardenDress.head_option(body, kind, index)
	var id: String = String(option.get("id", ""))
	var entry: Dictionary = (WardenDress.heads().get("options", {}) as Dictionary).get(id, {})
	return String(entry.get("name", "Style %d" % index))


# --- Opening, closing, sizing --------------------------------------------------

func open() -> void:
	_touched = false
	visible = true
	_facing = SOUTH_VIEW
	_turn_left = TURN_SECONDS
	_resume_left = 0.0
	_set_pose("idle")
	_refresh()
	_close_button.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


## Whether anything was changed while the glass was open.
func touched() -> bool:
	return _touched


func _refit() -> void:
	if _panel == null:
		return
	var screen: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	var wide: float = minf(screen.x * 0.94, 1100.0)
	var tall: float = minf(screen.y * 0.92, 720.0)
	_panel.custom_minimum_size = Vector2(wide, tall)
	# Side by side where there is width for both; stacked on an upright screen,
	# where a preview beside the pickers leaves neither room to be read.
	_split.vertical = screen.x < screen.y * 1.1
	_preview_holder.custom_minimum_size = Vector2(minf(320.0, wide * 0.42), minf(360.0, tall * 0.5)) \
		if not _split.vertical else Vector2(0.0, minf(300.0, tall * 0.38))


func _process(delta: float) -> void:
	if not visible or _stage == null:
		return
	var room: Vector2 = Vector2(_viewport.size)
	_stage.position = Vector2(room.x * 0.5,
		room.y * STAGE_FEET - HeroAnimator.PAINTED_FEET_BELOW_CENTRE * _stage.scale.y)
	if _resume_left > 0.0:
		_resume_left -= delta
		return
	_turn_left -= delta
	if _turn_left <= 0.0:
		_turn_left = TURN_SECONDS
		_face((_facing + 1) % HeroAnimator.DIRECTION_COUNT)


# --- What a press does ---------------------------------------------------------

func _choose(key: String, index: int) -> void:
	var before: int = int(WardenLook.mine().get(key, 0))
	MetaState.set_look(key, float(index))
	var now: Dictionary = WardenLook.mine()
	if key == WardenLook.KEY_BODY and before != int(now[key]):
		_rebuild_heads()
	var colour: Color = GOLD
	match key:
		WardenLook.KEY_SKIN:
			colour = _skin_swatch_colour(index)
		WardenLook.KEY_HAIR_COLOUR, WardenLook.KEY_HAIR, WardenLook.KEY_BEARD:
			colour = WardenLook.hair_colour(now)
	_changed(colour)


## Everything a change has to reach, and the flourish that says it landed.
func _changed(colour: Color) -> void:
	_touched = true
	_refresh()
	_flourish(colour)


func _surprise() -> void:
	var look: Dictionary = WardenLook.mine()
	for key: String in [WardenLook.KEY_HAIR, WardenLook.KEY_HAIR_COLOUR, WardenLook.KEY_BEARD,
			WardenLook.KEY_SKIN]:
		look[key] = _rng.randi_range(0, int(WardenLook.CHOICES[key]) - 1)
	MetaState.set_whole_look(WardenLook.dyed_as(look, _rng.randi_range(0, WardenLook.PRESETS.size() - 1)))
	_changed(WardenLook.hair_colour(WardenLook.mine()))


## The painted Warden on the body already chosen: a reset is never a new body.
func _as_painted() -> void:
	var plain: Dictionary = WardenLook.plain()
	plain[WardenLook.KEY_BODY] = int(WardenLook.mine().get(WardenLook.KEY_BODY, 0))
	MetaState.set_whole_look(plain)
	_changed(INK)


func _turn(step: int) -> void:
	_face(posmod(_facing + step, HeroAnimator.DIRECTION_COUNT))
	_resume_left = TURN_RESUME_SECONDS


func _face(facing: int) -> void:
	_facing = facing
	_animator.set_facing(Vector2.from_angle(float(_facing) * TAU / float(HeroAnimator.DIRECTION_COUNT)))


func _set_pose(pose: String) -> void:
	if pose == "attack_1a":
		_animator.play(pose, true)
		return
	_pose = pose
	for index: int in _pose_buttons.size():
		if _pose_buttons[index].toggle_mode:
			_pose_buttons[index].set_pressed_no_signal(POSES[index] == pose)
	_animator.play(pose)


func _on_pose_finished(state: String) -> void:
	if state == "attack_1a":
		_animator.play(_pose, true)


## The page re-read from the save: which choice is chosen, what it is called,
## and the Warden wearing it.
func _refresh() -> void:
	var look: Dictionary = WardenLook.mine()
	if _hair_grid.get_child_count() == 0 or _choices.get(WardenLook.KEY_HAIR, []).is_empty():
		_rebuild_heads()
	var body: int = int(look.get(WardenLook.KEY_BODY, 0))
	for index: int in _body_buttons.size():
		_body_buttons[index].set_pressed_no_signal(index == body)
	for key: String in [WardenLook.KEY_SKIN, WardenLook.KEY_HAIR, WardenLook.KEY_HAIR_COLOUR,
			WardenLook.KEY_BEARD]:
		var buttons: Array = _choices.get(key, [])
		var chosen: int = int(look.get(key, 0))
		for index: int in buttons.size():
			(buttons[index] as Button).set_pressed_no_signal(index == chosen)
	for key: Variant in _dye_sliders:
		(_dye_sliders[key] as HSlider).set_value_no_signal(float(look.get(key, 0.0)))
	# The skin swatch for "as painted" is the body's own painted skin.
	var skins: Array = _choices.get(WardenLook.KEY_SKIN, [])
	if not skins.is_empty():
		_paint_swatch(skins[0] as Button, _skin_swatch_colour(0))
	# A body that grows no beard is not offered one.
	var beards: bool = not WardenDress.head_option(WardenDress.body_name(look), "beard", 1).is_empty() \
		or WardenDress.body_name(look) == WardenDress.BODIES[0]
	_beard_section.visible = beards
	_skin_name.text = WardenLook.SKIN_NAMES[int(look[WardenLook.KEY_SKIN])]
	_colour_name.text = WardenLook.HAIR_COLOUR_NAMES[int(look[WardenLook.KEY_HAIR_COLOUR])]
	_style_name.text = _head_name("hair", int(look[WardenLook.KEY_HAIR]))
	_beard_name.text = _head_name("beard", int(look[WardenLook.KEY_BEARD]))
	var hair: Color = WardenLook.hair_colour(look)
	for material: ShaderMaterial in _hair_materials:
		material.set_shader_parameter("hair_colour", hair)
	var painted: Color = WardenDress.skin_painted(WardenDress.body_name(look))
	var tone: Color = WardenLook.skin_tone(look, painted)
	for material: ShaderMaterial in _face_materials:
		material.set_shader_parameter("skin_from", Vector3(painted.r, painted.g, painted.b))
		material.set_shader_parameter("skin_to", Vector3(tone.r, tone.g, tone.b))
	_refresh_preview()


func _refresh_preview() -> void:
	var look: Dictionary = WardenLook.worn()
	var outfit: Dictionary = WardenDress.outfit(look, _worn(GearData.Slot.WEAPON), _worn(GearData.Slot.ARMOUR),
		_worn(GearData.Slot.CAPE), _worn(GearData.Slot.HELMET)) if _show_gear \
		else WardenDress.outfit(look, null, null, null, null)
	_animator.dress(outfit)
	WardenLook.dress(_sprite, look)
	_face(_facing)
	_animator.play(_pose)


func _worn(slot: int) -> GearData:
	var piece: Dictionary = MetaState.equipped_piece(slot)
	return ContentDB.gear(String(piece.get("kind", ""))) if not piece.is_empty() else null


## The preview answers a change: it swells and settles, sparks in the colour
## chosen, and the ring under the Warden takes that colour.
func _flourish(colour: Color) -> void:
	if _pop != null and _pop.is_valid():
		_pop.kill()
	_stage.scale = Vector2(STAGE_SCALE, STAGE_SCALE) * POP_SCALE
	_pop = create_tween()
	_pop.tween_property(_stage, "scale", Vector2(STAGE_SCALE, STAGE_SCALE), POP_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pedestal.flare(colour)
	if _sparkles.amount > 0:
		_sparkles.color = Color(colour.r, colour.g, colour.b, 0.9).lightened(0.25)
		_sparkles.restart()
		_sparkles.emitting = true


## The ground the Warden stands on in the glass: a soft shadow and a ring of
## light that breathes, and flares in the colour of whatever was just chosen.
class Pedestal extends Node2D:
	const RESTING: Color = Color(0.91, 0.64, 0.24)
	var _colour: Color = RESTING
	var _flare: float = 0.0
	var _clock: float = 0.0

	func flare(colour: Color) -> void:
		_colour = colour
		_flare = 1.0

	func _process(delta: float) -> void:
		_clock += delta
		_flare = maxf(_flare - delta * 1.6, 0.0)
		queue_redraw()

	func _draw() -> void:
		var feet := Vector2(0.0, HeroAnimator.PAINTED_FEET_BELOW_CENTRE)
		draw_set_transform(feet, 0.0, Vector2(1.0, 0.3))
		for step: int in 5:
			var t: float = float(step) / 4.0
			draw_circle(Vector2.ZERO, lerpf(44.0, 20.0, t), Color(0.0, 0.0, 0.0, 0.10 + 0.06 * t))
		var breath: float = 0.5 + 0.5 * sin(_clock * 2.2)
		var ring: Color = _colour.lerp(RESTING, 1.0 - _flare)
		ring.a = 0.25 + 0.2 * breath + 0.45 * _flare
		draw_arc(Vector2.ZERO, 40.0 + 6.0 * _flare, 0.0, TAU, 48, ring, 2.0 + 2.0 * _flare, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
