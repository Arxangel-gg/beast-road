class_name SwimCover
extends Node2D

## The water over a swimmer's legs.
##
## Owner brief (2026-09-12): a hero who walks into a pond falls in and swims,
## with the submerged part semi-transparent. The hero's sprite already wears
## the blood-and-impact material and a second material cannot stack on one
## sprite, so the water is drawn *over* the sprite instead: a band of the
## pond's own colour from the waterline down, with a wobbling surface line and
## a pale highlight along it. The legs show through it dimly, which is what
## "submerged" looks like from above.
##
## Follows the sprite's frame rather than the node: the frames are 160 tall
## with the feet on the bottom row, so the waterline is a fraction of the
## sprite's drawn height and moves with any squash the animator applies.

## The sprite to cover.
var sprite: Sprite2D = null
## The colour of the water the hero is in, alpha included.
var water: Color = Color(0.16, 0.34, 0.48, 0.58)
## The surface line as a fraction of the sprite's height from its feet.
var waterline: float = 0.42
var _clock: float = 0.0


func _ready() -> void:
	z_index = 1
	y_sort_enabled = false
	visible = false


func _process(delta: float) -> void:
	_clock += delta
	if visible:
		queue_redraw()


## The field, asked whether each vertex is over water. Set by the hero.
var field: Node = null


func _draw() -> void:
	if sprite == null or sprite.texture == null:
		return
	# The sprite's drawn rectangle, in this node's space (a sibling of the
	# sprite under the same parent, so the transform is the sprite's own).
	var frame: Vector2 = Vector2(sprite.region_rect.size) if sprite.region_enabled \
		else sprite.texture.get_size()
	var drawn: Vector2 = frame * sprite.scale.abs()
	var top_left: Vector2 = sprite.position + sprite.offset * sprite.scale \
		- (drawn * 0.5 if sprite.centered else Vector2.ZERO)
	var bottom: float = top_left.y + drawn.y
	var line: float = bottom - drawn.y * waterline
	var left: float = top_left.x - 6.0
	var right: float = top_left.x + drawn.x + 6.0
	# **Feathered, and clipped to the water.** A strip of quads with vertex
	# colours: the top row at the surface is clear and a few pixels down is
	# the water's full colour, the outermost columns are clear, and any vertex
	# standing over dry ground is clear too - so the band never draws a hard
	# edge over the bank or the pond's own rim (owner report, 2026-09-12).
	var steps: int = 14
	var feather: float = Balance.SWIM_COVER_FEATHER
	var rows: Array[float] = [0.0, feather, drawn.y * waterline * 0.5, drawn.y * waterline + 6.0]
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for row: int in rows.size():
		for index: int in steps + 1:
			var x: float = lerpf(left, right, float(index) / float(steps))
			var wobble: float = sin(x * 0.11 + _clock * 4.2) * 2.2 + sin(x * 0.05 - _clock * 2.7) * 1.4
			var y: float = line + rows[row] + (wobble if row < 2 else 0.0)
			points.append(Vector2(x, y))
			var alpha: float = water.a
			if row == 0:
				alpha = 0.0
			var side: float = minf(x - left, right - x)
			alpha *= clampf(side / Balance.SWIM_COVER_SIDE_FEATHER, 0.0, 1.0)
			if field != null and field.has_method("water_depth_at"):
				var world: Vector2 = get_global_transform() * Vector2(x, y)
				if float(field.call("water_depth_at", world)) <= 0.0:
					alpha = 0.0
			colours.append(Color(water.r, water.g, water.b, alpha))
	var indices := PackedInt32Array()
	for row: int in rows.size() - 1:
		for index: int in steps:
			var a: int = row * (steps + 1) + index
			var b: int = a + 1
			var c: int = a + steps + 1
			var d: int = c + 1
			indices.append_array([a, b, c, b, d, c])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)
	# The highlight along the surface.
	var bright: Color = Color(0.9, 0.97, 1.0, 0.55)
	for index: int in steps:
		var a: Vector2 = points[(steps + 1) + index]
		var b: Vector2 = points[(steps + 1) + index + 1]
		var wet: bool = colours[(steps + 1) + index].a > 0.01 and colours[(steps + 1) + index + 1].a > 0.01
		if wet:
			draw_line(a, b, bright, 1.5)
