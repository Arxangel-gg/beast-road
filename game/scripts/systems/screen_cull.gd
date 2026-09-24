class_name ScreenCull
extends RefCounted

## One question, asked by everything that may rest while the camera is
## elsewhere (2026-09-24): could any of this node land inside the viewport?
##
## `Flame` had its own copy of this test since the flames were made to redraw
## only in view, and the tower airs, the camp fires and the foliage's idle
## step each had none - so a hundred torches' embers, forty towers' airs and
## every ember on every camp were simulated on the CPU every frame whether or
## not a single one of them could be seen. `CPUParticles2D` skips its whole
## update while it is not visible in the tree, which is what makes hiding an
## emitter the cheap answer: nothing restarts, nothing is freed, and an
## emitter scrolling back into view is mid-life rather than starting empty.
##
## `get_global_transform_with_canvas` gives the position in viewport pixels
## directly, so this costs one transform and four comparisons. A node with no
## viewport - one being built, or one a gate stands up on its own - is always
## seen, because "not drawn" must never mean "not simulated" for something
## that is about to be drawn.
##
## A look, never a fact. Nothing about damage, spawning, pathing or reward
## reads whether a thing is on screen.

static func sees(node: CanvasItem, margin: float) -> bool:
	if node == null or not node.is_inside_tree():
		return true
	var view: Viewport = node.get_viewport()
	if view == null:
		return true
	var at: Vector2 = node.get_global_transform_with_canvas().origin
	var size: Vector2 = view.get_visible_rect().size
	return at.x > -margin and at.y > -margin \
		and at.x < size.x + margin and at.y < size.y + margin


## The rectangle of the world the camera can see, grown by `margin`, for a
## system that holds many positions and would rather test them against one
## rectangle than transform each of them. A viewport with no camera answers
## its own rectangle, which is what a headless gate sees.
static func world_window(view: Viewport, margin: float) -> Rect2:
	if view == null:
		return Rect2(-1.0e9, -1.0e9, 2.0e9, 2.0e9)
	var rect: Rect2 = view.get_visible_rect()
	var world: Rect2 = view.get_canvas_transform().affine_inverse() * rect
	return world.grow(margin)
