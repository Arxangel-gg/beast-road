class_name DisciplinesScreen
extends CanvasLayer
## The Warden's Disciplines, drawn as a trunk: one arm at a time, its five
## clusters left to right - Basic, Core, Guard, Ultimate, Oath - each skill
## with its enhancement branching off it and its two forks off that
## (docs/SKILL_TREE_D4_2026-09-28.md).
##
## **The tree is the account's and this is where it is shaped** (owner rulings
## R1 and R5, 2026-09-26). A node may be learned here or at the Hero Mansion on
## the road; it is **let go only here**, between roads, and letting go is free.
##
## **The screen decides nothing.** Every rule - the points, the clusters, a
## branch's skill, a fork's twin, the ranks, the one Oath, the free pair, the
## loadout's slots - is asked of `MetaState` through the same doors the Mansion
## and `discipline_check` use, and the page re-reads the account after every
## press rather than keeping a copy.
##
## The radial map of phase 1 could not hold a hundred and thirty nodes at a
## readable size; a trunk is what the owner named, and a fork is what the eye
## reads as a choice.

signal closed

const GOLD: Color = Color("e8a33d")
const INK: Color = Color("f2e6d0")
const QUIET: Color = Color("8f9b98")
const LEARNED: Color = Color("9fd48a")
## Each arm's colour, by `DisciplineNodeData.Discipline`.
const ARM_COLOURS: Array[Color] = [Color("c8453a"), Color("f0d27a"), Color("e07a2e"),
	Color("7fa8ff")]

## What the page says under its heading, in the Hold and on the road.
const HOLD_SUB: String = ("Kept between roads. Learn here or at the Hero Mansion on the road; "
	+ "letting go is free, and only here. Points spent in an arm open its next cluster; "
	+ "a skill's enhancement hangs off it, and one of its two forks off that.")
const ROAD_SUB: String = ("The same tree the Hold draws. On the road it only grows: learn "
	+ "here in Preparation with the Mansion standing, and put a skill in its slot; letting "
	+ "go is the Hold's, between roads. Points spent in an arm open its next cluster.")

## **Opened from the Hero Mansion on the road** (owner, 2026-10-06: "Full
## Disciplines tree and skill points should be accessible during runs in the
## town scope view from the Hero Mansion"). The same screen, the same nodes,
## the same `MetaState` doors - behind the road's own two rules: a node is
## learned in Preparation with the Mansion standing
## (`RunState.try_learn_discipline`), a skill is slotted and a form taken up
## through `try_equip_discipline` and `try_choose_form` so the bar hears it,
## the arms open against the act this run is in, and letting go stays the
## Hold's (`unlearn_problem` refuses on a live road; the reset is not
## offered). Set before `open()`; `TownPanel` sets it and nothing else does.
var on_road: bool = false
const SLOT_NAMES: Array[String] = ["Attack", "Defense", "Power", "Ultimate"]
## How a skill's branches stand round it, in node sizes: the enhancement this
## far to the right, the forks this far again and this far up and down.
const BRANCH_STEP: float = 1.3
const FORK_RISE: float = 0.72
## A cluster's column, in node sizes, and the room a passive row takes.
const CLUSTER_WIDTH: float = 4.4
const ROW_HEIGHT: float = 1.7
const HEADER_HEIGHT: float = 34.0

var _panel: PanelContainer
var _split: BoxContainer
var _map: Control
## **The tree scrolls rather than shrinks on a thumb** (2026-10-01). On an
## upright phone the five clusters shared the width and a node came out a
## third of a fingertip; past `UI_DISCIPLINE_NODE_TOUCH_MIN` the map keeps its
## node size and this scrolls it, sideways and down.
var _map_scroll: ScrollContainer
## Where the Warden's column ends and how wide a cluster's column is, decided
## by `_layout_map` and read by `_draw_map`, so the trunk is drawn where the
## nodes stand.
var _root_wide: float = 120.0
var _column_wide: float = 160.0
var _stage: WardenStage
var _nodes: Dictionary = {}
var _node_size: float = 40.0
var _arm: int = 0
var _tabs: Array[Button] = []
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
## Every form of the chain, one button each (2026-09-30).
var _primaries: HFlowContainer
var _reset_button: Button
var _close_button: Button
var _selected: String = ""
## The node the pointer is resting on and how long it has rested, for the dwell
## (`Balance.DISCIPLINE_HOVER_DWELL`). Empty when the pointer is on nothing.
var _dwell_id: String = ""
var _dwell_held: float = 0.0
var _reset_armed: bool = false


func _ready() -> void:
	UiJuice.enrol.call_deferred(get_tree(), self)
	layer = 93
	visible = false
	_build()
	get_viewport().size_changed.connect(_refit)


# --- Building ------------------------------------------------------------------

## **The screen's own buttons - the arms and the way out - sized here for the
## screen it is on** (owner, 2026-10-01: *"ensure all of the UIs are perfect on
## mobile"*). Inflated to a thumb's full height they were taller than a phone
## held sideways, and Done was drawn below it.
var _chrome: Array[Control] = []
var _sub: Label = null


func _keep_sized(control: Control) -> void:
	control.set_meta(UiMetrics.SELF_SIZED, true)
	_chrome.append(control)


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
	UiFonts.set_role(heading, UiFonts.Role.TITLE, 28)
	heading.add_theme_color_override("font_color", GOLD)
	column.add_child(heading)
	_points = Label.new()
	_points.name = "Points"
	_points.add_theme_font_size_override("font_size", 15)
	_points.add_theme_color_override("font_color", INK)
	_points.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_points)
	var sub := Label.new()
	sub.text = HOLD_SUB
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", QUIET)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(sub)
	_sub = sub

	var tabs := HBoxContainer.new()
	tabs.name = "Arms"
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	for arm: int in DisciplineNodeData.DISCIPLINE_NAMES.size():
		var tab := Button.new()
		tab.name = "Arm%s" % DisciplineNodeData.DISCIPLINE_NAMES[arm]
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(120.0, 36.0)
		tab.add_theme_color_override("font_color", ARM_COLOURS[arm])
		tab.add_theme_color_override("font_pressed_color", INK)
		tab.pressed.connect(_show_arm.bind(arm))
		tabs.add_child(tab)
		_tabs.append(tab)
		_keep_sized(tab)

	_split = BoxContainer.new()
	_split.name = "Split"
	_split.add_theme_constant_override("separation", 14)
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_split)

	_map_scroll = ScrollContainer.new()
	_map_scroll.name = "MapScroll"
	UiMetrics.prepare_scroll(_map_scroll, TouchInput.is_showing())
	# Both ways: a tree too wide for an upright screen and too deep for a
	# sideways one. The vertical rail stays the contract's.
	_map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_scroll.custom_minimum_size = Vector2(360.0, 360.0)
	_map_scroll.resized.connect(_layout_map)
	_split.add_child(_map_scroll)
	_map = Control.new()
	_map.name = "Map"
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.clip_contents = true
	_map.draw.connect(_draw_map)
	_map_scroll.add_child(_map)

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
	_keep_sized(_reset_button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(gap)
	_close_button = Button.new()
	_close_button.name = "Done"
	_close_button.text = "Done"
	_close_button.custom_minimum_size = Vector2(140.0, 44.0)
	_close_button.pressed.connect(close)
	actions.add_child(_close_button)
	_keep_sized(_close_button)
	_refit()


func _node_button(node: DisciplineNodeData) -> TextureButton:
	var button := TextureButton.new()
	button.name = "Node_%s" % node.id
	# Sized by the map's own layout, never inflated for a thumb: a node a
	# thumb's height tall overlapped every node under it on a phone.
	button.set_meta(UiMetrics.SELF_SIZED, true)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = Control.FOCUS_ALL
	var path: String = node.get_sprite_path()
	if ResourceLoader.exists(path):
		button.texture_normal = load(path) as Texture2D
	button.tooltip_text = node.display_name
	var id: String = node.id
	button.pressed.connect(_select.bind(id))
	# The pad's focus selects at once - it moves only when somebody means it to.
	# A pointer passing over on its way to the buttons on the right does not: it
	# has to rest for the dwell, and leaving before then changes nothing. The
	# focus a hover hands a button is not a pad's, so it is told apart by
	# whether the pointer is the one resting there.
	button.focus_entered.connect(func() -> void:
		if _dwell_id != id:
			_select(id))
	button.mouse_entered.connect(_begin_dwell.bind(id))
	button.mouse_exited.connect(_end_dwell.bind(id))
	_nodes[id] = button
	return button


func _build_detail(detail: VBoxContainer) -> void:
	_detail_name = Label.new()
	_detail_name.name = "NodeName"
	UiFonts.set_role(_detail_name, UiFonts.Role.HEADING, 22)
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
	# **The primary attack, chosen directly** (owner, 2026-09-30). Every form
	# of the chain as a button: free to take up once its arm is open.
	var primary := Label.new()
	primary.text = "PRIMARY"
	primary.add_theme_font_size_override("font_size", 14)
	primary.add_theme_color_override("font_color", GOLD)
	detail.add_child(primary)
	_primaries = HFlowContainer.new()
	_primaries.name = "Primaries"
	_primaries.add_theme_constant_override("h_separation", 4)
	_primaries.add_theme_constant_override("v_separation", 4)
	detail.add_child(_primaries)


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
	if _sub != null:
		_sub.text = ROAD_SUB if on_road else HOLD_SUB
	_stage.show_look(WardenLook.worn())
	_stage.reset_turn()
	if _selected.is_empty():
		_selected = MetaState.discipline_form
	var chosen: DisciplineNodeData = ContentDB.discipline_node(_selected)
	_show_arm(chosen.discipline if chosen != null else 0)
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
	# Side by side where there is width for both; stacked on an upright screen.
	_split.vertical = screen.x < screen.y * 1.1
	var wide: float = minf(screen.x * 0.96, 1280.0)
	# An upright screen gives the tree its height, as it does the Glass.
	var cap: float = maxf(820.0, screen.x * Balance.UI_UPRIGHT_PANEL_ASPECT) if _split.vertical else 820.0
	var tall: float = minf(screen.y * 0.94, cap)
	_panel.custom_minimum_size = Vector2(wide, tall)
	# A short screen gives up the explanation and sizes the arms and the way
	# out to fit, as the Glass does.
	var short: bool = screen.y < Balance.UI_GLASS_SHORT_SCREEN
	var touch: bool = TouchInput.is_showing()
	var button_height: float = Balance.UI_GLASS_BUTTON_DESKTOP
	if touch:
		button_height = Balance.UI_GLASS_BUTTON_SHORT if short else Balance.UI_GLASS_BUTTON_TOUCH
	for control: Control in _chrome:
		control.custom_minimum_size.y = button_height
	if _sub != null:
		_sub.visible = not short
	# **The map takes what is left** - the split fills the panel - rather than
	# demanding a floor of its own: a floor worked out against a mouse's
	# buttons put Done below a touch screen's edge once the buttons grew.
	var map_wide: float = wide - 400.0 if not _split.vertical else wide - 40.0
	var map_tall: float = 160.0 if not _split.vertical else tall * 0.48
	_map_scroll.custom_minimum_size = Vector2(maxf(map_wide, 320.0), map_tall)


# --- The map -------------------------------------------------------------------

## Shows one arm's trunk. The other arms' buttons are hidden rather than
## removed, so every node keeps its button and the loadout can find any of them.
func _show_arm(arm: int) -> void:
	_arm = clampi(arm, 0, DisciplineNodeData.DISCIPLINE_NAMES.size() - 1)
	for index: int in _tabs.size():
		_tabs[index].button_pressed = index == _arm
	_layout_map()
	_refresh()


## The skills and forms of a cluster in this arm, each with its branches, and
## the passives after them: what one column holds, top to bottom.
func _column(arm: int, ring: int) -> Array[DisciplineNodeData]:
	var out: Array[DisciplineNodeData] = []
	var nodes: Array[DisciplineNodeData] = ContentDB.discipline_nodes_sorted()
	for node: DisciplineNodeData in nodes:
		if node.discipline == arm and node.ring == ring \
				and node.kind in [DisciplineNodeData.Kind.SKILL, DisciplineNodeData.Kind.FORM,
					DisciplineNodeData.Kind.OATH]:
			out.append(node)
	for node: DisciplineNodeData in nodes:
		if node.discipline == arm and node.ring == ring and node.kind == DisciplineNodeData.Kind.PASSIVE:
			out.append(node)
	return out


## A branch's place beside the node it hangs off: the enhancement to the right,
## a fork to the right of that and up or down.
func _branches_of(skill: DisciplineNodeData) -> Array[DisciplineNodeData]:
	var out: Array[DisciplineNodeData] = []
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.kind == DisciplineNodeData.Kind.UPGRADE and node.parent_id == skill.id:
			out.append(node)
	return out


func _layout_map() -> void:
	# The map's first resize arrives while it is being built, before the Warden
	# and the nodes stand on it; `_build` lays it out once they do.
	if _stage == null:
		return
	var clusters: int = DisciplineNodeData.CLUSTER_NAMES.size()
	# The root's column holds the Warden; the clusters share the rest.
	#
	# **The Warden is scaled to the column, never cut by it** (owner,
	# 2026-09-30: *"Player avatar cutoff bug in disciplines at the Hold"*).
	# The stage drew the figure at the Glass's scale - some 256 pixels tall -
	# in a box 120 wide and 120 tall, so the map showed a torso. The column is
	# a little wider, the stage takes most of the map's height, and the figure
	# is fitted to that height.
	# The visible window, which the content fills when it fits and outgrows,
	# scrolling, when a node would come out too small to press.
	var window: Vector2 = _map_scroll.size if _map_scroll != null and _map_scroll.size.x > 1.0 else _map.size
	var root_wide: float = minf(window.x * 0.15, 150.0)
	var room: float = window.x - root_wide
	# **As large as the width allows and no taller than the height does**: a
	# column of rows taller than the map ran its last nodes under each other.
	var deepest: float = 0.0
	for ring: int in range(1, clusters + 1):
		var depth: float = 0.0
		for node: DisciplineNodeData in _column(_arm, ring):
			depth += ROW_HEIGHT if node.kind == DisciplineNodeData.Kind.PASSIVE else FORK_RISE * 2.0 + 1.1
		deepest = maxf(deepest, depth)
	var by_height: float = (window.y - HEADER_HEIGHT - 8.0) / maxf(deepest, 1.0)
	_node_size = clampf(minf(room / (float(clusters) * CLUSTER_WIDTH), by_height), 18.0, 54.0)
	_node_size = maxf(_node_size, smallest_node())
	var column_wide: float = maxf(room / float(clusters), _node_size * CLUSTER_WIDTH)
	var content: Vector2 = Vector2(root_wide + column_wide * float(clusters),
		maxf(window.y, HEADER_HEIGHT + 8.0 + deepest * _node_size + _node_size))
	# Grown only when it has to: a content as wide as the window adds no rail.
	var wanted: Vector2 = Vector2(maxf(content.x - 1.0, 0.0), maxf(content.y - 1.0, 0.0))         if content.x > window.x + 1.0 or content.y > window.y + 1.0 else Vector2.ZERO
	if not _map.custom_minimum_size.is_equal_approx(wanted):
		_map.custom_minimum_size = wanted
	_root_wide = root_wide
	_column_wide = column_wide
	var map_tall: float = maxf(content.y, window.y)
	var stage_tall: float = clampf((window.y - HEADER_HEIGHT) * 0.72, 120.0, root_wide * 2.2)
	_stage.size = Vector2(root_wide * 0.92, stage_tall)
	_stage.position = Vector2(root_wide * 0.04,
		HEADER_HEIGHT + (window.y - HEADER_HEIGHT) * 0.5 - stage_tall * 0.5)
	_stage.fit_height(stage_tall)
	for id: String in _nodes:
		(_nodes[id] as TextureButton).visible = false
	for ring: int in range(1, clusters + 1):
		var column_x: float = root_wide + column_wide * float(ring - 1)
		var rows: Array[DisciplineNodeData] = _column(_arm, ring)
		var tall: float = 0.0
		for node: DisciplineNodeData in rows:
			tall += _node_size * (ROW_HEIGHT if node.kind == DisciplineNodeData.Kind.PASSIVE
				else FORK_RISE * 2.0 + 1.1)
		var y: float = maxf((map_tall - HEADER_HEIGHT - tall) * 0.5 + HEADER_HEIGHT, HEADER_HEIGHT + _node_size)
		for node: DisciplineNodeData in rows:
			var passive: bool = node.kind == DisciplineNodeData.Kind.PASSIVE
			var row_tall: float = _node_size * (ROW_HEIGHT if passive else FORK_RISE * 2.0 + 1.1)
			var at: Vector2 = Vector2(column_x + _node_size * 0.9, y + row_tall * 0.5)
			_place(node.id, at)
			var step: float = _node_size * BRANCH_STEP
			var branches: Array[DisciplineNodeData] = _branches_of(node)
			for branch: DisciplineNodeData in branches:
				_place(branch.id, at + Vector2(step, 0.0))
				var forks: Array[DisciplineNodeData] = _branches_of(branch)
				for index: int in forks.size():
					var rise: float = (float(index) - float(forks.size() - 1) * 0.5) * 2.0 * FORK_RISE * _node_size
					_place(forks[index].id, at + Vector2(step * 2.0, rise))
			y += row_tall
	_map.queue_redraw()


## The smallest a node may be drawn: a fingertip on a touch layout, and the
## old floor otherwise, so a desktop's map is exactly what it was.
static func smallest_node() -> float:
	return Balance.UI_DISCIPLINE_NODE_TOUCH_MIN if TouchInput.is_showing() else 18.0


## The visible window onto the map, for a gate.
func map_scroll() -> ScrollContainer:
	return _map_scroll


func _place(id: String, at: Vector2) -> void:
	var button: TextureButton = _nodes.get(id, null)
	if button == null:
		return
	button.visible = true
	button.size = Vector2(_node_size, _node_size)
	button.position = at - button.size * 0.5


func _centre_of(id: String) -> Vector2:
	var button: TextureButton = _nodes.get(id, null)
	return button.position + button.size * 0.5 if button != null else Vector2.ZERO


func _draw_map() -> void:
	var font: Font = UiFonts.face(UiFonts.Role.HEADING)
	var clusters: int = DisciplineNodeData.CLUSTER_NAMES.size()
	var root_wide: float = _root_wide
	var column_wide: float = _column_wide
	var colour: Color = ARM_COLOURS[_arm]
	var depth: int = int(MetaState.discipline_depth().get(_arm, 0))
	# The trunk: one line through the clusters, lit as far as the arm is open.
	var trunk_y: float = HEADER_HEIGHT * 0.5 + 6.0
	for ring: int in range(1, clusters + 1):
		var x: float = root_wide + column_wide * float(ring - 1)
		var needed: int = Balance.DISCIPLINE_RING_DEPTH[clampi(ring - 1, 0, Balance.DISCIPLINE_RING_DEPTH.size() - 1)]
		var open: bool = depth >= needed and MetaState.discipline_open(_arm)
		var tint: Color = colour if open else Color(QUIET, 0.7)
		_map.draw_line(Vector2(x, trunk_y), Vector2(x + column_wide - 6.0, trunk_y),
			Color(tint, 0.35), 2.0, true)
		var label: String = DisciplineNodeData.CLUSTER_NAMES[ring - 1].to_upper()
		if not open:
			label += "  ·  %d IN %s" % [needed, DisciplineNodeData.DISCIPLINE_NAMES[_arm].to_upper()]
		_map.draw_string(font, Vector2(x + 4.0, trunk_y - 6.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)
		if ring > 1:
			_map.draw_line(Vector2(x, HEADER_HEIGHT), Vector2(x, _map.size.y),
				Color(QUIET, 0.12), 1.0, true)
	# The arm's own name at the root, over the Warden.
	var open_arm: bool = MetaState.discipline_open(_arm)
	var title: String = DisciplineNodeData.DISCIPLINE_NAMES[_arm].to_upper()
	if not open_arm:
		title += "  ·  ACT %s" % RunState.act_numeral(Balance.DISCIPLINE_OPENS_AT_ACT[_arm])
	_map.draw_string(font, Vector2(6.0, trunk_y - 6.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		colour if open_arm else Color(QUIET, 0.7))
	# The branches: a line from every branch to what it hangs off.
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.discipline != _arm or node.kind != DisciplineNodeData.Kind.UPGRADE:
			continue
		if not _nodes.has(node.parent_id) or not (_nodes[node.id] as TextureButton).visible:
			continue
		var lit: bool = MetaState.owns_discipline(node.id)
		_map.draw_line(_centre_of(node.parent_id), _centre_of(node.id),
			Color(colour, 0.85 if lit else 0.3), 2.5 if lit else 1.5, true)
	# Each node's plate: lit in its arm's colour when learned, rimmed when open,
	# dark when closed; the selected one wears gold; a passive says its rank.
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.discipline != _arm or not (_nodes[node.id] as TextureButton).visible:
			continue
		var at: Vector2 = _centre_of(node.id)
		var radius: float = _node_size * 0.62
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
		if node.is_oath() and MetaState.owns_discipline(node.id):
			_map.draw_arc(at, radius + 5.0, 0.0, TAU, 40, GOLD, 2.0, true)
		if node.is_form() and node.id == MetaState.discipline_form \
				or (node.is_active_slot() and MetaState.discipline_loadout[node.slot_index()] == node.id):
			_map.draw_arc(at, radius + 4.0, 0.0, TAU, 32, INK, 1.5, true)
		if node.ranks > 1:
			var rank: int = MetaState.discipline_rank(node.id)
			_map.draw_string(font, at + Vector2(-radius, radius + 12.0), "%d/%d" % [rank, node.ranks],
				HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 11, INK if rank > 0 else QUIET)
		if node.id == _selected:
			_map.draw_arc(at, radius + 7.0, 0.0, TAU, 40, GOLD, 3.0, true)
		elif node.id == _dwell_id and dwell_share() > 0.0:
			# The rest, filling clockwise from the top toward the selection.
			_map.draw_arc(at, radius + 7.0, -PI * 0.5, -PI * 0.5 + TAU * dwell_share(), 40,
				Color(GOLD, 0.75), 3.0, true)


## "learned" (at its top rank), "open" - learnable, or a rank up - or "closed".
func _state(id: String) -> String:
	if MetaState.reach_problem(id, _run_act()) == "Already learned.":
		return "learned"
	if MetaState.owns_discipline(id):
		return "learned" if not MetaState.learn_problem(id, _run_act()).is_empty() else "open"
	return "open" if MetaState.reach_problem(id, _run_act()).is_empty() else "closed"


## The act the arms are read against: the run's on the road, so the Arcane
## opens on the road that fells the first boss (2026-09-21); the account's
## furthest in the Hold, which `MetaState` reads for a zero.
func _run_act() -> int:
	return RunState.act if on_road else 0


## Why Learn is refused for this node, from wherever the screen stands. On the
## road the Mansion's own rules come first - Preparation, the Mansion standing
## - and then the account's, read against the act this run is in.
func _learn_problem(id: String) -> String:
	if on_road:
		var refused: String = RunState.learn_road_problem()
		if not refused.is_empty():
			return refused
	return MetaState.learn_problem(id, _run_act())


# --- The page ------------------------------------------------------------------

func _refresh() -> void:
	var from_levels: int = MetaState.skill_points_for_level(MetaState.hero_level)
	var from_clears: int = MetaState.first_clears_count() * Balance.SKILL_POINTS_PER_FIRST_CLEAR
	var free: int = MetaState.skill_points_free()
	_points.text = "%d skill point%s to spend   ·   %d earned: %d from levels, %d from first clears" % [
		free, "" if free == 1 else "s", from_levels + from_clears, from_levels, from_clears]
	for index: int in _tabs.size():
		var arm_depth: int = int(MetaState.discipline_depth().get(index, 0))
		_tabs[index].text = "%s  ·  %d" % [DisciplineNodeData.DISCIPLINE_NAMES[index], arm_depth]
		if not MetaState.discipline_open(index, _run_act()):
			_tabs[index].text = "%s  ·  Act %s" % [DisciplineNodeData.DISCIPLINE_NAMES[index],
				RunState.act_numeral(Balance.DISCIPLINE_OPENS_AT_ACT[index])]
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
	_build_primaries()
	var anything: bool = not MetaState.discipline_tree.is_empty()
	# Reshaping is the Hold's, between roads (2026-09-26).
	_reset_button.visible = not on_road
	_reset_button.disabled = not anything
	_reset_button.text = "Press again to let it all go" if _reset_armed else "Let the whole tree go"
	_map.queue_redraw()


func _begin_dwell(id: String) -> void:
	_dwell_id = id
	_dwell_held = 0.0
	if _map != null:
		_map.queue_redraw()


func _end_dwell(id: String) -> void:
	if _dwell_id != id:
		return
	_dwell_id = ""
	_dwell_held = 0.0
	if _map != null:
		_map.queue_redraw()


## Counts the pointer's rest and selects the node once it has rested long
## enough. The ring that fills around the node while it does is the dwell said
## out loud: a selection that changes a second after the pointer stops, with
## nothing on screen saying why, reads as lag.
func _process(delta: float) -> void:
	if not visible or _dwell_id.is_empty():
		return
	if _dwell_id == _selected:
		return
	_dwell_held += delta
	if _dwell_held >= Balance.DISCIPLINE_HOVER_DWELL:
		var id: String = _dwell_id
		_dwell_held = 0.0
		_select(id)
	if _map != null:
		_map.queue_redraw()


## How far the pointer's rest has come, 0 to 1, or 0 when nothing is resting.
func dwell_share() -> float:
	if _dwell_id.is_empty() or _dwell_id == _selected:
		return 0.0
	return clampf(_dwell_held / Balance.DISCIPLINE_HOVER_DWELL, 0.0, 1.0)


func _select(id: String) -> void:
	if _selected == id:
		return
	_selected = id
	_reset_armed = false
	var node: DisciplineNodeData = ContentDB.discipline_node(id)
	if node != null and node.discipline != _arm:
		_show_arm(node.discipline)
		return
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
	var meta: String = "%s  ·  %s  ·  %s" % [node.discipline_name(), node.cluster_name(), _kind_name(node)]
	if node.ranks > 1:
		meta += "  ·  rank %d of %d" % [MetaState.discipline_rank(node.id), node.ranks]
	_detail_meta.text = meta
	_detail_tags.text = "  ·  ".join(node.tags) if not node.tags.is_empty() else ""
	_detail_tags.visible = not node.tags.is_empty()
	_detail_text.text = node.description
	var owned: bool = MetaState.owns_discipline(node.id)
	var problem: String = _learn_problem(node.id)
	var topped: bool = owned and MetaState.discipline_rank(node.id) >= node.ranks
	if topped:
		_detail_state.text = "Learned." if not Balance.DISCIPLINE_STARTERS.has(node.id) \
			else "Learned - every Warden begins with it."
		if node.is_oath():
			_detail_state.text = "Sworn."
		_detail_state.add_theme_color_override("font_color", LEARNED)
	elif problem.is_empty():
		_detail_state.text = ("Open - one skill point." if not owned
			else "Rank %d - one skill point for the next." % MetaState.discipline_rank(node.id))
		if node.is_oath():
			_detail_state.text = ("Open - one skill point, and the only Oath you may hold."
				if MetaState.oaths_allowed() == 1
				else "Open - one skill point. Gatebroken, you may hold two.")
		_detail_state.add_theme_color_override("font_color", GOLD)
	else:
		_detail_state.text = problem
		_detail_state.add_theme_color_override("font_color", QUIET)
	_learn_button.visible = not topped
	_learn_button.text = "Swear" if node.is_oath() else ("Learn" if not owned else "Rank up")
	_learn_button.disabled = not problem.is_empty()
	_learn_button.tooltip_text = problem
	_forget_button.visible = owned and not Balance.DISCIPLINE_STARTERS.has(node.id)
	_forget_button.text = "Let go" if MetaState.discipline_rank(node.id) <= 1 else "Let a rank go"
	var forget_problem: String = MetaState.unlearn_problem(node.id) if owned else ""
	_forget_button.disabled = not forget_problem.is_empty()
	_forget_button.tooltip_text = forget_problem
	# A form is free to take up once its arm is open, learned or not; a skill
	# still has to be learned before it can sit in a slot.
	_use_button.visible = (node.is_form() and MetaState.form_problem(node.id, _run_act()).is_empty()) \
		or (owned and node.is_active_slot())
	if node.is_form():
		var here: bool = MetaState.discipline_form == node.id
		_use_button.text = "Your primary attack" if here else "Make this your primary attack"
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
			var root: DisciplineNodeData = ContentDB.discipline_node(DisciplineUpgrades.root_of(node))
			var what: String = root.display_name if root != null else node.parent_id
			if node.is_fork():
				return "a fork of %s - one of two" % what
			return "enhances %s" % (parent.display_name if parent != null else node.parent_id)
		DisciplineNodeData.Kind.OATH:
			return "an Oath - a boon paid for with a bane"
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
	var sworn: Array[DisciplineNodeData] = MetaState.sworn_oaths()
	for which: int in MetaState.oaths_allowed():
		_loadout_row("Oath" if MetaState.oaths_allowed() == 1 else "Oath %d" % (which + 1),
			sworn[which] if which < sworn.size() else null)


## One button a form: the one in use lit, a closed arm's disabled with why.
func _build_primaries() -> void:
	if _primaries == null:
		return
	for child: Node in _primaries.get_children():
		_primaries.remove_child(child)
		child.queue_free()
	for node: DisciplineNodeData in MetaState.chain_forms():
		var id: String = node.id
		var button := Button.new()
		button.name = "Primary_%s" % id
		button.text = node.display_name
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0.0, 32.0)
		button.set_pressed_no_signal(MetaState.discipline_form == id)
		button.add_theme_color_override("font_color", ARM_COLOURS[node.discipline])
		var problem: String = MetaState.form_problem(id, _run_act())
		button.disabled = not problem.is_empty()
		button.tooltip_text = problem if not problem.is_empty() else (
			"%s - the %s form of the chain. Free to take up; learn it to open its branches."
			% [node.display_name, node.discipline_name()])
		button.pressed.connect(func() -> void:
			if on_road:
				RunState.try_choose_form(id)
			else:
				MetaState.set_discipline_form(id)
			_refresh())
		_primaries.add_child(button)


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
	if node == null:
		return
	var refused: String = (RunState.try_learn_discipline(_selected) if on_road
		else MetaState.learn_discipline(_selected))
	if not refused.is_empty():
		# Said on the page rather than swallowed: the state line reads the
		# reason off the same door on the next refresh.
		_refresh()
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
		if on_road:
			RunState.try_choose_form(node.id)
		else:
			MetaState.set_discipline_form(node.id)
	elif node.is_active_slot():
		if on_road:
			RunState.try_equip_discipline(node.id)
		else:
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
