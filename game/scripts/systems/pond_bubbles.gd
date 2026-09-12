class_name PondBubbles
extends Node2D

## Something under the water: a patch of bubbles that surfaces and pops, and
## the dark shape that makes them.
##
## Owner brief (2026-09-12): parts of a pond should have bubbles surfacing
## and popping with gentle movement; a cast into them is a chance at a rarer
## fish, or at startling it; a swimmer in them may be bitten. This node is
## the *tell* - what the player reads - and `Fishing` owns what it means.
##
## Drawn rather than particled, and deliberately small: eight bubbles on a
## slow clock, a pop ring each, and a soft shadow that drifts beneath. Two of
## these per pond is nothing, and the drawing is quantised to whole pixels so
## it reads as the pond's own pixel art moving rather than a smooth overlay.

const BUBBLE_COUNT: int = 8
const RISE_SECONDS: float = 1.6

## The patch's radius in world units. Read by the fishing code for the cast
## and the bite; drawn here.
var radius: float = 44.0
var _clock: float = 0.0
var _phases: PackedFloat32Array = []
var _offsets: PackedVector2Array = []
var _sizes: PackedFloat32Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(str(global_position.x, ":", global_position.y))
	for index: int in BUBBLE_COUNT:
		_phases.append(_rng.randf())
		_offsets.append(Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(0.0, 0.8))
		_sizes.append(_rng.randf_range(1.5, 3.5))
	# Above the water it sits on, and never y-sorted against the things
	# standing on the bank: a bubble is on the surface, not a body.
	z_index = 1
	y_sort_enabled = false


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	# The shape below: a dark disc that breathes, offset against the bubbles'
	# drift so it reads as a thing rather than as a shadow of the patch.
	var breath: float = 0.9 + 0.1 * sin(_clock * 1.3)
	draw_circle(Vector2(sin(_clock * 0.6) * 5.0, cos(_clock * 0.45) * 3.0),
		radius * 0.55 * breath, Color(0.02, 0.05, 0.08, 0.28))
	for index: int in BUBBLE_COUNT:
		var life: float = fmod(_clock / RISE_SECONDS + _phases[index], 1.0)
		var at: Vector2 = _offsets[index] * radius
		# Rising: a bubble drifts up the screen a little as it comes to the
		# surface, then pops as a ring for the last fifth of its life.
		var rise: float = minf(life / 0.8, 1.0)
		at.y -= rise * 6.0
		at.x += sin((life + _phases[index]) * TAU * 1.5) * 2.0
		at = at.round()
		var size: float = _sizes[index] * (0.5 + 0.5 * rise)
		if life < 0.8:
			draw_circle(at, size, Color(0.86, 0.94, 1.0, 0.55))
			draw_circle(at + Vector2(-size * 0.35, -size * 0.35), maxf(size * 0.35, 0.8),
				Color(1.0, 1.0, 1.0, 0.75))
		else:
			var pop: float = (life - 0.8) / 0.2
			draw_arc(at, size + pop * 5.0, 0.0, TAU, 12,
				Color(0.9, 0.97, 1.0, 0.6 * (1.0 - pop)), 1.0)
