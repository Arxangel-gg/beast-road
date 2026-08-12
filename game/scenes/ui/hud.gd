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
var _lane_ring: Control
var _build_panel: PanelContainer
var _build_list: VBoxContainer
var _build_title: Label
var _selected_lane: int = -1
var _selected_slot: int = -1

var _raid_panel: PanelContainer
var _raid_status: Label
var _extract_button: Button
@export var raid: RaidArena
@export var boss_director: BossDirector

var _spell_buttons: Array[Button] = []
var _spell_bar: HBoxContainer
var _boss_panel: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _state_label: Label
var _hero: Hero = null
var _boss_track: ProgressBar
var _boss_label: Label


func _ready() -> void:
	_build_top_bar()
	_build_lane_ring()
	_build_scope_bar()
	_build_tower_panel()
	_build_raid_panel()
	_build_boss_track()
	_build_spell_bar()
	_build_boss_bar()

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
	EventBus.war_horn_activated.connect(func(_d: float) -> void: _refresh_state_label())
	EventBus.war_horn_ended.connect(_refresh_state_label)
	EventBus.raid_available.connect(func(_s: float) -> void: _refresh_state_label())
	EventBus.weakened_ended.connect(_refresh_state_label)
	EventBus.spells_changed.connect(_rebuild_spell_bar)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(func(_id: String, _a: int) -> void: _boss_panel.visible = false)
	EventBus.run_started.connect(_rebuild_spell_bar)

	for node: Node in get_tree().get_nodes_in_group(TowerSlot.GROUP):
		var slot := node as TowerSlot
		if slot != null:
			slot.clicked.connect(_open_build_panel)

	_hero = battlefield.hero if battlefield != null else null
	_resources.text = "Resources  %d" % RunState.resources
	_on_act(RunState.act, RunState.terrain_id)
	_rebuild_spell_bar()
	_refresh_state_label()


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.text = ""
	if _raid_panel.visible:
		_update_raid_panel()
	_update_spell_bar()
	_update_boss_bar()
	_update_boss_track()


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

	_state_label = _label("", 19)
	_state_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_state_label.offset_top = 132.0
	_state_label.offset_left = -520.0
	_state_label.offset_right = 520.0
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_state_label)

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
	_lane_ring = ring

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

	_add_button(bar, "F1  Battlefield", func() -> void: scope_requested.emit(GameDirector.Scope.BATTLEFIELD))
	_add_button(bar, "F2  Town", func() -> void: scope_requested.emit(GameDirector.Scope.TOWN))
	_add_button(bar, "F3  Beast", func() -> void: scope_requested.emit(GameDirector.Scope.BEAST))

	_horn_button = _add_button(bar, "Q  War Horn", func() -> void: horn_requested.emit())
	_raid_button = _add_button(bar, "R  Raid", func() -> void: raid_requested.emit())
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


## Four slots along the bottom. A spell you cannot cast still shows, greyed —
## an empty bar tells the player nothing about what they are missing.
## A bar counting down to the act boss.
##
## The trigger is distance, not waves, and nothing said so - so a player at wave
## 33 with no boss in sight reasonably concluded it was broken. This makes the
## approach legible, and turns the last stretch of an act into something you can
## see coming and prepare for.
func _build_boss_track() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -190.0
	box.offset_right = 190.0
	box.offset_top = 14.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	add_child(box)

	_boss_label = _label("", 15)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_boss_label)

	_boss_track = _make_bar(Color("8c3a2b"), 380.0)
	_boss_track.custom_minimum_size = Vector2(380.0, 10.0)
	_boss_track.value = 0.0
	box.add_child(_boss_track)


func _update_boss_track() -> void:
	if _boss_track == null:
		return
	# While the boss is actually out, the bar becomes its health instead of a
	# countdown - the same strip of screen answering "how close" then "how bad".
	if boss_director != null and boss_director.boss_is_out():
		_boss_track.value = 1.0
		_boss_label.text = ""
		_boss_track.visible = false
		return
	_boss_track.visible = true
	var remaining: float = RunState.distance_to_boss()
	_boss_track.value = RunState.act_progress()
	if remaining <= Balance.ACT_BOSS_RAMP_DISTANCE:
		_boss_label.text = "THE ACT %d BOSS IS COMING  -  %d" % [RunState.act, int(remaining)]
		_boss_label.add_theme_color_override("font_color", Color("ff7a5a"))
	else:
		_boss_label.text = "Act %d boss in %d distance" % [RunState.act, int(remaining)]
		_boss_label.add_theme_color_override("font_color", Color("b8ae98"))


func _build_spell_bar() -> void:
	_spell_bar = HBoxContainer.new()
	_spell_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_spell_bar.offset_left = -520.0
	_spell_bar.offset_top = -96.0
	_spell_bar.offset_right = -24.0
	_spell_bar.offset_bottom = -24.0
	_spell_bar.add_theme_constant_override("separation", 10)
	add_child(_spell_bar)


func _rebuild_spell_bar() -> void:
	if _spell_bar == null:
		return
	for child: Node in _spell_bar.get_children():
		child.queue_free()
	_spell_buttons.clear()

	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(118, 66)
		button.focus_mode = Control.FOCUS_NONE
		var spell: SpellData = _spell_in_slot(slot)
		if spell == null:
			button.text = "%d\n—" % (slot + 1)
			button.disabled = true
		else:
			button.text = "%d\n%s" % [slot + 1, spell.display_name]
			button.tooltip_text = spell.description
			button.pressed.connect(_cast.bind(slot))
		_spell_bar.add_child(button)
		_spell_buttons.append(button)


func _spell_in_slot(slot: int) -> SpellData:
	if slot < 0 or slot >= RunState.equipped_spells.size():
		return null
	return ContentDB.spells.get(RunState.equipped_spells[slot], null) as SpellData


func _cast(slot: int) -> void:
	if _hero != null and _hero.is_alive():
		_hero.spells.try_cast(slot, _hero.aim_direction(), _hero.global_position)


func _update_spell_bar() -> void:
	if _hero == null or not is_instance_valid(_hero):
		return
	for slot: int in _spell_buttons.size():
		var spell: SpellData = _spell_in_slot(slot)
		if spell == null:
			continue
		var left: float = _hero.spells.cooldown_ratio(slot)
		var button: Button = _spell_buttons[slot]
		button.disabled = left > 0.0
		button.text = "%d\n%s" % [slot + 1, spell.display_name] if left <= 0.0 else "%d\n%.1fs" % [slot + 1, left * spell.cooldown]


## A boss is the only enemy that gets its own bar. Everything else reads off the
## lane pressure ring.
func _build_boss_bar() -> void:
	_boss_panel = PanelContainer.new()
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.offset_left = -420.0
	_boss_panel.offset_right = 420.0
	_boss_panel.offset_top = 54.0
	_boss_panel.visible = false
	add_child(_boss_panel)

	var column := VBoxContainer.new()
	_boss_panel.add_child(column)
	_boss_name = _label("", 22)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_boss_name)
	_boss_bar = _make_bar(Color("8c3a2b"), 800.0)
	column.add_child(_boss_bar)


func _on_boss_spawned(boss_id: String, act: int) -> void:
	var data: EnemyData = ContentDB.enemy(boss_id)
	_boss_name.text = "%s   ·   Act %d" % [data.display_name if data != null else boss_id, act]
	_boss_panel.visible = true
	_message.text = "%s has come." % (data.display_name if data != null else "Something")
	_message_left = 3.2


func _update_boss_bar() -> void:
	if not _boss_panel.visible or boss_director == null:
		return
	var boss: Enemy = boss_director.active_boss()
	if boss == null:
		_boss_panel.visible = false
		return
	var health: Health = Health.of(boss)
	if health != null:
		_boss_bar.value = health.ratio()


## One line that says what state the field is in: horn blowing, enemies
## weakened, or nothing special. Both of those change how the player should be
## playing, so neither can be invisible.
func _refresh_state_label() -> void:
	if _state_label == null:
		return
	if RunState.horn_active:
		_state_label.text = "WAR HORN  —  they come faster, and the beast has stopped walking"
		_state_label.add_theme_color_override("font_color", Color("c4552e"))
	elif RunState.enemies_are_weakened():
		_state_label.text = "THEY FALTER  —  strike now, or take the road to their camp"
		_state_label.add_theme_color_override("font_color", Color("9b8fc4"))
	else:
		_state_label.text = ""


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
			var cost: int = Battlefield.upgrade_cost_of(level)
			_add_stat_preview(existing, level)
			var afford: bool = RunState.can_afford(cost)
			var button: Button = _add_button(_build_list,
				"Upgrade to level %d   -   %d resources" % [level + 1, cost], func() -> void:
					_report(battlefield.try_upgrade(lane, slot))
					_refresh_build_panel())
			button.disabled = not afford
			if not afford:
				_build_list.add_child(_label("Need %d more." % (cost - RunState.resources), 13))
		else:
			_build_list.add_child(_label("Fully upgraded.", 14))
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


## Shows what the next level actually buys, before the player commits.
##
## Upgrading was a button with a price and no answer to "what do I get". Every
## stat that changes is listed as now -> next with the delta, and stats that do
## not change are left out entirely so the list is short enough to read mid-wave.
func _add_stat_preview(tower: TowerData, level: int) -> void:
	var next_level: int = level + 1

	var rows: Array[Dictionary] = []
	_collect_stat(rows, "Damage", tower.damage_at(level), tower.damage_at(next_level), 1)
	# Interval goes down as the tower gets faster, so shots per second is the
	# honest way to show it - a falling number reading as an upgrade is a trap.
	var rate_now: float = 1.0 / maxf(tower.interval_at(level), 0.001)
	var rate_next: float = 1.0 / maxf(tower.interval_at(next_level), 0.001)
	_collect_stat(rows, "Shots/sec", rate_now, rate_next, 2)
	_collect_stat(rows, "Damage/sec",
		tower.damage_at(level) * rate_now, tower.damage_at(next_level) * rate_next, 1)

	if rows.is_empty():
		return

	var panel := PanelContainer.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)

	var heading: Label = _label("NEXT LEVEL", 13)
	heading.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(heading)

	for row: Dictionary in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var name_label: Label = _label(String(row["name"]), 14)
		name_label.custom_minimum_size = Vector2(112.0, 0.0)
		line.add_child(name_label)
		line.add_child(_label(String(row["from"]), 14))
		var arrow: Label = _label("->", 14)
		arrow.add_theme_color_override("font_color", Color("7f8a86"))
		line.add_child(arrow)
		var to_label: Label = _label(String(row["to"]), 14)
		to_label.add_theme_color_override("font_color", Color("9fe8b0"))
		line.add_child(to_label)
		var delta_label: Label = _label(String(row["delta"]), 13)
		delta_label.add_theme_color_override("font_color", Color("9fe8b0"))
		line.add_child(delta_label)
		column.add_child(line)

	_build_list.add_child(panel)


## Appends a row only when the value actually moves.
func _collect_stat(rows: Array[Dictionary], name: String, from: float, to: float, digits: int) -> void:
	if is_equal_approx(from, to):
		return
	var percent: float = ((to - from) / from * 100.0) if absf(from) > 0.001 else 0.0
	rows.append({
		"name": name,
		"from": String.num(from, digits),
		"to": String.num(to, digits),
		"delta": "+%d%%" % int(round(percent)) if percent >= 0.0 else "%d%%" % int(round(percent)),
	})


func _add_tower_row(tower: TowerData, lane: int, slot: int) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var cost: int = Battlefield.build_cost_of(tower)
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
	var on_field: bool = scope == int(GameDirector.Scope.BATTLEFIELD)
	_raid_panel.visible = in_raid
	_build_panel.visible = _build_panel.visible and on_field
	# The pressure ring and the boss bar describe the battlefield. Floating them
	# over the town reads as though the town is the thing under attack.
	if _lane_ring != null:
		_lane_ring.visible = on_field
	if _boss_panel != null and not on_field:
		_boss_panel.visible = false
	elif _boss_panel != null and boss_director != null:
		_boss_panel.visible = boss_director.boss_is_out()


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
