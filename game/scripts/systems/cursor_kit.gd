class_name CursorKit
extends RefCounted

## Beast Road's cursor language. Registering textures for Godot cursor shapes
## means every standard Button, link and busy state inherits the set without
## per-screen hover scripts. World interactions can opt into build/attack/repair
## through the small helpers below.

const DIRECTORY: String = "res://art/cursors/"

static var _ready: bool = false


static func apply() -> void:
	if _ready:
		return
	_ready = true
	_register(Input.CURSOR_ARROW, "cursor_default", Vector2(7.0, 6.0))
	_register(Input.CURSOR_POINTING_HAND, "cursor_point", Vector2(17.0, 5.0))
	_register(Input.CURSOR_CROSS, "cursor_attack", Vector2(16.0, 7.0))
	_register(Input.CURSOR_DRAG, "cursor_build", Vector2(15.0, 15.0))
	_register(Input.CURSOR_CAN_DROP, "cursor_repair", Vector2(15.0, 14.0))
	_register(Input.CURSOR_BUSY, "cursor_busy", Vector2(16.0, 16.0))
	_register(Input.CURSOR_WAIT, "cursor_busy", Vector2(16.0, 16.0))

	# Give every present and future Button the authored pointing cursor. Buttons
	# default to the arrow in Godot, so merely registering a POINTING_HAND image
	# would otherwise leave that state invisible throughout most of the UI.
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		_decorate_controls(tree.root)
		tree.node_added.connect(func(node: Node) -> void: _decorate_controls(node))


static func use_default() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


static func use_attack() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)


static func use_build() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)


static func use_repair() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_CAN_DROP)


## Releases the cursor textures before the renderer shuts down. Input retains
## custom cursor resources globally, so short-lived QA processes otherwise end
## with six false-positive RID leak reports despite their scene tree being clean.
static func clear() -> void:
	for shape: Input.CursorShape in [
			Input.CURSOR_ARROW,
			Input.CURSOR_POINTING_HAND,
			Input.CURSOR_CROSS,
			Input.CURSOR_DRAG,
			Input.CURSOR_CAN_DROP,
			Input.CURSOR_BUSY,
			Input.CURSOR_WAIT,
	]:
		Input.set_custom_mouse_cursor(null, shape)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_ready = false


static func _register(shape: Input.CursorShape, id: String, hotspot: Vector2) -> void:
	var path: String = "%s%s.png" % [DIRECTORY, id]
	if not ResourceLoader.exists(path):
		push_warning("Cursor art is missing: %s" % path)
		return
	Input.set_custom_mouse_cursor(load(path), shape, hotspot)


static func _decorate_controls(node: Node) -> void:
	if node is Button:
		var button := node as Button
		if button.mouse_default_cursor_shape == Control.CURSOR_ARROW:
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for child: Node in node.get_children():
		_decorate_controls(child)
