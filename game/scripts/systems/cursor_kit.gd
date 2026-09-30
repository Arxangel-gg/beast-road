class_name CursorKit
extends RefCounted

## Wilderhold's cursor language. Registering textures for Godot cursor shapes
## means every standard Button, text field and busy state inherits the set
## without per-screen hover scripts. World interactions opt into build, attack
## and repair through the small helpers below.
##
## **The Pathfire family, as of 2026-09-30** (owner: "Chatgpt made some assets
## for you to be able to implement into our game including UI assets and cursor
## sets"). Eleven cursors, each drawn at 32, 48 and 64 pixels, installed from
## `art_inbox/chatgpt/ui/cursors` byte for byte (the copy is checked against the
## manifest's sha256), with that manifest's own hotspot for every size rather
## than one scaled by hand.
##
## **Each meaning has its own shape now.** The old kit put building on
## `CURSOR_DRAG` while the HUD put it on `CURSOR_CAN_DROP`, which was also
## repair's - so the same click said two things and two clicks said the same
## thing. Godot's shapes are a fixed list, so a meaning with no shape of its own
## borrows one the game never otherwise shows: placement is `CURSOR_MOVE`, a
## service (repair, the Quartermaster, tending) is `CURSOR_HELP`. The genuine
## drag shapes keep their drag art for the day a real drag is built, and a
## locked control's `CURSOR_FORBIDDEN` finally has a picture.

const DIRECTORY: String = "res://art/cursors/"

## The sizes each cursor is drawn at.
const SIZES: Array[int] = [32, 48, 64]

## What each shape shows: the art's role, and its hotspot at 32, 48 and 64 as
## the manifest records them.
const SHAPES: Array[Dictionary] = [
	{"shape": Input.CURSOR_ARROW, "role": "default", "hot": [Vector2(4, 4), Vector2(6, 5), Vector2(8, 7)]},
	{"shape": Input.CURSOR_POINTING_HAND, "role": "point", "hot": [Vector2(9, 3), Vector2(14, 4), Vector2(18, 6)]},
	{"shape": Input.CURSOR_CROSS, "role": "attack", "hot": [Vector2(16, 16), Vector2(24, 24), Vector2(32, 32)]},
	{"shape": Input.CURSOR_MOVE, "role": "build", "hot": [Vector2(4, 4), Vector2(6, 5), Vector2(8, 7)]},
	{"shape": Input.CURSOR_HELP, "role": "repair", "hot": [Vector2(4, 4), Vector2(6, 5), Vector2(8, 7)]},
	{"shape": Input.CURSOR_FORBIDDEN, "role": "forbidden", "hot": [Vector2(4, 4), Vector2(6, 5), Vector2(8, 7)]},
	{"shape": Input.CURSOR_BUSY, "role": "busy", "hot": [Vector2(4, 4), Vector2(6, 5), Vector2(8, 7)]},
	{"shape": Input.CURSOR_WAIT, "role": "busy", "hot": [Vector2(4, 4), Vector2(6, 5), Vector2(8, 7)]},
	{"shape": Input.CURSOR_IBEAM, "role": "text", "hot": [Vector2(16, 16), Vector2(24, 24), Vector2(32, 32)]},
	{"shape": Input.CURSOR_DRAG, "role": "grabbing", "hot": [Vector2(16, 16), Vector2(24, 24), Vector2(32, 32)]},
	{"shape": Input.CURSOR_CAN_DROP, "role": "drop_allowed", "hot": [Vector2(4, 4), Vector2(6, 5), Vector2(8, 7)]},
]

## The shape a placement shows, and the one a service shows - for a Control's
## `mouse_default_cursor_shape`, which takes the same numbers.
const BUILD_SHAPE: Control.CursorShape = Control.CURSOR_MOVE
const SERVICE_SHAPE: Control.CursorShape = Control.CURSOR_HELP

static var _ready: bool = false
static var _size: int = 48


static func apply() -> void:
	if _ready:
		return
	_ready = true
	_size = size_for_screen(_screen_height())
	for entry: Dictionary in SHAPES:
		_register(entry["shape"] as Input.CursorShape, String(entry["role"]),
			hotspot(entry, _size))

	# Give every present and future Button the authored pointing cursor. Buttons
	# default to the arrow in Godot, so merely registering a POINTING_HAND image
	# would otherwise leave that state invisible throughout most of the UI.
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		_decorate_controls(tree.root)
		tree.node_added.connect(func(node: Node) -> void: _decorate_controls(node))


## **Which size the cursors are drawn at, by the screen's height.** A cursor is
## drawn in screen pixels and never scaled, so one size is a speck on a 4K panel
## and a fist on a small laptop. The manifest's own advice: 48 for a desktop,
## 64 large, 32 compact. [TUNE] in `Balance.CURSOR_SIZE_*`.
static func size_for_screen(height: int) -> int:
	if height >= Balance.CURSOR_SIZE_LARGE_FROM:
		return 64
	if height >= Balance.CURSOR_SIZE_DESKTOP_FROM:
		return 48
	return 32


## A shape's hotspot at a size, as the manifest recorded it.
static func hotspot(entry: Dictionary, size: int) -> Vector2:
	var hot: Array = entry["hot"] as Array
	var index: int = SIZES.find(size)
	return hot[index if index >= 0 else 1] as Vector2


static func path_for(role: String, size: int) -> String:
	return "%scursor_%s_%d.png" % [DIRECTORY, role, size]


static func size_in_use() -> int:
	return _size


static func _screen_height() -> int:
	if DisplayServer.get_name() == "headless":
		return 1080
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()).y


static func use_default() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


static func use_attack() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)


static func use_build() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_MOVE)


static func use_repair() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_HELP)


## Releases the cursor textures before the renderer shuts down. Input retains
## custom cursor resources globally, so short-lived QA processes otherwise end
## with false-positive RID leak reports despite their scene tree being clean.
static func clear() -> void:
	for entry: Dictionary in SHAPES:
		Input.set_custom_mouse_cursor(null, entry["shape"] as Input.CursorShape)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_ready = false


static func _register(shape: Input.CursorShape, role: String, hot: Vector2) -> void:
	var path: String = path_for(role, _size)
	if not ResourceLoader.exists(path):
		push_warning("Cursor art is missing: %s" % path)
		return
	Input.set_custom_mouse_cursor(load(path), shape, hot)


static func _decorate_controls(node: Node) -> void:
	if node is Button:
		var button := node as Button
		if button.mouse_default_cursor_shape == Control.CURSOR_ARROW:
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for child: Node in node.get_children():
		_decorate_controls(child)
