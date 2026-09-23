extends Node

## The two right-hand sheets: the build sheet and the road sheet.
##
##   godot --headless --path game res://tools/road_sheet_check.tscn -- --viewport=1920x1080
##
## **`layout_check` opens the build sheet and has never opened the road sheet**,
## which is the whole reason the owner found the trap menu growing through the
## spirit readout on 2026-09-22 while every layout gate was green. A sheet that
## is never opened is a sheet nothing measures, and this one had no fit function
## at all: it hung from the bottom right, grew upward with the rows in it, and
## had no ceiling to stop at.
##
## Five properties, and every one of them fails in silence.
##
## **The sheets stay under the right column's floor.** The floor is the lowest
## edge of the spirit readout - the panel with the Call button in it - and the
## sheets grow up toward it. Nothing errors when one passes it; the two simply
## draw over each other and the button underneath stops taking clicks, because
## a `PanelContainer` is `MOUSE_FILTER_STOP`.
##
## **Every offer carries its figures.** `_add_road_row` takes the picture and
## the figures as optional arguments, and the barricade loop passed neither - so
## the two walls had a bare sentence where the traps beside them had a picture
## and five lines of numbers. An argument that defaults to empty is the kind of
## omission no type checker and no layout measurement can see.
##
## **The list scrolls and the chrome does not.** A sheet too short for its
## contents must scroll them rather than grow past the screen, and the Close
## button must not be one of the things that scrolls away.
##
## **A reshape re-lays them.** Both sheets are placed from the viewport's shape
## and the column's floor, and the road sheet was placed once: three functions
## re-fitted the build sheet on a resize and none of them named the road sheet.
##
## **The command panel is on screen.** It is here rather than in `layout_check`
## because it is the same question the sheets ask - what does a sheet in that
## corner have to clear - and because `layout_check` cannot see this one: it
## ignores a widget *entirely* outside the viewport, on the reasonable grounds
## that it is usually a panel waiting to slide in.
##
## Runs headless. What is measured is the sheets' own rectangles and their
## children's, which a headless viewport lays out perfectly well once the
## window has been given a size.

const SEED: int = 606060601

## The least the road sheet may offer.
##
## The owner asked for *"1 more option to total 10"* on 2026-09-22, and eight
## traps plus the two barricades are those ten. A floor rather than an exact
## count, because an eleventh is content and not a regression - but a floor is
## needed at all, because everything else here counts the rows against what
## `ContentDB` loaded, and a trap whose resource silently failed to load makes
## those two agree with each other and both be wrong.
const ROAD_OFFERS_MIN: int = 10

## A spirit is equipped so the readout is on screen, because the floor the
## sheets stop at is the readout's lower edge. On a clean profile the panel is
## invisible, the floor collapses to the scope bar's own top, and both sheets
## measure clear however far they grow - `ci-profile-hides-state-dependent-ui`,
## in the one corner where it costs most.
const SPIRIT: String = "fox:0"

var _failures: int = 0
var _checks: int = 0
var _notes: PackedStringArray = []
var _run: Node = null
var _hud: HUD = null
var _field: Battlefield = null
var _touch: bool = false
var _window: Vector2i = Vector2i(1920, 1080)
## How many towers the element the build sheet is showing holds.
var _element_showing: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	MetaState.equipped_spirit = SPIRIT
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--touch=on":
			_touch = true
		elif argument.begins_with("--viewport="):
			var parts: PackedStringArray = argument.trim_prefix("--viewport=").split("x")
			if parts.size() == 2:
				_window = Vector2i(parts[0].to_int(), parts[1].to_int())
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = _window
	if _touch:
		MetaState.settings[TouchInput.TOUCH_KEY] = true
		# Before the run is built, not after: the HUD reads the touch state
		# while constructing and decides there how many rows the action bar is.
		TouchInput.refresh()
		ScreenFit._fit()

	RunState.reset(false, SEED)
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	_hud = _run.get("hud") as HUD
	_field = _run.get("battlefield") as Battlefield
	if _hud == null or _field == null:
		printerr("[road-sheet] the harness needs a HUD and a battlefield")
		get_tree().quit(1)
		return
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.gain_every_currency(9999)
	# **Every tower unlocked, for the same reason a spirit is equipped.** A new
	# account has two towers an element and a sheet fits two of anything, so on
	# a clean profile this gate would report a list that fits comfortably while
	# a played account scrolled one it could not reach the bottom of.
	for tower: TowerData in ContentDB.base_towers():
		if not MetaState.unlocked_towers.has(tower.id):
			MetaState.unlocked_towers.append(tower.id)
	for _f: int in 4:
		await get_tree().process_frame
	_notes.append("viewport %dx%d%s  ·  %d towers unlocked" % [_window.x,
		_window.y, "  touch" if _touch else "",
		ContentDB.unlocked_base_towers().size()])

	await _test_the_road_sheet_lists_everything()
	await _test_the_road_sheet_clears_the_right_column()
	await _test_every_offer_says_what_it_does()
	await _test_the_build_sheet_fits_or_scrolls()
	await _test_close_is_reachable()
	await _test_a_reshape_re_lays_both_sheets()
	await _test_the_command_panel_is_on_screen()

	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	_run = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	for note: String in _notes:
		print("[road-sheet] %s" % note)
	print("[road-sheet] %s - %d checks" % [
		"PASS" if _failures == 0 else "FAIL", _checks])
	get_tree().quit(_failures)


## Everything that can go on a road is offered, and the count is the content's.
##
## Read from `ContentDB` rather than written down, so the day a ninth trap is
## authored this asks for nine without anybody editing the gate - and the day
## one silently fails to load, this is what says so.
func _test_the_road_sheet_lists_everything() -> void:
	await _open_road_sheet()
	var want: int = ContentDB.trap_kinds().size() + _barricades().size()
	var rows: Array[Button] = _rows_of(_hud.get("_road_list") as Control)
	_check(rows.size() == want,
		"the road sheet must offer every trap and every barricade: %d rows for "
			% rows.size() + "%d kinds" % want)
	_check(rows.size() >= ROAD_OFFERS_MIN,
		"the road sheet offers %d things and the owner asked for %d: a trap "
			% [rows.size(), ROAD_OFFERS_MIN]
			+ "whose resource failed to load leaves every other count here "
			+ "agreeing with itself and wrong")
	_notes.append("road sheet: %d rows (%d traps, %d barricades)" % [rows.size(),
		ContentDB.trap_kinds().size(), _barricades().size()])


## The sheet grows upward, and what is above it is the Call button.
func _test_the_road_sheet_clears_the_right_column() -> void:
	await _open_road_sheet()
	var panel: Control = _hud.get("_road_panel") as Control
	var spirit: Control = _hud.get("_spirit_panel") as Control
	_check(spirit != null and spirit.visible,
		"the harness needs the spirit readout on screen, or the floor being "
			+ "measured is not the floor a player has")
	var rect: Rect2 = panel.get_global_rect()
	var floor_at: float = _hud.call("_right_column_floor")
	_notes.append("road sheet at %.0f,%.0f  %.0fx%.0f  ·  column floor %.0f"
		% [rect.position.x, rect.position.y, rect.size.x, rect.size.y, floor_at])
	_check(rect.position.y >= floor_at,
		"the road sheet's top edge is at %.0f and the right column's floor is "
			% rect.position.y + "%.0f: it has grown up behind the spirit "
			% floor_at + "readout, whose Call button then stops taking clicks")
	if spirit != null and spirit.visible:
		var over: Rect2 = spirit.get_global_rect()
		_check(not rect.intersects(over),
			"the road sheet covers the spirit readout: sheet %s over %s"
				% [rect, over])
		# The floor already carries `SPIRIT_PANEL_GAP`; the sheet keeps its own
		# air on top of that, or the two read as one crowded mass and the
		# layout gate's panel-gap check fires on them.
		var gap: float = rect.position.y - over.end.y
		_check(gap >= HUD.RIGHT_SHEET_GAP,
			"the road sheet sits %.0f under the spirit readout, wanted %.0f"
				% [gap, HUD.RIGHT_SHEET_GAP])
	_check_on_screen(panel, "the road sheet")
	_hud.call("_close_road_panel")
	await get_tree().process_frame


## Every offer on both sheets has a picture and figures behind it.
##
## Driven through the row's own `mouse_entered`, which is the signal a cursor
## fires, rather than by calling `_trap_tooltip` - a figures builder that works
## and a row that never calls it is exactly the shape of the fault this is here
## for. `_barricade_tooltip` did not exist and `_trap_tooltip` was perfect.
func _test_every_offer_says_what_it_does() -> void:
	await _open_road_sheet()
	await _hover_every_row(_hud.get("_road_list") as Control, "road sheet",
		_road_art_owed())
	_hud.call("_close_road_panel")
	await get_tree().process_frame

	await _open_build_sheet()
	await _hover_every_row(_hud.get("_build_list") as Control, "build sheet",
		_tower_art_owed())
	_hud.call("_close_build_panel")
	await get_tree().process_frame


## How many offers on the road sheet have no art on disk yet.
##
## Zero, and `trap_check` already refuses a trap without a sprite - but
## counted rather than assumed, for the same reason the row count is.
func _road_art_owed() -> int:
	var owed: int = 0
	for trap: TrapData in ContentDB.trap_kinds():
		if not ResourceLoader.exists(trap.get_sprite_path()):
			owed += 1
	for value: Variant in _barricades():
		var wall := value as BarricadeData
		if not ResourceLoader.exists(wall.get_sprite_path()):
			owed += 1
	return owed


## How many towers on the build sheet have no art on disk yet.
##
## **An allowance rather than an exemption.** A row that shows no picture is a
## fault when the picture exists and the row does not pass it - which is the
## barricade fault - and it is the asset manifest's business when the file is
## simply not drawn yet. A tower authored this morning with its art still
## generating would otherwise turn this gate red for work that belongs to
## somebody else's change, and a gate that is red for a reason the reader
## cannot act on is a gate people stop reading. Counted from disk, so the
## allowance shrinks to nothing on its own the day the art lands.
func _tower_art_owed() -> int:
	var owed: int = 0
	for tower: TowerData in ContentDB.unlocked_base_towers():
		if not ResourceLoader.exists(tower.get_sprite_path()):
			owed += 1
	return owed


func _hover_every_row(list: Control, which: String, art_owed: int) -> void:
	var label: Label = _hud.get("_build_tooltip_label") as Label
	var picture: TextureRect = _hud.get("_build_tooltip_picture") as TextureRect
	var box: Control = _hud.get("_build_tooltip") as Control
	var offers: int = 0
	var bare: int = 0
	for row: Button in _rows_of(list):
		if not row.mouse_entered.has_connections():
			continue
		# **Wiped before every hover.** Otherwise the last row's figures are
		# still in the box and the next row reads as explained by them: the
		# first cut of this check reported four element-rail buttons as bare
		# and quoted a *barricade's* numbers at them. A reading taken without
		# clearing what it measures is the same fault one layer up.
		_hud.call("_hide_build_tooltip")
		if label != null:
			label.text = ""
		await get_tree().process_frame
		row.mouse_entered.emit()
		await get_tree().process_frame
		var text: String = label.text if label != null else ""
		# **A row that opens the figures box is an offer; one that does not is
		# navigation.** The element rail's four picks are buttons on the build
		# sheet that buy nothing - they open an element - and they carry their
		# own `tooltip_text`. Demanding figures of one would be demanding a
		# price of a folder. What is not allowed is a row that explains itself
		# nowhere at all.
		if box == null or not box.visible:
			_check(not row.tooltip_text.strip_edges().is_empty(),
				"%s: the row %s says nothing on hover - no figures box and no "
					% [which, _quoted(row.text)] + "tooltip either")
			row.mouse_exited.emit()
			await get_tree().process_frame
			continue
		offers += 1
		# Every figures builder in the HUD ends with the price, and a bare
		# description carries no line break. Both tells, because the fault this
		# exists for produced exactly a one-line description.
		var has_figures: bool = text.contains("Cost:") and text.contains(_break())
		if not has_figures:
			bare += 1
			_check(false, "%s: the offer %s opens its figures box with no "
				% [which, _quoted(row.text)] + "figures in it - it says only %s"
				% _quoted(text.replace(_break(), " / ")))
		elif picture != null and not picture.visible:
			# Counted rather than failed on the spot: the summary decides,
			# against how many of these offers are owed art. See
			# `_tower_art_owed`.
			bare += 1
			_notes.append("%s: %s shows no picture" % [which, _quoted(row.text)])
		else:
			_check(true, "")
		row.mouse_exited.emit()
		await get_tree().process_frame
	_notes.append("%s: %d offers hovered, %d without a picture, %d owed art"
		% [which, offers, bare, art_owed])
	_check(offers > 0, "%s: no offers at all, so nothing was measured" % which)
	_check(bare <= art_owed,
		"%s: %d offers show no picture and only %d are owed art - the rest are "
			% [which, bare, art_owed] + "rows that were never given one")


## The build sheet either fits or scrolls, and never grows past the column.
func _test_the_build_sheet_fits_or_scrolls() -> void:
	await _open_build_sheet()
	var panel: Control = _hud.get("_build_panel") as Control
	var scroll: ScrollContainer = _hud.get("_build_scroll") as ScrollContainer
	var column: Control = _hud.get("_build_column") as Control
	var rect: Rect2 = panel.get_global_rect()
	var floor_at: float = _hud.call("_right_column_floor")
	var wanted: float = column.get_combined_minimum_size().y
	var room: float = scroll.size.y
	_notes.append("build sheet at %.0f,%.0f  %.0fx%.0f  ·  %d rows want %.0f of "
		% [rect.position.x, rect.position.y, rect.size.x, rect.size.y,
			_rows_of(_hud.get("_build_list") as Control).size(), wanted]
		+ "%.0f  ·  column floor %.0f" % [room, floor_at])
	_check(rect.position.y >= floor_at,
		"the build sheet's top edge is at %.0f against a floor of %.0f"
			% [rect.position.y, floor_at])
	_check_on_screen(panel, "the build sheet")
	# **Fits, or scrolls.** A list taller than its room and a scrollbar that
	# cannot move is a list with rows nobody can reach - which is what a sheet
	# with no ceiling turns into the day it is given one.
	if wanted > room + 1.0:
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		_check(bar != null and bar.max_value - bar.page > 1.0,
			"the build sheet's list wants %.0f of %.0f and cannot be scrolled"
				% [wanted, room])
	else:
		_check(true, "")
	_hud.call("_close_build_panel")
	await get_tree().process_frame


## The way out of a sheet is always reachable, and fixed wherever it fits.
##
## **Two seatings, and both are correct somewhere.** Outside the scroll is what
## a sheet wants: a close control the player has to scroll a list to reach is
## the one control on a panel that must always be under the cursor. But a
## thumb-sized button is 120 units and a landscape phone leaves a sheet about
## 185, with the spirit readout owning the top of that screen and the combat
## row the bottom - so there the button scrolls, at the end of the list, which
## is what it did on every shape before this. What is never allowed is a Close
## button that cannot be got to at all.
func _test_close_is_reachable() -> void:
	await _open_road_sheet()
	_check_close(_hud.get("_road_panel") as Control,
		_hud.get("_road_scroll") as ScrollContainer,
		_hud.get("_road_column") as Control, "the road sheet")
	_hud.call("_close_road_panel")
	await get_tree().process_frame

	await _open_build_sheet()
	_check_close(_hud.get("_build_panel") as Control,
		_hud.get("_build_scroll") as ScrollContainer,
		_hud.get("_build_column") as Control, "the build sheet")
	_hud.call("_close_build_panel")
	await get_tree().process_frame


func _check_close(panel: Control, scroll: ScrollContainer, column: Control,
		which: String) -> void:
	var close: Button = null
	for node: Node in _all(panel):
		var button := node as Button
		if button != null and button.text.strip_edges() == "Close":
			close = button
	if close == null:
		_check(false, "%s has no Close button" % which)
		return
	var scrolled: bool = scroll != null and scroll.is_ancestor_of(close)
	_notes.append("%s: Close is %s" % [which,
		"inside the scroll, at the end of the list" if scrolled
			else "fixed under the list"])
	if scrolled:
		# Reachable means at the end of the list rather than buried in it, and
		# a scroll that can actually be taken to the end.
		_check(close.get_parent() == column
			and column.get_child(column.get_child_count() - 1) == close,
			"%s scrolls its Close button and does not put it last, so it is "
				% which + "buried in the middle of the offers")
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		_check(bar != null and bar.max_value - bar.page > -1.0,
			"%s scrolls its Close button and cannot be scrolled" % which)
	else:
		_check(panel.get_global_rect().encloses(close.get_global_rect()),
			"%s draws its fixed Close button outside its own frame" % which)
	# **And the fixed seating has to actually happen somewhere**, or a rule
	# that always takes the same branch is a rule nothing is testing. A desktop
	# screen has room for the chrome by a wide margin; this says so about the
	# shape the gate was given rather than by re-deriving the rule that decides
	# it, which would be a second copy of the thing under test.
	if not _touch and _window.y >= 900:
		_check(not scrolled,
			"%s scrolls its Close button on a %dx%d screen, which has room for "
				% [which, _window.x, _window.y] + "it several times over")


## Both sheets are re-laid when the window changes shape.
##
## The road sheet was not: `_refit_banners`, `_refit_right_column` and the touch
## pass each re-fitted the build sheet and none of them named the road sheet, so
## after a reshape its offsets described the window it had been opened in.
##
## **Turned on its side rather than merely made shorter**, and that is the
## difference between measuring something and measuring nothing. The project
## stretches `canvas_items`, so shrinking a window's height leaves the logical
## viewport exactly as tall and the sheet legitimately does not move - the first
## cut of this test read 737x560 before and after and called it a pass. Portrait
## is a shape the sheets answer differently on purpose: there is no column of
## screen beside the field, so a right-hand sheet goes across the bottom
## instead. A sheet that is still pinned to the right edge after that did not
## hear about it.
func _test_a_reshape_re_lays_both_sheets() -> void:
	await _open_road_sheet()
	var panel: Control = _hud.get("_road_panel") as Control
	var was: Rect2 = panel.get_global_rect()
	var wide: Vector2 = get_viewport().get_visible_rect().size
	get_window().size = Vector2i(mini(_window.x, _window.y),
		maxi(_window.x, _window.y))
	for _f: int in 12:
		await get_tree().process_frame
	var tall: Vector2 = get_viewport().get_visible_rect().size
	var now: Rect2 = panel.get_global_rect()
	var floor_at: float = _hud.call("_right_column_floor")
	_notes.append("upright: viewport %.0fx%.0f (was %.0fx%.0f)  ·  road sheet "
		% [tall.x, tall.y, wide.x, wide.y]
		+ "at %.0f,%.0f %.0fx%.0f (was at %.0f,%.0f %.0fx%.0f)"
		% [now.position.x, now.position.y, now.size.x, now.size.y,
			was.position.x, was.position.y, was.size.x, was.size.y])
	if tall.y <= tall.x:
		# Nothing to say: the window could not be made upright, which happens
		# when the two shapes this gate was given are already square-ish.
		_check(true, "")
	else:
		_check(now.position.x < tall.x * 0.5,
			"turned upright, the road sheet is still pinned to the right edge "
				+ "at x=%.0f of %.0f: nothing re-laid it" % [now.position.x, tall.x])
	_check(now.position.y >= floor_at,
		"after the reshape the road sheet's top edge is at %.0f against a "
			% now.position.y + "floor of %.0f" % floor_at)
	_check_on_screen(panel, "the road sheet after a reshape")
	_hud.call("_close_road_panel")
	get_window().size = _window
	for _f: int in 10:
		await get_tree().process_frame


## The panel the sheets' lift was derived from.
##
## `BUILD_PANEL_LIFT` spent its life described as *"the command panel's old
## bottom edge"*, and the command panel has been anchored top left since the day
## it moved out of the bottom right to make room for these sheets. It is checked
## here because the two are one question - what does a sheet in that corner have
## to clear - and because the panel was being sent 276 units above the top of
## the screen by two lines in the touch pass that still wrote the offsets it had
## in the other corner.
func _test_the_command_panel_is_on_screen() -> void:
	var panel: Control = _hud.get("_command_panel") as Control
	if panel == null:
		_check(false, "the HUD has no command panel")
		return
	# Shown in combat only, and only once Command has been earned this run
	# (owner, 2026-09-22: "hidden until the player has gained command").
	RunState.command_earned = 0.0
	RunState.command = 0.0
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	for _f: int in 8:
		await get_tree().process_frame
	_check(not panel.visible,
		"the command panel is shown before any Command has been earned")
	RunState.gain_command(10.0)
	for _f: int in 8:
		await get_tree().process_frame
	_check(panel.visible, "the command panel must be on screen once Command is earned")
	var rect: Rect2 = panel.get_global_rect()
	_notes.append("command panel at %.0f,%.0f  %.0fx%.0f"
		% [rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	_check_on_screen(panel, "the command panel")
	# **Below the second row, never over it** (owner, 2026-09-22): the quiver
	# readout and the sundial were drawn under the panel's frame. Every visible
	# readout in that row is measured, because it grows when the quiver appears.
	var row: Control = _hud.get("_journey_bar") as Control
	_check(row != null, "the HUD has no second row to hang the command panel beneath")
	if row != null:
		for child: Node in row.get_children():
			var readout := child as Control
			if readout == null or not readout.is_visible_in_tree():
				continue
			var theirs: Rect2 = readout.get_global_rect()
			_check(not rect.intersects(theirs),
				"the command panel %s overlaps %s at %s" % [rect, readout.name, theirs])
	RunState.set_phase(RunState.Phase.PREPARATION)
	for _f: int in 4:
		await get_tree().process_frame


# --- the harness ------------------------------------------------------------

## Opens the road sheet on a road tile with nothing standing on it, which is the
## state that lists every trap and every barricade at once.
func _open_road_sheet() -> void:
	_hud.call("_close_build_panel")
	_hud.call("_open_road_panel", _road_tile())
	for _f: int in 10:
		await get_tree().process_frame


## Opens the build sheet with the longest element list showing.
##
## **Pressed rather than set.** The sheet opens on the element rail with no
## element chosen, which is a list of four - and four of anything fits, so a
## gate that stopped there would measure the short case for ever. The element
## is chosen the way a player chooses one, through the rail's own button, so
## what is measured is the list the press actually produces.
func _open_build_sheet() -> void:
	_hud.call("_open_build_panel", _field.free_anchor_near(0))
	for _f: int in 8:
		await get_tree().process_frame
	var fullest: Button = null
	var most: int = -1
	for row: Button in _rows_of(_hud.get("_build_list") as Control):
		if not row.toggle_mode:
			continue
		# The rail writes the element's name and its count into the button.
		var count: int = row.text.split(" ")[-1].to_int()
		if count > most:
			most = count
			fullest = row
	# **Only if it is not already open.** The rail's picks are toggles, so a
	# second press on the element that is already showing closes it - and the
	# gate opens this sheet more than once. The first cut pressed regardless
	# and the second test measured the four-row rail with no element on it,
	# which fits any screen and proved nothing.
	if fullest != null and not fullest.button_pressed:
		fullest.pressed.emit()
		for _f: int in 8:
			await get_tree().process_frame
	_element_showing = most


func _road_tile() -> Vector2i:
	for radius: int in range(2, 40):
		for angle: int in range(0, 360, 15):
			var at := Vector2i(int(cos(deg_to_rad(angle)) * float(radius)),
				int(sin(deg_to_rad(angle)) * float(radius)))
			if _field.grid.cell_at(at) != BattleGrid.Cell.ROAD:
				continue
			if RunState.traps.has(at) or RunState.barricade_at(at) != null:
				continue
			return at
	_check(false, "the harness needs an empty road tile")
	return Vector2i.ZERO


func _barricades() -> Array:
	var out: Array = []
	for value: Variant in ContentDB.barricades.values():
		if value as BarricadeData != null:
			out.append(value)
	return out


## The pressable rows of a list, in order.
func _rows_of(list: Control) -> Array[Button]:
	var out: Array[Button] = []
	if list == null:
		return out
	for node: Node in _all(list):
		var button := node as Button
		if button != null and button.is_visible_in_tree():
			out.append(button)
	return out


func _check_on_screen(control: Control, which: String) -> void:
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var rect: Rect2 = control.get_global_rect()
	_check(screen.encloses(rect),
		"%s hangs off the screen: %s is not inside %s" % [which, rect, screen])


func _all(from: Node) -> Array[Node]:
	var out: Array[Node] = [from]
	for child: Node in from.get_children():
		out.append_array(_all(child))
	return out


## A quotation mark is awkward in a GDScript format string and a failure that
## cannot name the row it is about is a failure nobody can act on.
func _quoted(text: String) -> String:
	return "'%s'" % text.strip_edges()


## One line break, built rather than written, for the same reason.
func _break() -> String:
	return PackedByteArray([10]).get_string_from_ascii()


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	printerr("[road-sheet] %s" % why)
