class_name WaysideCard
extends CanvasLayer

## The card a wayside encounter asks from (2026-09-25). See `Wayside`.
##
## **It decides nothing.** A choice is said on the bus and `Wayside` pays for it
## and opens its doors; this only shows what the encounter says, what each
## answer costs and gives, and then what came of it. So the rule for what a
## choice may reach lives in one function, and a screen cannot disagree with it.
##
## **A choice the purse cannot pay for is shown and not offered.** Dimmed, with
## the price still on it, because an answer that vanishes when you are short
## reads as an encounter with fewer answers, and the point of the price is that
## it was there to see.
##
## The field is frozen while it is up - the run does that on `wayside_reached`
## and lets it go on `wayside_left` - the same way the crossroad freezes it for
## a decision, because an answer given while something bites is not a decision.

var _encounter: WaysideData = null
var _title: Label
var _text: Label
var _choices: VBoxContainer
var _outcome: Label
var _leave: Button
var _panel: PanelContainer
var _answered: bool = false


func _ready() -> void:
	UiJuice.enrol.call_deferred(get_tree(), self)
	layer = Balance.WAYSIDE_CARD_LAYER
	visible = false
	_build()
	get_viewport().size_changed.connect(_refit)


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.03, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.name = "Wayside"
	_panel.set_meta(UiMetrics.SELF_SIZED, true)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	_title = Label.new()
	_title.name = "Title"
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color("e8a33d"))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)

	_text = Label.new()
	_text.name = "Text"
	_text.add_theme_font_size_override("font_size", 16)
	_text.add_theme_color_override("font_color", Color("c9d2cf"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_text)

	_choices = VBoxContainer.new()
	_choices.name = "Choices"
	_choices.add_theme_constant_override("separation", 8)
	column.add_child(_choices)

	_outcome = Label.new()
	_outcome.name = "Outcome"
	_outcome.add_theme_font_size_override("font_size", 16)
	_outcome.add_theme_color_override("font_color", Color("e6d7b4"))
	_outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outcome.visible = false
	column.add_child(_outcome)

	_leave = Button.new()
	_leave.name = "Leave"
	_leave.text = "Walk on"
	_leave.custom_minimum_size = Vector2(0.0, 44.0)
	_leave.pressed.connect(close)
	column.add_child(_leave)
	UiPanels.pin_last_to_bottom(column)
	_refit()


## One answer: the button, and under it what it gives and what it costs.
func _choice_row(choice: WaysideChoiceData) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.name = choice.id
	row.add_theme_constant_override("separation", 2)
	var button := Button.new()
	button.name = "Take"
	var cost: Dictionary = choice.cost()
	var price: String = ""
	for id_value: Variant in cost:
		price = "  ·  %d %s" % [int(cost[id_value]), RunState.currency_name(String(id_value))]
	button.text = choice.label + price
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var affordable: bool = RunState.can_afford_cost(cost)
	button.disabled = not affordable
	button.pressed.connect(_take.bind(choice.id))
	row.add_child(button)
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = choice.hint
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("8f9b98") if affordable else Color("6a5d58"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(hint)
	return row


## Opens on an encounter. With none it opens on the first authored one - the
## door the focus gate stands every screen up through.
func open(encounter: WaysideData = null, title: String = "") -> void:
	if encounter == null:
		var ids: Array[String] = ContentDB.wayside_ids()
		if not ids.is_empty():
			encounter = ContentDB.wayside(ids[0])
	_encounter = encounter
	_answered = false
	for child: Node in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	_outcome.visible = false
	_choices.visible = true
	if encounter == null:
		return
	_title.text = title if not title.is_empty() else encounter.title_for("")
	_text.text = encounter.text
	for choice_id: String in encounter.choice_ids:
		var choice: WaysideChoiceData = ContentDB.wayside_choice(choice_id)
		if choice != null:
			_choices.add_child(_choice_row(choice))
	_leave.text = "Walk on"
	visible = true
	_refit()
	var first: Button = _first_offer()
	if first != null:
		first.grab_focus()
	else:
		_leave.grab_focus()


func _first_offer() -> Button:
	for row: Node in _choices.get_children():
		var button := row.get_node_or_null("Take") as Button
		if button != null and not button.disabled:
			return button
	return null


## Said on the bus, then the outcome in place of the answers.
func _take(choice_id: String) -> void:
	if _encounter == null or _answered:
		return
	var choice: WaysideChoiceData = ContentDB.wayside_choice(choice_id)
	if choice == null or not RunState.can_afford_cost(choice.cost()):
		return
	_answered = true
	EventBus.wayside_chosen.emit(_encounter.id, choice_id)
	_choices.visible = false
	_outcome.text = choice.outcome
	_outcome.visible = true
	_leave.text = "Go on"
	_leave.grab_focus()


func close() -> void:
	visible = false
	if _encounter != null:
		EventBus.wayside_left.emit(_encounter.id)


## What the card is showing, for the gate.
func showing() -> String:
	return _encounter.id if visible and _encounter != null else ""


func _refit() -> void:
	if _panel == null:
		return
	var screen: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	_panel.custom_minimum_size = Vector2(minf(screen.x * 0.9, 600.0), 0.0)
