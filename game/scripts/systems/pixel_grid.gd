class_name PixelGrid
extends Control

## **The grid itself: a screen copy, a shader, and nothing else.**
##
## Split out of `PixelFilter` on 2026-09-17, when the owner asked for the grid on
## the main menu as well. A `CanvasLayer` is the right home for it in a *run*,
## where the scopes, the HUD and the type are already three layers - but the menu
## is one `Control` tree drawing in order, and what has to go between the painted
## art and the buttons there is a *sibling at the right index*, not a layer.
##
## So the mechanism is a `Control` and the layer is a wrapper around it. Both
## routes are the same node doing the same thing: everything drawn before it is
## snapped to the grid, everything after it is not, and where "before" ends is
## the only thing the two callers disagree about.
##
## **Optimised where the cost actually is.** A fullscreen pass is one texture
## read, two floors and a short loop, which is nothing; the expensive half is the
## `BackBufferCopy`, and that is switched *off* rather than left running when the
## setting is off. Turned off, this copies nothing, draws nothing and costs a
## hidden `ColorRect`.
##
## **It changes no number.** Nothing reads it and nothing asks it anything, so
## the run is identical with it on or off - the bound the fog of war, the
## phenotypes and the trampled foliage are all held to, and what makes it safe to
## give away on a weak machine.
##
## **Never headless**, where there is no frame to copy. `flood_sheen` learned the
## same way: a screen-reading shader with nothing to read is a black rectangle
## over the game.

const SHADER: String = "res://scripts/shaders/pixel_filter.gdshader"

var _copy: BackBufferCopy = null
var _screen: ColorRect = null
var _material: ShaderMaterial = null
var _on: bool = false
## Rectangles handed in by `CrispText` for the text it cannot redraw.
var _exclude: Array[Rect2] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_fit()
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


## The rectangles the grid leaves alone, from `CrispText`.
##
## **Truncated here rather than at the caller**, because the bound belongs to the
## shader's array and this is the only thing that knows about it. A ninth
## rectangle would be dropped in silence otherwise, which is a `RichTextLabel`
## quietly going blocky on one screen and nowhere else - exactly the kind of
## absence nothing notices.
func set_exclusions(rects: Array[Rect2]) -> void:
	_exclude = rects.slice(0, Balance.UI_PIXEL_FILTER_EXCLUDE_MAX)
	_push_exclusions()


func exclusions() -> int:
	return _exclude.size()


func _push_exclusions() -> void:
	if _material == null:
		return
	var packed: Array[Plane] = []
	for rect: Rect2 in _exclude:
		# A `vec4` uniform array takes Planes from GDScript: x, y, width, height.
		packed.append(Plane(rect.position.x, rect.position.y,
			rect.size.x, rect.size.y))
	_material.set_shader_parameter("exclude", packed)
	_material.set_shader_parameter("exclusions", packed.size())


## The grid, and the viewport it is measured in.
##
## The block is stated in pixels rather than in UV because a grid that is square
## in UV is a rectangle of blocks on any window that is not square.
func _fit() -> void:
	if _screen == null or _material == null or not is_inside_tree():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	# **The rect is not assigned.** It is anchored `PRESET_FULL_RECT`, so the
	# layout already gives it the whole viewport - and writing `size` on a
	# Control whose opposite anchors differ makes Godot warn that it will be
	# overridden after `_ready`, which every gate that stands up a run then
	# prints. A warning is a failed gate on the release bar.
	if _copy != null:
		_copy.rect = Rect2(Vector2.ZERO, view)
	_material.set_shader_parameter("viewport", view)
	_material.set_shader_parameter("grid", block_for(view))
	_material.set_shader_parameter("strength", 1.0)
	_push_exclusions()


## How big one block is on this screen.
##
## **A share of the height rather than a flat number.** A three-pixel block is a
## strong effect on a 720-tall window and almost invisible on a 4K one, so the
## same setting would be two different games. Rounded to a whole number because a
## fractional grid puts one block edge on a half pixel and the rows either side
## of it come out different widths - which reads as a seam across the screen
## rather than as pixel art.
static func block_for(view: Vector2) -> float:
	return block_at(view, Graphics.pixel_filter_block())


## The same arithmetic against a stated block, so a gate can ask what a setting
## *would* draw without having to change the player's own.
static func block_at(view: Vector2, want: float) -> float:
	var share: float = view.y / Balance.UI_PIXEL_FILTER_REFERENCE_HEIGHT
	return maxf(round(want * share), 1.0)
