class_name UiFrost
extends RefCounted

## **Glass for the interface** (owner, 2026-10-07: "Elevate the Hold's UIs to
## have semi-transparency. Any UIs etc anywhere in the game that would benefit
## from being semi-transparent that aren't should be aesthetically made so with
## polish and game juice perfection").
##
## Two things, and only these. **A screen's scrim turns to frosted glass**
## (`ui_frost.gdshader`): the world behind it blurred and washed in the scrim's
## own colour, a slow band of light drifting over it - so the place a screen was
## opened from is still there, soft, behind it. **Its main panel lets that
## through** (`UiTint.see_through`): the plate is drawn at a share of its alpha
## and its words, which are never in a stylebox, stay whole.
##
## **Applied once, centrally**, to every screen named in `SCREENS` as it opens
## (`watch`), rather than by fifteen screens each remembering to - so a screen
## added tomorrow is one line here. A screen's own scrim keeps its colour as the
## glass's wash, so a screen that wanted a darker room still gets one.
##
## **Readability first, then cost.** A panel never goes below
## `UI_FROST_PANEL_ALPHA`, and on Low and below (`Graphics.at_most_low`) the
## frost is not drawn at all - the scrim stays the flat dark it was - because a
## blurred copy of the screen is a copy of the screen. Headless there is no
## screen to copy, so a gate measures the scrim it always measured.

## The screens dressed when they open, by class name.
const SCREENS: Array[String] = [
	"StashScreen", "CodexScreen", "ChronicleScreen", "DisciplinesScreen", "PenScreen",
	"StableScreen", "InnScreen", "WardenGlass", "SaveSlotScreen", "GuideScreen",
	"ActStartScreen", "LeaderboardScreen", "ExchangeScreen", "SmithyScreen",
	"VendorScreen", "ComfortCard", "PauseMenu", "MercenaryCard",
]
const FROST_SHADER: String = "res://scripts/shaders/ui_frost.gdshader"
## Marks a control already dressed, so a screen dressed twice is dressed once.
const DRESSED: StringName = &"ui_frost_dressed"

static var _watching: SceneTree = null
static var _shader: Shader = null


## Dresses every listed screen that enters `tree` from now on.
static func watch(tree: SceneTree) -> void:
	if tree == null or _watching == tree:
		return
	_watching = tree
	tree.node_added.connect(_on_node_added)


static func _on_node_added(node: Node) -> void:
	if not (node is CanvasLayer or node is Control):
		return
	var script: Script = node.get_script() as Script
	if script == null or not SCREENS.has(String(script.get_global_name())):
		return
	_dress_soon(node)


## A screen builds itself in `_ready` and again in `open`, so it is dressed a
## couple of frames after it arrives - and again once more, for the screens
## that build their panel the first time they are opened.
static func _dress_soon(node: Node) -> void:
	var tree: SceneTree = node.get_tree()
	if tree == null:
		return
	for _frame: int in 2:
		await tree.process_frame
		if not is_instance_valid(node):
			return
	dress_screen(node)
	await tree.process_frame
	await tree.process_frame
	if is_instance_valid(node):
		dress_screen(node)


## The glass on one screen: its full-screen scrim frosted and its main panels
## see-through. Idempotent.
static func dress_screen(screen: Node) -> void:
	if screen == null:
		return
	var view: Vector2 = Vector2(1920.0, 1080.0)
	var viewport: Viewport = screen.get_viewport()
	if viewport != null:
		view = viewport.get_visible_rect().size
	_dress_under(screen, view, 0)


static func _dress_under(node: Node, view: Vector2, depth: int) -> void:
	if depth > 4:
		return
	for child: Node in node.get_children():
		var rect := child as ColorRect
		if rect != null and _covers(rect, view, 0.9) and rect.color.a >= 0.35:
			frost(rect)
			continue
		var panel := child as PanelContainer
		if panel != null and _covers(panel, view, 0.04):
			glass(panel)
			continue
		if child is Container or child is Control or child is CanvasLayer:
			_dress_under(child, view, depth + 1)


static func _covers(control: Control, view: Vector2, share: float) -> bool:
	var size: Vector2 = control.size
	if size.x <= 1.0 or size.y <= 1.0:
		return false
	return size.x * size.y >= view.x * view.y * share


## A scrim turned to frosted glass, its own colour kept as the wash.
static func frost(rect: ColorRect) -> void:
	if rect == null or rect.has_meta(DRESSED):
		return
	rect.set_meta(DRESSED, true)
	if not frost_drawn():
		return
	if _shader == null:
		_shader = load(FROST_SHADER) as Shader
	if _shader == null:
		return
	var material := ShaderMaterial.new()
	material.shader = _shader
	var wash: Color = rect.color
	wash.a = clampf(rect.color.a * Balance.UI_FROST_WASH, 0.0, 0.95)
	material.set_shader_parameter("wash", wash)
	material.set_shader_parameter("blur_lod", Balance.UI_FROST_BLUR_LOD)
	material.set_shader_parameter("sheen", Balance.UI_FROST_SHEEN)
	rect.material = material


## A panel's plate drawn see-through, its words whole: `self_modulate` reaches
## the panel's own frame and none of its children, as the HUD's sheets do.
static func glass(panel: Control) -> void:
	if panel == null or panel.has_meta(DRESSED):
		return
	panel.set_meta(DRESSED, true)
	panel.self_modulate.a = minf(panel.self_modulate.a, Balance.UI_FROST_PANEL_ALPHA)


## Whether the frost is drawn on this machine: never headless, never on Low or
## below.
static func frost_drawn() -> bool:
	return frost_drawn_for(DisplayServer.get_name() == "headless", Graphics.at_most_low())


## The rule, pure, so the gate can ask it for a machine it is not.
static func frost_drawn_for(headless: bool, low: bool) -> bool:
	return not headless and not low
