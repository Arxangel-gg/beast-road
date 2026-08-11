class_name Arena
extends Node2D

## Stage 1's arena: one open circle, a tiled ground, and nothing else.
##
## GDD §10 is explicit that this stage has no towers, no lanes, no city and no
## waves. The only question it exists to answer is whether swinging at things is
## fun with nothing on top of it, and every element added here that is not the
## hero, an enemy, or the floor makes that answer less trustworthy.
##
## Sizes are applied from Balance at runtime rather than baked into the scene
## file, so the arena resizes when the tuning does.

@export var ground: Sprite2D
@export var boundary: Line2D
@export var hero: Hero

## Segments in the boundary ring. Enough that it reads as a circle.
const BOUNDARY_SEGMENTS: int = 96

const BOUNDARY_COLOUR: Color = Color(0.85, 0.80, 0.72, 0.30)
const BOUNDARY_WIDTH: float = 4.0

## How far the floor extends past the boundary, so the arena edge is a line on
## the ground rather than the end of the world.
const GROUND_OVERDRAW: float = 1.25


func _ready() -> void:
	_setup_ground()
	_setup_boundary()
	RunState.reset()


## The terrain placeholder is a 512px tile. Repeating it across the arena gives
## the movement something to read against — without a texture underfoot, 200px/s
## and 600px/s look identical.
func _setup_ground() -> void:
	if ground == null:
		return
	var extent: float = Balance.ARENA_RADIUS * GROUND_OVERDRAW
	ground.centered = true
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	ground.region_rect = Rect2(-extent, -extent, extent * 2.0, extent * 2.0)


## A greybox marker for the spawn ring, not art. Stage 2 replaces it with the
## terrain edge and the four lanes.
func _setup_boundary() -> void:
	if boundary == null:
		return
	var points: PackedVector2Array = []
	for i: int in BOUNDARY_SEGMENTS + 1:
		var angle: float = TAU * float(i) / float(BOUNDARY_SEGMENTS)
		points.append(Vector2.RIGHT.rotated(angle) * Balance.ARENA_RADIUS)
	boundary.points = points
	boundary.width = BOUNDARY_WIDTH
	boundary.default_color = BOUNDARY_COLOUR
	boundary.closed = true
