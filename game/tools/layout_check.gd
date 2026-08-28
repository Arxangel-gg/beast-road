extends Node

## Finds UI that overlaps or overflows, without anybody having to play the game.
##
## Three separate bugs were reported in one message and they are all the same
## bug: "the command widget is overlapping the skills", "there's a progressbar
## that's overlapped by skills", "skill icons are not properly padded within the
## buttons but overflow, same with text". Every one of them is two rectangles in
## the wrong relationship, and every one was found by a human noticing it on
## screen — which is the most expensive way to find a rectangle.
##
##   godot --path game res://tools/layout_check.tscn --resolution 1920x1080
##
## Two checks, and the second is the one that repays the effort:
##
## **Overflow** — a Control whose combined minimum size is larger than the size
## it was given. That is the definitive form of "the text does not fit in the
## button": Godot has computed what the content needs and the layout gave it
## less. It cannot be argued with and it cannot be a matter of taste.
##
## **Overlap** — two widgets from different branches of the tree covering the
## same pixels. This one needs judgement, because plenty of overlap is intended:
## a label sits inside its panel, a dim layer covers the screen on purpose. So it
## only compares *leaf widgets* — the things that draw content — ignores
## anything containing the other, and ignores full-screen scrims.
##
## Run windowed. Control rects are only meaningful once a real viewport has laid
## them out; headless reports zero sizes for everything and would pass silently.

## Ignore overlaps smaller than this. Adjacent widgets in a container routinely
## share a boundary pixel, and a gate that fires on those gets switched off.
const OVERLAP_TOLERANCE: float = 6.0

## Anything at least this large in both axes is treated as a backdrop rather than
## a widget: dim layers, scrims and full-screen panels are meant to sit under
## things.
const BACKDROP_FRACTION: float = 0.75

## How much clear space two separate panels need between them. Below this they
## read as one crowded mass however the geometry is measured.
const MIN_PANEL_GAP: float = 18.0

var _failures: PackedStringArray = []
var _notes: PackedStringArray = []
var _touch_layout: bool = false
var _dump: bool = false


func _ready() -> void:
	var viewport_size := Vector2i.ZERO
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--touch=on":
			_touch_layout = true
		elif argument == "--dump":
			_dump = true
		elif argument.begins_with("--viewport="):
			var dimensions: PackedStringArray = argument.trim_prefix("--viewport=").split("x")
			if dimensions.size() == 2:
				viewport_size = Vector2i(dimensions[0].to_int(), dimensions[1].to_int())
	if viewport_size.x > 0 and viewport_size.y > 0:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = viewport_size
	if _touch_layout:
		MetaState.settings[TouchInput.TOUCH_KEY] = true
		# **Refreshed before the run is built, not after.** A real device has its
		# touch state settled long before a scene loads, and the HUD reads it
		# while constructing - it decides there whether the action bar is one row
		# or two. Refreshing afterwards measured a layout built for a mouse and
		# then told it a thumb had arrived.
		TouchInput.refresh()
		ScreenFit._fit()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset()
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	var run: Node = load("res://scenes/run/run.tscn").instantiate()
	add_child(run)
	# Several frames: containers resolve their children's sizes over more than
	# one, and measuring too early reports the pre-layout zeros as overflow.
	for _f: int in 8:
		await get_tree().process_frame
	if _touch_layout:
		TouchInput.refresh()
		for _f: int in 4:
			await get_tree().process_frame

	# The build panel is closed until a slot is clicked, so a check that only
	# looks at the resting screen never sees the busiest interface in the game -
	# and reported a clean sweep while the panel it was meant to be checking was
	# not on screen. Every reported layout fault so far has been in this panel.
	_open_build_panel(run)
	for _f: int in 8:
		await get_tree().process_frame

	var widgets: Array[Control] = _visible_widgets()
	_notes.append("%d visible widgets" % widgets.size())

	_check_overflow(widgets)
	_check_overlap(widgets)
	_check_on_screen(widgets)
	_check_crowding(widgets)
	if _touch_layout:
		_check_touch_targets(widgets)
	await _check_hover_stability()

	if _dump:
		# Ground truth for a layout complaint. A screenshot says "cut off"; this
		# says which control, how tall it is and where its edges are, in the same
		# units the constants are written in.
		var screen: Vector2 = get_viewport().get_visible_rect().size
		print("[layout] viewport %.0fx%.0f" % [screen.x, screen.y])
		for control: Control in widgets:
			if not control.is_visible_in_tree():
				continue
			var rect: Rect2 = control.get_global_rect()
			var off: bool = rect.position.y < -1.0 or rect.end.y > screen.y + 1.0 				or rect.position.x < -1.0 or rect.end.x > screen.x + 1.0
			print("[dump] %-34s %7.1fx%-7.1f at %7.1f,%-7.1f%s" % [
				_named(control), rect.size.x, rect.size.y,
				rect.position.x, rect.position.y, "   OFF-SCREEN" if off else ""])

	for note: String in _notes:
		print("[layout] %s" % note)
	for problem: String in _failures:
		push_error(problem)
	print("[layout] %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	_bail(1 if not _failures.is_empty() else 0)


## A touch layout is only real if the controls themselves grew. Measuring the
## rectangles catches a visually enlarged parent whose child hit boxes remained
## desktop-sized — the exact failure that prompted the responsive pass.
func _check_touch_targets(widgets: Array[Control]) -> void:
	var checked: int = 0
	var undersized: int = 0
	var screen: Rect2 = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	for control: Control in widgets:
		if not control is BaseButton or not control.is_visible_in_tree():
			continue
		var rect: Rect2 = control.get_global_rect()
		if not screen.intersects(rect) or bool((control as BaseButton).disabled):
			continue
		checked += 1
		# Measured in the control's own space rather than in screen pixels.
		#
		# `canvas_items` stretch scales the whole interface by window/base, so a
		# global rect is the layout size times that ratio - and the ratio in a
		# headless run is whatever size the window happened to open at. That made
		# a 120px minimum measure 118.2 and fail, which is a property of the test
		# window rather than of the button. The floor is written in the same units
		# `custom_minimum_size` is, so it is compared against the same units.
		var target: float = float(control.get_meta(UiMetrics.TOUCH_TARGET_HEIGHT,
			Balance.UI_TOUCH_MIN_TARGET_HEIGHT))
		if control.size.y + 1.0 < target:
			undersized += 1
			_failures.append("touch target: %s is %.0fpx tall, minimum is %.0fpx" % [
				_named(control), control.size.y, target])
	_notes.append("touch targets: %d checked, %d undersized" % [checked, undersized])


## Content that needs more room than it was given.
func _check_overflow(widgets: Array[Control]) -> void:
	var found: int = 0
	for control: Control in widgets:
		var needed: Vector2 = control.get_combined_minimum_size()
		var got: Vector2 = control.size
		# A one pixel shortfall is rounding, not a layout fault.
		var short_x: float = needed.x - got.x
		var short_y: float = needed.y - got.y
		if short_x <= 1.0 and short_y <= 1.0:
			continue
		found += 1
		_failures.append("overflow: %s (%s) needs %.0fx%.0f, has %.0fx%.0f" % [
			_path_of(control), control.get_class(),
			needed.x, needed.y, got.x, got.y])
	_notes.append("overflow: %d" % found)


## Leaf widgets from different branches covering the same pixels.
## Nothing interactive may hang off the edge of the screen.
##
## Added after the fourth spell slot shipped with a sliver of it showing and the
## rest off-screen: the bar's box was a number typed once and never re-derived
## when a slot was added. Overlap checking cannot see this - a widget outside the
## viewport overlaps nothing at all, so the layout looked perfectly clean.
##
## Widgets partly off the edge are the failure; ones entirely outside are usually
## deliberate (an off-screen panel waiting to slide in), so they are ignored.
func _check_on_screen(widgets: Array[Control]) -> void:
	var screen: Rect2 = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var clipped: int = 0
	for control: Control in widgets:
		if not _is_leaf_widget(control) or not control.is_visible_in_tree():
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if not screen.intersects(rect):
			continue
		var inside: Rect2 = screen.intersection(rect)
		var shown: float = (inside.size.x * inside.size.y) 			/ maxf(rect.size.x * rect.size.y, 1.0)
		if shown < 0.995:
			clipped += 1
			_failures.append("off screen: %s%s at %s size %s - only %.0f%% visible"
				% [control.get_parent().name if control.get_parent() != null else "?",
					"/" + control.name, rect.position, rect.size, shown * 100.0])
	_notes.append("off screen: %d" % clipped)


func _check_overlap(widgets: Array[Control]) -> void:
	var leaves: Array[Control] = []
	var screen: Vector2 = get_viewport().get_visible_rect().size
	for control: Control in widgets:
		if not _is_leaf_widget(control):
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		# Backdrops are supposed to be underneath things.
		if rect.size.x >= screen.x * BACKDROP_FRACTION \
				and rect.size.y >= screen.y * BACKDROP_FRACTION:
			continue
		leaves.append(control)

	var found: int = 0
	var reported: Dictionary = {}
	for i: int in leaves.size():
		for j: int in range(i + 1, leaves.size()):
			var a: Control = leaves[i]
			var b: Control = leaves[j]
			# One inside the other is nesting, not collision.
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			# Deliberate stacking is not a bug, and telling the two apart is the
			# whole difficulty. The rule: find where the two branches meet.
			#
			# If they meet at a *container*, the container laid both out - and
			# containers do not overlap their own children, so an overlap there is
			# real. If they meet at a plain Control, that Control is a hand-built
			# frame whose job is to stack things: the plate behind a spell slot,
			# the label over a bar. Those are intended.
			#
			# Without this the check reported sixty overlaps, almost all of them
			# the spell slots working exactly as designed.
			if _stacked_on_purpose(a, b):
				continue
			var shared: Rect2 = a.get_global_rect().intersection(b.get_global_rect())
			if shared.size.x <= OVERLAP_TOLERANCE or shared.size.y <= OVERLAP_TOLERANCE:
				continue
			# One widget overlapping an assembly hits every child of it, so the same
			# fault arrives nine times. Reported once per pair of assemblies: nine
			# copies of one bug reads as nine bugs, and whoever fixes it has to work
			# out for themselves that it is not.
			var pair: String = "%s|%s" % [_assembly_of(a), _assembly_of(b)]
			if reported.has(pair):
				continue
			reported[pair] = true
			found += 1
			_failures.append("overlap: %s%s at %s over %s%s at %s by %.0fx%.0f" % [
				_path_of(a), _describe(a), a.get_global_rect().position,
				_path_of(b), _describe(b), b.get_global_rect().position,
				shared.size.x, shared.size.y])
	_notes.append("overlap: %d" % found)


## Assemblies that do not overlap but sit too close to read as separate.
##
## Reported: "the preparation box overlaps the warhorn, raid and repair town
## buttons". The rectangles never actually intersected, so the overlap check was
## right to stay silent and useless to the person looking at the screen - two
## panels with four pixels between them read as touching whatever the geometry
## says.
##
## So proximity is its own fault. Only between separate assemblies, and only
## where they genuinely face each other: widgets side by side in a container are
## meant to be close, and a gate that says otherwise would fire on every toolbar
## in the game.
func _check_crowding(widgets: Array[Control]) -> void:
	var panels: Array[Control] = []
	for control: Control in widgets:
		# Panels are the things a player perceives as boxes. Comparing every label
		# to every other one measures nothing anybody can see.
		if control is PanelContainer and control.is_visible_in_tree():
			panels.append(control)

	var found: int = 0
	for i: int in panels.size():
		for j: int in range(i + 1, panels.size()):
			var a: Rect2 = panels[i].get_global_rect()
			var b: Rect2 = panels[j].get_global_rect()
			if a.intersects(b):
				continue  # already the overlap check's business
			var gap: float = _gap_between(a, b)
			if gap >= MIN_PANEL_GAP:
				continue
			found += 1
			_failures.append("crowding: %s and %s are %.0fpx apart, want %.0f" % [
				_path_of(panels[i]), _path_of(panels[j]), gap, MIN_PANEL_GAP])
	_notes.append("crowding: %d" % found)


## Opens the tower build panel, which is where the interface is densest and where
## every layout complaint so far has come from. Reaching for a private is the
## point of a tool: the alternative is synthesising a click on a world-space
## button, which tests the click and not the layout.
func _open_build_panel(run: Node) -> void:
	var hud := run.get("hud") as HUD
	if hud == null:
		_failures.append("no HUD on the run, so the build panel was never checked")
		return
	# Free placement: open the panel on a real legal tile rather than on a slot
	# index that no longer exists.
	var field: Battlefield = run.get("battlefield") as Battlefield
	hud._open_build_panel(field.free_anchor_near(0) if field != null else Vector2i.ZERO)


## Panels that change size when the cursor lands on something.
##
## Reported as "some UI boxes resize based on hover", and neither of the checks
## above can see it: they measure one still frame, and the fault only exists
## between two of them.
##
## It is always the same mistake. A hover writes a longer string into a label
## that was given a `custom_minimum_size` and no ceiling - and a minimum is a
## floor, not a cap, so the label grows, its panel grows with it, and the row the
## player was reading about moves out from under the cursor. The build footer
## reserved thirty pixels for text that wrapped to sixty.
##
## So: hover everything hoverable, and require that every panel is the size it
## was before.
func _check_hover_stability() -> void:
	var panels: Array[Control] = []
	var before: Array[Vector2] = []
	for node: Node in _all(get_tree().root):
		var panel := node as PanelContainer
		if panel != null and panel.is_visible_in_tree() and _is_interface(panel):
			panels.append(panel)
			before.append(panel.size)

	var hovered: int = 0
	var found: int = 0
	var reported: Dictionary = {}
	for node: Node in _all(get_tree().root):
		var button := node as Button
		if button == null or not button.is_visible_in_tree() \
				or not _is_interface(button) \
				or not button.mouse_entered.has_connections():
			continue
		hovered += 1
		button.mouse_entered.emit()
		# Containers resolve over more than one frame, so a size change caused by
		# the hover is not necessarily visible on the frame it was caused.
		await get_tree().process_frame
		await get_tree().process_frame

		for i: int in panels.size():
			if not is_instance_valid(panels[i]):
				continue
			var grew: Vector2 = panels[i].size - before[i]
			if absf(grew.x) <= 1.0 and absf(grew.y) <= 1.0:
				continue
			# One panel that resizes does so for every button in it, so the same
			# fault would otherwise be reported once per row.
			var path: String = _path_of(panels[i])
			if reported.has(path):
				continue
			reported[path] = true
			found += 1
			_failures.append("hover resize: %s changed by %.0fx%.0f when %s was hovered" % [
				path, grew.x, grew.y, _path_of(button)])

		button.mouse_exited.emit()
		await get_tree().process_frame

	_notes.append("hover: %d hoverable widgets, %d resized a panel" % [hovered, found])


## Shortest distance between two non-overlapping rectangles.
func _gap_between(a: Rect2, b: Rect2) -> float:
	var dx: float = maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dy: float = maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	# Diagonal separation is fine; only near-alignment on one axis reads as
	# crowding, which is what taking the larger of the two gives.
	return maxf(dx, dy)


## The widget group a control belongs to - its nearest Container, or itself.
## Two members of the same group are one thing as far as a report is concerned.
func _assembly_of(control: Control) -> String:
	var node: Node = control
	while node != null:
		if node is Container:
			return String(node.get_path())
		node = node.get_parent()
	return String(control.get_path())


## Things that draw their own content, as opposed to things that arrange others.
##
## Containers and plain Controls are excluded because their rects are layout
## scaffolding: two HBoxes sharing space is how a screen is built, not a bug.
## True when the two meet at something whose purpose is to layer them.
func _stacked_on_purpose(a: Control, b: Control) -> bool:
	var common: Node = _common_ancestor(a, b)
	return common != null and common is Control and not (common is Container)


func _common_ancestor(a: Node, b: Node) -> Node:
	var chain: Array[Node] = []
	var node: Node = a
	while node != null:
		chain.append(node)
		node = node.get_parent()
	node = b
	while node != null:
		if chain.has(node):
			return node
		node = node.get_parent()
	return null


func _is_leaf_widget(control: Control) -> bool:
	return control is Button or control is ProgressBar \
		or control is Label or control is TextureRect


func _visible_widgets() -> Array[Control]:
	var found: Array[Control] = []
	for layer: Node in _all(get_tree().root):
		var control := layer as Control
		if control == null or not control.is_visible_in_tree():
			continue
		# Only real interface. The build spots are Buttons living in the world, so
		# without this every tower slot "overlaps" whatever HUD text happens to be
		# in front of it - which is what a HUD is for.
		if not _is_interface(control):
			continue
		if control.size.x <= 0.0 and control.size.y <= 0.0:
			continue
		if _clipped_away(control):
			continue
		# A label with nothing in it draws nothing. The HUD keeps several
		# reserved for messages that are not currently showing, and they are
		# full-width - so an empty one "covers" whatever is beneath it in every
		# frame where there is no message, which is most of them.
		if control is Label and (control as Label).text.strip_edges().is_empty():
			continue
		if control is RichTextLabel 				and (control as RichTextLabel).get_parsed_text().strip_edges().is_empty():
			continue
		found.append(control)
	return found


## Whether an ancestor that clips has scrolled this control out of sight.
##
## A `ScrollContainer` keeps its children's layout rectangles wherever the list
## puts them and simply does not draw the parts outside itself. Read as geometry
## that is what it looks like when a list overlaps everything below it, so the
## build sheet's tower list "covered" the ability bar the moment the sheet
## learned to scroll. Nothing is drawn there and nothing can be pressed there.
func _clipped_away(control: Control) -> bool:
	var rect: Rect2 = control.get_global_rect()
	var parent: Node = control.get_parent()
	while parent != null:
		var box := parent as Control
		if box != null and box.clip_contents:
			if not box.get_global_rect().intersects(rect):
				return true
		parent = parent.get_parent()
	return false


## Under a CanvasLayer, which is where this project puts its interface.
func _is_interface(control: Control) -> bool:
	var node: Node = control
	while node != null:
		if node is CanvasLayer:
			return true
		node = node.get_parent()
	return false


## Autogenerated node names like `@Button@631` identify nothing to a person
## reading a failure, so a widget is described by what it says on screen.
func _describe(control: Control) -> String:
	if control is Button:
		return " \"%s\"" % (control as Button).text
	if control is Label:
		return " \"%s\"" % (control as Label).text
	if control is TextureRect:
		var texture: Texture2D = (control as TextureRect).texture
		return " <%s>" % (texture.resource_path.get_file() if texture != null else "no texture")
	return ""


## Enough of the path to find the node, without the full root chain.
func _path_of(control: Control) -> String:
	var parts: PackedStringArray = []
	var node: Node = control
	for _depth: int in 3:
		if node == null:
			break
		parts.insert(0, node.name)
		node = node.get_parent()
	return "/".join(parts)


func _bail(code: int) -> void:
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for child: Node in get_children():
		child.queue_free()
	for _frame: int in 40:
		await get_tree().process_frame
	get_tree().quit(code)


func _all(from: Node) -> Array[Node]:
	var found: Array[Node] = [from]
	for child: Node in from.get_children():
		found.append_array(_all(child))
	return found


## A control described by what it says, not by where it sits in the tree.
##
## `@Button@861` names nothing a person can act on. The label is what identifies
## a control to whoever has to go and fix it.
func _named(control: Control) -> String:
	var text: String = ""
	if control is Button:
		text = (control as Button).text
	if text.is_empty():
		text = control.tooltip_text.split("
")[0]
	if text.is_empty():
		return _path_of(control)
	return "%s \"%s\"" % [_path_of(control), text.substr(0, 32)]
