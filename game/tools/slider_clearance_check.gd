extends Node

## **No slider touches a button** (owner, 2026-10-01: *"Padding so that sliders
## do not overlap UI elements such as buttons etc."*):
##
##   godot --headless --path game res://tools/slider_clearance_check.tscn
##
## Every screen with a slider is stood up as the game stands it - the HUD in a
## real run, the Hold, the settings, the comfort card and the Warden's Glass -
## at a desktop shape and a landscape phone's, and every visible slider must
## stand `CLEARANCE` clear of every visible button on the same screen.
##
## **Measured on the slider's own rectangle**, which is where its rail and its
## grabber are drawn: Godot keeps a horizontal grabber inside the rect and a
## rail fills it, so a rect that clears the buttons is a slider that clears
## them. Two found by photograph on the day this was written: the HUD's zoom
## rail ran full height between two buttons, its filled end meeting the one
## under it, and the Hold's ran edge to edge between "-" and "+".
##
## **The ways this goes wrong:** a slider added beside a button with no gap; a
## gap that exists on a desktop and closes on a phone, where the touch pass
## grows every button; and a screen nobody stood up, which this cannot see -
## so a screen with a slider that is not on the list below is named by a source
## walk.

const CLEARANCE: float = 8.0
const SHAPES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 592)]
## Every script that builds a slider, and the screen here that stands it up.
const COVERED: Array[String] = [
	"res://scenes/ui/hud.gd",
	"res://scenes/ui/hub_screen.gd",
	"res://scenes/ui/settings_panel.gd",
	"res://scenes/ui/comfort_card.gd",
	"res://scenes/ui/warden_glass.gd",
]

var _failures: int = 0
var _checks: int = 0
var _sliders_seen: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	WardenGlass.mark_offered()
	_test_every_slider_screen_is_covered()
	for shape: Vector2i in SHAPES:
		get_window().size = shape
		get_window().content_scale_size = shape
		for _f: int in 3:
			await get_tree().process_frame
		await _measure_the_hud(shape)
		await _measure(_stand_hold(), "the Hold", shape)
		await _measure(_stand_settings(), "the settings", shape)
		await _measure(_stand_comfort(), "the comfort card", shape)
		await _measure(_stand_glass(), "the Warden's Glass", shape)
	_check(_sliders_seen >= SHAPES.size() * 5,
		"only %d sliders were measured - a screen stood up with none showing measures nothing"
		% _sliders_seen)
	MetaState.resume_saves()
	if _failures == 0:
		print("[slider] PASS - %d checks: %d sliders on five screens at two shapes, each %.0f clear of every button"
			% [_checks, _sliders_seen, CLEARANCE])
	else:
		push_error("[slider] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _test_every_slider_screen_is_covered() -> void:
	for path: String in _scripts_under("res://scenes"):
		var text: String = FileAccess.get_file_as_string(path)
		if not (text.contains("HSlider.new()") or text.contains("VSlider.new()")):
			continue
		_check(COVERED.has(path),
			"%s builds a slider and no screen here stands it up to measure" % path)


func _scripts_under(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for name: String in dir.get_files():
		if name.ends_with(".gd"):
			out.append(root.path_join(name))
	for sub: String in dir.get_directories():
		out.append_array(_scripts_under(root.path_join(sub)))
	return out


# --- The screens --------------------------------------------------------------


func _measure_the_hud(shape: Vector2i) -> void:
	RunState.reset(false, 20261001)
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	run.battlefield.wave_director.stop()
	await _measure(run, "the HUD", shape, false)
	run.queue_free()
	GameDirector.run_active = false
	for _f: int in 4:
		await get_tree().process_frame


func _stand_hold() -> Node:
	var hub := HubScreen.new()
	add_child(hub)
	hub.open()
	return hub


func _stand_settings() -> Node:
	var layer := CanvasLayer.new()
	var panel := SettingsPanel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(panel)
	add_child(layer)
	return layer


func _stand_comfort() -> Node:
	var card := ComfortCard.new()
	add_child(card)
	card.open()
	return card


func _stand_glass() -> Node:
	var glass := WardenGlass.new()
	add_child(glass)
	glass.open()
	return glass


## Every visible slider under `screen` against every visible button under it.
func _measure(screen: Node, label: String, shape: Vector2i, free_after: bool = true) -> void:
	for _f: int in 6:
		await get_tree().process_frame
	var sliders: Array[Control] = []
	var buttons: Array[Control] = []
	for node: Node in screen.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control is Slider:
			sliders.append(control)
		elif control is BaseButton:
			buttons.append(control)
	for slider: Control in sliders:
		var rect: Rect2 = slider.get_global_rect()
		if rect.size.x < 1.0 or rect.size.y < 1.0:
			continue
		_sliders_seen += 1
		for button: Control in buttons:
			var other: Rect2 = button.get_global_rect()
			if other.size.x < 1.0 or other.size.y < 1.0:
				continue
			# A button inside the slider's own box (none today) is the slider's.
			if slider.is_ancestor_of(button):
				continue
			_check(not rect.grow(CLEARANCE - 0.5).intersects(other),
				"%s at %dx%d: the slider %s %s comes within %.0f of the button %s %s" % [
					label, shape.x, shape.y, slider.name, rect, CLEARANCE, button.name, other])
	if free_after:
		screen.queue_free()
		for _f: int in 3:
			await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[slider] " + message)
