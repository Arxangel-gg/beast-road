class_name SupportDiagnosticsPanel
extends VBoxContainer

## Collection happens only on Prepare; Copy shares exactly the previewed text.
## The parent Data tab owns scrolling, keeping one themed, draggable scrollbar.
const COPY: DiagnosticCopyData = preload("res://data/ui/support_diagnostics.tres")

var _preview: RichTextLabel
var _copy_button: Button
var _status: Label


func _ready() -> void:
	name = "SupportDiagnostics"
	add_theme_constant_override("separation", 10)
	add_child(_label(COPY.heading, 22))
	add_child(_label(COPY.description, 14))
	var prepare := Button.new()
	prepare.name = "PrepareReport"
	prepare.text = COPY.prepare_label
	prepare.custom_minimum_size.y = 54.0
	prepare.pressed.connect(prepare_report)
	add_child(prepare)
	_status = _label("", 14)
	_status.visible = false
	add_child(_status)
	_copy_button = Button.new()
	_copy_button.name = "CopyReport"
	_copy_button.text = COPY.copy_label
	_copy_button.custom_minimum_size.y = 54.0
	_copy_button.visible = false
	_copy_button.pressed.connect(_copy_report)
	add_child(_copy_button)
	_preview = RichTextLabel.new()
	_preview.name = "ReportPreview"
	_preview.bbcode_enabled = false
	_preview.selection_enabled = true
	_preview.fit_content = true
	_preview.scroll_active = false
	_preview.focus_mode = Control.FOCUS_ALL
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.add_theme_font_size_override("normal_font_size", 14)
	_preview.visible = false
	add_child(_preview)


func prepare_report() -> void:
	_preview.text = SupportDiagnostics.report_text(
		Vector2i(get_viewport().get_visible_rect().size))
	_preview.visible = true
	_copy_button.visible = true
	_status.text = COPY.ready_note
	_status.visible = true


func _copy_report() -> void:
	if _preview.text.is_empty():
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		_status.text = COPY.clipboard_unavailable_note
		return
	# Web clipboard writes can be denied asynchronously. Never claim success
	# from this void-returning API, and retain a selectable fallback on screen.
	DisplayServer.clipboard_set(_preview.text)
	_status.text = COPY.copy_requested_note


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label
