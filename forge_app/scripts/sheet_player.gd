class_name SheetPlayer
extends Control

## Plays a forged sheet back the way the game will play it.
##
## **This is the whole reason the app exists.** A sheet is sixteen cells in a
## row and a lit-pixel count says nothing about what it looks like moving; the
## catalogue was authored against that number and two effects passed every
## rule while rendering as a cog and a sunburst. A tool that renders a sheet
## and cannot show it playing is a slower command line.
##
## It draws the sheet the way `Vfx.forge_burst` draws it and under the same
## rules, so what is seen here is what the game gets:
##
## - **tinted**, because every sheet is white on transparent and the game
##   tints it once per use;
## - **additive**, because that is the blend the game uses, and an effect
##   judged on a normal blend is judged on a picture nobody will see;
## - **at the game's own frame rate**, `Balance.VFX_FORGE_FRAME_RATE`, which
##   is 30 - a sheet played at sixty is half as long as it will be;
## - and over a **plate the colour of the road**, because a bright effect on
##   a black rectangle always looks good.
##
## **The additive half is a child node rather than a draw call.** Godot 4 has
## no `draw_set_blend_mode`: a blend is a property of a `CanvasItemMaterial`,
## which belongs to a node. So the plate and the cell grid are drawn here and
## the effect is drawn by `Glass`, a child wearing the additive material -
## which is also the arrangement the game uses everywhere it adds light.

## The game's own playback rate. Mirrored rather than imported: this app is
## its own Godot project and cannot reach into `res://` of the other one.
## Kept here in one place with the reason, so the day it moves there is one
## line to change and a comment saying where the other copy lives
## (`Balance.VFX_FORGE_FRAME_RATE`).
const GAME_FRAME_RATE: float = 30.0

## What the plate behind the effect may be: the road at night, the road by
## day, a near-black, and a pale ground for reading a dark fringe.
const GROUNDS: Array[Color] = [
	Color("1b2118"), Color("3f4a33"), Color("101215"), Color("8d8579"),
]


## The additive layer. It reads the player rather than holding state of its
## own, so there is exactly one answer to "which cell is showing".
class Glass extends Control:
	var player: SheetPlayer = null

	func _draw() -> void:
		if player == null or player.sheet == null:
			return
		var sheet: Texture2D = player.sheet
		var cell: float = float(sheet.get_width()) / float(player.cells)
		var tall: float = float(sheet.get_height())
		var drawn := Vector2(cell, tall) * player.zoom
		var at: Vector2 = (size - drawn) * 0.5
		draw_texture_rect_region(sheet, Rect2(at, drawn),
			Rect2(float(player.current_frame()) * cell, 0.0, cell, tall),
			player.tint)


var sheet: Texture2D = null:
	set(value):
		sheet = value
		_frame = 0.0
		_redraw()

var cells: int = 16:
	set(value):
		cells = maxi(value, 1)
		_redraw()

var tint: Color = Color("ffb36a"):
	set(value):
		tint = value
		_redraw()

var ground: int = 0:
	set(value):
		ground = wrapi(value, 0, GROUNDS.size())
		_redraw()

var zoom: float = 3.0:
	set(value):
		zoom = clampf(value, 1.0, 10.0)
		_redraw()

var playing: bool = true
var looping: bool = true
## Drawn over the play, so the shape of one cell can be read while it moves.
var show_grid: bool = false:
	set(value):
		show_grid = value
		_redraw()

var _frame: float = 0.0
var _glass: Glass = null

signal frame_changed(frame: int, of: int)


func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glass = Glass.new()
	_glass.player = self
	_glass.material = additive
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_glass)


func _process(delta: float) -> void:
	if sheet == null or not playing:
		return
	_frame += delta * GAME_FRAME_RATE
	if _frame >= float(cells):
		if looping:
			_frame = fmod(_frame, float(cells))
		else:
			_frame = float(cells) - 0.001
			playing = false
	_redraw()
	frame_changed.emit(int(_frame), cells)


func scrub_to(frame: int) -> void:
	_frame = clampf(float(frame), 0.0, float(cells) - 0.001)
	playing = false
	_redraw()
	frame_changed.emit(int(_frame), cells)


func restart() -> void:
	_frame = 0.0
	playing = true


func current_frame() -> int:
	return int(_frame)


func _redraw() -> void:
	queue_redraw()
	if _glass != null:
		_glass.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GROUNDS[ground])
	if sheet == null or not show_grid:
		return
	var cell: float = float(sheet.get_width()) / float(cells)
	var drawn := Vector2(cell, float(sheet.get_height())) * zoom
	var at: Vector2 = (size - drawn) * 0.5
	draw_rect(Rect2(at, drawn), Color(1, 1, 1, 0.16), false, 1.0)
	# The middle, so an effect that is meant to be centred can be seen not to
	# be. Every impact in the catalogue is drawn about the centre and one of
	# them was not.
	draw_line(at + Vector2(drawn.x * 0.5, 0.0),
		at + Vector2(drawn.x * 0.5, drawn.y), Color(1, 1, 1, 0.10), 1.0)
	draw_line(at + Vector2(0.0, drawn.y * 0.5),
		at + Vector2(drawn.x, drawn.y * 0.5), Color(1, 1, 1, 0.10), 1.0)


## Every cell side by side, small, as a contact sheet. The playing view says
## how it moves and this says what it *is* - which is the reading that caught
## a flame rendering as a sunburst when its curve was perfect.
func contact_strip(into: Control, width: float) -> void:
	for child: Node in into.get_children():
		into.remove_child(child)
		child.queue_free()
	if sheet == null:
		return
	var cell: float = float(sheet.get_width()) / float(cells)
	# **Sized to fit, never anchored to fit.** `Control.size` is clamped to a
	# container's combined minimum, so a row of natural-size cells is as wide
	# as its cells whatever the panel says - the first cut anchored the row to
	# the strip and got a 1372-pixel row in an 830-pixel panel, showing eight
	# cells of fourteen. The share each cell may have is worked out first and
	# becomes its minimum, so the row's minimum is the width it was given.
	var each: float = maxf(floorf(width / float(cells)) - 2.0, 8.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	into.add_child(row)
	for index: int in cells:
		var one := TextureRect.new()
		one.custom_minimum_size = Vector2(each, each)
		var slice := AtlasTexture.new()
		slice.atlas = sheet
		slice.region = Rect2(float(index) * cell, 0.0, cell,
			float(sheet.get_height()))
		one.texture = slice
		one.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		one.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		one.modulate = tint
		one.tooltip_text = "cell %d" % (index + 1)
		row.add_child(one)
