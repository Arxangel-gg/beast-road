class_name Hitbox
extends RefCounted

## **Where a body can be hit, and how far apart two bodies stand** (owner,
## 2026-10-01: *"Enemy hitboxes need to be elevated and polished, it currently
## sits just at their body origin or feet root for most enemies. Enemies also
## need to have hitbox targeting improved on players and wildlife as well and
## vice versa, as well as hitboxes on wildlife targeting wildlife"*).
##
## Two questions, and the fault was answering one with the other.
##
## - **How far apart two bodies stand** is a question about the ground: feet to
##   feet. An enemy measured its reach from its own chest to its target's feet,
##   so a body standing south of the Warden could swing from far off and one
##   standing north had to all but stand on them - the same gap in two
##   directions, two different answers, and the taller the body the worse.
## - **Whether a blow or a shot meets a body** is a question about the picture:
##   the body stands up out of the ground, so it can be met anywhere from its
##   feet to its upper chest. That is a *stroke* - a short upright line from the
##   feet to `HITBOX_STROKE_SHARE` of the way past the body's centre - and a
##   blow meets the body when it comes within the body's radius of that line.
##   A swing aimed at a chest, an arrow at a torso and a tower's shot at the
##   middle of a giant all land where they were drawn landing.
##
## One class so the two questions are asked the same way by everything that
## asks them: the Warden's swing, a tower's shot, the Arsenal, a hostile shot, a
## body's own reach, and an animal's.

## The ground under a thing - where it stands.
static func feet_of(node: Node2D) -> Vector2:
	if node == null or not is_instance_valid(node):
		return Vector2.ZERO
	return node.global_position


## The middle of a thing's body as it is drawn: a body's or a Warden's own
## `combat_origin`, a tower's origin, an animal's painted centre.
static func body_of(node: Node2D) -> Vector2:
	if node == null or not is_instance_valid(node):
		return Vector2.ZERO
	if node.has_method("combat_origin"):
		var origin: Variant = node.call("combat_origin")
		if origin is Vector2:
			return origin as Vector2
	var tower := node as Tower
	if tower != null:
		return tower.origin()
	var sprite := node as Sprite2D
	if sprite != null:
		return sprite.global_position + Vector2(sprite.offset.x * sprite.scale.x,
			sprite.offset.y * sprite.scale.y)
	return node.global_position


## The top of the stroke a blow can meet: from the feet, past the body's
## centre to the upper chest.
static func top_of(node: Node2D) -> Vector2:
	var feet: Vector2 = feet_of(node)
	return feet + (body_of(node) - feet) * Balance.HITBOX_STROKE_SHARE


## The point of a body's stroke nearest `point` - where a blow from there meets
## it, and the bearing a swing arc is judged by.
static func meet(node: Node2D, point: Vector2) -> Vector2:
	return Geometry2D.get_closest_point_to_segment(point, feet_of(node), top_of(node))


## How far `point` is from meeting the body (its stroke, before its radius).
static func gap(node: Node2D, point: Vector2) -> float:
	return meet(node, point).distance_to(point)


## How far apart two things stand on the ground, feet to feet.
static func ground_gap(one: Node2D, other: Node2D) -> float:
	return feet_of(one).distance_to(feet_of(other))
