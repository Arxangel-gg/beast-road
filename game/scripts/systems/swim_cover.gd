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
	# The surface, wobbling: a polygon with a sine along its top edge.
	var points: PackedVector2Array = []
	var steps: int = 14
	for index: int in steps + 1:
		var x: float = lerpf(left, right, float(index) / float(steps))
		var y: float = line + sin(x * 0.11 + _clock * 4.2) * 2.2 + sin(x * 0.05 - _clock * 2.7) * 1.4
		points.append(Vector2(x, y))
	points.append(Vector2(right, bottom + 6.0))
	points.append(Vector2(left, bottom + 6.0))
	draw_colored_polygon(points, water)
	# The highlight along the surface.
	var bright: Color = Color(0.9, 0.97, 1.0, 0.55)
	for index: int in steps:
		draw_line(points[index], points[index + 1], bright, 1.5)
