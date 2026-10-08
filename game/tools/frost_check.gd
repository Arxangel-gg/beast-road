extends Node

## **The interface's frost** (owner, 2026-10-07: "Elevate the Hold's UIs to have
## semi-transparency. Any UIs etc anywhere in the game that would benefit from
## being semi-transparent ... with polish and game juice perfection").
##
##   godot --headless --path game res://tools/frost_check.tscn
##
## Holds that every screen `UiFrost` names is a class the game has; that each,
## stood up and opened as a player opens it, has its scrim dressed and its main
## panel drawn see-through at exactly the frost's share and its words whole;
## that the Hold's bar, zoom and the Warden's card are dressed; that the pause
## menu's frost shows only while the pause panel or its settings do and takes no
## clicks; that the frost is never drawn headless or on Low; and that the shader
## blurs the world it reads rather than drawing anything of its own over words.
## Headless cannot compile a shader, so what is held is the dressing, not the
## picture - `frost_shot` is the picture.

const TAG: String = "[frost]"

var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset()
	_test_the_names()
	await _test_every_screen()
	await _test_the_hold()
	await _test_the_pause_menu()
	_test_the_rule_and_the_shader()
	for stage: String in ["names", "screens", "hold", "pause", "rule"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: every listed screen frosts its scrim and lets its panel through with its words whole, the Hold and the pause menu are dressed, and the frost is never drawn headless or on Low" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().paused = false
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])


func _test_the_names() -> void:
	var known: Dictionary = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		known[String(entry.get("class", ""))] = true
	for name: String in UiFrost.SCREENS:
		_check(known.has(name), "UiFrost names '%s', which is no class in the game" % name)
	_reached.append("names")


## Every listed screen with a plain `open()`, stood up as `pad_focus_check`
## stands them up, and read after the frost has had its frames.
func _test_every_screen() -> void:
	var dressed: int = 0
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		var name: String = String(entry.get("class", ""))
		if not UiFrost.SCREENS.has(name) or name in ["PauseMenu", "MercenaryCard", "WaysideCard"]:
			continue
		var script: Script = load(String(entry.get("path", ""))) as Script
		if script == null or not script.can_instantiate():
			continue
		var screen: Node = script.new()
		add_child(screen)
		await get_tree().process_frame
		if screen.has_method("open"):
			var arguments: int = 0
			for method: Dictionary in screen.get_method_list():
				if String(method.get("name", "")) == "open":
					arguments = (method.get("args", []) as Array).size() - (method.get("default_args", []) as Array).size()
			if arguments == 0:
				screen.call("open")
		for _frame: int in 8:
			await get_tree().process_frame
		var panels: Array[Control] = []
		var scrims: Array[ColorRect] = []
		_collect(screen, panels, scrims)
		_check(not panels.is_empty() or not scrims.is_empty(), "%s was opened and nothing on it was dressed" % name)
		for panel: Control in panels:
			_check(is_equal_approx(panel.self_modulate.a, Balance.UI_FROST_PANEL_ALPHA) or panel.self_modulate.a < Balance.UI_FROST_PANEL_ALPHA,
				"%s's panel %s is drawn at %.2f, not the frost's %.2f" % [name, panel.name, panel.self_modulate.a, Balance.UI_FROST_PANEL_ALPHA])
			_check(panel.self_modulate.a >= Balance.UI_FROST_PANEL_ALPHA - 0.25,
				"%s's panel %s is drawn at %.2f - too faint to read on" % [name, panel.name, panel.self_modulate.a])
			for node: Node in panel.find_children("*", "Label", true, false):
				var label := node as Label
				if label.is_visible_in_tree():
					_check(label.self_modulate.a >= 0.99, "%s's words were made see-through with its plate" % name)
					break
		if not panels.is_empty() or not scrims.is_empty():
			dressed += 1
		screen.queue_free()
		await get_tree().process_frame
	_check(dressed >= 8, "only %d of the listed screens were dressed" % dressed)
	_reached.append("screens")


func _collect(node: Node, panels: Array[Control], scrims: Array[ColorRect]) -> void:
	for child: Node in node.get_children():
		var control := child as Control
		if control != null and control.has_meta(UiFrost.DRESSED):
			if control is ColorRect:
				scrims.append(control as ColorRect)
			else:
				panels.append(control)
		_collect(child, panels, scrims)


func _test_the_hold() -> void:
	var hub := HubScreen.new()
	add_child(hub)
	await get_tree().process_frame
	hub.open()
	for _frame: int in 4:
		await get_tree().process_frame
	var bar := hub.find_child("Bar", true, false) as Control
	_check(bar != null, "the Hold has no bar")
	if bar != null:
		for node: Node in bar.get_children():
			var button := node as Button
			if button != null:
				_check(is_equal_approx(float(button.get_meta(&"ui_see_through", 1.0)), Balance.UI_BUTTON_SEE_THROUGH),
					"the Hold's '%s' is drawn whole" % button.text)
	for name: String in ["ZoomOut", "ZoomIn"]:
		var button := hub.find_child(name, true, false) as Button
		_check(button != null and is_equal_approx(float(button.get_meta(&"ui_see_through", 1.0)), Balance.UI_BUTTON_SEE_THROUGH),
			"the Hold's %s is drawn whole" % name)
	var card := hub.find_child("Hold", true, false) as Control
	_check(card != null and card.has_meta(UiFrost.DRESSED) and card.self_modulate.a <= Balance.UI_FROST_PANEL_ALPHA + 0.001,
		"the Warden's card is not glass")
	var dim := hub.find_child("Dim", true, false) as ColorRect
	_check(dim != null and dim.has_meta(UiFrost.DRESSED), "the yard behind the Warden's card is not frosted")
	hub.queue_free()
	await get_tree().process_frame
	_reached.append("hold")


func _test_the_pause_menu() -> void:
	GameDirector.run_active = true
	var run := (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 12:
		await get_tree().process_frame
	var pause: PauseMenu = run.pause_ui
	var frost := pause.find_child("PauseFrost", true, false) as ColorRect if pause != null else null
	_check(frost != null, "the pause menu has no frost")
	if frost != null:
		_check(frost.has_meta(UiFrost.DRESSED), "the pause menu's frost is not dressed")
		_check(frost.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the pause menu's frost takes clicks")
		_check(not frost.visible, "the frost stands over the road with the pause menu shut")
		pause.toggle()
		await get_tree().process_frame
		_check(frost.visible, "the pause menu opened with no frost behind it")
		pause.toggle()
		await get_tree().process_frame
		_check(not frost.visible, "the frost stayed after the pause menu shut")
	get_tree().paused = false
	GameDirector.run_active = false
	run.queue_free()
	await get_tree().process_frame
	_reached.append("pause")


func _test_the_rule_and_the_shader() -> void:
	_check(not UiFrost.frost_drawn_for(true, false), "the frost would be drawn headless")
	_check(not UiFrost.frost_drawn_for(false, true), "the frost would be drawn on Low, where a copy of the screen costs too much")
	_check(UiFrost.frost_drawn_for(false, false), "the frost is never drawn")
	var source: String = FileAccess.get_file_as_string(UiFrost.FROST_SHADER)
	_check(source.contains("hint_screen_texture") and source.contains("filter_linear_mipmap") and source.contains("textureLod"),
		"the frost does not blur the world behind it")
	_check(source.contains("wash"), "the frost does not keep the scrim's own colour")
	_reached.append("rule")
