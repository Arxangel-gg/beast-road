class_name VendorScreen
extends CanvasLayer

## **The Market**: the vendor's own wares, and the door to the Long Ledger.
##
## Owner brief, 2026-09-17: the Ledger belongs *inside* a vendor's shop, the
## vendor sells their own gear on a shelf that refreshes on a real run or every
## ten minutes, and the shop itself should be somewhere worth standing in.
##
## **The shelf is `VendorStock`'s and the screen never rolls one.** Every rule
## the brief names - the ten minutes, the two-minute run, keeping the same
## stock across a restart, trailing the Warden's own rarity - lives on that
## class, so this window can be opened, closed and reopened as often as anybody
## likes without a single ware changing. The gate drives `VendorStock`; this
## draws it.
##
## **The Ledger is a door rather than a tab.** It is its own screen with its own
## escrow, its own orders and its own bound, and a copy of it inside this one
## would be a second place for prices to be wrong. The shop shows the poster on
## the wall and opens the real thing.

signal closed()
## The player asked for the Long Ledger. The menu owns that screen, so the shop
## asks for it rather than holding one - the same split every door in the Hold
## is built on.
signal ledger_wanted()

const PANEL_WIDTH: float = 1040.0
const ICON_SIZE: float = 46.0
const HEADER_HEIGHT: float = 120.0
const HEADER_MIN_SCREEN: float = 900.0
const SHOP_ART: String = "res://art/city/building_market.png"
const KEEPER_ART: String = "res://art/city/merchant_quartermaster.png"
const ATTRIBUTE_NAMES: Array[String] = ["Might", "Vigour", "Swiftness", "Focus", "Resolve"]

var _panel: PanelContainer
var _heading: Label
var _note: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _purse: Label
var _result: Label
var _close_button: Button
var _art: TextureRect = null
var _compare: GearCompare = null


func _ready() -> void:
	# Every plate, button and bar on this screen gets the standing animation
	# and the hover hologram (owner, 2026-09-17). **Deferred**, because a
	# screen builds its own children further down this same function -
	# enrolled here and now it would dress an empty `Control` and nothing else.
	UiJuice.enrol.call_deferred(get_tree(), self)
	layer = 92
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(_refit)
	visible = false


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.03, 0.02, 0.9)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	# The stall and the person behind it, side by side. A shop header with only
	# the building in it is a picture of a door.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.custom_minimum_size = Vector2(0.0, HEADER_HEIGHT)
	column.add_child(header)
	_art = _picture(SHOP_ART)
	if _art != null:
		_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(_art)
	var keeper: TextureRect = _picture(KEEPER_ART)
	if keeper != null:
		keeper.custom_minimum_size = Vector2(HEADER_HEIGHT, HEADER_HEIGHT)
		header.add_child(keeper)

	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 22)
	_heading.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(_heading)

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", Color("b8ae98"))
	column.add_child(_note)

	_scroll = ScrollContainer.new()
	UiMetrics.prepare_scroll(_scroll, TouchInput.is_showing())
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	_scroll.add_child(_rows)

	_result = Label.new()
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.add_theme_font_size_override("font_size", 15)
	_result.add_theme_color_override("font_color", Color("d8d2c4"))
	column.add_child(_result)

	_purse = Label.new()
	_purse.add_theme_font_size_override("font_size", 15)
	_purse.add_theme_color_override("font_color", Color("e8d9a8"))
	column.add_child(_purse)

	# **The poster and the way out share the bottom row.** The Long Ledger is
	# a wanted list for gear - the owner's own image - and it belongs on this
	# screen; what it may not do is cost a landscape phone another 120-unit
	# line, which is what `menu_layout_check` refused when it sat on its own
	# above the shelf. Both of them are ways out of the list, so both are one
	# row.
	# **The comparison, over the shelf and never in front of the pointer.**
	# Added to the screen rather than into the column, so it floats over the
	# list instead of pushing it about - and `MOUSE_FILTER_IGNORE` throughout,
	# because it is opened by a hover and a panel that ate the pointer would
	# close itself the instant it appeared.
	_compare = GearCompare.new()
	_compare.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_compare.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_compare.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_compare)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	column.add_child(bottom)

	var ledger := Button.new()
	ledger.name = "LedgerDoor"
	ledger.text = "The Long Ledger"
	ledger.custom_minimum_size = Vector2(0.0, 44.0)
	ledger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	IconKit.on_button(ledger, "quiet_ledger", 24)
	ledger.pressed.connect(func() -> void: ledger_wanted.emit())
	bottom.add_child(ledger)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button.pressed.connect(hide_screen)
	bottom.add_child(_close_button)


func _picture(path: String) -> TextureRect:
	if not ResourceLoader.exists(path):
		return null
	var art := TextureRect.new()
	art.texture = load(path) as Texture2D
	art.custom_minimum_size = Vector2(0.0, HEADER_HEIGHT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return art


func open() -> void:
	visible = true
	_result.text = ""
	_refresh()
	_refit()
	_refit.call_deferred()
	_close_button.grab_focus()


## A card left open over a closed shop is a card that never closes.
func hide_screen() -> void:
	_hide_compare()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_screen()


func _refresh() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()

	_heading.text = "The Market  ·  Tessel keeps it"
	_note.text = ("What comes off the road ends up here, and what Tessel could "
		+ "not sell goes back out on it. She deals a little behind where you "
		+ "are and now and then a little ahead of it, and she never buys twice "
		+ "at the price she sells.\n" + VendorStock.refresh_line())

	var stock: Array = VendorStock.wares()
	if stock.is_empty():
		_rows.add_child(_line("The shelf is bare. Come back after a road."))
	for index: int in stock.size():
		var piece: Variant = stock[index]
		if piece is Dictionary:
			_rows.add_child(_ware_row(piece as Dictionary, index))

	_purse.text = "%d Marks  ·  %d Shards" % [MetaState.marks, MetaState.shards]


func _ware_row(piece: Dictionary, index: int) -> Container:
	var kind := ContentDB.gear_kinds.get(String(piece.get("kind", "")), null) as GearData
	var tint: Color = Stash.rarity_colour(piece)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if kind != null:
		var art: String = kind.get_sprite_path()
		if ResourceLoader.exists(art):
			icon.texture = load(art) as Texture2D
		icon.modulate = tint.lerp(Color.WHITE, 0.45)
	row.add_child(icon)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(column)

	var name_line := Label.new()
	name_line.text = "%s %s" % [Stash.rarity_name(piece),
		kind.display_name if kind != null else "Unknown"]
	name_line.add_theme_font_size_override("font_size", 18)
	name_line.add_theme_color_override("font_color", tint.lerp(Color("efe9dc"), 0.25))
	column.add_child(name_line)

	var said: PackedStringArray = []
	if kind != null:
		for affix: Dictionary in Stash.affixes(piece, kind):
			var which: int = clampi(int(affix["attribute"]), 0,
				ATTRIBUTE_NAMES.size() - 1)
			said.append("+%d %s" % [int(affix["points"]), ATTRIBUTE_NAMES[which]])
		for legend: GearAffixData in Stash.legendary_affixes(piece, kind):
			said.append(legend.line())
	var what := Label.new()
	what.text = "%s  ·  Level %d%s" % [kind.slot_name() if kind != null else "-",
		int(piece.get("level", 1)),
		"  ·  " + ", ".join(said) if said.size() > 0 else ""]
	what.add_theme_font_size_override("font_size", 14)
	what.add_theme_color_override("font_color", Color("8d968f"))
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(what)

	var asking: int = VendorStock.price(piece)
	var buy := Button.new()
	buy.text = "%d Marks" % asking
	buy.custom_minimum_size = Vector2(150.0, 44.0)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.disabled = MetaState.marks < asking
	buy.pressed.connect(func() -> void: _buy(index))
	# **The pad gets the same answer as the pointer**, which is `UiJuice`'s
	# standing rule and the one that is always forgotten: a comparison wired to
	# `mouse_entered` alone is a comparison for one of the three ways this game
	# is played.
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.mouse_entered.connect(func() -> void: _compare_to_worn(piece))
	row.mouse_exited.connect(func() -> void: _hide_compare())
	buy.focus_entered.connect(func() -> void: _compare_to_worn(piece))
	buy.focus_exited.connect(func() -> void: _hide_compare())
	row.add_child(buy)
	return row


## Lays the hovered piece beside whatever is worn in its slot.
func _compare_to_worn(piece: Dictionary) -> void:
	if _compare == null or not is_instance_valid(_compare):
		return
	_compare.show_pair(piece)


func _hide_compare() -> void:
	if _compare != null and is_instance_valid(_compare):
		_compare.hide_pair()


func _buy(index: int) -> void:
	var refused: String = VendorStock.buy(index)
	if refused.is_empty():
		UiSound.confirm()
		_result.text = "Tessel wraps it and puts it in your stash."
	else:
		UiSound.deny()
		_result.text = refused
	_refresh()


func _line(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("b8ae98"))
	return label


## Sized against the screen, and the picture is the first thing to give up:
## `menu_layout_check` failed the Forge's first cut at phone sizes with "no way
## out at all", and its header was a third of why.
func _refit() -> void:
	if _panel == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_panel.custom_minimum_size = Vector2(minf(PANEL_WIDTH, screen.x * 0.94), 0.0)
	var room: bool = screen.y >= HEADER_MIN_SCREEN
	if _art != null:
		(_art.get_parent() as CanvasItem).visible = room
	# Measured rather than a share of the screen: a flat 42% plus a header, a
	# heading, two lines of copy, a result, a purse and a row of buttons is
	# taller than a landscape phone, and the panel then hangs off the bottom.
	_scroll.custom_minimum_size = Vector2(0.0, minf(screen.y * 0.42,
		UiMetrics.scroll_room_measured(_scroll, _scroll.get_parent() as Control,
			Balance.UI_PANEL_MARGIN)))
	_panel.reset_size()
