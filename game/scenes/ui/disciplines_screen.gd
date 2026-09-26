class_name DisciplinesScreen
extends CanvasLayer

## The Warden's Disciplines, drawn as what they are: four arms around the
## Warden, opening outward in rings.
##
## **The tree is the account's and this is where it is shaped** (owner rulings
## R1 and R5, 2026-09-26; `docs/SKILL_TREE_REWORK_2026-09-26.md`). A node may be
## learned here or at the Hero Mansion on the road; it is **let go only here**,
## between roads, and letting go is free - a build rebuilt at every Preparation
## is not a build, and a build that costs Food to rethink is one nobody tries.
##
## **The screen decides nothing.** Every rule - the points, the rings, an
## upgrade's skill, the free pair, the loadout's slots - is asked of `MetaState`
## through the same doors the Mansion and `discipline_check` use, and the page
## re-reads the account after every press rather than keeping a copy.
##
## Counted, not graphed, and the drawing says so: a ring is a circle, and what
## opens it is how much of its own arm is learned, so there are no lines between
## nodes to follow except an upgrade's to the skill it changes.

signal closed

const GOLD: Color = Color("e8a33d")
const INK: Color = Color("f2e6d0")
const QUIET: Color = Color("8f9b98")
const LEARNED: Color = Color("9fd48a")
## Each arm's colour, by `DisciplineNodeData.Discipline`.
const ARM_COLOURS: Array[Color] = [Color("c8453a"), Color("f0d27a"), Color("e07a2e"),
	Color("7fa8ff")]
## Where each arm points, in degrees clockwise from the right: Blood to the
## left, Holy above, Berserk to the right, the Arcane below.
const ARM_ANGLES: Array[float] = [180.0, 270.0, 0.0, 90.0]
## The most a ring's nodes may spread round their arm, in degrees. Inside it
## they are spaced by their own size at that radius (`NODE_GAP` apart), so a
## ring near the Warden, where a node is a wide angle, still clears the next
## arm - a fixed arc put the first rings of neighbouring arms on top of each
## other on a small map.
const ARM_SPREAD: float = 62.0
const NODE_GAP: float = 1.2
## Each ring's radius, as a share of the map's half-size, from the Warden out.
const RING_RADII: Array[float] = [0.46, 0.68, 0.88, 0.98]
const SLOT_NAMES: Array[String] = ["Attack", "Defense", "Power", "Ultimate"]

var _panel: PanelContainer
var _split: BoxContainer
var _map: Control
var _stage: WardenStage
var _nodes: Dictionary = {}
var _node_size: float = 46.0
var _points: Label
var _detail_name: Label
var _detail_meta: Label
var _detail_tags: Label
var _detail_text: Label
var _detail_state: Label
var _learn_button: Button
var _forget_button: Button
var _use_button: Button
var _loadout: VBoxContainer
var _reset_button: Button
var _close_button: Button
var _selected: String = ""
var _reset_armed: bool = false


func _ready() -> void:
	UiJuice.enrol.call_deferred(get_tree(), self)
	layer = 93
	visible = false
	_build()
	get_viewport().size_changed.connect(_refit)


# --- Building ------------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.03, 0.03, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.name = "Disciplines"
	_panel.set_meta(UiMetrics.SELF_SIZED, true)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)

	var heading := Label.new()
	heading.text = "THE DISCIPLINES"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", GOLD)
	column.add_child(heading)
	_points = Label.new()
	_points.name = "Points"
	_points.add_theme_font_size_override("font_size", 15)
	_points.add_theme_color_override("font_color", INK)
	_points.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_points)
	var sub := Label.new()
	sub.text = ("Kept between roads. Learn here or at the Hero Mansion on the road; "
		+ "letting go is free, and only here. Each ring opens when enough of its own arm is learned.")
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", QUIET)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(sub)

	_split = BoxContainer.new()
	_split.name = "Split"
	_split.add_theme_constant_override("separation", 14)
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_split)

	_map = Control.new()
	_map.name = "Map"
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.custom_minimum_size = Vector2(360.0, 360.0)
	_map.clip_contents = true
	_map.draw.connect(_draw_map)
	_map.resized.connect(_layout_map)
	_split.add_child(_map)

	_stage = WardenStage.new()
	_stage.name = "Warden"
	_stage.turntable = false
	_map.add_child(_stage)
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		_map.add_child(_node_button(node))
	_layout_map()

	var scroll := ScrollContainer.new()
	scroll.name = "Detail"
	UiMetrics.prepare_scroll(scroll, TouchInput.is_showing())
	scroll.custom_minimum_size = Vector2(340.0, 0.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(scroll)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(detail)
	_build_detail(detail)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	_reset_button = Button.new()
	_reset_button.name = "Reset"
	_reset_button.text = "Let the whole tree go"
	_reset_button.tooltip_text = "Free, between roads: every point back, the first form taken up again"
	_reset_button.custom_minimum_size = Vector2(0.0, 44.0)
	_reset_button.pressed.connect(_reset)
	actions.add_child(_reset_button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(gap)
	_close_button = Button.new()
	_close_button.name = "Done"
	_close_button.text = "Done"
	_close_button.custom_minimum_size = Vector2(140.0, 44.0)
	_close_button.pressed.connect(close)
	actions.add_child(_close_button)
	_refit()


func _node_button(node: DisciplineNodeData) -> TextureButton:
	var button := TextureButton.new()
	button.name = "Node_%s" % node.id
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = Control.FOCUS_ALL
	var path: String = node.get_sprite_path()
	if ResourceLoader.exists(path):
		button.texture_normal = load(path) as Texture2D
	button.tooltip_text = node.display_name
	var id: String = node.id
	button.pressed.connect(_select.bind(id))
	button.focus_entered.connect(_select.bind(id))
	button.mouse_entered.connect(_select.bind(id))
	_nodes[id] = button
	return button


func _build_detail(detail: VBoxContainer) -> void:
	_detail_name = Label.new()
	_detail_name.name = "NodeName"
	_detail_name.add_theme_font_size_override("font_size", 22)
	_detail_name.add_theme_color_override("font_color", GOLD)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_detail_name)
	_detail_meta = _quiet_line(detail, 13, QUIET)
	_detail_tags = _quiet_line(detail, 13, Color("c9b98f"))
	_detail_text = _quiet_line(detail, 15, INK)
	_detail_state = _quiet_line(detail, 14, LEARNED)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	detail.add_child(row)
	_learn_button = _action(row, "Learn", _learn)
	_forget_button = _action(row, "Let go", _forget)
	_use_button = Button.new()
	_use_button.name = "Use"
	_use_button.custom_minimum_size = Vector2(0.0, 40.0)
	_use_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_use_button.pressed.connect(_use)
	detail.add_child(_use_button)

	var heading := Label.new()
	heading.text = "LOADOUT"
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", GOLD)
	detail.add_child(heading)
	_loadout = VBoxContainer.new()
	_loadout.name = "Loadout"
	_loadout.add_theme_constant_override("separation", 4)
	detail.add_child(_loadout)


func _quiet_line(into: Control, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	into.add_child(label)
	return label


func _action(into: Control, text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.name = text.replace(" ", "")
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 40.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(handler)
	into.add_child(button)
	return button


# --- Opening and closing -------------------------------------------------------

func open() -> void:
	visible = true
	_reset_armed = false
	_stage.show_look(WardenLook.worn())
	_stage.reset_turn()
	if _selected.is_empty():
		_selected = MetaState.discipline_form
	_refresh()
	_close_button.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _refit() -> void:
	if _panel == null:
		return
	var screen: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	var wide: float = minf(screen.x * 0.96, 1240.0)
	var tall: float = minf(screen.y * 0.94, 800.0)
	_panel.custom_minimum_size = Vector2(wide, tall)
	# Side by side where there is width for both; stacked on an upright screen.
	_split.vertical = screen.x < screen.y * 1.1
	var map_side: float = minf(tall - 170.0, wide - 380.0) if not _split.vertical \
		else minf(wide - 40.0, tall * 0.52)
	_map.custom_minimum_size = Vector2(maxf(map_side, 260.0), maxf(map_side, 260.0))


# --- The map -------------------------------------------------------------------

## Where each node stands: its arm's direction, its ring's radius, spread round
## the arm by kind and id so the same tree always draws the same way.
func _layout_map() -> void:
	# The map's first resize arrives while it is being built, before the Warden
	# and the nodes stand on it; `_build` lays it out once they do.
	if _stage == null:
		return
	var half: float = minf(_map.size.x, _map.size.y) * 0.5
	var middle: Vector2 = _map.size * 0.5
	_node_size = clampf(half * 0.17, 30.0, 54.0)
	var reach: float = half - _node_size * 0.6
	var stage_side: float = reach * RING_RADII[0] * 1.2
	_stage.size = Vector2(stage_side, stage_side * 1.1)
	_stage.position = middle - _stage.size * 0.5
	for arm: int in ARM_ANGLES.size():
		for ring: int in range(1, 5):
			var here: Array[DisciplineNodeData] = []
			for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
				if node.discipline == arm and node.ring == ring:
					here.append(node)
			var radius: float = reach * RING_RADII[ring - 1]
			var spread: float = minf(ARM_SPREAD, float(here.size() - 1)
				* rad_to_deg(_node_size / maxf(radius, 1.0)) * NODE_GAP)
			for index: int in here.size():
				var share: float = 0.5 if here.size() == 1 \
					else float(index) / float(here.size() - 1)
				var degrees: float = ARM_ANGLES[arm] + (share - 0.5) * spread
				var at: Vector2 = middle + Vector2.RIGHT.rotated(deg_to_rad(degrees)) * radius
				var button: TextureButton = _nodes.get(here[index].id, null)
				if button != null:
					button.size = Vector2(_node_size, _node_size)
					button.position = at - button.size * 0.5
	_map.queue_redraw()


func _centre_of(id: String) -> Vector2:
	var button: TextureButton = _nodes.get(id, null)
	return button.position + button.size * 0.5 if button != null else Vector2.ZERO


func _draw_map() -> void:
	var half: float = minf(_map.size.x, _map.size.y) * 0.5
	var middle: Vector2 = _map.size * 0.5
	var reach: float = half - _node_size * 0.6
	# The rings, faint: a ring is a circle, never a path.
	for ring: int in 3:
		_map.draw_arc(middle, reach * RING_RADII[ring], 0.0, TAU, 96,
			Color(QUIET, 0.22), 2.0, true)
	# **The arms named in the corner, each beside a pointer its own way.** A name
	# written along its arm lands on a node or behind the Warden however it is
	# placed; the corner between Blood and Holy is empty ground on every size.
	var font: Font = ThemeDB.fallback_font
	for arm: int in ARM_ANGLES.size():
		var direction: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(ARM_ANGLES[arm]))
		var label: String = DisciplineNodeData.DISCIPLINE_NAMES[arm].to_upper()
		var open: bool = MetaState.discipline_open(arm)
		if not open:
			label += "  ·  ACT %s" % RunState.act_numeral(Balance.DISCIPLINE_OPENS_AT_ACT[arm])
		var colour: Color = ARM_COLOURS[arm] if open else Color(QUIET, 0.7)
		var tip: Vector2 = Vector2(13.0, 12.0 + 18.0 * arm)
		var side: Vector2 = direction.orthogonal() * 4.0
		_map.draw_colored_polygon(PackedVector2Array([tip + direction * 5.0,
			tip - direction * 4.0 + side, tip - direction * 4.0 - side]), colour)
		_map.draw_string(font, Vector2(24.0, tip.y + 5.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)
	# An upgrade's thread to the skill it changes: the only line on the map.
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.kind == DisciplineNodeData.Kind.UPGRADE and _nodes.has(node.parent_id):
			_map.draw_line(_centre_of(node.parent_id), _centre_of(node.id),
				Color(ARM_COLOURS[node.discipline], 0.45), 2.0, true)
	# Each node's plate: lit in its arm's colour when learned, rimmed when open,
	# dark when closed; the selected one wears gold.
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		var at: Vector2 = _centre_of(node.id)
		var radius: float = _node_size * 0.62
		var colour: Color = ARM_COLOURS[node.discipline]
		match _state(node.id):
			"learned":
				_map.draw_circle(at, radius, Color(colour, 0.55))
				_map.draw_arc(at, radius, 0.0, TAU, 32, LEARNED, 2.5, true)
			"open":
				_map.draw_circle(at, radius, Color(0.08, 0.09, 0.09, 0.9))
				_map.draw_arc(at, radius, 0.0, TAU, 32, Color(colour, 0.95), 2.0, true)
			_:
				_map.draw_circle(at, radius, Color(0.05, 0.05, 0.06, 0.9))
				_map.draw_arc(at, radius, 0.0, TAU, 32, Color(QUIET, 0.35), 1.5, true)
		if node.is_form() and node.id == MetaState.discipline_form \
				or (node.is_active_slot() and MetaState.discipline_loadout[node.slot_index()] == node.id):
			_map.draw_arc(at, radius + 4.0, 0.0, TAU, 32, INK, 1.5, true)
		if node.id == _selected:
			_map.draw_arc(at, radius + 7.0, 0.0, TAU, 40, GOLD, 3.0, true)


## "learned", "open" - learnable if a point is free - or "closed".
func _state(id: String) -> String:
	if MetaState.owns_discipline(id):
		return "learned"
	return "open" if MetaState.reach_problem(id).is_empty() else "closed"


# --- The page ------------------------------------------------------------------

func _refresh() -> void:
	var from_levels: int = MetaState.skill_points_for_level(MetaState.hero_level)
	var from_clears: int = MetaState.first_clears_count() * Balance.SKILL_POINTS_PER_FIRST_CLEAR
	var free: int = MetaState.skill_points_free()
	_points.text = "%d skill point%s to spend   ·   %d earned: %d from levels, %d from first clears" % [
		free, "" if free == 1 else "s", from_levels + from_clears, from_levels, from_clears]
	for id: String in _nodes:
		var button: TextureButton = _nodes[id]
		match _state(id):
			"learned":
				button.modulate = Color.WHITE
			"open":
				button.modulate = Color(0.88, 0.88, 0.88)
			_:
				button.modulate = Color(0.42, 0.42, 0.46, 0.85)
	_show_detail()
	_build_loadout()
	var anything: bool = not MetaState.discipline_tree.is_empty()
	_reset_button.disabled = not anything
	_reset_button.text = "Press again to let it all go" if _reset_armed else "Let the whole tree go"
	_map.queue_redraw()


func _select(id: String) -> void:
	if _selected == id:
		return
	_selected = id
	_reset_armed = false
	_show_detail()
	_reset_button.text = "Let the whole tree go"
	_map.queue_redraw()


func _show_detail() -> void:
	var node: DisciplineNodeData = ContentDB.discipline_node(_selected)
	if node == null:
		_detail_name.text = "Choose a node"
		for label: Label in [_detail_meta, _detail_tags, _detail_text, _detail_state]:
			label.text = ""
		for button: Button in [_learn_button, _forget_button, _use_button]:
			button.visible = false
		return
	_detail_name.text = node.display_name
	_detail_meta.text = "%s  ·  ring %s  ·  %s" % [node.discipline_name(),
		RunState.act_numeral(node.ring), _kind_name(node)]
	_detail_tags.text = "  ·  ".join(node.tags) if not node.tags.is_empty() else ""
	_detail_tags.visible = not node.tags.is_empty()
	_detail_text.text = node.description
	var owned: bool = MetaState.owns_discipline(node.id)
	var problem: String = MetaState.learn_problem(node.id)
	if owned:
		_detail_state.text = "Learned." if not Balance.DISCIPLINE_STARTERS.has(node.id) \
			else "Learned - every Warden begins with it."
		_detail_state.add_theme_color_override("font_color", LEARNED)
	elif problem.is_empty():
		_detail_state.text = "Open - one skill point."
		_detail_state.add_theme_color_override("font_color", GOLD)
	else:
		_detail_state.text = problem
		_detail_state.add_theme_color_override("font_color", QUIET)
	_learn_button.visible = not owned
	_learn_button.disabled = not problem.is_empty()
	_learn_button.tooltip_text = problem
	_forget_button.visible = owned and not Balance.DISCIPLINE_STARTERS.has(node.id)
	var forget_problem: String = MetaState.unlearn_problem(node.id) if owned else ""
	_forget_button.disabled = not forget_problem.is_empty()
	_forget_button.tooltip_text = forget_problem
	_use_button.visible = owned and (node.is_form() or node.is_active_slot())
	if node.is_form():
		var here: bool = MetaState.discipline_form == node.id
		_use_button.text = "The chain's form" if here else "Take up this form"
		_use_button.disabled = here
	elif node.is_active_slot():
		var here: bool = MetaState.discipline_loadout[node.slot_index()] == node.id
		_use_button.text = ("In the %s slot" if here else "Put in the %s slot") \
			% SLOT_NAMES[node.slot_index()]
		_use_button.disabled = here


func _kind_name(node: DisciplineNodeData) -> String:
	match node.kind:
		DisciplineNodeData.Kind.FORM:
			return "a form of the chain"
		DisciplineNodeData.Kind.PASSIVE:
			return "always on"
		DisciplineNodeData.Kind.UPGRADE:
			var parent: DisciplineNodeData = ContentDB.discipline_node(node.parent_id)
			return "changes %s" % (parent.display_name if parent != null else node.parent_id)
		DisciplineNodeData.Kind.OATH:
			return "an oath"
	return "%s skill" % node.slot_name()


## The form and the four slots, each pressable to find its node on the map.
func _build_loadout() -> void:
	for child: Node in _loadout.get_children():
		_loadout.remove_child(child)
		child.queue_free()
	var form: DisciplineNodeData = ContentDB.discipline_node(MetaState.discipline_form)
	_loadout_row("Form", form)
	for slot: int in SLOT_NAMES.size():
		var id: String = MetaState.discipline_loadout[slot]
		_loadout_row(SLOT_NAMES[slot], ContentDB.discipline_node(id) if not id.is_empty() else null)


func _loadout_row(label: String, node: DisciplineNodeData) -> void:
	var row := Button.new()
	row.name = "Loadout%s" % label
	row.text = "%s  ·  %s" % [label, node.display_name if node != null else "empty"]
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0.0, 36.0)
	row.disabled = node == null
	if node != null:
		var id: String = node.id
		row.pressed.connect(func() -> void:
			_select(id)
			var button: TextureButton = _nodes.get(id, null)
			if button != null:
				button.grab_focus())
	_loadout.add_child(row)


# --- What a press does ---------------------------------------------------------

func _learn() -> void:
	var node: DisciplineNodeData = ContentDB.discipline_node(_selected)
	if node == null or not MetaState.learn_discipline(_selected).is_empty():
		return
	_stage.flourish(ARM_COLOURS[node.discipline])
	_refresh()


func _forget() -> void:
	if MetaState.unlearn_discipline(_selected).is_empty():
		_refresh()


func _use() -> void:
	var node: DisciplineNodeData = ContentDB.discipline_node(_selected)
	if node == null:
		return
	if node.is_form():
		MetaState.set_discipline_form(node.id)
	elif node.is_active_slot():
		MetaState.set_discipline_slot(node.slot_index(), node.id)
	_refresh()


## Two presses, because it is every point at once - free, but not undoable.
func _reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_refresh()
		return
	_reset_armed = false
	MetaState.reset_disciplines()
	_refresh()
