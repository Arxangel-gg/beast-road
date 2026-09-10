class_name TradeScreen
extends CanvasLayer

## The trade window: two offers, an acceptance, and then a second screen.
##
## Owner brief, 2026-09-10, RuneScape-style. `TradeSession` holds the rules and
## `TradeBooth` owns the gear; this only draws what they say and sends what the
## player presses.
##
## **Two screens, not one, and the second one is the point.** The first is where
## the deal is put together and either side may change their mind about anything.
## The second shows what is about to happen and asks both players to say yes to
## *that* - and any change at all, by anybody, throws everybody back to the first
## screen with both acceptances withdrawn. Without the second screen, agreeing to
## a trade and receiving one are two different things separated by half a second
## of somebody else's honesty.
##
## The stash list is the player's own, drawn from `MetaState` each refresh rather
## than cached: a run can end and deliver a drop while this is open, and a list
## that had gone stale would let somebody offer a piece by a position that had
## moved under them.

const MAX_ROWS: int = 40

var _panel: PanelContainer
var _header: Label
var _note: Label
var _mine: VBoxContainer
var _theirs: VBoxContainer
var _stash: VBoxContainer
var _actions: HBoxContainer
var _scroll: ScrollContainer

## Stash indices this player has put on the table, in the order they were added.
var _picked: Array[int] = []
var _message: String = ""


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	TradeBooth.changed.connect(_on_trade_changed)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.9)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(940.0, 0.0)
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

	# The two offers, side by side, because the whole question a player is
	# answering is "is this what we agreed" and that is a comparison.
	var tables := HBoxContainer.new()
	tables.add_theme_constant_override("separation", 12)
	column.add_child(tables)
	_mine = _table(tables, "You give")
	_theirs = _table(tables, "You get")

	var scroll := ScrollContainer.new()
	UiMetrics.prepare_scroll(scroll, TouchInput.is_showing())
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, 260.0)
	column.add_child(scroll)
	_scroll = scroll

	_stash = VBoxContainer.new()
	_stash.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stash.add_theme_constant_override("separation", 4)
	scroll.add_child(_stash)

	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	column.add_child(_actions)


## One side's column: a heading that stays, over a list that is rebuilt.
##
## The heading lives *outside* the box `_fill` empties. It did not, and the first
## screenshot of this window showed two offers under no headings at all - the
## refresh cleared the column and took the words "You give" with it. A caption
## that only survives until the first redraw is a caption nobody sees.
func _table(into: HBoxContainer, title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", Color("cbb682"))
	column.add_child(heading)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	column.add_child(box)
	into.add_child(column)
	return box


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	TradeBooth.cancel("Trade cancelled.")


func _on_trade_changed() -> void:
	var trade: TradeSession = TradeBooth.session()
	if trade == null or not trade.is_running():
		if visible:
			_message = ""
			_picked.clear()
			visible = false
		return
	visible = true
	_refresh()


## Everything drawn from what the booth says, every time.
##
## Rebuilt wholesale rather than patched, because the alternative is a screen
## that is *mostly* the current table - and this is the one screen where a stale
## row is a player agreeing to something that is not on offer.
func _refresh() -> void:
	var trade: TradeSession = TradeBooth.session()
	if trade == null:
		return
	var me: String = TradeBooth.side()
	var them: String = TradeSession.other_side(me)

	match trade.stage:
		TradeSession.Stage.INVITED:
			_draw_invitation(trade, me)
			return
		TradeSession.Stage.CONFIRMING, TradeSession.Stage.SETTLING:
			_header.text = "Confirm the trade"
			_note.text = ("This is what is about to happen. Either of you can "
				+ "still change it - and if anybody does, you will both be asked "
				+ "to agree again.")
		_:
			_header.text = "Trading with %s" % TradeBooth.partner_name()
			_note.text = ("Pick from your stash below. Changing either offer "
				+ "withdraws both acceptances.")
	if not _message.is_empty():
		_note.text = _message

	_fill(_mine, trade.offer(me))
	_fill(_theirs, trade.offer(them))
	_draw_stash(trade)
	_draw_actions(trade, me, them)


func _draw_invitation(trade: TradeSession, me: String) -> void:
	_clear(_mine)
	_clear(_theirs)
	_clear(_stash)
	_clear(_actions)
	var waiting: bool = trade.invited_by == me
	_header.text = "Trade"
	_note.text = "Waiting for %s to answer." % TradeBooth.partner_name() if waiting \
		else "%s wants to trade." % TradeBooth.partner_name()
	if waiting:
		_actions.add_child(_button("Withdraw", func() -> void:
			TradeBooth.cancel("The invitation was withdrawn.")))
		return
	_actions.add_child(_button("Trade", func() -> void:
		_say(TradeBooth.answer_invite(true))))
	_actions.add_child(_button("No thanks", func() -> void:
		_say(TradeBooth.answer_invite(false))))


func _fill(into: VBoxContainer, pieces: Array) -> void:
	_clear(into)
	if pieces.is_empty():
		var empty := Label.new()
		empty.text = "nothing"
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color("6f675c"))
		into.add_child(empty)
		return
	for entry: Variant in pieces:
		var piece := entry as Dictionary
		var line := Label.new()
		line.text = _describe(piece)
		line.add_theme_font_size_override("font_size", 13)
		line.add_theme_color_override("font_color", Stash.rarity_colour(piece))
		into.add_child(line)


## The player's own stash, with what is already on the table marked.
##
## Only drawn while the offers can still change. On the confirmation screen the
## stash is deliberately absent: a list of pieces you can click is an invitation
## to change the deal, and the whole purpose of that screen is to read the deal
## rather than edit it. Changing your mind there means going back, which the
## Change button does explicitly.
func _draw_stash(trade: TradeSession) -> void:
	_clear(_stash)
	# Hidden rather than emptied on the confirmation screen, so the panel closes
	# up around the two offers instead of leaving a pane of nothing between the
	# deal and the button that agrees to it.
	_scroll.visible = trade.stage == TradeSession.Stage.OFFERING
	if not _scroll.visible:
		return
	var rows: int = 0
	for index: int in MetaState.stash.size():
		if rows >= MAX_ROWS:
			break
		var piece: Dictionary = MetaState.stash[index]
		var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
		if kind == null:
			continue
		rows += 1
		var on_table: bool = _picked.has(index)
		var row := Button.new()
		# **ASCII, because a tick is not a glyph every bundled font has.**
		# `font_glyph_check` caught U+2713 here: it draws correctly on this
		# machine and as an empty box on Android, which is the worst kind of
		# wrong - it looks finished to whoever wrote it.
		row.text = "%s  %s" % ["*" if on_table else "   ", _describe(piece)]
		row.custom_minimum_size = Vector2(0.0, 34.0)
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", Stash.rarity_colour(piece))
		var at: int = index
		row.pressed.connect(func() -> void: _toggle(at))
		_stash.add_child(row)


func _draw_actions(trade: TradeSession, me: String, them: String) -> void:
	_clear(_actions)
	var mine_yes: bool = trade.has_accepted(me)
	var theirs_yes: bool = trade.has_accepted(them)
	if trade.stage == TradeSession.Stage.OFFERING:
		_actions.add_child(_button("Accepted" if mine_yes else "Accept",
			func() -> void: _say(TradeBooth.set_accepted(not mine_yes))))
		var status := Label.new()
		status.text = "%s has accepted." % TradeBooth.partner_name() if theirs_yes \
			else "%s has not accepted." % TradeBooth.partner_name()
		status.add_theme_font_size_override("font_size", 13)
		status.add_theme_color_override("font_color",
			Color("9fd48a") if theirs_yes else Color("b8ae98"))
		_actions.add_child(status)
	else:
		var mine_done: bool = trade.has_confirmed(me)
		_actions.add_child(_button("Confirmed" if mine_done else "Confirm",
			func() -> void: _say(TradeBooth.set_confirmed(not mine_done))))
		_actions.add_child(_button("Change", func() -> void:
			# Re-offering the same list is a change as far as the rules are
			# concerned, which is exactly what going back should be: everybody
			# agrees again from the first screen.
			_say(TradeBooth.offer_indices(_picked.duplicate())))
		)
	_actions.add_child(_button("Cancel", func() -> void:
		TradeBooth.cancel("%s cancelled the trade." % _own_name())))


func _toggle(index: int) -> void:
	if _picked.has(index):
		_picked.erase(index)
	elif _picked.size() >= Balance.TRADE_MAX_PIECES:
		_say("You cannot put more than %d pieces on the table."
			% Balance.TRADE_MAX_PIECES)
		return
	else:
		_picked.append(index)
	var refusal: String = TradeBooth.offer_indices(_picked.duplicate())
	if not refusal.is_empty():
		# Put back, so what is ticked and what is on the table never disagree.
		if _picked.has(index):
			_picked.erase(index)
		else:
			_picked.append(index)
		_say(refusal)
		return
	_say("")


func _describe(piece: Dictionary) -> String:
	var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
	var name: String = kind.display_name if kind != null else "Gear"
	return "%s %s  ·  level %d" % [Stash.rarity_name(piece), name,
		int(piece.get("level", 1))]


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150.0, 42.0)
	button.pressed.connect(action)
	return button


func _say(message: String) -> void:
	_message = message
	if message.is_empty():
		_refresh()
		return
	_note.text = message


func _own_name() -> String:
	var seat: CoopParty.Seat = Coop.party().seat_for_slot(Coop.party().slot())
	return seat.name if seat != null else "Somebody"


func _clear(box: Container) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
