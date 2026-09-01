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

## Zoom a step in or out. The HUD owns no camera; the run does.
signal zoom_requested(steps: int)

## Open the pause menu, for anything with no Escape key.
signal pause_requested()
signal horn_requested()
signal raid_requested()
signal extract_requested()
signal ride_on_requested()
signal command_requested(order_id: String, anchor: Vector2i)

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
## Wide enough for the element rail and the towers it pulls out beside it.
const BUILD_PANEL_WIDTH: float = 560.0

## The element rail down the left of the build panel.
const ELEMENT_RAIL_WIDTH: float = 150.0
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

## How far the build sheet's lower edge sits above the combat row.
##
## The command panel's old bottom edge, inherited on purpose: that gap was
## already tuned to clear the bottom band without wasting the space.
const BUILD_PANEL_LIFT: float = 164.0

## The same, for a thumb.
##
## The Preparation box sits in the bottom centre between 156 and 272 above the
## combat row. On desktop the build sheet is far enough right to pass beside it;
## on touch that box grows past its authored width and the sheet's Close button
## lands on it. Cleared rather than narrowed: the box is what a player reads to
## decide whether to press Ride On, so it wins the space.
const BUILD_PANEL_TOUCH_LIFT: float = 24.0

## The hover figures box, which sits *beside* the build panel rather than over it.
##
## Godot's own `tooltip_text` opens at the cursor, and the cursor is by definition
## inside the panel - so the numbers for the tower being considered landed on top
## of the towers it was being compared against. A player cannot compare two rows
## when reading one of them hides the other.
##
## The panel is pinned to the right edge, so anything parked immediately to its
## left is guaranteed to be outside it at any window size, with no overlap test
## to get wrong.
const BUILD_TOOLTIP_WIDTH: float = 320.0
const BUILD_TOOLTIP_GAP: float = 12.0

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

## The ability's mark, inside its slot. Larger under a thumb for the same reason
## everything else is: it is being read at arm's length on a small screen.
const SPELL_ICON_SIZE: float = 26.0
const SPELL_ICON_TOUCH_SIZE: float = 46.0

## Gap between the spell bar and the screen edge.
const SPELL_BAR_MARGIN: float = 24.0

## Height of the bottom band the ability bar owns. Everything that used to sit
## on the bottom edge is lifted by this, so the bar has a row to itself.
const BOTTOM_BAND: float = SPELL_SLOT_SIZE.y + SPELL_BAR_MARGIN

## One square in the scope column, and the art inside it.
##
## Matched to the combat row's buttons deliberately: the two are one control
## system - where you are, and what you do while you are there - and a player
## should not have to learn that they are different sizes to know they are
## different things.
const NAV_ICON_SIZE: float = 58.0
const NAV_ICON_ART: int = 38
const NAV_TOUCH_ICON_SIZE: float = 92.0
const NAV_TOUCH_ICON_ART: int = 72

## Padding inside a scope button, on all four sides.
##
## Overridden rather than inherited. The theme's button style pads the sides far
## more than the top and bottom, which is right for a label and wrong for a
## square: it made a 58px button 100px wide, so a column of squares came out a
## column of letterboxes with a small mark in the middle of each.
const NAV_ICON_PAD: float = 8.0

## How far down the scope column starts. Below the top bar and no further:
## sitting higher with less padding was the whole objection to the old one.
const NAV_BAR_TOP: float = 104.0

## The command column, top left.
## The currency marks along the top edge.
const TOP_BAR_ICON: float = 28.0
const TOP_BAR_ICON_TOUCH: float = 44.0
const TOP_BAR_FONT_TOUCH: int = 34
const TOP_BAR_FONT_MIN: int = 19
## The two health tracks in the strip, at full size.
const TOWN_BAR_WIDTH: float = 240.0
const HERO_BAR_WIDTH: float = 180.0
## The width at which the strip can be drawn at full touch size.
##
## Measured, not guessed: an act name, a level, the weather, four currencies and
## the boss track come to about 2070 layout units at full touch size, and a
## little headroom on top of that. A phone held upright gives 1680, so it gets
## roughly two thirds and everything stays on screen; held sideways it gives
## 2335 and the strip grows all the way.
const TOP_BAR_FULL_WIDTH: float = 2200.0

const COMMAND_BAR_WIDTH: float = 236.0
const COMMAND_BAR_TOP: float = 104.0

## Where the boss track sits, and where it moves to for a thumb.
##
## It shares the top edge with the resource bar, which is fine at desktop sizes
## and is not once the currency icons and their numbers are grown for touch: the
## row then reaches into the centre and prints straight through "Act 1 boss in
## 900 distance". Dropped below the bar rather than shortened, because the thing
## it is competing with is the information a player checks most often.
## The centred stack, top to bottom, in both layouts.
##
## One table rather than four scattered numbers, because they are not four
## independent decisions - they are a column, and the only thing that matters is
## that each clears the one above it. Touch grows the resource bar into the
## centre of the top edge, so everything below shifts by roughly one row rather
## than one element being nudged and the collision moving down to the next.
const BOSS_TRACK_TOP: float = 14.0
const BOSS_TRACK_TOUCH_TOP: float = 78.0
const MESSAGE_TOP: float = 90.0
const MESSAGE_TOUCH_TOP: float = 130.0
const STATE_LABEL_TOP: float = 132.0
const STATE_LABEL_TOUCH_TOP: float = 172.0

@export var battlefield: Battlefield

var _resources: Label
var _currency_labels: Dictionary = {}
## The rows themselves, so their marks can be re-cut when the layout changes.
var _currency_rows: Dictionary = {}
## The second line of run telemetry, which has to sit under the first however
## tall the first has become.
var _journey_bar: HBoxContainer
## Weapon, shots left and what is nocked. Null until a bow is found.
var _quiver_row: HBoxContainer
var _quiver_label: Label
var _level: Label
var _weather: Label
var _distance: Label
var _wave: Label
var _wave_preview: Label
var _act: Label
var _town_bar: ProgressBar
var _hero_bar: ProgressBar
var _xp_band: Control
var _xp_bar: ProgressBar
var _xp_label: Label
var _wounds_label: Label
var _item_row: HBoxContainer

## What the carried-item row was last built from, so a row of icons is not
## freed and rebuilt sixty times a second to draw the same two things.
var _items_signature: String = ""
var _charge_bar: ProgressBar
var _horn_button: Button
var _raid_button: Button
var _repair_button: Button

## Build or Fight, during Preparation. Hidden outside it, because outside it
## there is nothing to build and the question does not arise.
var _mode_button: Button

## The party feed and the box a player types into.
var _party_log: PartyLog = null
var _chat_box: LineEdit = null
var _tend_button: Button
## Whether healing is both needed and affordable. Drives the pulse below.
var _tend_urgent: bool = false
var _tend_pulse: float = 0.0
## Breathing room either side of a centred banner, and the narrowest it may get
## before it simply overflows rather than becoming a column of single words.
const BANNER_MARGIN: float = 12.0
const BANNER_MIN_HALF: float = 150.0
## Below this logical width the nav bar and a centred banner cannot both have
## the full width, and the banner is the one that gives way.
const NARROW_WIDTH: float = 1500.0
## The width the nav bar column occupies, plus a gap.
const NAV_STRIP: float = 140.0
## How many action buttons fit across a phone before they have to wrap.
## How many action buttons fit across, when a thumb is driving.
##
## **Was a flat 3, and that shape cost more screen than the buttons did.** Five
## thumb-sized targets do not fit a 720-wide phone, so they were wrapped onto two
## rows - and two rows of 120 plus the charge readout is a 356px band across the
## bottom of the screen. Worse, the ability slots share that row and stretch to
## match it, so a 132px slot came out 356 and the whole lower third of a
## *landscape* phone was interface, on a screen with room for one row twice over.
##
## Asked of the width instead. A landscape phone gets one row and its field back;
## a portrait one still wraps, because there the original reasoning holds.
## The preparation card's corner, when a thumb is driving.
##
## Smaller than the desktop card and out of the play area: it is on screen for
## the whole of every Preparation, so every pixel of it is a pixel of road
## nobody can see. The RIDE ON button inside it stays a full touch target - the
## card shrinks around it rather than at its expense.
const PREPARATION_TOUCH_MARGIN: float = 24.0
const PREPARATION_TOUCH_TOP: float = 128.0
const PREPARATION_TOUCH_WIDTH: float = 360.0
const PREPARATION_TOUCH_HEIGHT: float = 164.0

## How far above centre an announcement sits when a thumb is driving.
const REGION_CARD_TOUCH_RISE: float = 160.0
const REGION_CARD_TOUCH_LEFT: float = 220.0

const ACTION_COLUMNS: int = 3
## Six, not five: the raid-charge readout is the sixth thing in the grid, and at
## five columns it wrapped onto a row of its own and took the band back up to
## 240 to hold a 48px label.
const ACTION_COLUMNS_WIDE: int = 6
## Width, in layout units, below which the buttons have to wrap.
const ACTION_WRAP_BELOW: float = 1500.0


static func _action_columns() -> int:
	if not touch_ui():
		return ACTION_COLUMNS_WIDE
	var span: float = 0.0
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		span = tree.root.get_visible_rect().size.x
	var landscape: bool = false
	if tree != null and tree.root != null:
		var size: Vector2 = tree.root.get_visible_rect().size
		landscape = size.x > size.y
	return ACTION_COLUMNS_WIDE if landscape or span >= ACTION_WRAP_BELOW else ACTION_COLUMNS
## What `_build_action_bar` puts in the bar. Horn, Raid, Build, Repair, Tend.
const ACTION_BUTTON_COUNT: int = 5
## The authored height of one, before a thumb grows it.
const ACTION_BUTTON_HEIGHT: float = 54.0
const ACTION_ROW_GAP: float = 8.0

var _message: Label
var _message_left: float = 0.0
var _top_bar: HBoxContainer

## The rosette listens to EventBus.lane_pressure_changed itself, so the HUD only
## has to decide whether it is on screen.
var _lane_ring: Control
var _build_panel: PanelContainer
var _build_scroll: ScrollContainer
var _build_column: VBoxContainer

## The road sheet: traps and barricades, for the tile that was clicked.
var _road_panel: PanelContainer
var _road_list: VBoxContainer
var _road_title: Label
var _road_tile: Vector2i = Vector2i.ZERO

## Which element's towers the build panel is showing, or -1 for none. Survives a
## refresh, because building a tower rebuilds the panel and collapsing the rail
## each time would fight the player placing three Water towers in a row.
var _build_element: int = -1
var _build_list: VBoxContainer
var _build_title: Label
var _build_detail: Label
var _build_tooltip: PanelContainer
var _build_tooltip_label: Label
## The tile the build panel is open on, or an impossible anchor for "none".
var _selected: Vector2i = Vector2i(-999, -999)

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
var _bottom_row: HBoxContainer
var _nav_bar: VBoxContainer
var _boss_box: VBoxContainer
var _nav_buttons: Array[Button] = []
var _boss_panel: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss_id: String = ""
var _tutorial: TutorialCoach
var _region_card: VBoxContainer
var _region_kicker: Label
var _region_title: Label
var _region_tween: Tween = null
var _state_label: Label
var _recovery_status: Label
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
	# World post-processing sits on layer 2; interface must remain ungraded.
	layer = 20
	# The HUD is a CanvasLayer, so the size that matters is the viewport's.
	get_viewport().size_changed.connect(_refit_banners)
	_build_top_bar()
	_build_lane_ring()
	_build_nav_bar()
	_build_tower_panel()
	_build_road_panel()
	_build_raid_panel()
	_build_boss_track()
	_build_bottom_row()
	_build_party_feed()
	_build_xp_bar()
	_build_boss_bar()
	_build_region_card()
	_build_tutorial_coach()
	_build_preparation_panel()
	_build_command_panel()
	_refit_banners()  # once the whole HUD exists

	EventBus.resources_changed.connect(func(v: int) -> void:
		if _resources != null:
			_resources.text = "%d" % v
		if _build_panel.visible:
			_refresh_build_panel())
	EventBus.distance_changed.connect(_on_distance)
	EventBus.town_health_changed.connect(_on_town_health)
	EventBus.hero_health_changed.connect(_on_hero_health)
	EventBus.hero_wounds_changed.connect(_on_hero_wounds_changed)
	EventBus.hero_xp_changed.connect(_on_hero_xp_changed)
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
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.run_started.connect(_rebuild_spell_bar)
	EventBus.construction_completed.connect(func(_id: String, _tier: int) -> void:
		if _build_panel.visible:
			_refresh_build_panel())
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.preparation_changed.connect(_on_preparation_changed)
	EventBus.preparation_warning.connect(_show_message)
	# The spirit collection, said out loud on the road. A discovery the player
	# only finds later in a menu is a discovery that did not happen when it
	# happened - and the shiny is the whole reason to look up from the fight.
	EventBus.spirit_discovered.connect(_on_spirit_discovered)
	EventBus.spirit_bonded.connect(_on_spirit_bonded)
	EventBus.spirit_downed.connect(func(_key: String, seconds: float) -> void:
		_show_message("Your spirit is re-forming  ·  %ds" % int(ceil(seconds))))
	EventBus.spirit_returned.connect(func(_key: String) -> void:
		_show_message("Your spirit has returned."))
	EventBus.command_changed.connect(_on_command_changed)
	EventBus.command_order_used.connect(_on_command_order_used)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.ammo_changed.connect(func(_id: String, _held: int) -> void:
		_refresh_quiver())
	EventBus.blueprint_learned.connect(func(_id: String, _fresh: bool) -> void:
		_refresh_quiver())
	EventBus.last_scar_changed.connect(func(_state: String) -> void:
		_refresh_recovery_status())
	EventBus.last_scar_resolved.connect(_on_last_scar_resolved)
	TouchInput.shown_changed.connect(_on_touch_layout_changed)

	if battlefield != null and battlefield.placement != null:
		battlefield.placement.tile_clicked.connect(_open_build_panel)
		battlefield.placement.road_tile_clicked.connect(_open_road_panel)

	_hero = battlefield.hero if battlefield != null else null
	_refresh_currencies()
	_on_act(RunState.act, RunState.terrain_id)
	_rebuild_spell_bar()
	_refresh_state_label()
	_on_phase_changed(int(RunState.phase), int(RunState.phase))
	_on_preparation_changed(0.0, true)
	_on_command_changed(RunState.command, Balance.COMMAND_MAX)
	_on_hero_wounds_changed(RunState.hero_wounds, RunState.max_wounds())
	_refresh_recovery_status()
	_refresh_xp_bar()
	_on_touch_layout_changed(touch_ui())
	_on_scope_changed(int(GameDirector.current_scope))


func _process(delta: float) -> void:
	# A slow warm breath rather than a flash: the player is being told an
	# option exists, not alarmed. Driven here because the refresh that
	# decides urgency runs on events, and a pulse has to run on frames.
	if _tend_button != null and _tend_urgent:
		_tend_pulse += delta * Balance.HUD_HEAL_PULSE_RATE
		var warmth: float = 0.5 + 0.5 * sin(_tend_pulse)
		_tend_button.modulate = Color.WHITE.lerp(
			Balance.HUD_HEAL_URGENT_TINT, warmth)
	_refresh_recovery_status()
	if Input.is_action_just_pressed(&"ride_on"):
		ride_on_requested.emit()
	if Input.is_action_just_pressed(&"tend") and battlefield != null:
		_report(battlefield.try_tend_hero())
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
	_update_carried_items()
	_update_boss_track()
	_update_repair_button()
	_update_wave_preview()


## End-of-run presentation keeps only the top telemetry strip. Every lower HUD
## control is both visual clutter over the debrief and an input blocker at the
## exact place its Return button sits; hiding them also leaves the final battle
## state visible through the translucent report instead of replacing it.
func show_end_report() -> void:
	for control: Control in [
		_lane_ring, _build_panel, _build_tooltip, _road_panel, _raid_panel,
		_spell_bar, _bottom_row, _nav_bar, _boss_panel, _region_card,
		_preparation_panel, _command_panel, _xp_band, _party_log, _chat_box,
		_boss_track, _message, _state_label, _recovery_status,
	]:
		if control != null:
			control.visible = false
	if _tutorial != null:
		_tutorial.visible = false


# --- Construction -----------------------------------------------------------

## Keeps a centred banner inside the screen it is drawn on.
##
## These are laid out as a half-width either side of centre, which is exact and
## readable and assumes the viewport is at least as wide as the number. On a
## phone it is not: the message banner is 800 units across and the logical
## viewport is 720, so it hung 40 units off both edges and the layout gate found
## it the moment `ScreenFit` stopped shrinking everything to a fifth of its size.
##
## Clamped rather than re-anchored, so a desktop keeps the authored width and
## only a screen too narrow for it gives anything up.
## Every centred banner, re-fitted. Called when the screen changes size.
func _refit_banners() -> void:
	for pair: Array in [[_state_label, 520.0], [_message, 400.0],
			[_wave_preview, 420.0], [_raid_panel, 280.0],
			[_preparation_panel, 190.0], [_boss_panel, 420.0]]:
		var control: Control = pair[0] as Control
		if control != null and is_instance_valid(control):
			_fit_centred(control, float(pair[1]))
	_fit_build_panel()
	_place_preparation_panel()


func _fit_centred(control: Control, half: float) -> void:
	var wide: float = get_viewport().get_visible_rect().size.x
	if wide <= 0.0:
		return
	# **The nav bar is a column down the right edge**, so a banner cannot clear
	# it by moving down - there is another button under the last one. It has to
	# stop short of it instead. On a wide screen there is room for both and this
	# reserves nothing.
	# A constant rather than the bar's own `size.x`: containers have not laid
	# themselves out while the HUD is still being built, so asking then reserves
	# nothing and the banner is placed as if the bar were not there.
	var reserved: float = NAV_STRIP if wide < NARROW_WIDTH else 0.0
	var room: float = (wide - reserved) * 0.5 - BANNER_MARGIN
	var kept: float = minf(half, maxf(room, BANNER_MIN_HALF))
	# Anchored to the centre of the whole screen, so giving up the right-hand
	# strip means shifting left by half of it, not just narrowing.
	var shift: float = reserved * 0.5
	control.offset_left = -kept - shift
	control.offset_right = kept - shift
	if control is Label:
		(control as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _label(text: String, size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	_top_bar = bar
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

	# The level sits with the act rather than with the currencies: it is what the
	# player has become, not what they can spend.
	_level = _label("Lv 1")
	_level.tooltip_text = "Persistent hero level. Earn XP in battles and raids."
	bar.add_child(_level)

	_weather = _label("Clear")
	_weather.tooltip_text = "Weather over the road."
	bar.add_child(_weather)

	_currency_labels.clear()
	_currency_rows.clear()
	for id: String in RunState.CURRENCIES:
		var resource_row: HBoxContainer = IconKit.labelled(id, "0", 17, 24)
		resource_row.tooltip_text = RunState.currency_name(id)
		bar.add_child(resource_row)
		_currency_labels[id] = IconKit.label_of(resource_row)
		_currency_rows[id] = resource_row
	_size_top_bar()
	_resources = _currency_labels.get(RunState.GOLD, null) as Label
	_refresh_quiver()
	# Journey telemetry gets a quiet second line. Keeping it out of this wide
	# health row prevents four currencies from colliding with the boss tracker at
	# 1920x1080 and gives every counter a stable place at narrower ratios.
	var journey_bar := HBoxContainer.new()
	_journey_bar = journey_bar
	journey_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	journey_bar.position = Vector2(24.0, 52.0)
	journey_bar.add_theme_constant_override("separation", 20)
	add_child(journey_bar)
	var distance_row: HBoxContainer = IconKit.labelled("distance", "0", 15, 21)
	var wave_row: HBoxContainer = IconKit.labelled("wave", "0", 15, 21)
	for row: HBoxContainer in [distance_row, wave_row]:
		journey_bar.add_child(row)
	# The quiver, shown only once there is one.
	#
	# **Hidden until the hero is armed**, which is most of every run: a readout
	# for a system the player has not met yet is clutter, and it also means the
	# layout gates - which run a fresh, melee-only state - see exactly the HUD
	# they saw before this existed.
	_quiver_row = IconKit.labelled("gold", "", 15, 21)
	_quiver_row.visible = false
	journey_bar.add_child(_quiver_row)
	_quiver_label = IconKit.label_of(_quiver_row)

	_distance = IconKit.label_of(distance_row)
	_wave = IconKit.label_of(wave_row)
	var seed_label: Label = _label("SEED  " + RunState.seed_code(), 12)
	seed_label.tooltip_text = "Gameplay seed. Enter this code on the main menu to reproduce road, wave, raid and reward rolls."
	seed_label.add_theme_color_override("font_color", Color("778985"))
	journey_bar.add_child(seed_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	_town_bar = _make_bar(Color("8a5a3a"), TOWN_BAR_WIDTH)
	bar.add_child(_bar_icon("city_health", "Town"))
	bar.add_child(_town_bar)

	_hero_bar = _make_bar(Color("c4552e"), HERO_BAR_WIDTH)
	bar.add_child(_bar_icon("hero_health", "Hero"))
	bar.add_child(_hero_bar)
	var wound_row := HBoxContainer.new()
	wound_row.add_theme_constant_override("separation", 5)
	var wound_icon: Control = _bar_icon("wounds", "Wounds")
	wound_icon.custom_minimum_size = Vector2(24.0, 24.0)
	wound_row.add_child(wound_icon)
	_wounds_label = _label("0/%d" % RunState.max_wounds(), 15)
	_wounds_label.tooltip_text = "A lethal down adds one Wound and reduces maximum HP by 10%. Reaching the limit ends the run."
	wound_row.tooltip_text = _wounds_label.tooltip_text
	wound_row.add_child(_wounds_label)
	bar.add_child(wound_row)

	# A carried item nobody can see is an item nobody plays around. A consumable
	# changes how much risk is worth taking, so it sits beside the Wounds it
	# exists to prevent - and the row stays empty until something is held,
	# because an empty slot in the top bar reads as a thing that is broken.
	#
	# **A row rather than one icon.** It used to be a single hardcoded Draught,
	# which was the visible half of the same assumption that made the Draught the
	# only consumable this game could ever have. Icons follow the same id-derived
	# convention as every resource, so a new item appears here by existing.
	_item_row = HBoxContainer.new()
	_item_row.add_theme_constant_override("separation", 4)
	bar.add_child(_item_row)

	_state_label = _label("", 19)
	_state_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_state_label.offset_top = STATE_LABEL_TOP
	_fit_centred(_state_label, 520.0)
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_state_label)

	_recovery_status = _label("", 16)
	_recovery_status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_recovery_status.offset_top = STATE_LABEL_TOP + 30.0
	_fit_centred(_recovery_status, 680.0)
	_recovery_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recovery_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_recovery_status)

	_message = _label("", 22)
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.offset_top = MESSAGE_TOP
	_fit_centred(_message, 400.0)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_color", Color("e8a33d"))
	add_child(_message)

	_wave_preview = _label("", 15)
	_wave_preview.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_wave_preview.offset_top = 158.0
	_fit_centred(_wave_preview, 420.0)
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


## Two bars, split by what the buttons are *for* rather than by what fits.
##
## Everything used to live on one wide row pinned to the bottom left, with the
## ability slots on a second row underneath it. That reads as an afterthought
## bolted below the interface, and it is the wrong way round besides: abilities
## are the thing a player uses every few seconds and they were the row furthest
## from the eye, under nine buttons most players press once a minute.
##
## Now the split is by frequency and by kind:
##
##   right edge    scope switching, zoom and the menu - navigation, and rarely
##                 touched during a fight
##   top left      command orders, which are aimed rather than pressed
##   bottom centre one row: the combat actions, then the abilities
##
## Nothing is stacked on anything, both bottom corners are left empty for thumbs,
## and the row a player actually watches sits in the middle of the bottom edge
## where their eyes already are.


## Where you are, as a column of icons down the right edge.
##
## It was a horizontal row of text buttons, and the objection was not what was in
## it but its shape. A row across the top has to be read left to right and then
## pointed at; a column of squares under a thumb is one movement, and it stops
## competing with the centred status band for the same horizontal space - which
## is what forced the old bar down to y=196 to begin with. Being narrow is what
## lets it sit higher, which was the other half of the complaint.
##
## Icons rather than words because the words were the widest thing about it, and
## because "F1 Battlefield" names a key a phone does not have. The shortcut
## survives in the tooltip: useful to the people holding a keyboard, invisible to
## the people who are not.
func _build_nav_bar() -> void:
	var bar := VBoxContainer.new()
	_nav_bar = bar
	bar.name = "NavBar"
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.offset_right = -24.0
	bar.offset_top = NAV_BAR_TOP
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)

	_nav_buttons.append(_add_icon_button(bar, "scope_battlefield",
		"Battlefield  (F1)",
		func() -> void: scope_requested.emit(GameDirector.Scope.BATTLEFIELD)))
	_nav_buttons.append(_add_icon_button(bar, "scope_town", "Town  (F2)",
		func() -> void: scope_requested.emit(GameDirector.Scope.TOWN)))
	_nav_buttons.append(_add_icon_button(bar, "scope_beast", "Beast  (F3)",
		func() -> void: scope_requested.emit(GameDirector.Scope.BEAST)))

	# Zoom stays in the column rather than somewhere tidier, because it is
	# navigation too - and it is not optional: the whole field does not fit a
	# phone screen at combat zoom. Glyphs rather than icons, because plus and
	# minus are already universal and two more 128px assets would say less.
	var zoom_out: Button = _add_icon_button(bar, "", "Zoom out",
		func() -> void: zoom_requested.emit(-1))
	zoom_out.text = "\u2212"
	_nav_buttons.append(zoom_out)
	var zoom_in: Button = _add_icon_button(bar, "", "Zoom in",
		func() -> void: zoom_requested.emit(1))
	zoom_in.text = "+"
	_nav_buttons.append(zoom_in)

	# Escape is the only other way to reach the pause menu, and a phone browser
	# has no Escape - so without this there is no way off the battlefield, out of
	# the settings, or out of the game.
	_nav_buttons.append(_add_icon_button(bar, "pause", "Menu  (Esc)",
		func() -> void: pause_requested.emit()))
	# **Marked before the touch pass can reach them.**
	#
	# `_size_nav_bar` already gives these their thumb size, and `UiMetrics`
	# multiplies a button's minimum height again on top - so a 120px square came
	# out 240 and a column of six ran 1490px down a screen 1080 tall. The bottom
	# three, zoom and the pause menu among them, were simply not on the phone.
	for button: Button in _nav_buttons:
		button.set_meta(UiMetrics.SELF_SIZED, true)
		button.set_meta(UiMetrics.TOUCH_TARGET_HEIGHT, NAV_TOUCH_ICON_SIZE)
	_size_nav_bar()


## How far above the bottom edge the build sheet's lower rim sits.
func _build_panel_lift() -> float:
	var base: float = BUILD_PANEL_TOUCH_LIFT if touch_ui() else BUILD_PANEL_LIFT
	return base + _bottom_band_height()


## Holds the build sheet inside the screen, scrolling its contents if it cannot.
##
## Called wherever the sheet is shown or rebuilt, because its height is decided
## by its contents and those change - eight towers, one upgrade, or a road with
## nothing on it.
func _fit_build_panel() -> void:
	if _build_panel == null or _build_scroll == null or _build_column == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var span: float = screen.y
	var lift: float = _build_panel_lift()
	# **Across the bottom when the screen is tall, down the side when it is
	# wide.** A right-hand sheet needs a column of screen beside the field, and a
	# phone held upright has not got one: the sheet and anything centred - an act
	# announcement, a wave banner - are simply in the same place. Held sideways
	# there is room for both, which is where it started.
	if screen.y > screen.x:
		_build_panel.offset_left = BUILD_PANEL_MARGIN
		_build_panel.offset_right = -BUILD_PANEL_MARGIN - nav_column_width()
	else:
		_build_panel.offset_left = -BUILD_PANEL_WIDTH - _build_panel_inset()
		_build_panel.offset_right = -_build_panel_inset()
	# Clear of the scope column's top, so the sheet never grows up behind it.
	var room: float = maxf(span - lift - NAV_BAR_TOP, 160.0)
	# **The content's height, not the panel's.**
	#
	# A ScrollContainer's own minimum is nearly nothing - that is what lets it
	# scroll - so asking the panel how tall it wants to be now answers "barely
	# any", and the sheet collapsed to zero with its list spilling out below.
	# The column inside still knows its real height.
	var frame: float = 0.0
	var style: StyleBox = _build_panel.get_theme_stylebox("panel")
	if style != null:
		frame = style.get_minimum_size().y
	var wanted: float = _build_column.get_combined_minimum_size().y + frame
	var height: float = minf(wanted, room)
	_build_panel.offset_top = -(lift + height)
	_build_panel.offset_bottom = -lift


## How far in from the right edge the build sheet has to start.
##
## Clear of the scope column, not merely below it. The sheet's *height* changes
## with what is in it - eight towers, or one upgrade - so a rule that relies on
## it staying short breaks the first time somebody adds a tower. A column's width
## does not change, so this is the half of "must not overlap" that cannot come
## undone.
func _build_panel_inset() -> float:
	return BUILD_PANEL_MARGIN + nav_column_width() + 16.0


## The scope column's width, including the margin it holds off the right edge.
## Static so `TouchInput` can keep its buttons out of the rail without holding a
## reference to the HUD. The rail's width is a property of the constants, not of
## any particular HUD instance.
static func nav_column_width() -> float:
	return (NAV_TOUCH_ICON_SIZE if touch_ui() else NAV_ICON_SIZE) + 24.0


## One square in the scope column.
func _add_icon_button(parent: Node, icon: String, tip: String,
		on_press: Callable) -> Button:
	var b := Button.new()
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	if not icon.is_empty():
		b.set_meta(&"nav_icon", icon)
		IconKit.on_button(b, icon, NAV_ICON_ART)
	# Set after `on_button`, which switches to left alignment so that labelled
	# buttons line their icons up. There is no label here, so centred is the only
	# thing that looks deliberate.
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(on_press)
	parent.add_child(b)
	# After it is in the tree, and that is not a detail: a Control outside the
	# tree has no theme to read, so asking it for its style box returns the engine
	# default and the override silently replaces the game's frame with nothing.
	_square_off(b)
	return b


## Makes a button's padding the same on all four sides.
##
## Without this the theme's label padding decides the width and no minimum size
## can win it back: a Control cannot be smaller than its own style demands, so
## asking for 58x58 got 100x58 and the column read as a stack of letterboxes.
func _square_off(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBox = button.get_theme_stylebox(state)
		if box == null:
			continue
		var square: StyleBox = box.duplicate()
		square.content_margin_left = NAV_ICON_PAD
		square.content_margin_right = NAV_ICON_PAD
		square.content_margin_top = NAV_ICON_PAD
		square.content_margin_bottom = NAV_ICON_PAD
		button.add_theme_stylebox_override(state, square)


## Grows the column for a thumb without moving it.
##
## The old layout sent the whole bar to the opposite corner on touch, because a
## wide row of text could not share the right edge with the build sheet. A column
## of icons can, so there is one position to reason about instead of two - and
## the top left it used to borrow is now free for the command column.
func _size_nav_bar() -> void:
	if _nav_bar == null:
		return
	var side: float = NAV_TOUCH_ICON_SIZE if touch_ui() else NAV_ICON_SIZE
	var art: int = NAV_TOUCH_ICON_ART if touch_ui() else NAV_ICON_ART
	for button: Button in _nav_buttons:
		if button == null or not is_instance_valid(button):
			continue
		button.custom_minimum_size = Vector2(side, side)
		# Re-cut from the 128px source at the size it will actually be drawn at,
		# rather than stretched from whatever it was built as. A resized icon on a
		# button is the one place softness is obvious, because it is sitting next
		# to a crisp frame.
		if button.has_meta(&"nav_icon"):
			IconKit.on_button(button, String(button.get_meta(&"nav_icon")), art)
			button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if button.text.length() > 0:
			button.add_theme_font_size_override("font_size", int(art * 0.36))


## The combat half: what a player reaches for while something is happening.
## A button's caption, with its keyboard shortcut only where there is one.
static func _action_label(key: String, what: String) -> String:
	return what if touch_ui() else "%s  %s" % [key, what]


func _build_action_bar(bar: Container) -> void:
	# **No key hints on a thumb.** "Q", "R" and "TAB" are instructions for a
	# keyboard nobody holding a phone has, and on a 720-wide screen the three
	# labels together are wider than the screen - the last button was pushed off
	# the right edge entirely. The tooltips still say everything.
	_horn_button = _add_button(bar, _action_label("Q", "War Horn"),
		func() -> void: horn_requested.emit())
	IconKit.on_button(_horn_button, "war_horn", 26)
	_raid_button = _add_button(bar, _action_label("R", "Raid"),
		func() -> void: raid_requested.emit())
	IconKit.on_button(_raid_button, "raid_charge", 26)
	_raid_button.disabled = true
	# Short labels because the bar has to share the bottom edge with the spell
	# slots, and both buttons carry an icon and a tooltip that say the rest.
	# **Build or Fight.** Preparation is both, and the player has to be able to
	# say which without hunting for a key: a wolf pack arriving mid-build is
	# exactly when nobody wants to remember a shortcut.
	_mode_button = _add_button(bar, _action_label("TAB", "Build"),
		func() -> void: GameDirector.toggle_build_mode())
	_mode_button.tooltip_text = "Build lays towers and traps. Fight lets you " 		+ "swing at whatever wandered in. Tab switches."
	IconKit.on_button(_mode_button, "upgrade", 22)
	EventBus.build_mode_changed.connect(_on_build_mode_changed)
	EventBus.phase_changed.connect(func(_n: int, _p: int) -> void: _update_mode_button())
	_update_mode_button()

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
	_tend_button.tooltip_text = ("Preparation: restore %d%% of the hero's health for %d Food.\n"
		+ "Under fire: a field ration restores %d%% for %d Food, once every %ds, "
		+ "and each one this wave costs %d more.") % [
			int(round(Balance.HERO_TEND_FRACTION * 100.0)), Balance.HERO_TEND_COST,
			int(round(Balance.RATION_FRACTION * 100.0)), Balance.RATION_COST,
			int(Balance.RATION_COOLDOWN), Balance.RATION_ESCALATION]
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


## The party feed, and the line a player types into.
##
## Bottom left, above the action bar: the corner the eye is not using during a
## wave, and the place every game with a chat log has put one for twenty years -
## which matters more than whether it is the prettiest spot, because a player
## should not have to learn where their friends are talking.
##
## **The box is hidden until Enter is pressed.** A permanent text field in the
## corner of an action game is a permanent invitation to lose a wave to it, and
## it would also swallow every key a player meant for the hero.
func _build_party_feed() -> void:
	var column := VBoxContainer.new()
	column.name = "PartyFeed"
	column.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	column.offset_left = 18.0
	column.offset_bottom = -_bottom_band_height() - 14.0
	column.offset_top = -520.0
	column.offset_right = Balance.PARTY_LOG_WIDTH + 18.0
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_party_log = PartyLog.new()
	_party_log.name = "PartyLog"
	column.add_child(_party_log)

	_chat_box = LineEdit.new()
	_chat_box.name = "ChatBox"
	_chat_box.placeholder_text = "Say something to your party"
	_chat_box.max_length = Balance.CHAT_MAX_LENGTH
	_chat_box.visible = false
	_chat_box.custom_minimum_size = Vector2(Balance.PARTY_LOG_WIDTH, 0.0)
	_chat_box.text_submitted.connect(_on_chat_submitted)
	column.add_child(_chat_box)


## Enter opens the box; Enter sends and closes it; Escape closes it unsent.
##
## Handled in `_input` rather than `_unhandled_input` for the same reason Tab is:
## a LineEdit with focus eats the key before an unhandled handler ever sees it,
## so the second Enter would never reach this.
func _input(event: InputEvent) -> void:
	if not _chat_available():
		return
	if _chat_box.visible and event.is_action_pressed(&"ui_cancel"):
		_close_chat()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(&"chat"):
		return
	if _chat_box.visible:
		_on_chat_submitted(_chat_box.text)
	else:
		_chat_box.visible = true
		_chat_box.grab_focus()
	get_viewport().set_input_as_handled()


func _chat_available() -> bool:
	return _chat_box != null and is_instance_valid(_chat_box) 		and Coop.is_networked()


func _on_chat_submitted(text: String) -> void:
	var said: String = text.strip_edges()
	_close_chat()
	if said.is_empty():
		return
	# Emitted, not sent. The relay forwards it and the host passes it on to the
	# rest of the party; this machine draws its own copy from the same signal.
	var slot: int = Coop.party().slot()
	EventBus.coop_chat.emit(maxi(slot, 1), said.substr(0, Balance.CHAT_MAX_LENGTH))


func _close_chat() -> void:
	if _chat_box == null or not is_instance_valid(_chat_box):
		return
	_chat_box.text = ""
	_chat_box.visible = false
	_chat_box.release_focus()


## The mode button says what pressing it *gives you*, not what mode you are in.
##
## Both readings are defensible and mixing them is the trap - a button labelled
## "Build" while you are already building is the version that gets clicked by
## mistake. It reads as a state here, with the colour carrying the difference,
## because that is what the surrounding bar does.
## Leaving Build mode has to take the build interface with it.
##
## Both panels sit over the battlefield and both swallow clicks, so a player who
## switched to Fight to deal with a wolf was still looking at a tower list and
## still could not swing at anything under it. The cursor moves too - a build
## reticle during a fight says the click will place something, and it will not.
func _on_build_mode_changed(building: bool) -> void:
	_update_mode_button()
	_apply_mode_cursor(building)
	if building and RunState.can_build_now():
		return
	_close_build_panel()
	if _road_panel != null:
		_road_panel.visible = false


## The pointer says which click you are about to make.
##
## `CURSOR_CROSS` for a fight and `CURSOR_CAN_DROP` for building: two shapes the
## OS already draws, rather than a custom texture that would have to be authored
## at four sizes and would still be wrong on a phone. Cleared entirely outside
## Preparation, where there is no choice to describe.
func _apply_mode_cursor(building: bool) -> void:
	if not RunState.can_build_now():
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	Input.set_default_cursor_shape(Input.CURSOR_CAN_DROP if building
		else Input.CURSOR_CROSS)


func _update_mode_button() -> void:
	if _mode_button == null:
		return
	var choosing: bool = RunState.can_build_now()
	_mode_button.visible = choosing
	if not choosing:
		_apply_mode_cursor(false)
		return
	_apply_mode_cursor(GameDirector.build_mode)
	var building: bool = GameDirector.build_mode
	_mode_button.text = ("BUILD" if building else "FIGHT") if touch_ui() 		else ("TAB  Build" if building else "TAB  Fight")
	_mode_button.add_theme_color_override("font_color",
		Color("9fd6b0") if building else Color("e8a33d"))
	IconKit.on_button(_mode_button, "upgrade" if building else "war_horn", 22)


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
	# **Available under fire now, at ration prices.** It used to be Preparation
	# only, which meant a hero who mistimed a wave had nothing to do about it
	# but die - and meant Food had almost nothing to buy, so hunting produced
	# a wallet that had stopped meaning anything by Act III.
	var preparing: bool = RunState.is_preparation()
	var price: int = Balance.HERO_TEND_COST if preparing else battlefield.ration_price()
	_tend_button.disabled = hero_health == null \
		or hero_health.current_hp >= hero_health.max_hp \
		or not RunState.can_afford_cost({RunState.FOOD: price}) \
		or (not preparing and not battlefield.ration_blocked().is_empty())
	# The label carries the price: the two modes cost different amounts, and a
	# button that quietly charges more than expected is worse than a greyed one.
	_tend_button.text = _action_label("V", "TEND  %d" % price) if preparing \
		else _action_label("V", "RATION  %d" % price)
	# **Healing announces itself when it is worth taking.**
	#
	# A hero on their last third has one button that answers the situation
	# and it looked exactly like the four beside it. Lit only when it is both
	# needed and takeable - a glowing button that refuses the press is worse
	# than a quiet one, so an unaffordable ration stays quiet.
	var left: float = 1.0
	if hero_health != null and hero_health.max_hp > 0.0:
		left = hero_health.current_hp / hero_health.max_hp
	_tend_urgent = not _tend_button.disabled and left <= Balance.HUD_HEAL_URGENT_FRACTION
	if not _tend_urgent:
		_tend_button.modulate = Color.WHITE


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


## The road sheet: what can be put *on* a lane, as opposed to beside one.
##
## A separate panel from the build sheet rather than a tab inside it, because the
## two answer different questions and are reached by clicking different things. A
## player who clicked a road wants to know what goes on a road.
##
## Its absence is why traps and barricades shipped unreachable: both systems
## were built, gated and replicated, and there was no way for a person to touch
## either of them. Gates do not check that a feature can be found.
func _build_road_panel() -> void:
	_road_panel = PanelContainer.new()
	_road_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_road_panel.offset_left = -BUILD_PANEL_WIDTH - _build_panel_inset()
	_road_panel.offset_right = -_build_panel_inset()
	_road_panel.offset_top = -_build_panel_lift()
	_road_panel.offset_bottom = -_build_panel_lift()
	_road_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_road_panel.visible = false
	add_child(_road_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_road_panel.add_child(column)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	var icon: TextureRect = IconKit.rect("blueprint", 28.0)
	if icon != null:
		heading.add_child(icon)
	_road_title = _label("The road", 22)
	heading.add_child(_road_title)
	column.add_child(heading)

	_road_list = VBoxContainer.new()
	_road_list.add_theme_constant_override("separation", 8)
	_road_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_road_list)

	var close: Button = _add_button(column, "Close",
		func() -> void: _road_panel.visible = false)
	IconKit.on_button(close, "close", 22)


## Opens it on one tile, listing what may be put there.
func _open_road_panel(tile: Vector2i) -> void:
	if _road_panel == null or battlefield == null:
		return
	_road_tile = tile
	# The tower sheet closes, for the same reason: one question at a time.
	_close_build_panel()
	_road_panel.visible = true
	_refresh_road_panel()


func _refresh_road_panel() -> void:
	for child: Node in _road_list.get_children():
		child.queue_free()
	var lane: int = BattleGrid.lane_at(BattleGrid.tile_to_world(_road_tile))
	_road_title.text = "%s road  ·  %d paces out" % [
		LANE_NAMES[clampi(lane, 0, 3)],
		int(round(BattleGrid.tile_to_world(_road_tile).length() / BattleGrid.TILE))]

	var standing: TrapData = RunState.trap_at(_road_tile)
	var wall: BarricadeData = RunState.barricade_at(_road_tile)
	if standing != null or wall != null:
		var name: String = standing.display_name if standing != null else wall.display_name
		var note: Label = _label("%s is already here." % name, 15)
		note.add_theme_color_override("font_color", Color("aebcb8"))
		_road_list.add_child(note)
	else:
		for trap: TrapData in ContentDB.trap_kinds():
			_add_road_row(trap.display_name, trap.description, trap.cost,
				func() -> void: _report(battlefield.try_place_trap(_road_tile, trap)))
		for value: Variant in ContentDB.barricades.values():
			var barricade := value as BarricadeData
			if barricade == null:
				continue
			_add_road_row(barricade.display_name, barricade.description,
				barricade.cost,
				func() -> void: _report(battlefield.try_raise_barricade(
					_road_tile, barricade)))
	UiMetrics.apply_touch_tree(_road_panel, touch_ui())


## One offer on the road sheet.
func _add_road_row(name: String, description: String, cost: Dictionary,
		on_press: Callable) -> void:
	var row: Button = _add_button(_road_list, "%s   %s" % [
		name, RunState.format_cost(cost)], func() -> void:
		on_press.call()
		_refresh_road_panel())
	row.tooltip_text = description
	row.disabled = not RunState.can_afford_cost(cost)


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
	# Anchored to the bottom and grown upward, into the space the command panel
	# used to occupy.
	#
	# Centred on the right edge, it ran straight through the scope column above
	# it - which is the overlap that was reported. Hanging it from the bottom
	# instead means its height changes where its *top* is rather than where its
	# bottom is, so the taller build view and the shorter upgrade view both clear
	# the column by the same margin without either being given a fixed height.
	_build_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_build_panel.offset_left = -BUILD_PANEL_WIDTH - _build_panel_inset()
	_build_panel.offset_right = -_build_panel_inset()
	_build_panel.offset_top = -_build_panel_lift()
	_build_panel.offset_bottom = -_build_panel_lift()
	_build_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_build_panel.visible = false
	add_child(_build_panel)

	# **The tower list scrolls.**
	#
	# The sheet hangs from the bottom edge and grows upward, which keeps it clear
	# of the scope column however tall it gets - and "however tall it gets" has
	# no ceiling. Eight towers on a phone came to 831px hanging off a lift of
	# nearly 500, so the top of the sheet sat 250px above the top of the screen
	# and the first two elements could not be reached at all. A list that does
	# not fit has to scroll; the alternative is a list with items nobody can
	# press.
	var scroll := ScrollContainer.new()
	UiMetrics.prepare_scroll(scroll, touch_ui())
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_scroll = scroll
	_build_panel.add_child(scroll)
	_size_build_scrollbar()

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_column = column
	scroll.add_child(column)

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
	# Fixed height, not a minimum. A minimum still grows when the text needs more
	# room, and the new towers carry longer descriptions - so hovering one rewrapped
	# the footer to a second line and pushed the whole panel six pixels taller. A
	# panel that changes size under the cursor is the jitter the hover gate exists
	# to catch.
	_build_detail.custom_minimum_size = Vector2(0.0, BUILD_DETAIL_HEIGHT)
	_build_detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_build_detail.clip_text = true
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

	_build_side_tooltip()


## The figures box that sits beside the build panel.
##
## A sibling of the panel rather than a child of it, so the panel's own clipping
## and layout have no say in where it lands - it is pinned to the screen's right
## edge and steps left past the panel's full width, which puts it outside the
## panel by construction rather than by arithmetic that could drift.
func _build_side_tooltip() -> void:
	_build_tooltip = PanelContainer.new()
	_build_tooltip.anchor_left = 1.0
	_build_tooltip.anchor_right = 1.0
	_build_tooltip.anchor_top = 0.0
	_build_tooltip.anchor_bottom = 0.0
	# Grows downward from wherever it is placed, so the box sizes to its own text
	# and the row it belongs to stays its top edge.
	_build_tooltip.grow_vertical = Control.GROW_DIRECTION_END
	_build_tooltip.offset_right = -(BUILD_PANEL_MARGIN + BUILD_PANEL_WIDTH + BUILD_TOOLTIP_GAP)
	_build_tooltip.offset_left = _build_tooltip.offset_right - BUILD_TOOLTIP_WIDTH
	# It must never eat a click meant for the field behind it, and it is never
	# interactive itself.
	_build_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_tooltip.visible = false
	add_child(_build_tooltip)

	_build_tooltip_label = _label("", 14)
	_build_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_tooltip.add_child(_build_tooltip_label)


## Shows the figures for `near`, aligned with the row that asked.
func _show_build_tooltip(text: String, near: Control) -> void:
	if _build_tooltip == null:
		return
	if text.is_empty() or near == null or not is_instance_valid(near):
		_hide_build_tooltip()
		return
	_build_tooltip_label.text = text
	_build_tooltip.visible = true
	# Straight from the row's global position, with nothing subtracted: this is a
	# CanvasLayer at the identity transform, so a child's offsets and a Control's
	# global position are already the same viewport space.
	var row_top: float = near.global_position.y
	_build_tooltip.offset_top = row_top
	_build_tooltip.offset_bottom = row_top
	# The height is not known until the box has been laid out with this text, and
	# a row near the bottom of a tall panel would otherwise hang off the screen.
	_clamp_build_tooltip.call_deferred(row_top)


## Pulls the box back inside the viewport once its height is known.
func _clamp_build_tooltip(row_top: float) -> void:
	if _build_tooltip == null or not _build_tooltip.visible:
		return
	# The viewport's height, not the layer's - a CanvasLayer has no size of its
	# own, and the bottom of the screen is what the box must not fall off.
	var screen_height: float = get_viewport().get_visible_rect().size.y
	var lowest: float = maxf(screen_height - _build_tooltip.size.y - BUILD_TOOLTIP_GAP,
		BUILD_TOOLTIP_GAP)
	var top: float = clampf(row_top, BUILD_TOOLTIP_GAP, lowest)
	_build_tooltip.offset_top = top
	_build_tooltip.offset_bottom = top


func _hide_build_tooltip() -> void:
	if _build_tooltip != null:
		_build_tooltip.visible = false


func _build_raid_panel() -> void:
	_raid_panel = PanelContainer.new()
	_raid_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_fit_centred(_raid_panel, 280.0)
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
	_fit_centred(_preparation_panel, 190.0)
	# Its ornate skin is taller than the nominal controls. Keep the whole frame
	# above the persistent scope bar instead of letting the lower rivets clip.
	# Clear of the scope bar, with a gap rather than a shave.
	#
	# The bar occupies the bottom 84px and this used to end at 118, leaving 34px
	# that the panel's ornate skin ate into - so it read as overlapping the horn,
	# raid and repair buttons even though the rectangles never intersected. That
	# is also why the layout gate stayed silent: they were close, not overlapping.
	# Shifted up by exactly the band the ability bar now occupies, derived from the
	# same constants rather than re-typed, so moving the bar again moves these
	# with it instead of silently re-opening the collision.
	# **Low, on a phone.** On a desktop this sits comfortably above the bottom
	# edge and nothing is behind it that matters. With a thumb the bottom band is
	# far taller, and lifting the panel by that whole band put it across the
	# middle of the screen - directly over the hero, which is the one thing a
	# player is trying to look at while deciding whether to ride on.
	#
	# Tucked just above the band instead, so the field above it is clear.
	add_child(_preparation_panel)
	_place_preparation_panel()

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
	_ride_on_button.set_meta(UiMetrics.SELF_SIZED, true)
	_ride_on_button.set_meta(UiMetrics.TOUCH_TARGET_HEIGHT,
		Balance.UI_TOUCH_PREPARATION_BUTTON_HEIGHT)
	_ride_on_button.custom_minimum_size.y = 34.0
	_ride_on_button.add_theme_font_size_override("font_size", 12)
	_ride_on_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ride_on_button.tooltip_text = "Begin the next wave. Leaving during the first 10 seconds earns bonus Gold; waiting is always safe."



## Where the preparation card sits, which depends on whether a thumb is
## driving and on how tall the bottom band currently is.
##
## A function rather than four lines in the builder, because both of those
## answers change *after* the HUD is built - the controls can be switched on
## mid-run, and the band's height moves with them. Computed once at build
## time, the card kept a desktop placement on a phone.
func _place_preparation_panel() -> void:
	if _preparation_panel == null:
		return
	if touch_ui():
		# **Out of the field entirely, into the top left.**
		#
		# Above the bottom band was better than across the middle and still not
		# good: a card sitting anywhere in the play area is a card in front of
		# whatever the player is trying to watch, and this one is on screen for
		# the whole of every Preparation. The top left corner already holds the
		# run's readouts, so it is a corner the eye visits and the thumbs do not.
		#
		# Below them rather than among them - the two header rows end at 82 and
		# the command column starts at 104, so this hangs beneath both.
		_preparation_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_preparation_panel.grow_horizontal = Control.GROW_DIRECTION_END
		_preparation_panel.grow_vertical = Control.GROW_DIRECTION_END
		_preparation_panel.offset_left = PREPARATION_TOUCH_MARGIN
		_preparation_panel.offset_right = PREPARATION_TOUCH_MARGIN 			+ PREPARATION_TOUCH_WIDTH
		_preparation_panel.offset_top = PREPARATION_TOUCH_TOP
		_preparation_panel.offset_bottom = PREPARATION_TOUCH_TOP 			+ PREPARATION_TOUCH_HEIGHT
		if _preparation_label != null:
			_preparation_label.visible = false
		if _ride_on_button != null:
			_ride_on_button.custom_minimum_size.y = Balance.UI_TOUCH_PREPARATION_BUTTON_HEIGHT
	else:
		if _preparation_label != null:
			_preparation_label.visible = true
		if _ride_on_button != null:
			_ride_on_button.custom_minimum_size.y = 34.0
		_preparation_panel.offset_top = -272.0 - _bottom_band_height()
		_preparation_panel.offset_bottom = -156.0 - _bottom_band_height()



## Grows the run readouts along the top edge for a thumb.
##
## `UiMetrics` grows their type and cannot grow their marks - those are textures
## cut to a size at build time - so on a phone a 28px number sat beside a 24px
## icon and the whole strip read as small. Both move together here.
## What the bow is carrying, or nothing at all.
##
## Reads the ammunition's own icon, so a Rime Arrow and an Ember Arrow are told
## apart at a glance rather than by reading a word - which is the same reason the
## currencies carry marks rather than labels.
func _refresh_quiver() -> void:
	if _quiver_row == null or _quiver_label == null:
		return
	var weapon := ContentDB.ranged_weapons.get(RunState.ranged_id, null) as RangedWeaponData
	if weapon == null:
		_quiver_row.visible = false
		return
	_quiver_row.visible = true
	var kind := ContentDB.ammo_kinds.get(RunState.ammo_id, null) as AmmoData
	if kind == null:
		_quiver_label.text = "%s  ·  empty" % weapon.display_name
		return
	IconKit.resize_labelled(_quiver_row, kind.id,
		TOP_BAR_ICON_TOUCH * _top_bar_room() if touch_ui() else TOP_BAR_ICON)
	_quiver_label.text = "%d  %s" % [RunState.ammo_count(kind.id), kind.display_name]


func _size_top_bar() -> void:
	if _top_bar != null:
		_top_bar.add_theme_constant_override("separation", 24 if touch_ui() else 32)
	var mark: float = TOP_BAR_ICON_TOUCH * _top_bar_room() if touch_ui() 		else TOP_BAR_ICON
	for id: Variant in _currency_rows.keys():
		IconKit.resize_labelled(_currency_rows[id] as Node, String(id), mark)
	# Set outright rather than left to the generic floor. `UiMetrics` lifts every
	# label to a minimum, which keeps small print legible and leaves a readout
	# the player checks constantly at the same size as a tooltip. This strip is
	# the run's state - what act, what level, what can be spent - and it is read
	# at a glance from arm's length.
	if not touch_ui():
		return
	var type_size: int = maxi(int(round(float(TOP_BAR_FONT_TOUCH)
		* _top_bar_room())), TOP_BAR_FONT_MIN)
	for label: Label in [_act, _level, _weather]:
		if label != null:
			label.add_theme_font_size_override("font_size", type_size)
	for id: Variant in _currency_labels.keys():
		var value := _currency_labels[id] as Label
		if value != null:
			value.add_theme_font_size_override("font_size", type_size)
	# The health tracks are authored at a fixed width and are the widest single
	# things in the row, so they have to give ground too - a strip that shrinks
	# its type and keeps a 240px bar has not shrunk.
	var room: float = _top_bar_room()
	if _town_bar != null:
		_town_bar.custom_minimum_size.x = maxf(TOWN_BAR_WIDTH * room, 120.0)
	if _hero_bar != null:
		_hero_bar.custom_minimum_size.x = maxf(HERO_BAR_WIDTH * room, 96.0)
	# The line beneath moves with it. Its 52px was measured against 35px type;
	# grow the type and the two rows share the same pixels.
	if _journey_bar != null:
		_journey_bar.position.y = 16.0 + float(type_size) + 22.0



## How much of the full touch size the top strip can afford, 0.55 to 1.
##
## The strip carries an act name, a level, the weather and four currencies in one
## row across the top. On a phone held sideways there is room to grow all of it;
## held upright there is not - at full size the boss track was pushed off the
## right edge with a quarter of it showing. Bigger where bigger fits, rather than
## one size that is wrong at one of the two orientations.
func _top_bar_room() -> float:
	var wide: float = get_viewport().get_visible_rect().size.x
	return clampf(wide / TOP_BAR_FULL_WIDTH, 0.55, 1.0)


func _build_command_panel() -> void:
	_command_panel = PanelContainer.new()
	# Top left, as a column.
	#
	# It used to sit above the bottom right, directly over the space the build
	# sheet needed - the two could not both be open without one covering the
	# other. Moving it here is what frees that space, and it suits the orders
	# besides: they are *aimed*, so the hand is already going to the field rather
	# than to the bar, and the corner that costs least to leave is the one no
	# thumb rests in.
	_command_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_command_panel.offset_left = 24.0
	_command_panel.offset_right = 24.0 + COMMAND_BAR_WIDTH
	_command_panel.offset_top = COMMAND_BAR_TOP
	_command_panel.offset_bottom = COMMAND_BAR_TOP
	_command_panel.grow_vertical = Control.GROW_DIRECTION_END
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
	_command_bar = _make_bar(Color("e8a33d"), 96.0)
	_command_bar.custom_minimum_size.y = 9.0
	_command_bar.value = 0.0
	meter_row.add_child(_command_bar)
	_command_value = _label("0 / 100", 12)
	_command_value.custom_minimum_size = Vector2(56.0, 0.0)
	meter_row.add_child(_command_value)
	column.add_child(meter_row)
	_command_target = _label("TARGET  ·  select a road or tower", 11)
	_command_target.add_theme_color_override("font_color", Color("b8ae98"))
	# It wraps now that the panel is a column rather than a wide strip. Without
	# this the longest target name pushes the panel wider than the bar it lives
	# in and the whole column jumps about as the cursor moves.
	_command_target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_command_target.custom_minimum_size = Vector2(COMMAND_BAR_WIDTH - 24.0, 30.0)
	column.add_child(_command_target)

	var orders := VBoxContainer.new()
	orders.add_theme_constant_override("separation", 6)
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
	var reward: int = Balance.preparation_early_gold(seconds_left)
	_ride_on_button.text = "RIDE ON  ·  +%d GOLD" % reward if reward > 0 else "RIDE ON"
	_preparation_label.text = _preparation_text(seconds_left, reward)


## What the breather says it is doing. Three states, because the countdown has
## three: the bonus is falling, the bonus is about to vanish, and the wave comes
## regardless. One "time left" number would hide both cliffs the reward schedule
## is built around, and the cliffs are the whole decision.
func _preparation_text(seconds_left: float, reward: int) -> String:
	if seconds_left <= 0.0:
		return "Prepare as long as you need. The next wave waits for you."
	if reward > Balance.PREPARATION_EARLY_GOLD_FLOOR:
		return "Ride on now for +%d Gold — the bonus drops every second." % reward
	if reward > 0:
		var left: float = ceil(Balance.preparation_bonus_seconds_left(seconds_left))
		return "+%d Gold if you ride on within %.0f sec, then the bonus is gone." % [reward, left]
	return "No bonus left. The wave rolls in %.0f sec." % ceil(seconds_left)


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
	_boss_box = box
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -190.0
	box.offset_right = 190.0
	box.offset_top = BOSS_TRACK_TOP
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


## The bottom row: actions, then abilities, centred as one thing.
##
## One container rather than two anchored separately, because two centred rows
## that must not collide is a sum nobody can hold in their head - and the last
## attempt at it ended with the ability bar a quarter off the right of the
## screen. A single HBox cannot overlap itself.
func _build_bottom_row() -> void:
	var centre := HBoxContainer.new()
	_bottom_row = centre
	centre.name = "BottomRow"
	centre.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.offset_top = -_bottom_band_height()
	centre.offset_bottom = -_bottom_row_inset()
	centre.offset_right = -nav_column_width() if touch_ui() else 0.0
	centre.add_theme_constant_override("separation", 26)
	add_child(centre)

	# **Two rows on a phone.** The action bar carries five buttons, each grown to
	# a thumb-sized target, and five of those in a row is wider than the screen -
	# the last one hung off the right edge with 18% of it visible. A grid wraps
	# them instead of shrinking targets that are the size they are for a reason.
	var actions: Container
	if touch_ui():
		var grid := GridContainer.new()
		grid.columns = _action_columns()
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		actions = grid
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		actions = row
	actions.name = "Actions"
	# **On the same baseline as the ability slots.** Both halves share one row,
	# and the row is as tall as its tallest content - so the action buttons sat
	# at the top of it and the slots, which hug the bottom to keep their own
	# height, sat well below. Two rails of controls at two different heights read
	# as a mistake because it is one. Both hug the bottom now.
	actions.size_flags_vertical = Control.SIZE_SHRINK_END
	centre.add_child(actions)
	_build_action_bar(actions)

	_build_spell_bar(centre)


## Whether the interface is being driven by a thumb.
##
## Asked rather than assumed from the platform: a tablet with a keyboard case and
## a touch laptop both report a touchscreen, and the setting can say otherwise.
static func touch_ui() -> bool:
	return TouchInput.is_showing()


## A size, grown if a thumb has to hit it.
static func hit(size: Vector2) -> Vector2:
	return Vector2(size.x, size.y * Balance.UI_TOUCH_SCALE) if touch_ui() else size


static func _spell_slot_size() -> Vector2:
	return Vector2(Balance.UI_TOUCH_SPELL_SLOT_WIDTH if touch_ui() else SPELL_SLOT_SIZE.x,
		Balance.UI_TOUCH_SPELL_SLOT_HEIGHT if touch_ui() else SPELL_SLOT_SIZE.y)


static func _bottom_band_height() -> float:
	return _spell_slot_size().y + _bottom_row_inset() + _action_band_height()


## How much vertical room the action buttons need.
##
## Zero on a desktop, where they sit in the same row as everything else and the
## band was measured from the spell slots alone. On a phone they wrap to two
## rows of thumb-sized targets, and a band that does not know that puts the
## lower row through the bottom of the screen - which is where it went.
static func _action_band_height() -> float:
	if not touch_ui():
		return 0.0
	var rows: int = int(ceil(float(ACTION_BUTTON_COUNT) / float(_action_columns())))
	return float(rows) * hit(Vector2(0.0, ACTION_BUTTON_HEIGHT)).y 		+ float(rows - 1) * ACTION_ROW_GAP


static func _bottom_row_inset() -> float:
	# Desktop keeps the authored 24px air. The taller mobile XP strip becomes the
	# lower bound so a 120px touch target never reaches into progression text.
	return maxf(SPELL_BAR_MARGIN, _xp_bar_height() + 4.0)


## The XP strip lives on the literal screen edge so it remains readable during
## the two scopes where XP is earned without joining the already busy combat
## control row. It is deliberately thin: progression context, not a fifth
## health bar competing for attention.
func _build_xp_bar() -> void:
	_xp_band = Control.new()
	_xp_band.name = "HeroXP"
	_xp_band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_xp_band.offset_top = -_xp_bar_height()
	_xp_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_xp_band)

	_xp_bar = _make_bar(Color("9b8fc4"), 0.0)
	_xp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_bar.custom_minimum_size = Vector2.ZERO
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_band.add_child(_xp_bar)

	_xp_label = _label("LEVEL 1  ·  0 / 17 XP", 12)
	_xp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xp_label.add_theme_color_override("font_color", Color("f3e7cb"))
	_xp_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_xp_label.add_theme_constant_override("shadow_offset_x", 1)
	_xp_label.add_theme_constant_override("shadow_offset_y", 1)
	_xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_band.add_child(_xp_label)


static func _xp_bar_height() -> float:
	return Balance.UI_XP_BAR_TOUCH_HEIGHT if touch_ui() else Balance.UI_XP_BAR_HEIGHT


func _build_spell_bar(parent: Node = null) -> void:
	_spell_bar = HBoxContainer.new()
	_spell_bar.name = "Abilities"
	# No anchors and no offsets any more: it is a child of the bottom row, and
	# the row centres itself and both its halves together.
	#
	# It used to anchor itself to the bottom centre and compute its own width
	# from its slots, which was correct in isolation and could not stay correct
	# beside a second bar doing the same sum - the two collided, and the fix at
	# the time was to stack them, which is the thing this replaces.
	_spell_bar.add_theme_constant_override("separation", 10)
	if parent != null:
		parent.add_child(_spell_bar)
	else:
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
		var slot_size: Vector2 = _spell_slot_size()
		var discipline: DisciplineNodeData = RunState.discipline_node_in_slot(slot)
		# The slot frame sits behind the button rather than being its background,
		# so an empty slot still reads as a slot the player could fill. A gap
		# reads as nothing at all.
		var frame := Control.new()
		frame.custom_minimum_size = slot_size
		# **Its own height, not the row's.** The slots share a row with the action
		# grid, and a container hands every child the height of its tallest one -
		# so a 132px slot was drawn 356 tall next to a two-row grid, stretching
		# the art and eating the field behind it.
		frame.size_flags_vertical = Control.SIZE_SHRINK_END
		# Everything below is placed against the art's interior, not the slot's
		# outer rectangle. "HEMORRHAGE EDGE" in a 92px box on a 118px slot spilled
		# straight over the ironwork on both sides.
		var inset := Vector2(slot_size.x * UiMetrics.SLOT_INSET_X,
			slot_size.y * UiMetrics.SLOT_INSET_Y)
		var interior := Vector2(slot_size.x - inset.x * 2.0,
			slot_size.y - inset.y * 2.0)
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
		# **Centred on the slot, and derived rather than typed.**
		#
		# It used to sit at a fixed (46, 9), which centred it on the safe area of
		# the art as drawn at desktop size - 17px left of the slot's own middle,
		# and nowhere near right once a touch slot is 132 tall instead of 72. The
		# mark is the thing a player reads at a glance, so it belongs in the
		# middle of the thing they are looking at.
		#
		# Lifted slightly above centre because the ability's name sits along the
		# bottom edge; splitting the difference puts the pair in the middle
		# together rather than the icon alone.
		var icon_side: float = SPELL_ICON_TOUCH_SIZE if touch_ui() 			else SPELL_ICON_SIZE
		icon.size = Vector2(icon_side, icon_side)
		icon.position = Vector2((slot_size.x - icon_side) * 0.5,
			(slot_size.y - icon_side) * 0.5 - inset.y * 0.5)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(icon)

		var name_label := Label.new()
		name_label.position = Vector2(inset.x, slot_size.y - inset.y - 16.0)
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
## The card that announces an act, a region or a boss.
##
## Every one of these moments existed and none of them was *shown*: the act
## changed, the terrain changed underfoot and the music changed, and the only
## acknowledgement was a line in the message strip that also carries "not enough
## Gold". A region the player has just arrived in deserves to be named.
##
## One card for all three rather than three screens, because they are the same
## beat — something has changed and the next thirty seconds are different — and
## three near-identical overlays is how a game ends up with three slightly
## different fonts.
func _build_region_card() -> void:
	_region_card = VBoxContainer.new()
	_region_card.name = "RegionCard"
	_region_card.visible = false
	_region_card.modulate.a = 0.0
	_region_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_region_card.set_anchors_preset(Control.PRESET_CENTER)
	_region_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_region_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	# Above centre on a phone. Dead centre is where the preparation card now
	# sits - it had to come down off the hero - and an announcement that lands on
	# top of the button the player is reaching for is worse than one sitting a
	# little high.
	if touch_ui():
		_region_card.offset_top -= REGION_CARD_TOUCH_RISE
		_region_card.offset_bottom -= REGION_CARD_TOUCH_RISE
		_region_card.offset_left -= REGION_CARD_TOUCH_LEFT
		_region_card.offset_right -= REGION_CARD_TOUCH_LEFT
	_region_card.add_theme_constant_override("separation", 4)
	add_child(_region_card)

	_region_kicker = _label("", 20)
	_region_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_kicker.add_theme_color_override("font_color", Color("d9b271"))
	_region_card.add_child(_region_kicker)

	_region_title = _label("", 52)
	_region_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_card.add_child(_region_title)

	EventBus.act_started.connect(_on_act_started)
	EventBus.boss_spawned.connect(_on_boss_announced)
	EventBus.run_started.connect(_on_run_opened)
	EventBus.hero_levelled.connect(_on_hero_levelled)
	EventBus.weather_changed.connect(_on_weather_changed)


## Weather is a condition the player has to build for, so it is announced when
## it turns rather than only shown as a label they may never look at.
func _on_weather_changed(weather_id: String) -> void:
	var weather: WeatherData = ContentDB.weather(weather_id)
	if weather == null:
		return
	if _weather != null:
		_weather.text = weather.display_name
		_weather.tooltip_text = weather.effect_line
	if weather.id != "clear":
		announce(weather.effect_line, weather.display_name.to_upper())


## A level is worth announcing: it is the only reward in the run that arrives
## mid-fight and cannot be seen on the board.
func _on_hero_levelled(level: int, attribute_points: int, skill_points: int) -> void:
	if _level != null:
		_level.text = "Lv %d" % level
	var parts: PackedStringArray = ["Level %d" % level]
	if attribute_points > 0:
		parts.append("%d attribute point%s"
			% [attribute_points, "" if attribute_points == 1 else "s"])
	if skill_points > 0:
		parts.append("%d skill point%s"
			% [skill_points, "" if skill_points == 1 else "s"])
	_show_message("  ·  ".join(parts))
	Sfx.play("sfx_ui_confirm", 2.0)
	_refresh_xp_bar()


func _on_hero_xp_changed(_current: float, _needed: float, _level_number: int) -> void:
	_refresh_xp_bar()


func _refresh_xp_bar() -> void:
	if _xp_bar == null or _xp_label == null:
		return
	if RunState.hero_level >= Balance.HERO_MAX_LEVEL:
		_xp_bar.max_value = 1.0
		_xp_bar.value = 1.0
		_xp_label.text = "LEVEL %d  ·  MAX" % RunState.hero_level
		return
	var needed: float = RunState.hero_xp_for_level(RunState.hero_level)
	_xp_bar.max_value = maxf(needed, 1.0)
	_xp_bar.value = RunState.hero_xp
	_xp_label.text = "LEVEL %d  ·  %d / %d XP" % [RunState.hero_level,
		int(floor(RunState.hero_xp)), int(ceil(needed))]


## Touch changes the metrics of the controls themselves, not the CanvasLayer.
## The HUD only owns the structural follow-through: short labels, a taller spell
## frame and moving the panels that intentionally sit above that frame.
func _on_touch_layout_changed(showing: bool) -> void:
	if _horn_button != null:
		_horn_button.text = "HORN" if showing else "Q  War Horn"
	if _raid_button != null:
		_raid_button.text = "RAID" if showing else "R  Raid"
	if _repair_button != null:
		_repair_button.text = "FIX" if showing else "Repair"
	_update_mode_button()
	if _tend_button != null:
		_tend_button.text = "TEND" if showing else "Tend"

	if _bottom_row != null:
		_bottom_row.offset_top = -_bottom_band_height()
		_bottom_row.offset_bottom = -_bottom_row_inset()
		_bottom_row.offset_right = -nav_column_width() if showing else 0.0
	# The column stays where it is and only grows. Moving it to the opposite
	# corner on touch was a workaround for a *wide* bar that could not share the
	# right edge with the build sheet; a narrow one can, and one position is one
	# thing to reason about instead of two.
	_size_nav_bar()
	if _boss_box != null:
		_boss_box.offset_top = BOSS_TRACK_TOUCH_TOP if showing else BOSS_TRACK_TOP
	if _message != null:
		_message.offset_top = MESSAGE_TOUCH_TOP if showing else MESSAGE_TOP
	if _state_label != null:
		_state_label.offset_top = STATE_LABEL_TOUCH_TOP if showing else STATE_LABEL_TOP
	if _xp_band != null:
		_xp_band.offset_top = -_xp_bar_height()
	if _build_panel != null:
		# Hung from the bottom in both layouts, so the touch sheet growing taller
		# moves its top edge rather than pushing its footer into the combat row.
		var lift: float = -_build_panel_lift()
		_build_panel.offset_top = lift
		_build_panel.offset_bottom = lift
		_build_panel.offset_left = -BUILD_PANEL_WIDTH - _build_panel_inset()
		_build_panel.offset_right = -_build_panel_inset()
	if _wave_preview != null:
		_wave_preview.offset_top = 214.0 if showing else 158.0
		_fit_centred(_wave_preview, 360.0 if showing else 420.0)
	if _preparation_panel != null:
		_preparation_panel.offset_top = -272.0 - _bottom_band_height()
		_preparation_panel.offset_bottom = -156.0 - _bottom_band_height()
	if _command_panel != null:
		_command_panel.offset_top = -276.0 - _bottom_band_height()
		_command_panel.offset_bottom = -164.0 - _bottom_band_height()

	_rebuild_spell_bar()
	UiMetrics.apply_touch_tree(self, showing)
	_place_preparation_panel()
	_size_build_controls(_build_panel)
	_size_build_scrollbar()
	_fit_build_panel()
	_size_top_bar()


## The opening beat, before Act I names itself.
##
## Deferred by a frame rather than shown immediately: `act_started` for Act I
## fires during scene startup, and both cards arriving on the same frame means
## the second tween simply overwrites the first and the title is never seen.
func _on_run_opened() -> void:
	await get_tree().process_frame
	announce("The road begins", "BEAST ROAD")


func _on_act_started(act: int, terrain_id: String) -> void:
	var terrain: TerrainData = ContentDB.terrain(terrain_id)
	announce("Act %d" % act, terrain.display_name if terrain != null else terrain_id)


func _on_boss_announced(boss_id: String, act: int) -> void:
	var data: EnemyData = ContentDB.enemy(boss_id)
	# The tier publishes what it expects of the hero here, and only when they are
	# short of it. A boss is an expectancy rather than a lock - a wall that says
	# "come back later" throws away the forty minutes already spent - so the
	# player is told plainly and then allowed to try it anyway.
	var behind: float = RunState.under_levelled(act)
	var kicker: String = "Something enormous is on the road"
	if behind > 0.0:
		kicker = "Level %d expected — you are %d" % [
			RunState.expected_boss_level(act), RunState.hero_level]
	announce(kicker, data.display_name if data != null else boss_id)


## Shows the card, then takes it away. Never blocks: the road does not stop for
## a title, and a card that paused the game during a boss walk-in would be
## taking the fight away at the exact moment it started.
func announce(kicker: String, title: String) -> void:
	if _region_card == null:
		return
	_region_kicker.text = kicker.to_upper()
	_region_title.text = title
	_region_card.visible = true
	_region_card.modulate.a = 0.0

	# Killed rather than layered: two cards overlapping fade against each other
	# and both come out muddy.
	if _region_tween != null and _region_tween.is_valid():
		_region_tween.kill()
	var show: Tween = create_tween()
	_region_tween = show
	show.tween_property(_region_card, "modulate:a", 1.0, REGION_CARD_FADE)
	show.tween_interval(REGION_CARD_HOLD)
	show.tween_property(_region_card, "modulate:a", 0.0, REGION_CARD_FADE)
	show.tween_callback(func() -> void: _region_card.visible = false)


## The first-run coach. Built last so it sits above the panels it points at, and
## owned by the HUD because every moment it teaches is a HUD moment.
func _build_tutorial_coach() -> void:
	_tutorial = TutorialCoach.new()
	add_child(_tutorial)


func _build_boss_bar() -> void:
	_boss_panel = PanelContainer.new()
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_fit_centred(_boss_panel, 420.0)
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
	_boss_id = boss_id
	var data: EnemyData = ContentDB.enemy(boss_id)
	_boss_name.text = "%s   ·   Act %d" % [data.display_name if data != null else boss_id, act]
	_boss_panel.visible = true
	_message.text = "%s has come." % (data.display_name if data != null else "Something")
	_message_left = 3.2


func _on_boss_phase_changed(boss_id: String, phase: int, phase_name: String) -> void:
	_boss_id = boss_id
	var data: EnemyData = ContentDB.enemy(boss_id)
	_message.text = "%s  —  %s\nReinforcements on the other roads." % [
		data.display_name if data != null else "The boss", phase_name.to_upper()]
	_message_left = 4.0
	if _boss_name != null:
		_boss_name.text = "%s  ·  %s" % [
			data.display_name if data != null else boss_id, phase_name]


func _update_boss_bar() -> void:
	if not _boss_panel.visible:
		return
	var boss: Enemy = _active_boss_for_ui()
	if boss == null:
		_boss_panel.visible = false
		return
	var health: Health = Health.of(boss)
	if health != null:
		_boss_bar.value = health.ratio()


func _active_boss_for_ui() -> Enemy:
	var directed: Enemy = boss_director.active_boss() if boss_director != null else null
	if directed != null:
		return directed
	if _boss_id.is_empty():
		return null
	# Guests do not simulate BossDirector, but CoopWorld does give them the
	# authoritative boss puppet and health snapshots. The HUD reads that body.
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var candidate := node as Enemy
		if candidate != null and candidate.data != null \
				and candidate.data.id == _boss_id and not candidate.is_dying():
			return candidate
	return null


func _on_boss_defeated(_id: String, _act: int) -> void:
	_boss_id = ""
	_boss_panel.visible = false


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


func _refresh_recovery_status() -> void:
	if _recovery_status == null:
		return
	var parts: PackedStringArray = []
	if RunState.last_scar_active:
		var challenge: Resource = ContentDB.run_challenge("last_scar")
		if challenge != null:
			var town_percent: int = int(round(
				RunState.last_scar_min_town_ratio * 100.0))
			var hunt_key: String = "pursuer_defeated_status" \
				if RunState.last_scar_pursuer_defeated else "pursuer_hunt_status"
			parts.append(String(challenge.get("active_status")) % [
				String(challenge.get(hunt_key)), town_percent])
	if _hero != null and is_instance_valid(_hero) and _hero.mender_active():
		var recovery: Resource = ContentDB.recovery_drop(Balance.MENDER_SPARK_ID)
		if recovery != null:
			parts.append(String(recovery.get("active_status")) \
				% _hero.mender_seconds_left())
	_recovery_status.text = "     ".join(parts)
	_recovery_status.add_theme_color_override("font_color",
		Color("8ff0ac") if parts.size() == 1 and _hero != null \
			and _hero.mender_active() else Color("ef8065"))


func _on_last_scar_resolved(success: bool, reason: String,
		_maximum: int) -> void:
	var challenge: Resource = ContentDB.run_challenge("last_scar")
	if challenge == null:
		return
	if success:
		_show_message(String(challenge.get("success_line")))
	else:
		var failures: Dictionary = challenge.get("failure_lines") as Dictionary
		_show_message(String(failures.get(reason, challenge.get("description"))))


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
	var target: Vector2i = _selected
	if order_id != CommandSystemScript.LAST_STAND and not RunState.can_build_now():
		var aimed: Vector2i = _aimed_tower()
		if aimed.x != -999:
			target = aimed
	command_requested.emit(order_id, target)


## The slot the cursor is aiming at, or (-1, -1). `built_only` restricts it to
## spots with a tower on them, so Overdrive skips over an empty spot that happens
## to be marginally nearer the cursor than the tower the player meant.
func _aimed_tower() -> Vector2i:
	if battlefield == null:
		return Vector2i(-999, -999)
	var cursor: Vector2 = battlefield.get_global_mouse_position()
	var best: Vector2i = Vector2i(-999, -999)
	var best_distance: float = INF
	for built: Tower in battlefield.all_towers():
		var distance: float = built.global_position.distance_to(cursor)
		if distance < best_distance:
			best_distance = distance
			best = built.anchor
	# Aiming at the far side of the map should not reach across and boost a tower.
	# Rally derives its road from whatever this returns, so an out-of-reach answer
	# is no answer for either order.
	if best.x == -999 or best_distance > Balance.COMMAND_AIM_RADIUS:
		return Vector2i(-999, -999)
	return best


# --- Build panel ------------------------------------------------------------

## Opens the tower sheet, closing the road sheet if it was up.
##
## The two are alternatives, not layers: a plot and a road are different pieces
## of ground and nobody is deciding about both at once. Leaving the other open
## put two panels over each other in the same corner, which is not a stacking
## order anybody chose.
func _open_build_panel(anchor: Vector2i) -> void:
	if _road_panel != null:
		_road_panel.visible = false
	# Cleared before the selection moves, or the previous tower keeps its ring.
	_show_selected_range(false)
	_selected = anchor
	if _command_target != null:
		var tower: TowerData = RunState.tower_at(anchor)
		_command_target.text = "TARGET  ·  %s road  ·  %s" % [
			LANE_NAMES[clampi(RunState.tower_lane(anchor), 0, 3)],
			tower.display_name if tower != null else "open ground"]
	_refresh_build_panel()
	_show_selected_range(true)
	_build_panel.visible = true
	_fit_build_panel.call_deferred()
	if _tutorial != null:
		_tutorial.build_panel_opened()
	UiSound.confirm()
	_pop_in(_build_panel)


## Rings the selected tower's reach.
##
## `Tower.show_range` existed and nothing ever called it, so the rings were dead
## code and a player had no way to see what a tower actually covered - which is
## the single most important thing about where it stands.
func _show_selected_range(on: bool) -> void:
	if battlefield == null:
		return
	var tower: Tower = battlefield.tower_at_anchor(_selected)
	if tower != null and is_instance_valid(tower):
		tower.show_range(on)


func _close_build_panel() -> void:
	if _build_panel == null or not _build_panel.visible:
		return
	_show_selected_range(false)
	_build_panel.visible = false
	_show_build_detail("")
	_hide_build_tooltip()


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


## Rebuilds the sheet's contents, then re-applies the touch sizing to them.
##
## The rows are thrown away and rebuilt every time the sheet opens or the
## selection changes - long after the responsive pass has run. So on a phone the
## element filters and the Close button were built at their desktop size and
## nothing ever came back to grow them: 118px targets on a 120px floor, and the
## only reason it was ever noticed is that a gate measured them.
##
## Applied to this subtree rather than the whole HUD, because everything else has
## already been converted and `apply_touch_tree` is not free.
func _refresh_build_panel() -> void:
	_finish_build_panel_refresh.call_deferred()
	for child: Node in _build_list.get_children():
		child.queue_free()
	# The card the cursor was over has just been freed, so its mouse_exited will
	# never arrive. Without this the footer keeps describing a button that is no
	# longer there - and the figures box keeps hanging beside the panel with the
	# numbers of a row that no longer exists.
	_show_build_detail("")
	_hide_build_tooltip()
	# Assume no grid; the two branches that build one turn the footer back on.
	_set_build_detail_visible(false)

	var anchor: Vector2i = _selected
	var existing: TowerData = RunState.tower_at(anchor)
	var level: int = RunState.level_at(anchor)
	# Placement is free, so a tile has no name of its own - it is identified by
	# the road it covers and how far out it sits, which is what a player reading
	# the panel actually wants to know.
	var reach: float = BattleGrid.footprint_centre(anchor).length()
	_build_title.text = "%s road  ·  %d paces out" % [
		LANE_NAMES[clampi(RunState.tower_lane(anchor), 0, 3)], int(round(reach / BattleGrid.TILE))]

	if existing != null:
		_build_list.add_child(_label("%s  ·  level %d" % [existing.display_name, level], 18))
		_build_list.add_child(_label(existing.description, 14))
		var target_priority: int = RunState.target_priority_at(anchor)
		var target_button: Button = _add_button(_build_list,
			"Target: %s  ·  click to cycle" % TowerData.target_priority_name(target_priority),
			func() -> void:
				RunState.cycle_target_priority(anchor)
				_refresh_build_panel())
		# No tooltip here. The very next line puts the same sentence in the panel
		# as a label, so the floating copy was covering rows to repeat something
		# already visible an inch below it.
		_build_list.add_child(_label(TowerData.target_priority_description(target_priority), 13))
		if not RunState.is_preparation():
			var locked_note: Label = _label(
				"COMBAT LOCK  ·  upgrades and selling return in Preparation.\n"
				+ "This tower is selected for Overdrive; this road is selected for Rally.", 14)
			locked_note.add_theme_color_override("font_color", Color("e8a33d"))
			_build_list.add_child(locked_note)
			return
		var live_tower: Tower = battlefield.tower_at_anchor(anchor)
		if live_tower != null and live_tower.needs_repair():
			var repair_afford: bool = RunState.can_afford_cost(
				{RunState.WOOD: Balance.TOWER_REPAIR_WOOD_COST})
			var repair_button: Button = _add_button(_build_list, "Repair Tower", func() -> void:
				_report(battlefield.try_repair_tower(anchor))
				_refresh_build_panel())
			repair_button.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
			var repair_figures: String = "Restore %d%% durability.\nCost: %d Wood." % [
				int(round(Balance.TOWER_REPAIR_FRACTION * 100.0)), Balance.TOWER_REPAIR_WOOD_COST]
			repair_button.mouse_entered.connect(func() -> void:
				_show_build_tooltip(repair_figures, repair_button))
			repair_button.mouse_exited.connect(func() -> void: _hide_build_tooltip())
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
					_report(battlefield.try_upgrade(anchor))
					_refresh_build_panel())
			IconKit.on_button(button, "upgrade", 22)
			_attach_price(button, {RunState.GOLD: cost}, afford)
			button.disabled = not afford
			if not afford:
				_build_list.add_child(_label("Need %d more Gold." % (
					cost - RunState.currency(RunState.GOLD)), 13))
		else:
			_build_list.add_child(_label("Fully upgraded.", 14))
		var sell: Button = _add_button(_build_list, "Sell", func() -> void:
			_report(battlefield.try_sell(anchor))
			_refresh_build_panel())
		# Every other button in this panel carries a mark; one bare label in the
		# column reads as an unfinished row rather than as a different action.
		IconKit.on_button(sell, "resource", 22)
		return

	if not RunState.is_preparation():
		var lock_note: Label = _label(
			"COMBAT LOCK  ·  construction returns in Preparation.
"
			+ "This road is selected for Rally Road.", 14)
		lock_note.add_theme_color_override("font_color", Color("e8a33d"))
		_build_list.add_child(lock_note)
		return

	var blocked: String = battlefield.placement_problem(anchor)
	if not blocked.is_empty():
		var no := HBoxContainer.new()
		no.add_theme_constant_override("separation", 8)
		var lock: TextureRect = IconKit.rect("lock", 30.0, Color(0.75, 0.72, 0.66))
		if lock != null:
			no.add_child(lock)
		no.add_child(_label(blocked, 15))
		_build_list.add_child(no)
		return

	# Fusions first, because they are the reason this tile is interesting. More
	# than one pair can flank a tile, and v4 §13 says the player picks rather
	# than the game picking for them - so each is offered as its own card.
	var offers: Array[Dictionary] = RunState.combinations_for_tile(anchor)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", BUILD_ROW_GAP)

	for option: Dictionary in offers:
		var combo: TowerData = option["tower"]
		var parents := HBoxContainer.new()
		parents.add_theme_constant_override("separation", 6)
		for parent: int in [combo.parent_a, combo.parent_b]:
			var mark := TextureRect.new()
			mark.texture = IconKit.element(parent)
			mark.custom_minimum_size = Vector2(26.0, 26.0)
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			parents.add_child(mark)
		parents.add_child(_label("%s + %s  ·  fusion" % [
			TowerData.element_name(combo.parent_a),
			TowerData.element_name(combo.parent_b)], 15))
		column.add_child(parents)
		column.add_child(_tower_card(combo, anchor))

	if not offers.is_empty():
		var note: Label = _label(
			"Or build an ordinary tower here. A tower built ordinary stays ordinary.", 13)
		note.add_theme_color_override("font_color", Color("aebcb8"))
		column.add_child(note)

	column.add_child(_element_rail(anchor))
	_build_list.add_child(column)
	_set_build_detail_visible(true)
	UiMetrics.apply_touch_tree(_build_panel, touch_ui())


## Runs after every refresh branch, including the early-return upgrade and lock
## views, so every version of the sheet receives the same responsive sizing.
func _finish_build_panel_refresh() -> void:
	if _build_panel == null or not is_instance_valid(_build_panel):
		return
	UiMetrics.apply_touch_tree(_build_panel, touch_ui())
	_size_build_controls(_build_panel)
	_size_build_scrollbar()
	_fit_build_panel()


func _size_build_controls(root: Node) -> void:
	if touch_ui() and root is BaseButton:
		var button := root as BaseButton
		button.custom_minimum_size.y = Balance.UI_TOUCH_BUILD_TARGET_HEIGHT
		button.set_meta(UiMetrics.TOUCH_TARGET_HEIGHT, Balance.UI_TOUCH_BUILD_TARGET_HEIGHT)
	for child: Node in root.get_children():
		_size_build_controls(child)


func _size_build_scrollbar() -> void:
	if _build_scroll == null:
		return
	UiMetrics.prepare_scroll(_build_scroll, touch_ui())


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
## The build menu's element rail, and the towers it pulls out beside it.
##
## The roster is sixteen towers. As one column that is a scroll, and a scroll is
## where a player stops reading - so the panel offers four elements and picking
## one opens just that element's towers next to it. Two steps, and they are the
## two the roster is already organised around: the element, then the role in it.
func _element_rail(anchor: Vector2i) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 6)
	row.add_child(rail)

	var by_element: Dictionary = {}
	for tower: TowerData in ContentDB.unlocked_base_towers():
		var listed: Array = by_element.get(tower.element, [])
		listed.append(tower)
		by_element[tower.element] = listed

	for element: int in [TowerData.Element.FIRE, TowerData.Element.WATER,
			TowerData.Element.EARTH, TowerData.Element.AIR]:
		var towers: Array = by_element.get(element, [])
		var pick := Button.new()
		pick.custom_minimum_size = Vector2(ELEMENT_RAIL_WIDTH, BUILD_ROW_HEIGHT)
		pick.text = "%s  %d" % [TowerData.element_name(element), towers.size()]
		pick.icon = IconKit.element_sized(element, 26)
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.focus_mode = Control.FOCUS_NONE
		pick.toggle_mode = true
		pick.button_pressed = element == _build_element
		pick.disabled = towers.is_empty()
		pick.add_theme_color_override("font_color", TowerData.element_colour(element))
		pick.tooltip_text = "%s  -  %d unlocked" % [
			TowerData.element_name(element), towers.size()]
		pick.pressed.connect(func() -> void:
			_build_element = -1 if _build_element == element else element
			_refresh_build_panel())
		rail.add_child(pick)

	var flyout := VBoxContainer.new()
	flyout.add_theme_constant_override("separation", BUILD_ROW_GAP)
	flyout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(flyout)

	if _build_element < 0 or not by_element.has(_build_element):
		var hint: Label = _label("Pick an element to see its towers.", 14)
		hint.add_theme_color_override("font_color", Color("aebcb8"))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flyout.add_child(hint)
		return row

	for tower: TowerData in by_element[_build_element]:
		flyout.add_child(_tower_card(tower, anchor))
	return row


func _tower_card(tower: TowerData, anchor: Vector2i) -> Button:
	# Quoted from the same function that charges. Assembling the price here as
	# well is how a quote and a charge end up disagreeing, and only one of them
	# knew about the secondary currency each element draws on.
	var cost_map: Dictionary = Battlefield.cost_of(tower)
	var affordable: bool = RunState.can_afford_cost(cost_map)

	var button := Button.new()
	button.text = tower.display_name
	button.custom_minimum_size = Vector2(0.0, BUILD_ROW_HEIGHT)
	button.icon = IconKit.element_sized(tower.element, 26)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE

	_attach_price(button, cost_map, affordable)
	button.disabled = not affordable
	button.add_theme_color_override("font_color", TowerData.element_colour(tower.element))
	button.pressed.connect(func() -> void:
		Sfx.play("sfx_tower_build", -4.0)
		_report(battlefield.try_build(anchor, tower))
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
	# The figures box *and* the footer, which an earlier version deliberately
	# avoided because both carried the same sentence. They no longer do: the
	# footer says what the tower is for, the box gives the numbers. Two
	# questions, and the second one cannot be answered in prose.
	#
	# What changed is where the numbers appear. This was `button.tooltip_text`,
	# and Godot opens those at the cursor - which is inside the panel, so the
	# figures for the row being considered covered the rows it was being weighed
	# against. The box now opens beside the panel instead of over it.
	var figures: String = _tower_tooltip(tower, cost_map)
	button.mouse_entered.connect(func() -> void:
		_show_build_detail(blurb if affordable else "%s\nInsufficient currency." % blurb)
		_show_build_tooltip(figures, button))
	button.mouse_exited.connect(func() -> void:
		_show_build_detail("")
		_hide_build_tooltip())
	return button


## The numbers behind a tower, for its hover tooltip.
func _tower_tooltip(tower: TowerData, cost_map: Dictionary) -> String:
	var level: int = 1
	var rate: float = 1.0 / maxf(tower.interval_at(level), 0.001)
	var lines: PackedStringArray = [
		"%s  -  %s" % [tower.display_name, TowerData.element_name(tower.element)],
		"Damage %.0f  -  %.2f shots/sec  -  %.0f DPS" % [
			tower.damage_at(level), rate, tower.damage_at(level) * rate],
		"Range %.0f" % tower.range_at(level),
	]
	if tower.aoe_at(level) > 0.0:
		lines.append("Blast radius %.0f" % tower.aoe_at(level))
	if tower.extra_targets_at(level) > 0:
		lines.append("Hits %d targets" % (1 + tower.extra_targets_at(level)))
	if tower.burn_dps > 0.0:
		lines.append("Burn %.0f/sec for %.1fs" % [tower.burn_dps, tower.burn_duration])
	if tower.slow_factor < 1.0:
		lines.append("Slow to %d%% for %.1fs" % [
			int(round(tower.slow_factor * 100.0)), tower.slow_duration])
	if tower.max_hp > 0.0:
		lines.append("Structure %.0f HP" % tower.max_hp)
	lines.append("Cost: %s" % RunState.format_cost(cost_map))
	return "\n".join(lines)


## Blank means "nothing hovered", which reads as a hole in the panel rather than
## as an empty field. The footer's height is reserved either way, so it may as
## well say what it is for.
## How long a region card fades and how long it holds. Short: this is a caption,
## not a cutscene, and the player is usually mid-wave when a boss one appears.
const REGION_CARD_FADE: float = 0.45
const REGION_CARD_HOLD: float = 2.1

const BUILD_HINT: String = "Point at a tower to see what it does."


## Pins a price to the right edge of a button, clear of the frame.
##
## A right-anchored child rather than part of the label, so a column of them
## lines up. Padding the string out with spaces cannot work here: the theme font
## is proportional, so a space is not a fixed width and the prices land ragged.
##
## It also keeps long labels off the frame. "Upgrade to level 2 - 90 resources"
## as one string ran the word "resources" straight into the right-hand bolt.
## The price tag on a build or upgrade button.
##
## Takes a currency map rather than a bare number, because a tower can cost two
## things now and a button that shows only the Gold is a button that lies about
## what it will charge.
func _attach_price(button: Button, cost: Dictionary, affordable: bool) -> void:
	var parts: PackedStringArray = []
	for id: String in RunState.CURRENCIES:
		var amount: int = int(cost.get(id, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, id.substr(0, 1).to_upper()])
	var price := Label.new()
	price.text = "  ".join(parts)
	price.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	price.offset_left = -150.0
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
	_wounds_label.tooltip_text = ("A lethal down adds one Wound and reduces maximum HP by 10%%. "
		+ "Reaching %d Wounds ends the run.") % maximum
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
	# Refreshed here as well as on level-up, so a HUD rebuilt mid-run - a scope
	# change, a reload - does not show Lv 1 under a level 60 hero.
	if _level != null:
		_level.text = "Lv %d" % RunState.hero_level


func _on_scope_changed(scope: int) -> void:
	var in_raid: bool = scope == int(GameDirector.Scope.RAID)
	var on_field: bool = scope == int(GameDirector.Scope.BATTLEFIELD)
	if _xp_band != null:
		_xp_band.visible = on_field or in_raid
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
	elif _boss_panel != null:
		_boss_panel.visible = _active_boss_for_ui() != null


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


## The consumables the hero is carrying, one icon each.
##
## Rebuilt only when the holding actually changes. This runs inside the HUD's
## per-frame refresh, and freeing and rebuilding a row of icons sixty times a
## second to draw the same two things would be a real cost for no change on
## screen - so the signature of what is held is compared first.
func _update_carried_items() -> void:
	if _item_row == null:
		return
	var signature: String = ""
	var ids: Array = RunState.held_items.keys()
	ids.sort()
	for id: Variant in ids:
		signature += "%s:%d|" % [String(id), RunState.item_count(String(id))]
	if signature == _items_signature:
		return
	_items_signature = signature

	for child: Node in _item_row.get_children():
		_item_row.remove_child(child)
		child.queue_free()
	for id: Variant in ids:
		var kind: ItemData = ContentDB.item(String(id))
		if kind == null:
			continue
		var held: int = RunState.item_count(kind.id)
		var icon: Control = _bar_icon(kind.id, kind.display_name)
		icon.custom_minimum_size = Vector2(26.0, 26.0)
		# The count only when there is more than one, so a carry-limit-of-one
		# item is not labelled with a number that can never change.
		icon.tooltip_text = "%s%s\n%s" % [kind.display_name,
			"  x%d" % held if held > 1 else "", kind.effect_line()]
		_item_row.add_child(icon)


## A variant met for the first time, or its bond completed.
##
## Written from the key rather than passed a sentence, so the wording lives in
## one place and a new rarity needs no new string. Shiny is louder because a
## shiny is the moment the system exists for.
func _spirit_words(bond_key: String) -> String:
	var kind := ContentDB.wildlife_kinds.get(
		SpiritBond.species_of(bond_key), null) as WildlifeData
	if kind == null:
		return ""
	return SpiritBond.display_name(kind, SpiritBond.rarity_of(bond_key),
		SpiritBond.shiny_of(bond_key)).to_upper()


func _on_spirit_discovered(bond_key: String, count: int, needed: int) -> void:
	var words: String = _spirit_words(bond_key)
	if words.is_empty():
		return
	_show_message("%s DISCOVERED  ·  Spirit Bond %d / %d" % [words, count, needed])
	if SpiritBond.shiny_of(bond_key):
		Vfx.word(Vector2.ZERO, "SHINY", Balance.SPIRIT_SHINY_COLOUR, 40)
		EventBus.camera_shake_requested.emit(3.0, 0.25)


func _on_spirit_bonded(bond_key: String) -> void:
	var words: String = _spirit_words(bond_key)
	if words.is_empty():
		return
	_show_message("%s UNLOCKED" % words)
	Vfx.flash(SpiritBond.tint(SpiritBond.rarity_of(bond_key),
		SpiritBond.shiny_of(bond_key)), 0.10, 0.45)
