class_name HUD
extends CanvasLayer

const CommandSystemScript = preload("res://scripts/systems/command_system.gd")

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
signal ride_on_requested()
signal command_requested(order_id: String, lane: int, slot: int)

const LANE_NAMES: Array[String] = ["N", "E", "S", "W"]

## Frame drawn behind each spell slot.
const SLOT_TEXTURE: String = "res://art/ui/ui_slot.png"

## Build panel geometry.
##
## One column of eight, down the right-hand side. Each tower is one line — mark,
## name, price — because that is all a tower needs to be chosen between: the
## description belongs in the footer, and a card tall enough to hold one is a
## card that forces the list to scroll.
##
## Nothing here is a scroll container. Eight rows at 44 plus the heading, footer
## and close button come to ~600 of the 1080 the UI is laid out in.
const BUILD_PANEL_WIDTH: float = 420.0
const BUILD_ROW_HEIGHT: float = 44.0
const BUILD_ROW_GAP: int = 5

## How far the price sits in from a row's right edge.
##
## Shares the theme's own button inset so it lines up with the label on the other
## side of the row. Read from UiMetrics, never from ThemeBuilder: that lives under
## `tools/`, which `export_presets.cfg` strips from the build, and referencing it
## from here once cost an entire release its HUD.
const BUILD_ROW_PRICE_INSET: float = float(UiMetrics.PAD_BUTTON_X)

## Distance from the right edge of the screen.
const BUILD_PANEL_MARGIN: float = 34.0

## Reserved height for the hover description, so the panel does not resize as the
## cursor moves along the row.
##
## This said "one line is enough" and reserved thirty pixels for it, but the text
## it holds is an element, a description, a price and sometimes a refusal - which
## wraps to three. `custom_minimum_size` is a floor and not a ceiling, so the
## footer simply grew past its reservation and took the panel with it: the box
## changed size under the cursor every time it moved between towers.
##
## Reserved and capped, so the height is now the same whatever the text says.
const BUILD_DETAIL_LINES: int = 3
const BUILD_DETAIL_LINE_HEIGHT: float = 20.0
const BUILD_DETAIL_HEIGHT: float = BUILD_DETAIL_LINES * BUILD_DETAIL_LINE_HEIGHT

## Spell slot size. Wide enough that a two-word ability name fits inside the
## frame's interior rather than across its border.
const SPELL_SLOT_SIZE: Vector2 = Vector2(152.0, 72.0)

@export var battlefield: Battlefield

var _resources: Label
var _currency_labels: Dictionary = {}
var _distance: Label
var _wave: Label
var _wave_preview: Label
var _act: Label
var _town_bar: ProgressBar
var _hero_bar: ProgressBar
var _wounds_label: Label
var _draught_icon: Control
var _charge_bar: ProgressBar
var _horn_button: Button
var _raid_button: Button
var _repair_button: Button
var _tend_button: Button
var _message: Label
var _message_left: float = 0.0

## The rosette listens to EventBus.lane_pressure_changed itself, so the HUD only
## has to decide whether it is on screen.
var _lane_ring: Control
var _build_panel: PanelContainer
var _build_list: VBoxContainer
var _build_title: Label
var _build_detail: Label
var _selected_lane: int = -1
var _selected_slot: int = -1

var _raid_panel: PanelContainer
var _raid_status: Label
var _extract_button: Button
@export var raid: RaidArena
@export var boss_director: BossDirector

var _spell_buttons: Array[Button] = []
var _spell_icons: Array[TextureRect] = []
var _spell_labels: Array[Label] = []
var _spell_cooldowns: Array[Label] = []
var _spell_bar: HBoxContainer
var _boss_panel: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _state_label: Label
var _hero: Hero = null
var _boss_track: ProgressBar
var _boss_label: Label
var _preparation_panel: PanelContainer
var _preparation_label: Label
var _ride_on_button: Button
var _command_panel: PanelContainer
var _command_bar: ProgressBar
var _command_value: Label
var _command_target: Label
var _command_buttons: Dictionary = {}
var _last_stand_spent: bool = false


func _ready() -> void:
	_build_top_bar()
	_build_lane_ring()
	_build_scope_bar()
	_build_tower_panel()
	_build_raid_panel()
	_build_boss_track()
	_build_spell_bar()
	_build_boss_bar()
	_build_preparation_panel()
	_build_command_panel()

	EventBus.resources_changed.connect(func(v: int) -> void:
		if _resources != null:
			_resources.text = "%d" % v
		if _build_panel.visible:
			_refresh_build_panel())
	EventBus.distance_changed.connect(_on_distance)
	EventBus.town_health_changed.connect(_on_town_health)
	EventBus.hero_health_changed.connect(_on_hero_health)
	EventBus.hero_wounds_changed.connect(_on_hero_wounds_changed)
	EventBus.raid_charge_changed.connect(_on_charge)
	EventBus.wave_started.connect(_on_wave)
	EventBus.wave_archetype_started.connect(_on_wave_archetype)
	EventBus.act_started.connect(_on_act)
	EventBus.raid_available.connect(func(_s: float) -> void: _raid_button.disabled = false)
	EventBus.war_horn_activated.connect(func(_d: float) -> void: _refresh_horn_button())
	EventBus.war_horn_ended.connect(_refresh_horn_button)
	EventBus.scope_changed.connect(_on_scope_changed)
	EventBus.war_horn_activated.connect(func(_d: float) -> void: _refresh_state_label())
	EventBus.war_horn_ended.connect(_refresh_state_label)
	EventBus.raid_available.connect(func(_s: float) -> void: _refresh_state_label())
	EventBus.weakened_ended.connect(_refresh_state_label)
	EventBus.spells_changed.connect(_rebuild_spell_bar)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	EventBus.boss_defeated.connect(func(_id: String, _a: int) -> void: _boss_panel.visible = false)
	EventBus.run_started.connect(_rebuild_spell_bar)
	EventBus.construction_completed.connect(func(_id: String, _tier: int) -> void:
		if _build_panel.visible:
			_refresh_build_panel())
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.preparation_changed.connect(_on_preparation_changed)
	EventBus.preparation_warning.connect(_show_message)
	EventBus.command_changed.connect(_on_command_changed)
	EventBus.command_order_used.connect(_on_command_order_used)
	EventBus.currency_changed.connect(_on_currency_changed)

	for node: Node in get_tree().get_nodes_in_group(TowerSlot.GROUP):
		var slot := node as TowerSlot
		if slot != null:
			slot.clicked.connect(_open_build_panel)

	_hero = battlefield.hero if battlefield != null else null
	_refresh_currencies()
	_on_act(RunState.act, RunState.terrain_id)
	_rebuild_spell_bar()
	_refresh_state_label()
	_on_phase_changed(int(RunState.phase), int(RunState.phase))
	_on_preparation_changed(0.0, true)
	_on_command_changed(RunState.command, Balance.COMMAND_MAX)
	_on_hero_wounds_changed(RunState.hero_wounds, Balance.HERO_MAX_WOUNDS)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"ride_on"):
		ride_on_requested.emit()
	if Input.is_action_just_pressed(&"command_overdrive"):
		_request_command(CommandSystemScript.OVERDRIVE)
	if Input.is_action_just_pressed(&"command_rally"):
		_request_command(CommandSystemScript.RALLY_ROAD)
	if Input.is_action_just_pressed(&"command_last_stand"):
		_request_command(CommandSystemScript.LAST_STAND)
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.text = ""
	if _raid_panel.visible:
		_update_raid_panel()
	_update_spell_bar()
	_update_boss_bar()
	if _draught_icon != null:
		_draught_icon.visible = RunState.has_resurrection_draught
	_update_boss_track()
	_update_repair_button()
	_update_wave_preview()


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

	# The act name keeps its word; the three counters do not need theirs. An icon
	# says "resources" faster than the word does once it has been seen twice, and
	# the numbers are what the player is actually reading.
	_act = _label("Act 1")
	bar.add_child(_act)

	_currency_labels.clear()
	for id: String in RunState.CURRENCIES:
		var resource_row: HBoxContainer = IconKit.labelled(id, "0", 17, 24)
		resource_row.tooltip_text = RunState.currency_name(id)
		bar.add_child(resource_row)
		_currency_labels[id] = IconKit.label_of(resource_row)
	_resources = _currency_labels.get(RunState.GOLD, null) as Label
	# Journey telemetry gets a quiet second line. Keeping it out of this wide
	# health row prevents four currencies from colliding with the boss tracker at
	# 1920x1080 and gives every counter a stable place at narrower ratios.
	var journey_bar := HBoxContainer.new()
	journey_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	journey_bar.position = Vector2(24.0, 52.0)
	journey_bar.add_theme_constant_override("separation", 20)
	add_child(journey_bar)
	var distance_row: HBoxContainer = IconKit.labelled("distance", "0", 15, 21)
	var wave_row: HBoxContainer = IconKit.labelled("wave", "0", 15, 21)
	for row: HBoxContainer in [distance_row, wave_row]:
		journey_bar.add_child(row)
	_distance = IconKit.label_of(distance_row)
	_wave = IconKit.label_of(wave_row)
	var seed_label: Label = _label("SEED  " + RunState.seed_code(), 12)
	seed_label.tooltip_text = "Gameplay seed. Enter this code on the main menu to reproduce road, wave, raid and reward rolls."
	seed_label.add_theme_color_override("font_color", Color("778985"))
	journey_bar.add_child(seed_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	_town_bar = _make_bar(Color("8a5a3a"), 240.0)
	bar.add_child(_bar_icon("city_health", "Town"))
	bar.add_child(_town_bar)

	_hero_bar = _make_bar(Color("c4552e"), 180.0)
	bar.add_child(_bar_icon("hero_health", "Hero"))
	bar.add_child(_hero_bar)
	var wound_row := HBoxContainer.new()
	wound_row.add_theme_constant_override("separation", 5)
	var wound_icon: Control = _bar_icon("wounds", "Wounds")
	wound_icon.custom_minimum_size = Vector2(24.0, 24.0)
	wound_row.add_child(wound_icon)
	_wounds_label = _label("0/%d" % Balance.HERO_MAX_WOUNDS, 15)
	_wounds_label.tooltip_text = "A lethal down adds one Wound and reduces maximum HP by 10%. The third ends the run."
	wound_row.tooltip_text = _wounds_label.tooltip_text
	wound_row.add_child(_wounds_label)
	bar.add_child(wound_row)

	# A carried item nobody can see is an item nobody plays around. The Draught
	# changes how much risk is worth taking, so it has to be on screen next to
	# the Wounds it exists to prevent - hidden until one is held, because an
	# empty slot in the top bar reads as a thing that is broken.
	# Borrows the relic icon rather than carrying its own.
	#
	# A new icon means a new manifest row, and a manifest row with only a
	# placeholder behind it fails the production-art gate - which is the gate
	# that stops placeholder art reaching a player, and which was passing at
	# 100% before this indicator was added. Reusing a finished icon costs a
	# little specificity and blocks nothing. `ItemData.get_sprite_path()` still
	# names the path real art should land at.
	_draught_icon = _bar_icon("relic", "Draught")
	_draught_icon.custom_minimum_size = Vector2(26.0, 26.0)
	_draught_icon.tooltip_text = "Resurrection Draught. Prevents the next lethal down and restores %d%% health, then is consumed." % \
		int(round(Balance.HERO_DRAUGHT_REVIVE_HP * 100.0))
	_draught_icon.visible = false
	bar.add_child(_draught_icon)

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

	_wave_preview = _label("", 15)
	_wave_preview.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_wave_preview.offset_top = 158.0
	_wave_preview.offset_left = -420.0
	_wave_preview.offset_right = 420.0
	_wave_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_preview.add_theme_color_override("font_color", Color("aebcb8"))
	add_child(_wave_preview)


func _update_wave_preview() -> void:
	if _wave_preview == null or battlefield == null or battlefield.wave_director == null:
		return
	_wave_preview.text = battlefield.wave_director.preview_text()


## An icon if the art exists, the word if it does not. The fallback protects the
## HUD from a bad content import even though the production manifest is complete.
func _bar_icon(id: String, fallback: String) -> Control:
	var icon: TextureRect = IconKit.rect(id, 28.0)
	return icon if icon != null else _label(fallback)


## A bar in the theme's own art, tinted.
##
## It used to override both styleboxes with flat colours, which meant every bar
## in the game bypassed the theme entirely - so `ui_bar_fill.png` and
## `ui_bar_back.png` could never appear no matter what the theme said. Tinting a
## textured fill keeps the art's vertical shading, which is what makes a bar look
## lit rather than filled in.
func _make_bar(colour: Color, width: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, 22.0)
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false

	var fill: StyleBox = bar.get_theme_stylebox("fill", "ProgressBar")
	if fill is StyleBoxTexture:
		var tinted: StyleBoxTexture = (fill as StyleBoxTexture).duplicate()
		# The art is a neutral warm ramp so this multiply lands on the intended
		# hue; a saturated source would drag every bar toward orange.
		tinted.modulate_color = colour
		bar.add_theme_stylebox_override("fill", tinted)
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = colour
		bar.add_theme_stylebox_override("fill", flat)
	return bar


## The directional pressure indicator (GDD §3): four arcs hugging the town, on
## the side the threat is coming from. See LaneRosette for why it is no longer
## four labelled bars.
func _build_lane_ring() -> void:
	var rosette := LaneRosette.new()
	rosette.name = "LaneRosette"
	# CanvasLayer has no Control rect to inherit. Full anchors on a direct child
	# therefore resolve to zero; size the overlay from the viewport explicitly.
	rosette.size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(func() -> void:
		if is_instance_valid(rosette):
			rosette.size = get_viewport().get_visible_rect().size)
	add_child(rosette)
	_lane_ring = rosette


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
	var zoom_hint: Label = _label("Wheel  Zoom", 14)
	zoom_hint.add_theme_color_override("font_color", Color("8f9b98"))
	bar.add_child(zoom_hint)

	_horn_button = _add_button(bar, "Q  War Horn", func() -> void: horn_requested.emit())
	IconKit.on_button(_horn_button, "war_horn", 26)
	_raid_button = _add_button(bar, "R  Raid", func() -> void: raid_requested.emit())
	IconKit.on_button(_raid_button, "raid_charge", 26)
	_raid_button.disabled = true
	# Short labels because the bar has to share the bottom edge with the spell
	# slots, and both buttons carry an icon and a tooltip that say the rest.
	_repair_button = _add_button(bar,
		"Repair",
		func() -> void: _report(battlefield.try_repair_town()))
	_repair_button.tooltip_text = "Restore %d Town health during Preparation. Cost: %d Wood." % [
		int(Balance.TOWN_REPAIR_AMOUNT), Balance.TOWN_REPAIR_COST]
	_repair_button.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
	IconKit.on_button(_repair_button, "upgrade", 22)

	_tend_button = _add_button(bar,
		"Tend",
		func() -> void: _report(battlefield.try_tend_hero()))
	_tend_button.tooltip_text = "Restore %d%% of the hero's health during Preparation. Cost: %d Food." % [
		int(round(Balance.HERO_TEND_FRACTION * 100.0)), Balance.HERO_TEND_COST]
	_tend_button.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
	IconKit.on_button(_tend_button, "hero_health", 22)

	var charge_readout := VBoxContainer.new()
	# 92 rather than 108: the bar ends where the spell slots begin, and the last
	# widget in it was reaching seventeen pixels into the first slot.
	charge_readout.custom_minimum_size = Vector2(92.0, 48.0)
	charge_readout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	charge_readout.add_theme_constant_override("separation", 1)
	var charge_label: Label = _label("CHARGE", 10)
	charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	charge_label.add_theme_color_override("font_color", Color("b9abc9"))
	charge_readout.add_child(charge_label)
	_charge_bar = _make_bar(Color("9b8fc4"), 92.0)
	_charge_bar.custom_minimum_size.y = 18.0
	_charge_bar.value = 0.0
	_charge_bar.tooltip_text = "Raid charge. Defeat enemies to fill it; War Horn accelerates the gain."
	charge_readout.tooltip_text = _charge_bar.tooltip_text
	charge_readout.add_child(_charge_bar)
	bar.add_child(charge_readout)


func _update_repair_button() -> void:
	if _repair_button == null or battlefield == null or battlefield.town == null:
		return
	var health: Health = battlefield.town.health
	_repair_button.disabled = health == null or health.current_hp >= health.max_hp \
		or not RunState.can_afford_cost({RunState.WOOD: Balance.TOWN_REPAIR_COST}) \
		or not RunState.is_preparation()

	if _tend_button == null:
		return
	var hero_health: Health = battlefield.hero.health if battlefield.hero != null else null
	_tend_button.disabled = hero_health == null \
		or hero_health.current_hp >= hero_health.max_hp \
		or not RunState.can_afford_cost({RunState.FOOD: Balance.HERO_TEND_COST}) \
		or not RunState.is_preparation()


func _add_button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	# Left, always. Godot centres button text by default and IconKit.on_button
	# switches to left so the icons line up - which left a column of buttons where
	# some labels were centred and some were not, entirely by whether they happened
	# to have art.
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


## The build panel: everything visible at once, no scrolling in either axis.
##
## It used to be a 336x480 box with a ScrollContainer in it. Eight towers, each
## a button plus a wrapped description, come to roughly 530px of content — so
## choosing a tower meant scrolling a list during a wave, and the two towers at
## the bottom were effectively hidden.
##
## The fix is not a taller box. It is that a vertical list was the wrong shape
## for eight items: two columns of four fit in less height than four of eight,
## and the descriptions do not belong in the list at all. They now appear in a
## fixed footer for whichever tower the cursor is over, which keeps the panel's
## height constant no matter how long the text is.
##
## The panel has no fixed height. Anchors pinned to one line with GROW_BOTH make
## a Control size to its own content, so the upgrade view and the build view can
## differ in height without either one being cropped or padded to fit the other.
func _build_tower_panel() -> void:
	_build_panel = PanelContainer.new()
	_build_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_build_panel.offset_left = -BUILD_PANEL_WIDTH - BUILD_PANEL_MARGIN
	_build_panel.offset_right = -BUILD_PANEL_MARGIN
	# No fixed height: anchors pinned to one line with GROW_BOTH make a Control
	# size to its own content, so the eight-row build view and the shorter upgrade
	# view each get the box they need rather than sharing one compromise.
	_build_panel.offset_top = 0.0
	_build_panel.offset_bottom = 0.0
	_build_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_build_panel.visible = false
	add_child(_build_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_build_panel.add_child(column)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	var heading_icon: TextureRect = IconKit.rect("blueprint", 28.0)
	if heading_icon != null:
		heading.add_child(heading_icon)
	_build_title = _label("Build", 22)
	heading.add_child(_build_title)
	column.add_child(heading)

	_build_list = VBoxContainer.new()
	_build_list.add_theme_constant_override("separation", 8)
	_build_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_build_list)

	# The footer. Its height is reserved whether or not there is anything to say,
	# so the panel does not jump every time the cursor crosses a tower.
	_build_detail = _label("", 14)
	_build_detail.custom_minimum_size = Vector2(0.0, BUILD_DETAIL_HEIGHT)
	_build_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The ceiling that makes the reservation above mean anything. Without it a
	# long description wraps to a fourth line and the label - and the panel -
	# grow to meet it.
	_build_detail.max_lines_visible = BUILD_DETAIL_LINES
	_build_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_build_detail.add_theme_color_override("font_color", Color("aebcb8"))
	column.add_child(_build_detail)

	var close: Button = _add_button(column, "Close", func() -> void: _close_build_panel())
	IconKit.on_button(close, "close", 22)


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


func _build_preparation_panel() -> void:
	_preparation_panel = PanelContainer.new()
	_preparation_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_preparation_panel.offset_left = -190.0
	_preparation_panel.offset_right = 190.0
	# Its ornate skin is taller than the nominal controls. Keep the whole frame
	# above the persistent scope bar instead of letting the lower rivets clip.
	# Clear of the scope bar, with a gap rather than a shave.
	#
	# The bar occupies the bottom 84px and this used to end at 118, leaving 34px
	# that the panel's ornate skin ate into - so it read as overlapping the horn,
	# raid and repair buttons even though the rectangles never intersected. That
	# is also why the layout gate stayed silent: they were close, not overlapping.
	_preparation_panel.offset_top = -272.0
	_preparation_panel.offset_bottom = -156.0
	add_child(_preparation_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_preparation_panel.add_child(column)
	var title := Label.new()
	title.text = "PREPARATION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(title)
	_preparation_label = _label("Build, upgrade and reposition before the road.", 11)
	_preparation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_preparation_label)
	_ride_on_button = _add_button(column, "RIDE ON", func() -> void: ride_on_requested.emit())
	_ride_on_button.custom_minimum_size.y = 34.0
	_ride_on_button.add_theme_font_size_override("font_size", 12)
	_ride_on_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ride_on_button.tooltip_text = "Begin the next wave. Leaving during the first 10 seconds earns bonus Gold; waiting is always safe."


func _build_command_panel() -> void:
	_command_panel = PanelContainer.new()
	_command_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_command_panel.offset_left = -424.0
	_command_panel.offset_top = -276.0
	_command_panel.offset_right = -24.0
	_command_panel.offset_bottom = -164.0
	add_child(_command_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_command_panel.add_child(column)
	var meter_row := HBoxContainer.new()
	meter_row.add_theme_constant_override("separation", 6)
	var command_icon: TextureRect = IconKit.rect("command", 22.0)
	if command_icon != null:
		meter_row.add_child(command_icon)
	var name := _label("COMMAND", 13)
	name.add_theme_color_override("font_color", Color("e8a33d"))
	meter_row.add_child(name)
	_command_bar = _make_bar(Color("e8a33d"), 150.0)
	_command_bar.custom_minimum_size.y = 9.0
	_command_bar.value = 0.0
	meter_row.add_child(_command_bar)
	_command_value = _label("0 / 100", 12)
	_command_value.custom_minimum_size = Vector2(56.0, 0.0)
	meter_row.add_child(_command_value)
	column.add_child(meter_row)
	_command_target = _label("TARGET  ·  select a road or tower", 11)
	_command_target.add_theme_color_override("font_color", Color("b8ae98"))
	column.add_child(_command_target)

	var orders := HBoxContainer.new()
	orders.add_theme_constant_override("separation", 8)
	column.add_child(orders)
	_add_command_button(orders, CommandSystemScript.OVERDRIVE, "Z",
		"command_overdrive", "Point at a tower and press Z: it surges its attack rate and utility for 5 seconds.")
	_add_command_button(orders, CommandSystemScript.RALLY_ROAD, "X",
		"command_rally", "Point at a road and press X: it staggers everything on it and shields its blockers.")
	_add_command_button(orders, CommandSystemScript.LAST_STAND, "C",
		"command_last_stand", "Press C: the Town Hall is protected for 3 seconds and every tower attack resets. Once per battle.")


func _add_command_button(parent: Node, id: String, text: String, icon: String,
		tip: String) -> void:
	# Routed through the same aiming as the hotkey, so pressing the button and
	# pressing the key are the same order rather than two with different rules.
	var button: Button = _add_button(parent, text, func() -> void:
		_request_command(id))
	button.custom_minimum_size = Vector2(54.0, 34.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	var costs: Dictionary = {
		CommandSystemScript.OVERDRIVE: Balance.COMMAND_OVERDRIVE_COST,
		CommandSystemScript.RALLY_ROAD: Balance.COMMAND_RALLY_COST,
		CommandSystemScript.LAST_STAND: Balance.COMMAND_LAST_STAND_COST,
	}
	button.tooltip_text = "%s\nCommand cost: %d" % [tip, int(costs.get(id, 0))]
	IconKit.on_button(button, icon, 19)
	_command_buttons[id] = button


func _on_phase_changed(phase: int, _previous: int) -> void:
	var preparing: bool = phase == int(RunState.Phase.PREPARATION)
	var commanding: bool = phase == int(RunState.Phase.ROAD_BATTLE) \
		or phase == int(RunState.Phase.BOSS) \
		or phase == int(RunState.Phase.FINAL_ASCENT)
	_preparation_panel.visible = preparing \
		and GameDirector.current_scope == GameDirector.Scope.BATTLEFIELD
	_command_panel.visible = commanding \
		and GameDirector.current_scope == GameDirector.Scope.BATTLEFIELD
	if preparing:
		_last_stand_spent = false
	_refresh_horn_button()
	if _build_panel.visible:
		_refresh_build_panel()
	_refresh_state_label()


func _on_preparation_changed(seconds_left: float, ready: bool) -> void:
	if _preparation_label == null or _ride_on_button == null:
		return
	_ride_on_button.disabled = not ready
	var reward: int = int(round(float(Balance.PREPARATION_EARLY_GOLD_MAX) \
		* clampf(seconds_left / maxf(Balance.PREPARATION_BETWEEN_WAVES, 0.01), 0.0, 1.0)))
	_ride_on_button.text = "RIDE ON  ·  +%d GOLD" % reward if reward > 0 else "RIDE ON"
	_preparation_label.text = "Early-departure bonus fades in %.0f sec. The next wave still waits." \
		% ceil(seconds_left) if reward > 0 \
		else "Prepare as long as you need. The next wave waits for you."


func _on_command_changed(current: float, maximum: float) -> void:
	if _command_bar == null:
		return
	_command_bar.value = current / maximum if maximum > 0.0 else 0.0
	_command_value.text = "%d / %d" % [int(round(current)), int(round(maximum))]
	_set_command_available(CommandSystemScript.OVERDRIVE,
		current >= Balance.COMMAND_OVERDRIVE_COST)
	_set_command_available(CommandSystemScript.RALLY_ROAD,
		current >= Balance.COMMAND_RALLY_COST)
	_set_command_available(CommandSystemScript.LAST_STAND,
		current >= Balance.COMMAND_LAST_STAND_COST and not _last_stand_spent)


func _set_command_available(id: String, available: bool) -> void:
	var button: Button = _command_buttons.get(id, null) as Button
	if button != null:
		button.disabled = not available


func _on_command_order_used(order_id: String, _lane: int, _slot: int, _at: Vector2) -> void:
	var names: Dictionary = {
		CommandSystemScript.OVERDRIVE: "OVERDRIVE",
		CommandSystemScript.RALLY_ROAD: "RALLY ROAD",
		CommandSystemScript.LAST_STAND: "LAST STAND",
	}
	if order_id == CommandSystemScript.LAST_STAND:
		_last_stand_spent = true
	_show_message(String(names.get(order_id, "COMMAND ORDER")))
	_on_command_changed(RunState.command, Balance.COMMAND_MAX)


func _show_message(text: String) -> void:
	_message.text = text
	_message_left = 3.0


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
	_spell_icons.clear()
	_spell_labels.clear()
	_spell_cooldowns.clear()

	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		var discipline: DisciplineNodeData = RunState.discipline_node_in_slot(slot)
		# The slot frame sits behind the button rather than being its background,
		# so an empty slot still reads as a slot the player could fill. A gap
		# reads as nothing at all.
		var frame := Control.new()
		frame.custom_minimum_size = Vector2(SPELL_SLOT_SIZE.x, SPELL_SLOT_SIZE.y)
		# Everything below is placed against the art's interior, not the slot's
		# outer rectangle. "HEMORRHAGE EDGE" in a 92px box on a 118px slot spilled
		# straight over the ironwork on both sides.
		var inset := Vector2(SPELL_SLOT_SIZE.x * UiMetrics.SLOT_INSET_X,
			SPELL_SLOT_SIZE.y * UiMetrics.SLOT_INSET_Y)
		var interior := Vector2(SPELL_SLOT_SIZE.x - inset.x * 2.0,
			SPELL_SLOT_SIZE.y - inset.y * 2.0)
		var plate: TextureRect = null
		var slot_texture: Texture2D = load(SLOT_TEXTURE) \
			if ResourceLoader.exists(SLOT_TEXTURE) else null
		if slot_texture != null:
			plate = TextureRect.new()
			plate.texture = slot_texture
			plate.set_anchors_preset(Control.PRESET_FULL_RECT)
			plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			plate.stretch_mode = TextureRect.STRETCH_SCALE
			plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(plate)

		var button := Button.new()
		button.flat = slot_texture != null
		button.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.focus_mode = Control.FOCUS_NONE
		var spell: SpellData = _spell_in_slot(slot)

		var hotkey := Label.new()
		hotkey.text = str(slot + 1)
		hotkey.position = Vector2(inset.x, inset.y - 2.0)
		hotkey.add_theme_font_size_override("font_size", 11)
		hotkey.add_theme_color_override("font_color", Color("f4ddb0"))
		hotkey.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(hotkey)

		var icon := TextureRect.new()
		# ui_slot's authored safe area is x=11..107, y=10..53. Content
		# remains inside it so neither art nor text paints over the metal rail.
		icon.position = Vector2(46.0, 9.0)
		icon.size = Vector2(26.0, 26.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(icon)

		var name_label := Label.new()
		name_label.position = Vector2(inset.x, SPELL_SLOT_SIZE.y - inset.y - 16.0)
		name_label.size = Vector2(interior.x, 15.0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 9)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(name_label)

		var cooldown := Label.new()
		cooldown.set_anchors_preset(Control.PRESET_FULL_RECT)
		cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cooldown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cooldown.add_theme_font_size_override("font_size", 17)
		cooldown.add_theme_color_override("font_color", Color("ffcf76"))
		cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(cooldown)

		if discipline != null:
			icon.texture = load(discipline.get_sprite_path()) \
				if ResourceLoader.exists(discipline.get_sprite_path()) else null
			name_label.text = discipline.display_name.to_upper()
			button.tooltip_text = "%s · %s\n%s%s" % [discipline.discipline_name(),
				discipline.slot_name(), discipline.description,
				"\nCooldown: %.1fs" % spell.cooldown if spell != null else "\nModifies core combat"]
			if spell != null:
				button.pressed.connect(_cast.bind(slot))
			else:
				button.disabled = true
		elif spell == null:
			button.disabled = true
			name_label.text = "EMPTY"
			name_label.add_theme_color_override("font_color", Color("8b8175"))
			if plate != null:
				plate.modulate = Color(1, 1, 1, 0.45)
		else:
			icon.texture = _spell_icon(spell)
			name_label.text = spell.display_name.to_upper()
			button.tooltip_text = "%s\n%s\nCooldown: %.1fs" % [
				spell.display_name, spell.description, spell.cooldown]
			button.pressed.connect(_cast.bind(slot))
		frame.add_child(button)
		# Keep the interactive surface behind informational overlays.
		frame.move_child(button, 1 if plate != null else 0)

		_spell_bar.add_child(frame)
		_spell_buttons.append(button)
		_spell_icons.append(icon)
		_spell_labels.append(name_label)
		_spell_cooldowns.append(cooldown)


func _spell_icon(spell: SpellData) -> Texture2D:
	if spell == null:
		return null
	var path: String = spell.get_sprite_path()
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


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
			_spell_cooldowns[slot].text = ""
			continue
		var left: float = _hero.spells.cooldown_ratio(slot)
		var button: Button = _spell_buttons[slot]
		button.disabled = left > 0.0
		_spell_cooldowns[slot].text = "" if left <= 0.0 else "%.1f" % (left * spell.cooldown)
		_spell_icons[slot].modulate = Color.WHITE if left <= 0.0 \
			else Color(0.35, 0.35, 0.38, 0.45)
		_spell_labels[slot].modulate = Color.WHITE if left <= 0.0 \
			else Color(0.55, 0.55, 0.58)


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


func _on_boss_phase_changed(boss_id: String, phase: int, phase_name: String) -> void:
	var data: EnemyData = ContentDB.enemy(boss_id)
	_message.text = "%s  —  %s\nReinforcements on the other roads." % [
		data.display_name if data != null else "The boss", phase_name.to_upper()]
	_message_left = 4.0
	if _boss_name != null:
		_boss_name.text = "%s  ·  %s" % [
			data.display_name if data != null else boss_id, phase_name]


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


# --- Command targeting ------------------------------------------------------

## Where a Command order lands.
##
## Orders used to be aimed by whatever slot the player last clicked, which made
## them unusable in the fight they exist for. During combat the build spots are
## deliberately not clickable - clicking one meant opening the build panel over
## the battle - so on a fresh battle nothing was selected and every hotkey
## answered "Select a built tower for Overdrive". The order was not broken; it
## had no way to be aimed.
##
## Aimed with the mouse instead, which is where the player is already pointing:
## Overdrive takes the built tower nearest the cursor, Rally the road the cursor
## is over, and Last Stand is the town and needs no aim at all. Clicking a tower
## during Preparation still selects it, and that selection is still honoured -
## it just is not required any more.
func _request_command(order_id: String) -> void:
	var lane: int = _selected_lane
	var slot: int = _selected_slot
	if order_id != CommandSystemScript.LAST_STAND and not RunState.can_build_now():
		var aimed: Vector2i = _aimed_slot(order_id == CommandSystemScript.OVERDRIVE)
		if aimed.x >= 0:
			lane = aimed.x
			slot = aimed.y
	command_requested.emit(order_id, lane, slot)


## The slot the cursor is aiming at, or (-1, -1). `built_only` restricts it to
## spots with a tower on them, so Overdrive skips over an empty spot that happens
## to be marginally nearer the cursor than the tower the player meant.
func _aimed_slot(built_only: bool) -> Vector2i:
	if battlefield == null:
		return Vector2i(-1, -1)
	var cursor: Vector2 = battlefield.get_global_mouse_position()
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for slot_node: TowerSlot in battlefield.all_slots():
		if built_only and slot_node.tower() == null:
			continue
		var distance: float = slot_node.global_position.distance_to(cursor)
		if distance < best_distance:
			best_distance = distance
			best = Vector2i(slot_node.lane, slot_node.slot)
	if best.x < 0:
		return best
	# Rally wants a road, and every point on the field is nearer one road than the
	# others, so it always has an answer. Overdrive wants a specific tower, and
	# aiming at the far side of the map should not reach across and boost one.
	if built_only and best_distance > Balance.COMMAND_AIM_RADIUS:
		return Vector2i(-1, -1)
	return best


# --- Build panel ------------------------------------------------------------

func _open_build_panel(lane: int, slot: int) -> void:
	_selected_lane = lane
	_selected_slot = slot
	if _command_target != null:
		var tower: TowerData = RunState.tower_in_slot(lane, slot)
		_command_target.text = "TARGET  ·  %s road  ·  %s" % [
			LANE_NAMES[clampi(lane, 0, 3)],
			tower.display_name if tower != null else "open spot"]
	_refresh_build_panel()
	_build_panel.visible = true
	UiSound.confirm()
	_pop_in(_build_panel)


func _close_build_panel() -> void:
	if _build_panel == null or not _build_panel.visible:
		return
	_build_panel.visible = false
	_show_build_detail("")


## A panel that appears instantly reads as a texture being switched on. A short
## overshoot reads as something being *brought up*, which is the difference
## between a menu and an interface.
##
## The pivot has to be set after a layout pass or the panel scales about its
## top-left and swings in from the corner - and this panel has no fixed height,
## so its size is not known until the frame it is shown.
func _pop_in(panel: Control) -> void:
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	await get_tree().process_frame
	if not is_instance_valid(panel) or not panel.visible:
		return
	panel.pivot_offset = panel.size * 0.5
	var tween: Tween = panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.12)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_build_panel() -> void:
	for child: Node in _build_list.get_children():
		child.queue_free()
	# The card the cursor was over has just been freed, so its mouse_exited will
	# never arrive. Without this the footer keeps describing a button that is no
	# longer there.
	_show_build_detail("")
	# Assume no grid; the two branches that build one turn the footer back on.
	_set_build_detail_visible(false)

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
		var target_priority: int = RunState.target_priority_in_slot(lane, slot)
		var target_button: Button = _add_button(_build_list,
			"Target: %s  ·  click to cycle" % TowerData.target_priority_name(target_priority),
			func() -> void:
				RunState.cycle_target_priority(lane, slot)
				_refresh_build_panel())
		target_button.tooltip_text = TowerData.target_priority_description(target_priority)
		_build_list.add_child(_label(TowerData.target_priority_description(target_priority), 13))
		if not RunState.is_preparation():
			var locked_note: Label = _label(
				"COMBAT LOCK  ·  upgrades and selling return in Preparation.\n"
				+ "This tower is selected for Overdrive; this road is selected for Rally.", 14)
			locked_note.add_theme_color_override("font_color", Color("e8a33d"))
			_build_list.add_child(locked_note)
			return
		var live_slot: TowerSlot = battlefield.slot_at(lane, slot)
		var live_tower: Tower = live_slot.tower() if live_slot != null else null
		if live_tower != null and live_tower.needs_repair():
			var repair_afford: bool = RunState.can_afford_cost(
				{RunState.WOOD: Balance.TOWER_REPAIR_WOOD_COST})
			var repair_button: Button = _add_button(_build_list, "Repair Tower", func() -> void:
				_report(battlefield.try_repair_tower(lane, slot))
				_refresh_build_panel())
			repair_button.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
			repair_button.tooltip_text = "Restore %d%% durability. Cost: %d Wood." % [
				int(round(Balance.TOWER_REPAIR_FRACTION * 100.0)), Balance.TOWER_REPAIR_WOOD_COST]
			IconKit.on_button(repair_button, "upgrade", 22)
			repair_button.disabled = not repair_afford
		var level_cap: int = RunState.tower_level_cap()
		if level < Balance.TOWER_MAX_LEVEL and level >= level_cap:
			_build_list.add_child(_label(
				"Forge tier %d required for level %d." % [level - Balance.TOWER_BASE_LEVEL_CAP + 1, level + 1], 14))
		elif level < Balance.TOWER_MAX_LEVEL:
			var cost: int = Battlefield.upgrade_cost_of(level)
			_add_stat_preview(existing, level)
			var afford: bool = RunState.can_afford_cost({RunState.GOLD: cost})
			var button: Button = _add_button(_build_list,
				"Upgrade to level %d" % (level + 1), func() -> void:
					_report(battlefield.try_upgrade(lane, slot))
					_refresh_build_panel())
			IconKit.on_button(button, "upgrade", 22)
			_attach_price(button, cost, afford)
			button.disabled = not afford
			if not afford:
				_build_list.add_child(_label("Need %d more Gold." % (
					cost - RunState.currency(RunState.GOLD)), 13))
		else:
			_build_list.add_child(_label("Fully upgraded.", 14))
		var sell: Button = _add_button(_build_list, "Sell", func() -> void:
			_report(battlefield.try_sell(lane, slot))
			_refresh_build_panel())
		# Every other button in this panel carries a mark; one bare label in the
		# column reads as an unfinished row rather than as a different action.
		IconKit.on_button(sell, "resource", 22)
		return

	var target_slot: TowerSlot = battlefield.slot_at(lane, slot)
	if not RunState.is_preparation():
		var lock_note: Label = _label(
			"COMBAT LOCK  ·  construction returns in Preparation.\n"
			+ "This road is selected for Rally Road.", 14)
		lock_note.add_theme_color_override("font_color", Color("e8a33d"))
		_build_list.add_child(lock_note)
		return
	if target_slot != null and target_slot.is_combo_slot():
		var combo: TowerData = target_slot.buildable_combination()
		if combo == null:
			var locked := HBoxContainer.new()
			locked.add_theme_constant_override("separation", 8)
			var lock: TextureRect = IconKit.rect("lock", 30.0, Color(0.75, 0.72, 0.66))
			if lock != null:
				locked.add_child(lock)
			locked.add_child(_label("Build a tower either side first.\nThe middle spot combines them.", 15))
			_build_list.add_child(locked)
			return
		# The two parents shown as their own element icons: what this slot makes
		# is a fact about two other slots, and the icons say that without reading.
		var parents := HBoxContainer.new()
		parents.add_theme_constant_override("separation", 6)
		for parent: int in [combo.parent_a, combo.parent_b]:
			var mark := TextureRect.new()
			mark.texture = IconKit.element(parent)
			mark.custom_minimum_size = Vector2(26.0, 26.0)
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			parents.add_child(mark)
		parents.add_child(_label("%s + %s" % [
			TowerData.element_name(combo.parent_a), TowerData.element_name(combo.parent_b)], 15))
		_build_list.add_child(parents)
		_build_list.add_child(_tower_card(combo, lane, slot))
		_set_build_detail_visible(true)
		return

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", BUILD_ROW_GAP)
	for tower: TowerData in ContentDB.base_towers():
		column.add_child(_tower_card(tower, lane, slot))
	_build_list.add_child(column)
	_set_build_detail_visible(true)


## Shows what the next level actually buys, before the player commits.
##
## Upgrading was a button with a price and no answer to "what do I get". Every
## stat that changes is listed as now -> next with the delta, and stats that do
## not change are left out entirely so the list is short enough to read mid-wave.
func _add_stat_preview(tower: TowerData, level: int) -> void:
	var next_level: int = level + 1

	var rows: Array[Dictionary] = []
	# Quoted as a range, because that is what the player watches float off an
	# enemy. A single averaged number they never actually observe reads as the
	# game misreporting itself.
	_collect_range(rows, "Damage", tower.damage_at(level), tower.damage_at(next_level))
	# Interval goes down as the tower gets faster, so shots per second is the
	# honest way to show it - a falling number reading as an upgrade is a trap.
	var rate_now: float = 1.0 / maxf(tower.interval_at(level), 0.001)
	var rate_next: float = 1.0 / maxf(tower.interval_at(next_level), 0.001)
	_collect_stat(rows, "Shots/sec", rate_now, rate_next, 2)
	_collect_stat(rows, "Damage/sec",
		tower.damage_at(level) * rate_now, tower.damage_at(next_level) * rate_next, 1)

	# Everything else the level buys, and only for the towers it applies to.
	# `_collect_stat` drops a row whose value does not change, so a single-target
	# tower never shows a blast radius and a burn tower never shows chain targets -
	# each tower's panel lists what that tower is actually for.
	_collect_stat(rows, "Range", tower.range_at(level), tower.range_at(next_level), 0)
	_collect_stat(rows, "Blast radius", tower.aoe_at(level), tower.aoe_at(next_level), 0)
	_collect_stat(rows, "Targets hit",
		float(1 + tower.extra_targets_at(level)),
		float(1 + tower.extra_targets_at(next_level)), 0)
	_collect_stat(rows, "Structure HP",
		tower.max_hp * tower.utility_at(level),
		tower.max_hp * tower.utility_at(next_level), 0)
	if tower.burn_dps > 0.0:
		_collect_stat(rows, "Burn/sec",
			tower.burn_dps * tower.utility_at(level),
			tower.burn_dps * tower.utility_at(next_level), 1)
	if tower.slow_factor < 1.0:
		# A slow is stored as a factor, where lower is stronger. Shown as the
		# percentage it takes off, so a bigger number is a better upgrade.
		_collect_stat(rows, "Slow",
			(1.0 - tower.slow_factor) * tower.utility_at(level) * 100.0,
			(1.0 - tower.slow_factor) * tower.utility_at(next_level) * 100.0, 0)
	if tower.ground_zone_dps > 0.0:
		_collect_stat(rows, "Ground/sec",
			tower.ground_zone_dps_at(level), tower.ground_zone_dps_at(next_level), 1)
	if tower.freeze_chance > 0.0:
		_collect_stat(rows, "Freeze chance",
			minf(tower.freeze_chance * tower.utility_at(level), 0.82) * 100.0,
			minf(tower.freeze_chance * tower.utility_at(next_level), 0.82) * 100.0, 0)
	if tower.lane_armour_bonus > 0.0:
		_collect_stat(rows, "Road armour",
			tower.lane_armour_bonus * tower.utility_at(level),
			tower.lane_armour_bonus * tower.utility_at(next_level), 1)

	if rows.is_empty():
		return

	var panel := PanelContainer.new()
	# The plain dark frame, not the ornate one. This sits inside the build panel,
	# and the same riveted border twice reads as a bug rather than as a nested box.
	panel.theme_type_variation = &"InnerPanel"
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


## A stat that lands somewhere inside a spread rather than on a number.
func _collect_range(rows: Array[Dictionary], name: String, from: float, to: float) -> void:
	if is_equal_approx(from, to):
		return
	var low: Vector2 = TowerData.damage_range(from)
	var high: Vector2 = TowerData.damage_range(to)
	var percent: float = ((to - from) / from * 100.0) if absf(from) > 0.001 else 0.0
	rows.append({
		"name": name,
		"from": "%d-%d" % [roundi(low.x), roundi(low.y)],
		"to": "%d-%d" % [roundi(high.x), roundi(high.y)],
		"delta": "+%d%%" % roundi(percent) if percent >= 0.0 else "%d%%" % roundi(percent),
	})


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


## One tower, as a card for the grid.
##
## The description does not live on the card. Eight wrapped paragraphs is what
## made the list too tall to fit, and the player is choosing between towers, not
## reading all eight - so the text goes to the footer for whichever one the
## cursor is over.
func _tower_card(tower: TowerData, lane: int, slot: int) -> Button:
	var cost: int = Battlefield.build_cost_of(tower)
	var cost_map: Dictionary = {RunState.GOLD: cost}
	if tower.is_combination:
		cost_map[RunState.STONE] = Balance.TOWER_COMBO_STONE_COST
	var affordable: bool = RunState.can_afford_cost(cost_map)

	var button := Button.new()
	button.text = tower.display_name
	button.custom_minimum_size = Vector2(0.0, BUILD_ROW_HEIGHT)
	button.icon = IconKit.element_sized(tower.element, 26)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE

	_attach_price(button, cost, affordable)
	button.disabled = not affordable
	button.add_theme_color_override("font_color", TowerData.element_colour(tower.element))
	button.pressed.connect(func() -> void:
		Sfx.play("sfx_tower_build", -4.0)
		_report(battlefield.try_build(lane, slot, tower))
		_refresh_build_panel())

	# Hovering explains, in the footer, immediately.
	#
	# There was a tooltip carrying the same string "for anyone who waits". What
	# that actually did was print the description twice: the footer answered on
	# entry, and a second later an identical floating box appeared over the row
	# and covered the towers the player was comparing it against. One answer, in
	# the place the panel reserves for answers.
	var blurb: String = "%s  ·  %s\nCost: %s" % [TowerData.element_name(tower.element),
		tower.description, RunState.format_cost(cost_map)]
	button.mouse_entered.connect(func() -> void: _show_build_detail(
		blurb if affordable else "%s\nInsufficient currency." % blurb))
	button.mouse_exited.connect(func() -> void: _show_build_detail(""))
	return button


## Blank means "nothing hovered", which reads as a hole in the panel rather than
## as an empty field. The footer's height is reserved either way, so it may as
## well say what it is for.
const BUILD_HINT: String = "Point at a tower to see what it does."


## Pins a price to the right edge of a button, clear of the frame.
##
## A right-anchored child rather than part of the label, so a column of them
## lines up. Padding the string out with spaces cannot work here: the theme font
## is proportional, so a space is not a fixed width and the prices land ragged.
##
## It also keeps long labels off the frame. "Upgrade to level 2 - 90 resources"
## as one string ran the word "resources" straight into the right-hand bolt.
func _attach_price(button: Button, cost: int, affordable: bool) -> void:
	var price := Label.new()
	price.text = str(cost)
	price.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	price.offset_left = -110.0
	price.offset_right = -BUILD_ROW_PRICE_INSET
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.add_theme_font_size_override("font_size", 17)
	price.add_theme_color_override("font_color",
		Color("d8cfba") if affordable else Color(0.62, 0.44, 0.38))
	button.add_child(price)


func _show_build_detail(text: String) -> void:
	if _build_detail == null:
		return
	var showing: bool = not text.is_empty()
	_build_detail.text = text if showing else BUILD_HINT
	_build_detail.add_theme_color_override("font_color",
		Color("cfe0da") if showing else Color(0.62, 0.66, 0.64, 0.55))


## The footer belongs to the tower grid. On the upgrade view there is nothing to
## point at, so inviting the player to point at something is just noise taking up
## fifty-six pixels.
func _set_build_detail_visible(showing: bool) -> void:
	if _build_detail != null:
		_build_detail.visible = showing


## Empty means the action succeeded, so only refusals are ever shown.
##
## A refusal now sounds like one. The click a button makes is the same whether it
## worked or not, so without this the only signal that a build was rejected is a
## line of text appearing above the town - which is not where the player is
## looking when they click a slot on the right of the screen.
func _report(problem: String) -> void:
	if problem.is_empty():
		return
	UiSound.deny()
	_message.text = problem
	_message_left = 2.4
	_nudge(_message)


## A short shake on the message, so a second identical refusal still registers.
## Re-showing the same string is otherwise invisible.
func _nudge(node: Control) -> void:
	node.modulate = Color(1.0, 0.55, 0.45)
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "modulate", Color.WHITE, 0.45)


# --- Signal handlers --------------------------------------------------------

func _on_currency_changed(id: String, amount: int) -> void:
	var label: Label = _currency_labels.get(id, null) as Label
	if label != null:
		label.text = str(amount)
	if _build_panel.visible:
		_refresh_build_panel()
	_update_repair_button()


func _refresh_currencies() -> void:
	for id: String in RunState.CURRENCIES:
		_on_currency_changed(id, RunState.currency(id))

func _on_distance(total: float, to_crossroad: float) -> void:
	# "Distance" is dropped - the icon says it. "crossroad in" is kept, because
	# that is a second number and an icon cannot tell the two apart.
	_distance.text = "%d   ·   crossroad in %d" % [int(total), int(ceil(to_crossroad))]


func _on_town_health(current: float, maximum: float) -> void:
	_town_bar.value = current / maximum if maximum > 0.0 else 0.0


func _on_hero_health(current: float, maximum: float) -> void:
	_hero_bar.value = current / maximum if maximum > 0.0 else 0.0


func _on_hero_wounds_changed(wounds: int, maximum: int) -> void:
	if _wounds_label == null:
		return
	_wounds_label.text = "Wounds %d/%d" % [wounds, maximum]
	_wounds_label.add_theme_color_override("font_color",
		Color("dc6548") if wounds > 0 else Color("aebcb8"))


func _on_charge(value: float) -> void:
	_charge_bar.value = value
	_refresh_horn_button()


func _refresh_horn_button() -> void:
	if _horn_button == null:
		return
	_horn_button.disabled = RunState.phase != RunState.Phase.ROAD_BATTLE \
		or RunState.horn_active or RunState.horn_used_this_battle \
		or RunState.raid_charge >= 1.0


func _on_wave(number: int, lanes: Array) -> void:
	var names: PackedStringArray = []
	for lane: int in lanes:
		names.append(LANE_NAMES[clampi(lane, 0, 3)])
	_wave.text = "%d" % number
	_message.text = "Wave %d  —  %s" % [number, ", ".join(names)]
	_message_left = 2.0


func _on_wave_archetype(number: int, archetype_id: String) -> void:
	var archetype: WaveArchetypeData = ContentDB.wave_archetype(archetype_id)
	if archetype == null:
		return
	_message.text = "Wave %d  —  %s\n%s" % [
		number, archetype.display_name.to_upper(), archetype.description]
	_message_left = 3.1


func _on_act(act: int, terrain_id: String) -> void:
	var terrain: TerrainData = ContentDB.terrain(terrain_id)
	_act.text = "Act %d  ·  %s" % [act, terrain.display_name if terrain != null else "—"]


func _on_scope_changed(scope: int) -> void:
	var in_raid: bool = scope == int(GameDirector.Scope.RAID)
	var on_field: bool = scope == int(GameDirector.Scope.BATTLEFIELD)
	_raid_panel.visible = in_raid
	_build_panel.visible = _build_panel.visible and on_field
	if _command_panel != null:
		_command_panel.visible = on_field and RunState.is_command_combat()
	if _preparation_panel != null:
		_preparation_panel.visible = on_field and RunState.is_preparation()
	if _spell_bar != null:
		_spell_bar.visible = on_field or in_raid
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
