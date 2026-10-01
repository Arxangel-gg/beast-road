extends Node

## **Every screen fits a phone** (owner, 2026-10-01: *"ensure all of the UIs are
## perfect on mobile. For example the Warden's glass on mobile does not properly
## fit the UI so I cannot create my character on a new install to even play"*):
##
##   godot --headless --path game res://tools/mobile_fit_check.tscn -- --viewport=430x932
##
## Every screen a player can open outside a road - the Glass, the stash, the
## codex, the Disciplines, the Ledger, the Guide, the board, the pen, the save
## slots, the smithy, the stable, the shop, a wayside card, the comfort card,
## the act screen and the Chronicle - and the main menu, the Hold, the co-op
## screen, the pause menu and the settings, each stood up on a touch layout at
## the shape given, and every control a thumb presses is held to two rules:
##
## - **On the screen.** A button outside every scroll lies wholly inside the
##   window; a scroll that holds buttons lies wholly inside it, and does not
##   hide a button off an axis it cannot scroll.
## - **Not under another.** No two pressable controls outside a scroll overlap.
##
## And every screen with a way out has it on the screen: a Done, Close or Back a
## player can press. The Glass is the screen a new account cannot get past, so
## it is held hardest: Done is on the screen and pressable, and closing it
## through Done closes it.

const TOLERANCE: float = 2.0

var _screens: Array = [
	["ActStartScreen", ActStartScreen],
	["ChronicleScreen", ChronicleScreen],
	["CodexScreen", CodexScreen],
	["ComfortCard", ComfortCard],
	["DisciplinesScreen", DisciplinesScreen],
	["ExchangeScreen", ExchangeScreen],
	["GuideScreen", GuideScreen],
	["LeaderboardScreen", LeaderboardScreen],
	["PenScreen", PenScreen],
	["SaveSlotScreen", SaveSlotScreen],
	["WardenGlass", WardenGlass],
	["SmithyScreen", SmithyScreen],
	["StableScreen", StableScreen],
	["StashScreen", StashScreen],
	["VendorScreen", VendorScreen],
	["WaysideCard", WaysideCard],
]

var _failures: int = 0
var _checks: int = 0
var _shape: String = ""
var _view: Rect2 = Rect2()


func _ready() -> void:
	MetaState.hold_saves()
	var viewport_size := Vector2i(430, 932)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--viewport="):
			var dimensions: PackedStringArray = argument.trim_prefix("--viewport=").split("x")
			if dimensions.size() == 2:
				viewport_size = Vector2i(dimensions[0].to_int(), dimensions[1].to_int())
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = viewport_size
	_shape = "%dx%d" % [viewport_size.x, viewport_size.y]
	MetaState.settings[TouchInput.TOUCH_KEY] = true
	TouchInput.refresh()
	# **Measured on the canvas the game hands them.** Every one of these is
	# opened from the main menu or the Hold, which switch the portrait menu
	# layout on - a narrower canvas, so the words are larger - and the pause
	# menu is opened on a road, which does not. Measured on the road's canvas
	# instead, an upright phone read as passing while the real screens did not.
	ScreenFit.set_menu_layout(true)
	for _f: int in 3:
		await get_tree().process_frame
	_view = get_viewport().get_visible_rect()
	RunState.reset()
	RunState.gain_every_currency(500)
	for entry: Array in _screens:
		await _measure_screen(String(entry[0]), entry[1] as GDScript)
	await _measure_the_glass_closes()
	await _measure_settings()
	await _measure_scene("MainMenu", "res://scenes/ui/main_menu.tscn")
	ScreenFit.set_menu_layout(false)
	for _f: int in 3:
		await get_tree().process_frame
	_view = get_viewport().get_visible_rect()
	await _measure_pause_menu()
	MetaState.resume_saves()
	if _failures == 0:
		print("[mobile-fit] PASS - %d checks at %s: every pressable control on the screen and clear of the next, and a way out of every screen" % [_checks, _shape])
	else:
		push_error("[mobile-fit] FAIL - %d problem(s) at %s" % [_failures, _shape])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _settle() -> void:
	# Autowrapped text knows its height only once it has its width, and a
	# container re-lays after its children do: a few frames, in seconds.
	for _f: int in 6:
		await get_tree().process_frame


func _measure_screen(label: String, script: GDScript) -> void:
	var screen: Node = script.new()
	add_child(screen)
	await get_tree().process_frame
	if screen.has_method("open"):
		screen.call("open")
	await _settle()
	_measure(label, screen, true)
	screen.queue_free()
	await get_tree().process_frame


func _measure_scene(label: String, path: String) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	add_child(scene)
	await _settle()
	_measure(label, scene, false)
	scene.queue_free()
	await get_tree().process_frame


func _measure_pause_menu() -> void:
	var menu: PauseMenu = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	add_child(menu)
	await get_tree().process_frame
	menu.set_showing(true)
	await _settle()
	_measure("PauseMenu", menu, true)
	menu.set_showing(false)
	get_tree().paused = false
	menu.queue_free()
	await get_tree().process_frame


func _measure_settings() -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.size = _view.size
	add_child(host)
	var panel := SettingsPanel.new()
	host.add_child(panel)
	await get_tree().process_frame
	if panel.has_method("open"):
		panel.call("open")
	await _settle()
	_measure("SettingsPanel", panel, true)
	host.queue_free()
	await get_tree().process_frame


## **The one a new account cannot get past**: Done on the screen, pressable,
## and closing the glass when pressed.
func _measure_the_glass_closes() -> void:
	var glass := WardenGlass.new()
	add_child(glass)
	await get_tree().process_frame
	glass.open()
	await _settle()
	var done := glass.find_child("Done", true, false) as Button
	_check(done != null, "the Warden's Glass has no Done button")
	if done != null:
		var rect: Rect2 = done.get_global_rect()
		_check(_view.grow(TOLERANCE).encloses(rect),
			"the Glass's Done button is off the screen at %s (%s)" % [_shape, rect])
		_check(done.is_visible_in_tree() and not done.disabled, "the Glass's Done button cannot be pressed")
		done.pressed.emit()
		await get_tree().process_frame
		_check(not glass.visible, "pressing Done did not close the Glass")
	var stage := glass.find_child("Stage", true, false) as Control
	if stage != null:
		_check(stage.size.x >= 120.0 and stage.size.y >= 120.0,
			"the Glass's Warden is shown %s at %s - too small to see who is being made" % [stage.size, _shape])
	# **The choices themselves are on the screen.** An upright phone gave the
	# Warden the height and left the body, skin and hair pickers a scroll of
	# nothing - which no rectangle rule above can see, because a scroll of
	# nothing holds no buttons to measure.
	var choices := glass.find_child("Choices", true, false) as Control
	_check(choices != null, "the Glass has no Choices scroll")
	if choices != null:
		_check(choices.size.y >= 160.0,
			"the Glass's choices are given %.0f units at %s - nothing to choose from" % [choices.size.y, _shape])
	glass.queue_free()
	await get_tree().process_frame


## The rules, over every pressable control the screen shows.
func _measure(label: String, root: Node, wants_exit: bool) -> void:
	var loose: Array[Control] = []
	var exits: int = 0
	for node: Node in _all(root):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if not _pressable(control):
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x < 1.0 or rect.size.y < 1.0:
			continue
		var name_lower: String = String(control.name).to_lower()
		var text_lower: String = String((control as Button).text).to_lower() if control is Button else ""
		var scroll: ScrollContainer = _scroll_of(control)
		if scroll == null:
			_check(_view.grow(TOLERANCE).encloses(rect),
				"%s at %s: %s is off the screen (%s)" % [label, _shape, _path(root, control), rect])
			loose.append(control)
		else:
			var window: Rect2 = scroll.get_global_rect()
			_check(_view.grow(TOLERANCE).encloses(window),
				"%s at %s: the scroll holding %s is off the screen (%s)" % [label, _shape, _path(root, control), window])
			if scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
				_check(rect.position.x >= window.position.x - TOLERANCE and rect.end.x <= window.end.x + TOLERANCE,
					"%s at %s: %s hangs off the side of a scroll that cannot scroll sideways (%s in %s)"
						% [label, _shape, _path(root, control), rect, window])
		if name_lower in ["done", "close", "back", "leave", "closebutton"] \
				or text_lower in ["done", "close", "back", "leave", "resume", "return", "take the road"]:
			if _view.grow(TOLERANCE).encloses(rect):
				exits += 1
	for i: int in loose.size():
		for j: int in range(i + 1, loose.size()):
			var a: Rect2 = loose[i].get_global_rect().grow(-TOLERANCE)
			var b: Rect2 = loose[j].get_global_rect().grow(-TOLERANCE)
			if a.intersects(b) and not loose[i].is_ancestor_of(loose[j]) and not loose[j].is_ancestor_of(loose[i]):
				_check(false, "%s at %s: %s lies under %s" % [label, _shape,
					_path(root, loose[i]), _path(root, loose[j])])
	if wants_exit:
		_check(exits > 0, "%s at %s has no Done, Close or Back on the screen" % [label, _shape])


func _pressable(control: Control) -> bool:
	if control is BaseButton:
		return not (control as BaseButton).disabled or true
	return control is Range and not control is ProgressBar or control is LineEdit \
		or control is OptionButton or control is TextEdit


func _scroll_of(control: Control) -> ScrollContainer:
	var at: Node = control.get_parent()
	while at != null:
		if at is ScrollContainer:
			return at as ScrollContainer
		at = at.get_parent()
	return null


func _all(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		out.append(node)
		for child: Node in node.get_children():
			stack.append(child)
	return out


func _path(root: Node, node: Node) -> String:
	var path: String = String(root.get_path_to(node))
	return path if path.length() < 90 else "..." + path.right(87)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[mobile-fit] " + why)
