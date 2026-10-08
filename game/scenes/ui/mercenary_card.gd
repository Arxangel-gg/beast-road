class_name MercenaryCard
extends CanvasLayer

## **Talking to a mercenary on the road** (owner, 2026-10-07: *"Let players be
## able to interact with and talk to the mercenary companions, both in the Hold
## and at the battlefield for brief dialogues"*). Interact beside one opens this:
## a line of its own, its wounds and its purse, and the four orders. It does not
## pause the road - a word in a fight is a word in a fight - and it closes on
## Close, on Interact again, or when the Warden walks away.

signal ordered(uid: String, order: int)

const ORDERS: Array[Array] = [
	[MercenaryInput.Order.FOLLOW, "Follow me", "order_follow", "Follow"],
	[MercenaryInput.Order.GUARD, "Guard here", "order_guard", "Guard"],
	[MercenaryInput.Order.HUNT, "Hunt", "order_hunt", "Hunt"],
	[MercenaryInput.Order.WALL, "Hold the wall", "order_wall", "Wall"],
]

var uid: String = ""
var _panel: PanelContainer
var _title: Label
var _quote: Label
var _state: Label
var _buttons: Dictionary = {}
var _dice := RandomNumberGenerator.new()


func _ready() -> void:
	UiJuice.enrol.call_deferred(get_tree(), self)
	layer = 60
	_dice.randomize()
	_panel = PanelContainer.new()
	_panel.name = "MercenaryCard"
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.custom_minimum_size = Vector2(Balance.MERC_CARD_WIDTH, 0.0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_bottom = -Balance.MERC_CARD_LIFT
	add_child(_panel)
	UiTint.see_through(_panel, Balance.UI_BUTTON_SEE_THROUGH)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)
	_title = Label.new()
	UiFonts.set_role(_title, UiFonts.Role.HEADING, 18)
	_title.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(_title)
	_quote = Label.new()
	_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFonts.set_role(_quote, UiFonts.Role.FLAVOUR, 16)
	_quote.add_theme_color_override("font_color", Color("efe9dc"))
	column.add_child(_quote)
	_state = Label.new()
	_state.add_theme_font_size_override("font_size", 14)
	_state.add_theme_color_override("font_color", Color("9fc48a"))
	column.add_child(_state)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	for entry: Array in ORDERS:
		var button := Button.new()
		button.name = "Order%d" % int(entry[0])
		button.text = String(entry[1])
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 40.0)
		var order: int = int(entry[0])
		button.pressed.connect(func() -> void: _order(order))
		row.add_child(button)
		_buttons[order] = button
	var close := Button.new()
	close.name = "Close"
	close.text = "Done"
	close.custom_minimum_size = Vector2(0.0, 40.0)
	close.pressed.connect(hide_card)
	column.add_child(close)
	visible = false


## Opens on one mercenary, with a line of its own.
func open_for(who: String, mind: MercenaryInput) -> void:
	uid = who
	var row: Dictionary = RunState.company_row(who)
	var hired: Dictionary = MetaState.mercenary(who)
	var speaker: String = String(row.get("name", hired.get("name", "")))
	_title.text = "%s  ·  level %d" % [speaker, int(hired.get("level", 1))]
	_quote.text = "“%s”" % MercenaryVoice.line_for("greet", speaker, _dice)
	_state.text = "%d %s left  ·  %d Gold in its purse" % [int(row.get("wounds", 0)),
		"wound" if int(row.get("wounds", 0)) == 1 else "wounds", int(row.get("purse", 0))]
	for order: Variant in _buttons:
		(_buttons[order] as Button).set_pressed_no_signal(mind != null and mind.order == int(order))
	visible = true


func is_open() -> bool:
	return visible


func hide_card() -> void:
	visible = false
	uid = ""


func _order(order: int) -> void:
	for key: Variant in _buttons:
		(_buttons[key] as Button).set_pressed_no_signal(int(key) == order)
	ordered.emit(uid, order)
