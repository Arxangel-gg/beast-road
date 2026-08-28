class_name ChronicleScreen
extends CanvasLayer

const KeywordTextScript = preload("res://scripts/systems/keyword_text.gd")

## The account's finite set of one-time mastery deeds.
##
## Always reachable from the front door: an objective hidden until it is earned
## is a surprise payout, not something a player can work toward. The Chronicle
## shows the complete bounded set and makes its horizontal reward explicit.

signal closed()

var _heading: Label
var _note: Label
var _rows: VBoxContainer
var _close_button: Button


func _ready() -> void:
	layer = 64
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.9)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(940.0, 0.0)
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 22)
	_heading.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(_heading)

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", Color("b8ae98"))
	column.add_child(_note)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Leaves the heading and the always-visible Close button inside a 720p frame.
	# The rows are the flexible part and scroll; the only way out never does.
	scroll.custom_minimum_size = Vector2(0.0, 420.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_close_button.pressed.connect(hide_screen)
	column.add_child(_close_button)


func open() -> void:
	visible = true
	_refresh()
	_close_button.grab_focus()


func hide_screen() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_screen()


func _refresh() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()

	var objectives: Array[ChronicleObjectiveData] = ContentDB.chronicle_objectives_sorted()
	var completed: int = 0
	for objective: ChronicleObjectiveData in objectives:
		if MetaState.objective_completed(objective.id):
			completed += 1
	_heading.text = "Chronicle  ·  %d of %d deeds kept" % [completed, objectives.size()]
	_note.text = "One-time feats across the whole road. Tools widen future choices; " \
		+ "these deeds never raise combat stats."

	for objective: ChronicleObjectiveData in objectives:
		_rows.add_child(_objective_row(objective))


func _objective_row(objective: ChronicleObjectiveData) -> PanelContainer:
	var done: bool = MetaState.objective_completed(objective.id)
	var tint: Color = Color("e8a33d") if done else Color("d8d2c4")

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"InnerPanel"
	panel.custom_minimum_size = Vector2(0.0, 62.0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var seal: TextureRect = IconKit.rect("chainbreaker_seal", 38.0,
		Color.WHITE if done else Color(0.48, 0.5, 0.5, 0.72))
	if seal != null:
		row.add_child(seal)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)

	var name_label := Label.new()
	name_label.text = objective.display_name
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", tint)
	copy.add_child(name_label)

	var description := RichTextLabel.new()
	KeywordTextScript.apply(description, objective.description)
	description.fit_content = true
	description.scroll_active = false
	description.add_theme_font_size_override("font_size", 13)
	description.add_theme_color_override("default_color", Color("9fa7a2"))
	copy.add_child(description)

	var status := Label.new()
	status.text = "◆  KEPT" if done else "+%d Tool%s" % [
		objective.tool_reward, "" if objective.tool_reward == 1 else "s"]
	status.custom_minimum_size = Vector2(128.0, 0.0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_color", tint)
	row.add_child(status)
	return panel
