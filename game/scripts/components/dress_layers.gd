class_name DressLayers
extends Node2D

## The parts of a dressed Warden drawn over and under the body (the modular
## Warden, 2026-09-25): the cape, the weapon in the right fist, the second of a
## pair in the left.
##
## **Two holders, both children of the hero's sprite, on purpose.** This node is
## the one drawn *over* the body, and `behind` is its sibling with
## `show_behind_parent`, drawn *under* it. That flag only ever orders a node
## against its own parent: a part flagged behind one level further down - under
## this node - is still drawn after the sprite, over the body, which is where
## the first cut put the back of the cape and every weapon "behind" the chest.
## `dress_check` walks each part up to the sprite and asks the holder it hangs
## from, because a flag on the part itself says nothing about the picture.
##
## A child of the sprite inherits everything `SpriteAnimator` does to it - the
## bounce, the lean, the squash, the recoil - so the cape and the sword move
## with the body through all of it without either system knowing the other
## exists.
##
## **The fist closes over the handle** (owner, 2026-09-25: *"make sure the part
## of the hand that grips the weapon gets zsorted over the blade"*). A weapon in
## front of the body is cut along its own picture: the stretch of handle under
## each gripping fist - a fist's width, never past the hilt - is drawn behind
## the body, so the painted fingers cover the handle they hold; the guard, the
## blade and the pommel are drawn in front. `grip_bands` is the rule, and
## `tools/warden_rig/compose.py` is the same rule for the pictures a pilot is
## judged on. A weapon behind the body is drawn whole behind it, where the fist
## covers it anyway.
##
## **Placed, never animated here.** `HeroAnimator` decides the state, frame and
## facing; this reads the socket table `tools/warden_rig/pack.py` wrote for that
## frame - each hand moved onto the fist the body actually drew - and lays each
## part on it. A frame with no socket shows no weapon rather than a weapon in
## the wrong place.

## Facings that show the Warden's back, by HeroAnimator row: a cape is drawn
## over the body on these and under it on the rest.
const BACK_ROWS: Array[int] = [5, 6, 7]
## A weapon is cut into at most this many bands behind the body - one per fist
## on it - and so at most one more stretch in front.
const MAX_BANDS: int = 2

## The holder drawn under the body. Made by `attach`, beside this node.
var behind: Node2D

var _cape_back: Sprite2D
var _cape_front: Sprite2D
## Per hand (0 the weapon in the right fist, 1 the second of a pair in the
## left): the pieces drawn over the body and the pieces drawn under it.
var _over: Array = [[], []]
var _under: Array = [[], []]
var _outfit: Dictionary = {}
var _cape_sheets: Dictionary = {}
var _texture: Texture2D = null
var _grip: Vector2 = Vector2.ZERO
var _tip: float = 0.0
var _hilt: Vector2 = Vector2.ZERO


## The one way to dress a sprite: both holders, under and over, as its own
## children.
static func attach(sprite: Node2D) -> DressLayers:
	var under := Node2D.new()
	under.name = "DressBehind"
	under.show_behind_parent = true
	sprite.add_child(under)
	var layers := DressLayers.new()
	layers.name = "Dress"
	layers.behind = under
	sprite.add_child(layers)
	return layers


func _ready() -> void:
	if behind == null:
		# Never reached through `attach`; a node made by hand still draws its
		# under-layer where one belongs rather than nowhere.
		behind = Node2D.new()
		behind.name = "DressBehind"
		behind.show_behind_parent = true
		get_parent().add_child.call_deferred(behind)
	# Added in drawing order: the cape first, then the weapon over it.
	_cape_back = _part(behind, "CapeBack")
	_cape_front = _part(self, "CapeFront")
	for part: Sprite2D in [_cape_back, _cape_front]:
		part.region_enabled = true
	for hand: int in 2:
		for i: int in MAX_BANDS + 1:
			(_over[hand] as Array).append(_piece(self, "Weapon%d_%d" % [hand, i]))
		for i: int in MAX_BANDS:
			(_under[hand] as Array).append(_piece(behind, "WeaponBehind%d_%d" % [hand, i]))


## The under-holder goes when this does. On deletion rather than on leaving the
## tree: a hero taken out of the tree and put back must come back dressed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(behind) and not behind.is_queued_for_deletion():
		behind.queue_free()


func _part(holder: Node, node_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.centered = false
	sprite.visible = false
	holder.add_child(sprite)
	return sprite


func _piece(holder: Node, node_name: String) -> Sprite2D:
	var sprite: Sprite2D = _part(holder, node_name)
	sprite.region_enabled = true
	# The pieces of one weapon meet along a row; clipped to its own region a
	# piece never samples its neighbour's pixels, so the joint cannot show.
	sprite.region_filter_clip_enabled = true
	return sprite


## Show or hide everything the dress draws - both holders.
func set_worn(on: bool) -> void:
	visible = on
	if is_instance_valid(behind):
		behind.visible = on


## Dress in an outfit from `WardenDress.outfit`.
func wear(outfit: Dictionary) -> void:
	_outfit = outfit
	_cape_sheets.clear()
	var held: String = String(outfit.get("held", ""))
	var grip: Dictionary = outfit.get("held_grip", {})
	_texture = WardenDress.texture(held) if not held.is_empty() else null
	if _texture != null and not grip.is_empty():
		_grip = grip["grip"]
		_tip = float(grip["tip"])
		_hilt = grip.get("hilt", Vector2(_grip.y, _grip.y))
	else:
		_texture = null
	for hand: int in 2:
		_hide_hand(hand)
	var tint: Color = outfit.get("cape_tint", Color(1, 1, 1, 0))
	for part: Sprite2D in [_cape_back, _cape_front]:
		part.self_modulate = Color(tint.r, tint.g, tint.b, 1.0) if tint.a > 0.0 else Color.WHITE
		part.visible = false


## Lay every part on one frame. `offset` is where the body's cell was drawn,
## in the sprite's own coordinates; the socket table is in the cell's pixels.
func show_frame(state: String, frame: int, row: int, offset: Vector2, meta: Dictionary) -> void:
	var cell: Array = meta.get("cell", [0, 0])
	var region := Rect2(float(frame * int(cell[0])), float(row * int(cell[1])),
		float(cell[0]), float(cell[1]))
	_show_cape(state, region, row, offset)
	var rows: Dictionary = meta.get("sockets", {})
	var facing: String = HeroAnimator.FACING_NAMES[row] if row < HeroAnimator.FACING_NAMES.size() else ""
	var table: Array = rows.get(facing, [])
	if frame >= table.size() or _texture == null:
		_hide_hand(0)
		_hide_hand(1)
		return
	var socket: Array = table[frame]
	var stature: float = float(meta.get("stature", 150.0))
	var length: float = float(_outfit.get("held_length", 0.42)) * stature
	# Half a fist, in the cell's pixels. A table written before fists were
	# measured carries none, and its weapons are drawn whole, as they were.
	var fist: float = float(meta.get("fist", 0.0))
	var grip: int = int(_outfit.get("grip", 0))
	var left: Array = [socket[5], socket[6], socket[9]] if grip == GearData.Grip.TWO_HAND else []
	_lay(0, socket, 0, offset, length, fist, left)
	if grip == GearData.Grip.PAIRED:
		_lay(1, socket, 5, offset, length, fist, [])
	else:
		_hide_hand(1)


## One weapon on one hand's socket - [x, y, angle, reach, front] from `start` -
## cut so the handle under each gripping fist is drawn under the body. `left`
## is the other fist on the same haft, [x, y, front], or empty.
func _lay(hand: int, socket: Array, start: int, offset: Vector2, length: float, fist: float,
		left: Array) -> void:
	var tip_len: float = maxf(_grip.y - _tip, 1.0)
	var across: float = length / tip_len
	var along: float = across * maxf(float(socket[start + 3]), 0.08)
	var at := Vector2(float(socket[start]), float(socket[start + 1]))
	var angle: float = deg_to_rad(float(socket[start + 2]))
	var height: int = _texture.get_height()
	var bands: Array[Vector2i] = []
	if int(socket[start + 4]) == 1:
		var holds: Array[float] = [_grip.y]
		if not left.is_empty() and int(left[2]) == 1:
			# The other fist's row on the haft: how far it is from this one
			# along the blade, in the picture's rows.
			var apart: Vector2 = Vector2(float(left[0]), float(left[1])) - at
			holds.append(_grip.y - apart.dot(Vector2.from_angle(angle)) / along)
		bands = grip_bands(_hilt, fist, along, holds)
	else:
		# The whole weapon is behind the body: one band, all of it.
		bands = [Vector2i(0, height)]
	var over: Array = _over[hand]
	var under: Array = _under[hand]
	var used_over: int = 0
	var used_under: int = 0
	for piece: Dictionary in pieces(height, bands):
		var rows: Vector2i = piece["rows"]
		var part: Sprite2D
		if bool(piece["behind"]):
			part = under[used_under]
			used_under += 1
		else:
			part = over[used_over]
			used_over += 1
		part.texture = _texture
		part.region_rect = Rect2(0.0, float(rows.x), float(_texture.get_width()), float(rows.y - rows.x))
		# The picture is laid with its grip on the node, so turning the node
		# turns the weapon about the fist; a piece starting lower in the
		# picture starts lower under the node.
		part.offset = Vector2(-_grip.x, float(rows.x) - _grip.y)
		part.position = offset + at
		# The picture points up its own -y; the socket's angle is on screen.
		part.rotation = angle + PI * 0.5
		part.scale = Vector2(across, along)
		part.visible = true
	for i: int in range(used_over, over.size()):
		(over[i] as Sprite2D).visible = false
	for i: int in range(used_under, under.size()):
		(under[i] as Sprite2D).visible = false


func _hide_hand(hand: int) -> void:
	for part: Sprite2D in (_over[hand] as Array) + (_under[hand] as Array):
		part.visible = false


## The rows of a weapon's picture drawn under the body: a fist's width of handle
## round each gripping fist's row, clipped to the hilt, as [start, end) spans,
## merged where two fists overlap. `fist` and `along` are in the cell's pixels
## (half a fist, and how many of them one row of the picture covers).
static func grip_bands(hilt: Vector2, fist: float, along: float, holds: Array[float]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if fist <= 0.0 or holds.is_empty():
		return out
	var half: float = fist / maxf(along, 0.000001)
	var spans: Array[Vector2i] = []
	for row: float in holds:
		var a: int = floori(maxf(row - half, hilt.x))
		var b: int = ceili(minf(row + half, hilt.y + 1.0))
		if b > a:
			spans.append(Vector2i(a, b))
	spans.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return p.x < q.x)
	for span: Vector2i in spans:
		if not out.is_empty() and span.x <= out[-1].y:
			out[-1] = Vector2i(out[-1].x, maxi(out[-1].y, span.y))
		else:
			out.append(span)
	return out


## A picture `height` rows tall cut at `bands`: every row exactly once, in
## order, each piece marked for under the body or over it.
static func pieces(height: int, bands: Array[Vector2i]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at: int = 0
	for band: Vector2i in bands:
		var a: int = clampi(band.x, 0, height)
		var b: int = clampi(band.y, 0, height)
		if a > at:
			out.append({"rows": Vector2i(at, a), "behind": false})
		if b > a:
			out.append({"rows": Vector2i(a, b), "behind": true})
		at = maxi(at, b)
	if at < height:
		out.append({"rows": Vector2i(at, height), "behind": false})
	return out


## What one hand's weapon is drawn as this frame: its visible pieces, top of
## the picture first. For `dress_check`, which asks each piece where it hangs.
func drawn(hand: int) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for part: Sprite2D in (_over[hand] as Array) + (_under[hand] as Array):
		if part.visible:
			out.append(part)
	out.sort_custom(func(p: Sprite2D, q: Sprite2D) -> bool: return p.region_rect.position.y < q.region_rect.position.y)
	return out


func cape_back() -> Sprite2D:
	return _cape_back


func cape_front() -> Sprite2D:
	return _cape_front


func _show_cape(state: String, region: Rect2, row: int, offset: Vector2) -> void:
	var layer: String = String(_outfit.get("cape_layer", ""))
	if layer.is_empty():
		_cape_back.visible = false
		_cape_front.visible = false
		return
	if not _cape_sheets.has(state):
		_cape_sheets[state] = WardenDress.texture(WardenDress.art_root + layer + "/" + state + ".png")
	var sheet: Texture2D = _cape_sheets[state]
	var front: bool = BACK_ROWS.has(row)
	var shown: Sprite2D = _cape_front if front else _cape_back
	var hidden: Sprite2D = _cape_back if front else _cape_front
	hidden.visible = false
	shown.visible = sheet != null
	if sheet != null:
		shown.texture = sheet
		shown.region_rect = region
		shown.offset = offset
