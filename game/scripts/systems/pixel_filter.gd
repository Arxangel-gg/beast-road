class_name PixelFilter
extends CanvasLayer

## **One grid for the whole world** (owner, 2026-09-17).
##
## The brief: *"can you apply a pixel art shader to the whole screen? One that is
## perfectly polished and optimized, and also include it in the settings toggle,
## in hopes that this will give a more cohesive look to the whole game."*
##
## **What it is actually fixing.** The sprites are pixel art on their own grid;
## everything the engine draws beside them - blood fans, flame cones, the fog's
## soft edge, a bar's fill, a ring at a telegraph - is drawn at device
## resolution and sits on no grid at all. That is two materials in one frame, and
## snapping the finished picture to a single grid is what puts them on the same
## one.
##
## **It goes over the world and under the interface**, and that is the decision
## in this file. A filter over everything would quantise the type as well, and
## the owner asked for bigger, clearer battlefield text in the same breath -
## making the letters blocky would take that back. So it sits at
## `Balance.UI_PIXEL_FILTER_LAYER`, above every scope and below the HUD.
##
## **Optimised where the cost actually is.** A fullscreen pass is one texture
## read and two floors, which is nothing; the expensive half is the
## `BackBufferCopy`, and that is switched *off* rather than left running when the
## setting is off. Turned off, this node copies nothing, draws nothing and costs
## a hidden `ColorRect`.
##
## **It changes no number.** Nothing reads it, nothing asks it anything, and the
## run is identical with it on or off - the bound the fog of war, the phenotypes
## and the trampled foliage are all held to, which is what makes it safe to give
## away on a weak machine.
##
## **Never headless.** There is no frame to copy, and `flood_sheen` learned that
## the same way: a screen-reading shader with no screen is a black rectangle over
## the game.

const SHADER: String = "res://scripts/shaders/pixel_filter.gdshader"

var _copy: BackBufferCopy = null
var _screen: ColorRect = null
var _material: ShaderMaterial = null
var _on: bool = false


func _ready() -> void:
	name = "PixelFilter"
	layer = Balance.UI_PIXEL_FILTER_LAYER
	# So the switch in the video settings reaches it while the game is running,
	# rather than changing a saved value and nothing on screen - which is how a
	# setting reads as broken, and is why this group exists.
	add_to_group(Graphics.SETTINGS_GROUP)
	_build()
	refresh_from_settings()
	get_viewport().size_changed.connect(_fit)


func _build() -> void:
	_copy = BackBufferCopy.new()
	_copy.name = "Copy"
	_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	add_child(_copy)

	_screen = ColorRect.new()
	_screen.name = "Screen"
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.visible = false
	if ResourceLoader.exists(SHADER):
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER) as Shader
		_screen.material = _material
	add_child(_screen)
	_fit()


## Reads the setting. Named to match the other display preferences, because
## `Graphics.apply_to_scene` calls this on every node that has it.
func refresh_from_settings() -> void:
	set_enabled(Graphics.pixel_filter())


func set_enabled(on: bool) -> void:
	_on = on and _material != null
	if _copy != null:
		# **The copy is the cost, so the copy is what stops.** Leaving it in
		# `COPY_MODE_VIEWPORT` and hiding the rect would pay for a full screen
		# read every frame to feed a shader nobody is running.
		_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if _on \
			else BackBufferCopy.COPY_MODE_DISABLED
	if _screen != null:
		_screen.visible = _on
	_fit()


func enabled() -> bool:
	return _on


## The grid, and the viewport it is measured in.
##
## The block is stated in pixels rather than in UV because a grid that is square
## in UV is a rectangle of blocks on any window that is not square.
func _fit() -> void:
	if _screen == null or _material == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	_screen.size = view
	if _copy != null:
		_copy.rect = Rect2(Vector2.ZERO, view)
	_material.set_shader_parameter("viewport", view)
	_material.set_shader_parameter("grid", block_for(view))
	_material.set_shader_parameter("strength", 1.0)


## How big one block is on this screen.
##
## **A share of the height rather than a flat number.** A three-pixel block is a
## strong effect on a 720-tall window and almost invisible on a 4K one, so the
## same setting would be two different games. Rounded to a whole number because
## a fractional grid puts one block edge on a half pixel and the rows either
## side of it come out different widths - which reads as a seam across the
## screen rather than as pixel art.
static func block_for(view: Vector2) -> float:
	var share: float = view.y / Balance.UI_PIXEL_FILTER_REFERENCE_HEIGHT
	return maxf(round(Balance.UI_PIXEL_FILTER_BLOCK * share), 1.0)
