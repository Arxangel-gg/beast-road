class_name MilestoneCinematic
extends CanvasLayer

## A single short, pause-safe milestone card.
##
## The full-screen composition is deliberately separate from HUD layout. It can
## scale to a phone or ultrawide without competing with battlefield controls,
## and Claude's concurrent HUD pass can move those controls independently.

signal finished(skipped: bool)

var _root: Control
var _backdrop: TextureRect
var _portrait: TextureRect
var _eyebrow: Label
var _title: Label
var _body: Label
var _hint: Label
var _hold_bar: ProgressBar
var _running: bool = false
var _advance: bool = false
var _skipped: bool = false
var _held: float = 0.0
var _pointer_held: bool = false
var _tree_was_paused: bool = false


func _ready() -> void:
	layer = 124
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EventBus.coop_cinematic_skipped.connect(skip_from_coop)


func _build() -> void:
	_root = Control.new()
	_root.name = "Frame"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_backdrop = TextureRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_backdrop.add_to_group(Graphics.FILTER_GROUP)
	_root.add_child(_backdrop)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.015, 0.021, 0.032, 0.38)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	_portrait = TextureRect.new()
	_portrait.name = "BossPortrait"
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.anchor_left = 0.43
	_portrait.anchor_top = 0.05
	_portrait.anchor_right = 0.96
	_portrait.anchor_bottom = 0.79
	_portrait.offset_left = 0.0
	_portrait.offset_top = 0.0
	_portrait.offset_right = 0.0
	_portrait.offset_bottom = 0.0
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_portrait.add_to_group(Graphics.FILTER_GROUP)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_portrait)

	var scrim := TextureRect.new()
	scrim.name = "TextScrim"
	scrim.texture = _scrim_texture()
	scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	scrim.offset_top = -470.0
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(scrim)

	var margin := MarginContainer.new()
	margin.name = "CopySafeArea"
	margin.anchor_left = 0.065
	margin.anchor_top = 0.59
	margin.anchor_right = 0.935
	margin.anchor_bottom = 0.91
	margin.offset_left = 0.0
	margin.offset_top = 0.0
	margin.offset_right = 0.0
	margin.offset_bottom = 0.0
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	_root.add_child(margin)

	var copy := VBoxContainer.new()
	copy.name = "Copy"
	copy.add_theme_constant_override("separation", 10)
	copy.size_flags_vertical = Control.SIZE_SHRINK_END
	margin.add_child(copy)

	_eyebrow = Label.new()
	_eyebrow.name = "Eyebrow"
	_eyebrow.add_theme_font_size_override("font_size", 22)
	_eyebrow.add_theme_color_override("font_color", Color("e9ae55"))
	copy.add_child(_eyebrow)

	_title = Label.new()
	_title.name = "Title"
	_title.add_theme_font_size_override("font_size", 56)
	_title.add_theme_color_override("font_color", Color("fff2d1"))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_title)

	_body = Label.new()
	_body.name = "Body"
	_body.custom_minimum_size = Vector2(0.0, 58.0)
	_body.add_theme_font_size_override("font_size", 23)
	_body.add_theme_color_override("font_color", Color("d8cfbd"))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_body)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.text = "TAP / CONFIRM  ·  CONTINUE     HOLD ESC / TOUCH  ·  SKIP"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -560.0
	_hint.offset_top = -58.0
	_hint.offset_right = -38.0
	_hint.offset_bottom = -26.0
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.78, 0.74, 0.67, 0.82))
	_root.add_child(_hint)

	_hold_bar = ProgressBar.new()
	_hold_bar.name = "SkipProgress"
	_hold_bar.show_percentage = false
	_hold_bar.max_value = Balance.MILESTONE_CINEMATIC_SKIP_HOLD_SECONDS
	_hold_bar.value = 0.0
	_hold_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hold_bar.offset_left = -560.0
	_hold_bar.offset_top = -20.0
	_hold_bar.offset_right = -38.0
	_hold_bar.offset_bottom = -14.0
	_hold_bar.modulate = Color(0.91, 0.64, 0.24, 0.0)
	_root.add_child(_hold_bar)


func _scrim_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.015, 0.021, 0.032, 0.0))
	gradient.set_color(1, Color(0.015, 0.021, 0.032, 0.97))
	var fill := GradientTexture2D.new()
	fill.gradient = gradient
	fill.width = 4
	fill.height = 256
	fill.fill_from = Vector2.ZERO
	fill.fill_to = Vector2(0.0, 1.0)
	return fill


func play(data: MilestoneCinematicData) -> void:
	if _running or data == null:
		return
	_running = true
	_advance = false
	_skipped = false
	_held = 0.0
	_pointer_held = false
	_apply(data)

	_tree_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_root.modulate.a = 0.0

	# Headless presentation exists only for the focused release gate. Starting a
	# Vorbis player there leaves an in-flight decoder at process exit, while a
	# server has no audience for the cue in the first place.
	if DisplayServer.get_name() != "headless":
		Sfx.play("sfx_story_open", 0.0)
	var arrival := create_tween()
	arrival.set_parallel(true)
	arrival.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	arrival.tween_property(_root, "modulate:a", 1.0,
		Balance.MILESTONE_CINEMATIC_FADE_IN_SECONDS)
	if _portrait.visible:
		var rest: Vector2 = _portrait.position
		_portrait.position.x += 64.0
		arrival.tween_property(_portrait, "position", rest,
			Balance.MILESTONE_CINEMATIC_FADE_IN_SECONDS)
	await _wait(Balance.MILESTONE_CINEMATIC_FADE_IN_SECONDS)

	if not _skipped:
		await _interruptible(Balance.MILESTONE_CINEMATIC_HOLD_SECONDS)

	if not _skipped:
		var departure := create_tween()
		departure.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		departure.tween_property(_root, "modulate:a", 0.0,
			Balance.MILESTONE_CINEMATIC_FADE_OUT_SECONDS)
		await _wait(Balance.MILESTONE_CINEMATIC_FADE_OUT_SECONDS)

	visible = false
	get_tree().paused = _tree_was_paused
	_running = false
	finished.emit(_skipped)


func _apply(data: MilestoneCinematicData) -> void:
	_backdrop.texture = _load_texture(data.get_backdrop_path())
	_portrait.visible = data.presentation == MilestoneCinematicData.Presentation.BOSS
	_portrait.texture = _load_texture(data.get_sprite_path()) if _portrait.visible else null
	_eyebrow.text = data.eyebrow.to_upper()
	_title.text = data.display_name
	_body.text = data.description


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _interruptible(seconds: float) -> bool:
	var left: float = seconds
	while left > 0.0:
		if _advance or _skipped:
			_advance = false
			return true
		await get_tree().process_frame
		left -= get_process_delta_time()
	return false


func _process(delta: float) -> void:
	if not _running:
		return
	var holding: bool = Input.is_key_pressed(KEY_ESCAPE) or _pointer_held
	if holding:
		_held += delta
		_hold_bar.value = _held
		_hold_bar.modulate.a = clampf(
			_held / Balance.MILESTONE_CINEMATIC_SKIP_HOLD_SECONDS, 0.0, 1.0)
		if _held >= Balance.MILESTONE_CINEMATIC_SKIP_HOLD_SECONDS:
			if not _skipped:
				GameDirector.skip_cinematic()
			_skipped = true
	else:
		_held = 0.0
		_hold_bar.value = 0.0
		_hold_bar.modulate.a = 0.0


func _input(event: InputEvent) -> void:
	if not _running or _skipped:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_pointer_held = touch.pressed
		if not touch.pressed and _held < Balance.MILESTONE_CINEMATIC_SKIP_HOLD_SECONDS:
			_advance = true
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var click := event as InputEventMouseButton
		_pointer_held = click.pressed
		if not click.pressed and _held < Balance.MILESTONE_CINEMATIC_SKIP_HOLD_SECONDS:
			_advance = true
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.is_pressed():
		var key := event as InputEventKey
		if key.keycode != KEY_ESCAPE:
			_advance = true
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.is_pressed():
		_advance = true
		get_viewport().set_input_as_handled()


## Skipped by the other player, so skipped here.
##
## Only the *whole-cinematic* skip crosses. Advancing a single panel does not:
## reading speed is personal, the panels are short, and yanking the page out from
## under someone mid-sentence to keep two machines in lockstep would be a worse
## experience than a few seconds of drift that the next hold resolves anyway.
func skip_from_coop() -> void:
	if not _running:
		return
	_skipped = true
