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


func _ready() -> void:
	MetaState.settings[TouchInput.TOUCH_KEY] = true
	TouchInput.refresh()
	for shape: Vector2i in SHAPES:
		await _sweep(shape)
	_finish()


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

		# 3. Thumb-sized, measured in the control's own units.
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
		break

	if screen.has_method("hide_screen"):
		screen.call("hide_screen")
	elif screen is CanvasLayer:
		(screen as CanvasLayer).visible = false
	elif screen is Control:
		(screen as Control).visible = false
	await _settle()


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
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 30:
		await get_tree().process_frame
	if _failures == 0:
		print("[menu-layout] PASS - %d screen openings across %d phone shapes, "
			% [_checked, SHAPES.size()]
			+ "every way out fully on screen and every control thumb-sized")
	else:
		push_error("[menu-layout] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[menu-layout] FAIL: %s" % why)
