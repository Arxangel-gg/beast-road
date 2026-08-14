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


func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	add_child(load("res://scenes/run/run.tscn").instantiate())
	# Several frames: containers resolve their children's sizes over more than
	# one, and measuring too early reports the pre-layout zeros as overflow.
	for _f: int in 8:
		await get_tree().process_frame

	var widgets: Array[Control] = _visible_widgets()
	_notes.append("%d visible widgets" % widgets.size())

	_check_overflow(widgets)
	_check_overlap(widgets)
	_check_crowding(widgets)

	for note: String in _notes:
		print("[layout] %s" % note)
	for problem: String in _failures:
		push_error(problem)
	print("[layout] %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	_bail(1 if not _failures.is_empty() else 0)


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
			_failures.append("overlap: %s over %s by %.0fx%.0f" % [
				_path_of(a), _path_of(b), shared.size.x, shared.size.y])
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
		found.append(control)
	return found


## Under a CanvasLayer, which is where this project puts its interface.
func _is_interface(control: Control) -> bool:
	var node: Node = control
	while node != null:
		if node is CanvasLayer:
			return true
		node = node.get_parent()
	return false


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
