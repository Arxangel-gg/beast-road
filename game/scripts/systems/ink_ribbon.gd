class_name InkRibbon
extends RefCounted

## A tapered, feathered ribbon along a polyline, drawn as one triangle array
## (2026-09-24). The shape both projectile kinds trail behind them, and the
## reason it is not a `Line2D`: a line has one width and two flat caps, so a
## trail read as a pipe with a rounded end, and every shot rebuilt its
## line's mesh twice a frame. This is nine floats a point handed to the
## renderer once, and it has no hard edge anywhere - solid on the spine, clear
## at both sides, nothing at the tail.
##
## `inverse` is the target item's inverse global transform, because the
## points are in world space and a canvas item draws in its own.

static var _points: PackedVector2Array = PackedVector2Array()
static var _colours: PackedColorArray = PackedColorArray()
static var _indices: PackedInt32Array = PackedInt32Array()


static func ribbon(on: CanvasItem, points: PackedVector2Array, inverse: Transform2D,
		width: float, colour_at_head: Color, tail_alpha: float, head_alpha: float) -> void:
	var count: int = points.size()
	if count < 2 or on == null:
		return
	_points.clear()
	_colours.clear()
	_indices.clear()
	var clear := Color(colour_at_head.r, colour_at_head.g, colour_at_head.b, 0.0)
	for index: int in count:
		var t: float = float(index) / float(count - 1)
		var here: Vector2 = points[index]
		var next: Vector2 = points[mini(index + 1, count - 1)]
		var prev: Vector2 = points[maxi(index - 1, 0)]
		var along: Vector2 = next - prev
		if along.length_squared() < 0.0001:
			along = Vector2.RIGHT
		var side: Vector2 = along.normalized().orthogonal() * width * lerpf(0.05, 1.0, t)
		var mid := Color(colour_at_head.r, colour_at_head.g, colour_at_head.b,
			colour_at_head.a * lerpf(tail_alpha, head_alpha, t))
		_points.append(inverse * (here - side))
		_colours.append(clear)
		_points.append(inverse * here)
		_colours.append(mid)
		_points.append(inverse * (here + side))
		_colours.append(clear)
	for index: int in count - 1:
		var row: int = index * 3
		for column: int in 2:
			var a: int = row + column
			_indices.append(a)
			_indices.append(a + 1)
			_indices.append(a + 3)
			_indices.append(a + 1)
			_indices.append(a + 4)
			_indices.append(a + 3)
	RenderingServer.canvas_item_add_triangle_array(on.get_canvas_item(), _indices, _points, _colours)
