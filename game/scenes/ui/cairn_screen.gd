class_name CairnScreen
extends CanvasLayer

## **The Cairn** (triage of 2026-10-07, "run history and the Hall"): a stone in
## the Hold for every road the account has walked. The fallen on one side - the
## last of them standing as they were, in the look and gear they fell in - and
## the records on the other, with how many roads were walked and how each ended.
##
## A readout: it reads `MetaState.run_history` and `run_records` and writes
## nothing, so opening it changes no byte of the account. Every word is data
## (`CairnText`).

signal closed()

const PANEL_WIDTH: float = 1100.0
const FIGURE_HEIGHT: float = 220.0
const NUMERALS: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]

var _panel: PanelContainer
var _heading: Label
var _note: Label
var _figure: WardenStage = null
var _figure_line: Label
var _fallen: VBoxContainer
var _records: VBoxContainer
var _walked: Label
var _scroll: ScrollContainer
var _close_button: Button


func _ready() -> void:
	UiJuice.enrol.call_deferred(get_tree(), self)
	layer = 92
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(_refit)
	visible = false


func _text() -> CairnText:
	return ContentDB.ui_texts.get("cairn_text", null) as CairnText


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.03, 0.03, 0.9)
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
	UiFonts.set_role(_heading, UiFonts.Role.TITLE, 26)
	_heading.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(_heading)

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFonts.set_role(_note, UiFonts.Role.FLAVOUR, 15)
	_note.add_theme_color_override("font_color", Color("b8ae98"))
	column.add_child(_note)

	_scroll = ScrollContainer.new()
	UiMetrics.prepare_scroll(_scroll, TouchInput.is_showing())
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)

	var sides := HBoxContainer.new()
	sides.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sides.add_theme_constant_override("separation", 24)
	_scroll.add_child(sides)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	left.add_theme_constant_override("separation", 8)
	sides.add_child(left)
	left.add_child(_section("fallen"))
	# **The last to fall, as they were**: the dressed Warden on the Glass's own
	# stage, in the look and the worn kinds the road ended in.
	_figure = WardenStage.new()
	_figure.custom_minimum_size = Vector2(0.0, FIGURE_HEIGHT)
	_figure.turntable = false
	left.add_child(_figure)
	_figure_line = Label.new()
	_figure_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_figure_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.set_role(_figure_line, UiFonts.Role.FLAVOUR, 14)
	_figure_line.add_theme_color_override("font_color", Color("d8cbb0"))
	left.add_child(_figure_line)
	_fallen = VBoxContainer.new()
	_fallen.add_theme_constant_override("separation", 6)
	left.add_child(_fallen)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	sides.add_child(right)
	right.add_child(_section("records"))
	_records = VBoxContainer.new()
	_records.add_theme_constant_override("separation", 6)
	right.add_child(_records)
	right.add_child(_section("walked"))
	_walked = Label.new()
	_walked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_walked.add_theme_font_size_override("font_size", 15)
	_walked.add_theme_color_override("font_color", Color("d8d2c4"))
	right.add_child(_walked)

	_close_button = Button.new()
	_close_button.name = "Close"
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_close_button.pressed.connect(hide_screen)
	column.add_child(_close_button)


func _section(which: String) -> Label:
	var label := Label.new()
	label.name = "Heading_" + which
	UiFonts.set_role(label, UiFonts.Role.HEADING, 19)
	label.add_theme_color_override("font_color", Color("c9a46a"))
	return label


func open() -> void:
	visible = true
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


## The rows the screen shows, read off the account: the fallen, newest first.
static func fallen_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in MetaState.run_history:
		if String(row.get("ended", "")) == "fell":
			out.append(row)
	return out


func _refresh() -> void:
	var text: CairnText = _text()
	if text == null:
		return
	_heading.text = text.title
	_note.text = text.note
	_close_button.text = text.close
	(_find("Heading_fallen") as Label).text = text.fallen_heading
	(_find("Heading_records") as Label).text = text.records_heading
	(_find("Heading_walked") as Label).text = text.walked_heading
	for child: Node in _fallen.get_children():
		child.queue_free()
	for child: Node in _records.get_children():
		child.queue_free()
	var fallen: Array[Dictionary] = fallen_rows()
	_figure.visible = not fallen.is_empty()
	_figure_line.visible = not fallen.is_empty()
	if fallen.is_empty():
		_fallen.add_child(_line(text.no_fallen, Color("9f978a")))
	else:
		var last: Dictionary = fallen[0]
		_figure.show_look_wearing(WardenLook.unpack(last.get("look", [])), last.get("gear", []) as Array)
		var cause: String = String(last.get("cause", ""))
		_figure_line.text = cause if not cause.is_empty() else text.cause_unknown
		# The figure says what felled the last; its row does not say it twice.
		for index: int in fallen.size():
			_fallen.add_child(_fallen_row(fallen[index], text, index > 0))
	var any: bool = false
	for key: String in MetaState.RUN_RECORD_KEYS:
		var value: int = int(MetaState.run_records.get(key, 0))
		if value <= 0:
			continue
		any = true
		_records.add_child(_record_row(String(text.record_names.get(key, key)), _record_value(key, value, text)))
	if not any:
		_records.add_child(_line(text.no_records, Color("9f978a")))
	var home: int = 0
	var summit: int = 0
	var fell: int = 0
	for row: Dictionary in MetaState.run_history:
		match String(row.get("ended", "")):
			"home":
				home += 1
			"summit":
				summit += 1
			_:
				fell += 1
	_walked.text = text.walked_line % [MetaState.run_history.size(), home, summit, fell]


func _find(name: String) -> Node:
	return _panel.find_child(name, true, false)


func _fallen_row(row: Dictionary, text: CairnText, with_cause: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var act: int = int(row.get("act", 1))
	var terrain: TerrainData = ContentDB.terrain_for_act(act)
	var top: String = text.fallen_line % [NUMERALS[clampi(act - 1, 0, NUMERALS.size() - 1)],
		terrain.display_name if terrain != null else "", int(row.get("wave", 0))]
	if bool(row.get("hardcore", false)):
		top += "  ·  " + text.hardcore_mark
	box.add_child(_line(top, Color("e2d6bb"), 15))
	var tier: CampaignTierData = ContentDB.tier(String(row.get("tier", "")))
	var cause: String = String(row.get("cause", ""))
	var detail: String = text.fallen_detail % [tier.display_name if tier != null else "",
		int(row.get("level", 1)), _ago(int(row.get("at", 0)), text)]
	box.add_child(_line(detail, Color("a89f8e"), 13))
	if with_cause and not cause.is_empty():
		box.add_child(_line(cause, Color("c08a7a"), 13))
	return box


func _record_row(name: String, value: String) -> Control:
	var row := HBoxContainer.new()
	var label := _line(name, Color("cfc5b0"), 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var shown := _line(value, Color("f0d9a0"), 15)
	# A number is never wrapped: autowrapping in a row gives it no width of its
	# own, and it came out one character a line.
	shown.autowrap_mode = TextServer.AUTOWRAP_OFF
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(shown)
	return row


func _record_value(key: String, value: int, text: CairnText) -> String:
	match key:
		"time":
			if value >= 3600:
				return text.record_hours % [value / 3600, (value / 60) % 60]
			return text.record_minutes % [value / 60, value % 60]
		"act":
			return text.record_act % NUMERALS[clampi(value - 1, 0, NUMERALS.size() - 1)]
	return str(value)


func _ago(at: int, text: CairnText) -> String:
	var seconds: int = maxi(int(Time.get_unix_time_from_system()) - at, 0)
	if at <= 0 or seconds < 60:
		return text.ago_now
	if seconds < 3600:
		return text.ago_minutes % (seconds / 60)
	if seconds < 86400:
		return text.ago_hours % (seconds / 3600)
	return text.ago_days % (seconds / 86400)


func _line(words: String, colour: Color, size: int = 15) -> Label:
	var label := Label.new()
	label.text = words
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _refit() -> void:
	if _panel == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_panel.custom_minimum_size = Vector2(minf(PANEL_WIDTH, screen.x * 0.94), 0.0)
	_scroll.custom_minimum_size = Vector2(0.0, minf(screen.y * 0.62,
		UiMetrics.scroll_room_measured(_scroll, _scroll.get_parent() as Control,
			Balance.UI_PANEL_MARGIN)))
	if _figure != null:
		_figure.fit_height(FIGURE_HEIGHT)
	_panel.reset_size()
