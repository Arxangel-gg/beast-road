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
	# The last row is clear too, so the band fades out under the feet rather
	# than ending in a hard line on the water (owner report, 2026-09-14).
	var rows: Array[float] = [0.0, feather, drawn.y * waterline * 0.5, drawn.y * waterline + 6.0,
		drawn.y * waterline + 6.0 + feather * 3.0]
	# In a flood the band wears the flood's colour, a little thinner, so it
	# is the same water as the sheet around it.
	var body: Color = water
	if RunState.flood > 0.0:
		body = water.lerp(Balance.FLOOD_TINT, RunState.flood * 0.7)
		body.a = water.a * (1.0 - 0.35 * RunState.flood)
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for row: int in rows.size():
		for index: int in steps + 1:
			var x: float = lerpf(left, right, float(index) / float(steps))
			var wobble: float = sin(x * 0.11 + _clock * 4.2) * 2.2 + sin(x * 0.05 - _clock * 2.7) * 1.4
			var y: float = line + rows[row] + (wobble if row < 2 else 0.0)
			points.append(Vector2(x, y))
			var alpha: float = body.a
			if row == 0 or row == rows.size() - 1:
				alpha = 0.0
			alpha *= _end_fade(x, left, right)
			if field != null and field.has_method("water_depth_at"):
				var world: Vector2 = get_global_transform() * Vector2(x, y)
				if float(field.call("water_depth_at", world)) <= 0.0:
					alpha = 0.0
			colours.append(Color(body.r, body.g, body.b, alpha))
	var indices := PackedInt32Array()
	for row: int in rows.size() - 1:
		for index: int in steps:
			var a: int = row * (steps + 1) + index
			var b: int = a + 1
			var c: int = a + steps + 1
			var d: int = c + 1
			indices.append_array([a, b, c, b, d, c])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)
	_draw_the_sheen(points, colours, steps, left, right)


## **How far a point is from the end of the line, as a share.**
##
## Smoothstep rather than a straight ramp: a linear fade reaches full strength at
## a definite place and the eye finds that place, so a "feathered" edge still
## reads as an edge. This has no corner at either end of the fade.
func _end_fade(x: float, left: float, right: float) -> float:
	var reach: float = maxf(Balance.SWIM_COVER_SIDE_FEATHER,
		(right - left) * 0.5 * Balance.SWIM_COVER_SIDE_SHARE)
	return smoothstep(0.0, reach, minf(x - left, right - x))


## **The light along the surface**, as a feathered strip rather than a stroke.
##
## The band under it has been feathered by vertex colour since it was written and
## this was a `draw_line` at a flat alpha that simply stopped at each end - which
## is the white stub the owner reported. Three rows: clear above, bright on the
## surface, clear below, every vertex carrying the same end fade and the same
## "is this over water" question the band asks, so it cannot draw over a bank.
##
## One `canvas_item_add_triangle_array` rather than fourteen `draw_line` calls,
## which is also fewer draw calls than it replaces - `flame.gd` is the standing
## warning in this project about per-segment drawing.
func _draw_the_sheen(band: PackedVector2Array, wet: PackedColorArray, steps: int,
		left: float, right: float) -> void:
	var surface: int = steps + 1
	var reach: float = Balance.SWIM_COVER_SHEEN_REACH
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for row: int in 3:
		for index: int in steps + 1:
			var on: Vector2 = band[surface + index]
			points.append(on + Vector2(0.0, (float(row) - 1.0) * reach))
			var alpha: float = 0.0
			if row == 1 and wet[surface + index].a > 0.01:
				alpha = 0.62 * _end_fade(on.x, left, right)
				# A slow glint travelling along the surface: the same water,
				# catching light as it moves.
				var travel: float = sin(on.x * 0.035 - _clock * 1.6)
				alpha *= 1.0 + Balance.SWIM_COVER_GLINT * travel
			colours.append(Color(0.9, 0.97, 1.0, maxf(alpha, 0.0)))
	var indices := PackedInt32Array()
	for row: int in 2:
		for index: int in steps:
			var a: int = row * (steps + 1) + index
			indices.append_array([a, a + 1, a + steps + 1,
				a + 1, a + steps + 2, a + steps + 1])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)
