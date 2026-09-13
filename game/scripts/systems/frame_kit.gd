class_name FrameKit
extends RefCounted

## One frame, drawn the same way everywhere it is wanted.
##
## Owner brief, 2026-09-13: the minimap should have "a thin aesthetic border
## frame", and "things that can have aesthetic frames should".
##
## The minimap had two nested `draw_rect` calls, which is a border rather than a
## frame, and every other picture in the game - the Guide's photographs, the
## codex's creatures, the Warden's portrait, the forge over its own screen - had
## none at all. A picture with no edge reads as a hole in the panel rather than
## as something hung on it.
##
## **Drawn rather than nine-sliced**, because it has to sit on things of wildly
## different sizes - a 40px codex thumbnail and a 640px photograph - and a
## texture stretched across both would be a different weight of line on each.
## Four lines and eight short brackets cost nothing and are the same thickness
## at every size.
##
## Two ways in, and they are the same drawing:
##
##   `FrameKit.draw_frame(ci, rect)` inside a `_draw`, for something already
##   drawing itself.
##   `FrameKit.hang(control)` for a `TextureRect` or a panel, which adds an
##   overlay that keeps itself the right size and ignores the mouse.

## The dark outer line, the bright hairline inside it, and the corner brackets.
const OUTLINE: Color = Color(0.06, 0.07, 0.07, 0.92)
const HAIRLINE: Color = Color(0.66, 0.60, 0.44, 0.55)
const CORNER: Color = Color(0.91, 0.78, 0.48, 0.85)
const THICK: float = 2.0
## How long a corner bracket is, as a share of the shorter side, and the most
## it may ever be - a bracket that scaled freely would meet in the middle of a
## small thumbnail.
const CORNER_SHARE: float = 0.16
const CORNER_MAX: float = 22.0
const CORNER_MIN: float = 5.0


## Draws the frame on `ci`, inside `rect`.
static func draw_frame(ci: CanvasItem, rect: Rect2, tint: Color = CORNER) -> void:
	if ci == null or rect.size.x < 4.0 or rect.size.y < 4.0:
		return
	ci.draw_rect(rect, OUTLINE, false, THICK)
	var inner: Rect2 = rect.grow(-THICK)
	ci.draw_rect(inner, HAIRLINE, false, 1.0)

	# Brackets, on the inner line so they read as part of the frame rather than
	# as something sitting outside it.
	var reach: float = clampf(minf(inner.size.x, inner.size.y) * CORNER_SHARE,
		CORNER_MIN, CORNER_MAX)
	var left: float = inner.position.x
	var top: float = inner.position.y
	var right: float = inner.position.x + inner.size.x
	var bottom: float = inner.position.y + inner.size.y
	var width: float = maxf(THICK - 0.4, 1.2)
	for corner: Array in [
			[Vector2(left, top), Vector2(1.0, 0.0), Vector2(0.0, 1.0)],
			[Vector2(right, top), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)],
			[Vector2(left, bottom), Vector2(1.0, 0.0), Vector2(0.0, -1.0)],
			[Vector2(right, bottom), Vector2(-1.0, 0.0), Vector2(0.0, -1.0)]]:
		var at: Vector2 = corner[0]
		ci.draw_line(at, at + (corner[1] as Vector2) * reach, tint, width, true)
		ci.draw_line(at, at + (corner[2] as Vector2) * reach, tint, width, true)


## Hangs a frame on an existing control.
##
## The overlay is a child rather than a wrapper, so nothing about the parent's
## layout changes - a framed `TextureRect` is the same size and in the same
## place it was, which is what makes this safe to add to a screen a layout gate
## already measures.
static func hang(on: Control, tint: Color = CORNER) -> Control:
	if on == null:
		return null
	var overlay := Control.new()
	overlay.name = "Frame"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(func() -> void:
		draw_frame(overlay, Rect2(Vector2.ZERO, overlay.size), tint))
	on.resized.connect(func() -> void: overlay.queue_redraw())
	on.add_child(overlay)
	return overlay
