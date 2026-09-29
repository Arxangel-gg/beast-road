extends Node

## The stash's paper doll: the tiles say what is worn, filter the list, the
## comparison card answers a hover, "upgrades only" reads the list, and the
## doll steps aside where there is no room for it.
##
##   godot --headless --path game res://tools/stash_doll_check.tscn
##
## `docs/GEAR_REWORK_2026-09-28.md` §5. **A picture, driven rather than read**:
## the tiles are built by the screen the player opens, pressed through their
## own signal, and the list is counted afterwards - a test that called the
## filter by hand would pass with the tile wired to nothing.
##
## **Five ways it lies:**
##
## - **A tile shows the wrong piece**, or a piece where nothing is worn. The
##   doll is the one place the nine slots are seen together, so a tile that
##   disagrees with the equipped map is the whole feature being wrong.
## - **Pressing a tile filters nothing**, or filters and never releases.
## - **The comparison card opens for a worn piece** (comparing a piece with
##   itself), or never closes, or never opens.
## - **"Upgrades only" hides an upgrade or shows chaff.**
## - **The doll takes the panel off a narrow screen.** The list had a way out
##   on every shape before the doll existed, and must still.

var _failures: int = 0
var _checks: int = 0
var _screen: StashScreen = null

var _stash_before: Array = []
var _equipped_before: Dictionary = {}
var _attributes_before: Array = []
var _points_before: int = 0
var _window_before: Vector2i = Vector2i.ZERO


func _ready() -> void:
	MetaState.hold_saves()
	_stash_before = MetaState.stash.duplicate(true)
	_equipped_before = MetaState.equipped.duplicate()
	_attributes_before = RunState.hero_attributes.duplicate()
	_points_before = RunState.hero_attribute_points
	_window_before = get_window().size
	get_window().size = Vector2i(1920, 1080)
	_stock()
	_screen = StashScreen.new()
	add_child(_screen)
	await get_tree().process_frame
	_screen.open()
	await get_tree().process_frame
	await get_tree().process_frame
	_test_the_tiles_say_what_is_worn()
	await _test_a_tile_filters_the_list()
	await _test_the_comparison_card()
	await _test_upgrades_only()
	await _test_equipping_redresses_the_doll()
	_test_the_sheet_names_the_tier()
	await _test_the_doll_steps_aside()
	await _test_the_card_follows_a_refit()
	_test_the_bars_carry_it()
	_screen.hide_screen()
	_screen.queue_free()
	await get_tree().process_frame
	get_window().size = _window_before
	MetaState.stash = _stash_before
	MetaState.equipped = _equipped_before
	RunState.hero_attributes = _attributes_before
	RunState.hero_attribute_points = _points_before
	Modifiers.rebuild()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[stash-doll] PASS - %d checks: nine tiles that say what is worn, "
			+ "filter the list and let it go, a comparison that answers a hover "
			+ "and never a worn piece, upgrades only, the doll re-dressed on an "
			+ "equip, the tier on the sheet, and the doll stepping aside")
			% _checks)
	else:
		push_error("[stash-doll] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# --- The account under test ---------------------------------------------------

func _kind_in(slot: int, skip: int = 0) -> GearData:
	var seen: int = 0
	for kind: GearData in ContentDB.gear_sorted():
		if kind != null and int(kind.slot) == slot:
			if seen == skip:
				return kind
			seen += 1
	return null


## A worn Chainbroken weapon, a worn Rough charm, and three unworn pieces: a
## Rough and a Sound weapon (both worse than the worn one) and a Fine helmet
## (better than the nothing worn there).
func _stock() -> void:
	MetaState.stash = []
	MetaState.equipped = {}
	var top: int = Stash.RARITY_NAMES.size() - 2
	_receive(_kind_in(GearData.Slot.WEAPON), top, true)
	_receive(_kind_in(GearData.Slot.CHARM), 0, true)
	_receive(_kind_in(GearData.Slot.WEAPON, 1), 0, false)
	_receive(_kind_in(GearData.Slot.WEAPON, 2), 1, false)
	_receive(_kind_in(GearData.Slot.HELMET), 2, false)
	RunState.hero_attributes = [Balance.ATTRIBUTE_THRESHOLD * 2, 0, 0, 0, 0]
	RunState.hero_attribute_points = 0
	Modifiers.rebuild()


func _receive(kind: GearData, rarity: int, wear: bool) -> void:
	_check(kind != null, "a gear kind is needed for every slot the harness stocks")
	if kind == null:
		return
	MetaState.receive_gear(Stash.make(kind.id, rarity, 1))
	if wear:
		MetaState.equip(kind.slot, MetaState.stash.size() - 1)


# --- The tiles ----------------------------------------------------------------

func _tile(slot: int) -> Button:
	var tiles: GridContainer = _screen.get("_tiles") as GridContainer
	if tiles == null:
		return null
	return tiles.get_node_or_null("Tile%s" % GearData.name_of_slot(slot)) as Button


func _mark(tile: Button) -> TextureRect:
	return _find(tile, "Mark") as TextureRect


func _find(from: Node, wanted: String) -> Node:
	if from == null:
		return null
	if from.name == wanted:
		return from
	for child: Node in from.get_children():
		var hit: Node = _find(child, wanted)
		if hit != null:
			return hit
	return null


func _test_the_tiles_say_what_is_worn() -> void:
	var tiles: GridContainer = _screen.get("_tiles") as GridContainer
	_check(tiles != null, "the stash builds no slot tiles")
	if tiles == null:
		return
	_check(tiles.get_child_count() == GearData.Slot.size(),
		"%d tiles for %d slots" % [tiles.get_child_count(), GearData.Slot.size()])
	for slot: int in GearData.Slot.size():
		var tile: Button = _tile(slot)
		_check(tile != null, "no tile for %s" % GearData.name_of_slot(slot))
		if tile == null:
			continue
		var mark: TextureRect = _mark(tile)
		_check(mark != null and mark.texture != null, "the %s tile carries no mark" % GearData.name_of_slot(slot))
		var worn: Dictionary = MetaState.equipped_piece(slot)
		if worn.is_empty():
			_check(mark != null and mark.modulate.a < 0.5,
				"nothing is worn as %s and its tile is lit as though something were" % GearData.name_of_slot(slot))
			continue
		var kind: GearData = ContentDB.gear(String(worn["kind"]))
		_check(mark != null and mark.texture != null and mark.texture.resource_path == kind.get_sprite_path(),
			"the %s tile shows %s rather than the worn %s" % [GearData.name_of_slot(slot),
				mark.texture.resource_path if mark != null and mark.texture != null else "nothing", kind.id])
		_check(mark != null and mark.modulate.a > 0.9, "the worn %s is dimmed" % GearData.name_of_slot(slot))
		_check(tile.tooltip_text.contains(kind.display_name), "the worn tile does not name its piece")


func _rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list: VBoxContainer = _screen.get("_list") as VBoxContainer
	if list == null:
		return out
	for stripe: Node in list.get_children():
		var card: Button = _first_button(stripe)
		if card != null:
			out.append({"card": card})
	return out


func _first_button(from: Node) -> Button:
	var button := from as Button
	if button != null:
		return button
	for child: Node in from.get_children():
		var hit: Button = _first_button(child)
		if hit != null:
			return hit
	return null


func _test_a_tile_filters_the_list() -> void:
	var all: int = _rows().size()
	_check(all == MetaState.stash.size(), "the whole stash lists %d of %d rows" % [all, MetaState.stash.size()])
	var weapon: Button = _tile(GearData.Slot.WEAPON)
	if weapon == null:
		return
	weapon.pressed.emit()
	await get_tree().process_frame
	_check(int(_screen.get("_filter")) == GearData.Slot.WEAPON, "pressing the weapon tile did not filter to weapons")
	_check(_rows().size() == 3, "filtered to weapons the list shows %d rows, not 3" % _rows().size())
	# The tile is rebuilt with the list; the new one reads as pressed.
	weapon = _tile(GearData.Slot.WEAPON)
	_check(weapon != null and weapon.button_pressed, "the filtering tile does not read as pressed")
	weapon.pressed.emit()
	await get_tree().process_frame
	_check(int(_screen.get("_filter")) == -1, "pressing the tile again did not let the list go")
	_check(_rows().size() == all, "let go, the list shows %d rows, not %d" % [_rows().size(), all])


func _test_the_comparison_card() -> void:
	var compare: GearCompare = _screen.get("_compare") as GearCompare
	_check(compare != null, "the stash carries no comparison card")
	if compare == null:
		return
	_check(not compare.visible, "the card is showing before anything is hovered")
	# The rows are in the stash's order; the first two are the worn pieces.
	var rows: Array[Dictionary] = _rows()
	if rows.size() < 3:
		return
	var worn_card: Button = rows[0]["card"]
	worn_card.mouse_entered.emit()
	await get_tree().process_frame
	_check(not compare.visible, "hovering a worn piece opened a comparison of it with itself")
	var unworn_card: Button = rows[2]["card"]
	unworn_card.mouse_entered.emit()
	await get_tree().process_frame
	_check(compare.visible, "hovering an unworn piece did not open the comparison")
	unworn_card.mouse_exited.emit()
	await get_tree().process_frame
	_check(not compare.visible, "leaving the row did not close the comparison")
	unworn_card.focus_entered.emit()
	await get_tree().process_frame
	_check(compare.visible, "focusing a row with the pad did not open the comparison")
	unworn_card.focus_exited.emit()
	await get_tree().process_frame
	_check(not compare.visible, "leaving the row with the pad did not close it")
	await _test_the_card_never_covers_its_row(compare)
	# That rebuilt the list, so the row is fetched again rather than kept.
	rows = _rows()
	if rows.size() < 3:
		return
	unworn_card = rows[2]["card"]
	# Closing the screen closes the card with it.
	unworn_card.mouse_entered.emit()
	await get_tree().process_frame
	_screen.hide_screen()
	_check(not compare.visible, "the card outlived the screen")
	_screen.open()
	await get_tree().process_frame


## The card takes one of two seats and never the one over the row it is
## comparing. Both seats have to be seen taken, or a card nailed to one of
## them passes every row it happens to miss. The lane is scrolled to its end
## so a row stands where the filter grid was, which is what forces the bottom.
func _test_the_card_never_covers_its_row(compare: GearCompare) -> void:
	var scroll: ScrollContainer = _screen.get("_scroll") as ScrollContainer
	_check(scroll != null, "the stash has no list scroll")
	if scroll == null:
		return
	# A dozen more Rough weapons, so the lane scrolls a long way; taken back
	# out after, since the tests after this count rows.
	var before: int = MetaState.stash.size()
	for extra: int in 12:
		_receive(_kind_in(GearData.Slot.WEAPON, 1), 0, false)
	_screen.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var seats: Dictionary = {}
	for pass_index: int in 2:
		scroll.scroll_vertical = 0 if pass_index == 0 else 100000
		await get_tree().process_frame
		await get_tree().process_frame
		var lane: Rect2 = scroll.get_global_rect()
		for row: Dictionary in _rows():
			var card: Button = row["card"]
			var here: Rect2 = card.get_global_rect()
			if not lane.encloses(here):
				continue
			card.mouse_entered.emit()
			# Two passes: the card's labels are unlaid on the frame of the hover.
			await get_tree().process_frame
			await get_tree().process_frame
			if not compare.visible:
				card.mouse_exited.emit()
				continue
			var seat: Rect2 = compare.get_global_rect()
			_check(seat.size.y <= StashScreen.COMPARE_TALL,
				"the card settled at %.0f tall, past the %.0f the seat is chosen against" % [seat.size.y, StashScreen.COMPARE_TALL])
			var covered: float = seat.intersection(here).get_area()
			_check(covered <= 0.0,
				"the card at %s covers the hovered row at %s" % [seat, here])
			seats[seat.position.y < lane.get_center().y] = true
			card.mouse_exited.emit()
			await get_tree().process_frame
	_check(seats.has(true) and seats.has(false),
		"the card only ever took one seat (%s); the other was never forced" % [seats.keys()])
	MetaState.stash.resize(before)
	scroll.scroll_vertical = 0
	_screen.open()
	await get_tree().process_frame


func _upgrades_button() -> Button:
	var tools: GridContainer = _screen.get("_tools") as GridContainer
	if tools == null:
		return null
	for child: Node in tools.get_children():
		var button := child as Button
		if button != null and button.text.begins_with("Upgrades"):
			return button
	return null


func _test_upgrades_only() -> void:
	var button: Button = _upgrades_button()
	_check(button != null, "there is no upgrades-only button")
	if button == null:
		return
	_check(not button.toggle_mode, "the upgrades button is a toggle, which menu_check counts as a slot filter")
	button.pressed.emit()
	await get_tree().process_frame
	# Two worse weapons and two worn pieces are hidden; the helmet, worn against
	# nothing, is the one upgrade.
	_check(_rows().size() == 1, "upgrades only lists %d rows, not the one helmet" % _rows().size())
	button = _upgrades_button()
	button.pressed.emit()
	await get_tree().process_frame
	_check(_rows().size() == MetaState.stash.size(), "pressing again did not show everything")


func _test_equipping_redresses_the_doll() -> void:
	# Wear the Fine helmet through the screen's own action door.
	var index: int = -1
	for at: int in MetaState.stash.size():
		var kind: GearData = ContentDB.gear(String((MetaState.stash[at] as Dictionary).get("kind", "")))
		if kind != null and int(kind.slot) == GearData.Slot.HELMET:
			index = at
	_check(index >= 0, "the harness stocked no helmet")
	if index < 0:
		return
	_screen.call("_do_item_action", index, StashScreen.MENU_EQUIP)
	await get_tree().process_frame
	_check(not MetaState.equipped_piece(GearData.Slot.HELMET).is_empty(), "the equip door did not wear the helmet")
	var tile: Button = _tile(GearData.Slot.HELMET)
	var mark: TextureRect = _mark(tile)
	var kind: GearData = ContentDB.gear(String((MetaState.stash[index] as Dictionary).get("kind", "")))
	_check(mark != null and mark.texture != null and mark.texture.resource_path == kind.get_sprite_path(),
		"the helmet tile was not re-dressed after the equip")
	var stage: WardenStage = _screen.get("_stage") as WardenStage
	if stage != null:
		_check(stage.animator() != null, "the doll's stage has no animator")


func _test_the_sheet_names_the_tier() -> void:
	var sheet: VBoxContainer = _screen.get("_sheet") as VBoxContainer
	_check(sheet != null and sheet.get_child_count() == RunState.ATTRIBUTE_NAMES.size(),
		"the sheet has %d lines for %d attributes" % [sheet.get_child_count() if sheet != null else 0,
			RunState.ATTRIBUTE_NAMES.size()])
	if sheet == null or sheet.get_child_count() == 0:
		return
	var perk: AttributePerkData = ContentDB.attribute_perk(RunState.Attribute.MIGHT)
	var said: String = _labels_under(sheet.get_child(0))
	_check(said.contains("Might"), "the first line is not Might: \"%s\"" % said)
	_check(perk == null or said.contains(perk.display_name) and said.contains("II"),
		"twenty Might placed does not read as the second tier: \"%s\"" % said)


func _test_the_doll_steps_aside() -> void:
	var doll: VBoxContainer = _screen.get("_doll") as VBoxContainer
	_check(doll != null and doll.visible, "on a desktop the doll is hidden")
	# **The logical size, not the window's.** The project stretches
	# `canvas_items`, so a smaller window keeps the same logical rect and a
	# stale doll still fits by accident (road_sheet_check learned this the
	# same way). The content scale size is the logical rect itself.
	var scale_before: Vector2i = get_window().content_scale_size
	# Upright, both the window and the logical rect: `expand` keeps the
	# window's aspect, so a wide window stays wide whatever the scale says.
	get_window().size = Vector2i(700, 1000)
	get_window().content_scale_size = Vector2i(700, 1000)
	await get_tree().process_frame
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_check(screen.x < Balance.UI_STASH_DOLL_WIDTH,
		"the harness meant to make a narrow screen and got %.0f wide" % screen.x)
	_screen.call("_refit")
	await get_tree().process_frame
	_check(doll != null and not doll.visible, "on a narrow screen the doll is still shown")
	var panel: PanelContainer = _screen.get("_panel") as PanelContainer
	_check(panel != null and panel.size.x <= screen.x,
		"narrow, the panel is %.0f wide on a %.0f screen" % [panel.size.x if panel != null else 0.0, screen.x])
	get_window().content_scale_size = scale_before
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	_screen.call("_refit")
	await get_tree().process_frame
	_check(doll != null and doll.visible, "back on a desktop the doll did not return")


## A card seated by the lane must follow the lane when the screen changes
## shape under it: photographed left half off the right of a narrow screen,
## where the wide lane's centre had been.
func _test_the_card_follows_a_refit() -> void:
	var compare: GearCompare = _screen.get("_compare") as GearCompare
	var scroll: ScrollContainer = _screen.get("_scroll") as ScrollContainer
	var rows: Array[Dictionary] = _rows()
	if compare == null or scroll == null or rows.size() < 3:
		return
	var card: Button = rows[2]["card"]
	card.mouse_entered.emit()
	await get_tree().process_frame
	_check(compare.visible, "hovering before the refit did not open the card")
	var scale_before: Vector2i = get_window().content_scale_size
	get_window().size = Vector2i(700, 1000)
	get_window().content_scale_size = Vector2i(700, 1000)
	await get_tree().process_frame
	_screen.call("_refit")
	for _settle: int in 4:
		await get_tree().process_frame
	var screen: Rect2 = get_viewport().get_visible_rect()
	var seat: Rect2 = compare.get_global_rect()
	_check(screen.encloses(seat), "after the refit the card sits at %s, off a %s screen" % [seat, screen])
	var lane: Rect2 = scroll.get_global_rect()
	_check(absf(seat.get_center().x - lane.get_center().x) < 2.0,
		"after the refit the card is centred at %.0f, the lane at %.0f" % [seat.get_center().x, lane.get_center().x])
	card.mouse_exited.emit()
	get_window().content_scale_size = scale_before
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	_screen.call("_refit")
	await get_tree().process_frame


func _test_the_bars_carry_it() -> void:
	for workflow: String in ["res://../.github/workflows/guard.yml",
			"res://../.github/workflows/release.yml"]:
		_check(FileAccess.get_file_as_string(workflow).contains("stash_doll_check.tscn"),
			"%s does not run this gate" % workflow.get_file())


# --- Helpers -------------------------------------------------------------------

func _labels_under(node: Node) -> String:
	if node == null:
		return ""
	var lines: PackedStringArray = []
	var label := node as Label
	if label != null:
		lines.append(label.text)
	for child: Node in node.get_children():
		lines.append(_labels_under(child))
	return " | ".join(lines)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[stash-doll] " + why)
