class_name InkBatch
extends RefCounted

## **Many shapes, one hand-over** (2026-09-30). In the Compatibility renderer a
## `canvas_item_add_triangle_array` is a draw call and a new GPU buffer, and a
## `draw_arc` or `draw_polyline` is its own command that breaks the batch around
## it - so a canvas that drew each glow, each ring and each bolt on its own paid
## for every one of them. The visual bisect of Act X with a full Arsenal read
## the combat tells at 2.3 ms and the Arsenal at 2.9 ms, nearly all of it that.
##
## A batch is the arrays of one repaint. Shapes append to it; `flush` hands the
## lot to the renderer once. A batch with a texture carries UVs, so every head a
## weapon draws this frame - which all share one frame of its turning - is one
## call. The shapes are the ones the ink already draws: solid in the middle and
## clear at the rim wherever a soft edge is wanted, because one colour for a
## whole shape is what a hard edge is.

var points := PackedVector2Array()
var colours := PackedColorArray()
var uvs := PackedVector2Array()
var indices := PackedInt32Array()


func clear() -> void:
	points.clear()
	colours.clear()
	uvs.clear()
	indices.clear()


func is_empty() -> bool:
	return indices.is_empty()


## Hands the batch to `item` and empties it. A texture's batch is drawn with it.
func flush(item: RID, texture: Texture2D = null) -> void:
	if indices.is_empty():
		return
	if texture != null:
		RenderingServer.canvas_item_add_triangle_array(item, indices, points, colours, uvs,
			PackedInt32Array(), PackedFloat32Array(), texture.get_rid())
	else:
		RenderingServer.canvas_item_add_triangle_array(item, indices, points, colours)
	clear()


## A soft disc: `colour` in the middle, clear at the rim. `squash` lays it on
## the ground (`Vector2(1, 0.5)`).
func soft_disc(at: Vector2, radius: float, colour: Color, segments: int = 12,
		squash: Vector2 = Vector2.ONE) -> void:
	var base: int = points.size()
	points.append(at)
	colours.append(colour)
	var rim := Color(colour.r, colour.g, colour.b, 0.0)
	for step: int in segments:
		var angle: float = TAU * float(step) / float(segments)
		points.append(at + Vector2(cos(angle), sin(angle)) * radius * squash)
		colours.append(rim)
	for step: int in segments:
		indices.append(base)
		indices.append(base + 1 + step)
		indices.append(base + 1 + (step + 1) % segments)


## A solid disc, where `draw_circle` was.
func disc(at: Vector2, radius: float, colour: Color, segments: int = 12) -> void:
	var base: int = points.size()
	points.append(at)
	colours.append(colour)
	for step: int in segments:
		var angle: float = TAU * float(step) / float(segments)
		points.append(at + Vector2(cos(angle), sin(angle)) * radius)
		colours.append(colour)
	for step: int in segments:
		indices.append(base)
		indices.append(base + 1 + step)
		indices.append(base + 1 + (step + 1) % segments)


## A solid ring `width` across, where `draw_arc` was: the whole circle, or the
## part from `from` to `to` radians. `squash` lays it on the ground.
func ring(at: Vector2, radius: float, width: float, colour: Color, segments: int = 40,
		squash: Vector2 = Vector2.ONE, from: float = 0.0, to: float = TAU) -> void:
	if radius <= 0.5 or colour.a <= 0.004:
		return
	var base: int = points.size()
	var inner: float = maxf(radius - width * 0.5, 0.0)
	var outer: float = radius + width * 0.5
	for step: int in segments + 1:
		var angle: float = lerpf(from, to, float(step) / float(segments))
		var out := Vector2(cos(angle), sin(angle)) * squash
		points.append(at + out * inner)
		colours.append(colour)
		points.append(at + out * outer)
		colours.append(colour)
	for step: int in segments:
		var a: int = base + step * 2
		indices.append_array([a, a + 1, a + 2, a + 2, a + 1, a + 3])


## A solid band `width` across along a polyline, where `draw_polyline` was. The
## sides at each point follow the mean of the two segments meeting there, so a
## jagged bolt has no gaps at its joints.
func band(line: PackedVector2Array, width: float, colour: Color) -> void:
	var count: int = line.size()
	if count < 2 or colour.a <= 0.004:
		return
	var base: int = points.size()
	for index: int in count:
		var along: Vector2 = line[mini(index + 1, count - 1)] - line[maxi(index - 1, 0)]
		var side: Vector2 = along.normalized().orthogonal() * width * 0.5 \
			if along.length_squared() > 0.0001 else Vector2.ZERO
		points.append(line[index] - side)
		colours.append(colour)
		points.append(line[index] + side)
		colours.append(colour)
	for index: int in count - 1:
		var a: int = base + index * 2
		indices.append_array([a, a + 1, a + 2, a + 2, a + 1, a + 3])


## A textured quad `half` from its middle each way, turned by `angle` - where a
## `draw_set_transform` and a `draw_texture_rect` were.
func quad(at: Vector2, half: float, angle: float, colour: Color) -> void:
	var base: int = points.size()
	var right: Vector2 = Vector2.from_angle(angle) * half
	var down: Vector2 = right.orthogonal()
	points.append(at - right - down)
	points.append(at + right - down)
	points.append(at + right + down)
	points.append(at - right + down)
	uvs.append(Vector2(0.0, 0.0))
	uvs.append(Vector2(1.0, 0.0))
	uvs.append(Vector2(1.0, 1.0))
	uvs.append(Vector2(0.0, 1.0))
	for _corner: int in 4:
		colours.append(colour)
	indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


## One triangle of one colour.
func triangle(a: Vector2, b: Vector2, c: Vector2, colour: Color) -> void:
	var base: int = points.size()
	points.append(a)
	points.append(b)
	points.append(c)
	colours.append(colour)
	colours.append(colour)
	colours.append(colour)
	indices.append_array([base, base + 1, base + 2])


## `InkRibbon.ribbon`'s tapered, feathered ribbon, appended rather than handed
## over, so a canvas with many trails pays for one call.
func ribbon(line: PackedVector2Array, inverse: Transform2D, width: float,
		colour_at_head: Color, tail_alpha: float, head_alpha: float) -> void:
	var count: int = line.size()
	if count < 2:
		return
	var base: int = points.size()
	var clear_colour := Color(colour_at_head.r, colour_at_head.g, colour_at_head.b, 0.0)
	for index: int in count:
		var t: float = float(index) / float(count - 1)
		var here: Vector2 = line[index]
		var along: Vector2 = line[mini(index + 1, count - 1)] - line[maxi(index - 1, 0)]
		if along.length_squared() < 0.0001:
			along = Vector2.RIGHT
		var normal: Vector2 = along.normalized().orthogonal()
		var taper: float = lerpf(0.08, 1.0, t)
		var core: Vector2 = normal * width * 0.5 * taper
		var feather: Vector2 = normal * width * 1.1 * taper
		var mid := Color(colour_at_head.r, colour_at_head.g, colour_at_head.b,
			colour_at_head.a * lerpf(tail_alpha, head_alpha, t))
		points.append(inverse * (here - feather))
		colours.append(clear_colour)
		points.append(inverse * (here - core))
		colours.append(mid)
		points.append(inverse * (here + core))
		colours.append(mid)
		points.append(inverse * (here + feather))
		colours.append(clear_colour)
	for index: int in count - 1:
		var row: int = base + index * 4
		for column: int in 3:
			var a: int = row + column
			indices.append_array([a, a + 1, a + 4, a + 1, a + 5, a + 4])
