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
	await _measure_the_discipline_nodes()
	await _measure_the_glass_closes()
	await _measure_the_stash_shows_gear()
	await _measure_settings()
	await _measure_scene("MainMenu", "res://scenes/ui/main_menu.tscn")
	await _measure_the_hold()
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
	# Anchored and offset to the whole screen, never sized by hand: a size set
	# on a control stretched between its anchors is overridden after _ready
	# and says so as a warning, which the release bar reads as a failure.
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
## **A Discipline node is a fingertip on a thumb** (2026-10-01). Five clusters
## shared an upright phone's width and a node came out a third of one; the tree
## scrolls instead now, so every node of the arm on show is at least
## `UI_DISCIPLINE_NODE_TOUCH_MIN`, and the map's window is what scrolls.
func _measure_the_discipline_nodes() -> void:
	var screen := DisciplinesScreen.new()
	add_child(screen)
	await get_tree().process_frame
	screen.open()
	await _settle()
	var smallest: float = INF
	var shown: int = 0
	for node: Node in _all(screen):
		var button := node as TextureButton
		if button == null or not button.is_visible_in_tree():
			continue
		shown += 1
		smallest = minf(smallest, minf(button.size.x, button.size.y))
	_check(shown > 0, "Disciplines at %s: no node of the arm on show is visible" % _shape)
	_check(smallest >= Balance.UI_DISCIPLINE_NODE_TOUCH_MIN - 0.5,
		"Disciplines at %s: a node is %.0f across on a thumb, under the %.0f a fingertip needs"
			% [_shape, smallest, Balance.UI_DISCIPLINE_NODE_TOUCH_MIN])
	var scroll: ScrollContainer = screen.map_scroll()
	_check(scroll != null and _view.grow(TOLERANCE).encloses(scroll.get_global_rect()),
		"Disciplines at %s: the tree's window is off the screen" % _shape)
	screen.queue_free()
	await get_tree().process_frame


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


## **The Hold**, stood up by the real menu as a player reaches it, measured by
## the same rules - and its zoom row held to one more (owner, 2026-10-01: *"the
## zoom slider in the Hold in the bottom left corner should be centered
## vertically in the middle of the height of the buttons to the left and right
## of it"*): the slider's middle on the buttons' middle line.
func _measure_the_hold() -> void:
	var menu: Node = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await _settle()
	var hub := menu.get("_hub") as HubScreen
	_check(hub != null, "the real menu has no Hold to measure")
	if hub == null:
		menu.queue_free()
		await get_tree().process_frame
		return
	hub.open()
	await _settle()
	_measure("Hold", hub, false)
	var slider := hub.find_child("ZoomSlider", true, false) as Control
	var out := hub.find_child("ZoomOut", true, false) as Control
	var closer := hub.find_child("ZoomIn", true, false) as Control
	_check(slider != null and out != null and closer != null, "the Hold's zoom row is missing a part")
	if slider != null and out != null and closer != null:
		var middle: float = slider.get_global_rect().get_center().y
		for button: Control in [out, closer]:
			var line: float = button.get_global_rect().get_center().y
			_check(absf(middle - line) <= TOLERANCE,
				"the Hold's zoom slider sits %.0f units off the middle of %s at %s (slider %s, button %s)"
					% [middle - line, button.name, _shape, slider.get_global_rect(), button.get_global_rect()])
			_check(_view.grow(TOLERANCE).encloses(button.get_global_rect()),
				"the Hold's %s is off the screen at %s (%s)" % [button.name, _shape, button.get_global_rect()])
	menu.queue_free()
	await get_tree().process_frame


## **The stash shows gear on its first screen.** On a phone held sideways its
## seventeen tools, a thumb tall in three columns, were the whole first screen,
## and the gear the screen exists for was below them - which no rectangle rule
## above can see, because everything was on the screen and nothing overlapped.
## So a stash with gear in it is opened, and some row of gear must lie inside
## the list's window before anything is scrolled.
func _measure_the_stash_shows_gear() -> void:
	var kept: Array = MetaState.stash.duplicate(true)
	var kinds: Array = ContentDB.gear_kinds.keys()
	for index: int in 12:
		MetaState.stash.append(Stash.make(String(kinds[index % kinds.size()]), index % 4, 1))
	var stash := StashScreen.new()
	add_child(stash)
	await get_tree().process_frame
	stash.open()
	await _settle()
	await _settle()
	var scroll := stash.get("_scroll") as ScrollContainer
	var list := stash.get("_list") as Control
	_check(scroll != null and list != null, "the stash has no list to read")
	if scroll != null and list != null:
		var window: Rect2 = scroll.get_global_rect()
		var seen: int = 0
		for row: Node in list.get_children():
			var control := row as Control
			if control != null and control.is_visible_in_tree() \
					and window.intersection(control.get_global_rect()).size.y >= 24.0:
				seen += 1
		_check(seen > 0, "the stash at %s shows no gear before it is scrolled (the list's window is %s)"
			% [_shape, window])
	# **Folded, and every tool still reached.** On a thumb the bar opens the
	# filters and tools, each of them is held to the same rules as any screen,
	# and choosing a filter folds them again so the gear is back in view.
	var fold := stash.find_child("ToolsFold", true, false) as Button
	var tools := stash.get("_tools") as Control
	if fold != null and fold.is_visible_in_tree() and tools != null:
		_check(not tools.is_visible_in_tree(), "the stash's tools are open before the bar is pressed at %s" % _shape)
		fold.pressed.emit()
		await _settle()
		_check(tools.is_visible_in_tree(), "pressing the stash's bar did not open its tools at %s" % _shape)
		_measure("StashTools", stash, true)
		var tab: Button = null
		for child: Node in tools.get_children():
			var button := child as Button
			if button != null and button.toggle_mode:
				tab = button
				break
		if tab != null:
			tab.pressed.emit()
			await _settle()
			var refold := stash.find_child("ToolsFold", true, false) as Button
			var tools_now := stash.get("_tools") as Control
			_check(refold != null and tools_now != null and not tools_now.is_visible_in_tree(),
				"choosing a filter did not fold the stash's tools again at %s" % _shape)
	stash.queue_free()
	MetaState.stash.clear()
	MetaState.stash.append_array(kept)
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
