extends Node

## Every menu panel, opened at phone size, with its way out on screen.
##
## Reported from a phone, 2026-09-02: "the stash screen cannot be closed on
## mobile". It could not - the panel's column had grown past the viewport and a
## `CenterContainer` overflows equally in both directions, so the Close button
## sat below the bottom edge with no way to scroll to it.
##
## **`layout_check` could not have caught this**, and that is the reason this
## file exists rather than another assertion in that one: it builds the *run*
## scene and measures the HUD. Nothing in the project ever opened a main-menu
## panel at a phone size and looked. Six screens have this shape and the bug has
## now appeared in three of them - the results screen, the leaderboard, and the
## stash - each time found by a person holding a phone.
##
## Three promises, per screen:
##
## 1. **The way out is fully on screen.** Not merely present, not merely
##    intersecting: a Close button 90% visible is one whose label is cut, and a
##    player who cannot see it does not know it is there.
## 2. **The panel fits the viewport.** A panel taller than the screen is the
##    cause; the button is only where it shows.
## 3. **Every control is thumb-sized.** A 24-unit button is a miss on glass.

## Phone shapes. Portrait is the one the stash failed in; landscape has caught
## its own faults before and costs one more pass.
const SHAPES: Array[Vector2i] = [Vector2i(430, 932), Vector2i(932, 430)]

var _failures: int = 0
var _checked: int = 0
var _saved_settings: Dictionary = {}
var _saved_completed: Array[String] = []
var _saved_window_size: Vector2i
var _saved_window_mode: Window.Mode
var _capture: bool = false


func _ready() -> void:
	# Pinning and leaving Settings normally save. The test uses scratch state,
	# never a fresh-account reset that might overwrite the player's real slot.
	MetaState.hold_saves()
	_saved_settings = MetaState.settings.duplicate(true)
	_saved_completed = MetaState.completed_objectives.duplicate()
	_saved_window_size = get_window().size
	_saved_window_mode = get_window().mode
	MetaState.completed_objectives.clear()
	MetaState.settings[ChronicleGoals.SETTING] = ""
	MetaState.settings[TouchInput.TOUCH_KEY] = true
	_capture = OS.get_cmdline_user_args().has("--capture") \
		and DisplayServer.get_name() != "headless"
	if OS.get_cmdline_user_args().has("--capture") and not _capture:
		print("[menu-layout] capture skipped: headless display has no rendered pixels")
	TouchInput.refresh()
	for shape: Vector2i in SHAPES:
		await _sweep(shape)
	await _finish()


func _sweep(shape: Vector2i) -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = shape
	ScreenFit._fit()
	await _settle()

	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate() as Control
	add_child(menu)
	await _settle()

	# **Found by shape, not by name.** Only some of these are held in a field -
	# the stash is a local inside `_build` - so a list of property names finds
	# five of six and silently skips the one the bug was reported in.
	for node: Node in _all(menu):
		if node == menu or not node.has_method("open"):
			continue
		if not (node is CanvasLayer or node is Control):
			continue
		await _open_and_measure(node, _name_of(node), shape)
	await _test_diagnostics(menu as MainMenu, shape)

	menu.queue_free()
	await _settle()


func _open_and_measure(screen: Node, name: String, shape: Vector2i) -> void:
	# Opened the way a player opens it. A panel measured while hidden reports the
	# sizes it had before its container ran, which is the state nobody sees.
	if screen.has_method("open"):
		screen.call("open")
	elif screen is CanvasLayer:
		(screen as CanvasLayer).visible = true
	elif screen is Control:
		(screen as Control).visible = true
	await _settle()
	if not _is_showing(screen):
		return
	_checked += 1

	var view: Rect2 = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var exits: int = 0
	for node: Node in _all(screen):
		var button := node as Button
		if button == null or not button.is_visible_in_tree():
			continue
		var rect: Rect2 = button.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue

		# 3. Configured touch targets, measured in the control's own units.
		# Physical readability/hit size still needs real-device acceptance:
		# passing virtual-canvas geometry cannot certify CSS pixels or device DPI.
		#
		# `canvas_items` stretch scales the whole interface, so a global rect is
		# the layout size times a ratio that depends on the window the test
		# happened to open at. `layout_check` learned this the hard way when a
		# 120 floor measured 118.2 and failed on a property of the test window.
		if not button.disabled:
			var floor_height: float = float(button.get_meta(
				UiMetrics.TOUCH_TARGET_HEIGHT, Balance.UI_TOUCH_MIN_TARGET_HEIGHT))
			_check(button.size.y + 1.0 >= floor_height,
				"%s at %s: '%s' is %.0f tall, under the %.0f thumb floor"
					% [name, shape, button.text, button.size.y, floor_height])

		# 1. The way out, whole and visible.
		if not _is_exit(button):
			continue
		exits += 1
		var inside: Rect2 = view.intersection(rect)
		var shown: float = (inside.size.x * inside.size.y) \
			/ maxf(rect.size.x * rect.size.y, 1.0)
		_check(shown >= 0.999,
			"%s at %s: the way out ('%s') is %.0f%% on screen, at %s size %s - "
				% [name, shape, button.text, shown * 100.0, rect.position, rect.size]
				+ "a player who cannot see it cannot leave")

	_check(exits > 0,
		"%s at %s has no way out at all" % [name, shape])

	# 2. The panel itself.
	for node: Node in _all(screen):
		var panel := node as PanelContainer
		if panel == null or not panel.is_visible_in_tree():
			continue
		var rect: Rect2 = panel.get_global_rect()
		if rect.size.y <= 0.0:
			continue
		_check(rect.size.y <= view.size.y + 1.0,
			"%s at %s: a panel is %.0f tall in a %.0f screen, so whatever is at "
				% [name, shape, rect.size.y, view.size.y]
				+ "the bottom of it is off the bottom of the display")
		_check(rect.position.x >= view.position.x - 1.0 and rect.end.x <= view.end.x + 1.0,
			"%s at %s: the panel extends past a side of the display (%s)" % [name, shape, rect])
		break
	if screen is ChronicleScreen:
		await _test_chronicle(screen as ChronicleScreen, shape)

	if screen.has_method("hide_screen"):
		screen.call("hide_screen")
	elif screen is CanvasLayer:
		(screen as CanvasLayer).visible = false
	elif screen is Control:
		(screen as Control).visible = false
	await _settle()


func _test_chronicle(screen: ChronicleScreen, shape: Vector2i) -> void:
	var objectives: Array[ChronicleObjectiveData] = ContentDB.chronicle_objectives_sorted()
	_check(not objectives.is_empty(), "Chronicle needs objectives to exercise its pins")
	if objectives.is_empty():
		return
	var pin: Button = screen._pins.get(objectives[0].id) as Button
	var scroll: ScrollContainer = _scroll_ancestor(pin)
	_check(pin != null and scroll != null, "Chronicle must expose a scrollable pin button")
	if pin == null or scroll == null:
		return
	scroll.ensure_control_visible(pin)
	await _settle()
	_check_control_visible(pin, scroll, "Chronicle first pin at %s" % shape)
	_click(pin)
	await _settle()
	_check(Chronicle.selected_id() == objectives[0].id and pin.button_pressed
		and pin.text == ChronicleGoals.COPY.unpin,
		"Chronicle at %s: clicking Track must select the deed and offer Untrack" % shape)
	await _capture_screen("chronicle", shape)
	_click(pin)
	await _settle()
	_check(Chronicle.selected_id().is_empty() and not pin.button_pressed
		and pin.text == ChronicleGoals.COPY.pin,
		"Chronicle at %s: clicking Untrack must clear the selection" % shape)
	await _drag_scrollbar(scroll, "Chronicle at %s" % shape)
	var last: Button = screen._pins.get(objectives.back().id) as Button
	if last != null:
		scroll.ensure_control_visible(last)
		await _settle()
		_check_control_visible(last, scroll, "Chronicle final pin at %s" % shape)
	# Closing and reopening must retain the selected deed, while changing no
	# objective progress. Exercise the final row, not only the convenient first.
		_click(last)
		await _settle()
		screen.hide_screen()
		screen.open()
		await _settle()
		var reopened: Button = screen._pins.get(objectives.back().id) as Button
		_check(reopened != null and reopened.button_pressed
			and Chronicle.selected_id() == objectives.back().id,
			"Chronicle at %s: the selected final deed must survive reopening" % shape)
		if reopened != null:
			var reopened_scroll: ScrollContainer = _scroll_ancestor(reopened)
			reopened_scroll.ensure_control_visible(reopened)
			await _settle()
			_click(reopened)
			await _settle()


func _test_diagnostics(menu: MainMenu, shape: Vector2i) -> void:
	menu.call("_show_settings", true)
	await _settle()
	var data_scroll: ScrollContainer = null
	var diagnostics: SupportDiagnosticsPanel = null
	for node: Node in _all(menu._settings):
		if node is ScrollContainer and node.name == "Data":
			data_scroll = node as ScrollContainer
		elif node is SupportDiagnosticsPanel:
			diagnostics = node as SupportDiagnosticsPanel
	_check(data_scroll != null and diagnostics != null,
		"Settings must attach support diagnostics to its Data tab")
	if data_scroll == null or diagnostics == null:
		menu.call("_show_settings", false)
		return
	var tabs := data_scroll.get_parent() as TabContainer
	_check(tabs != null, "the diagnostics scroll must belong to Settings tabs")
	if tabs == null:
		menu.call("_show_settings", false)
		return
	tabs.current_tab = data_scroll.get_index()
	await _settle()
	var prepare := diagnostics.get_node("PrepareReport") as Button
	data_scroll.ensure_control_visible(prepare)
	await _settle()
	_check_control_visible(prepare, data_scroll, "Prepare diagnostics at %s" % shape)
	_click(prepare)
	await _settle()
	var preview := diagnostics.get_node("ReportPreview") as RichTextLabel
	var copy := diagnostics.get_node("CopyReport") as Button
	_check(preview.is_visible_in_tree() and JSON.parse_string(preview.text) is Dictionary,
		"diagnostics at %s: Prepare must reveal a real report" % shape)
	_check(not preview.scroll_active,
		"diagnostics must use the Data tab's outer scroll, not a nested scroll")
	data_scroll.ensure_control_visible(copy)
	await _settle()
	_check_control_visible(copy, data_scroll, "Copy diagnostics at %s" % shape)
	# Report text is intentionally longer than a phone. Width must fit, while
	# its beginning and end remain reachable through the one outer scrollbar.
	var preview_rect: Rect2 = preview.get_global_rect()
	var scroll_rect: Rect2 = data_scroll.get_global_rect()
	_check(preview_rect.position.x >= scroll_rect.position.x - 1.0
		and preview_rect.end.x <= scroll_rect.end.x + 1.0,
		"diagnostics at %s: the preview must not require horizontal scrolling" % shape)
	await _capture_screen("diagnostics", shape)
	await _drag_scrollbar(data_scroll, "Diagnostics at %s" % shape)
	# No clipboard writes: validating that Copy is reachable must not replace
	# whatever the person running the gate currently has on their clipboard.
	menu.call("_show_settings", false)
	await _settle()


func _scroll_ancestor(control: Control) -> ScrollContainer:
	var node: Node = control
	while node != null:
		if node is ScrollContainer:
			return node as ScrollContainer
		node = node.get_parent()
	return null


func _check_control_visible(control: Control, scroll: ScrollContainer, label: String) -> void:
	_check(control != null and scroll != null, "%s: control and scroll must exist" % label)
	if control == null or scroll == null:
		return
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var rect: Rect2 = control.get_global_rect()
	var visible_rect: Rect2 = rect.intersection(view).intersection(scroll.get_global_rect())
	_check(control.is_visible_in_tree() and visible_rect.get_area() >= rect.get_area() * 0.999,
		"%s: control must be wholly visible, including its full width (%s)" % [label, rect])


func _click(button: Button) -> void:
	var at: Vector2 = button.get_global_rect().get_center()
	_mouse_button(at, true)
	_mouse_button(at, false)


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	get_viewport().push_input(event, true)


func _drag_scrollbar(scroll: ScrollContainer, label: String) -> void:
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	_check(bar.is_visible_in_tree() and bar.max_value > bar.page,
		"%s must expose its draggable scrollbar when content overflows" % label)
	if not bar.is_visible_in_tree() or bar.max_value <= bar.page:
		return
	bar.value = bar.min_value
	await _settle()
	var rect: Rect2 = bar.get_global_rect()
	var arrow: Texture2D = bar.get_theme_icon("decrement")
	var arrow_height: float = float(arrow.get_height()) if arrow != null else 0.0
	var track_height: float = maxf(rect.size.y - arrow_height * 2.0, 1.0)
	var thumb_height: float = maxf(bar.get_theme_stylebox("grabber").get_minimum_size().y,
		track_height * bar.page / maxf(bar.max_value - bar.min_value, 1.0))
	var start := Vector2(rect.get_center().x, rect.position.y + arrow_height + thumb_height * 0.5)
	var end := Vector2(start.x, rect.end.y - arrow_height - 1.0)
	_mouse_button(start, true)
	var drag := InputEventMouseMotion.new()
	drag.position = end
	drag.global_position = end
	drag.relative = end - start
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(drag, true)
	_mouse_button(end, false)
	await _settle()
	_check(scroll.scroll_vertical > 0, "%s: dragging the visible thumb must move content" % label)


func _capture_screen(label: String, shape: Vector2i) -> void:
	if not _capture:
		return
	await RenderingServer.frame_post_draw
	var texture: ViewportTexture = get_viewport().get_texture()
	var image: Image = texture.get_image() if texture != null else null
	_check(image != null and not image.is_empty(), "capture needs actual rendered pixels")
	if image == null or image.is_empty():
		return
	var path: String = "user://menu_layout_%s_%dx%d.png" % [label, shape.x, shape.y]
	var error: Error = image.save_png(path)
	_check(error == OK, "could not save capture %s: %s" % [label, error_string(error)])
	if error == OK:
		print("[menu-layout] capture -> %s" % ProjectSettings.globalize_path(path))


## What to call a screen in a failure. The node names are autogenerated
## (`@CanvasLayer@36`), which says nothing; the script's filename is the thing
## somebody would go and open.
func _name_of(node: Node) -> String:
	var script: Script = node.get_script() as Script
	if script != null and not script.resource_path.is_empty():
		return script.resource_path.get_file().get_basename()
	return node.name


## A button that leaves. Matched on what it says, because that is what a player
## matches on too.
func _is_exit(button: Button) -> bool:
	var label: String = button.text.strip_edges().to_lower()
	return label in ["close", "back", "leave", "done", "return", "x", "×"]


func _is_showing(screen: Node) -> bool:
	if screen is CanvasLayer:
		return (screen as CanvasLayer).visible
	if screen is Control:
		return (screen as Control).is_visible_in_tree()
	return false


func _all(from: Node) -> Array[Node]:
	var found: Array[Node] = [from]
	for child: Node in from.get_children():
		found.append_array(_all(child))
	return found


func _settle() -> void:
	for _frame: int in 6:
		await get_tree().process_frame


func _finish() -> void:
	MetaState.settings = _saved_settings
	MetaState.completed_objectives = _saved_completed
	TouchInput.refresh()
	get_window().size = _saved_window_size
	get_window().mode = _saved_window_mode
	ScreenFit._fit()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 30:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("[menu-layout] PASS - %d screen openings across %d phone shapes, "
			% [_checked, SHAPES.size()]
			+ "exits on screen, configured touch targets, pins and draggable scrollbars")
	else:
		push_error("[menu-layout] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[menu-layout] FAIL: %s" % why)
