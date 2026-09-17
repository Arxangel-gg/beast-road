extends Node

## The Hold, photographed - which nothing has ever done.
##
##   godot --path game res://tools/hold_shot.tscn
##   godot --path game res://tools/hold_shot.tscn -- night
##
## **Thirty-eight shot tools and none of them is this one.** The beast, the
## blood, a dungeon, the menu, a mount, a raid, a tower, the weather and the
## wildlife families all have a way to be looked at; the Hold, which is the place
## a player stands between every run, has never been photographed. That is why
## the owner's reports about it - *"some of the characters are static and have
## ground included in their images"*, *"shadows need to be improved"*,
## *"everything in the Hold needs to be way more aesthetically appealing"* - have
## had to be answered by reading source art, which is exactly the mistake this
## project keeps paying for.
##
## **The tail is the precedent.** Yuri's was reported as ungraded seven times and
## six passes were spent measuring the two paintings; the seventh photographed
## the render and found the limb being multiplied by flat grey. *A model of a
## thing is not the thing.* Every claim below is about pixels, so this takes
## pixels.
##
## Four plates, each answering a question that a number cannot:
##
## - **day** - the whole yard at noon: what is where, and whether the place reads
##   as a camp or as a diagram.
## - **night** - the same yard with the sun down, which is the only way to see
##   whether the fire and the torches are doing anything and whether the floor
##   under `HOLD_NIGHT_FLOOR` left it readable.
## - **pens** - the fences and the animals in them, close enough to see whether a
##   post is a post or a line.
## - **figures** - the residents and the seated Wardens at their own scale, which
##   is where "the ground is included in their image" would show: a figure drawn
##   on a patch of earth has a hard edge under its feet that the yard's own
##   ground does not continue.
##
## **Never headless.** There is no frame to read, and a shot tool that runs there
## writes a black rectangle and reports success.

const SIZE := Vector2i(1600, 900)

var _yard: HoldYard = null
var _night: bool = false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[hold-shot] skipped: a headless display has no pixels to read")
		get_tree().quit(0)
		return
	_night = OS.get_cmdline_user_args().has("night")
	get_window().size = SIZE
	# One content unit to one pixel, so the yard is photographed at the size it
	# is drawn rather than through the project's own content scale - the lesson
	# `blood_shot` records, where every mark came out half size and was read as
	# the blood being too small.
	get_viewport().set_content_scale_size(SIZE)
	RunState.reset(false, 20260917)

	var plate := ColorRect.new()
	plate.color = Color(0.05, 0.06, 0.05)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(plate)

	_yard = HoldYard.new()
	add_child(_yard)
	# **Driven rather than waited on.** The yard's people walk on their own
	# clocks, so a photograph taken on the first frame catches every one of them
	# in its starting pose - which is the one arrangement that never happens in
	# play and reads as a place where nobody has moved yet.
	# **The pens are filled here, because the session is what fills them in
	# play and there is no session in a photograph.** Without this the plates
	# show four empty paddocks and would have been read as the pens being
	# broken - a tool that photographs less than the game is worse than one that
	# photographs nothing, because it is believed.
	for index: int in _yard.pens():
		_yard.set_pen(index, HoldSession._simulated_pen("shot%d" % index))
	_yard.advance(6.0)

	_set_the_hour()
	await _frame("yard", 0.34, Vector2.ZERO)
	await _frame("pens", 0.95, Vector2(420.0, 300.0))
	await _frame("figures", 1.20, Vector2(-300.0, 0.0))
	await _frame("square", 0.70, Vector2(0.0, 40.0))
	get_tree().quit(0)


## Noon, or the middle of the night.
##
## Set through `DayNight` rather than by writing the yard's own modulate,
## because the thing being photographed is *the yard following the sun* - a
## picture taken by forcing the colour would be a picture of this tool.
func _set_the_hour() -> void:
	# **`_apply`, not `phase`.** Writing the phase alone leaves `_sun_tint`
	# exactly where it was - the colour is interpolated from the day table
	# inside `_apply`, and `_publish` only copies whatever that last computed.
	# The first night plates came out identical to the day ones and were very
	# nearly read as the fires not working.
	DayNight._apply(0.92 if _night else 0.30)
	_yard.advance(0.5, 4)


func _frame(what: String, zoom: float, at: Vector2) -> void:
	_yard.scale = Vector2(zoom, zoom)
	_yard.position = Vector2(SIZE) * 0.5 - at * zoom
	for _settle: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	var tag: String = "night" if _night else "day"
	var path: String = "user://hold_shot_%s_%s.png" % [tag, what]
	frame.save_png(ProjectSettings.globalize_path(path))
	print("[hold-shot] %s (%s) -> %s" % [what, tag,
		ProjectSettings.globalize_path(path)])
