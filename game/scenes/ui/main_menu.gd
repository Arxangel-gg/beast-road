class_name MainMenu
extends Control

const LeaderboardScreenScript = preload("res://scenes/ui/leaderboard_screen.gd")
const CoopScreenScript = preload("res://scenes/ui/coop_screen.gd")
const ChronicleScreenScript = preload("res://scenes/ui/chronicle_screen.gd")
const CodexScreenScript = preload("res://scenes/ui/codex_screen.gd")
const PenScreenScript = preload("res://scenes/ui/pen_screen.gd")
const ActStartScreenScript = preload("res://scenes/ui/act_start_screen.gd")
const SaveSlotScreenScript = preload("res://scenes/ui/save_slot_screen.gd")

## The front door. Shows what the unlock pool has grown to, because that is the
## only thing that persists between runs (GDD §10) and it should be visible.

@export var new_run_button: Button
@export var settings_button: Button
@export var quit_button: Button
@export var stats_label: Label
@export var seed_input: LineEdit



var _settings: SettingsPanel
var _leaderboard: CanvasLayer
var _coop: CanvasLayer
var _chronicle: CanvasLayer
var _codex: CanvasLayer
var _pen: CanvasLayer
## The stable's counter. See `_build_stable_button`.
var _stable: StableScreen = null
var _act_start: CanvasLayer
## The Wardens this machine keeps (owner, 2026-09-22). See
## `_build_slot_button`.
var _slots: SaveSlotScreen = null
var _frame: MenuFrame = null
var _world_grid: PixelGrid = null
var _ui_grid: PixelGrid = null
var _crisp: CrispText = null
## The Hold: the room the stash, the Ledger, the Chronicle, the codex and the
## board moved into (owner ruling, 2026-09-11). See `HubScreen`.
var _hub: HubScreen
var _guide: GuideScreen
var _coop_button: Button
## The Warden's line (bottom centre) and the build (top right), placed by
## `_fit_menu` (owner brief, 2026-09-12).
var _warden_label: Label = null
var _version_label: Label = null
var _seed_hovered: bool = false
var _seed_tween: Tween = null


func _exit_tree() -> void:
	ScreenFit.set_menu_layout(false, true)


## Portrait puts the wordmark above the menu instead of behind its first
## buttons. The scrollable middle keeps both the title and statistics clear.
func _fit_menu() -> void:
	if not is_inside_tree():
		return
	var scroll := get_node_or_null("MenuScroll") as ScrollContainer
	var title := get_node_or_null("Title") as TextureRect
	if scroll == null or title == null or stats_label == null:
		return
	var screen: Vector2 = get_viewport_rect().size
	var column: Control = scroll.get_node_or_null("Buttons") as Control
	if TouchInput.is_showing() and screen.y > screen.x:
		var margin: float = Balance.UI_PANEL_MARGIN
		var width: float = screen.x - margin * 2.0
		var logo_height: float = width / title.texture.get_size().aspect()
		title.set_anchors_preset(Control.PRESET_TOP_LEFT)
		title.position = Vector2(margin, margin)
		title.size = Vector2(width, logo_height)
		var stats_height: float = stats_label.get_combined_minimum_size().y
		stats_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		stats_label.position = Vector2(margin, screen.y - margin - stats_height)
		stats_label.size = Vector2(width, stats_height)
		scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
		scroll.position = Vector2(margin, title.position.y + logo_height + margin)
		scroll.size = Vector2(width, maxf(0.0,
			stats_label.position.y - margin - scroll.position.y))
		if column != null:
			column.size_flags_vertical = Control.SIZE_FILL
		if _warden_label != null:
			_warden_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_warden_label.position = Vector2(margin, stats_label.position.y - 30.0)
			_warden_label.size = Vector2(width, 26.0)
		if _version_label != null:
			_version_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_version_label.position = Vector2(margin, 4.0)
			_version_label.size = Vector2(width, 22.0)
	else:
		# The desktop layout (owner brief, 2026-09-12): the wordmark top
		# centre, the column hugging the bottom-left corner, the Warden's line
		# bottom centre, the statistics bottom right, the build top right.
		title.set_anchors_preset(Control.PRESET_CENTER_TOP)
		title.offset_left = -420.0
		title.offset_top = 54.0
		title.offset_right = 420.0
		title.offset_bottom = 474.0
		scroll.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		scroll.grow_vertical = Control.GROW_DIRECTION_BEGIN
		scroll.offset_left = Balance.MENU_COLUMN_INSET.x
		scroll.offset_right = scroll.offset_left + 400.0
		scroll.offset_bottom = -Balance.MENU_COLUMN_INSET.y
		# As tall as the column wants and no taller, so the buttons sit on
		# the bottom edge; a ScrollContainer fills its child to its own height
		# whatever the child's size flags say.
		var wanted: float = screen.y - 24.0 - Balance.MENU_COLUMN_INSET.y
		if column != null:
			column.size_flags_vertical = Control.SIZE_FILL
			wanted = minf(column.get_combined_minimum_size().y + 8.0, wanted)
		scroll.offset_top = scroll.offset_bottom - wanted
		stats_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		stats_label.offset_left = -640.0
		stats_label.offset_top = -190.0
		stats_label.offset_right = -40.0
		stats_label.offset_bottom = -40.0
		if _warden_label != null:
			_warden_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			_warden_label.offset_left = -320.0
			_warden_label.offset_right = 320.0
			_warden_label.offset_top = -40.0
			_warden_label.offset_bottom = -14.0
		if _version_label != null:
			_version_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			_version_label.offset_left = -400.0
			_version_label.offset_right = -20.0
			_version_label.offset_top = 14.0
			_version_label.offset_bottom = 38.0


## The wordmark's sheen, and its own clock.
var _title_paint: ShaderMaterial = null
var _title_clock: float = 0.0
var _title_arcs: MenuArcs = null
## The interface is never quite still: see `UiJuice.idle_shimmer`.
var _shimmer_left: float = 1.5
var _shimmer_dice := RandomNumberGenerator.new()


func _ready() -> void:
	# **No hero here, so nothing that reads one.**
	#
	# Owner, 2026-09-15: "the red health vignette still appears on title screen
	# in some cases but shouldn't." It is a shader parameter on a layer `Vfx`
	# owns, and `Vfx` is an autoload - so it outlives every scene change, and
	# the only thing that ever takes it off is somebody choosing to. It was
	# cleared when a run was *settled* (`run_ended`), which misses every way of
	# leaving one that settles nothing: quitting from the pause menu, and a
	# co-op host going away. Nothing on this screen reports health, so whatever
	# the road last said was worn until the next run started.
	#
	# Cleared at the destination rather than at each door, because the
	# invariant the owner reported is about *this screen* rather than about any
	# particular way of reaching it - and a door added later cannot forget.
	# Deliberately not done on every scope change: a raid must not wipe the
	# warning that the hero is nearly dead, which is why `Vfx.clear` and
	# `Vfx.clear_vignette` are two functions.
	Vfx.clear_vignette()
	ScreenFit.set_menu_layout(true)
	get_viewport().size_changed.connect(_fit_menu)
	TouchInput.shown_changed.connect(func(_showing: bool) -> void: _fit_menu.call_deferred())
	_fit_menu.call_deferred()
	MusicPlayer.play("menu")
	_light_the_title()
	_spark_the_title()
	_grade_the_interface.call_deferred()
	# **The menu column scrolls.** It used to sit in a fixed 310px box anchored
	# to the middle of the screen while holding far more than that - on a tall
	# desktop the overflow happened to land on screen and nobody noticed, and on
	# a phone held sideways the first and last buttons ran off the top and bottom
	# with no way to reach them. Reported from an installed APK, where "Take the
	# road" itself was one of the buttons off the screen.
	var scroll := get_node_or_null("MenuScroll") as ScrollContainer
	if scroll != null:
		UiMetrics.prepare_scroll(scroll, TouchInput.is_showing())
	new_run_button.pressed.connect(_start_run)
	quit_button.pressed.connect(GameDirector.quit_game)
	seed_input.text_submitted.connect(func(_value: String) -> void: _start_run())

	# All three carry an icon, which also left-aligns them. Without one on the
	# first button its label stayed centred while the two below it were not, and a
	# menu column with one odd row out reads as a mistake before it reads as a
	# menu. The arrow means the same here as on the pause screen: carry on.
	IconKit.on_button(new_run_button, "pressure_arrow", 26)
	IconKit.on_button(settings_button, "settings", 24)
	IconKit.on_button(quit_button, "close", 24)

	_build_tier_row()
	_build_stash_button()
	_build_coop_button()
	_build_chronicle_button()
	_build_codex_button()
	_build_pen_button()
	_build_stable_button()
	_build_walk_button()
	_build_resume_button()
	_build_act_start_button()
	_build_slot_button()
	_build_leaderboard_button()
	_build_hold()
	_build_guide_button()
	_build_settings()
	settings_button.pressed.connect(func() -> void: _show_settings(true))
	_build_version_label()
	_dress_seed_row()

	# Wired after every door has been built, so the watcher sees all of them.
	_watch_the_doors()
	stats_label.text = _summary()
	# **A player who has never played has one correct press**, and it is not
	# New run. The walk takes focus when it is offered and nothing else does.
	var walk: Node = new_run_button.get_parent().get_node_or_null("WalkValley")
	if walk is Button:
		(walk as Button).grab_focus()
	else:
		new_run_button.grab_focus()
	_setup_stage()
	_setup_frame()
	_setup_pixel_grids()
	_setup_front_leaves()
	# Again, now that the lines this lays out exist.
	_fit_menu.call_deferred()


## **Every door in the Hold comes back to the Hold.**
##
## Owner, 2026-09-16: closing a section should reopen the room, "so that players
## do not have to keep opening the Hold to go through each one".
##
## `HubScreen.suspend()` has said "remembering to come back" since it was built,
## and `_focus_home()` is what comes back - but the two were joined by hand at
## each door and only three of them ever got the line. The Stash, the Ledger, the
## Pen, the Chronicle, the Codex and the Leaderboard all dropped the player onto
## the front door instead.
##
## Wired once here rather than at each door, because a return that has to be
## remembered at seven call sites is one that will be forgotten at the eighth.
## Every screen the menu owns is a `CanvasLayer` child of it, so watching them
## all catches the doors that exist and the ones added later.
##
## A front-door screen closing does nothing: `_focus_home` only reopens the room
## when it is already visible or suspended.
func _watch_the_doors() -> void:
	for child: Node in get_children():
		var screen := child as CanvasLayer
		if screen == null or screen == _hub:
			continue
		if screen.visibility_changed.is_connected(_on_door_closed):
			continue
		screen.visibility_changed.connect(_on_door_closed.bind(screen))


func _on_door_closed(screen: CanvasLayer) -> void:
	if screen == null or screen.visible:
		return
	_focus_home()


## Where focus lands when a screen closes: the room if it is open, else the
## front door's first button.
func _focus_home() -> void:
	# The room comes back when a door closes over it.
	if _hub != null and (_hub.visible or _hub.is_suspended()):
		_hub.open()
		return
	new_run_button.grab_focus()


## The Hold. Every door that is not "play" moves off the front door and into
## the room, so the menu is New run, Co-op, The Hold, Settings, Quit - and the
## room is where the account lives. `HubScreen.adopt` keeps each button's own
## handler, so nothing that opened before opens differently now.
func _build_hold() -> void:
	if new_run_button == null:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	_hub = HubScreen.new()
	_hub.name = "Hold"
	add_child(_hub)
	var button := Button.new()
	button.name = "Hold"
	button.text = "The Hold"
	button.custom_minimum_size = settings_button.custom_minimum_size
	button.theme_type_variation = settings_button.theme_type_variation
	IconKit.on_button(button, "quiet_ledger", 24)
	column.add_child(button)
	var coop: Node = column.get_node_or_null("Coop")
	column.move_child(button, (coop.get_index() + 1) if coop != null else new_run_button.get_index() + 1)
	_hub.closed.connect(func() -> void: button.grab_focus())
	button.pressed.connect(func() -> void: _hub.open())
	_build_smithy_button(column)
	for door: String in ["Stash", "Ledger", "Vendor", "Smithy", "Pen", "Stable",
			"Chronicle",
			"Codex", "Leaderboard", "WalkAgain"]:
		var found: Node = column.get_node_or_null(door)
		if found is Button:
			_hub.adopt(found as Button)


## The forge (owner brief, 2026-09-13).
##
## Built here and then adopted into the Hold with the other doors, which is the
## pattern every screen in this room follows: the menu owns the screen, the room
## owns the button, and the button is the same button either way.
##
## **Always present, unlike the stash button.** The stash hides until there is
## gear or Marks because an empty stash is a promise the game has not made yet;
## the forge is the opposite - it is the thing that tells a new Warden that the
## trees and seams on the outskirts are worth stopping for at all. It says so
## when the store is empty rather than not being there.
func _build_smithy_button(column: Node) -> void:
	var button := Button.new()
	button.name = "Smithy"
	button.text = "The Forge"
	IconKit.on_button(button, "quarry_gauntlets", 24)
	column.add_child(button)

	var screen := SmithyScreen.new()
	add_child(screen)
	screen.closed.connect(_focus_home)
	button.pressed.connect(func() -> void: screen.open())


## Swaps the still key art for the living one.
##
## The authored `Art` node stays in the scene and is emptied rather than freed.
## It is what the scene file's NodePath points at, and a menu that deletes its
## own exported node is a menu that breaks the next time someone opens the scene
## — which is exactly the failure `menu_check` exists to catch.
func _setup_stage() -> void:
	var art: TextureRect = get_node_or_null("Art") as TextureRect
	if art == null:
		return
	art.texture = null

	var stage := MenuStage.new()
	stage.name = "Stage"
	# Directly after the art it replaces, so it is under the logo, the buttons
	# and the statistics line and over nothing else.
	art.add_sibling(stage)
	move_child(stage, art.get_index() + 1)


## The carved border, on its own layer over everything and reading nothing.
##
## Owner, 2026-09-15: a frame that is "gorgeous and maybe even has lively
## animated elements with awesome game juice and even reactiveness". See
## `menu_frame.gd` for what is in it; this is where it is hung and where it is
## told what the player just did.
##
## **Over the picture, under the interface, and reading no input.** It frames
## the scene rather than the screen: the buttons, the title and the statistics
## all draw in front of it, which is what stops a carved border from clipping
## the words in a corner - it did exactly that on the first pass, over the run
## statistics. Input is ignored as well as ordered, because a decoration that
## could swallow TAKE THE ROAD is the worst trade in the project.
## The pixel grid on the title screen (owner, 2026-09-17: *"Make sure the main
## menu is also properly affected by the pixelshader if toggled on, including
## the extra toggle for UI elements too not including text."*).
##
## **Bands in the tree rather than layers**, which is the one thing that makes
## this screen different from a run. In a run the scopes, the HUD and the type
## are already three `CanvasLayer`s and a filter simply takes a number between
## them. Here the painted beast, the carved border, the wordmark, the buttons
## and the statistics are all children of one `Control`, drawn in tree order -
## so what goes *between* the art and the buttons is a sibling at the right
## index. `PixelGrid` is a `Control` for exactly this.
##
## Inserted rather than appended, and the indices are read off the nodes they
## have to sit between rather than written down: `_setup_frame` already moves
## the border by reading `Stage`'s index, and a second hand-kept ordering is a
## second thing to get wrong the next time somebody adds a node here.
func _setup_pixel_grids() -> void:
	# So a video preference changed from the title screen's own settings panel
	# reaches the screen underneath it rather than only the saved file.
	add_to_group(Graphics.SETTINGS_GROUP)
	_world_grid = PixelGrid.new()
	_world_grid.name = "PixelGridWorld"
	add_child(_world_grid)
	var title: Node = get_node_or_null("Title")
	if title != null:
		move_child(_world_grid, title.get_index() + 1)

	# The interface's own grid goes last, so everything pressable is under it.
	_ui_grid = PixelGrid.new()
	_ui_grid.name = "PixelGridUI"
	add_child(_ui_grid)

	# And the type above both, which is the whole of "except for text".
	_crisp = CrispText.new()
	_crisp.name = "CrispText"
	_crisp.ui_filter_grid = _ui_grid
	_crisp.world_filter_grid = _world_grid
	_crisp.ui_roots = [self] as Array[Node]
	add_child(_crisp)
	_refresh_pixel_grids()


## Both grids answer the video settings, and are told together because the
## interface's only means anything under the world's.
func _refresh_pixel_grids() -> void:
	if _world_grid != null:
		_world_grid.set_enabled(Graphics.pixel_filter())
	if _ui_grid != null:
		_ui_grid.set_enabled(Graphics.pixel_filter_ui())
	if _crisp != null:
		_crisp.set_enabled(Graphics.pixel_filter(), Graphics.pixel_filter_ui())


## `Graphics.apply_to_scene` calls this on every node in its group when a video
## preference changes, so the switch reaches the title screen while it is open.
func refresh_from_settings() -> void:
	_refresh_pixel_grids()


func _setup_frame() -> void:
	var art: Node = get_node_or_null("Art")
	_frame = MenuFrame.new()
	_frame.name = "MenuBorder"
	_frame.light = _menu_light()
	add_child(_frame)
	# **Over the picture and under the interface**, which is the whole of its
	# placement. Photographed above everything on a CanvasLayer first: the
	# border ran across the run statistics in the bottom right and clipped
	# three words off them. A frame that covers text is worse than no frame,
	# and no thickness small enough to miss that line is thick enough to read
	# as carved - so the order is the answer rather than the size.
	var stage: Node = get_node_or_null("Stage")
	var after: Node = stage if stage != null else art
	if after != null:
		move_child(_frame, after.get_index() + 1)
	_wire_frame_to(self)


## Every button on the menu tells the frame where it was pressed.
##
## Walked rather than listed, because this screen builds several of its buttons
## conditionally - the stash only appears once there is something in it - and a
## hand-kept list is a button that quietly stops answering.
func _wire_frame_to(from: Node) -> void:
	for child: Node in from.get_children():
		var button := child as BaseButton
		if button != null and not button.button_down.is_connected(_on_frame_touched):
			button.button_down.connect(_on_frame_touched.bind(button))
		_wire_frame_to(child)


func _on_frame_touched(button: Control) -> void:
	if _frame == null or not is_instance_valid(button):
		return
	_frame.pulse_at(button.get_global_rect().get_center())


## The rare leaves that cross in front of the buttons.
##
## On their own layer above the interface, which is the only way a leaf can pass
## over a word - and the reason they are rare and small and quick: see
## `menu_leaves.gd`. Input is ignored, like the frame, because a decoration that
## could take a press is the worst trade in the project.
func _setup_front_leaves() -> void:
	var stage: Node = get_node_or_null("Stage")
	if stage == null or not stage.has_method("front_leaves"):
		return
	var leaves: MenuLeaves = stage.call("front_leaves")
	if leaves == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "FrontLeafLayer"
	layer.layer = 7
	add_child(layer)
	layer.add_child(leaves)


## The stash, reached from the menu rather than from a run.
##
## Only once there is something in it. A button leading to an empty screen on a
## first launch is a promise the game has not made yet, and the first gear a
## player finds announces itself anyway.
func _build_stash_button() -> void:
	if MetaState.stash.is_empty() and MetaState.marks <= 0 and MetaState.shards <= 0:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	var button := Button.new()
	button.name = "Stash"
	button.text = "Stash  ·  %d Marks  ·  %d Shards" % [MetaState.marks, MetaState.shards]
	IconKit.on_button(button, "relic", 24)
	column.add_child(button)
	column.move_child(button, new_run_button.get_index() + 1)

	var screen := StashScreen.new()
	add_child(screen)
	screen.closed.connect(func() -> void:
		button.text = "Stash  ·  %d Marks  ·  %d Shards" % [MetaState.marks, MetaState.shards]
		_focus_home())
	button.pressed.connect(func() -> void: screen.open())
	_build_exchange_button(column, button, new_run_button)


## The Long Ledger, under the stash, because it is the stash's other half.
##
## Same rule as the stash button and for the same reason: an exchange with
## nothing to list and nothing to spend is a promise the game has not made yet.
## It appears the moment there is either gear or Marks - which is exactly when a
## player first has a decision to make about what a piece is worth.
func _build_exchange_button(column: Node, stash_button: Button,
		new_run_button: Button) -> void:
	var button := Button.new()
	button.name = "Ledger"
	button.text = "The Long Ledger"
	# The ledger charm's own icon: a closed book of accounts, which is exactly
	# what this is. Reused rather than authored, so the manifest is unchanged.
	IconKit.on_button(button, "quiet_ledger", 24)
	column.add_child(button)
	column.move_child(button, stash_button.get_index() + 1)

	var screen := ExchangeScreen.new()
	add_child(screen)
	screen.closed.connect(func() -> void:
		stash_button.text = "Stash  ·  %d Marks  ·  %d Shards" % [
			MetaState.marks, MetaState.shards]
		button.text = _ledger_caption()
		_focus_home())
	button.pressed.connect(func() -> void: screen.open())
	button.text = _ledger_caption()
	_build_vendor_button(column, button)


## What the button says: silent when the board is empty, and counting when it is.
##
## A line that has been met is the one thing worth interrupting a player for -
## Marks or gear are sitting there - so it is said on the menu rather than only
## behind a click.
func _ledger_caption() -> String:
	var waiting: int = 0
	var standing: int = 0
	for order: ExchangeOrder in Exchange.orders():
		if order.stage == ExchangeOrder.Stage.FILLED:
			waiting += 1
		elif order.is_open():
			standing += 1
	if waiting > 0:
		return "The Long Ledger  ·  %d met" % waiting
	if standing > 0:
		return "The Long Ledger  ·  %d standing" % standing
	return "The Long Ledger"


## **The Market** (owner brief, 2026-09-17): the vendor's own wares, with the
## Long Ledger on the wall inside it.
##
## Built here and adopted into the Hold with the other doors, which is the
## pattern every screen in that room follows: the menu owns the screen, the
## room owns the button, and `HoldYard` stands a building where the button is.
##
## **The Ledger is pressed rather than reimplemented.** The shop asks for it
## (`ledger_wanted`) and this presses the same button the Hold's own list
## does, so there is exactly one path to that screen however a player reaches
## it - and the shop steps aside first, so the Ledger is not opened over a
## window nobody can see behind.
func _build_vendor_button(column: Node, ledger_button: Button) -> void:
	var button := Button.new()
	button.name = "Vendor"
	button.text = "The Market"
	IconKit.on_button(button, "ledgerkeepers_seal", 24)
	column.add_child(button)
	column.move_child(button, ledger_button.get_index() + 1)

	var screen := VendorScreen.new()
	add_child(screen)
	screen.closed.connect(_focus_home)
	screen.ledger_wanted.connect(func() -> void:
		screen.hide_screen()
		ledger_button.pressed.emit())
	button.pressed.connect(func() -> void: screen.open())


## The campaign tier, chosen before a run and shown with the hero it will be
## played by.
##
## Built here rather than in the scene because which tiers exist is an account
## question: a locked tier is not drawn at all. A row of greyed-out buttons
## advertises content a new player cannot have and reads as a paywall.
func _build_tier_row() -> void:
	if new_run_button == null:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return

	# The Warden's line sits bottom centre (owner brief, 2026-09-12) rather
	# than in the column; `_fit_menu` places it.
	_warden_label = Label.new()
	_warden_label.name = "Warden"
	_warden_label.text = _warden_line()
	_warden_label.add_theme_font_size_override("font_size", 16)
	_warden_label.add_theme_color_override("font_color", Color("d8cfb4"))
	_warden_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warden_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_warden_label)

	var unlocked: Array[CampaignTierData] = []
	for tier: CampaignTierData in ContentDB.tiers_sorted():
		if MetaState.tier_is_unlocked(tier):
			unlocked.append(tier)
	if unlocked.size() <= 1:
		# One tier open is not a choice, and a picker with one entry is furniture.
		if not unlocked.is_empty():
			MetaState.last_tier_id = unlocked[0].id
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for tier: CampaignTierData in unlocked:
		var button := Button.new()
		button.toggle_mode = true
		button.text = tier.display_name
		# The ends rather than the whole array: ten numbers in a tooltip is a
		# wall of digits, and what the player is deciding is how far above their
		# level the road starts and where it finishes.
		button.tooltip_text = "%s\nExpects level %d at the first act boss, %d at the last." % [
			tier.summary, tier.expected_level(1),
			tier.expected_level(Balance.ACT_COUNT)]
		button.button_pressed = tier.id == MetaState.last_tier_id
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			MetaState.last_tier_id = tier.id
			MetaState.save_game()
			for other: Node in row.get_children():
				(other as Button).button_pressed = (other as Button).text == tier.display_name)
		row.add_child(button)
	column.add_child(row)
	column.move_child(row, new_run_button.get_index())


## The shared board is always reachable. With no network it becomes this save's
## personal-best list, so the button never opens a dead screen.
## Co-op, on the front door.
##
## Directly under the button that starts a single-player run, because that is
## where a player looks for "the other way to play" and because co-op is a
## separate mode rather than a setting on this one.
##
## Its absence was the whole of "multiplayer is not fully integrated": every
## piece underneath worked and was gated across two real processes, and none of
## it could be reached by anyone playing the game.
func _build_coop_button() -> void:
	if new_run_button == null:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	var button := Button.new()
	button.name = "Coop"
	button.text = "Co-op"
	button.custom_minimum_size = settings_button.custom_minimum_size
	button.theme_type_variation = settings_button.theme_type_variation
	IconKit.on_button(button, "pressure_arrow", 26)
	column.add_child(button)
	# Immediately below "New run", not at the bottom with the utilities.
	column.move_child(button, new_run_button.get_index() + 1)

	_coop = CoopScreenScript.new()
	add_child(_coop)
	_coop_button = button
	(_coop as CoopScreenScript).closed.connect(func() -> void: button.grab_focus())
	button.pressed.connect(func() -> void:
		if not MetaState.tutorial_done:
			# Owner brief, 2026-09-12, amended 2026-09-17: a run that *ends*
			# is what opens it, however it ended. The button says so.
			button.text = "Co-op  \u00b7  finish your first run"
			return
		_coop.open())
	_refresh_coop_gate()


## Co-op waits for the first run to end, and says so.
func _refresh_coop_gate() -> void:
	if _coop_button == null:
		return
	if MetaState.tutorial_done:
		_coop_button.text = "Co-op"
		_coop_button.tooltip_text = ""
		_coop_button.modulate = Color.WHITE
	else:
		_coop_button.text = "Co-op  \u00b7  locked"
		_coop_button.tooltip_text = "Walk your first road to its crossroad, and the door opens."
		_coop_button.modulate = Color(0.72, 0.72, 0.75)


## The guide: every section in one place, on the front door beside Settings.
func _build_guide_button() -> void:
	if settings_button == null:
		return
	var column: Node = settings_button.get_parent()
	if column == null:
		return
	var button := Button.new()
	button.name = "Guide"
	button.text = "Guide"
	button.custom_minimum_size = settings_button.custom_minimum_size
	button.theme_type_variation = settings_button.theme_type_variation
	IconKit.on_button(button, "quiet_ledger", 24)
	column.add_child(button)
	column.move_child(button, settings_button.get_index())
	_guide = GuideScreen.new()
	_guide.name = "Guide"
	add_child(_guide)
	_guide.closed.connect(func() -> void: button.grab_focus())
	button.pressed.connect(func() -> void: _guide.open())


func _build_leaderboard_button() -> void:
	if new_run_button == null:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	var button := Button.new()
	button.name = "Leaderboard"
	button.text = "Leaderboard"
	button.custom_minimum_size = settings_button.custom_minimum_size
	button.theme_type_variation = settings_button.theme_type_variation
	IconKit.on_button(button, "distance", 24)
	column.add_child(button)
	column.move_child(button, settings_button.get_index())

	_leaderboard = LeaderboardScreenScript.new()
	add_child(_leaderboard)
	(_leaderboard as LeaderboardScreenScript).closed.connect(func() -> void: button.grab_focus())
	button.pressed.connect(func() -> void: _leaderboard.open())


## The bounded account goals, visible before the player earns one.
##
## A result-only achievement is not an objective: the player could not aim for
## it. Keeping the Chronicle on the front door turns every row into a deliberate
## challenge while preserving the GDD's no-grind progression ceiling.
## The codex, beside the Chronicle.
##
## Always present, unlike the stash button - a codex with nothing in it still
## says what there is to find, which is the whole reason to open one. That is the
## opposite of the stash's rule, and deliberately so: an empty stash is a promise
## the game has not made yet, while an empty codex is the map of the promise.
func _build_codex_button() -> void:
	if new_run_button == null:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	var button := Button.new()
	button.name = "Codex"
	button.text = _codex_label()
	button.custom_minimum_size = settings_button.custom_minimum_size
	button.theme_type_variation = settings_button.theme_type_variation
	IconKit.on_button(button, "blueprint", 24)
	column.add_child(button)
	column.move_child(button, settings_button.get_index())

	_codex = CodexScreenScript.new()
	add_child(_codex)
	button.pressed.connect(func() -> void:
		_codex.call("open"))
	# Refreshed when it closes, so the count on the button is the count inside.
	_codex.visibility_changed.connect(func() -> void:
		if not _codex.visible:
			button.text = _codex_label()
			button.grab_focus())


## The stable (owner brief, 2026-09-17).
##
## Built here and adopted into the Hold with every other door, which is the
## pattern the whole room is built on: the menu owns the screen, the room owns
## the button, and `HoldYard` stands a barn where the button is. So the list
## and the place cannot disagree about what is in the Hold - they are the same
## buttons, read twice.
##
## **Always present, like the codex and unlike the stash.** An empty stable
## still says there is something to buy, and a Warden who has never seen the
## door has no way to learn that mounts exist at all.
func _build_stable_button() -> void:
	if new_run_button == null:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	var button := Button.new()
	button.name = "Stable"
	button.text = _stable_label()
	button.custom_minimum_size = settings_button.custom_minimum_size
	button.theme_type_variation = settings_button.theme_type_variation
	IconKit.on_button(button, "distance", 24)
	column.add_child(button)
	column.move_child(button, settings_button.get_index())

	_stable = StableScreen.new()
	add_child(_stable)
	_stable.closed.connect(func() -> void:
		button.text = _stable_label()
		_focus_home())
	button.pressed.connect(func() -> void: _stable.open())


## What the stable door says. It names what is saddled, because that is the
## one fact about the stable a player wants before opening it - the same
## reasoning the Ledger's door counts standing orders.
func _stable_label() -> String:
	var kind: MountData = MetaState.saddled_mount()
	if kind == null:
		return "The Stable"
	return "The Stable  ·  %s" % kind.display_name


## The pen, beside the codex.
##
## Always present, like the codex and unlike the stash: an empty pen still says
## what there is to raise, and "carry an egg home" is a thing a player has to be
## told once somewhere.
func _build_pen_button() -> void:
	if new_run_button == null:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	var button := Button.new()
	button.name = "Pen"
	button.text = _pen_label()
	button.custom_minimum_size = settings_button.custom_minimum_size
	button.theme_type_variation = settings_button.theme_type_variation
	IconKit.on_button(button, "spirit", 24)
	column.add_child(button)
	column.move_child(button, settings_button.get_index())

	_pen = PenScreenScript.new()
	add_child(_pen)
	button.pressed.connect(func() -> void:
		_pen.call("open"))
	_pen.visibility_changed.connect(func() -> void:
		if not _pen.visible:
			button.text = _pen_label()
			button.grab_focus())


## **A road that begins further along.**
##
## Offered only once a second act has actually been reached: a door promising
## every act you have reached, shown to somebody who has reached one, is a door
## that does nothing.
func _build_act_start_button() -> void:
	if new_run_button == null or ActStart.furthest_act() <= 1:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	var button := Button.new()
	button.name = "ActStart"
	button.text = "Start at an act \u00b7 up to Act %d" % ActStart.furthest_act()
	button.tooltip_text = ("A new road beginning at an act you have reached, "
		+ "outfitted on a doctrine of your choosing. Your banked front is not "
		+ "touched.")
	button.custom_minimum_size = new_run_button.custom_minimum_size
	button.theme_type_variation = settings_button.theme_type_variation
	IconKit.on_button(button, "pressure_arrow", 24)
	column.add_child(button)
	column.move_child(button, new_run_button.get_index() + 1)

	_act_start = ActStartScreenScript.new()
	add_child(_act_start)
	# **The Hold takes the road through this same screen**, rather than the
	# three buttons of its own it used to carry - which passed no doctrine at
	# all, so `ActStart.begin` refused and the run opened at Act I however
	# high an act was chosen (owner, 2026-09-22). One screen, two callers.
	if _hub != null:
		_hub.act_start = _act_start
	button.pressed.connect(func() -> void:
		# The same cost and the same question: an act start is a new road, so
		# it gives up the banked one exactly as a fresh run does.
		if not _arm(button, "Give up the front? · press again"):
			return
		_disarm()
		_act_start.call("open"))
	_act_start.visibility_changed.connect(func() -> void:
		if not _act_start.visible:
			button.grab_focus())


## The Wardens, on the front door rather than in the Hold.
##
## **Every other account door moved into the Hold** and this one deliberately
## did not. The Hold is a room *this* Warden owns - their stash, their pen,
## their forge - so choosing which Warden to be from inside it is the wrong way
## round, and a player whose slot is not the one they meant would have to walk
## into somebody else's room to leave it.
##
## Always present, even on an account that has only ever had one. A picker that
## appeared once a second save existed would be a feature nobody could find the
## first time, because finding it is what makes the second one.
func _build_slot_button() -> void:
	if new_run_button == null:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	var button := Button.new()
	button.name = "Wardens"
	button.text = _slot_label()
	button.tooltip_text = ("Several Wardens on one machine, each with their own "
		+ "level, gear and banked road. Only between roads.")
	button.custom_minimum_size = settings_button.custom_minimum_size
	button.theme_type_variation = settings_button.theme_type_variation
	IconKit.on_button(button, "spirit", 24)
	column.add_child(button)
	column.move_child(button, settings_button.get_index())

	_slots = SaveSlotScreenScript.new()
	_slots.name = "Wardens"
	add_child(_slots)
	button.pressed.connect(func() -> void: _slots.open())
	_slots.visibility_changed.connect(func() -> void:
		if not _slots.visible:
			button.text = _slot_label()
			button.grab_focus())
	# **The whole front door is built again when the Warden changes**, rather
	# than each label being patched: the statistics, the stable, the pen and
	# the resume card are all a different account's now, and *which buttons
	# exist* moves too - see `GameDirector.reopen_the_menu`. `MetaState` says
	# when, so nothing has to remember to ask.
	#
	# **A named method, never a lambda.** `MetaState` is an autoload and
	# outlives this scene, and a lambda's connection belongs to no object Godot
	# can drop - so every later switch would fire on a freed capture and print
	# "Lambda capture at index 0 was freed". Guarding inside the lambda does not
	# help; the engine complains at the call, before the body runs. Three scopes
	# in this project shipped that exact fault following `DayNight`.
	MetaState.slot_changed.connect(_on_slot_changed)


## A slot change rebuilds the front door rather than patching it - see
## `GameDirector.reopen_the_menu` for why a label refresh is not enough.
func _on_slot_changed(_index: int) -> void:
	GameDirector.reopen_the_menu()


## What the door says: which Warden, because that is the one fact a player
## wants before opening it - the same reasoning the stable's door names what is
## saddled and the Ledger's counts standing orders.
func _slot_label() -> String:
	var summary: Dictionary = MetaState.slot_summary(MetaState.slot())
	var named: String = String(summary.get("name", "")).strip_edges()
	if named.is_empty():
		return "Wardens  ·  %d of %d" % [MetaState.slot() + 1, Balance.SAVE_SLOTS]
	return "Wardens  ·  %s" % named


## The Warden's own line, bottom centre. One function because the line is read
## twice - once when it is built and again when the Warden changes - and two
## copies of it would drift the first time either was edited.
func _warden_line() -> String:
	var line: String = "%s  ·  level %d" % [MetaState.warden_title(),
		MetaState.hero_level]
	if MetaState.hero_attribute_points > 0:
		line += "  ·  %d unspent" % MetaState.hero_attribute_points
	return line


## "Pen · 3 / 12", so the cap is visible before the screen is opened - a full
## pen is a decision and the door should say so.
func _pen_label() -> String:
	return "Pen · %d / %d" % [MetaState.pen.size(), Balance.PEN_CAPACITY]


## "Codex · 14 / 38", counted across every section the screen shows.
func _codex_label() -> String:
	var met: int = 0
	var total: int = 0
	for section: Dictionary in CodexScreenScript.SECTIONS:
		var table: Dictionary = ContentDB.get(String(section["source"]))
		total += table.size()
		met += MetaState.seen_count(String(section["kind"]))
	return "Codex  ·  %d / %d" % [met, total]


func _build_chronicle_button() -> void:
	if new_run_button == null:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	var button := Button.new()
	button.name = "Chronicle"
	button.text = "Chronicle  ·  %d / %d" % [MetaState.chronicle_completed_count(),
		ContentDB.chronicle_objectives.size()]
	button.custom_minimum_size = settings_button.custom_minimum_size
	button.theme_type_variation = settings_button.theme_type_variation
	IconKit.on_button(button, "chainbreaker_seal", 24)
	column.add_child(button)
	column.move_child(button, settings_button.get_index())

	_chronicle = ChronicleScreenScript.new()
	add_child(_chronicle)
	(_chronicle as ChronicleScreenScript).closed.connect(func() -> void:
		button.text = "Chronicle  ·  %d / %d" % [MetaState.chronicle_completed_count(),
			ContentDB.chronicle_objectives.size()]
		button.grab_focus())
	button.pressed.connect(func() -> void: _chronicle.open())


## **The Walk** (owner brief, 2026-09-17): the guided valley.
##
## Offered on the front door **only to an account that has never taken a**
## **road**, and that test is derived rather than stored: a flag defaulting
## false would send every existing account - the owner's at level 81 included
## - to the tutorial on the next launch. It sits above everything, because a
## player who has never played is the one person on this screen with no other
## correct press.
##
## It is always in the Hold as well, for anybody who wants it again. Both go
## through `start_walk`, never `start_run`, which is the whole reason the two
## doors exist - see `GameDirector.start_walk`.
func _build_walk_button() -> void:
	if new_run_button == null:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	_build_walk_door(column)
	if not TutorialGrants.should_offer():
		return
	var button := Button.new()
	button.name = "WalkValley"
	button.text = "Walk the valley"
	button.tooltip_text = ("One night in the last hold, west to east, learning what a Warden does - and it ends with the chain coming off.")
	button.custom_minimum_size = new_run_button.custom_minimum_size
	button.theme_type_variation = new_run_button.theme_type_variation
	IconKit.on_button(button, "distance", 26)
	column.add_child(button)
	column.move_child(button, new_run_button.get_index())
	button.pressed.connect(func() -> void: GameDirector.start_walk())


## The same valley, from the Hold, for ever. It grants nothing the second
## time - `TutorialGrants.award` is guarded - and it shows the instructions
## without the asides, because a player walking it again wants the rules and
## not the story a second time.
func _build_walk_door(column: Node) -> void:
	var door := Button.new()
	door.name = "WalkAgain"
	door.text = "Walk the valley again"
	IconKit.on_button(door, "distance", 24)
	column.add_child(door)
	door.pressed.connect(func() -> void: GameDirector.start_walk())


## **Back to the front.**
##
## Offered only when there is a banked frontier, and it sits above New run
## because a player with a campaign in progress almost always means to continue
## it - and starting a fresh one from this screen should be the deliberate press
## rather than the accidental one.
func _build_resume_button() -> void:
	if new_run_button == null or not MetaState.has_expedition():
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	var front: Dictionary = MetaState.expedition
	var standing: Vector2i = Expedition.fortifications(front)
	var button := Button.new()
	button.name = "Resume"
	button.text = "Resume · %s" % Expedition.describe(front)
	# **The wall is on the card too.** It was not, and `fortifications` counts
	# towers only - so the one thing a run is actually lost through was the one
	# thing a player could not see before resuming. It matters more since the
	# withdrawal (2026-09-16), which a wall can be worn by on the way out.
	var wall: float = Expedition.wall_share(front)
	button.tooltip_text = ("%d fortifications standing, %d of them damaged, the "
		+ "gate at %d%%. The road will be alive again; what you built will not "
		+ "have moved.") % [standing.x, standing.y, int(round(wall * 100.0))]
	button.custom_minimum_size = new_run_button.custom_minimum_size
	button.theme_type_variation = new_run_button.theme_type_variation
	IconKit.on_button(button, "distance", 26)
	column.add_child(button)
	column.move_child(button, new_run_button.get_index())
	button.pressed.connect(func() -> void:
		GameDirector.start_run(0, true))

	# **And the bill for what is broken out there**, offered only when something
	# is. A fortress that comes home damaged and cannot be mended would be a
	# fortress that only ever gets worse.
	# Asked of the bill rather than of the tower count - see
	# `Expedition.needs_mending`. A worn gate above a whole board is a front
	# that needs mending and could not be offered one.
	if Expedition.needs_mending(front):
		var mend := Button.new()
		mend.name = "Mend"
		mend.text = "Mend the front · %s" % Expedition.hurt_summary(front)
		mend.tooltip_text = _mend_bill_text()
		mend.custom_minimum_size = new_run_button.custom_minimum_size
		mend.theme_type_variation = settings_button.theme_type_variation
		# Timber unless there is no timber in it. A front whose board is whole
		# and whose gate is down is a Marks purchase, and a button wearing a
		# log for it says the wrong currency before the tooltip says the right
		# one - which is the case that had no button at all until 2026-09-22.
		IconKit.on_button(mend, "wood" if not Expedition.repair_bill(front).is_empty()
			else "marks", 24)
		column.add_child(mend)
		column.move_child(mend, button.get_index() + 1)
		mend.pressed.connect(func() -> void:
			var refused: String = MetaState.mend_expedition()
			if refused.is_empty():
				mend.queue_free()
				button.tooltip_text = "The front stands whole."
			else:
				mend.text = refused)
	# The fresh run says what it costs, because it is the one press here that
	# throws away a campaign - and since 2026-09-17 it really does throw it
	# away rather than leaving it banked, so it asks first.
	new_run_button.tooltip_text = ("A new expedition from Act I. This gives up "
		+ "the front you have banked.")
	button.grab_focus()


## What mending the front would cost, written out. Read off the same two
## functions the purchase spends, so the tooltip and the till cannot disagree -
## and off `Expedition` rather than written out here, because the Hold offers
## the same purchase and two copies of a price is how one of them goes stale.
func _mend_bill_text() -> String:
	return Expedition.bill_text(MetaState.expedition)


## **The press that gives up a campaign asks once.**
##
## A banked front is hours of road, and taking a fresh one now clears it
## (owner ruling, 2026-09-17), so the button arms rather than fires: the first
## press says what it is about to cost and the second does it. A two-press
## button rather than a dialog because the menu has no confirmation component
## and one press away from the answer is the whole requirement - a modal would
## be a new screen to lay out, theme and test on a phone for one question.
##
## Disarmed by leaving the button, so a press, a change of mind and a press on
## something else later cannot add up to a lost campaign.
var _armed: Button = null


func _arm(button: Button, cost: String) -> bool:
	if not MetaState.has_expedition():
		return true
	if _armed == button:
		return true
	_disarm()
	_armed = button
	button.set_meta("label", button.text)
	button.text = cost
	if not button.mouse_exited.is_connected(_disarm):
		button.mouse_exited.connect(_disarm)
		button.focus_exited.connect(_disarm)
	return false


func _disarm() -> void:
	if _armed == null or not is_instance_valid(_armed):
		_armed = null
		return
	if _armed.has_meta("label"):
		_armed.text = String(_armed.get_meta("label"))
	_armed = null


func _start_run() -> void:
	if not _arm(new_run_button, "Give up the front? · press again"):
		return
	_disarm()
	var requested: int = 0
	var entered: String = seed_input.text.strip_edges()
	if not entered.is_empty():
		if not entered.is_valid_int() or int(entered) <= 0:
			seed_input.text = ""
			seed_input.placeholder_text = "Use 1–999999999"
			seed_input.grab_focus()
			return
		requested = clampi(int(entered), 1, RunState.RNG_MAX_SEED)
	GameDirector.start_run(requested)


## The panel is the shared component, centred over the key art. The menu used to
## hand-roll its own settings box in the scene file, which is how it ended up
## offering exactly one setting while three volume sliders sat unreachable in the
## save file.
func _build_settings() -> void:
	_settings = SettingsPanel.new()
	_settings.set_anchors_preset(Control.PRESET_CENTER)
	_settings.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_settings.grow_vertical = Control.GROW_DIRECTION_BOTH
	_settings.visible = false
	_settings.closed.connect(func() -> void: _show_settings(false))
	add_child(_settings)


func _show_settings(showing: bool) -> void:
	_settings.visible = showing
	if not showing:
		settings_button.grab_focus()


func _summary() -> String:
	return "\n".join([
		"Runs   %d started   ·   %d reached the sanctuary" % [MetaState.runs_started, MetaState.runs_won],
		"Furthest   %d of %d" % [int(MetaState.best_distance), int(Balance.JOURNEY_TOTAL_DISTANCE)],
		"Unlocked   %d towers   ·   %d relics   ·   %d lands" % [
			MetaState.unlocked_towers.size(),
			MetaState.unlocked_relics.size(),
			MetaState.unlocked_terrains.size()],
		"Chronicle   %d of %d deeds kept" % [MetaState.chronicle_completed_count(),
			ContentDB.chronicle_objectives.size()],
	])


# --- The build, and the seed row's fade (2026-09-12) --------------------------------

## Which build this is, top right. A development build says so.
func _build_version_label() -> void:
	_version_label = Label.new()
	_version_label.name = "Version"
	_version_label.text = ("v" + BuildInfo.VERSION.trim_prefix("v")) if BuildInfo.is_release() \
		else "dev build"
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_version_label.add_theme_font_size_override("font_size", 14)
	_version_label.add_theme_color_override("font_color", Color("9a927e"))
	_version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_version_label)


## The seed row sits above "Take the road", faded until it is wanted: hovered,
## focused, or holding a seed. A row most players never use should not be the
## brightest thing in the column.
func _dress_seed_row() -> void:
	if seed_input == null:
		return
	var row: Control = seed_input.get_parent() as Control
	if row == null:
		return
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for node: Control in [row, seed_input]:
		node.mouse_entered.connect(_on_seed_hover.bind(true))
		node.mouse_exited.connect(_on_seed_hover.bind(false))
	seed_input.focus_entered.connect(_refresh_seed_fade)
	seed_input.focus_exited.connect(_refresh_seed_fade)
	seed_input.text_changed.connect(func(_value: String) -> void: _refresh_seed_fade())
	row.modulate.a = Balance.MENU_SEED_FADE
	_refresh_seed_fade()


func _on_seed_hover(over: bool) -> void:
	_seed_hovered = over
	_refresh_seed_fade()


func _refresh_seed_fade() -> void:
	var row: Control = seed_input.get_parent() as Control
	if row == null:
		return
	var lit: bool = _seed_hovered or seed_input.has_focus() \
		or not seed_input.text.strip_edges().is_empty()
	if _seed_tween != null and _seed_tween.is_valid():
		_seed_tween.kill()
	_seed_tween = create_tween()
	_seed_tween.tween_property(row, "modulate:a", 1.0 if lit else Balance.MENU_SEED_FADE, 0.18)


## The wordmark, lit from inside.
##
## Owner brief, 2026-09-14: the title should read as holographic. The obvious
## reading of that word - scanlines and a cyan tint - would put a
## science-fiction interface on the front of a grimdark fantasy game, so what
## `title_hologram.gdshader` takes from a hologram is its *behaviour*: a sheen
## that travels the letters, a rim that refracts, a slow instability. The
## colours stay the wordmark's own. Gold leaf catching a moving light, not a
## computer.
##
## Skipped headless, where the dummy renderer cannot compile a shader and says
## so as an error the sweep reads as a failure.
func _light_the_title() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var title := get_node_or_null("Title") as TextureRect
	if title == null:
		return
	var paint := ShaderMaterial.new()
	paint.shader = load("res://scripts/shaders/title_hologram.gdshader")
	paint.set_shader_parameter("strength", Balance.MENU_TITLE_SHEEN)
	paint.set_shader_parameter("sheen_width", Balance.MENU_TITLE_SHEEN_WIDTH)
	paint.set_shader_parameter("split", Balance.MENU_TITLE_SPLIT)
	title.material = paint
	_title_paint = paint


## **Little arcs off the wordmark** (owner, 2026-09-15: "make little lightning
## arcs procedurally spark off of the title text art").
##
## The anchors are read off the wordmark's *own silhouette* rather than scattered
## over its box: a bolt that starts in the empty space inside the D is a bolt
## that came from nowhere. Every few rows of the painting, the leftmost and
## rightmost opaque pixel are taken, which traces the outside of the lettering,
## and `MenuArcs` joins pairs of those that are near enough to each other - so
## the sparks run along the letters rather than across the word.
##
## Skipped headless: it is a decoration with a texture read in it, and the sweep
## has nothing to look at.
func _spark_the_title() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var title := get_node_or_null("Title") as TextureRect
	if title == null or title.texture == null:
		return
	_title_arcs = MenuArcs.new()
	_title_arcs.name = "TitleArcs"
	_title_arcs.spark_every = Balance.MENU_ARC_TITLE_EVERY
	_title_arcs.weight = 2.0
	_title_arcs.colour = Color(1.0, 0.86, 0.55, 1.0)
	title.add_child(_title_arcs)
	_title_arcs.anchors = _edge_of(title)


## Points around the outside of a wordmark, in the control's own space.
func _edge_of(title: TextureRect) -> PackedVector2Array:
	var found := PackedVector2Array()
	var image: Image = title.texture.get_image()
	if image == null or image.is_empty():
		return found
	var wide: float = title.size.x / maxf(float(image.get_width()), 1.0)
	var tall: float = title.size.y / maxf(float(image.get_height()), 1.0)
	var step: int = maxi(image.get_height() / 18, 1)
	for y: int in range(0, image.get_height(), step):
		var left: int = -1
		var right: int = -1
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.4:
				if left < 0:
					left = x
				right = x
		if left < 0:
			continue
		found.append(Vector2(float(left) * wide, float(y) * tall))
		found.append(Vector2(float(right) * wide, float(y) * tall))
	return found


func _process(delta: float) -> void:
	# **Before the title's own guard**, because the two are unrelated: a menu
	# whose wordmark shader failed to load should still have a living interface.
	_shimmer_left -= delta
	if _shimmer_left <= 0.0:
		_shimmer_left = _shimmer_dice.randf_range(
			Balance.UI_HOLO_IDLE_EVERY.x, Balance.UI_HOLO_IDLE_EVERY.y)
		UiJuice.idle_shimmer(get_tree(), _shimmer_dice)
	if _title_paint == null:
		return
	# Fed from here rather than read from `TIME` in the shader, so the sheen
	# stops with the menu instead of running while a dialog is over it.
	_title_clock += delta
	_title_paint.set_shader_parameter("clock", _title_clock)


## Grades the menu's buttons to the menu's own sky.
##
## Owner brief, 2026-09-14. The buttons were cold grey against a warm orange
## scene, which reads as an interface pasted over a painting rather than one
## belonging to it.
##
## Every button and panel joins `UiTint.GROUP` and is then painted from the
## backdrop's own colour, so the menu grades itself to whatever act's art it is
## showing. Frames only: `UiTint` moves `StyleBoxTexture.modulate_color` and
## never a font, so nothing here can make a word harder to read.
func _grade_the_interface() -> void:
	if DisplayServer.get_name() == "headless":
		return
	UiTint.enrol(get_tree(), self)
	UiTint.apply(get_tree(), _menu_light(), true)
	# The holograms are lit by the same light the frames are graded to, so the
	# two can never disagree about what the scene is lit by.
	UiJuice.enrol(get_tree(), self)
	UiJuice.set_glow(get_tree(), _menu_light())



## The menu's own light, taken off the stage rather than from the day cycle.
##
## The main menu is not standing in an act - it has no terrain and no hour - so
## asking `UiTint.for_the_world` here would grade it to whatever run was loaded
## last. The backdrop is the only honest source.
func _menu_light() -> Color:
	# **Found by what it can do, not by what it is called.** The stage node is
	# named "Art" in the scene, and looking it up by a guessed name returned
	# null silently - so the menu graded itself to a hardcoded fallback and the
	# whole feature did nothing while appearing to work.
	var stage: Node = _stage_with_light(self)
	if stage != null:
		return stage.call("stage_light") as Color
	return Color(1.0, 0.92, 0.82)


## The first descendant that can report the stage's light.
func _stage_with_light(from: Node) -> Node:
	for child: Node in from.get_children():
		if child.has_method("stage_light"):
			return child
		var deeper: Node = _stage_with_light(child)
		if deeper != null:
			return deeper
	return null
