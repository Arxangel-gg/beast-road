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
##   the body stands up out of the ground, so it can be met anywhere on it.
##
## **The picture is the hitbox** (owner, 2026-10-07: *"Act bosses are
## untargettable as the player goes to try to only hit the target between their
## legs and doesn't attack it there either"*). The first cut of the second
## question was a thin upright line from the feet to the chest with the body's
## *ground* radius round it - right for a Warden-sized body and wrong for a
## giant: a boss three hundred units tall and two hundred wide was a stick down
## its own middle, so a click on its torso was a click on the ground and the
## Warden walked into the space between its legs. A body is now a capsule: a
## spine from its feet to the crown of its own painting - the opaque bounds of
## the base painting, measured once - as wide as a share of what is painted.
##
## **And the capsule has zones**: legs, torso and a head that is a weak point.
## Where a blow meets the spine decides which, by the share of the painted
## height it lands at; the Warden's blows and the blows on the Warden read them
## (`zone_scale`, `roll_crit`). Tower shots and areas do not, so the numbers the
## curve is tuned against do not move.
##
## One class so the questions are asked the same way by everything that asks
## them: the Warden's swing, a tower's shot, the Arsenal, a hostile shot, a
## body's own reach, a click, and an animal's.

enum Zone { LEGS, TORSO, HEAD }

## A base painting's opaque bounds as a share of the canvas, by path. Values,
## never objects, so the static outlives nothing (2026-10-01).
static var _paint: Dictionary = {}


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


## **The opaque bounds of a painting, as a share of its canvas.** Read off the
## image once and kept; a painting nobody can read is taken as most of its
## canvas, which is what a body nearly always is.
static func paint_share(path: String) -> Rect2:
	if path.is_empty():
		return Balance.HITBOX_PAINT_DEFAULT
	if _paint.has(path):
		return _paint[path] as Rect2
	var share: Rect2 = Balance.HITBOX_PAINT_DEFAULT
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	var image: Image = texture.get_image() if texture != null else null
	if image != null and not image.is_empty():
		var used: Rect2i = image.get_used_rect()
		var size := Vector2(float(image.get_width()), float(image.get_height()))
		if used.size.x > 0 and used.size.y > 0:
			share = Rect2(Vector2(used.position) / size, Vector2(used.size) / size)
	_paint[path] = share
	return share


## **The painting a body is measured off**: a road body's base painting, an
## animal's (named on its sprite when it is placed), or the texture it wears.
static func _paint_path(node: Node2D) -> String:
	var enemy := node as Enemy
	if enemy != null:
		return enemy.data.get_sprite_path() if enemy.data != null else ""
	if node.has_meta(&"hitbox_paint"):
		return String(node.get_meta(&"hitbox_paint"))
	var sprite := node as Sprite2D
	if sprite != null and sprite.texture != null:
		return sprite.texture.resource_path
	return ""


## The sprite a body is drawn with, when it has one whose picture is the body.
static func _sprite_of(node: Node2D) -> Sprite2D:
	var enemy := node as Enemy
	if enemy != null:
		return enemy.sprite
	return node as Sprite2D


## **The painted body in the world**: the opaque bounds of its painting under
## the sprite's own transform and flip. Empty for a thing with no painting.
static func painted_rect(node: Node2D) -> Rect2:
	var sprite: Sprite2D = _sprite_of(node)
	if sprite == null or not is_instance_valid(sprite) or sprite.texture == null:
		return Rect2()
	var share: Rect2 = paint_share(_paint_path(node))
	var local: Rect2 = sprite.get_rect()
	var x: float = local.position.x + share.position.x * local.size.x
	if sprite.flip_h:
		x = local.position.x + (1.0 - share.position.x - share.size.x) * local.size.x
	var opaque := Rect2(Vector2(x, local.position.y + share.position.y * local.size.y),
		Vector2(share.size.x * local.size.x, share.size.y * local.size.y))
	var into: Transform2D = sprite.global_transform
	var a: Vector2 = into * opaque.position
	var b: Vector2 = into * opaque.end
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


## **The spine a blow meets**: from the feet to the crown. A body or an animal
## reads its crown off its painting; a Warden off their own chest, since a
## dressed body is a sheet of cells rather than one painting; anything else is
## the old stroke, feet through the middle to the upper chest.
static func spine_of(node: Node2D) -> PackedVector2Array:
	var feet: Vector2 = feet_of(node)
	if node == null or not is_instance_valid(node):
		return PackedVector2Array([feet, feet])
	if node is Hero:
		var chest: Vector2 = body_of(node)
		return PackedVector2Array([feet, feet + (chest - feet) * Balance.HITBOX_WARDEN_CROWN])
	var painted: Rect2 = painted_rect(node)
	if painted.size.y > 1.0:
		var crown: float = painted.position.y + painted.size.y * Balance.HITBOX_CROWN_INSET
		# The spine stands over the feet; the width covers a painting that is
		# not centred on them.
		return PackedVector2Array([feet, Vector2(feet.x, minf(crown, feet.y))])
	return PackedVector2Array([feet, top_of_stroke(node)])


## The old stroke's top, for a thing with no painting to read.
static func top_of_stroke(node: Node2D) -> Vector2:
	var feet: Vector2 = feet_of(node)
	return feet + (body_of(node) - feet) * Balance.HITBOX_STROKE_SHARE


## The top of the spine - the crown of the painting, or the upper chest.
static func top_of(node: Node2D) -> Vector2:
	return spine_of(node)[1]


## **How wide a body stands to a blow**: a share of its painted width, never
## narrower than its own footing. A Warden is a Warden's width.
static func hit_radius(node: Node2D) -> float:
	if node == null or not is_instance_valid(node):
		return 0.0
	if node is Hero:
		return Balance.HITBOX_WARDEN_RADIUS
	var footing: float = Balance.ENEMY_BODY_RADIUS
	if node.has_method("contact_radius"):
		footing = float(node.call("contact_radius"))
	var painted: Rect2 = painted_rect(node)
	if painted.size.x > 1.0:
		return maxf(painted.size.x * Balance.HITBOX_WIDTH_SHARE,
			footing * Balance.HITBOX_FOOTING_FLOOR)
	return footing


## The point of a body's spine nearest `point` - where a blow from there meets
## it, and the bearing a swing arc is judged by.
static func meet(node: Node2D, point: Vector2) -> Vector2:
	var spine: PackedVector2Array = spine_of(node)
	return Geometry2D.get_closest_point_to_segment(point, spine[0], spine[1])


## How far `point` is from the body's spine (before its width).
static func gap(node: Node2D, point: Vector2) -> float:
	return meet(node, point).distance_to(point)


## **How far `point` is from the body itself**: the spine less the body's width,
## and nothing at all from inside it. What a reach, a click and a bolt ask.
static func reach_gap(node: Node2D, point: Vector2) -> float:
	return maxf(gap(node, point) - hit_radius(node), 0.0)


## How far apart two things stand on the ground, feet to feet.
static func ground_gap(one: Node2D, other: Node2D) -> float:
	return feet_of(one).distance_to(feet_of(other))


## **Where a blow thrown from `origin` along `aim` for `reach` meets the body**:
## the point of the spine nearest the blow's line. A swing aimed up at a head
## meets the head; one aimed at the knees meets the knees.
static func struck_point(node: Node2D, origin: Vector2, aim: Vector2, reach: float) -> Vector2:
	var spine: PackedVector2Array = spine_of(node)
	if aim.length_squared() < 0.0001:
		return Geometry2D.get_closest_point_to_segment(origin, spine[0], spine[1])
	var end: Vector2 = origin + aim.normalized() * maxf(reach, 1.0)
	var pair: PackedVector2Array = Geometry2D.get_closest_points_between_segments(
		origin, end, spine[0], spine[1])
	return pair[1]


## How far up the body a point is, from 0 at the feet to 1 at the crown.
static func height_share(node: Node2D, point: Vector2) -> float:
	var spine: PackedVector2Array = spine_of(node)
	var tall: float = spine[0].y - spine[1].y
	if tall < 1.0:
		return 0.5
	return clampf((spine[0].y - point.y) / tall, 0.0, 1.0)


## **Which part of the body a point is on.**
static func zone_at(node: Node2D, point: Vector2) -> int:
	var share: float = height_share(node, point)
	if share < Balance.HITBOX_ZONE_LEGS_TOP:
		return Zone.LEGS
	if share >= Balance.HITBOX_ZONE_HEAD_FROM:
		return Zone.HEAD
	return Zone.TORSO


## What a blow on a zone is worth, before any crit: a Warden's own table when
## the body struck is a Warden, the roster's otherwise.
static func zone_scale(node: Node2D, zone: int) -> float:
	var table: Array[float] = Balance.HITBOX_WARDEN_ZONE_DAMAGE if node is Hero \
		else Balance.HITBOX_ZONE_DAMAGE
	return table[clampi(zone, 0, table.size() - 1)]


## Off only in a gate that measures one blow's exact size against another's -
## a ratio a critical would move. Nothing in the game writes it.
static var zone_crits: bool = true


## **Whether a blow on a zone is a critical**, on the dice it is handed.
static func roll_crit(zone: int, rng: RandomNumberGenerator) -> bool:
	if not zone_crits:
		return false
	var chance: float = Balance.HITBOX_ZONE_CRIT[clampi(zone, 0, Balance.HITBOX_ZONE_CRIT.size() - 1)]
	return chance > 0.0 and rng != null and rng.randf() < chance


## **The point a body aims a blow at on a target** - the nearest point of the
## target's spine to the body's own shoulder, or its head when it means to.
## A blow is thrown from the shoulder, so a body the Warden's height strikes
## their chest and one twice it strikes down on the head.
## A giant's blow falls on a Warden's head and a rat's on their shins; a body
## that hunts weak points sometimes reaches up for the head on purpose.
static func aim_point(attacker: Node2D, target: Node2D, for_the_head: bool) -> Vector2:
	if for_the_head:
		var spine: PackedVector2Array = spine_of(target)
		return spine[0].lerp(spine[1], Balance.HITBOX_HEAD_AIM_SHARE)
	return meet(target, shoulder_of(attacker))


## Where a body's blows are thrown from: a share up its spine.
static func shoulder_of(node: Node2D) -> Vector2:
	var spine: PackedVector2Array = spine_of(node)
	return spine[0].lerp(spine[1], Balance.HITBOX_SHOULDER_SHARE)
