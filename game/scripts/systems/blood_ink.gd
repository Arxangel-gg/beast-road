class_name BloodInk
extends RefCounted

## **How blood is actually painted.** Static only; nothing holds one of these.
##
## Both blood canvases used to draw with `draw_circle`, which gives a perfectly
## round shape in one flat colour - and one colour for the whole shape *is* a
## hard edge, the same finding the swim sheen and the menu campfire each paid
## for. A pool of blood has neither property: it is lobed rather than circular,
## and it thins toward its rim instead of stopping at it.
##
## So a blob is built here as a fan: one opaque vertex at the middle, a ring of
## vertices at the edge carrying the same colour at zero alpha, and a second ring
## between them holding most of the colour - which is what puts the falloff
## inside the shape rather than at its boundary. The outline is pushed in and out
## by a hash of the blob's own seed, so the same blob is the same shape every
## frame and no two blobs are the same shape as each other.
##
## **It appends into caller-owned arrays rather than drawing.** A busy wave puts
## down hundreds of marks, and a draw call each is what the one-node design of
## `BloodField` exists to avoid; the caller gathers every blob it owns and hands
## the lot to one `canvas_item_add_triangle_array`.

## Vertices around a blob's rim. Eight is enough for a lobed outline at the size
## blood is drawn and cheap enough to spend on hundreds of them; the shape reads
## from the wobble rather than from the vertex count.
const RIM: int = 8

## Where the colour is still at full strength, as a share of the radius. Inside
## this the blob is solid; outside it fades to nothing at the rim.
##
## **Photographed, not guessed.** At 0.52 the first cut read as a thin wisp
## rather than a pool: a feathered blob carries only 0.58 of the colour a flat
## disc of the same radius does, so replacing the discs quietly took two fifths
## of the ink out of every mark on the field. 0.66 carries 0.68 of it, and
## `BLOOD_GROUND_ALPHA` pays the rest back deliberately rather than by accident.
const CORE_SHARE: float = 0.66

## How far the outline is pushed in and out, as a share of the radius. Enough to
## stop it reading as a circle, not so much that a blob reads as a star.
const WOBBLE: float = 0.30

## The most a blob may ever be drawn out along its own motion, as a multiple of
## its width.
##
## **The cap belongs here rather than at each caller**, because the failure is
## the same wherever the stretch comes from: past about three times its width a
## blob stops reading as a drop of something and starts reading as a slash, and
## the first cut of the airborne motes came out as claw marks across the screen.
## A caller may hand over any velocity it likes and still get blood back.
const MAX_LONG: float = 2.2


## Appends one soft, lobed blob.
##
## `stretch` is the blob's own long axis - pass `Vector2.ZERO` for a round pool,
## or the motion of a droplet in flight, whose length is then how far it is drawn
## out along it. A mote thrown hard is a streak; the same mote about to land is
## nearly a bead, and stretching by velocity is what makes that difference the
## same number rather than two authored shapes.
static func blob(points: PackedVector2Array, colours: PackedColorArray,
		indices: PackedInt32Array, at: Vector2, radius: float, tone: Color,
		seed_value: float, stretch: Vector2 = Vector2.ZERO) -> void:
	if radius <= 0.01 or tone.a <= 0.004:
		return
	var first: int = points.size()
	var along: Vector2 = Vector2.RIGHT
	var long: float = 1.0
	if stretch.length_squared() > 0.0001:
		along = stretch.normalized()
		long = minf(1.0 + stretch.length() / maxf(radius, 0.01), MAX_LONG)
	var across: Vector2 = Vector2(-along.y, along.x)
	# The middle, at full strength.
	points.append(at)
	colours.append(tone)
	var middle := Color(tone.r, tone.g, tone.b, tone.a * 0.86)
	var edge := Color(tone.r, tone.g, tone.b, 0.0)
	for step: int in RIM:
		var angle: float = TAU * float(step) / float(RIM)
		# Stable per blob and per vertex: the same blob keeps its shape for its
		# whole life, so a mark does not shimmer while it dries.
		var wobble: float = 1.0 + (_hash(seed_value + float(step) * 7.31) - 0.5) \
			* 2.0 * WOBBLE
		var unit: Vector2 = along * cos(angle) * long + across * sin(angle)
		points.append(at + unit * radius * CORE_SHARE * wobble)
		colours.append(middle)
		points.append(at + unit * radius * wobble)
		colours.append(edge)
	for step: int in RIM:
		var here: int = first + 1 + step * 2
		var next: int = first + 1 + ((step + 1) % RIM) * 2
		# The solid disc out to the core ring.
		indices.append_array([first, here, next])
		# The feathered band from there to the rim.
		indices.append_array([here, here + 1, next + 1])
		indices.append_array([here, next + 1, next])


## Hands the gathered blobs to the canvas as one draw call. Does nothing on an
## empty set, so a caller need not test before calling.
static func paint(canvas: CanvasItem, points: PackedVector2Array,
		colours: PackedColorArray, indices: PackedInt32Array) -> void:
	if points.is_empty() or indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),
		indices, points, colours)


static func _hash(value: float) -> float:
	return fposmod(sin(value * 127.1) * 43758.5453123, 1.0)
