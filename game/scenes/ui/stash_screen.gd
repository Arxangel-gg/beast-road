class_name StashScreen
extends CanvasLayer

## The stash and the blacksmith, on one screen.
##
## One screen rather than two, because they are one decision. "Is this sword
## better than mine" and "should I break it for shards to upgrade the one I have"
## are the same question asked from either end, and putting a wall between them
## makes a player walk back and forth to answer it.
##
## Reached from the main menu, and — since 2026-09-09, at the owner's request —
## from the Hero Mansion inside a run.
##
## This paragraph used to say "not from a run: gear persists and a run does not
## pause for shopping", and the second half of that is still true and is why the
## Mansion is where it hangs. The town does not stop the battlefield: a scope is
## a window onto a fight that carries on without you, so shopping there costs
## exactly the road time that building there costs. Nothing was made to pause.
##
## What is deliberately *not* done is a stash button on the combat bar. Gear
## grants attribute points on the same capped scale as levelling (working rule
## 7), so swapping cannot out-run the curve — but a full gear screen one click
## from the fight turns a visit into a between-waves routine, and the Mansion is
## where the hero is edited.

signal closed()

## Filter tabs per row. Three keeps every button wide enough to hit on a phone
## once the eight gear slots and "All" are laid out.
const TOOL_COLUMNS: int = 3

const ATTRIBUTE_NAMES: Array[String] = RunState.ATTRIBUTE_NAMES

var _panel: PanelContainer
## The paper doll (docs/GEAR_REWORK_2026-09-28.md §5): the dressed Warden, the
## nine slot tiles and the attributes, in a column beside the list on a screen
## wide enough for both. `_stage` is null on an account whose body is not drawn.
var _body: HBoxContainer
var _doll: VBoxContainer
var _stage: WardenStage = null
var _tiles: GridContainer
var _sheet: VBoxContainer
## The comparison card the Market already draws, laid over the screen while a
## row is hovered or focused: what this piece would be instead of what is worn.
var _compare: GearCompare
## The row the card is comparing, so a refit can seat it again.
var _compare_row: Control = null
var _list: VBoxContainer
var _header: Label
var _note: Label
var _tools: GridContainer
var _scroll: ScrollContainer

## The pantry, which is not a gear slot at all.
##
## A separate value rather than a separate screen: fish are kept in the stash,
## the owner asked for them "under a consumables tab", and a second window for
## eleven rows would be a menu standing in front of a decision nobody makes.
const FILTER_PANTRY: int = -2

## Which slot the list is filtered to, -1 for all gear, or `FILTER_PANTRY` for
## the fish. A stash of ninety-six is not a list you read; it is one you search.
var _filter: int = -1

## **Which way the list is read.** By slot is the default and is what this
## screen has always done - it answers "is any of this better than what I am
## wearing in *this* place". Best-first answers "what is the best thing I own",
## which is the question a full stash is actually opened with, and it is the one
## the Sort button puts the store itself into.
var _best_first: bool = false

## **Only what beats what is worn.** A stash of ninety-six is opened to answer
## one question, and this reading answers it directly: an unworn piece whose
## points beat the worn piece of its slot, and nothing else.
var _upgrades_only: bool = false

## The last thing a bulk action had to say. Kept in a field rather than written
## straight to the label, because `_refresh` rewrites that label - the same trap
## that made every error message in the town sheet invisible.
var _message: String = ""


func _ready() -> void:
	layer = 64
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.88)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	move_child(backdrop, 0)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(940.0, 0.0)
	centre.add_child(_panel)

	# **The doll beside the list.** The list keeps everything it had; the doll
	# is a column to its left that `_refit` shows only where there is room.
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	_panel.add_child(_body)
	_doll = _build_doll()
	_body.add_child(_doll)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(column)

	# **The comparison card, on the layer rather than in the panel**, so a hover
	# re-lays nothing: it is the Market's own card, anchored to the bottom of
	# the screen exactly as the Market anchors it.
	_compare = GearCompare.new()
	_compare.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_compare.grow_horizontal = Control.GROW_DIRECTION_END
	_compare.grow_vertical = Control.GROW_DIRECTION_END
	add_child(_compare)

	_header = Label.new()
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header.add_theme_font_size_override("font_size", 22)
	_header.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(_header)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", Color("b8ae98"))
	# **A Label's minimum width is its whole text.** This one says "17 of 96
	# held - full-stash drops auto-break into Shards", it sits outside the
	# scroll as a direct child of the panel, and at touch font sizes it demanded
	# 1318 units on a 430-wide phone - so the panel grew to fit *it*, carried
	# the Close button off the bottom with it, and `layout_check` reported a
	# stash with no way out. Wrapped, its minimum is one word wide and the
	# panel is governed by its own `custom_minimum_size` again.
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)

	# Bulk work, above the list rather than in it.
	#
	# **Added with the drop-rate rise** (owner direction, 2026-09-01: "the game
	# needs way more loot"). Four times the drops means four times the sorting,
	# and a farming loop where clearing the chaff costs one press per piece is a
	# farming loop nobody runs twice. These never touch what is worn.
	# **A grid rather than a row, since the slots went from three to eight.**
	# Nine filters in one line is nine buttons about forty pixels wide on a
	# phone, which is under the thumb floor the layout gate enforces and
	# unreadable besides. Three columns wraps them into three rows and every
	# button keeps its width.
	# The list scrolls and the close button does not. A full stash is forty rows,
	# and a screen whose only way out is below forty rows is the results screen
	# bug again.
	var scroll := ScrollContainer.new()
	UiMetrics.prepare_scroll(scroll, TouchInput.is_showing())
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_scroll = scroll
	scroll.item_rect_changed.connect(_on_compare_row_moved)

	# **The filters scroll with the list.**
	#
	# They used to sit above it, pinned. Eleven of them wrap to four rows at 120
	# units each, which is 480 of the 775 a landscape phone has - so the panel
	# could not fit whatever else it needed however small the list was made, and
	# the Close button went off the bottom. Pinning only the heading and the way
	# out bounds the panel by construction rather than by arithmetic that has to
	# be right.
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)

	_tools = GridContainer.new()
	_tools.columns = TOOL_COLUMNS
	_tools.add_theme_constant_override("h_separation", 6)
	_tools.add_theme_constant_override("v_separation", 6)
	inner.add_child(_tools)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	inner.add_child(_list)
	# **And again whenever the window changes shape.** Every other screen
	# here connects this; the stash did not, so it kept the shape it was
	# built at - on a phone that left the panel at its 940-wide minimum with
	# the way out below the bottom of the display.
	get_viewport().size_changed.connect(_refit)
	_refit()

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0.0, 44.0)
	close.pressed.connect(func() -> void: hide_screen())
	column.add_child(close)


## **Enrolled like every other screen.** `UiJuice` is what gives a control its
## hover, focus and tap hologram; the HUD, the main menu and the crossroads all
## call it, and the stash - the screen a player spends the most time in - was
## inert. Additive and bounded, the same as everywhere else.
func _dress() -> void:
	UiJuice.enrol(get_tree(), self)


## The doll's column: the Warden, the nine slots and the attributes.
func _build_doll() -> VBoxContainer:
	var doll := VBoxContainer.new()
	doll.name = "Doll"
	doll.custom_minimum_size = Vector2(DOLL_WIDTH, 0.0)
	doll.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Wearing"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("b8ae98"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	doll.add_child(title)

	# The dressed Warden, the Glass's own stage, wearing this account's gear -
	# so the doll cannot disagree with the road about what is worn. An account
	# whose body is not drawn yet has the tiles and no figure.
	if WardenDress.available(WardenDress.body_name(WardenLook.worn())):
		_stage = WardenStage.new()
		_stage.name = "Stage"
		_stage.turn_seconds = STAGE_TURN_SECONDS
		_stage.art_scale = STAGE_ART_SCALE
		_stage.custom_minimum_size = Vector2(DOLL_WIDTH, STAGE_HEIGHT)
		_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		doll.add_child(_stage)

	_tiles = GridContainer.new()
	_tiles.name = "Slots"
	_tiles.columns = TILE_COLUMNS
	_tiles.add_theme_constant_override("h_separation", 6)
	_tiles.add_theme_constant_override("v_separation", 6)
	_tiles.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	doll.add_child(_tiles)

	_sheet = VBoxContainer.new()
	_sheet.name = "Attributes"
	_sheet.add_theme_constant_override("separation", 2)
	doll.add_child(_sheet)
	return doll


## One tile a slot: the worn piece's own mark in its rarity frame, or the
## slot's mark dimmed where nothing is worn; a dot a set gem. **Pressing one
## filters the list to that slot**, and pressing it again reads everything -
## the tabs do the same, so a thumb and a mouse reach the same list.
func _build_tiles() -> void:
	if _tiles == null:
		return
	for child: Node in _tiles.get_children():
		_tiles.remove_child(child)
		child.queue_free()
	for slot: int in GearData.Slot.size():
		var piece: Dictionary = MetaState.equipped_piece(slot)
		var kind: GearData = ContentDB.gear(String(piece.get("kind", ""))) if not piece.is_empty() else null
		var worn: bool = kind != null
		var tint: Color = Stash.rarity_colour(piece) if worn else Color("6f766f")
		var tile := Button.new()
		tile.name = "Tile%s" % GearData.name_of_slot(slot)
		tile.toggle_mode = true
		tile.button_pressed = _filter == slot
		tile.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE + TILE_LABEL)
		tile.add_theme_stylebox_override("normal", _card_plate(tint, worn, 0.0))
		tile.add_theme_stylebox_override("hover", _card_plate(tint, worn, 0.34))
		tile.add_theme_stylebox_override("pressed", _card_plate(tint, worn, 0.5))
		tile.add_theme_stylebox_override("focus", _card_plate(tint, worn, 0.34))
		tile.tooltip_text = ("%s %s\n%s" % [Stash.rarity_name(piece), kind.display_name,
			GearRow.bonus_text(piece, kind)]) if worn else "Nothing worn as %s" % GearData.name_of_slot(slot).to_lower()
		var face := VBoxContainer.new()
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.add_theme_constant_override("separation", 0)
		face.alignment = BoxContainer.ALIGNMENT_CENTER
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(face)
		var icon := TextureRect.new()
		icon.name = "Mark"
		icon.custom_minimum_size = Vector2(TILE_ICON, TILE_ICON)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = _art_at(kind.get_sprite_path()) if worn else _slot_mark(slot)
		icon.modulate = tint.lerp(Color.WHITE, 0.45) if worn else Color(1.0, 1.0, 1.0, 0.32)
		face.add_child(icon)
		# A dot a set gem, in the gem's own colour, under the mark.
		var gems: Array[String] = Stash.gems(piece)
		if not gems.is_empty():
			var dots := HBoxContainer.new()
			dots.name = "Gems"
			dots.alignment = BoxContainer.ALIGNMENT_CENTER
			dots.add_theme_constant_override("separation", 3)
			dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for gem_id: String in gems:
				var stone: MaterialData = ContentDB.material(gem_id)
				var dot := ColorRect.new()
				dot.custom_minimum_size = Vector2(7.0, 7.0)
				dot.color = Stash.RARITY_COLOURS[clampi((stone.rarity if stone != null else 0) + 2, 0,
					Stash.RARITY_COLOURS.size() - 1)]
				dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
				dots.add_child(dot)
			face.add_child(dots)
		var caption := Label.new()
		caption.text = GearData.name_of_slot(slot)
		caption.add_theme_font_size_override("font_size", 11)
		caption.add_theme_color_override("font_color", tint.lerp(Color("cfd6d0"), 0.6))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(caption)
		var which: int = slot
		tile.pressed.connect(func() -> void:
			_filter = -1 if _filter == which else which
			_refresh())
		_tiles.add_child(tile)


## The five attributes as the road reads them - placed and worn together - and
## the perk tier each has reached, on one line apiece.
func _build_sheet() -> void:
	if _sheet == null:
		return
	for child: Node in _sheet.get_children():
		_sheet.remove_child(child)
		child.queue_free()
	for which: int in RunState.ATTRIBUTE_NAMES.size():
		var total: int = WardenSheet.attribute_of(null, which)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var mark := TextureRect.new()
		mark.custom_minimum_size = Vector2(18.0, 18.0)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.texture = IconKit.attribute(which)
		line.add_child(mark)
		var words := Label.new()
		var perk: AttributePerkData = ContentDB.attribute_perk(which)
		var tiers: int = WardenSheet.perk_tiers(null, which)
		words.text = "%s %d" % [RunState.ATTRIBUTE_NAMES[which], total]
		if perk != null and tiers > 0:
			words.text += "  ·  %s %s" % [perk.display_name, ["", "I", "II", "III", "IV", "V"][clampi(tiers, 0, 5)]]
		words.add_theme_font_size_override("font_size", 13)
		words.add_theme_color_override("font_color", RunState.ATTRIBUTE_COLOURS[which].lerp(Color("e8e2d4"), 0.4)
			if which < RunState.ATTRIBUTE_COLOURS.size() else Color("cfd6d0"))
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.tooltip_text = perk.line(tiers, total) if perk != null else ""
		line.add_child(words)
		_sheet.add_child(line)


## Dresses the figure in what is worn now. Asked on every refresh, because a
## piece equipped from the list has to be on the Warden's back the same frame.
func _dress_doll() -> void:
	if _stage != null:
		_stage.show_look(WardenLook.worn())


## Whether the doll's column fits: a screen wide enough for both it and the
## list, and never on a thumb, where the panel is the whole glass.
func _doll_fits(screen: Vector2) -> bool:
	return screen.x >= Balance.UI_STASH_DOLL_WIDTH and not TouchInput.is_showing()


func open() -> void:
	visible = true
	# **Refresh first, then fit.** `_refit` measures the column's other children
	# to decide what the scroll may take, and the filter grid is *populated* by
	# `_refresh` - so fitting first measured an empty grid, under-reserved by the
	# four rows of filters, and handed the scroll room the panel did not have.
	# The panel then stood 3846 units tall in a 3641 screen and the Close button
	# was below the bottom edge. Reported from a phone as a stash with no way out.
	_refresh()
	_refit()
	_dress()


func hide_screen() -> void:
	visible = false
	if _compare != null:
		_compare.hide_pair()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_screen()


func _refit() -> void:
	if _panel == null or _scroll == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	# **A height floor as well as a width.** The panel was free to be as short as
	# its contents, so a filtered list with two pieces in it collapsed to a strip
	# floating in the middle of the screen with Close under it - reported as a
	# window "not properly sized", and as a Close button that reads as being at
	# the top of the space rather than the bottom of a panel. A floor of most of
	# the screen keeps the shape the same however many pieces are held, and the
	# scroll inside it takes up the slack.
	# **The filters wrap rather than shrink.** `UiMetrics` inflates a button
	# to a thumb on a touch layout, so three columns of them measure 900 -
	# exactly the portrait canvas - and with the scroll's padding and the
	# panel's margins on top the panel came out 992 wide on a 900 canvas, with
	# the way out pushed off the bottom along with it. Shrinking the buttons is
	# the answer tried and reverted for the scope column on 2026-09-13: it
	# trades a layout fault for undersized thumb targets, which is worse. Two
	# columns of full-size buttons fit, and the grid is a `GridContainer`
	# precisely so that this is one assignment.
	if _tools != null:
		_tools.columns = TOOL_COLUMNS if screen.x >= Balance.UI_STASH_WIDE_FILTERS \
			else TOOL_COLUMNS - 1
	# The doll takes its column only where the screen has one to give; the
	# panel grows by exactly that column when it does.
	var doll_shown: bool = _doll_fits(screen)
	if _doll != null:
		_doll.visible = doll_shown
	_panel.custom_minimum_size = Vector2(
		minf(940.0 + (DOLL_WIDTH + 14.0 if doll_shown else 0.0), screen.x - Balance.UI_PANEL_MARGIN * 2.0),
		minf(screen.y * 0.82, 860.0))
	# **Measured, not guessed.** This reserved a flat 300 for "heading, note, the
	# tool row and Close" - written when the filters were one row of three. They
	# became a three-column grid of nine plus two sweep buttons on 2026-09-01 and
	# this number was not revisited, so the column grew past the screen; a
	# `CenterContainer` overflows equally in both directions, and the Close
	# button went off the bottom. Reported from a phone as a stash that cannot be
	# closed. Measuring the column's other children cannot drift that way again.
	var column: Control = _scroll.get_parent() as Control
	_scroll.custom_minimum_size = Vector2(0.0,
		UiMetrics.scroll_room_measured(_scroll, column, Balance.UI_PANEL_MARGIN))
	if _compare != null and is_instance_valid(_compare) and _compare.visible:
		_reseat_after_layout()


## The list, best first within each slot.
##
## Sorted rather than in the order things were picked up, because the question a
## stash is opened to answer is "is any of this better than what I am wearing",
## and the answer to that is at the top of a sorted list and somewhere in the
## middle of an unsorted one. Returns indices into `MetaState.stash`, not copies:
## every action here removes by index.
func _sorted_indices() -> Array[int]:
	var order: Array[int] = []
	for index: int in MetaState.stash.size():
		var piece: Dictionary = MetaState.stash[index]
		var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
		if _filter >= 0 and (kind == null or int(kind.slot) != _filter):
			continue
		# Upgrades only: an unworn piece that beats what is worn in its slot.
		if _upgrades_only and kind != null and (MetaState.is_equipped_index(index)
				or Stash.points(piece, kind) <= HoldNews.worn_points(int(kind.slot))):
			continue
		order.append(index)
	# **Best first reads the store's own order**, which `MetaState.sort_stash`
	# has just put into exactly that: sorting the view a second way here would
	# be a second opinion about "best" that could disagree with the one every
	# other reader of this list sees.
	if _best_first:
		return order
	order.sort_custom(func(a: int, b: int) -> bool:
		var one: Dictionary = MetaState.stash[a]
		var two: Dictionary = MetaState.stash[b]
		var kind_one: GearData = ContentDB.gear(String(one.get("kind", "")))
		var kind_two: GearData = ContentDB.gear(String(two.get("kind", "")))
		var slot_one: int = int(kind_one.slot) if kind_one != null else 9
		var slot_two: int = int(kind_two.slot) if kind_two != null else 9
		if slot_one != slot_two:
			return slot_one < slot_two
		return Stash.points(one, kind_one) > Stash.points(two, kind_two))
	return order


## Everything unworn at or below `rarity`, broken for shards in one press.
##
## Descending, which is not a style choice: `MetaState.drop_gear` removes by
## index and every later index shifts down, so ascending would break the wrong
## pieces from the second one onward. Equipped gear is skipped outright rather
## than filtered afterwards - a bulk action that can strip the hero is a bulk
## action nobody presses.
## **Everything unworn at or below `rarity`, sold for Marks in one press**
## (owner, 2026-09-22: "options not just to break all rough and sound gear but to
## also sell all"). The same sweep as breaking - equipped and kept pieces are
## never touched, descending so removals do not shift what is still to come -
## paid at each piece's own sale price, the one a single sale pays.
func _sell_all(rarity: int) -> int:
	MetaState.hold_saves()
	var sold: int = 0
	var gained: int = 0
	for index: int in range(MetaState.stash.size() - 1, -1, -1):
		if MetaState.is_equipped_index(index):
			continue
		var piece: Dictionary = MetaState.stash[index]
		if not Stash.may_break(piece, rarity):
			continue
		gained += Stash.sell_price(piece)
		MetaState.drop_gear(index)
		sold += 1
	MetaState.resume_saves()
	MetaState.marks += gained
	MetaState.save_game()
	return sold


func _break_all(rarity: int) -> int:
	# Asked of `MetaState` by position rather than collected from the map: the
	# map keys by uid since 2026-09-22 and a screen must not know that.
	# Held across the sweep. `drop_gear` writes the save on every removal, so
	# breaking sixty pieces was sixty full serialisations of the whole account
	# - and sixty chances for a crash to land mid-write.
	MetaState.hold_saves()
	var broken: int = 0
	var gained: int = 0
	for index: int in range(MetaState.stash.size() - 1, -1, -1):
		if MetaState.is_equipped_index(index):
			continue
		var piece: Dictionary = MetaState.stash[index]
		# Asked of `Stash` rather than decided here. A marked piece is never
		# swept - that is the entire reason the mark exists - and a bulk action
		# that can take the thing you were saving is one nobody presses twice.
		if not Stash.may_break(piece, rarity):
			continue
		gained += Stash.salvage_yield(piece)
		MetaState.drop_gear(index)
		broken += 1
	MetaState.resume_saves()
	MetaState.shards += gained
	if broken > 0:
		MetaState.save_game()
		Sfx.play("sfx_relic_socket")
	return broken


## **How tall a filter tab stands, and how big its mark is.**
##
## 36 units with a 13pt label was under what either platform guideline asks of a
## touch target, on the screen a phone player spends most of their time in. The
## *width* is what `menu_layout_check` guards - three columns of the widest
## label - and none of this touches it. [TUNE]
const TAB_HEIGHT: float = 46.0
const TAB_ICON: int = 22


## **The mark a slot filter wears**: a piece of gear that actually goes in it.
##
## Every kind already has authored art at `icons/ui/ui_<id>.png`, so the filter
## for a slot can simply wear one of them. Drawn specially instead, a "helmet"
## icon would be a ninth thing to keep in step with the eight helmets - and when
## a slot is added the tab is right with nobody drawing anything.
##
## The pantry wears a fish for the same reason. `All` wears none: it is the
## absence of a filter, and a mark for that is a mark for nothing.
func _slot_mark(index: int) -> Texture2D:
	if index == FILTER_PANTRY:
		var caught: Array[FishData] = ContentDB.fish_sorted()
		if caught.is_empty():
			return null
		return _art_at(caught[0].get_sprite_path())
	if index < 0:
		return null
	# The roster is walked in a stable order so a slot's mark does not change
	# between launches - a filter that wears a different sword each time is a
	# filter a player cannot learn the shape of.
	var kinds: Array[GearData] = ContentDB.gear_sorted()
	for kind: GearData in kinds:
		if kind != null and kind.slot == index:
			var art: Texture2D = _art_at(kind.get_sprite_path())
			if art != null:
				return art
	return null


## A texture, or null if the file is not there. A missing mark must never take
## the screen with it.
func _art_at(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _build_tools() -> void:
	for child: Node in _tools.get_children():
		_tools.remove_child(child)
		child.queue_free()

	# Built from the enum rather than from a list. The list said Weapon, Armour
	# and Charm, and when five slots were added on 2026-09-01 a helm was
	# reachable only through "All" - the filter did not know it existed, and
	# nothing failed to say so.
	var names: Array[String] = ["All"]
	for slot: int in GearData.Slot.size():
		names.append(GearData.name_of_slot(slot))
	# Last rather than first: the nine slots are what this screen is for, and a
	# tab that pushes them along by one is a tab that moved every button a
	# returning player already knew the position of.
	#
	# **"Fish" rather than "Consumables", and the width is the reason.** The
	# tabs sit in a three-column grid whose minimum width is three times the
	# widest button, so an eleven-character label against the six-character
	# slot names pushed the whole stash panel off a 430-wide phone -
	# `menu_layout_check` caught it at exactly that size. The tooltip carries
	# the longer word; if a second kind of consumable is ever kept here, this
	# becomes "Items", which still fits.
	names.append("Fish")
	for which: int in names.size():
		var index: int = which - 1
		if which == names.size() - 1:
			index = FILTER_PANTRY
		var tab := Button.new()
		tab.text = names[which]
		tab.toggle_mode = true
		tab.button_pressed = _filter == index
		tab.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 14)
		# **The mark a filter wears is the gear it filters for.** See
		# `_slot_mark`: drawn specially, it would be a ninth thing to keep in step
		# with the eight helmets.
		var mark: Texture2D = _slot_mark(index)
		if mark != null:
			tab.icon = mark
			tab.expand_icon = true
			tab.add_theme_constant_override("icon_max_width", TAB_ICON)
			tab.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		if index == FILTER_PANTRY:
			tab.tooltip_text = ("Consumables. What came out of the ponds, and the "
				+ "meals left this run.")
		tab.pressed.connect(func() -> void:
			_filter = index
			_refresh())
		_tools.add_child(tab)

	# **Sort.** Owner, 2026-09-17: *"add a sort button to the stash so that all
	# gear can be sorted in prioritized order of best to worst gear so that
	# players can easily quick sort their stash."*
	#
	# It tidies the *store* rather than the view, which is what makes it worth
	# pressing: every other reader of this list - a bulk break, a trade offer, the
	# Ledger - walks `MetaState.stash` by index, and after this they all walk it
	# best first. The list then shows the store's own order, so the button visibly
	# does the thing it says.
	var tidy := Button.new()
	tidy.text = "Sort  ·  best first" if not _best_first else "Sort  ·  by slot"
	tidy.tooltip_text = ("Puts the whole stash in order, best first, and keeps "
		+ "it that way. What you are wearing goes to the top.")
	tidy.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
	tidy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tidy.add_theme_font_size_override("font_size", 14)
	tidy.pressed.connect(func() -> void:
		if _best_first:
			_best_first = false
			_message = "Back to reading by slot."
			_refresh()
			return
		# The same refusal breaking lives under, and for the same reason: an
		# offer names a piece by uid while every other reader works by index,
		# so reordering under an open trade is a race whose loser is gear.
		if not MetaState.sort_stash():
			_message = "Not while a trade is open."
			_refresh()
			return
		_best_first = true
		_message = "Sorted %d pieces, best first." % MetaState.stash.size()
		_refresh())
	_tools.add_child(tidy)

	# **Upgrades only.** Not a toggle button: `menu_check` counts the toggles in
	# this grid as the slot filters, and this is a reading of the list rather
	# than a slot. The words say which way it is set.
	var better := Button.new()
	better.text = "Upgrades  ·  showing" if _upgrades_only else "Upgrades only"
	better.tooltip_text = ("Only pieces that beat what you are wearing in their "
		+ "slot, by attribute points. Press again for everything.")
	better.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
	better.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	better.add_theme_font_size_override("font_size", 14)
	better.pressed.connect(func() -> void:
		_upgrades_only = not _upgrades_only
		_refresh())
	_tools.add_child(better)

	# Two thresholds rather than one "break everything": the first is chaff a
	# player will never wear, the second is what a mid-run stash fills with. Both
	# stop below Fine, because breaking a Fine piece is a decision.
	for rarity: int in 2:
		var sweep := Button.new()
		sweep.text = "Break all %s" % Stash.RARITY_NAMES[rarity]
		sweep.tooltip_text = ("Breaks every unequipped, un-upgraded %s piece for shards. "
			+ "Never touches what you are wearing.") % Stash.RARITY_NAMES[rarity]
		sweep.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
		sweep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sweep.add_theme_font_size_override("font_size", 14)
		sweep.theme_type_variation = &"DangerButton"
		# A full row each: "Break all Worn" beside a slot filter reads as another
		# filter, and it is the one control on this screen that destroys things.
		sweep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var threshold: int = rarity
		# **Nothing is destroyed while a trade is open.** A piece broken while it
		# sits on the trade table is a race whose loser is a player's gear: the
		# offer still names it, the settlement resolves the name, and what it
		# finds is whatever moved into that position. Refused with words rather
		# than greyed out, because a disabled button on a screen the player did
		# not open the trade from explains nothing.
		sweep.pressed.connect(func() -> void:
			if TradeBooth.is_trading():
				_message = "Not while a trade is open."
				_refresh()
				return
			var broken: int = _break_all(threshold)
			_message = "Broke %d piece%s for shards." % [broken,
				"" if broken == 1 else "s"]
			_refresh())
		_tools.add_child(sweep)
		var sale := Button.new()
		sale.text = "Sell all %s" % Stash.RARITY_NAMES[rarity]
		sale.tooltip_text = ("Sells every unequipped, unmarked %s piece for Marks. "
			+ "Never touches what you are wearing.") % Stash.RARITY_NAMES[rarity]
		sale.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
		sale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sale.add_theme_font_size_override("font_size", 14)
		sale.pressed.connect(func() -> void:
			if TradeBooth.is_trading():
				_message = "Not while a trade is open."
				_refresh()
				return
			var sold: int = _sell_all(threshold)
			_message = "Sold %d piece%s for Marks." % [sold, "" if sold == 1 else "s"]
			_refresh())
		_tools.add_child(sale)

	# The way into a trade, and the only one. Drawn beside the bulk tools
	# because that is where a player is already standing when they decide a
	# piece is somebody else's problem.
	if Coop.partner_present():
		var trade := Button.new()
		trade.text = "Trade with %s" % _partner_name()
		trade.custom_minimum_size = Vector2(0.0, 36.0)
		trade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trade.add_theme_font_size_override("font_size", 13)
		trade.pressed.connect(func() -> void:
			var refusal: String = TradeBooth.invite()
			_message = refusal if not refusal.is_empty() \
				else "Asked to trade. Waiting for an answer."
			_refresh())
		_tools.add_child(trade)


func _partner_name() -> String:
	for seat: Variant in Coop.party().seats():
		var person := seat as CoopParty.Seat
		if person != null and person.slot != Coop.party().slot():
			return person.name
	return "your partner"


func _refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_build_tools()
	_dress_doll()
	_build_tiles()
	_build_sheet()
	if _compare != null:
		_compare.hide_pair()
	_header.text = "Stash  ·  %d Marks  ·  %d Shards" % [MetaState.marks, MetaState.shards]
	var worn: Array[int] = MetaState.gear_attribute_points()
	var parts: PackedStringArray = []
	for index: int in ATTRIBUTE_NAMES.size():
		if worn[index] > 0:
			parts.append("+%d %s" % [worn[index], ATTRIBUTE_NAMES[index]])
	_note.text = "%d of %d held%s  ·  full-stash drops auto-break into Shards" % [
		MetaState.stash.size(), Balance.STASH_CAPACITY,
		"  ·  equipped: " + ", ".join(parts) if not parts.is_empty() else ""]
	if not _message.is_empty():
		_note.text += "   ·   " + _message
		_message = ""

	if _filter == FILTER_PANTRY:
		_build_pantry()
		return

	if MetaState.stash.is_empty():
		var empty := Label.new()
		empty.text = "Nothing yet. Gear can fall on the battlefield or come out of raid chests."
		empty.add_theme_color_override("font_color", Color("8f9b98"))
		_list.add_child(empty)
		return

	var stripe: int = 0
	for index: int in _sorted_indices():
		_list.add_child(_stripe(_row(index), stripe))
		stripe += 1


## The pantry: what was pulled out of the ponds, and the button that eats it.
##
## The note says how many meals are left rather than how many fish are held,
## because the meals are the scarce thing. A larder of forty that can be eaten
## three times a run is three decisions, not forty.
func _build_pantry() -> void:
	var meals: String = "%d meal%s left this run" % [RunState.meals_left(),
		"" if RunState.meals_left() == 1 else "s"]
	if not GameDirector.run_active:
		meals = "Fish are eaten on the road"
	var progress: Vector2 = MetaState.profession_progress("angler")
	_note.text = "Angler %d  ·  %d / %d  ·  %d of %d kept  ·  %s" % [
		MetaState.profession_level("angler"), int(progress.x), int(progress.y),
		MetaState.fish_total(), Balance.FISH_STASH_CAPACITY, meals]
	if not _message.is_empty():
		_note.text += "   ·   " + _message
		_message = ""

	if MetaState.fish.is_empty():
		var empty := Label.new()
		empty.text = ("Nothing in the larder. Find a pond at the edge of the field, "
			+ "cast, hook the bite, and reel it in.")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", Color("8f9b98"))
		_list.add_child(empty)
		return

	var ids: Array = MetaState.fish.keys()
	ids.sort()
	for value: Variant in ids:
		var kind: FishData = ContentDB.fish(String(value))
		if kind != null:
			_list.add_child(_fish_row(kind))


func _fish_row(kind: FishData) -> Container:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var art: String = kind.get_sprite_path()
	if ResourceLoader.exists(art):
		icon.texture = load(art) as Texture2D
	icon.tooltip_text = kind.description
	row.add_child(icon)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var restores: PackedStringArray = []
	if kind.heal_fraction > 0.0:
		restores.append("%d%% health" % int(round(kind.heal_fraction * 100.0)))
	if kind.shield_fraction > 0.0:
		restores.append("%d%% ward" % int(round(kind.shield_fraction * 100.0)))
	if kind.mana_fraction > 0.0:
		restores.append("%d%% mana" % int(round(kind.mana_fraction * 100.0)))
	label.text = "%s  ×%d\n%s  ·  %s" % [kind.display_name,
		MetaState.fish_count(kind.id), kind.rarity_name(),
		"restores " + ", ".join(restores) if not restores.is_empty()
			else "caught for the Food alone"]
	label.tooltip_text = kind.description
	label.add_theme_color_override("font_color",
		kind.rarity_colour().lerp(Color.WHITE, 0.35))
	row.add_child(label)

	# **Give it away.** A fish can go to the spirit at your shoulder or to a
	# player beside you who is hurt (owner brief, 2026-09-13). Both are offered
	# only when there is somebody to take it, because a button that always
	# refuses teaches nothing.
	var hero: Hero = _local_hero()
	if hero != null and hero.spirit != null and is_instance_valid(hero.spirit):
		var give := Button.new()
		give.text = "Feed spirit"
		give.custom_minimum_size = Vector2(126.0, ACTION_HEIGHT)
		give.tooltip_text = "Heals your spirit and stops it eating for a while."
		give.pressed.connect(func() -> void:
			_message = RunState.feed_spirit(kind.id)
			if _message.is_empty():
				_message = "Gave the %s to your spirit." % kind.display_name
			_refresh())
		row.add_child(give)
	if hero != null and hero.has_hurt_ally():
		var share := Button.new()
		share.text = "Share"
		share.custom_minimum_size = Vector2(96.0, ACTION_HEIGHT)
		share.tooltip_text = "Hands it to the hurt player beside you."
		share.pressed.connect(func() -> void:
			_message = RunState.feed_ally(kind.id)
			if _message.is_empty():
				_message = "Shared the %s." % kind.display_name
			_refresh())
		row.add_child(share)

	var eat := Button.new()
	eat.text = "Eat"
	eat.custom_minimum_size = Vector2(96.0, ACTION_HEIGHT)
	# Asked of `RunState`, which owns every reason this can fail, rather than
	# tested here - so the meal cap cannot be bypassed by a second caller.
	eat.pressed.connect(func() -> void:
		_message = RunState.eat_fish(kind.id)
		if _message.is_empty():
			_message = "Ate the %s." % kind.display_name
		_refresh())
	row.add_child(eat)
	return row


## Big enough that a 128px icon still reads at a glance, small enough that a
## full stash does not turn into a gallery.
## **How tall an item card stands.** Room for the name, what it is, and up to
## five bonus lines without the card growing under them.
## **How tall an item card stands**, and what each further row of bonuses adds.
##
## Measured rather than guessed: `stash_render_check` stands up the top rarity at
## full level in every slot and compares what the card reserves against what the
## content actually needs. At 104 the best gear in the game was **eight pixels
## short** - its last row of bonuses drawn under its own border, with nothing to
## say so, which is precisely the pieces a player cares about. [TUNE]
## The doll's column (docs/GEAR_REWORK_2026-09-28.md §5).
const DOLL_WIDTH: float = 292.0
const STAGE_HEIGHT: float = 210.0
const STAGE_TURN_SECONDS: float = 3.2
const STAGE_ART_SCALE: float = 1.4
const TILE_COLUMNS: int = 3
const TILE_SIZE: float = 84.0
const TILE_ICON: float = 52.0
const TILE_LABEL: float = 18.0
## How far above the bottom edge the comparison card sits.
const COMPARE_LIFT: float = 36.0
## The tallest the comparison card can be - a portrait over a two-line name,
## five attribute lines, two legendary lines and a two-line verdict - which is
## what the seat is chosen against, because the card's own minimum size is
## unlaid on the frame a hover asks for it. A seat safe for a card this tall is
## safe for the card that settles, since the settled card is inside it;
## `stash_doll_check` holds the settled height under this.
const COMPARE_TALL: float = 480.0
## Air between the card and the row it sits against.
const COMPARE_GAP: float = 8.0

const CARD_HEIGHT: float = 118.0

## What each row of bonuses past the first adds to a card's height.
const CARD_LINE: float = 21.0

## The options a card's menu offers. Ids rather than indices, so adding one in
## the middle cannot repoint the rest - the same trap `Role` and `Trigger` both
## fell into when data indexed an enum by number.
const MENU_EQUIP: int = 1
const MENU_UPGRADE: int = 2
const MENU_KEEP: int = 3
const MENU_SELL: int = 4
const MENU_BREAK: int = 5
const MENU_TEMPER: int = 6
## Set a gem: `MENU_SOCKET_FROM + i` names the i-th gem kind in `_gem_kinds()`;
## pry one out: `MENU_UNSOCKET_FROM + i` names the i-th socket.
const MENU_SOCKET_FROM: int = 100
const MENU_UNSOCKET_FROM: int = 200

## The open menu, so a second press replaces it rather than stacking on it.
var _menu: PopupMenu = null

const ICON_SIZE: float = 72.0

## How many bonuses a card lays across its width. One column left two thirds of
## the plate empty and made a six-affix piece two hundred units tall.
const CARD_COLUMNS: int = 2


## A row's own backing: every other one lifted, the one under the pointer
## lifted further, and a hairline under it.
##
## A stash of ninety-six pieces with four buttons a row is a wall, and the
## owner reported losing which button belonged to which piece. Striping is
## the cheapest fix that survives any width; the hover is what makes the
## click feel aimed.
func _stripe(row: Control, index: int) -> Container:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Balance.ROW_STRIPE if index % 2 == 1 else Color(0, 0, 0, 0)
	style.border_width_bottom = int(Balance.ROW_RULE_HEIGHT)
	style.border_color = Balance.ROW_RULE
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var lit := StyleBoxFlat.new()
	lit.bg_color = Balance.ROW_HOVER
	lit.border_width_bottom = int(Balance.ROW_RULE_HEIGHT)
	lit.border_color = Balance.ROW_RULE
	lit.content_margin_left = 6.0
	lit.content_margin_right = 6.0
	lit.content_margin_top = 3.0
	lit.content_margin_bottom = 3.0
	panel.mouse_entered.connect(func() -> void:
		panel.add_theme_stylebox_override("panel", lit))
	panel.mouse_exited.connect(func() -> void:
		panel.add_theme_stylebox_override("panel", style))
	panel.add_child(row)
	return panel


## **An item card.**
##
## Owner, 2026-09-16: Diablo IV's item cards in a scrollable list, and a menu when
## you press one.
##
## The row used to carry five action buttons - `ACTION_WIDTH * 5` is 660 units of
## a 940-unit panel - so the piece's own name got about two hundred and a
## Beastcalled sword wrapped to eight lines. Widening the name and shrinking the
## buttons trade against each other; taking the actions off the row is what
## actually buys the space, and it gives each of them a full-width target in the
## menu instead of a fifth of one.
func _row(index: int) -> Container:
	var piece: Dictionary = MetaState.stash[index]
	var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
	var tint: Color = Stash.rarity_colour(piece)
	var is_worn: bool = MetaState.is_equipped_index(index)

	# The whole card is the button: "click on an item to open a dropdown menu".
	# **As tall as what is printed on it.** A fixed height clipped the last bonus
	# off anything with three or more, which is precisely the pieces worth
	# reading - a `Button` does not grow with an anchored child, so the height is
	# counted rather than hoped for.
	var lines: int = 0
	if kind != null:
		lines = Stash.affixes(piece, kind).size() \
			+ Stash.legendary_affixes(piece, kind).size()
	# The gems, the empty sockets and the tempering are lines too, or the card
	# clips exactly the lines that say what a piece can still take.
	lines += Stash.gem_affixes(piece).size()
	if Stash.sockets(piece) > Stash.gems(piece).size():
		lines += 1
	if Stash.tempers(piece) > 0:
		lines += 1
	# **Two to a row**, so the bonuses use the card's width instead of running
	# down one narrow column beside two thirds of empty plate. A six-affix piece
	# was two hundred units tall; it is three rows now.
	var rows: int = int(ceil(float(lines) / float(CARD_COLUMNS)))
	var card := Button.new()
	card.custom_minimum_size = Vector2(0.0,
		CARD_HEIGHT + float(maxi(rows - 1, 0)) * CARD_LINE)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("normal", _card_plate(tint, is_worn, 0.0))
	card.add_theme_stylebox_override("hover", _card_plate(tint, is_worn, 0.34))
	card.add_theme_stylebox_override("pressed", _card_plate(tint, is_worn, 0.5))
	card.add_theme_stylebox_override("focus", _card_plate(tint, is_worn, 0.34))
	card.tooltip_text = kind.description if kind != null else "Unknown"
	card.pressed.connect(func() -> void: _open_item_menu(index, card))
	# **The comparison on hover and on focus** - a hover wired only to the
	# mouse is a feature for one of the three ways this game is played. Never
	# for a worn piece: comparing a piece with itself says nothing.
	if not is_worn:
		card.mouse_entered.connect(func() -> void: _compare_to_worn(piece, card))
		card.focus_entered.connect(func() -> void: _compare_to_worn(piece, card))
		card.mouse_exited.connect(func() -> void: _hide_compare())
		card.focus_exited.connect(func() -> void: _hide_compare())

	var face := HBoxContainer.new()
	face.add_theme_constant_override("separation", 12)
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 16.0
	face.offset_right = -16.0
	face.offset_top = 10.0
	face.offset_bottom = -10.0
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(face)

	# **The mark, in a recess.** Every gear kind has authored art at
	# `icons/ui/ui_<id>.png` - the same file the blade in the hero's hand is
	# drawn from - and framing it is what stops a list of loot reading as a
	# spreadsheet with pictures in the margin.
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _icon_recess(tint, is_worn))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind != null:
		var art: String = kind.get_sprite_path()
		if ResourceLoader.exists(art):
			icon.texture = load(art) as Texture2D
		icon.modulate = tint.lerp(Color.WHITE, 0.45)
	frame.add_child(icon)
	face.add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(column)

	var name_line := Label.new()
	name_line.text = "%s %s" % [Stash.rarity_name(piece),
		kind.display_name if kind != null else "Unknown"]
	name_line.add_theme_font_size_override("font_size", 20)
	name_line.add_theme_color_override("font_color", tint.lerp(Color("efe9dc"), 0.25))
	name_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_line)

	var what := Label.new()
	what.text = "%s  ·  Level %d%s" % [
		kind.slot_name() if kind != null else "-", int(piece.get("level", 1)),
		"  ·  EQUIPPED" if is_worn else ""]
	what.add_theme_font_size_override("font_size", 15)
	what.add_theme_color_override("font_color", Color("8d968f"))
	what.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(what)

	# **The bonuses as rows.** A comma-separated tail on the end of the name is
	# what made the name unreadable; a piece's numbers are what a player is
	# comparing and they deserve their own lines.
	if kind != null:
		var said: Array[Label] = []
		for affix: Dictionary in Stash.affixes(piece, kind):
			var which: int = clampi(int(affix["attribute"]), 0,
				ATTRIBUTE_NAMES.size() - 1)
			said.append(_stat_line("+%d %s" % [int(affix["points"]),
				ATTRIBUTE_NAMES[which]], tint))
		for legend: GearAffixData in Stash.legendary_affixes(piece, kind):
			said.append(_stat_line(legend.line(), tint.lightened(0.2)))
		# The set gems and the empty sockets, so what a piece can still take is
		# read on the line the player chooses on.
		for gem: Dictionary in Stash.gem_affixes(piece):
			var stone: MaterialData = ContentDB.material(String(gem["gem"]))
			said.append(_stat_line("%s: %s +%d%%" % [stone.display_name if stone != null else String(gem["gem"]),
				Modifiers.label(String(gem["key"])), int(round(float(gem["magnitude"]) * 100.0))],
				tint.lightened(0.35)))
		var free_sockets: int = Stash.sockets(piece) - Stash.gems(piece).size()
		if free_sockets > 0:
			said.append(_stat_line("%d empty socket%s" % [free_sockets, "" if free_sockets == 1 else "s"],
				Color("8d968f")))
		if Stash.tempers(piece) > 0:
			said.append(_stat_line("Tempered x%d" % Stash.tempers(piece), Color("8d968f")))
		var grid := GridContainer.new()
		grid.columns = CARD_COLUMNS
		grid.add_theme_constant_override("h_separation", 22)
		grid.add_theme_constant_override("v_separation", 1)
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for said_line: Label in said:
			said_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(said_line)
		column.add_child(grid)

	# **The marker reads as a control**, on a plate of its own rather than as grey
	# text at the far edge. Words rather than a glyph: no bundled font carries
	# U+203A any more than it carries the hearts this screen already learned not
	# to use, and a marker that renders as a box teaches nothing.
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", _icon_recess(tint))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chevron := Label.new()
	chevron.text = "OPTIONS"
	chevron.add_theme_font_size_override("font_size", 14)
	chevron.add_theme_color_override("font_color", tint.lerp(Color("cfd6d0"), 0.5))
	chevron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chevron.custom_minimum_size = Vector2(92.0, 0.0)
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(chevron)
	face.add_child(tag)
	return _wrap_card(card)


## Lays the hovered piece beside whatever is worn in its slot - and never over
## the row it is comparing.
##
## Photographed on 2026-09-28: anchored to the bottom of the screen as the
## Market's card is, it covered the hovered row and every row under it, which
## on a list that fills the screen is most of what the player is reading. The
## Market's shelf is eight rows and leaves the bottom empty; the stash's list
## does not. So the card takes the filter grid's own ground first - a block
## nobody is pressing while they hover a row - and falls back to the bottom
## only when the row is up there. `_seat_compare` picks whichever of the two
## covers the hovered row least, so a row is never hidden by its own card.
func _compare_to_worn(piece: Dictionary, row: Control = null) -> void:
	if _compare == null or not is_instance_valid(_compare):
		return
	_compare.show_pair(piece)
	_compare_row = row
	if _compare.visible:
		_seat_compare(row)
		# **The card follows the row.** A refit re-lays the panel over several
		# passes and a wheel scrolls the list under the pointer; the row's own
		# rect signal fires after each move, which is the one moment its rect
		# is true - a frame count after a refit read it mid-layout and seated
		# the card off the bottom of a narrow screen.
		if row != null and is_instance_valid(row) \
				and not row.item_rect_changed.is_connected(_on_compare_row_moved):
			row.item_rect_changed.connect(_on_compare_row_moved)


## The card's two seats, in the layer's own space - which is the screen's,
## since the card hangs off the layer and not off the panel: over the filter
## grid, or along the bottom. Centred on the list rather than on the screen,
## so the doll's column is never under it.
##
## **Chosen against a ceiling rather than the card's own height.** On the
## frame a hover fills it, every autowrapped label in it is still unlaid and
## reports the height it would have at a width of nothing - a thousand units
## for a card that settles at about two hundred and sixty - so its minimum
## size is a lie until the next layout pass. The card is anchored at its seat
## and grows from there as that settles; the seat itself is picked against
## the tallest the card can ever be (`COMPARE_TALL`), which errs toward
## keeping clear of the row.
func _seat_compare(row: Control) -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var wide: float = _compare.get_combined_minimum_size().x
	var centre_x: float = screen.x * 0.5
	var scroll_top: float = 0.0
	if _scroll != null and is_instance_valid(_scroll) and _scroll.is_visible_in_tree():
		var lane: Rect2 = _scroll.get_global_rect()
		centre_x = lane.get_center().x
		scroll_top = lane.position.y
	# The fallback's upper seat is the lane's own top. The filter grid's rect
	# was read here once and it is a child re-laid *after* the lane, so between
	# a refit's passes it read where the grid had been - which seated the card
	# off the bottom of a narrow screen.
	var top_y: float = scroll_top
	var left: float = clampf(centre_x - wide * 0.5, 0.0, maxf(screen.x - wide, 0.0))
	var floor_y: float = screen.y - COMPARE_LIFT
	# **Against the row first, and the two fixed seats only when the row leaves
	# no room.** Two fixed seats - over the filter grid, along the bottom - can
	# never both clear a row that sits between them, and the release sweep of
	# 2026-09-29 laid one exactly there on its shared profile: the settled card
	# overlapped it by six units. So the card is pinned just above the hovered
	# row when the ceiling fits above it, just below when it fits below, and
	# grows away from the row from that edge - which is what a tooltip does, and
	# what leaves the row being read uncovered on any layout. Only a row with
	# no room either side falls back to whichever fixed seat covers it least.
	var anchor_y: float = top_y
	var grow: int = Control.GROW_DIRECTION_END
	if row != null and is_instance_valid(row):
		var hovered: Rect2 = row.get_global_rect()
		if hovered.position.y - COMPARE_GAP - COMPARE_TALL >= 0.0:
			anchor_y = hovered.position.y - COMPARE_GAP
			grow = Control.GROW_DIRECTION_BEGIN
		elif hovered.end.y + COMPARE_GAP + COMPARE_TALL <= screen.y:
			anchor_y = hovered.end.y + COMPARE_GAP
			grow = Control.GROW_DIRECTION_END
		else:
			var top_seat := Rect2(left, top_y, wide, COMPARE_TALL)
			var bottom_seat := Rect2(left, floor_y - COMPARE_TALL, wide, COMPARE_TALL)
			if bottom_seat.intersection(hovered).get_area() < top_seat.intersection(hovered).get_area():
				anchor_y = floor_y
				grow = Control.GROW_DIRECTION_BEGIN
	# Whatever was read, the card at its ceiling stays on the screen.
	if grow == Control.GROW_DIRECTION_END:
		anchor_y = clampf(anchor_y, 0.0, maxf(screen.y - COMPARE_TALL, 0.0))
	else:
		anchor_y = clampf(anchor_y, minf(COMPARE_TALL, screen.y), screen.y)
	# A zero rect at the anchor, grown by the card's own minimum size - so the
	# frame follows the content as it settles rather than keeping the lie.
	_compare.offset_left = left
	_compare.offset_right = left
	_compare.grow_vertical = grow
	_compare.offset_top = anchor_y
	_compare.offset_bottom = anchor_y


func _hide_compare() -> void:
	if _compare_row != null and is_instance_valid(_compare_row) \
			and _compare_row.item_rect_changed.is_connected(_on_compare_row_moved):
		_compare_row.item_rect_changed.disconnect(_on_compare_row_moved)
	_compare_row = null
	if _compare != null and is_instance_valid(_compare):
		_compare.hide_pair()


func _on_compare_row_moved() -> void:
	if _compare == null or not is_instance_valid(_compare) or not _compare.visible:
		return
	if _compare_row == null or not is_instance_valid(_compare_row):
		return
	_seat_compare(_compare_row)


## A refit moves the lane, and the card is seated in the lane's own space -
## so it follows, once the containers have re-laid. Two passes, because a
## wrapped label knows its height only once it has its width; photographed
## before this, the narrow picture had the card where the wide lane's centre
## had been, half off the right of the screen.
func _reseat_after_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _compare == null or not is_instance_valid(_compare) or not _compare.visible:
		return
	if _compare_row == null or not is_instance_valid(_compare_row):
		_hide_compare()
		return
	_seat_compare(_compare_row)


## A card sits in a plain container so the list's own layout is unchanged.
func _wrap_card(card: Control) -> Container:
	var holder := HBoxContainer.new()
	holder.add_child(card)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return holder


func _stat_line(text: String, tint: Color) -> Label:
	var line := Label.new()
	line.text = text
	line.add_theme_font_size_override("font_size", 16)
	line.add_theme_color_override("font_color", tint.lerp(Color("cfd6d0"), 0.55))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## The plate a piece is printed on, edged in its rarity.
##
## A worn piece is edged brighter rather than labelled only: a stash of ninety-six
## is scanned before any of the words are read.
## **What a piece you are wearing looks like** (owner, 2026-09-22: as well as
## the rename, *"add extra indicators or highlights around the item slot"*).
##
## It differed from an unworn card by a border alpha of 0.75 against 0.42,
## which in a list of forty cards in rarity colours is not a difference anybody
## reads. A worn card is now framed on all four sides in gold rather than in
## its own rarity, and sits on a warmer plate: gold is the one colour in this
## screen that means nothing else, so it cannot be confused with a rarity, and
## a frame all the way round reads at a glance where a thicker left edge does
## not.
const WORN_GOLD: Color = Color(0.94, 0.78, 0.40)


func _card_plate(tint: Color, worn: bool, lift: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var edge: Color = WORN_GOLD if worn else tint
	box.bg_color = Color(0.068, 0.074, 0.078, 0.94).lerp(
		Color(edge.r, edge.g, edge.b, 0.94),
		(0.13 if worn else 0.05) + lift * 0.10)
	box.border_color = Color(edge.r, edge.g, edge.b,
		(0.92 if worn else 0.42) + lift * 0.4)
	box.border_width_left = 5 if worn else 4
	box.border_width_top = 2 if worn else 1
	box.border_width_bottom = 2 if worn else 1
	box.border_width_right = 2 if worn else 1
	box.set_corner_radius_all(6)
	box.set_content_margin_all(2.0)
	return box


## The well the icon sits in. Rung in gold on a worn piece, so the indicator
## reaches the part of the card a player is actually looking at.
func _icon_recess(tint: Color, worn: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.035, 0.038, 0.92)
	var edge: Color = WORN_GOLD if worn else tint
	box.border_color = Color(edge.r, edge.g, edge.b, 0.80 if worn else 0.35)
	box.set_border_width_all(2 if worn else 1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(4.0)
	return box


## **What you can do with this piece**, as a menu the card opens.
##
## A `PopupMenu` rather than a panel this screen lays out: it knows where the
## edges of the screen are, closes on a press elsewhere, and answers a pad and a
## keyboard without any of that being written twice. The items carry the same
## enabled state the buttons carried, so a Kept piece still cannot be sold by
## accident.
func _open_item_menu(index: int, near: Control) -> void:
	if index < 0 or index >= MetaState.stash.size():
		return
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
	var piece: Dictionary = MetaState.stash[index]
	var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
	var is_worn: bool = MetaState.is_equipped_index(index)
	var marked: bool = Stash.is_favourite(piece)
	var cost: Dictionary = Stash.upgrade_cost(piece)

	var menu := PopupMenu.new()
	menu.add_theme_font_size_override("font_size", 16)
	_menu = menu
	add_child(menu)

	menu.add_item("Remove" if is_worn else "Equip", MENU_EQUIP)
	menu.set_item_disabled(menu.get_item_index(MENU_EQUIP), kind == null)
	if cost.is_empty():
		menu.add_item("Fully upgraded", MENU_UPGRADE)
		menu.set_item_disabled(menu.get_item_index(MENU_UPGRADE), true)
	else:
		menu.add_item("Upgrade to level %d  ·  %d shards, %d marks" % [
			int(piece.get("level", 1)) + 1, int(cost["shards"]), int(cost["marks"])],
			MENU_UPGRADE)
		menu.set_item_disabled(menu.get_item_index(MENU_UPGRADE),
			MetaState.shards < int(cost["shards"]) or MetaState.marks < int(cost["marks"]))
	# Sockets and tempering (docs/GEAR_REWORK_2026-09-28.md §3-4), each with
	# its price on it before anything is spent - the Forge's own rule.
	var sockets: int = Stash.sockets(piece)
	if sockets > 0:
		menu.add_separator()
		var set_gems: Array[String] = Stash.gems(piece)
		for at: int in set_gems.size():
			var gem: MaterialData = ContentDB.material(set_gems[at])
			menu.add_item("Pry out %s  ·  %d marks" % [gem.display_name if gem != null else set_gems[at],
				Stash.unsocket_cost(set_gems[at])], MENU_UNSOCKET_FROM + at)
			menu.set_item_disabled(menu.get_item_index(MENU_UNSOCKET_FROM + at),
				MetaState.marks < Stash.unsocket_cost(set_gems[at]))
		var kinds: Array[MaterialData] = _gem_kinds()
		for at: int in kinds.size():
			var gem: MaterialData = kinds[at]
			var held: int = MetaState.material_count(gem.id)
			var problem: String = Stash.socket_problem(piece, gem.id, kind)
			menu.add_item("Set %s  ·  socket %d of %d  ·  %d held" % [gem.display_name,
				mini(set_gems.size() + 1, sockets), sockets, held], MENU_SOCKET_FROM + at)
			menu.set_item_disabled(menu.get_item_index(MENU_SOCKET_FROM + at),
				held <= 0 or not problem.is_empty())
			if not problem.is_empty():
				menu.set_item_tooltip(menu.get_item_index(MENU_SOCKET_FROM + at), problem)
	var temper: Dictionary = Stash.temper_cost(piece)
	if temper.is_empty():
		menu.add_item("Tempered %d of %d times" % [Stash.tempers(piece), Balance.GEAR_TEMPER_MAX], MENU_TEMPER)
		menu.set_item_disabled(menu.get_item_index(MENU_TEMPER), true)
	else:
		menu.add_item("Temper (reroll its bonuses)  ·  %d shards, %d marks  ·  %d of %d" % [
			int(temper["shards"]), int(temper["marks"]), Stash.tempers(piece) + 1, Balance.GEAR_TEMPER_MAX],
			MENU_TEMPER)
		menu.set_item_disabled(menu.get_item_index(MENU_TEMPER),
			MetaState.shards < int(temper["shards"]) or MetaState.marks < int(temper["marks"]))
	menu.add_separator()
	menu.add_item("Unmark as kept" if marked else "Mark as kept", MENU_KEEP)
	menu.add_item("Sell  ·  %d marks" % Stash.sell_price(piece), MENU_SELL)
	menu.set_item_disabled(menu.get_item_index(MENU_SELL), marked)
	menu.add_item("Break for %d shards" % Stash.salvage_yield(piece), MENU_BREAK)
	menu.set_item_disabled(menu.get_item_index(MENU_BREAK), marked)

	menu.id_pressed.connect(func(id: int) -> void: _do_item_action(index, id))
	menu.popup_hide.connect(func() -> void: menu.queue_free())
	var at: Vector2 = near.get_screen_position() + Vector2(near.size.x * 0.4, near.size.y)
	menu.popup(Rect2i(Vector2i(at), Vector2i(340, 0)))


## A gear door's answer, said and heard, and the list re-read.
func _attempt_gear(answer: String) -> void:
	if answer.is_empty():
		Sfx.play_group("sfx_hit_stone", -6.0)
	else:
		Sfx.play("sfx_ui_deny", -4.0)
		EventBus.preparation_warning.emit(answer)
	_refresh()


## One place every action a piece has is carried out, so the menu and anything
## that ever drives it cannot disagree about what "sell" does.
## The gems that grant something set, in a fixed order for the menu.
func _gem_kinds() -> Array[MaterialData]:
	var out: Array[MaterialData] = []
	for value: Variant in ContentDB.materials.values():
		var gem := value as MaterialData
		if gem != null and gem.kind == MaterialData.Kind.GEM and not gem.gem_key.is_empty():
			out.append(gem)
	out.sort_custom(func(a: MaterialData, b: MaterialData) -> bool: return a.rarity < b.rarity)
	return out


func _do_item_action(index: int, id: int) -> void:
	if id >= MENU_UNSOCKET_FROM and index >= 0 and index < MetaState.stash.size():
		_attempt_gear(MetaState.unsocket_gem(Stash.uid(MetaState.stash[index]), id - MENU_UNSOCKET_FROM))
		return
	if id >= MENU_SOCKET_FROM and index >= 0 and index < MetaState.stash.size():
		var kinds: Array[MaterialData] = _gem_kinds()
		var at: int = id - MENU_SOCKET_FROM
		if at >= 0 and at < kinds.size():
			_attempt_gear(MetaState.socket_gem(Stash.uid(MetaState.stash[index]), kinds[at].id))
		return
	if id == MENU_TEMPER and index >= 0 and index < MetaState.stash.size():
		_attempt_gear(MetaState.temper_gear(Stash.uid(MetaState.stash[index])))
		return
	if index < 0 or index >= MetaState.stash.size():
		return
	var piece: Dictionary = MetaState.stash[index]
	var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
	match id:
		MENU_EQUIP:
			if kind == null:
				return
			# Through the one door: `MetaState.equip` names the piece rather
			# than its position, saves and says so.
			MetaState.equip(kind.slot,
				-1 if MetaState.is_equipped_index(index) else index)
		MENU_UPGRADE:
			var cost: Dictionary = Stash.upgrade_cost(piece)
			if cost.is_empty() or MetaState.shards < int(cost["shards"]) \
					or MetaState.marks < int(cost["marks"]):
				return
			MetaState.shards -= int(cost["shards"])
			MetaState.marks -= int(cost["marks"])
			piece["level"] = int(piece.get("level", 1)) + 1
			MetaState.save_game()
			EventBus.stash_changed.emit()
			Sfx.play("sfx_tower_upgrade")
		MENU_KEEP:
			Stash.set_favourite(piece, not Stash.is_favourite(piece))
			MetaState.save_game()
			EventBus.stash_changed.emit()
		# **Both of these destroy a piece, so both ask first** (owner,
		# 2026-09-18). A stash of a hundred and sixty rows is exactly where
		# the wrong one gets clicked, and neither Marks nor Shards buy a
		# particular piece back.
		MENU_SELL:
			if Stash.is_favourite(piece):
				return
			_ask_then(piece, kind, "Sell",
				"%d Marks" % Stash.sell_price(piece),
				func() -> void:
					MetaState.marks += Stash.sell_price(piece)
					MetaState.drop_gear(index)
					Sfx.play("sfx_tower_sell")
					_refresh())
			return
		MENU_BREAK:
			if Stash.is_favourite(piece):
				return
			_ask_then(piece, kind, "Break for parts",
				"%d Shards" % Stash.salvage_yield(piece),
				func() -> void:
					MetaState.shards += Stash.salvage_yield(piece)
					MetaState.drop_gear(index)
					Sfx.play("sfx_relic_socket")
					_refresh())
			return
	_refresh()


## Puts the trade to the player and runs `then` only if they agree.
##
## The piece is named in full and in its rarity colour, because that is the
## one thing that tells a player they clicked the row they meant to.
func _ask_then(piece: Dictionary, kind: GearData, title: String,
	getting: String, then: Callable) -> void:
	var named: String = Stash.display_name(piece, kind) if kind != null \
			else "this piece"
	var panel: SaleConfirm = SaleConfirm.ask(self, title, named, getting,
		Stash.rarity_colour(piece))
	panel.decided.connect(func(yes: bool) -> void:
		if yes:
			then.call())


## One width and one height for all four row actions.
##
## They carried four different widths and four different labels, so every row
## began its buttons at a different x and the list read as ragged. Equal boxes
## line the column up whatever the numbers say.
##
## Marked `SELF_SIZED` with a dense target, the same way the in-run build sheet
## is: the generic 120-unit thumb floor is right for an isolated control and
## wrong for a list of ninety-six, where it leaves three rows visible on a phone.
## `ACTION_HEIGHT` is comfortably above the 44-48 both platform guidelines ask
## for, and `layout_check` reads the same meta rather than a copy of it.
## **The narrowest a piece's name may be squeezed to on a desktop row.**
##
## Five actions at `ACTION_WIDTH` are 660 units of a 940-unit panel, and with the
## icon that left a name about two hundred wide - so "Chainbroken Coalpaint Edge
## - Weapon - Lv3 - +6 Might, +3 Vigour..." wrapped to eight lines and the row
## stood a hundred and twenty units tall. A name is the thing the list exists to
## be read for; it gets a measure. [TUNE]
const NAME_FLOOR: float = 300.0

const ACTION_WIDTH: float = 132.0
const ACTION_HEIGHT: float = 40.0
## Horizontal frame padding for a row action, against the theme's 34. See
## `_size_action` for why these four are the exception.
const ACTION_PAD_X: float = 12.0


func _size_action(button: Button) -> void:
	# The touch height is the build sheet's dense target, not the generic thumb
	# floor. `SELF_SIZED` stops UiMetrics resizing the box but it still grows the
	# *font* to `UI_TOUCH_MIN_FONT_SIZE`, so a 40-unit box would have 26px type
	# and 28 units of frame padding to fit into and would simply overflow.
	var height: float = Balance.UI_TOUCH_BUILD_TARGET_HEIGHT \
		if TouchInput.is_showing() else ACTION_HEIGHT
	button.custom_minimum_size = Vector2(0.0, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Clipped rather than allowed to widen: the box is the layout, and a long
	# number must not be able to push its neighbours out of line.
	button.clip_text = true
	# And the frame is narrowed for these four specifically. The theme pads a
	# button by 34 units each side to clear the corner bolts on `ui_button`,
	# which is right for a menu and leaves a 132-unit action button 64 units of
	# room - so "Sell 120" rendered as "Sell 12" and "Break 11" as "Break".
	# These sit in a dense column where the bolts are not the point.
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBox = button.get_theme_stylebox(state, "Button")
		if box == null:
			continue
		var tight: StyleBox = box.duplicate() as StyleBox
		tight.content_margin_left = ACTION_PAD_X
		tight.content_margin_right = ACTION_PAD_X
		button.add_theme_stylebox_override(state, tight)
	button.set_meta(UiMetrics.SELF_SIZED, true)
	button.set_meta(UiMetrics.TOUCH_TARGET_HEIGHT, height)


## The hero this screen belongs to, or null between runs.
##
## Found through the group rather than held, because the stash outlives any
## one battlefield and a stale reference here would be a crash on the second
## run rather than on the first.
func _local_hero() -> Hero:
	if not GameDirector.run_active:
		return null
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP):
		var who := node as Hero
		if who != null and is_instance_valid(who) and who.is_local_player():
			return who
	return null
