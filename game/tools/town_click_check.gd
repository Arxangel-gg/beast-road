extends Node

## Every town plot can be clicked, including while a building sheet is open.
##
## Reported from play on 2026-09-08 as "some of the buildings in town on the
## bottom half seem to not be interactable". They were not: `UiMetrics.dock_panel`
## docks the sheet full-height down the *left* of the screen — 680x1036 of a
## 1920x1080 screen, by design — and the plot ring is centred on the viewport, so
## the left of the ring lands underneath it. A click there is swallowed by the
## panel instead of opening the building.
##
## It reads as "some of them" because which plots die depends on where the ring's
## rotation puts them and how wide the dock is at that resolution, so a player
## sees a couple of dead buildings rather than an obvious layout fault. Nothing
## caught it: `menu_layout_check` opens *menu* panels and measures their contents,
## and no gate had ever asked whether the world underneath a docked panel was
## still reachable.
##
## Clicks go through `viewport.push_input(event, true)`, which is what
## `menu_layout_check` uses. `Input.parse_input_event` does not reach the GUI
## system from a tool scene — it silently reports nothing hovered and nothing
## pressed, which cost three wrong diagnoses before the right method was used.

var _failures: int = 0
var _checked: int = 0

var _run: Node = null
var _town: Node2D = null
var _panel: Node = null
var _fired: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	RunState.reset()
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(_run)
	for _i: int in 12:
		await get_tree().process_frame
	_run.call("switch_scope", GameDirector.Scope.TOWN)
	for _i: int in 20:
		await get_tree().process_frame

	_town = _run.get("town")
	_panel = _run.get("town_panel")
	_town.connect("plot_selected", func(picked: String) -> void: _fired.append(picked))

	await _sweep("with no sheet open", "")
	# The state the bug lives in: the player opens one building, and the plots
	# the sheet now covers stop answering.
	await _sweep("with a sheet open", "forge")
	await _check_stash_reachable()
	_finish()


## The stash is reachable from inside a run, and reaching it does not stop the
## road. Added 2026-09-09 with the feature: `StashScreen` was menu-only, and the
## reason recorded in its own docstring was that "a run does not pause for
## shopping" - so the thing worth holding is not just that the button exists but
## that opening it leaves the battlefield running.
func _check_stash_reachable() -> void:
	_panel.call("open", "sanctum")
	for _s: int in 30:
		await get_tree().process_frame
	var button: Button = null
	for node: Node in _all(_panel):
		var b := node as Button
		if b != null and b.text.begins_with("Open the stash"):
			button = b
	_checked += 1
	_check(button != null, "the Hero Mansion offers no way into the stash")
	if button == null:
		return
	button.emit_signal("pressed")
	for _s: int in 30:
		await get_tree().process_frame
	var screen: CanvasLayer = null
	for node: Node in _all(_panel):
		if node is StashScreen:
			screen = node as CanvasLayer
	_checked += 1
	_check(screen != null and screen.visible, "the stash did not open in a run")
	_checked += 1
	_check(not get_tree().paused, "opening the stash paused the run")
	if screen != null:
		screen.call("hide_screen")
		for _s: int in 10:
			await get_tree().process_frame


func _all(from: Node) -> Array[Node]:
	var out: Array[Node] = [from]
	for c: Node in from.get_children():
		out.append_array(_all(c))
	return out


func _sweep(label: String, open_first: String) -> void:
	var plots: Dictionary = _town.get("_plots")
	for id: Variant in plots:
		if not open_first.is_empty():
			_panel.call("open", open_first)
		else:
			_panel.call("close")
		# The town eases out from under the sheet rather than snapping, so give
		# the slide time to finish before asking where anything is.
		for _s: int in 40:
			await get_tree().process_frame

		var plot: Node2D = plots[id] as Node2D
		var point: Vector2 = _town.get_viewport().get_canvas_transform() * plot.global_position
		_fired.clear()
		var move := InputEventMouseMotion.new()
		move.position = point
		move.global_position = point
		get_viewport().push_input(move, true)
		await get_tree().process_frame
		for pressed: bool in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = point
			click.global_position = point
			get_viewport().push_input(click, true)
			await get_tree().process_frame
		await get_tree().process_frame

		_checked += 1
		var got: String = ", ".join(_fired)
		_check(_fired.has(String(id)),
			"%s: clicking %s at %s selected %s" % [
				label, str(id), str(point.round()),
				got if not got.is_empty() else "nothing"])


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[town-click] %s" % why)


func _finish() -> void:
	if _failures == 0:
		print("[town-click] PASS - %d plot clicks across both sheet states land on "
			% _checked + "the building under the cursor")
	else:
		push_error("[town-click] FAIL - %d of %d clicks did not reach their plot"
			% [_failures, _checked])
	if is_instance_valid(_run):
		_run.queue_free()
	_run = null
	_town = null
	_panel = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)
