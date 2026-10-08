class_name InnScreen
extends CanvasLayer

## **The Inn** (owner, 2026-10-07): where a Warden hires the strangers in the
## Hold, keeps the company it hired, and finds the ones carried home after a
## third wound lying in a bed. The design is `docs/MERCENARIES_2026-10-07.md`.
##
## **Every rule lives on `MetaState` and none of them lives here**, the stable's
## rule: the fee, the seats, the bill, the rest and the release are doors there,
## and this screen calls one and re-reads the answer.

signal closed()

const PANEL_WIDTH: float = 1040.0
const PORTRAIT: float = 108.0

## Who is standing in the yard this visit, as `{who, name}` rows. Handed in by
## the menu from the Hold's yard; a screen with nothing to ask offers nobody.
var strangers: Callable = Callable()

var _panel: PanelContainer
var _heading: Label
var _note: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _purse: Label
var _result: Label
var _close_button: Button
## A release asked once; the second press does it.
var _releasing: String = ""
## Seeds each Warden's line for one visit, so a line does not change under the
## player every time a button redraws the rows.
var _visit: int = 0


func _ready() -> void:
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

	_heading = Label.new()
	UiFonts.set_role(_heading, UiFonts.Role.HEADING, 22)
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
	_rows.add_theme_constant_override("separation", 8)
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

	_close_button = Button.new()
	_close_button.name = "Close"
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_close_button.pressed.connect(hide_screen)
	column.add_child(_close_button)


func open() -> void:
	visible = true
	_result.text = ""
	_releasing = ""
	_visit += 1
	MetaState.wake_rested_mercenaries()
	_refresh()
	_refit()
	_refit.call_deferred()
	_close_button.grab_focus()


func hide_screen() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_screen()


## The offers standing in the yard, as hireable records.
func offers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not strangers.is_valid():
		return out
	for stranger: Variant in strangers.call():
		var row := stranger as Dictionary
		if row == null:
			continue
		var who: String = String(row.get("who", ""))
		if who.is_empty() or MetaState.has_hired(who):
			continue
		out.append(Mercenaries.offer(who, String(row.get("name", "")), MetaState.hero_level, RunState.tier()))
	return out


func _refresh() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	_heading.text = "The Inn  ·  your company %d of %d" % [MetaState.mercenaries.size(), Balance.MERC_ROSTER_MAX]
	_note.text = ("A hired Warden walks the road beside you, fights and builds with its own share "
		+ "of the spoils, and takes a cut of the Marks. It charges for every road it joins. "
		+ "Three wounds on one road and it is carried home to a bed here: it rests, and it "
		+ "rejoins once its bill is paid. Each one takes a seat in the party.")
	_rows.add_child(_section("Your company"))
	if MetaState.mercenaries.is_empty():
		_rows.add_child(_line("Nobody hired yet."))
	for row: Dictionary in MetaState.mercenaries:
		_rows.add_child(_company_row(row))
	_rows.add_child(_section("In the Hold today"))
	var standing: Array[Dictionary] = offers()
	if standing.is_empty():
		_rows.add_child(_line("Nobody else is in the yard to hire."))
	for offer: Dictionary in standing:
		_rows.add_child(_offer_row(offer))
	_purse.text = "%d Marks" % MetaState.marks


func _company_row(row: Dictionary) -> Control:
	var uid: String = String(row.get("uid", ""))
	var now: float = Time.get_unix_time_from_system()
	var resting: bool = String(row.get("state", "")) == Mercenaries.STATE_RESTING
	var line := _card_row(row, "bedridden" if resting else "hold_talk")
	var column: VBoxContainer = line.get_meta(&"column") as VBoxContainer
	var status := Label.new()
	status.add_theme_font_size_override("font_size", 14)
	if resting:
		var left: float = Mercenaries.rest_left(row, now)
		var owed: int = int(row.get("bill", 0))
		status.text = "In a bed at the inn  ·  %s%s" % [
			("rests %d more minutes" % int(ceil(left / 60.0))) if left > 0.0 else "rested",
			("  ·  owes %d Marks" % owed) if owed > 0 else "  ·  bill paid"]
		status.add_theme_color_override("font_color", Color("d98c6a"))
	else:
		status.text = "On its feet  ·  %d Marks a road" % Mercenaries.contract(row)
		status.add_theme_color_override("font_color", Color("9fc48a"))
	column.add_child(status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(buttons)
	if resting and int(row.get("bill", 0)) > 0:
		var pay := _button("Pay %d" % int(row.get("bill", 0)), "PayBill")
		pay.disabled = MetaState.marks < int(row.get("bill", 0))
		pay.pressed.connect(func() -> void: _pay(uid))
		buttons.add_child(pay)
	elif not resting:
		var taking: bool = not bool(row.get("home", false))
		var take := _button("Coming" if taking else "Stays home", "Take")
		take.toggle_mode = true
		take.button_pressed = taking
		take.pressed.connect(func() -> void: _toggle_taking(uid, not taking))
		buttons.add_child(take)
	var release := _button("Release?" if _releasing == uid else "Release", "Release")
	release.theme_type_variation = &"DangerButton"
	release.pressed.connect(func() -> void: _release(uid))
	buttons.add_child(release)
	return line


func _offer_row(offer: Dictionary) -> Control:
	var line := _card_row(offer, "stranger_pitch")
	var column: VBoxContainer = line.get_meta(&"column") as VBoxContainer
	var price := Label.new()
	price.text = "%d Marks to hire  ·  then %d a road" % [Mercenaries.fee(offer), Mercenaries.contract(offer)]
	price.add_theme_font_size_override("font_size", 14)
	price.add_theme_color_override("font_color", Color("e8d9a8"))
	column.add_child(price)
	var hire := _button("Hire", "Hire")
	hire.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var problem: String = MetaState.hire_problem(offer)
	hire.disabled = not problem.is_empty()
	hire.tooltip_text = problem
	hire.pressed.connect(func() -> void: _hire(offer))
	line.add_child(hire)
	return line


## A row for one Warden: the Warden dressed as they are, their name and level,
## what they wear and what it is worth.
func _card_row(row: Dictionary, moment: String = "") -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	var portrait := WardenStage.new()
	portrait.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	portrait.turntable = false
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(portrait)
	var look: Dictionary = WardenLook.unpack(row.get("look", []))
	var kinds: Array = Mercenaries.worn_kinds(row)
	portrait.ready.connect(func() -> void:
		portrait.show_look_wearing(look, kinds)
		portrait.fit_height(PORTRAIT), CONNECT_ONE_SHOT)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 2)
	line.add_child(column)
	line.set_meta(&"column", column)
	var name_line := Label.new()
	name_line.text = "%s  ·  level %d" % [String(row.get("name", "")), int(row.get("level", 1))]
	name_line.add_theme_font_size_override("font_size", 18)
	name_line.add_theme_color_override("font_color", Color("efe9dc"))
	column.add_child(name_line)
	# **What they say** (owner, 2026-10-07: talk to them in the Hold as well as on
	# the road): a line of their own, from the same data the road speaks from.
	if not moment.is_empty():
		var dice := RandomNumberGenerator.new()
		dice.seed = absi(hash("%s:%d" % [String(row.get("uid", "")), _visit]))
		var said: String = MercenaryVoice.line_for(moment, String(row.get("name", "")), dice)
		if not said.is_empty():
			var quote := Label.new()
			quote.name = "Says"
			quote.text = "“%s”" % said
			quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UiFonts.set_role(quote, UiFonts.Role.FLAVOUR, 14)
			quote.add_theme_color_override("font_color", Color("d9cfb8"))
			column.add_child(quote)
	var gear := Label.new()
	gear.text = _gear_line(row)
	gear.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gear.add_theme_font_size_override("font_size", 13)
	gear.add_theme_color_override("font_color", Color("8d968f"))
	column.add_child(gear)
	return line


func _gear_line(row: Dictionary) -> String:
	var parts: PackedStringArray = []
	for value: Variant in (row.get("gear", []) as Array):
		var piece := value as Dictionary
		var kind: GearData = ContentDB.gear(String(piece.get("kind", ""))) if piece != null else null
		if kind != null:
			parts.append("%s %s" % [Stash.rarity_name(piece), kind.display_name])
	if parts.is_empty():
		return "Wears nothing worth naming."
	return ", ".join(parts) + "  ·  gear worth %d points" % Mercenaries.gear_points(row)


func _hire(offer: Dictionary) -> void:
	if MetaState.hire_mercenary(offer):
		UiSound.confirm()
		_result.text = "%s takes your Marks and your hand, and walks out with your next road for %d a road." % [
			String(offer.get("name", "")), Mercenaries.contract(offer)]
	else:
		UiSound.deny()
		_result.text = MetaState.hire_problem(offer)
	_refresh()


func _pay(uid: String) -> void:
	var row: Dictionary = MetaState.mercenary(uid)
	if MetaState.pay_mercenary_bill(uid):
		UiSound.confirm()
		_result.text = "The bill for %s is settled." % String(row.get("name", ""))
	else:
		UiSound.deny()
		_result.text = "Not enough Marks for the bill."
	_refresh()


func _toggle_taking(uid: String, on: bool) -> void:
	if MetaState.set_mercenary_taking(uid, on):
		UiSound.confirm()
	else:
		UiSound.deny()
		_result.text = MetaState.taking_problem(uid)
	_refresh()


func _release(uid: String) -> void:
	if _releasing != uid:
		_releasing = uid
		_result.text = "Press Release again to let them go. Nothing is refunded."
		_refresh()
		return
	var row: Dictionary = MetaState.mercenary(uid)
	if MetaState.release_mercenary(uid):
		UiSound.confirm()
		_result.text = "%s takes their leave." % String(row.get("name", ""))
	else:
		UiSound.deny()
	_releasing = ""
	_refresh()


func _button(text: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(130.0, 44.0)
	return button


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	UiFonts.set_role(label, UiFonts.Role.HEADING, 17)
	label.add_theme_color_override("font_color", Color("c9b27a"))
	return label


func _line(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("b8ae98"))
	return label


func _refit() -> void:
	if _panel == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_panel.custom_minimum_size = Vector2(minf(PANEL_WIDTH, screen.x * 0.94), 0.0)
	_scroll.custom_minimum_size = Vector2(0.0, minf(screen.y * 0.5,
		UiMetrics.scroll_room_measured(_scroll, _scroll.get_parent() as Control,
			Balance.UI_PANEL_MARGIN)))
	_panel.reset_size()
