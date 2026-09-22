extends Node

## The four things the owner asked for on 2026-09-22 about the breather.
##
##   godot --headless --path game res://tools/preparation_check.tscn
##
## **The grace.** A wave closes synchronously: the director closes it, the run
## opens the breather, and both `can_build_now()` and `GameDirector.build_mode`
## become true inside one frame. So the very next mouse release opened a build
## sheet, and a player still swinging at the last body got one they had not
## asked for. `RunState.arm_build_grace` holds the click path shut for a
## second, and the Preparation clock waits that second out rather than
## spending it - the owner's own reading, *"for 1 second after a wave ends
## before preparation starts counting"*.
##
## **The clock on the sheets.** A player deciding what to build is looking at
## the sheet, not at the card at the bottom of the screen. The bar is fed from
## the same signal the card is, and is hidden when there is no deadline at all
## - which is three of the four ways into Preparation.
##
## **The tooltip.** The box and the Preparation card are siblings on one
## CanvasLayer and the card is added later, so a box that lands on the card is
## drawn behind it and simply cannot be read. Nothing in the placing code ever
## knew the card existed.
##
## **The wells.** Three rather than one, each dearer than the last, and the
## row says which of the three this would be. The refusal has existed since
## 2026-09-13 and was only ever shown *after* the press.
##
## Every one of these fails silently. A grace that never arms is a sheet that
## opens a frame early; a bar fed nothing reads empty; a tooltip behind the
## card is a tooltip nobody reads; and a well row that takes the click and
## then refuses it looks like the game changing its mind.

const SEED: int = 771144
## A spirit, so the right column's floor is where a played account puts it.
const SPIRIT: String = "fox:0"

var _failures: int = 0
var _checks: int = 0
var _run: Node = null
var _hud: HUD = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	MetaState.equipped_spirit = SPIRIT
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1920, 1080)

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
		printerr("[preparation] the harness needs a HUD and a battlefield")
		get_tree().quit(1)
		return
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.gain_every_currency(999999)
	for tower: TowerData in ContentDB.base_towers():
		if not MetaState.unlocked_towers.has(tower.id):
			MetaState.unlocked_towers.append(tower.id)
	for _f: int in 4:
		await get_tree().process_frame

	await _test_the_grace_shuts_the_click_path()
	await _test_the_clock_waits_the_grace_out()
	_test_the_grace_is_not_can_build_now()
	await _test_both_sheets_carry_the_clock()
	await _test_the_clock_hides_when_there_is_no_deadline()
	await _test_the_tooltip_clears_the_preparation_card()
	_test_three_wells_and_each_dearer_than_the_last()
	await _test_the_well_row_says_how_many_stand()

	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	_run = null
	MetaState.resume_saves()
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	if _failures == 0:
		print("[preparation] PASS - %d checks: the grace, the clock, the tooltip and the wells"
			% _checks)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[preparation] " + why)


func _cursor() -> Node:
	for node: Node in _field.get_children():
		if node is PlacementCursor:
			return node
	for node: Node in get_tree().get_nodes_in_group(&"placement_cursor"):
		return node
	return _field.find_child("PlacementCursor", true, false)


# --- the grace ----------------------------------------------------------------

## **Armed by the wave's own door, and it shuts the one gate every sheet opens
## through.** Driven through `Run._enter_wave_breather` rather than by setting
## the stamp, because what is being checked is that the arming is wired: a
## test that armed it itself would pass on a build where nothing ever does.
func _test_the_grace_shuts_the_click_path() -> void:
	var cursor: Node = _cursor()
	_check(cursor != null, "the harness needs the placement cursor")
	if cursor == null:
		return
	RunState.build_grace_until_msec = 0
	RunState.set_phase(RunState.Phase.PREPARATION)
	GameDirector.set_build_mode(true)
	await get_tree().process_frame
	_check(bool(cursor.call("_is_active")),
		"with no grace running the cursor must be live in Preparation")

	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_run.set("_breather", false)
	_run.set("_breather_after_wave", 0)
	var opened: bool = bool(_run.call("_enter_wave_breather", 1))
	_check(opened, "the harness needs the breather to open")
	_check(RunState.build_grace_left() > 0.0,
		"a wave closed and no grace was armed - the next click opens a sheet")
	await get_tree().process_frame
	_check(not bool(cursor.call("_is_active")),
		"the click path is open inside the grace, which is the whole fault")
	_check(RunState.can_build_now(),
		"the grace must not close Preparation itself: the Quartermaster, "
			+ "repairs and selling all ask that question")


## And it ends. Measured by waiting it out rather than by clearing the stamp.
func _test_the_clock_waits_the_grace_out() -> void:
	var before: float = float(_run.get("_preparation_left"))
	_check(is_equal_approx(before, Balance.PREPARATION_BETWEEN_WAVES),
		"the breather must open at the full clock (%.1f)" % before)
	# Half the grace: the clock must not have moved at all.
	await get_tree().create_timer(Balance.BUILD_GRACE_SECONDS * 0.5).timeout
	var during: float = float(_run.get("_preparation_left"))
	_check(is_equal_approx(during, before),
		"the clock spent %.2f seconds of the player's thirty inside the grace"
			% (before - during))
	# And past it: the grace is over and the clock is running.
	await get_tree().create_timer(Balance.BUILD_GRACE_SECONDS * 0.9).timeout
	_check(RunState.build_grace_left() <= 0.0,
		"the grace never ended (%.2f left)" % RunState.build_grace_left())
	var after: float = float(_run.get("_preparation_left"))
	_check(after < before,
		"the clock never started after the grace (%.2f)" % after)
	var cursor: Node = _cursor()
	if cursor != null:
		_check(bool(cursor.call("_is_active")),
			"the click path never re-opened after the grace")


## **The grace is asked beside `can_build_now`, never inside it.** A source
## walk, because what this catches is somebody folding it in later: the
## Quartermaster, tower repair, selling and the crossroad path all ask that
## question and none of them is a click on open ground.
func _test_the_grace_is_not_can_build_now() -> void:
	var file := FileAccess.open("res://autoload/RunState.gd", FileAccess.READ)
	_check(file != null, "RunState.gd is missing")
	if file == null:
		return
	var text: String = file.get_as_text()
	var at: int = text.find("func can_build_now()")
	_check(at >= 0, "RunState no longer has can_build_now")
	if at < 0:
		return
	var body: String = text.substr(at, 160)
	_check(not body.contains("build_grace"),
		"the grace has been folded into can_build_now, which refuses the "
			+ "Quartermaster, repairs and selling for a second as well")


# --- the clock on the sheets ---------------------------------------------------

func _test_both_sheets_carry_the_clock() -> void:
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.build_grace_until_msec = 0
	var clocks: Array = _hud.get("_sheet_clocks") as Array
	_check(clocks.size() >= 2,
		"both sheets must carry a preparation clock, found %d" % clocks.size())
	EventBus.preparation_changed.emit(Balance.PREPARATION_BETWEEN_WAVES * 0.5, true)
	await get_tree().process_frame
	for entry: Variant in clocks:
		var row: Dictionary = entry as Dictionary
		var bar := row["bar"] as ProgressBar
		var box := row["box"] as Control
		_check(box.visible, "a sheet clock is hidden while a deadline is running")
		_check(absf(bar.value - 0.5) < 0.02,
			"a sheet clock reads %.2f at half the breather" % bar.value)
		_check(bar.max_value == 1.0, "a sheet clock must be a share, not seconds")
		_check(not (row["line"] as Label).text.is_empty(),
			"a sheet clock says nothing")


## **Hidden where there is no deadline.** Only the between-wave breather is
## timed; the crossroad's, the boss's and the opening breather all leave the
## clock at zero, and a bar reading empty there would be a lie about the one
## thing it exists to say.
func _test_the_clock_hides_when_there_is_no_deadline() -> void:
	# **The run's own clock is stopped first.** `Run._process` emits this
	# signal every frame while the breather runs, so a value pushed in by
	# hand is overwritten before the next frame is drawn - the first cut of
	# this check measured the run's number rather than its own.
	_run.set("_preparation_left", 0.0)
	EventBus.preparation_changed.emit(0.0, true)
	await get_tree().process_frame
	for entry: Variant in (_hud.get("_sheet_clocks") as Array):
		var box := (entry as Dictionary)["box"] as Control
		_check(not box.visible,
			"a sheet clock is showing an empty bar where there is no deadline")


# --- the tooltip ---------------------------------------------------------------

## **Above the card, never behind it.** The box is placed from a hovered row's
## own Y, so it is put exactly where the card is and then measured - and the
## card is drawn over it, so a box that merely overlaps is a box nobody reads.
func _test_the_tooltip_clears_the_preparation_card() -> void:
	var card := _hud.get("_preparation_panel") as Control
	var box := _hud.get("_build_tooltip") as Control
	_check(card != null and box != null, "the harness needs the card and the box")
	if card == null or box == null:
		return
	card.visible = true
	await get_tree().process_frame
	var rect: Rect2 = card.get_global_rect()
	_check(rect.size.y > 0.0, "the preparation card has no size to clear")
	if rect.size.y <= 0.0:
		return
	# **Put the box over the card and then ask the real clamp.**
	#
	# The first cut handed the card itself to `_show_build_tooltip` as the
	# hovered control, and `_panel_of` walked up from it to the card - so the
	# box was placed to the *left* of the card, never overlapped it, and the
	# check passed with the lift removed. What has to be driven is the
	# geometry the build sheet produces: a box in the card's own column, at
	# the card's own height.
	_hud.call("_show_build_tooltip", "a line of figures", card, "")
	box.visible = true
	var screen: float = get_viewport().get_visible_rect().size.x
	box.offset_right = rect.position.x + rect.size.x * 0.5 - screen
	box.offset_left = box.offset_right - HUD.BUILD_TOOLTIP_WIDTH
	await get_tree().process_frame
	_hud.call("_clamp_build_tooltip", rect.position.y + 8.0)
	await get_tree().process_frame
	var placed: Rect2 = box.get_global_rect()
	_check(placed.position.x < rect.position.x + rect.size.x
			and placed.position.x + placed.size.x > rect.position.x,
		"the harness must put the box in the card's own column")
	_check(not placed.intersects(rect),
		"the tooltip was left on the preparation card (%s against %s)"
			% [str(placed), str(rect)])
	_check(placed.position.y + placed.size.y <= rect.position.y + 1.0,
		"the tooltip must be lifted above the card rather than pushed under it")
	box.visible = false


# --- the wells -----------------------------------------------------------------

## **Three, and each dearer than the last.** Measured through
## `Battlefield.cost_of`, which is the function that charges - a test reading
## the constants back would pass on a build where the quote and the charge had
## drifted apart, which is the exact failure that function exists to prevent.
func _test_three_wells_and_each_dearer_than_the_last() -> void:
	var well: TowerData = null
	for tower: TowerData in ContentDB.base_towers():
		if tower.is_well():
			well = tower
			break
	_check(well != null, "the roster must hold a well")
	if well == null:
		return
	_check(Balance.WELL_LIMIT_PER_PLAYER == 3,
		"the owner asked for three wells, the cap is %d" % Balance.WELL_LIMIT_PER_PLAYER)
	var last: int = 0
	for standing: int in Balance.WELL_LIMIT_PER_PLAYER:
		var price: int = well.build_cost(standing)
		_check(price > last,
			"well %d costs %d, which is not more than the %d before it"
				% [standing + 1, price, last])
		last = price
		var table: Dictionary = well.build_cost_table(standing)
		_check(int(table.get("gold", 0)) == price,
			"the table and the price disagree for well %d" % (standing + 1))
		_check(int(table.get("stone", 0)) > 0, "a well always costs Stone")
	# And the quarry climbs with the purse.
	_check(int(well.build_cost_table(2).get("stone", 0))
			> int(well.build_cost_table(0).get("stone", 0)),
		"the third well asks no more Stone than the first")


## The row says which of the three it would be, and stops taking the click at
## the cap rather than taking it and then refusing.
func _test_the_well_row_says_how_many_stand() -> void:
	var well: TowerData = null
	for tower: TowerData in ContentDB.base_towers():
		if tower.is_well():
			well = tower
			break
	if well == null:
		return
	RunState.towers.clear()
	# A spot the field will actually take, rather than the origin - which is
	# the town, and refuses everything for a different reason.
	var anchor: Vector2i = _field.free_anchor_near(0, 8)
	var row := _hud.call("_tower_card", well, anchor) as Button
	_check(row != null, "the build sheet must offer a well")
	if row == null:
		return
	_check(row.text.contains("0/%d" % Balance.WELL_LIMIT_PER_PLAYER),
		"the well row must say how many of its three stand, says %s" % row.text)
	_check(not row.disabled, "a well row with none standing must be pressable")
	row.queue_free()

	# Three standing: the count reads full and the row is dim.
	for index: int in Balance.WELL_LIMIT_PER_PLAYER:
		RunState.set_tower(Vector2i(10 + index, 10), well.id, 1)
	_check(RunState.wells_standing() == Balance.WELL_LIMIT_PER_PLAYER,
		"the count must read the run's own record, reads %d" % RunState.wells_standing())
	var capped := _hud.call("_tower_card", well, anchor) as Button
	if capped != null:
		_check(capped.text.contains("%d/%d" % [Balance.WELL_LIMIT_PER_PLAYER,
			Balance.WELL_LIMIT_PER_PLAYER]),
			"the well row must read full at the cap, says %s" % capped.text)
		_check(capped.disabled, "the well row must be dim at the cap")
		capped.queue_free()
	# And the field refuses it by name.
	var refusal: String = _field.try_build(anchor, well)
	_check(not refusal.is_empty(), "a fourth well was allowed")
	_check(refusal.contains(str(Balance.WELL_LIMIT_PER_PLAYER)),
		"the refusal must say how many a road may draw from, says %s" % refusal)
	# Selling one frees a place, which is what makes it a count of what stands.
	RunState.clear_tower(Vector2i(10, 10), Vector2.ZERO)
	_check(RunState.wells_standing() == Balance.WELL_LIMIT_PER_PLAYER - 1,
		"a well that leaves must free its place")
	RunState.towers.clear()
	await get_tree().process_frame
