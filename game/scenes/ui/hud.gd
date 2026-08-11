class_name HUD
extends CanvasLayer

## The run's heads-up display (GDD §3, §6).
##
## Built in code rather than authored, because almost all of it is generated:
## four lane indicators, a build panel whose contents depend on what is standing
## either side of the slot, and a raid bar that only exists during a raid.
## The layout is greybox — real art replaces the Panel/Label styling wholesale.
##
## The directional pressure indicator is the one part that is not optional. The
## hero's entire decision loop reads off it; without it the player is guessing.

signal scope_requested(scope: GameDirector.Scope)
signal horn_requested()
signal raid_requested()
signal extract_requested()

const LANE_NAMES: Array[String] = ["N", "E", "S", "W"]

@export var battlefield: Battlefield

var _resources: Label
var _distance: Label
var _wave: Label
var _act: Label
var _town_bar: ProgressBar
var _hero_bar: ProgressBar
var _charge_bar: ProgressBar
var _horn_button: Button
var _raid_button: Button
var _message: Label
var _message_left: float = 0.0

var _lane_bars: Array[ProgressBar] = []
var _build_panel: PanelContainer
var _build_list: VBoxContainer
var _build_title: Label
var _selected_lane: int = -1
var _selected_slot: int = -1

var _raid_panel: PanelContainer
var _raid_status: Label
var _extract_button: Button
@export var raid: RaidArena


func _ready() -> void:
	_build_top_bar()
	_build_lane_ring()
	_build_scope_bar()
	_build_tower_panel()
	_build_raid_panel()

	EventBus.resources_changed.connect(func(v: int) -> void: _resources.text = "Resources  %d" % v)
	EventBus.distance_changed.connect(_on_distance)
	EventBus.town_health_changed.connect(_on_town_health)
	EventBus.hero_health_changed.connect(_on_hero_health)
	EventBus.raid_charge_changed.connect(_on_charge)
	EventBus.lane_pressure_changed.connect(_on_pressure)
	EventBus.wave_started.connect(_on_wave)
	EventBus.act_started.connect(_on_act)
	EventBus.raid_available.connect(func(_s: float) -> void: _raid_button.disabled = false)
	EventBus.war_horn_activated.connect(func(_d: float) -> void: _horn_button.disabled = true)
	EventBus.war_horn_ended.connect(func() -> void: _horn_button.disabled = false)
	EventBus.scope_changed.connect(_on_scope_changed)

	for node: Node in get_tree().get_nodes_in_group(TowerSlot.GROUP):
		var slot := node as TowerSlot
		if slot != null:
			slot.clicked.connect(_open_build_panel)

	_resources.text = "Resources  %d" % RunState.resources
	_on_act(RunState.act, RunState.terrain_id)


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.text = ""
	if _raid_panel.visible:
		_update_raid_panel()


# --- Construction -----------------------------------------------------------

func _label(text: String, size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 24.0
	bar.offset_top = 16.0
	bar.offset_right = -24.0
	bar.add_theme_constant_override("separation", 32)
	add_child(bar)

	_resources = _label("Resources  0")
	_distance = _label("Distance  0")
	_wave = _label("Wave  0")
	_act = _label("Act 1")
	for l: Label in [_act, _resources, _distance, _wave]:
		bar.add_child(l)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	_town_bar = _make_bar(Color("8a5a3a"), 240.0)
	bar.add_child(_label("Town"))
	bar.add_child(_town_bar)

	_hero_bar = _make_bar(Color("c4552e"), 180.0)
	bar.add_child(_label("Hero"))
	bar.add_child(_hero_bar)

	_message = _label("", 22)
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.offset_top = 90.0
	_message.offset_left = -400.0
	_message.offset_right = 400.0
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_color", Color("e8a33d"))
	add_child(_message)


func _make_bar(colour: Color, width: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, 22.0)
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.08, 0.10, 0.11, 0.9)
	bar.add_theme_stylebox_override("background", back)
	return bar


## Four bars arranged N/E/S/W around the centre of the screen: the directional
## pressure indicator (GDD §3).
func _build_lane_ring() -> void:
	var ring := Control.new()
	ring.set_anchors_preset(Control.PRESET_CENTER)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ring)

	var offsets: Array[Vector2] = [
		Vector2(-60, -250), Vector2(200, -12), Vector2(-60, 230), Vector2(-320, -12),
	]
	for lane: int in Balance.LANE_COUNT:
		var box := VBoxContainer.new()
		box.position = offsets[lane]
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := _label(LANE_NAMES[lane], 16)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)
		var bar := _make_bar(Color("8c3a2b"), 120.0)
		bar.value = 0.0
		box.add_child(bar)
		_lane_bars.append(bar)
		ring.add_child(box)


func _build_scope_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.offset_left = 24.0
	bar.offset_top = -84.0
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)

	_add_button(bar, "1  Battlefield", func() -> void: scope_requested.emit(GameDirector.Scope.BATTLEFIELD))
	_add_button(bar, "2  Town", func() -> void: scope_requested.emit(GameDirector.Scope.TOWN))
	_add_button(bar, "3  Beast", func() -> void: scope_requested.emit(GameDirector.Scope.BEAST))

	_horn_button = _add_button(bar, "War Horn", func() -> void: horn_requested.emit())
	_raid_button = _add_button(bar, "Raid", func() -> void: raid_requested.emit())
	_raid_button.disabled = true

	_charge_bar = _make_bar(Color("9b8fc4"), 200.0)
	_charge_bar.value = 0.0
	bar.add_child(_charge_bar)


func _add_button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


func _build_tower_panel() -> void:
	_build_panel = PanelContainer.new()
	_build_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_build_panel.offset_left = -360.0
	_build_panel.offset_right = -24.0
	_build_panel.offset_top = -240.0
	_build_panel.offset_bottom = 240.0
	_build_panel.visible = false
	add_child(_build_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_build_panel.add_child(column)

	_build_title = _label("Build", 22)
	column.add_child(_build_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_build_list = VBoxContainer.new()
	_build_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_build_list)

	_add_button(column, "Close", func() -> void: _build_panel.visible = false)


func _build_raid_panel() -> void:
	_raid_panel = PanelContainer.new()
	_raid_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_raid_panel.offset_left = -280.0
	_raid_panel.offset_right = 280.0
	_raid_panel.offset_top = 130.0
	_raid_panel.visible = false
	add_child(_raid_panel)

	var column := VBoxContainer.new()
	_raid_panel.add_child(column)
	_raid_status = _label("", 20)
	_raid_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_raid_status)
	_extract_button = _add_button(column, "Extract", func() -> void: extract_requested.emit())
	_extract_button.disabled = true


# --- Build panel ------------------------------------------------------------

func _open_build_panel(lane: int, slot: int) -> void:
	_selected_lane = lane
	_selected_slot = slot
	_refresh_build_panel()
	_build_panel.visible = true


func _refresh_build_panel() -> void:
	for child: Node in _build_list.get_children():
		child.queue_free()

	var lane: int = _selected_lane
	var slot: int = _selected_slot
	var existing: TowerData = RunState.tower_in_slot(lane, slot)
	var level: int = RunState.level_in_slot(lane, slot)
	_build_title.text = "%s lane  ·  %s spot" % [
		LANE_NAMES[clampi(lane, 0, 3)],
		["inner", "middle", "outer"][clampi(slot, 0, 2)],
	]

	if existing != null:
		_build_list.add_child(_label("%s  ·  level %d" % [existing.display_name, level], 18))
		_build_list.add_child(_label(existing.description, 14))
		if level < Balance.TOWER_MAX_LEVEL:
			var cost: int = TowerData.upgrade_cost(level)
			_add_button(_build_list, "Upgrade to %d  (%d)" % [level + 1, cost], func() -> void:
				_report(battlefield.try_upgrade(lane, slot))
				_refresh_build_panel())
		_add_button(_build_list, "Sell", func() -> void:
			_report(battlefield.try_sell(lane, slot))
			_refresh_build_panel())
		return

	var target_slot: TowerSlot = battlefield.slot_at(lane, slot)
	if target_slot != null and target_slot.is_combo_slot():
		var combo: TowerData = target_slot.buildable_combination()
		if combo == null:
			_build_list.add_child(_label("Build a tower either side first.\nThe middle spot combines them.", 15))
			return
		_build_list.add_child(_label("%s + %s" % [
			TowerData.element_name(combo.parent_a), TowerData.element_name(combo.parent_b)], 15))
		_add_tower_row(combo, lane, slot)
		return

	for tower: TowerData in ContentDB.base_towers():
		_add_tower_row(tower, lane, slot)


func _add_tower_row(tower: TowerData, lane: int, slot: int) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var cost: int = tower.build_cost()
	var button: Button = _add_button(row, "%s  ·  %s  ·  %d" % [
		tower.display_name, TowerData.element_name(tower.element), cost], func() -> void:
			_report(battlefield.try_build(lane, slot, tower))
			_refresh_build_panel())
	button.disabled = not RunState.can_afford(cost)
	button.add_theme_color_override("font_color", TowerData.element_colour(tower.element))
	if not tower.description.is_empty():
		row.add_child(_label(tower.description, 13))
	_build_list.add_child(row)


## Empty means the action succeeded, so only refusals are ever shown.
func _report(problem: String) -> void:
	if problem.is_empty():
		return
	_message.text = problem
	_message_left = 2.4


# --- Signal handlers --------------------------------------------------------

func _on_distance(total: float, to_crossroad: float) -> void:
	_distance.text = "Distance  %d   ·   crossroad in %d" % [int(total), int(ceil(to_crossroad))]


func _on_town_health(current: float, maximum: float) -> void:
	_town_bar.value = current / maximum if maximum > 0.0 else 0.0


func _on_hero_health(current: float, maximum: float) -> void:
	_hero_bar.value = current / maximum if maximum > 0.0 else 0.0


func _on_charge(value: float) -> void:
	_charge_bar.value = value


func _on_pressure(lane: int, value: float) -> void:
	if lane >= 0 and lane < _lane_bars.size():
		_lane_bars[lane].value = value


func _on_wave(number: int, lanes: Array) -> void:
	var names: PackedStringArray = []
	for lane: int in lanes:
		names.append(LANE_NAMES[clampi(lane, 0, 3)])
	_wave.text = "Wave  %d" % number
	_message.text = "Wave %d  —  %s" % [number, ", ".join(names)]
	_message_left = 2.0


func _on_act(act: int, terrain_id: String) -> void:
	var terrain: TerrainData = ContentDB.terrain(terrain_id)
	_act.text = "Act %d  ·  %s" % [act, terrain.display_name if terrain != null else "—"]


func _on_scope_changed(scope: int) -> void:
	var in_raid: bool = scope == int(GameDirector.Scope.RAID)
	_raid_panel.visible = in_raid
	_build_panel.visible = _build_panel.visible and not in_raid


func _update_raid_panel() -> void:
	if raid == null:
		return
	_extract_button.disabled = not raid.window_is_open()
	if raid.chieftain_is_out():
		_raid_status.text = "The chieftain is here. No way out but through."
	elif raid.window_is_open():
		_raid_status.text = "WAY OUT OPEN — %.1fs   ·   %d killed" % [raid.window_time_left(), raid.kills()]
	else:
		_raid_status.text = "Next way out in %.0fs   ·   %d killed   ·   %d refused" % [
			raid.time_to_next_window(), raid.kills(), raid.refusals()]
