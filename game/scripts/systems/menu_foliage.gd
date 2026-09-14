class_name MenuFoliage
extends Node2D

## Hanging vines and standing ferns for the main menu, drawn rather than
## animated.
##
## **Owner brief, 2026-09-14:** branches with hanging vines in the top corners
## and large ferns in the bottom corners, swaying - and explicitly *not* looping
## pixel-art animation, which reads as repetitive the moment the loop is seen.
##
## So nothing here is a sprite and nothing loops. A vine is a chain of segments
## whose angle is the sum of two sines of different periods, and the periods are
## irrational multiples of each other - so the motion never returns to the same
## pose and there is no loop to notice. The same trick carries the ferns.
##
## Drawn as **silhouettes**, near-black against the menu's warm sky, because
## that is what foliage this close to a camera actually is at dusk - and because
## a silhouette needs no texture, no palette and no per-region art, so it fits
## every act's backdrop without ten sets of assets.
##
## One `_draw` for everything. Each frond and vine is a polyline, so the whole
## corner is a handful of draw calls rather than a node per leaf - the lesson
## `flame.gd` cost the project twice.

## Where the piece is rooted and which way it grows.
enum Kind { VINE, FERN }

## Which corner, as a fraction of the screen. Set by the menu.
var anchor: Vector2 = Vector2.ZERO
var kind: int = Kind.VINE
## Mirrors the whole piece, so the right-hand corner is not the left one again.
var facing: float = 1.0
## Silhouette colour. The menu passes its own sky's darkest value.
var tint: Color = Color(0.04, 0.05, 0.05, 0.92)
## Overall size in pixels: a vine's length, a fern's frond reach.
var reach: float = 320.0
## How far the tip travels, in radians of accumulated lean.
var sway: float = 0.22
## Decorrelates two pieces built from the same numbers.
var phase: float = 0.0

var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
## Per-strand: length scale, hang angle, sway scale, its own phase.
var _strands: Array[Dictionary] = []


func _ready() -> void:
	_rng.seed = hash("menu-foliage") ^ int(phase * 1024.0) ^ int(anchor.x * 977.0)
	_grow()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Decides the shape once. The motion is computed per frame; the *plant* is not.
func _grow() -> void:
	_strands.clear()
	var count: int = VINE_STRANDS if kind == Kind.VINE else FERN_FRONDS
	for index: int in count:
		var along: float = float(index) / maxf(float(count - 1), 1.0)
		_strands.append({
			"along": along,
			"length": _rng.randf_range(0.55, 1.0),
			"lean": _rng.randf_range(-0.20, 0.20),
			"sway": _rng.randf_range(0.7, 1.35),
			"phase": _rng.randf_range(0.0, TAU),
			"leaves": _rng.randi_range(3, 7),
		})


func _draw() -> void:
	if kind == Kind.VINE:
		_draw_branch()
	for strand: Dictionary in _strands:
		if kind == Kind.VINE:
			_draw_vine(strand)
		else:
			_draw_frond(strand)


## The limb the vines hang from: a thick tapering stroke into the corner.
func _draw_branch() -> void:
	var points := PackedVector2Array()
	var span: float = reach * BRANCH_SPAN
	for step: int in BRANCH_POINTS:
		var along: float = float(step) / float(BRANCH_POINTS - 1)
		# Sags a little along its length, and breathes very slowly - a branch
		# this thick barely moves, and moving it much reads as rubber.
		var droop: float = along * along * reach * 0.16
		var breath: float = sin(_time * 0.31 + phase) * reach * 0.012 * along
		points.append(Vector2(along * span * facing, droop + breath))
	# Drawn twice, thick then thin, so it tapers without needing a polygon.
	draw_polyline(points, tint, reach * 0.055, true)
	var half := PackedVector2Array()
	for index: int in range(points.size() / 2, points.size()):
		half.append(points[index])
	draw_polyline(half, tint, reach * 0.030, true)


## One hanging vine, swaying more the further it is from the branch.
func _draw_vine(strand: Dictionary) -> void:
	var along: float = float(strand["along"])
	var root := Vector2(along * reach * BRANCH_SPAN * facing,
		along * along * reach * 0.16)
	var length: float = reach * float(strand["length"])
	var own_phase: float = float(strand["phase"]) + phase
	var own_sway: float = sway * float(strand["sway"])

	var points := PackedVector2Array()
	var leaves: Array[Vector2] = []
	var angle: float = float(strand["lean"])
	var at: Vector2 = root
	var step_length: float = length / float(VINE_SEGMENTS)
	for segment: int in VINE_SEGMENTS:
		var down: float = float(segment) / float(VINE_SEGMENTS)
		# **Two sines of incommensurable periods.** Their sum has no period, so
		# the vine never returns to a pose a viewer can recognise - which is the
		# whole reason this is not a sprite animation.
		var wind: float = sin(_time * 0.9 + own_phase + down * 2.1) * 0.62 \
			+ sin(_time * 0.6180339 * 1.7 + own_phase * 1.31 + down * 3.3) * 0.38
		# The lean accumulates down the strand, so the tip travels far and the
		# root barely moves - which is how a hanging thing actually behaves.
		angle += wind * own_sway * down / float(VINE_SEGMENTS) * 6.0
		at += Vector2(sin(angle) * step_length, cos(angle) * step_length)
		points.append(at)
		if segment > 1 and segment % maxi(int(VINE_SEGMENTS / int(strand["leaves"])), 1) == 0:
			leaves.append(at)
	draw_polyline(points, tint, maxf(reach * 0.010, 1.5), true)
	for leaf: Vector2 in leaves:
		_draw_leaf(leaf, angle)


## A leaf, as a small triangle: three points beat a texture at this size.
func _draw_leaf(at: Vector2, angle: float) -> void:
	var out: Vector2 = Vector2(sin(angle + 1.2), cos(angle + 1.2)) * reach * 0.045
	var side: Vector2 = out.orthogonal() * 0.42
	draw_colored_polygon(PackedVector2Array([at, at + out + side, at + out - side]),
		tint)


## One fern frond: a spine with leaflets either side, shortening toward the tip.
func _draw_frond(strand: Dictionary) -> void:
	var spread: float = lerpf(-FERN_SPREAD, FERN_SPREAD, float(strand["along"]))
	var own_phase: float = float(strand["phase"]) + phase
	var length: float = reach * float(strand["length"])
	var base_angle: float = -PI * 0.5 + spread * facing + float(strand["lean"]) * 0.5

	var spine := PackedVector2Array()
	var at: Vector2 = Vector2.ZERO
	var angle: float = base_angle
	var step_length: float = length / float(FERN_SEGMENTS)
	var leaflets: Array[Array] = []
	for segment: int in FERN_SEGMENTS:
		var up: float = float(segment) / float(FERN_SEGMENTS)
		var wind: float = sin(_time * 0.75 + own_phase + up * 1.6) * 0.6 \
			+ sin(_time * 0.4370 + own_phase * 0.77) * 0.4
		# A frond bends from the middle out: stiff at the crown, loose at the tip.
		angle += wind * sway * float(strand["sway"]) * up * up / float(FERN_SEGMENTS) * 5.0
		at += Vector2(cos(angle), sin(angle)) * step_length
		spine.append(at)
		if segment > 0:
			leaflets.append([at, angle, 1.0 - up])
	draw_polyline(spine, tint, maxf(reach * 0.012, 1.6), true)
	for row: Array in leaflets:
		var point: Vector2 = row[0]
		var facing_angle: float = row[1]
		var size: float = float(row[2]) * reach * 0.10
		var arm: Vector2 = Vector2(cos(facing_angle), sin(facing_angle)).orthogonal() * size
		draw_line(point, point + arm, tint, maxf(size * 0.34, 1.0), true)
		draw_line(point, point - arm, tint, maxf(size * 0.34, 1.0), true)


## How many hanging strands a branch carries, and how many fronds a fern has.
const VINE_STRANDS: int = 7
const FERN_FRONDS: int = 9
## Segments per strand. Enough that the curve reads as a curve; few enough that
## a corner is a few hundred points rather than a few thousand.
const VINE_SEGMENTS: int = 14
const FERN_SEGMENTS: int = 10
## How far along the branch reaches, as a multiple of `reach`.
const BRANCH_SPAN: float = 1.35
const BRANCH_POINTS: int = 10
## How wide a fern opens, in radians either side of straight up.
const FERN_SPREAD: float = 1.05
