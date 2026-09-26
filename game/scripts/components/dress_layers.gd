class_name DressLayers
extends Node2D

## The parts of a dressed Warden drawn over and under the body (the modular
## Warden, 2026-09-25): the cape, the weapon in the right fist, the second of a
## pair in the left.
##
## **A child of the hero's sprite, on purpose.** `SpriteAnimator` owns that
## sprite's position, scale and rotation - the bounce, the lean, the squash, the
## recoil - and a child inherits every one of them, so the cape and the sword
## move with the body through all of it without either system knowing the
## other exists. `show_behind_parent` is how a layer goes under the body: the
## weapon behind the chest when the hand is, the cape behind a Warden facing
## the camera and over one walking away.
##
## **Placed, never animated here.** `HeroAnimator` decides the state, frame and
## facing; this reads the socket table `tools/warden_rig/pack.py` wrote for that
## frame and lays each part on it. A frame with no socket shows no weapon rather
## than a weapon in the wrong place.

## Facings that show the Warden's back, by HeroAnimator row: a cape is drawn
## over the body on these and under it on the rest.
const BACK_ROWS: Array[int] = [5, 6, 7]

var _cape_back: Sprite2D
var _cape_front: Sprite2D
var _weapon: Sprite2D
var _off_weapon: Sprite2D
var _outfit: Dictionary = {}
var _cape_sheets: Dictionary = {}
var _grip: Vector2 = Vector2.ZERO
var _tip: float = 0.0


func _ready() -> void:
	_cape_back = _layer("CapeBack", true)
	_cape_front = _layer("CapeFront", false)
	_weapon = _layer("Weapon", false)
	_off_weapon = _layer("OffWeapon", false)
	for part: Sprite2D in [_cape_back, _cape_front]:
		part.region_enabled = true


func _layer(node_name: String, behind: bool) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.centered = false
	sprite.show_behind_parent = behind
	sprite.visible = false
	add_child(sprite)
	return sprite


## Dress in an outfit from `WardenDress.outfit`.
func wear(outfit: Dictionary) -> void:
	_outfit = outfit
	_cape_sheets.clear()
	var held: String = String(outfit.get("held", ""))
	var grip: Dictionary = outfit.get("held_grip", {})
	var texture: Texture2D = WardenDress.texture(held) if not held.is_empty() else null
	for part: Sprite2D in [_weapon, _off_weapon]:
		part.texture = texture
		part.visible = false
	if texture != null and not grip.is_empty():
		_grip = grip["grip"]
		_tip = float(grip["tip"])
		# The picture is laid with its grip on the node, so turning the node
		# turns the weapon about the fist.
		_weapon.offset = -_grip
		_off_weapon.offset = -_grip
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
	if frame >= table.size() or _weapon.texture == null:
		_weapon.visible = false
		_off_weapon.visible = false
		return
	var socket: Array = table[frame]
	var stature: float = float(meta.get("stature", 150.0))
	var length: float = float(_outfit.get("held_length", 0.42)) * stature
	_place(_weapon, socket, 0, offset, length)
	var paired: bool = int(_outfit.get("grip", 0)) == GearData.Grip.PAIRED
	_off_weapon.visible = paired
	if paired:
		_place(_off_weapon, socket, 5, offset, length)


## One weapon on one hand's socket: [x, y, angle, reach, front] from `start`.
func _place(part: Sprite2D, socket: Array, start: int, offset: Vector2, length: float) -> void:
	var tip_len: float = maxf(_grip.y - _tip, 1.0)
	var across: float = length / tip_len
	var along: float = across * maxf(float(socket[start + 3]), 0.08)
	part.position = offset + Vector2(float(socket[start]), float(socket[start + 1]))
	# The picture points up its own -y; the socket's angle is on screen.
	part.rotation = deg_to_rad(float(socket[start + 2])) + PI * 0.5
	part.scale = Vector2(across, along)
	part.show_behind_parent = int(socket[start + 4]) == 0
	part.visible = true


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
