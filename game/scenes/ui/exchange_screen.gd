class_name ExchangeScreen
extends CanvasLayer

## The Long Ledger: six lines, a guide price, and the road that settles them.
##
## Owner brief, 2026-09-10: a grand exchange "for players to be able to create a
## trading economy for all of the loot in the game".
##
## ## What this screen has to teach, in the order it has to teach it
##
## **1. What a thing is worth.** Every price field opens on the guide, so a
## player who understands nothing and presses List still gets a fair, filling
## price. The Ledger is usable before it is understood.
##
## **2. That the price is a lever.** Under the field is the band - the least a
## caravan will ever pay, the guide, and the most anyone will ever ask - and the
## line beside it says how long *this* price will take. Move the number, watch
## the estimate move. That is the entire skill and it is one sentence.
##
## **3. That the road is the clock.** Every open line shows a bar and "settles
## in about N roads", never a wall-clock time, because nothing happens while the
## beast is standing still. A player who leaves the game open waiting is a player
## the screen lied to.
##
## Three tabs rather than three screens, because the board is the thing you come
## back to and listing is what you do while you are there.

signal closed()

## Rows of stash to offer at once. The stash holds 160 and the ledger holds six;
## a page is for finding the piece you meant, not for browsing.
const MAX_ROWS: int = 80

enum Tab {
	## The six lines and what they owe.
	BOARD,
	## Pick a piece out of the stash and name a price.
	SELL,
	## Name a piece you want and what you will pay.
	BUY,
}

var _panel: PanelContainer
var _header: Label
var _note: Label
var _tabs: HBoxContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _actions: HBoxContainer

var _tab: Tab = Tab.BOARD
var _message: String = ""

## What the Sell tab has selected, by name rather than by position: the stash can
## change under this screen and an index would quietly become another sword.
var _picked_uid: int = 0

## What the Buy tab is describing.
var _want_kind: String = ""
var _want_rarity: int = 1
var _want_level: int = 1

var _price: SpinBox = null


func _ready() -> void:
	layer = 64
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	Exchange.changed.connect(func() -> void:
		if visible:
			_refresh())
	EventBus.stash_changed.connect(func() -> void:
		if visible:
			_refresh())


func open() -> void:
	_tab = Tab.BOARD
	_message = ""
	visible = true
	Exchange.refresh_prices()
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.92)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(980.0, 0.0)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 22)
	_header.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(_header)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", Color("b8ae98"))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)

	var scroll := ScrollContainer.new()
	UiMetrics.prepare_scroll(scroll, TouchInput.is_showing())
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Replaced by the measured room every refresh; this is only what it looks
	# like for the frame before the first one.
	scroll.custom_minimum_size = Vector2(0.0, 300.0)
	column.add_child(scroll)
	_scroll = scroll

	# The scrollbar is drawn inside the scroll's own rect, so a row that fills
	# the width ends underneath it.
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override("margin_right", 14)
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(gutter)

	var inside := VBoxContainer.new()
	inside.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inside.add_theme_constant_override("separation", 8)
	gutter.add_child(inside)

	# **Inside the scroll, because they are content.** On a 430-tall phone the
	# fixed chrome - heading, note, a row of tabs and a row of actions - came to
	# more than the whole display, and a `CenterContainer` overflows equally in
	# both directions, so the Close button went off the bottom.
	# `menu_layout_check` caught it. Only the two things a player must always be
	# able to reach stay outside the scroll: what the screen is, and the way out.
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inside.add_child(_tabs)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	inside.add_child(_body)

	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	column.add_child(_actions)


## Sizes the panel to the display it is actually on.
##
## **A fixed panel width is a phone that cannot close the window.** The stash
## screen learned this the expensive way - a `CenterContainer` overflows equally
## in both directions, so a panel wider or taller than the screen pushes its
## Close button off the edge, and it was reported from a phone. `menu_layout_check`
## catches it now, which is how this one was found before anybody had to.
##
## The scroll's height is *measured* against the column's other children rather
## than reserving a guessed constant, for the same reason: a reserved number is
## wrong the moment a row is added above it.
func _refit() -> void:
	if _panel == null or _scroll == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_panel.custom_minimum_size = Vector2(minf(980.0,
		screen.x - Balance.UI_PANEL_MARGIN * 2.0), 0.0)
	var column: Control = _panel.get_child(0) as Control
	if column != null:
		_scroll.custom_minimum_size = Vector2(0.0,
			UiMetrics.scroll_room_measured(_scroll, column, Balance.UI_PANEL_MARGIN))


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close()


# --- Drawing ------------------------------------------------------------------

func _refresh() -> void:
	_header.text = "The Long Ledger  ·  %d Marks  ·  %d of %d lines" % [
		MetaState.marks, Exchange.slots_used(), Balance.EXCHANGE_SLOTS]
	if not _message.is_empty():
		_note.text = _message
	else:
		_note.text = _standing_note()
	_draw_tabs()
	_clear(_body)
	_clear(_actions)
	match _tab:
		Tab.BOARD:
			_draw_board()
		Tab.SELL:
			_draw_sell()
		Tab.BUY:
			_draw_buy()
	_actions.add_child(_button("Close", func() -> void: close()))
	# **Draw first, then fit.** `_refit` measures the column's other children,
	# and measuring them before they have been rebuilt fits the screen to the
	# previous one.
	_refit()


## The one sentence the screen is always saying.
##
## It says which of two things the guide price is, because they are different
## claims and a player pricing a sword deserves to know which one they are
## reading: the community's actual trades, or the authored markup on their own
## vendor price.
func _standing_note() -> String:
	if Exchange.prices_are_live():
		return ("Orders settle as the beast walks. Guide prices are what Wardens "
			+ "on this road have actually been paying.")
	return ("Orders settle as the beast walks. No word has reached this stretch "
		+ "of road yet, so guide prices are the caravans' standing rate.")


func _draw_tabs() -> void:
	_clear(_tabs)
	for entry: Array in [[Tab.BOARD, "The board"], [Tab.SELL, "List gear"],
			[Tab.BUY, "Place an order"]]:
		var which: Tab = entry[0] as Tab
		var button := Button.new()
		button.text = String(entry[1])
		# A floor rather than a width: three of these have to fit across a phone.
		button.custom_minimum_size = Vector2(96.0, 40.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.disabled = which == _tab
		button.pressed.connect(func() -> void:
			_tab = which
			_message = ""
			_picked_uid = 0
			_refresh())
		_tabs.add_child(button)


## The board: what is standing, how far along, and what it owes.
func _draw_board() -> void:
	var orders: Array[ExchangeOrder] = Exchange.orders()
	if orders.is_empty():
		_body.add_child(_quiet("The ledger is empty. List a piece, or put in an "
			+ "order for one you are hunting."))
		return
	for index: int in orders.size():
		var order: ExchangeOrder = orders[index]
		# The description, not the escrow: a met sale has handed its piece over
		# and holds only Marks, and the board still has to say what for.
		var about: Dictionary = order.about
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 2)
		row.add_child(text)
		text.add_child(GearRow.build(about))

		var line := Label.new()
		line.add_theme_font_size_override("font_size", 12)
		line.add_theme_color_override("font_color", Color("9d9484"))
		var verb: String = "Selling for" if order.side == ExchangeMarket.Side.SELL \
			else "Buying at"
		if order.stage == ExchangeOrder.Stage.FILLED:
			line.add_theme_color_override("font_color", Color("9fd48a"))
			line.text = "Met  ·  %s waiting" % (
				"%d Marks" % order.payout_marks if order.payout_marks > 0
					else "the piece")
		else:
			line.text = "%s %d Marks  ·  %s  ·  %d%% of the way" % [verb,
				order.price, _settles_in(order), int(round(order.progress * 100.0))]
		# Indented to the name above it rather than to the band's edge, so the
		# status reads as belonging to the piece instead of to the row.
		var under := MarginContainer.new()
		under.add_theme_constant_override("margin_left",
			int(GearRow.ICON_SIZE) + 10)
		under.add_child(line)
		text.add_child(under)

		var action := Button.new()
		action.custom_minimum_size = Vector2(140.0, 36.0)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		action.add_theme_font_size_override("font_size", 13)
		var at: int = index
		if order.stage == ExchangeOrder.Stage.FILLED:
			action.text = "Collect"
			action.pressed.connect(func() -> void: _say(Exchange.collect(at)))
		else:
			action.text = "Take back"
			action.tooltip_text = ("Cancelling gives back exactly what you put in: "
				+ "the piece, or the Marks.")
			action.pressed.connect(func() -> void: _say(Exchange.cancel(at)))
		row.add_child(action)
		_body.add_child(GearRow.band(row, about,
			order.stage == ExchangeOrder.Stage.FILLED))


## How long a line has left, in the only unit that means anything here.
##
## Roads, never minutes. Nothing moves while the beast is standing still, and a
## screen that counted seconds would be telling a player to wait in a menu.
func _settles_in(order: ExchangeOrder) -> String:
	var about: Dictionary = order.about
	var demand: float = Exchange.demand_for(about)
	var guide: int = ExchangeMarket.guide_price(about, demand)
	var rate: float = ExchangeMarket.fill_rate(int(order.side), order.price, guide,
		ExchangeMarket.max_ask(about, demand), ExchangeMarket.min_bid(about, demand))
	if order.side == ExchangeMarket.Side.BUY:
		rate *= Exchange.supply_for(about)
	if rate <= 0.0:
		return "no caravan will meet this price"
	var left: float = (1.0 - order.progress) / rate
	var roads: float = left / Balance.JOURNEY_TOTAL_DISTANCE
	if roads < 0.15:
		return "settles within the next road"
	return "about %s of road left" % ("%.1f runs" % roads if roads >= 1.0
		else "%d%% of a run" % int(round(roads * 100.0)))


## Listing: the stash on the left, one price field under it.
func _draw_sell() -> void:
	if not Exchange.has_room():
		_body.add_child(_quiet("Every line is taken. Collect or take back one first."))
		return
	var picked_at: int = Stash.index_of(MetaState.stash, _picked_uid)
	var picked: Dictionary = MetaState.stash[picked_at] if picked_at >= 0 else {}
	if picked.is_empty():
		_body.add_child(_caption("Choose a piece below to list it."))
	elif _is_equipped(picked_at):
		# Reachable without any misuse: choose a piece, equip something else in
		# another screen, come back. The button has to go, not just refuse.
		_body.add_child(_caption("That piece is equipped now. Take it off, or "
			+ "choose another."))
	else:
		_body.add_child(_caption("Listing"))
		_body.add_child(_pricing_panel(picked, ExchangeMarket.Side.SELL))
		_actions.add_child(_button("List it", func() -> void:
			var refusal: String = Exchange.post_sale(
				Stash.index_of(MetaState.stash, _picked_uid), _price_value())
			if refusal.is_empty():
				_tab = Tab.BOARD
				_picked_uid = 0
			_say(refusal)))

	var rows: int = 0
	for index: int in MetaState.stash.size():
		if rows >= MAX_ROWS:
			break
		var piece: Dictionary = MetaState.stash[index]
		if ContentDB.gear(String(piece.get("kind", ""))) == null:
			continue
		rows += 1
		var uid: int = Stash.uid(piece)
		var worn: bool = _is_equipped(index)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var body: Control = GearRow.build(piece)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(body)

		var guide := Label.new()
		guide.add_theme_font_size_override("font_size", 12)
		guide.add_theme_color_override("font_color", Color("cbb682"))
		guide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		guide.text = "guide %d" % Exchange.guide_price(piece)
		row.add_child(guide)

		var action := Button.new()
		action.custom_minimum_size = Vector2(120.0, 36.0)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		action.add_theme_font_size_override("font_size", 13)
		if worn:
			action.text = "Equipped"
			action.disabled = true
			action.tooltip_text = "Equipped gear cannot be listed. Take it off first."
		else:
			action.text = "Chosen" if uid == _picked_uid else "Choose"
			action.disabled = uid == _picked_uid
			var named: int = uid
			action.pressed.connect(func() -> void:
				_picked_uid = named
				_message = ""
				_refresh())
		row.add_child(action)
		var band: PanelContainer = GearRow.band(row, piece, uid == _picked_uid)
		band.modulate = Color(1.0, 1.0, 1.0, 0.68) if worn else Color.WHITE
		_body.add_child(band)


## Ordering: describe the piece you are hunting, then say what it is worth to you.
func _draw_buy() -> void:
	if not Exchange.has_room():
		_body.add_child(_quiet("Every line is taken. Collect or take back one first."))
		return
	if _want_kind.is_empty():
		_want_kind = _first_gear_kind()
	var wanted: Dictionary = Stash.make(_want_kind, _want_rarity, _want_level)
	_body.add_child(_caption("Hunting for"))
	_body.add_child(_pricing_panel(wanted, ExchangeMarket.Side.BUY))

	# What to hunt for: kind, then rarity, then level. Three pickers rather than
	# a search box, because the answer is always one of a known set and a player
	# should not have to spell "Oathbound Ashwalk Greaves".
	_body.add_child(_picker("Piece", _gear_names(), _gear_ids().find(_want_kind),
		func(at: int) -> void:
			_want_kind = _gear_ids()[at]
			_refresh()))
	_body.add_child(_picker("Rarity", Stash.RARITY_NAMES, _want_rarity,
		func(at: int) -> void:
			_want_rarity = at
			_refresh()))
	var levels: Array[String] = []
	for level: int in range(1, Stash.MAX_LEVEL + 1):
		levels.append("Level %d" % level)
	_body.add_child(_picker("Level", levels, _want_level - 1,
		func(at: int) -> void:
			_want_level = at + 1
			_refresh()))

	var scarcity := Label.new()
	scarcity.add_theme_font_size_override("font_size", 12)
	scarcity.add_theme_color_override("font_color", Color("9d9484"))
	scarcity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scarcity.text = _scarcity_line(wanted)
	_body.add_child(scarcity)

	_actions.add_child(_button("Place the order", func() -> void:
		var refusal: String = Exchange.post_purchase(_want_kind, _want_rarity,
			_want_level, _price_value())
		if refusal.is_empty():
			_tab = Tab.BOARD
		_say(refusal)))


## How often the road actually carries this, said in words rather than a number.
##
## The honest warning. A player who puts three runs of Marks into a standing
## order for an Oathbound piece and hears nothing should have been told, and
## "the road rarely carries these" is the thing to say before they press it.
func _scarcity_line(piece: Dictionary) -> String:
	var supply: float = Exchange.supply_for(piece)
	if supply >= 0.7:
		return "Caravans carry these by the crate. An order at the guide fills quickly."
	if supply >= 0.4:
		return "These come along often enough. Expect to wait a road or two."
	if supply >= 0.15:
		return ("Few of these change hands. A good price helps; patience helps more.")
	return ("Almost nobody parts with these. An order may stand for many roads, "
		+ "and finding one yourself is the likelier way to hold it.")


## The price field, with the band it sits in and what this price means.
func _pricing_panel(piece: Dictionary, side: ExchangeMarket.Side) -> Control:
	var demand: float = Exchange.demand_for(piece)
	var guide: int = ExchangeMarket.guide_price(piece, demand)
	var floor_price: int = ExchangeMarket.min_bid(piece, demand)
	var ceiling: int = ExchangeMarket.max_ask(piece, demand)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.add_child(GearRow.build(piece))

	var band := Label.new()
	band.add_theme_font_size_override("font_size", 12)
	band.add_theme_color_override("font_color", Color("9d9484"))
	band.text = "Guide %d Marks  ·  nobody buys under %d  ·  nobody sells over %d" % [
		guide, floor_price, ceiling]
	column.add_child(band)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	column.add_child(line)
	var caption := Label.new()
	caption.text = "Your price" if side == ExchangeMarket.Side.SELL else "Your offer"
	caption.add_theme_font_size_override("font_size", 14)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(caption)

	# **Opens on the guide.** A player who understands none of this and presses
	# the button still gets a fair price that fills, which is what makes the
	# Ledger usable before it is understood.
	_price = SpinBox.new()
	_price.min_value = 1
	_price.max_value = 9_999_999
	_price.step = 1
	_price.value = guide
	_price.custom_minimum_size = Vector2(180.0, 40.0)
	line.add_child(_price)

	var verdict := Label.new()
	verdict.add_theme_font_size_override("font_size", 12)
	verdict.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verdict.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(verdict)
	var supply: float = Exchange.supply_for(piece)
	var restate: Callable = func(_value: float = 0.0) -> void:
		verdict.text = _verdict(side, int(_price.value), guide, floor_price,
			ceiling, supply)
		verdict.add_theme_color_override("font_color",
			Color("9fd48a") if verdict.text.begins_with("Fills") else Color("cbb682"))
	_price.value_changed.connect(restate)
	restate.call()
	return GearRow.band(column, piece, true)


## What this particular number means, in the moment the player types it.
##
## The whole skill of the screen is "move the price, watch the wait move", and
## this is the sentence that makes it visible. Written as a consequence rather
## than a rate, because "0.0031 per unit" teaches nobody anything.
func _verdict(side: ExchangeMarket.Side, price: int, guide: int, floor_price: int,
		ceiling: int, supply: float) -> String:
	if side == ExchangeMarket.Side.SELL:
		if price > ceiling:
			return "No caravan pays this much. It will stand for ever."
		if price <= guide:
			return "Fills quickly - at or under the guide there is always a buyer."
		return "Over the guide. It will sell, but you will ride a good way first."
	if price < floor_price:
		return "Under what any caravan will part with one for. It will never fill."
	# **Price and scarcity are two different answers and the screen said one.**
	# A generous offer for something nobody carries reported "fills quickly"
	# directly above a line reading "almost nobody parts with these". Both were
	# true and together they were a contradiction, so the good-price verdict now
	# only claims speed when there is actually supply to be quick about.
	if price >= guide:
		if supply < 0.2:
			return ("A strong offer, but the road barely carries these. Expect to "
				+ "wait however much you pay.")
		if supply < 0.5:
			return "A good offer. These come along; give it a road or two."
		return "Fills quickly - you are offering at or over the going rate."
	return "Under the guide. Somebody may take it, eventually."


# --- Small parts --------------------------------------------------------------

func _picker(caption: String, options: Array, chosen: int, on_pick: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(90.0, 0.0)
	label.add_theme_font_size_override("font_size", 13)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var options_button := OptionButton.new()
	options_button.custom_minimum_size = Vector2(320.0, 40.0)
	options_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry: Variant in options:
		options_button.add_item(String(entry))
	options_button.selected = clampi(chosen, 0, maxi(options.size() - 1, 0))
	options_button.item_selected.connect(func(at: int) -> void: on_pick.call(at))
	row.add_child(options_button)
	return row


## A heading over a panel, so the thing being priced is not read as a list row.
func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("cbb682"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _quiet(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("6f675c"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160.0, 42.0)
	button.pressed.connect(action)
	return button


func _price_value() -> int:
	return int(_price.value) if _price != null else 0


func _picked_piece() -> Dictionary:
	var at: int = Stash.index_of(MetaState.stash, _picked_uid)
	return MetaState.stash[at] if at >= 0 else {}


func _is_equipped(index: int) -> bool:
	for slot: Variant in MetaState.equipped:
		if int(MetaState.equipped[slot]) == index:
			return true
	return false


func _gear_ids() -> Array[String]:
	var out: Array[String] = []
	for value: Variant in ContentDB.gear_kinds.values():
		var kind := value as GearData
		if kind != null:
			out.append(kind.id)
	out.sort()
	return out


func _gear_names() -> Array[String]:
	var out: Array[String] = []
	for id: String in _gear_ids():
		var kind: GearData = ContentDB.gear(id)
		out.append("%s  ·  %s" % [kind.display_name, kind.slot_name()])
	return out


func _first_gear_kind() -> String:
	var ids: Array[String] = _gear_ids()
	return ids[0] if not ids.is_empty() else ""


func _say(message: String) -> void:
	_message = message
	_refresh()


func _clear(box: Container) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
