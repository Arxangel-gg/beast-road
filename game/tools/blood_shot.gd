extends Node

## Photographs blood, which nothing did before.
##
##   godot --path game res://tools/blood_shot.tscn
##
## Diagnostic only, never a gate. `blood_vfx_check` holds the rules and the
## shape of a blob; this is the half a number cannot answer - whether a pool
## reads as something wet that landed, or as a red circle.
##
## Three plates, each written to `user://blood_shot_<what>.png`:
##
##  - `marks` - fresh spatter thrown in several directions, at the size a hit
##    and a death each lay down;
##  - `drying` - the same field driven forward most of its life, which is where
##    the tone ramp and the hold do their work;
##  - `burst` - motes still in the air, caught mid-arc, which is the one state
##    that lasts half a second in play and is therefore never looked at.
##
## Driven rather than awaited where the clock matters: `BloodField._process`
## ages marks by `delta`, and ten real minutes is not a thing to wait for.

const SIZE := Vector2i(900, 520)

var _field: BloodField = null
var _stage: Node2D = null
var _rng := RandomNumberGenerator.new()
var _across := Vector2(900.0, 520.0)


func _ready() -> void:
	_rng.seed = 20260916
	get_window().size = SIZE
	# **One content unit to one pixel.** The project's content scale size is far
	# larger than this window, so without pinning it the marks are laid across
	# the content rectangle and photographed into a window about half as wide -
	# every mark comes out at half the size it is in play, and the first cut of
	# this tool was read as blood being too small when it was the picture that
	# was shrunk. A photograph at half scale is a model of the thing.
	get_viewport().set_content_scale_size(SIZE)
	RunState.reset(false, 20260916)
	_stage = Node2D.new()
	add_child(_stage)
	# A plain mid-dark plate to read the marks against. The battlefield's own
	# ground would be a photograph of the ground.
	var plate := ColorRect.new()
	plate.color = Color(0.18, 0.17, 0.15)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(plate)
	move_child(plate, 0)
	_field = BloodField.new()
	_stage.add_child(_field)
	await get_tree().process_frame
	# **Above the plate, which the field is not by default.** `BLOOD_GROUND_Z` is
	# -3 so that blood lies under everything that walks on it; on a bare plate
	# that puts it behind the plate, and the first cut of this tool photographed
	# an empty rectangle. A diagnostic that draws nothing looks exactly like a
	# feature that draws nothing.
	_field.z_index = 10
	# The window is sized in pixels and the marks are laid in *content* units,
	# which differ by the project's content scale - so the spread is taken off
	# the viewport rather than off `SIZE`.
	_across = get_viewport().get_visible_rect().size

	_lay_the_marks()
	await _shot("marks")

	# Most of the way through the hold, where the tone has begun to dry but the
	# alpha has not yet taken the mark away.
	for _step: int in 60:
		_field._process(Balance.BLOOD_GROUND_LIFE * Balance.BLOOD_HOLD / 60.0)
	_field.queue_redraw()
	await _shot("drying")

	_field.wipe()
	Vfx.bind_world(_stage)
	for index: int in 4:
		Vfx.blood(Vector2(_across.x * (0.16 + float(index) * 0.23), _across.y * 0.56),
			Vector2.from_angle(-0.9 + float(index) * 0.5),
			Balance.VFX_BLOOD_DEATH_SIZE, Vector2(0.0, 40.0))
	# Part-way through a mote's life: the motes are in the air and stretched,
	# which is the whole subject and is gone in half a second in play.
	for _f: int in 8:
		await get_tree().process_frame
	await _shot("burst")

	Vfx.clear()
	Vfx.bind_world(null)
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	get_tree().quit(0)


func _lay_the_marks() -> void:
	# A row of hits and a row of deaths, thrown every which way, so the
	# directional bias is visible as a difference between marks rather than
	# having to be taken on trust from one.
	for index: int in 5:
		_field.splat(Vector2(_across.x * (0.12 + float(index) * 0.19),
			_across.y * 0.28),
			Vector2.from_angle(float(index) * 1.3), Balance.VFX_BLOOD_HIT_SIZE, _rng)
	for index: int in 4:
		_field.splat(Vector2(_across.x * (0.16 + float(index) * 0.23),
			_across.y * 0.70),
			Vector2.from_angle(0.6 + float(index) * 1.1),
			Balance.VFX_BLOOD_DEATH_SIZE, _rng)


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	var path: String = "user://blood_shot_%s.png" % what
	frame.save_png(ProjectSettings.globalize_path(path))
	print("%s -> %s" % [what, ProjectSettings.globalize_path(path)])
