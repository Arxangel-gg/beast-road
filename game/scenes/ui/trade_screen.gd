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

const MAX_ROWS: int = 60
const ICON_SIZE: float = 40.0
const ATTRIBUTE_NAMES: Array[String] = ["Might", "Vigour", "Swiftness", "Focus"]

var _panel: PanelContainer
var _header: Label
var _note: Label
var _mine: VBoxContainer
var _theirs: VBoxContainer
var _stash: VBoxContainer
var _actions: HBoxContainer
var _scroll: ScrollContainer
var _stash_heading: Label

var _message: String = ""


## What this player currently has on the table, by name.
##
## **Derived, not remembered.** This was a local array kept in step with the
## session by hand, and the screenshot that found the fault showed a piece
## sitting under "You give" while its row in the list below still offered to add
## it: the table had come from the host and the local copy knew nothing about it.
##
## Every route that sets an offer without going through this screen has that
## shape - reopening the window, a partner's change arriving, a settlement
## failing and rolling the table back. Reading it out of the session removes the
## whole class rather than the one instance, and it is the same reasoning that
## put names on pieces in the first place: one fact, in one place.
##
## Names rather than stash positions throughout, because a stash can change while
## this window is open and every index after the change moves.
func _on_table() -> Array[int]:
	var out: Array[int] = []
	var trade: TradeSession = TradeBooth.session()
	if trade == null:
		return out
	for entry: Variant in trade.offer(TradeBooth.side()):
		out.append(int((entry as Dictionary).get("uid", 0)))
	return out


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	TradeBooth.changed.connect(_on_trade_changed)
	# The stash can move while this is open: a run ends and delivers a drop, a
	# settlement lands. The list is redrawn from `MetaState` every refresh, so
	# this only has to ask for one.
	EventBus.stash_changed.connect(func() -> void:
		if visible:
			_refresh())


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

	# **The list below the offers needs to say what it is.**
	# Without this the panel ran the offer totals straight into the stash rows,
	# and the first row read as a third thing being given away. It lives beside
	# the scroll rather than inside it for the same reason the column headings
	# do: `_draw_stash` empties the box every refresh.
	_stash_heading = Label.new()
	_stash_heading.add_theme_font_size_override("font_size", 15)
	_stash_heading.add_theme_color_override("font_color", Color("cbb682"))
	column.add_child(_stash_heading)

	var scroll := ScrollContainer.new()
	UiMetrics.prepare_scroll(scroll, TouchInput.is_showing())
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Tall enough that the stash reads as a list rather than a peephole. The rows
	# grew when they gained art and a second line, and 260 showed four and a half
	# of them.
	scroll.custom_minimum_size = Vector2(0.0, 360.0)
	column.add_child(scroll)
	_scroll = scroll

	# The scrollbar is drawn inside the scroll's own rect, so rows that fill the
	# width end underneath it. A margin the width of the bar keeps the action
	# button at the end of each row clear of it.
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override("margin_right", 14)
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(gutter)

	_stash = VBoxContainer.new()
	_stash.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stash.add_theme_constant_override("separation", 4)
	gutter.add_child(_stash)

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

	_prune_picked()
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


## One piece, drawn the way the stash draws it.
##
## **The same presentation on both sides of the table and in the list below.**
## A trade is a judgement about value, and a player cannot make it from a name:
## they need the art they recognise the item by, the slot it competes for, the
## level it has been taken to, and the attribute it actually grants. The stash
## screen already shows all of that, and showing it differently here would mean
## reading the same sword two ways in one session.
##
## Works for the partner's pieces as well as your own, because everything it
## needs is derivable: the wire carries kind, rarity, level and name, and the
## receiving machine looks the rest up in its own `ContentDB`. Nothing about the
## other player's gear has to be trusted in order to be *described*.
func _piece_row(piece: Dictionary) -> Control:
	var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Centred rather than filled: the row is two lines of text tall and a top
	# aligned icon hangs off the bottom of the shorter ones.
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if kind != null:
		var art: String = kind.get_sprite_path()
		if ResourceLoader.exists(art):
			icon.texture = load(art) as Texture2D
		icon.modulate = Stash.rarity_colour(piece).lerp(Color.WHITE, 0.45)
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 14)
	title.text = "%s %s" % [Stash.rarity_name(piece),
		kind.display_name if kind != null else "Unknown"]
	title.add_theme_color_override("font_color",
		Stash.rarity_colour(piece).lerp(Color("e8e2d4"), 0.3))
	text.add_child(title)

	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color("9d9484"))
	if kind == null:
		detail.text = "gear this build does not know"
	else:
		# Marks are on the row because they are the only number in the game that
		# says what a piece is *worth*, and a trade is the one screen where that
		# is the question being asked.
		detail.text = "%s  ·  Lv%d  ·  +%d %s  ·  %d Marks%s" % [
			kind.slot_name(), int(piece.get("level", 1)),
			Stash.points(piece, kind),
			ATTRIBUTE_NAMES[clampi(kind.attribute, 0, ATTRIBUTE_NAMES.size() - 1)],
			Stash.sell_price(piece),
			"  ·  KEPT" if Stash.is_favourite(piece) else ""]
		row.tooltip_text = kind.description
	text.add_child(detail)
	return row


## A row on a band, edged in the piece's rarity.
##
## **The band is what joins a piece to the button that offers it.** The panel is
## 940 wide and the action sits at the right end of it, so the screenshot that
## found this showed a glaive on the left and an Offer button most of a screen
## away with nothing between them saying they were the same row. A background
## that runs the full width says it.
##
## The rarity edge is the second half: a stash of forty is scanned for what is
## worth trading before any of the words are read, and a coloured margin answers
## that at a glance the way the name alone cannot.
func _band(inner: Control, piece: Dictionary, lit: bool) -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var rarity: Color = Stash.rarity_colour(piece)
	style.bg_color = Color(0.13, 0.16, 0.19, 0.9) if lit \
		else Color(0.07, 0.09, 0.11, 0.55)
	style.border_width_left = 4
	style.border_color = rarity.lerp(Color.WHITE, 0.35) if lit else rarity
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	box.add_theme_stylebox_override("panel", style)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(inner)
	return box


## What a side's offer adds up to, for the line under it.
##
## Two numbers, because they answer different questions. The attribute total is
## what the gear will *do* for whoever ends up wearing it; the Marks total is
## what it is worth if they never wear it at all. A trade that is good by one and
## bad by the other is a trade worth thinking about, and a player cannot notice
## that from a list of names.
func _summarise(pieces: Array) -> String:
	if pieces.is_empty():
		return "nothing offered"
	var points: int = 0
	var marks: int = 0
	for entry: Variant in pieces:
		var piece := entry as Dictionary
		var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
		if kind != null:
			points += Stash.points(piece, kind)
		marks += Stash.sell_price(piece)
	return "%d piece%s  ·  +%d attribute points  ·  %d Marks" % [
		pieces.size(), "" if pieces.size() == 1 else "s", points, marks]


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
		into.add_child(_band(_piece_row(piece), piece, false))
	# Indented to the band's own text, so the sum reads as belonging to the list
	# above it rather than to the heading below.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 2)
	into.add_child(margin)
	var total := Label.new()
	total.text = _summarise(pieces)
	total.add_theme_font_size_override("font_size", 12)
	total.add_theme_color_override("font_color", Color("cbb682"))
	margin.add_child(total)


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
	_stash_heading.visible = _scroll.visible
	if not _scroll.visible:
		return
	var table: Array[int] = _on_table()
	_stash_heading.text = "Your stash  ·  %d held  ·  %d of %d offered" % [
		MetaState.stash.size(), table.size(), Balance.TRADE_MAX_PIECES]
	var rows: int = 0
	for index: int in MetaState.stash.size():
		if rows >= MAX_ROWS:
			break
		var piece: Dictionary = MetaState.stash[index]
		var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
		if kind == null:
			continue
		rows += 1
		var uid: int = Stash.uid(piece)
		var on_table: bool = table.has(uid)
		var worn: bool = int(MetaState.equipped.get(kind.slot, -1)) == index

		# **A row with a button on it, not a row inside a button.**
		#
		# The first version wrapped the whole thing in a `Button` and laid the
		# icon and text out with `PRESET_FULL_RECT` inside it. A Button positions
		# its own content within its frame, and an anchored child ignores that
		# entirely - so the art sat on the carved border and the name floated
		# above the top edge. It looked like a styling problem and was a
		# structural one.
		#
		# One explicit control per row is also the better screen: the stash
		# already reads as a list of pieces with actions beside them, and a
		# whole row that silently means "click me to give this away" is a wide
		# target for a decision that hands over gear.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var body: Control = _piece_row(piece)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(body)

		var action := Button.new()
		action.custom_minimum_size = Vector2(120.0, 36.0)
		action.add_theme_font_size_override("font_size", 13)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if worn:
			# Not "Worn": that is the name of the lowest rarity, and this list is
			# full of pieces actually called Worn Something. A button reading
			# "Worn" beside "Worn Ashfall Glaive" says nothing.
			action.text = "Equipped"
			action.disabled = true
			action.tooltip_text = "Equipped gear cannot be traded. Take it off first."
		else:
			action.text = "Take back" if on_table else "Offer"
			var named: int = uid
			action.pressed.connect(func() -> void: _toggle(named))
		row.add_child(action)

		var band: PanelContainer = _band(row, piece, on_table)
		# Dimmed enough to read as unavailable, not so far that its own label
		# stops being legible - a disabled Button is already faded once.
		band.modulate = Color(1.0, 1.0, 1.0, 0.68) if worn else Color.WHITE
		_stash.add_child(band)


func _draw_actions(trade: TradeSession, me: String, them: String) -> void:
	_clear(_actions)
	var mine_yes: bool = trade.has_accepted(me)
	var theirs_yes: bool = trade.has_accepted(them)
	if trade.stage == TradeSession.Stage.OFFERING:
		_actions.add_child(_button("Accepted" if mine_yes else "Accept",
			func() -> void: _say(TradeBooth.set_accepted(not mine_yes))))
		_actions.add_child(_status(theirs_yes,
			"%s has accepted." % TradeBooth.partner_name(),
			"%s has not accepted." % TradeBooth.partner_name()))
	else:
		var mine_done: bool = trade.has_confirmed(me)
		_actions.add_child(_button("Confirmed" if mine_done else "Confirm",
			func() -> void: _say(TradeBooth.set_confirmed(not mine_done))))
		_actions.add_child(_button("Change", func() -> void:
			# Re-offering the same list is a change as far as the rules are
			# concerned, which is exactly what going back should be: everybody
			# agrees again from the first screen.
			_say(TradeBooth.offer_uids(_on_table())))
		)
		# **The same standing question as the first screen, and it was missing
		# here.** This is the screen where a player waits, and waiting without
		# being told what for reads as the window having hung. It also tells you
		# the one thing worth knowing before pressing Confirm: whether pressing
		# it settles the trade or only starts the wait.
		_actions.add_child(_status(trade.has_confirmed(them),
			"%s has confirmed." % TradeBooth.partner_name(),
			"%s has not confirmed." % TradeBooth.partner_name()))
	_actions.add_child(_button("Cancel", func() -> void:
		TradeBooth.cancel("%s cancelled the trade." % _own_name())))


func _toggle(uid: int) -> void:
	var wanted: Array[int] = _on_table()
	if wanted.has(uid):
		wanted.erase(uid)
	elif wanted.size() >= Balance.TRADE_MAX_PIECES:
		_say("You cannot put more than %d pieces on the table."
			% Balance.TRADE_MAX_PIECES)
		return
	else:
		wanted.append(uid)
	# Nothing is put back when this is refused, because nothing was changed
	# locally to put back: the table is whatever the session says it is, and a
	# refused change simply never became one.
	_say(TradeBooth.offer_uids(wanted))


## Drops names that are no longer in this stash.
##
## A piece can leave while the window is open - the settlement of a previous
## trade, a bulk break from another screen - and a mark against something that
## is gone is a table the player cannot clear, because the row that would clear
## it is not there any more.
func _prune_picked() -> void:
	var wanted: Array[int] = _on_table()
	var kept: Array[int] = []
	for uid: int in wanted:
		if Stash.index_of(MetaState.stash, uid) >= 0:
			kept.append(uid)
	if kept.size() != wanted.size():
		TradeBooth.offer_uids(kept)


func _describe(piece: Dictionary) -> String:
	var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
	var name: String = kind.display_name if kind != null else "Gear"
	return "%s %s  ·  level %d" % [Stash.rarity_name(piece), name,
		int(piece.get("level", 1))]


## Where the other player is, in the one line the actions row has room for.
func _status(done: bool, yes: String, no: String) -> Label:
	var status := Label.new()
	status.text = yes if done else no
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color",
		Color("9fd48a") if done else Color("b8ae98"))
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return status


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
