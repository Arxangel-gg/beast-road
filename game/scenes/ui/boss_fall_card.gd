class_name BossFallCard
extends CanvasLayer

## The moment an act ends: the boss falls, the picture is taken away, and the
## thing that was killed is held up full-screen before the road ahead is
## offered.
##
## Owner brief, 2026-09-13: "Defeating an act boss should have a bunch of game
## juice! And then transition with shaders to a screen showing the fallen act
## boss with a large fullscreen display for story aesthetics and polish,
## before fading to the road ahead choices before the next act."
##
## Three beats, and each is doing a different job:
##
## 1. **The kill.** A flash, a long shake and a slow-down, on the frame it
##    happened. This is the only one that overlaps gameplay.
## 2. **The wipe.** `boss_fall.gdshader` drains the colour, sweeps a band of
##    light across and inks the field out. The field is still underneath; what
##    ends the act is that the player stops being able to see it.
## 3. **The card.** The boss at full height on the ink, its name, the act it
##    held, and the line the act's lore gives it. It waits, and then the
##    whole thing runs backwards onto the road ahead.
##
## It pauses nothing. The battlefield is already between waves when a boss
## dies, and a pause here would freeze the death animation underneath the
## wipe - which is the one thing the player wants to see finish.

signal finished

var _shade: ColorRect = null
var _material: ShaderMaterial = null
var _card: Control = null
var _portrait: TextureRect = null
var _title: Label = null
var _subtitle: Label = null
var _line: Label = null
var _embers: CPUParticles2D = null


func _ready() -> void:
	name = "BossFallCard"
	layer = Balance.BOSS_FALL_LAYER
	_shade = ColorRect.new()
	_shade.name = "Wipe"
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load("res://scripts/shaders/boss_fall.gdshader")
	_material.set_shader_parameter("progress", 0.0)
	_shade.material = _material
	add_child(_shade)

	_card = Control.new()
	_card.name = "Card"
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	add_child(_card)

	_embers = CPUParticles2D.new()
	_embers.name = "Embers"
	_embers.amount = 40
	_embers.lifetime = 5.0
	_embers.preprocess = 2.0
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.direction = Vector2.UP
	_embers.spread = 24.0
	_embers.gravity = Vector2(0.0, -14.0)
	_embers.initial_velocity_min = 10.0
	_embers.initial_velocity_max = 38.0
	_embers.scale_amount_min = 1.0
	_embers.scale_amount_max = 2.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.76, 0.4, 0.0))
	ramp.set_color(1, Color(1.0, 0.5, 0.22, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.84, 0.5, 0.8))
	_embers.color_ramp = ramp
	_card.add_child(_embers)

	_portrait = TextureRect.new()
	_portrait.name = "Fallen"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_portrait)

	_subtitle = _label(20, Color("b8a884"))
	_title = _label(54, Color("f0e2c0"))
	_line = _label(19, Color("9aa8a4"))
	for who: Label in [_subtitle, _title, _line]:
		_card.add_child(who)


func _label(size: int, colour: Color) -> Label:
	var who := Label.new()
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_theme_font_size_override("font_size", size)
	who.add_theme_color_override("font_color", colour)
	return who


## Plays the whole thing and returns when the road may be offered.
##
## Awaited by the run, so nothing else happens over the top of it - a portent
## card opening behind the wipe would be read by nobody and then dismissed by
## a click meant for this.
func play(boss: EnemyData, act: int) -> void:
	if boss == null or DisplayServer.get_name() == "headless":
		finished.emit()
		return
	_dress(boss, act)
	_layout()
	# 1. The kill lands.
	Vfx.flash(Color(1.0, 0.9, 0.62), 0.4, 1.0)
	EventBus.camera_shake_requested.emit(Balance.BOSS_FALL_SHAKE,
		Balance.BOSS_FALL_SHAKE_SECONDS)
	Sfx.play("sfx_boss_fall")
	Engine.time_scale = Balance.BOSS_FALL_SLOW
	await _wait(Balance.BOSS_FALL_SLOW_SECONDS)
	Engine.time_scale = 1.0
	# 2. The wipe takes the field.
	await _sweep(0.0, 1.0, Balance.BOSS_FALL_WIPE_SECONDS)
	# 3. The card is held.
	var rise: Tween = create_tween()
	rise.tween_property(_card, "modulate:a", 1.0, 0.45)
	await _wait(Balance.BOSS_FALL_HOLD_SECONDS)
	var fall: Tween = create_tween()
	fall.tween_property(_card, "modulate:a", 0.0, 0.4)
	await _wait(0.4)
	await _sweep(1.0, 0.0, Balance.BOSS_FALL_WIPE_SECONDS * 0.8)
	finished.emit()


## The boss, its name, the act it held, and what the act's lore calls it.
func _dress(boss: EnemyData, act: int) -> void:
	var art: String = boss.get_sprite_path()
	if ResourceLoader.exists(art):
		_portrait.texture = load(art) as Texture2D
	_subtitle.text = "ACT %s  ·  FALLEN" % _roman(act)
	_title.text = boss.display_name
	_line.text = boss.description


func _sweep(from: float, to: float, seconds: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(func(value: float) -> void:
		_material.set_shader_parameter("progress", value), from, to, seconds)
	await _wait(seconds)


## Waits in real seconds, whatever `Engine.time_scale` is doing. The slow-down
## is part of the beat, so a timer that slowed with it would stretch the whole
## sequence to four times its length.
func _wait(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		left -= get_process_delta_time() / maxf(Engine.time_scale, 0.01)
		await get_tree().process_frame


func _layout() -> void:
	var span: Vector2 = get_viewport().get_visible_rect().size
	var reach: float = minf(span.y * 0.52, span.x * 0.42)
	_portrait.size = Vector2(reach, reach)
	_portrait.position = Vector2((span.x - reach) * 0.5, span.y * 0.16)
	_embers.position = Vector2(span.x * 0.5, span.y * 0.74)
	_embers.emission_rect_extents = Vector2(reach * 0.6, 12.0)
	var text_top: float = span.y * 0.16 + reach + span.y * 0.02
	_subtitle.position = Vector2(span.x * 0.15, text_top)
	_subtitle.size = Vector2(span.x * 0.7, 26.0)
	_title.position = Vector2(span.x * 0.1, text_top + 28.0)
	_title.size = Vector2(span.x * 0.8, 66.0)
	_line.position = Vector2(span.x * 0.22, text_top + 98.0)
	_line.size = Vector2(span.x * 0.56, 60.0)


func _process(_delta: float) -> void:
	if _card != null and _card.modulate.a > 0.0:
		_layout()


## Act numbers read as numerals on a card like this, and there is no helper
## for it anywhere else in the project - a ten-entry table is smaller and
## clearer than the general algorithm for a range that stops at ten.
func _roman(act: int) -> String:
	const NUMERALS: Array[String] = ["I", "II", "III", "IV", "V",
		"VI", "VII", "VIII", "IX", "X"]
	return NUMERALS[clampi(act - 1, 0, NUMERALS.size() - 1)]
