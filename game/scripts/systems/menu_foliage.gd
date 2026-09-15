class_name MenuFoliage
extends Node2D

## Hanging vines and standing ferns for the main menu: painted leaves on a
## motion that never repeats.
##
## **Two owner briefs, and they are both satisfied rather than traded off.**
## The first (2026-09-14) asked for branches with hanging vines in the top
## corners and large ferns in the bottom, swaying, and explicitly *not* looping
## pixel-art animation, which reads as repetitive the moment the loop is seen.
## The second, later the same day, asked for real pixel-art sprites on them.
##
## So the *art* is authored and the *motion* is not. A strand is a chain of
## segments whose angle is the sum of two sines of incommensurable periods -
## their sum has no period, so the plant never returns to a pose a viewer can
## recognise - and the painted leaf is carried along that chain rather than
## played as frames. There is no loop to notice because there is no loop.
##
## **The art bends rather than swinging as a board.** Each strand is drawn as a
## short stack of textured bands, one per segment, each rotated to its own
## piece of the curve, so a frond curls and a vine hangs. Bands overlap
## slightly; at this size the seam is invisible and the alternative is a mesh.
##
## A missing texture costs nothing: the silhouettes this drew before are still
## here and still correct, and `painted()` is what chose between them. That is
## the art convention (CLAUDE.md SS4) doing its job - the menu is never blank
## because a file is late.
##
## One `_draw` for everything, a few dozen quads a corner rather than a node
## per leaf - the lesson `flame.gd` cost the project twice.

## Where the piece is rooted and which way it grows.
enum Kind { VINE, FERN }

## Which corner, as a fraction of the screen. Set by the menu.
var anchor: Vector2 = Vector2.ZERO
var kind: int = Kind.VINE
## Mirrors the whole piece, so the right-hand corner is not the left one again.
var facing: float = 1.0
## Silhouette colour, used for the woody parts and for the whole plant when
## the painted art is missing. The menu passes its own sky's darkest value.
var tint: Color = Color(0.04, 0.05, 0.05, 0.92)
## What the painted leaves are multiplied by. Foliage this close to a camera at
## dusk is *dark and slightly cool*, not its daylight colour, so the art is sat
## into the menu rather than pasted onto it - and the menu can push it further
## either way without a second set of assets.
var leaf_tint: Color = Color(0.46, 0.54, 0.44, 0.97)
## Overall size in pixels: a vine's length, a fern's frond reach.
var reach: float = 320.0
## How far the tip travels, in radians of accumulated lean.
var sway: float = 0.22
## Decorrelates two pieces built from the same numbers.
var phase: float = 0.0

## The painted pieces. Loaded once for every corner rather than per instance.
const LEAF_ART: String = "res://art/ui/menu_leaves.png"
const FROND_ART: String = "res://art/ui/menu_frond.png"
const TENDRIL_ART: String = "res://art/ui/menu_tendril.png"

static var _leaves: Texture2D = null
static var _frond: Texture2D = null
static var _tendril: Texture2D = null
static var _looked: bool = false

var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
## Per-strand: length scale, hang angle, sway scale, its own phase.
var _strands: Array[Dictionary] = []


func _ready() -> void:
	_rng.seed = hash("menu-foliage") ^ int(phase * 1024.0) ^ int(anchor.x * 977.0)
	_load_art()
	_grow()


## Once for the whole menu. A piece that is not on disk simply stays null and
## that strand falls back to its silhouette.
static func _load_art() -> void:
	if _looked:
		return
	_looked = true
	if ResourceLoader.exists(LEAF_ART):
		_leaves = load(LEAF_ART) as Texture2D
	if ResourceLoader.exists(FROND_ART):
		_frond = load(FROND_ART) as Texture2D
	if ResourceLoader.exists(TENDRIL_ART):
		_tendril = load(TENDRIL_ART) as Texture2D


## Whether this corner is drawing painted art rather than silhouettes. For the
## gate, which has no other way to tell the two apart from outside.
func painted() -> bool:
	return _leaves != null and _frond != null and _tendril != null


func _process(delta: float) -> void:
	advance(delta)


## Move the plant's clock on. **The gate's only way in**: headless runs no
## frames worth speaking of, and the claim being checked is about an hour of
## plant time rather than about any frame.
func advance(delta: float) -> void:
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
			# How big this strand's painted clusters are. One size on every
			# strand is what reads as a repeated sticker rather than a plant,
			# and it is the cheapest variation there is.
			"leaf_size": _rng.randf_range(0.78, 1.22),
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


## Where one hanging vine's segments are at this instant. Separate from the
## painting so `pose()` can read it without a canvas - headless draws nothing,
## and the non-looping motion is the one thing here worth gating.
func _vine_chain(strand: Dictionary) -> PackedVector2Array:
	var along: float = float(strand["along"])
	var root := Vector2(along * reach * BRANCH_SPAN * facing,
		along * along * reach * 0.16)
	var length: float = reach * float(strand["length"])
	var own_phase: float = float(strand["phase"]) + phase
	var own_sway: float = sway * float(strand["sway"])
	var points := PackedVector2Array()
	var angle: float = float(strand["lean"])
	var at: Vector2 = root
	var step_length: float = length / float(VINE_SEGMENTS)
	for segment: int in VINE_SEGMENTS:
		var down: float = float(segment) / float(VINE_SEGMENTS)
		# The lean accumulates down the strand, so the tip travels far and the
		# root barely moves - which is how a hanging thing actually behaves.
		angle += _wind_at(own_phase, down, VINE_WIND) * own_sway * down \
			/ float(VINE_SEGMENTS) * 6.0
		at += Vector2(sin(angle) * step_length, cos(angle) * step_length)
		points.append(at)
	return points


## Which of those segments carry leaves. A pure function of the strand's own
## dice, so it says the same thing whatever the wind is doing.
func _vine_leaf_steps(strand: Dictionary) -> PackedInt32Array:
	var steps := PackedInt32Array()
	var every: int = maxi(int(VINE_SEGMENTS / int(strand["leaves"])), 1)
	for segment: int in VINE_SEGMENTS:
		if segment > 1 and segment % every == 0:
			steps.append(segment)
	return steps


## One hanging vine, swaying more the further it is from the branch.
func _draw_vine(strand: Dictionary) -> void:
	var points: PackedVector2Array = _vine_chain(strand)
	var steps: PackedInt32Array = _vine_leaf_steps(strand)
	var leaves: Array[Vector2] = []
	for step: int in steps:
		leaves.append(points[step])
	if _tendril != null:
		# The woody line first, and **only where the painted vine is thin**.
		# Run along the whole chain it becomes a bare thread hanging below the
		# tendril's curl, because the art's ink stops short of its canvas -
		# five dark tails the picture showed at once. It joins the strand to
		# the branch and then gets out of the way.
		var joint := PackedVector2Array()
		for index: int in points.size():
			if float(index) / float(maxi(points.size() - 1, 1)) <= 0.34:
				joint.append(points[index])
		if joint.size() > 1:
			draw_polyline(joint, tint, maxf(reach * 0.006, 1.0), true)
		_draw_bent(points, _tendril, 1.0, false)
		# **Two clusters, never the same two.** One cluster at one depth on
		# every strand is a tiling pattern a viewer picks out in a second, so
		# the strand hangs its leaves at the points its own walk chose and at
		# its own size. `leaves` already varies with the strand's dice.
		if _leaves != null and leaves.size() > 0:
			var size: float = reach * 0.34 * float(strand["leaf_size"])
			var hung: int = 0
			for index: int in points.size():
				if hung >= 2 or index < 1 or index >= points.size() - 1:
					continue
				if not leaves.has(points[index]):
					continue
				var lean: Vector2 = points[index + 1] - points[index]
				_draw_sprite(points[index], _leaves,
					size * (1.0 - 0.18 * float(hung)),
					lean.angle() - PI * 0.5)
				hung += 1
		return
	draw_polyline(points, tint, maxf(reach * 0.010, 1.5), true)
	for step: int in steps:
		# Each leaf turns with its own piece of the strand. It used to take the
		# walk's *final* angle, which was an accident of where the loop ended.
		var lean: Vector2 = points[mini(step + 1, points.size() - 1)] - points[step]
		_draw_leaf(points[step], lean.angle() - PI * 0.5)


## A leaf, as a small triangle: three points beat a texture at this size.
func _draw_leaf(at: Vector2, angle: float) -> void:
	var out: Vector2 = Vector2(sin(angle + 1.2), cos(angle + 1.2)) * reach * 0.045
	var side: Vector2 = out.orthogonal() * 0.42
	draw_colored_polygon(PackedVector2Array([at, at + out + side, at + out - side]),
		tint)


## Where one frond's spine is at this instant. Same reason as `_vine_chain`.
func _fern_chain(strand: Dictionary) -> PackedVector2Array:
	var spread: float = lerpf(-FERN_SPREAD, FERN_SPREAD, float(strand["along"]))
	var own_phase: float = float(strand["phase"]) + phase
	var length: float = reach * float(strand["length"])
	var spine := PackedVector2Array()
	var at: Vector2 = Vector2.ZERO
	var angle: float = -PI * 0.5 + spread * facing + float(strand["lean"]) * 0.5
	var step_length: float = length / float(FERN_SEGMENTS)
	for segment: int in FERN_SEGMENTS:
		var up: float = float(segment) / float(FERN_SEGMENTS)
		# A frond bends from the middle out: stiff at the crown, loose at the tip.
		angle += _wind_at(own_phase, up, FERN_WIND) * sway * float(strand["sway"]) \
			* up * up / float(FERN_SEGMENTS) * 5.0
		at += Vector2(cos(angle), sin(angle)) * step_length
		spine.append(at)
	return spine


## One fern frond: a spine with leaflets either side, shortening toward the tip.
func _draw_frond(strand: Dictionary) -> void:
	var spread: float = lerpf(-FERN_SPREAD, FERN_SPREAD, float(strand["along"]))
	var own_phase: float = float(strand["phase"]) + phase
	var spine: PackedVector2Array = _fern_chain(strand)
	var leaflets: Array[Array] = []
	var angle: float = -PI * 0.5 + spread * facing + float(strand["lean"]) * 0.5
	for segment: int in spine.size():
		var up: float = float(segment) / float(FERN_SEGMENTS)
		angle += _wind_at(own_phase, up, FERN_WIND) * sway * float(strand["sway"]) \
			* up * up / float(FERN_SEGMENTS) * 5.0
		if segment > 0:
			leaflets.append([spine[segment], angle, 1.0 - up])
	if _frond != null:
		# **Drawn from the stem up, which is the way round it grows.**
		# `_draw_bent` lays a texture's *top* at the root of the chain, and the
		# frond is painted tip-up - so read in reverse, or the fern stands on
		# its point with a bare stalk in the air. It is exactly what the first
		# cut did, and the picture is the only thing that could have said so.
		_draw_bent(spine, _frond, 0.86, true)
		return
	draw_polyline(spine, tint, maxf(reach * 0.012, 1.6), true)
	for row: Array in leaflets:
		var point: Vector2 = row[0]
		var facing_angle: float = row[1]
		var size: float = float(row[2]) * reach * 0.10
		var arm: Vector2 = Vector2(cos(facing_angle), sin(facing_angle)).orthogonal() * size
		draw_line(point, point + arm, tint, maxf(size * 0.34, 1.0), true)
		draw_line(point, point - arm, tint, maxf(size * 0.34, 1.0), true)


## A texture laid along a polyline, one band per segment, each rotated to its
## own piece of the curve.
##
## **Bands rather than one rotated sprite**, because a hanging thing bends and
## a board does not: the whole point of the motion above is that the tip
## travels and the root barely moves, and a single quad throws that away. Each
## band is drawn about its own start point with `draw_set_transform`, which
## costs one matrix and no mesh. The bands overlap a little so the joins do not
## show as gaps where the curve is sharp.
##
## **The width is measured from the chain, never authored.** The first cut
## passed a width in and it was wrong on both plants: a vine came out three
## times taller than it was drawn and a fern two and a half, which turns
## painted leaves into smears and a flower into a pale streak - and the streak
## is what the picture showed. The width that keeps a sprite's own proportions
## is its length times its own aspect, so that is what this computes. `taper`
## is all the licence there is: the tip may be narrower than the root, and 1.0
## leaves the art exactly as drawn.
##
## `reverse` reads the source rows from the bottom up, for art painted growing
## the other way - a frond is drawn tip-up and a fern grows stem-first.
func _draw_bent(points: PackedVector2Array, texture: Texture2D,
		taper: float = 1.0, reverse: bool = false) -> void:
	if texture == null or points.size() < 2:
		return
	var bands: int = points.size() - 1
	var length: float = 0.0
	for index: int in bands:
		length += points[index].distance_to(points[index + 1])
	if length <= 0.01:
		return
	var wide: float = length * float(texture.get_width()) / float(texture.get_height())
	var source_height: float = float(texture.get_height()) / float(bands)
	for index: int in bands:
		var from: Vector2 = points[index]
		var to: Vector2 = points[index + 1]
		var along: Vector2 = to - from
		var span: float = along.length()
		if span <= 0.01:
			continue
		var middle: float = (float(index) + 0.5) / float(bands)
		var width: float = wide * lerpf(1.0, taper, middle)
		var row: int = (bands - 1 - index) if reverse else index
		# The band's own axis is *down* the polyline, so the texture's top is
		# at the root of the strand unless `reverse` says otherwise.
		draw_set_transform(from, along.angle() - PI * 0.5,
			Vector2(1.0, -1.0) if reverse else Vector2.ONE)
		draw_texture_rect_region(texture,
			Rect2(-width * 0.5, 0.0 if not reverse else -span * 1.06,
				width, span * 1.06),
			Rect2(0.0, float(row) * source_height,
				float(texture.get_width()), source_height),
			leaf_tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## One painted piece at a point, turned. `size` is its width in pixels.
func _draw_sprite(at: Vector2, texture: Texture2D, size: float, angle: float) -> void:
	if texture == null:
		return
	var height: float = size * float(texture.get_height()) / maxf(float(texture.get_width()), 1.0)
	draw_set_transform(at, angle, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-size * 0.5, 0.0, size, height), false, leaf_tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## **Two sines of incommensurable periods.** Their sum has no period, so a
## plant never returns to a pose a viewer can recognise - which is the whole
## reason none of this is a sprite animation, and it is the one property of
## this file a gate can hold from outside. `along` is how far down the strand
## the point is, so the tip travels and the root barely moves.
##
## **The second rate is the golden ratio times the first**, because the golden
## ratio is the hardest number there is to approximate with a fraction and a
## fraction is exactly what a loop is.
##
## It was written as the golden ratio *times 1.7*, and the comment beside it
## claimed the property the multiplication had thrown away: 0.618 x 1.7 is
## 1.0507, which is a fifteenth of a percent from 21/20, so the two sines came
## back into step about every 140 seconds. The code and its own comment
## disagreed and the comment was the honest one. **To be clear about what is
## and is not evidence here: `menu_foliage_check` passes at either value** -
## 140 seconds is inside its window but the drift over sixteen seconds is still
## under a pixel - so this is a constant corrected to match its stated
## intention, not a visible fault that was caught. Nothing in the expression
## should be scaled by anything.
const PHI: float = 1.6180339887


func _wind_at(own_phase: float, along: float, shape: Array[float]) -> float:
	return sin(_time * shape[0] + own_phase + along * shape[1]) * 0.62 \
		+ sin(_time * shape[0] * PHI + own_phase * 1.31 + along * shape[2]) * 0.38


## Where every strand's tip is at this instant.
##
## **For the gate**, which has no other way in: the whole design rests on the
## motion never repeating, and that is a claim about two poses far apart in
## time rather than about any one frame. Headless draws nothing, so a check
## that wanted to see the plant could only ever see the code.
func pose() -> PackedVector2Array:
	var tips := PackedVector2Array()
	for strand: Dictionary in _strands:
		var points: PackedVector2Array = _vine_chain(strand) if kind == Kind.VINE \
			else _fern_chain(strand)
		if points.size() > 0:
			tips.append(points[points.size() - 1])
	return tips


## How many hanging strands a branch carries, and how many fronds a fern has.
const VINE_STRANDS: int = 7
const FERN_FRONDS: int = 9
## Segments per strand. Enough that the curve reads as a curve; few enough that
## a corner is a few hundred points rather than a few thousand.
## The two wind rates and the two reaches down the strand, per plant.
const VINE_WIND: Array[float] = [0.9, 2.1, 3.3]
const FERN_WIND: Array[float] = [0.75, 1.6, 0.0]
const VINE_SEGMENTS: int = 14
const FERN_SEGMENTS: int = 10
## How far along the branch reaches, as a multiple of `reach`.
const BRANCH_SPAN: float = 1.35
const BRANCH_POINTS: int = 10
## How wide a fern opens, in radians either side of straight up.
const FERN_SPREAD: float = 1.05
