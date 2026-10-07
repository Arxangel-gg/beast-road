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
## **The head is socketed too** (owner, 2026-09-26: *"8 hairstyles, beards
## yes, code sway, one face"*). A hairstyle and a beard are one picture a
## facing, laid on the head point the socket table gives every frame and chosen
## by the view the head shows, coloured by `hair_tint.gdshader`. The beard is
## drawn first and the hair over it, both over the cape and under the weapon:
## a blade swung across the face is in front of the face. The hair leans about
## the head point as the Warden moves, on a spring driven by this node's own
## travel, so nothing else has to tell it the Warden moved.
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
const HAIR_SHADER_PATH: String = "res://scripts/shaders/hair_tint.gdshader"
## Where the head point is in the socket row: x, y, and the view's facing index.
const HEAD_SOCKET: int = 10

## The holder drawn under the body. Made by `attach`, beside this node.
var behind: Node2D

var _cape_back: Sprite2D
## A cape kind that names no colour of its own is plain undyed wool.
const CAPE_PLAIN: Color = Color8(118, 104, 86)
var _cape_front: Sprite2D
var _built: bool = false
var _beard: Sprite2D
var _hair: Sprite2D
var _hair_sway: float = 0.0
## The lean the hair is at, radians, and how fast it is changing.
var _sway: float = 0.0
var _sway_speed: float = 0.0
var _last_at: Vector2 = Vector2.INF
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
## **A shield in the left fist** (2026-10-07): over the body when that fist is
## in front of it, under it when it is behind.
var _shield_over: Sprite2D
var _shield_under: Sprite2D
var _shield_texture: Texture2D = null


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
	_build_parts()


## **The parts are made on first need**, from `_ready` or from `wear`, and
## once. The co-op lobby's `WardenStage` dresses a Warden before the stage has
## entered the tree, so `wear` ran against a cape that did not exist yet - seven
## script errors a session, for as long as the lobby had drawn partners.
func _build_parts() -> void:
	if _built:
		return
	_built = true
	if behind == null:
		# Never reached through `attach`; a node made by hand still draws its
		# under-layer where one belongs rather than nowhere.
		behind = Node2D.new()
		behind.name = "DressBehind"
		behind.show_behind_parent = true
		if get_parent() != null:
			get_parent().add_child.call_deferred(behind)
	# Added in drawing order: the cape first, then the weapon over it.
	_cape_back = _part(behind, "CapeBack")
	_cape_front = _part(self, "CapeFront")
	for part: Sprite2D in [_cape_back, _cape_front]:
		part.region_enabled = true
		# The cape is packed keyed to a grey shade (`pack.cape_key`) and coloured
		# here through the hair's own gradient map, so its folds keep their light
		# and dark in whatever colour the cape kind is - a multiply on grey would
		# only ever darken it (2026-09-26).
		if ResourceLoader.exists(HAIR_SHADER_PATH):
			var tint := ShaderMaterial.new()
			tint.shader = load(HAIR_SHADER_PATH) as Shader
			part.material = tint
	# Over the cape, under the weapon; the beard first so the hair meets it.
	_beard = _head_part("Beard")
	_hair = _head_part("Hair")
	for hand: int in 2:
		for i: int in MAX_BANDS + 1:
			(_over[hand] as Array).append(_piece(self, "Weapon%d_%d" % [hand, i]))
		for i: int in MAX_BANDS:
			(_under[hand] as Array).append(_piece(behind, "WeaponBehind%d_%d" % [hand, i]))
	_shield_over = _part(self, "Shield")
	_shield_under = _part(behind, "ShieldBehind")
	for part: Sprite2D in [_shield_over, _shield_under]:
		part.centered = true


## **A legendary weapon gleams in the hand** (owner, 2026-10-07). Every strip
## of the held picture wears one gleam, so the sheen sweeps the weapon as one
## picture; and the tip sheds motes in the rarity's colour (`_shed`). A
## weapon below the first legendary rung wears nothing.
var _gleam: ShaderMaterial = null
var _gleam_rarity: int = -1
var _shed_debt: float = 0.0
## Its own dice: a decoration never draws on a stream anything else rolls.
var _shed_dice := RandomNumberGenerator.new()


func _gleam_held(rarity: int, held: String) -> void:
	_gleam_rarity = rarity
	_gleam = LegendaryGleam.material_for(rarity, held) if not held.is_empty() else null
	for hand: int in 2:
		for part: Sprite2D in (_over[hand] as Array) + (_under[hand] as Array):
			part.material = _gleam
			if _gleam != null:
				part.set_meta(LegendaryGleam.META, rarity)
			elif part.has_meta(LegendaryGleam.META):
				part.remove_meta(LegendaryGleam.META)


## The gleam the held weapon wears, or null.
func held_gleam() -> ShaderMaterial:
	return _gleam


## Where the held weapon's tip is in the world, or `Vector2.INF` when none is
## drawn. Every strip lays the picture with its grip on the node, so any one
## of them carries the tip to the same place.
func tip_in_world() -> Vector2:
	if _texture == null:
		return Vector2.INF
	for hand: int in 2:
		for part: Sprite2D in (_over[hand] as Array) + (_under[hand] as Array):
			if part.visible:
				return part.global_transform * Vector2(0.0, _tip - _grip.y)
	return Vector2.INF


## Motes off a legendary tip, on its rarity's rate. The game calls it each
## frame; a gate calls it with a clock of its own and reads the count back.
func shed(delta: float) -> int:
	var strength: float = LegendaryGleam.tier(_gleam_rarity)
	if _gleam == null or strength <= 0.0 or not is_visible_in_tree():
		return 0
	var tip: Vector2 = tip_in_world()
	if tip == Vector2.INF:
		return 0
	_shed_debt += Balance.GEAR_GLEAM_MOTES * strength * delta * Graphics.particle_scale()
	var shed_now: int = 0
	var colour: Color = Stash.RARITY_COLOURS[clampi(_gleam_rarity, 0, Stash.RARITY_COLOURS.size() - 1)]
	while _shed_debt >= 1.0:
		_shed_debt -= 1.0
		shed_now += 1
		var drift := Vector2(_shed_dice.randf_range(-10.0, 10.0), _shed_dice.randf_range(-34.0, -18.0))
		Vfx.mote(tip + Vector2(_shed_dice.randf_range(-4.0, 4.0), _shed_dice.randf_range(-4.0, 4.0)), drift,
			colour.lerp(Color.WHITE, 0.35), _shed_dice.randf_range(1.6, 2.8), _shed_dice.randf_range(0.5, 0.9))
	return shed_now


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


func _head_part(node_name: String) -> Sprite2D:
	var sprite: Sprite2D = _part(self, node_name)
	sprite.region_enabled = true
	var shader: Shader = load(HAIR_SHADER_PATH) as Shader
	if shader != null:
		var material := ShaderMaterial.new()
		material.shader = shader
		sprite.material = material
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
	_build_parts()
	_outfit = outfit
	_cape_sheets.clear()
	var held: String = String(outfit.get("held", ""))
	var grip: Dictionary = outfit.get("held_grip", {})
	_texture = WardenDress.texture(held) if not held.is_empty() else null
	_gleam_held(int(outfit.get("held_rarity", -1)), held)
	if _texture != null and not grip.is_empty():
		_grip = grip["grip"]
		_tip = float(grip["tip"])
		_hilt = grip.get("hilt", Vector2(_grip.y, _grip.y))
	else:
		_texture = null
	for hand: int in 2:
		_hide_hand(hand)
	var shield_path: String = String(outfit.get("shield", ""))
	_shield_texture = load(shield_path) as Texture2D \
		if not shield_path.is_empty() and ResourceLoader.exists(shield_path) else null
	for part: Sprite2D in [_shield_over, _shield_under]:
		part.visible = false
	var tint: Color = outfit.get("cape_tint", Color(1, 1, 1, 0))
	var cloth: Color = Color(tint.r, tint.g, tint.b, 1.0) if tint.a > 0.0 else CAPE_PLAIN
	for part: Sprite2D in [_cape_back, _cape_front]:
		var material := part.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("hair_colour", cloth)
		part.visible = false
	var colour: Color = outfit.get("hair_colour", WardenLook.HAIR_COLOURS[0])
	for pair: Array in [[_hair, "hair"], [_beard, "beard"]]:
		var part: Sprite2D = pair[0]
		var option: Dictionary = outfit.get(pair[1], {})
		part.texture = WardenDress.texture(String(option.get("path", ""))) if not option.is_empty() else null
		part.visible = false
		var material := part.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("hair_colour", colour)
	_hair_sway = float((outfit.get("hair", {}) as Dictionary).get("sway", 0.0))


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
	_show_head(table[frame] if frame < table.size() else [], offset)
	_show_shield(table[frame] if frame < table.size() else [], offset, meta)
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


## The shield on the left fist's socket - [x, y, angle, reach, front] from 5 -
## upright and facing the camera, over the body when the fist is in front.
func _show_shield(socket: Array, offset: Vector2, meta: Dictionary) -> void:
	if _shield_texture == null or socket.size() < 10:
		_shield_over.visible = false
		_shield_under.visible = false
		return
	var front: bool = int(socket[9]) == 1
	var part: Sprite2D = _shield_over if front else _shield_under
	var other: Sprite2D = _shield_under if front else _shield_over
	other.visible = false
	var stature: float = float(meta.get("stature", 150.0))
	var side: float = stature * Balance.SHIELD_DRAWN_SHARE / maxf(float(_shield_texture.get_height()), 1.0)
	part.texture = _shield_texture
	part.position = offset + Vector2(float(socket[5]), float(socket[6]))
	part.rotation = 0.0
	part.scale = Vector2(side, side)
	part.visible = true


## The hair and the beard on this frame's head point, in the view the head
## shows. A socket row with no head in it - a table from before heads - shows
## neither, rather than a head dressing in the wrong place.
func _show_head(socket: Array, offset: Vector2) -> void:
	var cell: Array = _outfit.get("head_cell", [80, 128])
	var anchor: Array = _outfit.get("head_anchor", [40, 30])
	for part: Sprite2D in [_hair, _beard]:
		if part.texture == null or socket.size() <= HEAD_SOCKET + 2:
			part.visible = false
			continue
		var view: int = int(socket[HEAD_SOCKET + 2])
		part.region_rect = Rect2(float(view * int(cell[0])), 0.0, float(cell[0]), float(cell[1]))
		part.offset = -Vector2(float(anchor[0]), float(anchor[1]))
		part.position = offset + Vector2(float(socket[HEAD_SOCKET]), float(socket[HEAD_SOCKET + 1]))
		part.skew = _sway * _hair_sway if part == _hair else 0.0
		part.visible = true


## The lean trails the Warden's own travel: moving right, what hangs below the
## head swings left. A spring rather than a direct lean, so a stop overshoots
## and settles the way hair does.
func _process(delta: float) -> void:
	if delta <= 0.0 or not visible:
		return
	# Motes only where the effects are drawn: a Warden on the Glass's stage
	# stands in a viewport of its own, and the road's ink is not there.
	if _gleam != null and DisplayServer.get_name() != "headless" and Vfx.world != null \
			and is_instance_valid(Vfx.world) and Vfx.world.get_viewport() == get_viewport():
		shed(delta)
	var at: Vector2 = global_position
	var travel: Vector2 = Vector2.ZERO
	if _last_at != Vector2.INF:
		travel = (at - _last_at) / delta
	_last_at = at
	if travel.length() > Balance.DRESS_HAIR_TELEPORT_SPEED:
		_sway = 0.0
		_sway_speed = 0.0
		return
	var target: float = clampf(travel.x * Balance.DRESS_HAIR_SWAY_PER_SPEED,
		-Balance.DRESS_HAIR_SWAY_MAX, Balance.DRESS_HAIR_SWAY_MAX)
	_sway_speed += ((target - _sway) * Balance.DRESS_HAIR_SWAY_SPRING
		- _sway_speed * Balance.DRESS_HAIR_SWAY_DAMP) * delta
	_sway = clampf(_sway + _sway_speed * delta, -Balance.DRESS_HAIR_SWAY_MAX, Balance.DRESS_HAIR_SWAY_MAX)
	if _hair != null and _hair.visible:
		_hair.skew = _sway * _hair_sway


## How far what is worn on the head rises above the head point, in art pixels:
## the tallest of each dressing's eight views, or the bald crown when there is
## none. What the Warden's overhead bars stand clear of (owner, 2026-09-26).
func head_rise() -> float:
	var rise: float = Balance.DRESS_CROWN_ABOVE_HEAD
	var cell: Array = _outfit.get("head_cell", [80, 128])
	var anchor: Array = _outfit.get("head_anchor", [40, 30])
	for part: Sprite2D in [_hair, _beard]:
		if part != null and part.texture != null:
			rise = maxf(rise, _rise_of(part.texture, Vector2i(int(cell[0]), int(cell[1])), float(anchor[1])))
	return rise


## A dressing's rise, read once a picture and kept: the topmost pixel of any
## view against the anchor row. A picture that cannot be read is given the
## tallest dressing drawn, so a bar is never laid across a head.
static var _rises: Dictionary = {}


static func _rise_of(texture: Texture2D, cell: Vector2i, anchor_y: float) -> float:
	var key: String = texture.resource_path
	if not key.is_empty() and _rises.has(key):
		return float(_rises[key])
	var rise: float = Balance.DRESS_HEAD_RISE_FALLBACK
	var image: Image = texture.get_image()
	if image != null and not image.is_empty() and cell.x > 0:
		if image.is_compressed():
			image.decompress()
		var top: int = cell.y
		for view: int in image.get_width() / cell.x:
			var used: Rect2i = image.get_region(Rect2i(view * cell.x, 0, cell.x, cell.y)).get_used_rect()
			if used.size.y > 0:
				top = mini(top, used.position.y)
		if top < cell.y:
			rise = anchor_y - float(top)
	if not key.is_empty():
		_rises[key] = rise
	return rise


## The hair and the beard as drawn this frame, for `dress_check`.
func hair() -> Sprite2D:
	return _hair


func beard() -> Sprite2D:
	return _beard


func sway() -> float:
	return _sway


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
