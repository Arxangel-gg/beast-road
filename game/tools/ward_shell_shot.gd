extends Node

## Photographs the ward's shell round the Warden at the amounts it is meant to
## tell apart.
##
##   shot_offscreen.sh <profile> 1440 800 res://tools/ward_shell_shot.tscn
##
## Headless never compiles a shader, so `ward_shell_check` can hold the shell's
## numbers and wiring and nothing about how it looks - this is the half a number
## cannot answer. Six panels of one Warden, left to right and top to bottom:
##
##   1. a sliver of ward       2. half the ceiling       3. the whole ceiling
##   4. a blow landing on 3    5. worn through by blows  6. the moment it breaks
##
## Written to `user://ward_shell_shot.png`. Diagnostic only, never a gate.

const PANEL := Vector2i(480, 400)
const COLUMNS: int = 3
const ROWS: int = 2

var _hero: Hero = null
var _stage: Node2D = null
var _tag: Label = null


func _ready() -> void:
	var size := Vector2i(PANEL.x * COLUMNS, PANEL.y * ROWS)
	get_window().size = PANEL
	get_viewport().set_content_scale_size(PANEL)
	MetaState.hold_saves()
	RunState.reset(false, 20261001)

	var plate := ColorRect.new()
	plate.color = Color(0.16, 0.19, 0.15)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.z_index = -10
	add_child(plate)
	_stage = Node2D.new()
	add_child(_stage)
	var world_before: Node2D = Vfx.world
	Vfx.world = _stage

	_hero = (load("res://scenes/hero/hero.tscn") as PackedScene).instantiate() as Hero
	var stand := Vector2(float(PANEL.x) * 0.5, float(PANEL.y) * 0.78)
	_hero.position = stand
	_stage.add_child(_hero)
	await _settle(2)
	_hero.position.y -= _hero.global_position.y - stand.y
	_tag = Label.new()
	_tag.position = Vector2(14.0, 10.0)
	_tag.add_theme_font_size_override("font_size", 16)
	_stage.add_child(_tag)

	var sheet := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var ceiling: float = _hero.health.max_hp * Balance.HEALTH_SHIELD_CEILING
	var shield: float = 0.0

	shield = await _ward_to(ceiling * 0.06, shield, "1 · a sliver (6%)")
	await _blit(sheet, 0)
	shield = await _ward_to(ceiling * 0.5, shield, "2 · half the ceiling")
	await _blit(sheet, 1)
	shield = await _ward_to(ceiling, shield, "3 · the whole ceiling")
	await _blit(sheet, 2)

	_tag.text = "4 · a blow lands on it"
	_hero.health.take_damage(ceiling * 0.08, _hero.global_position + Vector2(160.0, -60.0))
	await _seconds(0.08)
	await _blit(sheet, 3)

	_tag.text = "5 · worn through by blows"
	for blow: int in 6:
		_hero.health.take_damage(ceiling * 0.11, _hero.global_position + Vector2(-160.0, -40.0))
		await _seconds(0.12)
	await _seconds(0.9)
	await _blit(sheet, 4)

	_tag.text = "6 · the moment it breaks"
	_hero.health.take_damage(_hero.health.shield() + 1.0, _hero.global_position + Vector2(0.0, -200.0))
	await _seconds(0.06)
	await _blit(sheet, 5)

	var path: String = ProjectSettings.globalize_path("user://ward_shell_shot.png")
	sheet.save_png(path)
	print("[ward-shell] -> %s" % path)
	Vfx.world = world_before
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)


## Grants ward until the Warden holds `amount`, through the one door every ward
## comes through, and lets the shell settle on it.
func _ward_to(amount: float, held: float, caption: String) -> float:
	_tag.text = caption
	if amount > held:
		_hero.health.add_shield((amount - _hero.health.shield()) / maxf(_hero.health.shield_scale, 0.01))
	await _seconds(1.2)
	return _hero.health.shield()


func _settle(frames: int) -> void:
	for _frame: int in frames:
		await get_tree().process_frame


func _seconds(span: float) -> void:
	await get_tree().create_timer(span).timeout


func _blit(sheet: Image, index: int) -> void:
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	frame.convert(Image.FORMAT_RGBA8)
	if frame.get_size() != PANEL:
		frame.resize(PANEL.x, PANEL.y, Image.INTERPOLATE_NEAREST)
	var column: int = index % COLUMNS
	var row: int = index / COLUMNS
	sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, PANEL), Vector2i(column * PANEL.x, row * PANEL.y))
